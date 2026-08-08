// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {MyTokenContract} from "../src/MyTokenContract.sol";

contract MyTokenIsERC20Test is Test {
    MyTokenContract public token;
    MyTokenContract public implementation;

    address public owner = makeAddr("owner");
    address public manager = makeAddr("manager");
    address public other = makeAddr("other");

    address public miningPool = makeAddr("miningPool");
    address public directSalePool = makeAddr("directSalePool");
    address public investorSalePool = makeAddr("investorSalePool");
    address public ecosystemPool = makeAddr("ecosystemPool");
    address public foundationPool = makeAddr("foundationPool");

    uint256 public constant MAX_TOTAL_SUPPLY = 1_000_000_000 * 10 ** 6;

    event SetManager(address indexed _newAddress, address _oldAddress);
    event SetPoolAddress(MyTokenContract.MyTokenContractPool indexed _myTokenIsERC20Pool);

    function setUp() public {
        implementation = new MyTokenContract();
        bytes memory initData = abi.encodeCall(MyTokenContract.initialize, (owner, manager));
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        token = MyTokenContract(address(proxy));
    }

    // =============================================================
    //                        initialize
    // =============================================================

    function test_Initialize_SetsStateCorrectly() public view {
        assertEq(token.owner(), owner);
        assertEq(token.manager(), manager);
        assertEq(token.name(), "OHANATOKEN");
        assertEq(token.symbol(), "OHANA");
        assertEq(token.decimals(), 6);
        assertEq(token.isAllocation(), false);
        assertEq(token.totalSupply(), 0);
    }

    function test_Initialize_RevertsWhenOwnerIsZero() public {
        MyTokenContract impl = new MyTokenContract();
        bytes memory initData = abi.encodeCall(MyTokenContract.initialize, (address(0), manager));

        vm.expectRevert("MyTokenContract initialize : _owner can't be zero address");
        new ERC1967Proxy(address(impl), initData);
    }

    function test_Initialize_RevertsWhenCalledTwice() public {
        vm.expectRevert();
        token.initialize(owner, manager);
    }

    function test_Implementation_CannotBeInitialized() public {
        // 实现合约构造函数调用了 _disableInitializers()
        vm.expectRevert();
        implementation.initialize(owner, manager);
    }

    // =============================================================
    //                        setManager
    // =============================================================

    function test_SetManager_Success() public {
        address newManager = makeAddr("newManager");

        vm.expectEmit(true, false, false, true);
        emit SetManager(newManager, manager);

        vm.prank(owner);
        token.setManagerByOwner(newManager);

        assertEq(token.manager(), newManager);
    }

    function test_SetManager_RevertsWhenCallerIsNotOwner() public {
        vm.prank(other);
        vm.expectRevert();
        token.setManagerByOwner(other);
    }

    function test_SetManager_AllowsZeroAddress() public {
        // 合约当前允许设为零地址；仅验证行为与文档一致
        vm.prank(owner);
        token.setManagerByOwner(address(0));
        assertEq(token.manager(), address(0));
    }

    // =============================================================
    //                      setPoolAddress
    // =============================================================

    function test_SetPoolAddress_Success() public {
        MyTokenContract.MyTokenContractPool memory pools = _validPools();

        vm.prank(owner);
        token.setPoolAddressByOwner(pools);

        (
            address mining,
            address directSale,
            address investorSale,
            address ecosystem,
            address foundation
        ) = token.myTokenIsERC20Pool();

        assertEq(mining, miningPool);
        assertEq(directSale, directSalePool);
        assertEq(investorSale, investorSalePool);
        assertEq(ecosystem, ecosystemPool);
        assertEq(foundation, foundationPool);
    }

    function test_SetPoolAddress_CanUpdateBeforeAllocation() public {
        vm.startPrank(owner);
        token.setPoolAddressByOwner(_validPools());

        address newMining = makeAddr("newMining");
        MyTokenContract.MyTokenContractPool memory updated = MyTokenContract.MyTokenContractPool({
            miningPool: newMining,
            directSalePool: directSalePool,
            investorSalePool: investorSalePool,
            ecosystemPool: ecosystemPool,
            foundationPool: foundationPool
        });
        token.setPoolAddressByOwner(updated);
        vm.stopPrank();

        (address mining,,,,) = token.myTokenIsERC20Pool();
        assertEq(mining, newMining);
    }

    function test_SetPoolAddress_RevertsWhenCallerIsNotOwner() public {
        vm.prank(other);
        vm.expectRevert();
        token.setPoolAddressByOwner(_validPools());
    }

    function test_SetPoolAddress_RevertsWhenMiningPoolIsZero() public {
        MyTokenContract.MyTokenContractPool memory pools = _validPools();
        pools.miningPool = address(0);

        vm.prank(owner);
        vm.expectRevert("MyTokenContract _beforePoolAddress: Missing MiningPool address");
        token.setPoolAddressByOwner(pools);
    }

    function test_SetPoolAddress_RevertsWhenDirectSalePoolIsZero() public {
        MyTokenContract.MyTokenContractPool memory pools = _validPools();
        pools.directSalePool = address(0);

        vm.prank(owner);
        vm.expectRevert("MyTokenContract _beforePoolAddress: Missing DirectSalePool address");
        token.setPoolAddressByOwner(pools);
    }

    function test_SetPoolAddress_RevertsWhenInvestorSalePoolIsZero() public {
        MyTokenContract.MyTokenContractPool memory pools = _validPools();
        pools.investorSalePool = address(0);

        vm.prank(owner);
        vm.expectRevert("MyTokenContract _beforePoolAddress: Missing InvestorSalePool address");
        token.setPoolAddressByOwner(pools);
    }

    function test_SetPoolAddress_RevertsWhenEcosystemPoolIsZero() public {
        MyTokenContract.MyTokenContractPool memory pools = _validPools();
        pools.ecosystemPool = address(0);

        vm.prank(owner);
        vm.expectRevert("MyTokenContract _beforePoolAddress: Missing EcosystemPool address");
        token.setPoolAddressByOwner(pools);
    }

    function test_SetPoolAddress_RevertsWhenFoundationPoolIsZero() public {
        MyTokenContract.MyTokenContractPool memory pools = _validPools();
        pools.foundationPool = address(0);

        vm.prank(owner);
        vm.expectRevert("MyTokenContract _beforePoolAddress: Missing FoundationPool address");
        token.setPoolAddressByOwner(pools);
    }

    function test_SetPoolAddress_RevertsAfterAllocation() public {
        _configureAndAllocate();

        vm.prank(owner);
        vm.expectRevert("MyTokenContract _beforePoolAllocation : OHANA is already allocate");
        token.setPoolAddressByOwner(_validPools());
    }

    // =============================================================
    //                       poolAllocate
    // =============================================================

    function test_PoolAllocate_MintsCorrectAmounts() public {
        _configureAndAllocate();

        uint256 expectedMining = (MAX_TOTAL_SUPPLY * 3) / 10; // 30%
        uint256 expectedDirectSale = (MAX_TOTAL_SUPPLY * 2) / 10; // 20%
        uint256 expectedInvestor = MAX_TOTAL_SUPPLY / 10; // 10%
        uint256 expectedEcosystem = MAX_TOTAL_SUPPLY / 10; // 10%
        uint256 expectedFoundation = (MAX_TOTAL_SUPPLY * 3) / 10; // 30%

        assertEq(token.balanceOf(miningPool), expectedMining);
        assertEq(token.balanceOf(directSalePool), expectedDirectSale);
        assertEq(token.balanceOf(investorSalePool), expectedInvestor);
        assertEq(token.balanceOf(ecosystemPool), expectedEcosystem);
        assertEq(token.balanceOf(foundationPool), expectedFoundation);

        assertEq(token.totalSupply(), MAX_TOTAL_SUPPLY);
        assertTrue(token.isAllocation());
    }

    function test_PoolAllocate_PercentagesSumTo100() public {
        _configureAndAllocate();

        uint256 sum = token.balanceOf(miningPool) + token.balanceOf(directSalePool)
            + token.balanceOf(investorSalePool) + token.balanceOf(ecosystemPool)
            + token.balanceOf(foundationPool);

        assertEq(sum, MAX_TOTAL_SUPPLY);
        assertEq(sum, token.totalSupply());
    }

    function test_PoolAllocate_RevertsWhenCallerIsNotManager() public {
        vm.prank(owner);
        token.setPoolAddressByOwner(_validPools());

        vm.prank(other);
        vm.expectRevert("MyTokenIsERC20 onlyManager : only manager can call this function");
        token.setPoolAllocateByManager();
    }

    function test_PoolAllocate_RevertsWhenOwnerCalls() public {
        vm.prank(owner);
        token.setPoolAddressByOwner(_validPools());

        // owner 也不能直接分配，必须是 manager
        vm.prank(owner);
        vm.expectRevert("MyTokenIsERC20 onlyManager : only manager can call this function");
        token.setPoolAllocateByManager();
    }

    function test_PoolAllocate_RevertsWhenCalledTwice() public {
        _configureAndAllocate();

        vm.prank(manager);
        vm.expectRevert("MyTokenIsERC20 _beforePoolAllocation : OHANA is already allocate");
        token.setPoolAllocateByManager();
    }

    function test_PoolAllocate_RevertsWhenPoolsNotSet() public {
        // 未 setPoolAddress 时池地址为 0，_mint 到零地址会回滚
        vm.prank(manager);
        vm.expectRevert();
        token.setPoolAllocateByManager();
    }

    // =============================================================
    //                     view / burn helpers
    // =============================================================

    function test_TokenBalance_MatchesBalanceOf() public {
        _configureAndAllocate();

        assertEq(token.tokenBalance(miningPool), token.balanceOf(miningPool));
        assertEq(token.tokenBalance(other), 0);
    }

    function test_Decimals_IsSix() public view {
        assertEq(token.decimals(), 6);
    }

    function test_Burn_WorksAfterAllocation() public {
        _configureAndAllocate();

        uint256 burnAmount = 1_000 * 10 ** 6;
        uint256 beforeBal = token.balanceOf(miningPool);
        uint256 beforeSupply = token.totalSupply();

        vm.prank(miningPool);
        token.burn(burnAmount);

        assertEq(token.balanceOf(miningPool), beforeBal - burnAmount);
        assertEq(token.totalSupply(), beforeSupply - burnAmount);
    }

    function test_Transfer_WorksAfterAllocation() public {
        _configureAndAllocate();

        uint256 amount = 100 * 10 ** 6;
        vm.prank(miningPool);
        assertTrue(token.transfer(other, amount));

        assertEq(token.balanceOf(other), amount);
        assertEq(token.tokenBalance(other), amount);
    }

    // =============================================================
    //                         helpers
    // =============================================================

    function _validPools() internal view returns (MyTokenContract.MyTokenContractPool memory) {
        return MyTokenContract.MyTokenContractPool({
            miningPool: miningPool,
            directSalePool: directSalePool,
            investorSalePool: investorSalePool,
            ecosystemPool: ecosystemPool,
            foundationPool: foundationPool
        });
    }

    function _configureAndAllocate() internal {
        vm.prank(owner);
        token.setPoolAddressByOwner(_validPools());

        vm.prank(manager);
        token.setPoolAllocateByManager();
    }
}
