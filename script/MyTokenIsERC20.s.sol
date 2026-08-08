// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/**
 * @title MyTokenIsERC20Script
 * @notice MyTokenIsERC20 可升级代理部署脚本（Transparent Proxy 模式）
 * @dev
 *  部署结构：
 *   - Implementation：逻辑合约（MyTokenIsERC20），禁止直接 initialize
 *   - Proxy：TransparentUpgradeableProxy，对外暴露的业务地址
 *   - ProxyAdmin：由 Proxy 构造时自动创建，负责后续 upgrade
 *
 *  初始化：
 *   - 在 Proxy 构造时通过 _data 调用 initialize(owner, manager)
 *   - owner 设为部署者地址（由 PRIVATE_KEY 推导）
 *   - manager 从环境变量 MANAGER_ADDRESS 读取
 *
 *  部署后建议调用顺序（不在本脚本内执行）：
 *   1. owner 调用 setPoolAddress 配置五个资金池
 *   2. manager 调用 poolAllocate 按比例一次性铸币分配
 *
 *  环境变量：
 *   - PRIVATE_KEY：部署者私钥（同时作为 token owner 与 ProxyAdmin initialOwner）
 *   - MANAGER_ADDRESS：初始 manager 地址
 *
 *  运行示例：
 *   forge script ./script/MyTokenIsERC20.s.sol:MyTokenIsERC20Script \
 *     --rpc-url $RPC_URL \
 *     --private-key $PRIVATE_KEY \
 *     --broadcast \
 *     --verify \
 *     --etherscan-api-key $ETHERSCAN_API_KEY
 */

import "forge-std/Vm.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";

import {MyTokenContract} from "../src/MyTokenContract.sol";
import {console, Script} from "forge-std/Script.sol";

contract MyTokenIsERC20Script is Script {
    /// @notice 代理管理员；OZ v5 Transparent Proxy 构造时会自动 new ProxyAdmin(initialOwner)
    ProxyAdmin public myTokenProxyAdmin;

    /// @notice 对外使用的代币地址（实际指向 Proxy，业务调用打到此地址）
    MyTokenContract public myToken;

    /// @notice 实现合约地址（仅存逻辑，不应直接被用户调用 initialize）
    MyTokenContract public myTokenImplementation;

    /**
     * @notice 部署实现合约 + Transparent 代理，并完成 initialize
     * @dev
     *  1. 读取 PRIVATE_KEY / MANAGER_ADDRESS
     *  2. 部署 MyTokenIsERC20 实现合约（constructor 内 _disableInitializers）
     *  3. 编码 initialize(deployer, manager) 作为 Proxy 构造 _data
     *  4. 部署 TransparentUpgradeableProxy：
     *     - _logic = 实现合约
     *     - initialOwner = 部署者（将成为自动创建的 ProxyAdmin 的 owner）
     *     - _data = initialize 调用数据（部署时对实现合约 delegatecall 一次）
     *  5. 将 Proxy 地址强转为 MyTokenIsERC20，供后续业务交互
     *  6. 从 ERC1967 ADMIN_SLOT 读取自动创建的 ProxyAdmin 地址
     *  7. 打印三个关键地址，便于写入配置 / 后续 upgrade
     */
    function run() public {
        // ---------- 读取环境变量 ----------
        // 部署私钥；用于签名广播交易，也用于推导 owner 地址
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        // 初始 manager；仅 manager 可调用 poolAllocate
        address managerAddress = vm.envAddress("MANAGER_ADDRESS");

        // 由私钥推导部署者 EOA，作为 token owner 与 ProxyAdmin initialOwner
        address deployerAddress = vm.addr(deployerPrivateKey);

        // 开始广播：此后 new / 外部调用会真正上链
        vm.startBroadcast(deployerPrivateKey);

        // ---------- 1. 部署实现合约 ----------
        // 实现合约 constructor 会 _disableInitializers()，防止有人直接 initialize 实现合约
        myTokenImplementation = new MyTokenContract();

        // ---------- 2. 编码初始化数据 ----------
        // 使用 abi.encodeCall 保证函数签名与参数类型在编译期检查
        // initialize 参数：(owner, manager) —— owner 为部署者，manager 来自环境变量
        bytes memory initData = abi.encodeCall(
            MyTokenContract.initialize,
            (deployerAddress, managerAddress)
        );

        // ---------- 3. 部署 Transparent 可升级代理 ----------
        // OZ v5：构造函数签名 constructor(_logic, initialOwner, _data)
        //  - 内部会 new ProxyAdmin(initialOwner)，并将该 ProxyAdmin 写入 ADMIN_SLOT
        //  - _data 非空时，对 _logic 做一次 delegatecall，完成代理侧 initialize
        TransparentUpgradeableProxy proxyMyToken =
            new TransparentUpgradeableProxy(
                address(myTokenImplementation),
                deployerAddress,
                initData
            );

        // ---------- 4. 绑定业务接口 ----------
        // 业务侧始终与 Proxy 交互；Proxy 再 delegatecall 到当前 implementation
        myToken = MyTokenContract(address(proxyMyToken));

        // ---------- 5. 读取自动创建的 ProxyAdmin ----------
        // 后续 upgrade 需通过 ProxyAdmin.upgradeAndCall，而不是直接调 Proxy
        myTokenProxyAdmin = ProxyAdmin(getProxyAdminAddress(address(proxyMyToken)));

        // ---------- 6. 输出关键地址 ----------
        console.log("deploy proxyMyToken:", address(proxyMyToken));
        console.log("deploy myTokenImplementation:", address(myTokenImplementation));
        console.log("deploy myTokenProxyAdmin:", address(myTokenProxyAdmin));

        vm.stopBroadcast();
    }

    /**
     * @notice 从 ERC1967 标准 admin 槽位读取 ProxyAdmin 地址
     * @dev
     *  TransparentUpgradeableProxy 在构造时把 ProxyAdmin 写入 ERC1967Utils.ADMIN_SLOT。
     *  本函数通过 Foundry cheatcode vm.load 直接读 storage，避免依赖额外事件解析。
     *
     *  注意：这里重新取 Vm 接口是因为 internal view 上下文中，
     *  直接使用 Script 继承的 vm 在部分场景下不便；使用标准 cheatcode 地址即可。
     *
     * @param proxy TransparentUpgradeableProxy 地址
     * @return ProxyAdmin 合约地址（OZ v5 自动部署的那一个）
     */
    function getProxyAdminAddress(address proxy) internal view returns (address) {
        // Foundry Vm cheatcode 固定地址
        address CHEATCODE_ADDRESS = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D;
        Vm vm = Vm(CHEATCODE_ADDRESS);

        // ERC1967 admin 槽：bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1)
        bytes32 adminSlot = vm.load(proxy, ERC1967Utils.ADMIN_SLOT);
        // 槽内 32 字节右 20 字节为地址
        return address(uint160(uint256(adminSlot)));
    }
}
