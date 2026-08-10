// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/UUPSDemoLogicV1.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title DeployUUPSDemo
 * @notice UUPS 最小部署脚本。
 * @dev
 * 部署流程：
 * 1. 使用广播私钥作为初始 owner
 * 2. 部署 V1 实现合约
 * 3. 通过 ERC1967Proxy 部署代理，并在构造时初始化
 *
 * 环境变量：
 * - PRIVATE_KEY：广播私钥，必填
 * - INITIAL_VALUE：初始数值，可选，默认 1
 */
contract DeployUUPSDemo is Script {
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address owner = vm.addr(privateKey);
        uint256 initialValue = vm.envOr("INITIAL_VALUE", uint256(1));

        vm.startBroadcast(privateKey);

        UUPSDemoLogicV1 logic = new UUPSDemoLogicV1();
        bytes memory initData = abi.encodeWithSelector(UUPSDemoLogicV1.initialize.selector, owner, initialValue);
        ERC1967Proxy proxy = new ERC1967Proxy(address(logic), initData);

        vm.stopBroadcast();

        console2.log("logic:", address(logic));
        console2.log("proxy:", address(proxy));
        console2.log("owner:", owner);
        console2.log("initialValue:", initialValue);
    }
}
