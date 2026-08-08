// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MyTokenContract.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract MyTokenContractTest is Test {
    MyTokenContract public token;
    ProxyAdmin public proxyAdmin;
    address public owner;
    address public admin;
    address public user1;
    address public user2;
    address public miningPool;
    address public directSalePool;
    address public investorSalePool;
    address public ecosystemPool;
    address public foundationPool;

    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10 ** 6; // 1e15

    function setUp() public {
        // 创建测试账户
        owner = address(0x1001);
        admin = address(0x1002);
        user1 = address(0x2001);
        user2 = address(0x2002);
        miningPool = address(0x3001);
        directSalePool = address(0x3002);
        investorSalePool = address(0x3003);
        ecosystemPool = address(0x3004);
        foundationPool = address(0x3005);

        // 部署逻辑合约
        MyTokenContract logic = new MyTokenContract();

        // 部署 ProxyAdmin
        proxyAdmin = new ProxyAdmin();

        // 编码初始化数据
        bytes memory initData = abi.encodeWithSelector(
            MyTokenContract.initialize.selector,
            owner,
            admin
        );

        // 部署透明代理
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(logic),
            address(proxyAdmin),
            initData
        );

        token = MyTokenContract(address(proxy));

        // 如果 ProxyAdmin 的 owner 不是测试账户（默认是测试合约），需要转移
        // 在测试中，测试合约是部署者，是 ProxyAdmin 的 owner，可以直接调用
    }

    // ---------- 辅助函数 ----------
    function _setPoolAddresses() internal {
        MyTokenContract.MyTokenContractPool memory pool = MyTokenContract.MyTokenContractPool({
            miningPool: miningPool,
            directSalePool: directSalePool,
            investorSalePool: investorSalePool,
            ecosystemPool: ecosystemPool,
            foundationPool: foundationPool
        });
        vm.prank(owner);
        token.setPoolAddressByOwner(pool);
    }

    // ---------- 测试 ----------

    function test_Initialization() public {
        assertEq(token.name(), "NAME_OHANA");
        assertEq(token.symbol(), "SYMBOL_OHANA");
        assertEq(token.decimals(), 6);
        assertEq(token.owner(), owner);
        assertEq(token.admin(), admin);
        assertEq(token.isAllocation(), false);
        assertEq(token.totalSupply(), 0);
    }

    function test_SetAdminByOwner() public {
        address newAdmin = address(0x999);
        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit SetAdmin(newAdmin, admin);
        token.setAdminByOwner(newAdmin);
        assertEq(token.admin(), newAdmin);
    }

    function test_SetAdminByOwner_RevertNonOwner() public {
        vm.prank(admin);
        vm.expectRevert("Ownable: caller is not the owner");
        token.setAdminByOwner(address(0x999));
    }

    function test_SetPoolAddresses() public {
        MyTokenContract.MyTokenContractPool memory pool = MyTokenContract.MyTokenContractPool({
            miningPool: miningPool,
            directSalePool: directSalePool,
            investorSalePool: investorSalePool,
            ecosystemPool: ecosystemPool,
            foundationPool: foundationPool
        });
        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit SetPool(pool);
        token.setPoolAddressByOwner(pool);

        MyTokenContract.MyTokenContractPool memory stored = token.MyTokenContractPool();
        assertEq(stored.miningPool, miningPool);
        assertEq(stored.directSalePool, directSalePool);
        assertEq(stored.investorSalePool, investorSalePool);
        assertEq(stored.ecosystemPool, ecosystemPool);
        assertEq(stored.foundationPool, foundationPool);
    }

    function test_SetPoolAddresses_RevertZeroAddress() public {
        MyTokenContract.MyTokenContractPool memory pool = MyTokenContract.MyTokenContractPool({
            miningPool: address(0),
            directSalePool: directSalePool,
            investorSalePool: investorSalePool,
            ecosystemPool: ecosystemPool,
            foundationPool: foundationPool
        });
        vm.prank(owner);
        vm.expectRevert("MyTokenContract _beforeSetPool: Missing MiningPool address");
        token.setPoolAddressByOwner(pool);
    }

    function test_SetPoolAddresses_RevertNonOwner() public {
        MyTokenContract.MyTokenContractPool memory pool = MyTokenContract.MyTokenContractPool({
            miningPool: miningPool,
            directSalePool: directSalePool,
            investorSalePool: investorSalePool,
            ecosystemPool: ecosystemPool,
            foundationPool: foundationPool
        });
        vm.prank(admin);
        vm.expectRevert("Ownable: caller is not the owner");
        token.setPoolAddressByOwner(pool);
    }

    function test_AllocateTokens() public {
        _setPoolAddresses();

        vm.prank(admin);
        token.setPoolTokenByAdmin();

        assertEq(token.totalSupply(), MAX_SUPPLY);
        assertEq(token.isAllocation(), true);

        // 检查各池余额
        assertEq(token.balanceOf(miningPool), (MAX_SUPPLY * 3) / 10);
        assertEq(token.balanceOf(directSalePool), (MAX_SUPPLY * 2) / 10);
        assertEq(token.balanceOf(investorSalePool), MAX_SUPPLY / 10);
        assertEq(token.balanceOf(ecosystemPool), MAX_SUPPLY / 10);
        assertEq(token.balanceOf(foundationPool), (MAX_SUPPLY * 3) / 10);
    }

    function test_Allocate_RevertIfAlreadyAllocated() public {
        _setPoolAddresses();
        vm.prank(admin);
        token.setPoolTokenByAdmin();

        vm.prank(admin);
        vm.expectRevert("MyTokenContract _beforePoolAllocation : OHANA is already allocate");
        token.setPoolTokenByAdmin();
    }

    function test_Allocate_RevertIfNotAdmin() public {
        _setPoolAddresses();
        vm.prank(user1);
        vm.expectRevert("MyTokenContract onlyAdmin : only admin can call this function");
        token.setPoolTokenByAdmin();
    }

    function test_Allocate_RevertIfPoolNotSet() public {
        // 不调用 _setPoolAddresses，直接分配
        vm.prank(admin);
        // 预期会 revert，因为 _mint 到零地址（结构体默认全零）
        vm.expectRevert(); // 因为 `_mint` 到 address(0) 会触发 ERC20 的 assert
        token.setPoolTokenByAdmin();
    }

    function test_Transfers() public {
        _setPoolAddresses();
        vm.prank(admin);
        token.setPoolTokenByAdmin();

        uint256 amount = 100 * 10 ** 6; // 100 枚
        vm.prank(miningPool);
        token.transfer(user1, amount);
        assertEq(token.balanceOf(user1), amount);
    }

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

    // ---------- 事件定义（用于测试） ----------
    event SetAdmin(address indexed _newAddress, address _oldAddress);
    event SetPool(MyTokenContract.MyTokenContractPool indexed _MyTokenContractPool);
}