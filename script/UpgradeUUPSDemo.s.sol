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
 * 3. 编码 V2 的 reinitializer(2) 迁移调用
 * 4. 通过代理地址调用 upgradeToAndCall，原子完成实现切换和状态迁移
 *
 * 前提：
 * - 这个私钥对应的钱包必须是当前 proxy 的 owner
 * - PROXY_ADDR 必须是 ERC1967Proxy 地址，而不是 V1/V2 实现地址
 */
contract UpgradeUUPSDemo is Script {
    function run() external {
        address proxyAddress = vm.envAddress("PROXY_ADDR");
        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(privateKey);

        UUPSDemoLogicV2 logicV2 = new UUPSDemoLogicV2();
        UUPSDemoLogicV1 proxy = UUPSDemoLogicV1(payable(proxyAddress));

        // upgradeToAndCall 会先执行 UUPS 的 onlyProxy、owner 和 UUID 校验，
        // 再更新 implementation 槽，并在同一笔交易里执行 initializeV2。
        bytes memory migrationData = abi.encodeWithSelector(UUPSDemoLogicV2.initializeV2.selector);
        proxy.upgradeToAndCall(address(logicV2), migrationData);

        vm.stopBroadcast();

        console2.log("proxy:", proxyAddress);
        console2.log("new implementation:", address(logicV2));
    }
}
