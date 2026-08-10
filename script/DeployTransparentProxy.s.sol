// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/TransparentProxyDemoLogic.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

/**
 * @title DeployTransparentProxy
 * @notice OpenZeppelin 透明代理生产级最小部署脚本。
 * @dev
 * 这个脚本做的事情很直白：
 * 1. 部署实现合约
 * 2. 编码 initialize(...) 的 calldata
 * 3. 部署 TransparentUpgradeableProxy，并在构造函数里完成初始化
 * 4. 读取代理自动创建的 ProxyAdmin
 * 5. 打印出代理地址、实现地址、ProxyAdmin 和管理员 owner
 *
 * 环境变量：
 * - OWNER_ADDR：业务 owner 地址，必填
 * - PROXY_ADMIN_OWNER_ADDR：ProxyAdmin owner 地址，可选，不填则默认等于 OWNER_ADDR
 * - INITIAL_VALUE：初始化数值，可选，默认 1
 */
contract DeployTransparentProxy is Script {
    bytes32 internal constant ERC1967_ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    function run() external {
        address owner = vm.envAddress("OWNER_ADDR");
        address proxyAdminOwner = vm.envOr("PROXY_ADMIN_OWNER_ADDR", owner);
        uint256 initialValue = vm.envOr("INITIAL_VALUE", uint256(1));

        vm.startBroadcast();

        TransparentProxyDemoLogic logic = new TransparentProxyDemoLogic();

        bytes memory initData =
            abi.encodeWithSelector(TransparentProxyDemoLogic.initialize.selector, owner, initialValue);

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(logic), proxyAdminOwner, initData);
        ProxyAdmin proxyAdmin = ProxyAdmin(address(uint160(uint256(vm.load(address(proxy), ERC1967_ADMIN_SLOT)))));

        vm.stopBroadcast();

        console2.log("logic:", address(logic));
        console2.log("proxy:", address(proxy));
        console2.log("owner:", owner);
        console2.log("proxyAdmin:", address(proxyAdmin));
        console2.log("proxyAdminOwner:", proxyAdminOwner);
        console2.log("initialValue:", initialValue);
    }
}
