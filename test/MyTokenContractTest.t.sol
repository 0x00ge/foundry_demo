// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";               // Foundry 标准测试库，提供 vm、assert 等工具
import "../src/MyTokenContract.sol";       // 待测试的代币逻辑合约
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol"; // 透明代理合约
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";                 // 代理管理员合约

/**
 * @title MyTokenContractTest
 * @notice MyTokenContract 的 Foundry 单元测试套件
 * @dev 覆盖初始化、权限控制、资金池配置、代币分配及 ERC20 标准功能
 */
contract MyTokenContractTest is Test {
    MyTokenContract public token;           // 通过代理调用的代币合约实例（类型为 MyTokenContract）
    ProxyAdmin public proxyAdmin;           // ProxyAdmin 合约实例，用于管理代理升级

    bytes32 internal constant ERC1967_ADMIN_SLOT =
        0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    // 角色地址（均使用硬编码的测试地址，避免与真实账户混淆）
    address public owner;                   // 合约的 Owner（最高权限）
    address public admin;                   // 业务管理员（执行分配）
    address public user1;                   // 普通用户 1
    address public user2;                   // 普通用户 2
    address public miningPool;              // 挖矿池地址
    address public directSalePool;          // 直销池地址
    address public investorSalePool;        // 投资者销售池地址
    address public ecosystemPool;           // 生态建设池地址
    address public foundationPool;          // 基金会池地址

    // 最大总供应量常量（1e15 = 10 亿 * 10^6，与合约中定义一致）
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10 ** 6; // 1e15

    /**
     * @notice 在每个测试用例执行前运行，部署全新的合约环境
     * @dev 流程：
     *      1. 分配测试账户地址
     *      2. 部署逻辑合约（MyTokenContract）
     *      3. 部署 ProxyAdmin
     *      4. 编码 initialize 调用数据
     *      5. 部署透明代理（TransparentUpgradeableProxy），并传入初始化数据
     *      6. 将代理地址转换为 MyTokenContract 类型，方便后续调用
     */
    function setUp() public {
        // 1. 创建测试账户（使用固定地址，确保可预测性）
        owner = address(0x1001);
        admin = address(0x1002);
        user1 = address(0x2001);
        user2 = address(0x2002);
        miningPool = address(0x3001);
        directSalePool = address(0x3002);
        investorSalePool = address(0x3003);
        ecosystemPool = address(0x3004);
        foundationPool = address(0x3005);

        // 2. 部署逻辑合约（即实现合约，不含代理）
        MyTokenContract logic = new MyTokenContract();

        // 4. 编码 initialize 函数的调用数据，传入 owner 和 admin
        bytes memory initData = abi.encodeWithSelector(
            MyTokenContract.initialize.selector,
            owner,
            admin
        );

        // 5. 部署透明代理，将逻辑合约、ProxyAdmin owner 和初始化数据传入
        //    代理构造函数会执行 delegatecall 到逻辑合约的 initialize
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(logic),
            address(this),
            initData
        );

        proxyAdmin = ProxyAdmin(address(uint160(uint256(vm.load(address(proxy), ERC1967_ADMIN_SLOT)))));

        // 6. 将代理地址转换为 MyTokenContract 类型，方便调用业务函数
        token = MyTokenContract(address(proxy));

        // 注：在 Foundry 测试中，测试合约本身就是 ProxyAdmin owner，
        //     无需额外转移。若需要模拟多签钱包，可通过 vm.prank 模拟 owner 操作。
    }

    /**
     * @notice 内部辅助函数：以 owner 身份设置五个资金池地址
     * @dev 在需要分配代币的测试中预先调用，确保池地址有效
     */
    function _setPoolAddresses() internal {
        // 构建资金池结构体，填入之前分配的测试地址
        MyTokenContract.PoolConfig memory pool = MyTokenContract.PoolConfig({
            miningPool: miningPool,
            directSalePool: directSalePool,
            investorSalePool: investorSalePool,
            ecosystemPool: ecosystemPool,
            foundationPool: foundationPool
        });
        // 使用 vm.prank 模拟 owner 调用
        vm.prank(owner);
        token.setPoolAddressByOwner(pool);
    }

    /**
     * @notice 测试合约初始化是否正确
     * @dev 验证代币名称、符号、小数位数、owner、admin、isAllocation 和总供应量
     */
    function test_Initialization() public {
        // 代币元数据
        assertEq(token.name(), "NAME_OHANA");
        assertEq(token.symbol(), "SYMBOL_OHANA");
        assertEq(token.decimals(), 6);

        // 权限角色
        assertEq(token.owner(), owner);
        assertEq(token.admin(), admin);

        // 分配状态与总供应量
        assertEq(token.isAllocation(), false);
        assertEq(token.totalSupply(), 0);
    }

    /**
     * @notice 测试 owner 能够成功变更 admin 地址
     * @dev 验证新旧地址的变更，并检查事件是否正常发出
     */
    function test_SetAdminByOwner() public {
        address newAdmin = address(0x999);
        // 模拟 owner 调用 setAdminByOwner
        vm.prank(owner);
        // 预期触发 SetAdmin 事件（参数匹配）
        vm.expectEmit(true, false, false, false);
        emit SetAdmin(newAdmin, admin);
        token.setAdminByOwner(newAdmin);
        // 确认 admin 已更新
        assertEq(token.admin(), newAdmin);
    }

    /**
     * @notice 测试非 owner 调用 setAdminByOwner 会回滚
     * @dev 使用 admin 地址尝试调用，预期被 Ownable 拒绝
     */
    function test_SetAdminByOwner_RevertNonOwner() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", admin));
        token.setAdminByOwner(address(0x999));
    }

    /**
     * @notice 测试 owner 能够正确设置五个资金池地址
     * @dev 验证存储更新和事件触发
     */
    function test_SetPoolAddresses() public {
        MyTokenContract.PoolConfig memory pool = MyTokenContract.PoolConfig({
            miningPool: miningPool,
            directSalePool: directSalePool,
            investorSalePool: investorSalePool,
            ecosystemPool: ecosystemPool,
            foundationPool: foundationPool
        });
        vm.prank(owner);
        // 预期触发 SetPool 事件
        vm.expectEmit(true, false, false, false);
        emit SetPool(pool);
        token.setPoolAddressByOwner(pool);

        // 读取存储并逐项比对；public struct getter 对外返回 tuple。
        (
            address storedMiningPool,
            address storedDirectSalePool,
            address storedInvestorSalePool,
            address storedEcosystemPool,
            address storedFoundationPool
        ) = token.MyTokenContractPool();
        assertEq(storedMiningPool, miningPool);
        assertEq(storedDirectSalePool, directSalePool);
        assertEq(storedInvestorSalePool, investorSalePool);
        assertEq(storedEcosystemPool, ecosystemPool);
        assertEq(storedFoundationPool, foundationPool);
    }

    /**
     * @notice 测试设置零地址作为资金池会回滚
     * @dev 分别测试五个池，此处仅以 miningPool 为例
     */
    function test_SetPoolAddresses_RevertZeroAddress() public {
        MyTokenContract.PoolConfig memory pool = MyTokenContract.PoolConfig({
            miningPool: address(0),     // 故意设为零地址
            directSalePool: directSalePool,
            investorSalePool: investorSalePool,
            ecosystemPool: ecosystemPool,
            foundationPool: foundationPool
        });
        vm.prank(owner);
        // 预期回滚消息来自 _beforeSetPool 校验
        vm.expectRevert("MyTokenContract _beforeSetPool: Missing MiningPool address");
        token.setPoolAddressByOwner(pool);
    }

    /**
     * @notice 测试非 owner 调用 setPoolAddressByOwner 会回滚
     * @dev 使用 admin 地址尝试调用，预期被 Ownable 拒绝
     */
    function test_SetPoolAddresses_RevertNonOwner() public {
        MyTokenContract.PoolConfig memory pool = MyTokenContract.PoolConfig({
            miningPool: miningPool,
            directSalePool: directSalePool,
            investorSalePool: investorSalePool,
            ecosystemPool: ecosystemPool,
            foundationPool: foundationPool
        });
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", admin));
        token.setPoolAddressByOwner(pool);
    }

    /**
     * @notice 测试正常分配流程：配置池地址 -> admin 调用分配
     * @dev 验证总供应量变为 MAX_SUPPLY，各池余额符合比例，isAllocation 置为 true
     */
    function test_AllocateTokens() public {
        _setPoolAddresses(); // 先配置池地址

        // admin 调用分配函数
        vm.prank(admin);
        token.setPoolTokenByAdmin();

        // 验证总供应量
        assertEq(token.totalSupply(), MAX_SUPPLY);
        assertEq(token.isAllocation(), true);

        // 验证各池余额（分别计算期望值）
        assertEq(token.balanceOf(miningPool), (MAX_SUPPLY * 3) / 10);   // 30%
        assertEq(token.balanceOf(directSalePool), (MAX_SUPPLY * 2) / 10); // 20%
        assertEq(token.balanceOf(investorSalePool), MAX_SUPPLY / 10);     // 10%
        assertEq(token.balanceOf(ecosystemPool), MAX_SUPPLY / 10);        // 10%
        assertEq(token.balanceOf(foundationPool), (MAX_SUPPLY * 3) / 10); // 30%
    }

    /**
     * @notice 测试重复分配会被阻止（isAllocation 防重入）
     * @dev 第一次分配成功后，第二次调用预期回滚
     */
    function test_Allocate_RevertIfAlreadyAllocated() public {
        _setPoolAddresses();
        vm.prank(admin);
        token.setPoolTokenByAdmin(); // 第一次分配

        // 第二次分配应回滚
        vm.prank(admin);
        vm.expectRevert("MyTokenContract _beforePoolAllocation : OHANA is already allocate");
        token.setPoolTokenByAdmin();
    }

    /**
     * @notice 测试非 admin 调用分配会回滚
     * @dev 使用 user1 尝试调用，被 onlyAdmin 修饰器拒绝
     */
    function test_Allocate_RevertIfNotAdmin() public {
        _setPoolAddresses();
        vm.prank(user1);
        vm.expectRevert("MyTokenContract onlyAdmin : only admin can call this function");
        token.setPoolTokenByAdmin();
    }

    /**
     * @notice 测试未配置池地址时分配会回滚
     * @dev 因池地址结构体默认全为零，_mint 到零地址触发 ERC20 的断言（非 require）
     *      使用 vm.expectRevert() 不指定消息，捕获任何回滚
     */
    function test_Allocate_RevertIfPoolNotSet() public {
        // 注意：此处未调用 _setPoolAddresses，池地址均为 address(0)
        vm.prank(admin);
        // 预期由于 _mint 到零地址而回滚（ERC20 内部使用 assert，故不指定错误消息）
        vm.expectRevert();
        token.setPoolTokenByAdmin();
    }

    /**
     * @notice 测试代币转账功能
     * @dev 先完成分配，然后从挖矿池转账给 user1，验证余额变化
     */
    function test_Transfers() public {
        _setPoolAddresses();
        vm.prank(admin);
        token.setPoolTokenByAdmin();

        uint256 amount = 100 * 10 ** 6; // 100 枚（精度 6）
        vm.prank(miningPool);
        token.transfer(user1, amount);
        assertEq(token.balanceOf(user1), amount);
    }

    /**
     * @notice 测试代币销毁（burn）功能
     * @dev 挖矿池销毁部分代币，验证余额减少且总供应量相应减少
     */
    function test_Burn() public {
        _setPoolAddresses();
        vm.prank(admin);
        token.setPoolTokenByAdmin();

        uint256 burnAmount = 100 * 10 ** 6;
        uint256 balanceBefore = token.balanceOf(miningPool);
        vm.prank(miningPool);
        token.burn(burnAmount);
        assertEq(token.balanceOf(miningPool), balanceBefore - burnAmount);
        assertEq(token.totalSupply(), MAX_SUPPLY - burnAmount);
    }

    /**
     * @notice 测试授权（approve）和转账（transferFrom）流程
     * @dev 挖矿池授权给 user2，然后 user2 代为转账给 user1
     */
    function test_ApproveAndTransferFrom() public {
        _setPoolAddresses();
        vm.prank(admin);
        token.setPoolTokenByAdmin();

        uint256 amount = 50 * 10 ** 6;
        vm.prank(miningPool);
        token.approve(user2, amount);
        vm.prank(user2);
        token.transferFrom(miningPool, user1, amount);
        assertEq(token.balanceOf(user1), amount);
    }

    // ============================================================
    //                 事件定义（用于测试匹配）
    // ============================================================
    // 注意：这些事件在代币合约中已经定义，此处重复声明是为了在测试中使用 expectEmit 匹配。
    // 它们与实际事件签名必须完全一致（包括 indexed 参数）。

    /**
     * @dev 对应 MyTokenContract.SetAdmin 事件
     */
    event SetAdmin(address indexed _newAddress, address _oldAddress);

    /**
     * @dev 对应 MyTokenContract.SetPool 事件
     *      结构体作为 indexed 参数，事件签名中的 topic 是整个结构体的 keccak256 哈希
     */
    event SetPool(MyTokenContract.PoolConfig indexed _MyTokenContractPool);
}
