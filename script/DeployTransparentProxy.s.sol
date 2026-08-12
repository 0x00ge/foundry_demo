// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/TransparentProxyDemoLogicV1.sol";
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
 */
contract DeployTransparentProxy is Script {
    // EIP-1967 admin 槽位。
    // OpenZeppelin v5 的 TransparentUpgradeableProxy 会自动部署 ProxyAdmin，
    // 并把 ProxyAdmin 地址写入这个槽位。
    bytes32 internal constant ERC1967_ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    /**
     * @notice 部署透明代理 V1、业务初始化数据和 ProxyAdmin。
     * @dev
     * 这里有三个重要角色：
     * - logic：只保存 V1 代码，不保存代理业务状态。
     * - proxy：稳定业务入口，保存 implementation 槽和全部业务状态。
     * - proxyAdmin：透明代理真正识别的 admin，负责转发升级操作。
     *
     * OWNER_ADDR 是业务逻辑 owner；PROXY_ADMIN_OWNER_ADDR 是 ProxyAdmin owner。
     * 两者可以是同一个地址，也可以分别交给业务多签和升级多签管理。
     *
     * `vm.startBroadcast()` 使用 forge 命令行配置的签名账户发送部署交易。
     * 它不改变 initialize 写入的业务 owner，业务 owner 由 OWNER_ADDR 决定。
     */
    function run() external {
        // 业务 owner 负责管理 V1 的业务状态，例如 setValue。
        address owner = vm.envAddress("OWNER_ADDR");

        // ProxyAdmin owner 负责升级透明代理。生产环境通常建议使用独立多签。
        address proxyAdminOwner = vm.envOr("PROXY_ADMIN_OWNER_ADDR", owner);

        vm.startBroadcast();

        // 第一步：部署 V1 实现。
        // 实现合约构造函数会锁定实现地址自身的初始化，业务状态仍由 proxy 持有。
        TransparentProxyDemoLogicV1 logic = new TransparentProxyDemoLogicV1();

        // 第二步：编码 initialize(owner)。
        // 这段 calldata 会在 TransparentUpgradeableProxy 构造阶段 delegatecall 到 logic。
        bytes memory initData = abi.encodeCall(TransparentProxyDemoLogicV1.initialize, owner);

        // 第三步：部署透明代理。
        // 构造函数内部会部署 ProxyAdmin、设置 implementation/admin，
        // 并 delegatecall 执行 initData，所以初始化状态写入 proxy。
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(logic), proxyAdminOwner, initData);

        // 代理没有直接暴露标准 admin ABI，使用 EIP-1967 admin 槽读取自动创建的 ProxyAdmin。
        ProxyAdmin proxyAdmin = ProxyAdmin(address(uint160(uint256(vm.load(address(proxy), ERC1967_ADMIN_SLOT)))));

        // 通过 V1 ABI 访问 proxy 地址，业务方后续应保存并使用 proxy 地址。
        TransparentProxyDemoLogicV1 app = TransparentProxyDemoLogicV1(address(proxy));

        // 第四步：部署后预检，确认初始化和 ProxyAdmin 所有权写入正确位置。
        require(app.owner() == owner, "Transparent deploy: owner initialization failed");
        require(app.value() == 0, "Transparent deploy: value initialization failed");
        require(
            keccak256(bytes(app.version())) == keccak256(bytes("TransparentProxyDemoLogicV1")),
            "Transparent deploy: version initialization failed"
        );
        require(proxyAdmin.owner() == proxyAdminOwner, "Transparent deploy: ProxyAdmin owner mismatch");

        vm.stopBroadcast();

        // 从代理槽位读取真实 admin，避免只依赖脚本内存中的 proxyAdmin 变量。
        address storedAdmin = address(uint160(uint256(vm.load(address(proxy), ERC1967_ADMIN_SLOT))));

        console2.log("logic:", address(logic));
        console2.log("proxy:", address(proxy));
        console2.log("owner:", owner);
        console2.log("proxyAdmin:", address(proxyAdmin));
        console2.log("proxyAdminOwner:", proxyAdminOwner);
        console2.log("version:", app.version());
        console2.log("stored admin:", storedAdmin);
    }
}
