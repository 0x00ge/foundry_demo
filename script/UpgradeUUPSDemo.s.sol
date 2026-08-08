// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/UUPSDemoLogic.sol";
import "../src/UUPSDemoLogicV2.sol";

/**
 * @title UpgradeUUPSDemo
 * @notice UUPS 升级脚本。
 * @dev
 * 升级步骤：
 * 1. 读取代理地址和广播私钥
 * 2. 部署 V2 实现合约
 * 3. 通过代理地址调用 upgradeToAndCall，把实现切到 V2
 *
 * 前提：
 * - 这个私钥对应的钱包必须是当前 proxy 的 owner
 */
contract UpgradeUUPSDemo is Script {
    function run() external {
        address proxyAddress = vm.envAddress("PROXY_ADDR");
        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(privateKey);

        UUPSDemoLogicV2 logicV2 = new UUPSDemoLogicV2();
        UUPSDemoLogic proxy = UUPSDemoLogic(payable(proxyAddress));
        proxy.upgradeToAndCall(address(logicV2), "");

        vm.stopBroadcast();

        console2.log("proxy:", proxyAddress);
        console2.log("new implementation:", address(logicV2));
    }
}
