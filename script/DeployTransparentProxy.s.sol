// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/TransparentProxy.sol";
import "../src/TransparentProxyDemoLogic.sol";

/**
 * @title DeployTransparentProxy
 * @notice 透明代理的最小部署脚本。
 * @dev
 * 这个脚本做的事情很直白：
 * 1. 部署实现合约
 * 2. 编码 initialize(...) 的 calldata
 * 3. 部署透明代理，并在构造函数里完成初始化
 * 4. 打印出代理地址、实现地址和管理员地址
 *
 * 环境变量：
 * - OWNER_ADDR：业务 owner 地址，必填
 * - PROXY_ADMIN_ADDR：代理管理员地址，可选，不填则默认等于 OWNER_ADDR
 * - INITIAL_VALUE：初始化数值，可选，默认 1
 */
contract DeployTransparentProxy is Script {
    function run() external {
        address owner = vm.envAddress("OWNER_ADDR");
        address proxyAdmin = vm.envOr("PROXY_ADMIN_ADDR", owner);
        uint256 initialValue = vm.envOr("INITIAL_VALUE", uint256(1));

        vm.startBroadcast();

        TransparentProxyDemoLogic logic = new TransparentProxyDemoLogic();

        bytes memory initData = abi.encodeWithSelector(
            TransparentProxyDemoLogic.initialize.selector,
            owner,
            initialValue
        );

        TransparentProxy proxy = new TransparentProxy(address(logic), proxyAdmin, initData);

        vm.stopBroadcast();

        console2.log("logic:", address(logic));
        console2.log("proxy:", address(proxy));
        console2.log("owner:", owner);
        console2.log("proxyAdmin:", proxyAdmin);
        console2.log("initialValue:", initialValue);
    }
}
