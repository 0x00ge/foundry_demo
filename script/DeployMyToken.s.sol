// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol"; // Foundry 标准脚本库，提供 vm 工具和 console
import "../src/MyTokenContractV1.sol"; // 待部署的代币逻辑合约
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol"; // 透明代理合约
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol"; // 代理管理员合约

/**
 * @title DeployMyToken
 * @notice 使用 Foundry 脚本部署 MyTokenContractV1 及其透明代理的部署脚本
 * @dev 部署流程：
 *      1. 从环境变量读取 owner、admin 及五个资金池地址
 *      2. 部署逻辑合约 (MyTokenContractV1)
 *      3. 部署 ProxyAdmin 合约
 *      4. 编码 initialize 调用数据
 *      5. 部署 TransparentUpgradeableProxy 代理，并传入逻辑地址、ProxyAdmin 地址和初始化数据
 *      6. （可选）将 ProxyAdmin 的所有权转移给 owner
 *      7. 通过代理调用 setPoolAddressByOwner 配置资金池地址
 *      8. 输出所有部署地址
 * @dev 环境变量设置示例（使用前 export）：
 *      export OWNER_ADDR=0x... ADMIN_ADDR=0x... MINING_POOL=0x... ...
 *      或者使用 .env 文件配合 `source .env` 加载
 */
contract DeployMyToken is Script {
    bytes32 internal constant ERC1967_ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    /**
     * @notice Foundry 脚本入口函数
     * @dev 执行前需设置必要的环境变量，否则 vm.envAddress 会报错
     */
    function run() external {
        //  1. 从环境变量读取参数
        // vm.envAddress 会从当前环境变量中读取对应名称的十六进制地址字符串
        address owner = vm.envAddress("OWNER_ADDR"); // 合约的 Owner（建议为多签钱包地址）
        address admin = vm.envAddress("ADMIN_ADDR"); // 业务管理员（执行分配操作）

        // 五个资金池地址（必须为非零地址）
        address miningPool = vm.envAddress("MINING_POOL");
        address directSalePool = vm.envAddress("DIRECT_SALE_POOL");
        address investorSalePool = vm.envAddress("INVESTOR_SALE_POOL");
        address ecosystemPool = vm.envAddress("ECOSYSTEM_POOL");
        address foundationPool = vm.envAddress("FOUNDATION_POOL");

        // 开始广播交易（即真实发送交易，若在分叉或模拟模式下则不会真正广播）
        vm.startBroadcast();

        // MyTokenContractV1 是升级逻辑的实现，不包含任何代理存储。
        // 它的构造函数中调用了 _disableInitializers()，确保不会被直接初始化。
        MyTokenContractV1 logic = new MyTokenContractV1();

        // 使用 abi.encodeWithSelector 生成 calldata，包含函数选择器和参数。
        // 这样在部署代理时，代理构造函数会执行 delegatecall 到逻辑合约的 initialize 函数。
        bytes memory initData = abi.encodeWithSelector(MyTokenContractV1.initialize.selector, owner, admin);

        // TransparentUpgradeableProxy 的构造函数参数（OpenZeppelin v5）：
        //   - _logic: 逻辑合约地址
        //   - initialOwner: 代理内部 ProxyAdmin 的 owner
        //   - _data: 初始化调用数据（会立即执行 delegatecall）
        // 部署完成后，代理合约将存储逻辑地址、管理员地址以及所有业务状态。
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(logic), owner, initData);

        // OpenZeppelin v5 的透明代理会在构造函数中自动部署 ProxyAdmin。
        address proxyAdminAddress = address(uint160(uint256(vm.load(address(proxy), ERC1967_ADMIN_SLOT))));
        ProxyAdmin proxyAdmin = ProxyAdmin(proxyAdminAddress);

        // 将代理地址转换为 MyTokenContractV1 接口，以便调用其业务函数。
        MyTokenContractV1 token = MyTokenContractV1(address(proxy));

        // 构建资金池结构体，包含从环境变量读取的五个地址。
        MyTokenContractV1.PoolConfig memory pool = MyTokenContractV1.PoolConfig({
            miningPool: miningPool,
            directSalePool: directSalePool,
            investorSalePool: investorSalePool,
            ecosystemPool: ecosystemPool,
            foundationPool: foundationPool
        });

        // 调用 setPoolAddressByOwner，此函数有 onlyOwner 修饰器。
        // 由于当前 msg.sender 是部署者，而部署者就是 owner（我们未转移所有权），
        // 所以部署者有权限调用。如果之前转移了 owner，则需要确保部署者是 owner 才能调用。
        // 故此处应保证当前调用者有权限，或者通过 prank 模拟 owner。
        // 因为部署者就是初始 owner（由 initialize 设置），所以可以直接调用。
        token.setPoolAddressByOwner(pool);

        // 停止广播
        vm.stopBroadcast();

        //  8. 输出部署信息
        console.log("Logic deployed at:", address(logic));
        console.log("ProxyAdmin deployed at:", address(proxyAdmin));
        console.log("Proxy deployed at:", address(proxy));
        console.log("Token address (proxy):", address(token));

        // 额外输出提示信息，方便后续操作
        console.log("----------------------------------------------------------------");
        console.log("Deployment completed. Please record the following addresses:");
        console.log("Token (proxy) address: ", address(token));
        console.log("ProxyAdmin address:    ", address(proxyAdmin));
        console.log("Logic implementation:  ", address(logic));
        console.log("Owner address:         ", owner);
        console.log("Admin address:         ", admin);
        console.log("----------------------------------------------------------------");
    }
}
