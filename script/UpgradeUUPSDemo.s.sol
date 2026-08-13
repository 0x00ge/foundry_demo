// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/UUPSDemoLogicV1.sol";
import "../src/UUPSDemoLogicV2.sol";

/**
 * @title UpgradeUUPSDemo
 * @notice UUPS 生产级最小升级脚本。
 * @dev
 * 升级步骤：
 * 1. 读取代理地址和广播私钥
 * 2. 部署 V2 实现合约；V2 实现自身同样会锁定初始化
 * 3. 通过代理地址调用 upgradeToAndCall，切换 implementation
 * 4. 通过 initializeToken 补充 ERC20 元数据初始化
 *
 * 前提：
 * - 这个私钥对应的钱包必须是当前 proxy 的 owner
 * - PROXY_ADDR 必须是 ERC1967Proxy 地址，而不是 V1/V2 实现地址
 */
contract UpgradeUUPSDemo is Script {
    // EIP-1967 implementation 槽位。
    // 升级前后都读取这个槽，用于确认代理确实完成了实现切换。
    bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /**
     * @notice 部署 V2 实现并通过 UUPS 代理完成升级。
     * @dev
     * 本脚本把“预检、广播、结果校验”分成三个阶段：
     *
     * 1. 预检：
     *    - 检查代理地址非零
     *    - 读取代理 owner
     *    - 确认广播私钥对应地址就是 owner
     *    - 记录旧 implementation 地址
     *
     * 2. 广播：
     *    - 部署 V2 实现
     *    - 从代理地址调用 upgradeToAndCall
     *    - 使用 initializeToken calldata，补充 ERC20 元数据
     *
     * 3. 结果校验：
     *    - implementation 槽必须指向新 V2
     *    - owner 必须保持不变
     *
     * 注意：upgradeToAndCall 必须从 proxy 地址调用，不能直接对 logicV2
     * 或旧 logicV1 地址调用；UUPSUpgradeable 的 onlyProxy 会拒绝直接调用。
     */
    function run() external {
        // PROXY_ADDR 是稳定的代理地址，不是实现合约地址。
        address proxyAddress = vm.envAddress("PROXY_ADDR");

        // PRIVATE_KEY 必须对应代理 owner，负责签名升级交易。
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address upgrader = vm.addr(privateKey);

        require(proxyAddress != address(0), "UUPS upgrade: proxy is zero address");

        // 预检阶段只读代理存储，不发送交易。
        UUPSDemoLogicV1 proxy = UUPSDemoLogicV1(payable(proxyAddress));
        require(proxy.owner() == upgrader, "UUPS upgrade: caller is not proxy owner");

        // 记录升级前实现，便于输出审计和排查信息。
        address previousImplementation = address(uint160(uint256(vm.load(proxyAddress, IMPLEMENTATION_SLOT))));

        vm.startBroadcast(privateKey);

        // 部署 V2 只会产生新的代码地址，不会改变现有代理状态。
        UUPSDemoLogicV2 logicV2 = new UUPSDemoLogicV2();

        // initializeToken 使用 reinitializer(2) 补充 ERC20 元数据。
        // upgradeToAndCall 会依次完成：
        // 1. onlyProxy：确认调用来自代理上下文
        // 2. _authorizeUpgrade：确认代理存储中的 owner 有权限
        // 3. proxiableUUID：确认 V2 使用兼容的 ERC1967 implementation 槽
        // 4. 写入新的 implementation 槽
        // 5. 在同一笔交易中初始化 ERC20 名称和符号
        bytes memory migrationData = abi.encodeCall(UUPSDemoLogicV2.initializeToken, ());
        proxy.upgradeToAndCall(address(logicV2), migrationData);

        // 升级后通过同一个 proxy 地址切换为 V2 ABI。
        UUPSDemoLogicV2 upgradedProxy = UUPSDemoLogicV2(payable(proxyAddress));

        // 读取代理槽位，而不是只比较 logicV2 变量，确认链上状态已经落盘。
        address currentImplementation = address(uint160(uint256(vm.load(proxyAddress, IMPLEMENTATION_SLOT))));

        require(currentImplementation == address(logicV2), "UUPS upgrade: implementation mismatch");
        // 升级只替换代码，不应重置代理中的 owner。
        require(upgradedProxy.owner() == upgrader, "UUPS upgrade: owner changed");

        vm.stopBroadcast();

        console2.log("proxy:", proxyAddress);
        console2.log("previous implementation:", previousImplementation);
        console2.log("new implementation:", address(logicV2));
        console2.log("version:", upgradedProxy.version());
    }
}
