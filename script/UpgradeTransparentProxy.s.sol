// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/TransparentProxyDemoLogicV2.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

/**
 * @title UpgradeTransparentProxy
 * @notice OpenZeppelin 透明代理生产级最小升级脚本。
 * @dev
 * 执行步骤很简单：
 * 1. 读取代理地址、ProxyAdmin 地址和广播私钥
 * 2. 部署新的 V2 实现合约
 * 3. 通过 ProxyAdmin 调用 upgradeAndCall，把 implementation 槽切到 V2
 *
 * 重要前提：
 * - 发起交易的钱包地址必须是 ProxyAdmin owner
 */
contract UpgradeTransparentProxy is Script {
    // EIP-1967 implementation 槽位。
    // 升级前后读取这个槽位，用于确认代理的实现地址确实发生变化。
    bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /**
     * @notice 部署 V2 实现并通过 ProxyAdmin 升级透明代理。
     * @dev
     * 透明代理的权限链路不是 EOA 直接调用代理升级：
     * 1. EOA 必须是 ProxyAdmin owner。
     * 2. EOA 调用 ProxyAdmin.upgradeAndCall。
     * 3. ProxyAdmin 作为透明代理 admin 调用代理内部升级入口。
     * 4. 代理切换 implementation 后，普通业务调用才会进入 V2。
     *
     * `ITransparentUpgradeableProxy` 是必要的，因为 OpenZeppelin 透明代理
     * 为避免 selector clash，不会把 upgradeToAndCall 直接编译进代理 ABI。
     */
    function run() external {
        // PROXY_ADDR 是业务方长期使用的代理地址，不是实现合约地址。
        address proxyAddress = vm.envAddress("PROXY_ADDR");

        // PROXY_ADMIN_ADDR 是部署脚本输出的 ProxyAdmin 合约地址，不是 owner EOA。
        address proxyAdminAddress = vm.envAddress("PROXY_ADMIN_ADDR");

        // PRIVATE_KEY 必须对应 ProxyAdmin.owner()，负责签名升级交易。
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address upgrader = vm.addr(privateKey);

        // 广播前预检，避免先部署 V2 再发现权限或地址配置错误。
        require(proxyAddress != address(0), "Transparent upgrade: proxy is zero address");
        require(proxyAdminAddress != address(0), "Transparent upgrade: ProxyAdmin is zero address");

        ProxyAdmin proxyAdmin = ProxyAdmin(proxyAdminAddress);
        require(proxyAdmin.owner() == upgrader, "Transparent upgrade: caller is not ProxyAdmin owner");

        // 记录升级前 implementation，便于审计输出和排查误配地址。
        address previousImplementation = address(uint160(uint256(vm.load(proxyAddress, IMPLEMENTATION_SLOT))));

        vm.startBroadcast(privateKey);

        // 部署 V2 只产生新代码，不会修改现有 proxy 状态。
        TransparentProxyDemoLogicV2 logicV2 = new TransparentProxyDemoLogicV2();

        // 透明代理没有直接暴露可用的升级 ABI，所以把代理地址转换为接口。
        // 空 calldata 表示本次升级没有额外的状态迁移。
        proxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(payable(proxyAddress)), address(logicV2), "");

        // 通过同一个 proxy 地址切换为 V2 ABI，确认代理地址保持不变。
        TransparentProxyDemoLogicV2 upgradedProxy = TransparentProxyDemoLogicV2(payable(proxyAddress));
        address currentImplementation = address(uint160(uint256(vm.load(proxyAddress, IMPLEMENTATION_SLOT))));

        // 升级后预检：implementation 必须指向刚部署的 V2，业务 owner 不应被重置。
        require(currentImplementation == address(logicV2), "Transparent upgrade: implementation mismatch");
        require(upgradedProxy.owner() != address(0), "Transparent upgrade: owner was reset");
        require(
            keccak256(bytes(upgradedProxy.version())) == keccak256(bytes("TransparentProxyDemoLogicV1")),
            "Transparent upgrade: stored version changed unexpectedly"
        );

        vm.stopBroadcast();

        console2.log("proxy:", proxyAddress);
        console2.log("proxyAdmin:", proxyAdminAddress);
        console2.log("previous implementation:", previousImplementation);
        console2.log("new implementation:", address(logicV2));
        console2.log("current implementation:", currentImplementation);
        console2.log("stored version:", upgradedProxy.version());
    }
}
