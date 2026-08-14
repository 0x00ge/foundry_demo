// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/console.sol";
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
    /**
     * @notice 部署 V1 实现合约和 ERC1967Proxy。
     * @dev
     * 这里有两个地址，职责完全不同：
     * - logic：只保存 V1 的代码，不能作为业务入口直接使用。
     * - proxy：保存 implementation 槽和全部业务状态，业务方应始终使用这个地址。
     *
     * `vm.startBroadcast(privateKey)` 之后的合约创建交易会使用 privateKey 发送到目标网络。广播结束后，脚本继续读取并校验链上状态，但不会再发送交易。
     */
    function run() external {
        // PRIVATE_KEY 同时决定交易签名者和 V1 的初始 owner。
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address owner = vm.addr(privateKey);

        vm.startBroadcast(privateKey);
        // 第一步：部署实现合约。
        // V1 构造函数会锁定实现地址自身的 initializer，防止被直接初始化。
        UUPSDemoLogicV1 logicV1 = new UUPSDemoLogicV1();
        console.log("********** 1 **********");

        // 第二步：编码代理部署时要执行的初始化调用。
        // selector 和参数必须与 V1.initialize(address) 完全匹配。
        bytes memory initData = abi.encodeCall(UUPSDemoLogicV1.initialize, owner);
        console.log("********** 2 **********");

        // 第三步：部署 ERC1967Proxy。
        // ERC1967Proxy 构造函数会把 initData delegatecall 到 logic：
        // - 执行代码来自 logic
        // - msg.sender 保持为部署交易的调用者
        // - address(this) 是 proxy
        // 因此 owner/version 等状态最终写入 proxy 存储。
        ERC1967Proxy proxy = new ERC1967Proxy(address(logicV1), initData);
        console.log("********** 3 **********");
        vm.stopBroadcast();

        console.log("owner : ", owner);
        console.log("proxy : ", address(proxy));
        console.log("logicV1 : ", address(logicV1));
    }
}
