// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/UUPSDemoLogicV1.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title DeployUUPSDemo
 * @notice UUPS 生产级最小部署脚本。
 * @dev
 * 部署流程：
 * 1. 使用广播私钥推导初始 owner
 * 2. 部署 V1 实现合约；实现构造函数会锁定实现自身初始化
 * 3. 编码 initialize(owner) calldata
 * 4. 通过 ERC1967Proxy 部署代理；代理构造函数 delegatecall 执行初始化
 *
 * 部署完成后：
 * - logic 是不可直接初始化的实现地址
 * - proxy 是用户和业务方应该使用的稳定地址
 * - owner 存储在 proxy 的代理存储中
 *
 * 环境变量：
 * - PRIVATE_KEY：广播私钥，必填
 */
contract DeployUUPSDemo is Script {
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address owner = vm.addr(privateKey);

        vm.startBroadcast(privateKey);

        // 实现合约只提供代码，不承载业务状态。
        UUPSDemoLogicV1 logic = new UUPSDemoLogicV1();

        // ERC1967Proxy 构造函数会把这段 calldata delegatecall 到 logic，
        // 所以 initialize 写入的是 proxy 存储，而不是 logic 存储。
        bytes memory initData = abi.encodeWithSelector(UUPSDemoLogicV1.initialize.selector, owner);

        ERC1967Proxy proxy = new ERC1967Proxy(address(logic), initData);

        vm.stopBroadcast();

        console2.log("logic:", address(logic));
        console2.log("proxy:", address(proxy));
        console2.log("owner:", owner);
    }
}
