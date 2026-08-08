// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/TransparentProxy.sol";
import "../src/TransparentProxyDemoLogicV2.sol";

/**
 * @title UpgradeTransparentProxy
 * @notice 透明代理升级脚本。
 * @dev
 * 执行步骤很简单：
 * 1. 读取代理地址和广播私钥
 * 2. 部署新的 V2 实现合约
 * 3. 调用代理的 upgradeTo，把 implementation 槽切到 V2
 *
 * 重要前提：
 * - 发起交易的钱包地址必须就是当前代理管理员
 * - 否则会在 upgradeTo 里被拒绝
 */
contract UpgradeTransparentProxy is Script {
    function run() external {
        address proxyAddress = vm.envAddress("PROXY_ADDR");
        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(privateKey);

        TransparentProxyDemoLogicV2 logicV2 = new TransparentProxyDemoLogicV2();
        TransparentProxy proxy = TransparentProxy(payable(proxyAddress));
        proxy.upgradeTo(address(logicV2));

        vm.stopBroadcast();

        console2.log("proxy:", proxyAddress);
        console2.log("new implementation:", address(logicV2));
    }
}
