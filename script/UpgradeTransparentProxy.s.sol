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
    function run() external {
        address proxyAddress = vm.envAddress("PROXY_ADDR");
        address proxyAdminAddress = vm.envAddress("PROXY_ADMIN_ADDR");
        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(privateKey);

        TransparentProxyDemoLogicV2 logicV2 = new TransparentProxyDemoLogicV2();
        ProxyAdmin proxyAdmin = ProxyAdmin(proxyAdminAddress);
        proxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(payable(proxyAddress)), address(logicV2), "");

        vm.stopBroadcast();

        console2.log("proxy:", proxyAddress);
        console2.log("proxyAdmin:", proxyAdminAddress);
        console2.log("new implementation:", address(logicV2));
    }
}
