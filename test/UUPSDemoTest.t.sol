// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/UUPSDemoLogicV1.sol";
import "../src/UUPSDemoLogicV2.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title UUPSDemoTest
 * @notice UUPS 生产级最小测试集。
 * @dev
 * 测试同时验证代理上下文和实现合约上下文：
 * 1. ERC1967Proxy 部署后，initialize 是否写入代理存储
 * 2. 实现地址和代理地址是否分别受到初始化保护
 * 3. 普通业务调用和 owner 权限是否通过 delegatecall 正常工作
 * 4. owner 能否通过 UUPS 升级，并在同一笔交易里完成 V2 迁移
 * 5. onlyProxy、onlyOwner 和 proxiableUUID 防护是否生效
 */
contract UUPSDemoTest is Test {
    // EIP-1967 implementation 槽位：代理只从这里读取当前实现地址。
    bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    // UUPSUpgradeable 在直接调用实现合约或通过代理调用 proxiableUUID 时使用的上下文错误。
    bytes4 internal constant UUPS_UNAUTHORIZED_CALL_CONTEXT = bytes4(keccak256("UUPSUnauthorizedCallContext()"));

    // Initializable 在初始化版本不满足要求时抛出的错误。
    bytes4 internal constant INVALID_INITIALIZATION = bytes4(keccak256("InvalidInitialization()"));

    address internal owner;
    address internal otherUser;
    address internal mintTarget;

    UUPSDemoLogicV1 internal logicV1;
    ERC1967Proxy internal proxy;
    UUPSDemoLogicV1 internal app;

    function setUp() public {
        owner = address(0xB0B);
        otherUser = address(0xC0C);
        mintTarget = address(0xD0D);

        // logicV1 只存放代码；构造函数会禁用 logicV1 自身的 initialize。
        logicV1 = new UUPSDemoLogicV1();

        // 初始化 calldata 会在 ERC1967Proxy 构造期间 delegatecall 到 logicV1。
        bytes memory initData = abi.encodeWithSelector(UUPSDemoLogicV1.initialize.selector, owner);

        proxy = new ERC1967Proxy(address(logicV1), initData);
        // 后续所有业务调用都通过 proxy 地址进入实现合约。
        app = UUPSDemoLogicV1(address(proxy));
    }

    /**
     * @notice 检查代理初始化后的实现地址是否正确。
     */
    function test_ProxyStoresImplementation() public {
        address storedImplementation = address(uint160(uint256(vm.load(address(proxy), IMPLEMENTATION_SLOT))));

        assertEq(storedImplementation, address(logicV1));
    }

    /**
     * @notice 初始化参数应该写入代理存储。
     */
    function test_InitializeThroughProxy() public {
        assertEq(app.owner(), owner);
        assertEq(app.value(), 0);
        assertEq(app.version(), "UUPSDemoLogicV1");
        assertEq(app.name(), "UUPS Demo Token");
        assertEq(app.symbol(), "UDT");
        assertEq(app.decimals(), 18);
        assertEq(app.totalSupply(), 0);
    }

    /**
     * @notice 实现合约自身不能被独立初始化。
     */
    function test_DirectImplementationInitializeReverts() public {
        vm.expectRevert(INVALID_INITIALIZATION);
        logicV1.initialize(owner);
    }

    /**
     * @notice 新版本实现合约自身也不能被独立初始化。
     */
    function test_DirectV2ImplementationInitializeReverts() public {
        UUPSDemoLogicV2 logicV2 = new UUPSDemoLogicV2();

        vm.expectRevert(INVALID_INITIALIZATION);
        logicV2.initialize(owner);
    }

    /**
     * @notice 代理地址只能初始化一次。
     */
    function test_ProxyCannotInitializeTwice() public {
        vm.expectRevert(INVALID_INITIALIZATION);
        app.initialize(owner);
    }

    /**
     * @notice 普通业务调用应当被正常 delegatecall 到实现合约。
     */
    function test_UserCanCallImplementationThroughProxy() public {
        vm.prank(owner);
        app.setValue(88);

        assertEq(app.value(), 88);
    }

    /**
     * @notice owner 可以向指定目标地址铸造代币。
     */
    function test_OwnerCanMintToTarget() public {
        uint256 amount = 250 ether;

        vm.prank(owner);
        app.mint(mintTarget, amount);

        assertEq(app.balanceOf(mintTarget), amount);
        assertEq(app.totalSupply(), amount);
    }

    /**
     * @notice 非 owner 不能铸造代币。
     */
    function test_RevertIfNonOwnerMints() public {
        vm.prank(otherUser);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", otherUser));
        app.mint(mintTarget, 1 ether);
    }

    /**
     * @notice ERC20 不允许向零地址铸造。
     */
    function test_RevertIfMintTargetIsZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("ERC20InvalidReceiver(address)", address(0)));
        app.mint(address(0), 1 ether);
    }

    /**
     * @notice 非 owner 不允许调用 onlyOwner 业务函数。
     */
    function test_RevertIfNotOwner() public {
        vm.prank(otherUser);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", otherUser));
        app.add1();
    }

    /**
     * @notice owner 可以通过 UUPS 方式升级到 V2。
     */
    function test_UpgradeToV2KeepsState() public {
        vm.prank(owner);
        app.setValue(21);
        vm.prank(owner);
        app.mint(mintTarget, 10 ether);

        UUPSDemoLogicV2 logicV2 = new UUPSDemoLogicV2();

        vm.prank(owner);
        app.upgradeToAndCall(address(logicV2), "");

        UUPSDemoLogicV2 upgradedApp = UUPSDemoLogicV2(address(proxy));
        assertEq(upgradedApp.value(), 21);
        // 没有执行额外迁移函数，因此代理中已有的 V1 version 状态保持不变。
        assertEq(upgradedApp.version(), "UUPSDemoLogicV1");
        assertEq(upgradedApp.owner(), owner);
        assertEq(upgradedApp.name(), "UUPS Demo Token");
        assertEq(upgradedApp.symbol(), "UDT");
        assertEq(upgradedApp.balanceOf(mintTarget), 10 ether);
        assertEq(upgradedApp.totalSupply(), 10 ether);

        vm.prank(owner);
        upgradedApp.mint(mintTarget, 5 ether);
        assertEq(upgradedApp.balanceOf(mintTarget), 15 ether);
        assertEq(upgradedApp.totalSupply(), 15 ether);
    }

    /**
     * @notice 旧版代理升级后可通过 V2 的 reinitializer 补初始化 ERC20 元数据。
     */
    function test_V2CanInitializeTokenMetadataOnce() public {
        UUPSDemoLogicV2 logicV2 = new UUPSDemoLogicV2();

        vm.prank(owner);
        app.upgradeToAndCall(address(logicV2), "");

        UUPSDemoLogicV2 upgradedApp = UUPSDemoLogicV2(address(proxy));
        vm.prank(owner);
        upgradedApp.initializeToken();

        assertEq(upgradedApp.name(), "UUPS Demo Token");
        assertEq(upgradedApp.symbol(), "UDT");

        vm.prank(owner);
        vm.expectRevert(INVALID_INITIALIZATION);
        upgradedApp.initializeToken();
    }

    /**
     * @notice 升级必须同时切换 EIP-1967 implementation 槽位。
     * @dev 只验证代理返回新逻辑还不够，直接检查槽位可以确认代理确实完成了实现切换。
     */
    function test_UpgradeChangesImplementationSlot() public {
        UUPSDemoLogicV2 logicV2 = new UUPSDemoLogicV2();

        vm.prank(owner);
        app.upgradeToAndCall(address(logicV2), "");

        address storedImplementation = address(uint160(uint256(vm.load(address(proxy), IMPLEMENTATION_SLOT))));
        assertEq(storedImplementation, address(logicV2));
    }

    /**
     * @notice 非 owner 不能通过代理执行 UUPS 升级。
     */
    function test_RevertIfNonOwnerUpgrades() public {
        UUPSDemoLogicV2 logicV2 = new UUPSDemoLogicV2();

        vm.prank(otherUser);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", otherUser));
        app.upgradeToAndCall(address(logicV2), "");
    }

    /**
     * @notice 直接在实现合约上调用升级函数会被拦下。
     * @dev UUPSUpgradeable 的 onlyProxy 会拒绝这种调用。
     */
    function test_DirectImplementationUpgradeReverts() public {
        UUPSDemoLogicV2 logicV2 = new UUPSDemoLogicV2();

        vm.prank(owner);
        vm.expectRevert(UUPS_UNAUTHORIZED_CALL_CONTEXT);
        logicV1.upgradeToAndCall(address(logicV2), "");
    }

    /**
     * @notice 升级后 V2 的新增业务函数仍然受 owner 权限保护。
     */
    function test_V2BusinessFunctionsRequireOwner() public {
        UUPSDemoLogicV2 logicV2 = new UUPSDemoLogicV2();

        vm.prank(owner);
        app.upgradeToAndCall(address(logicV2), "");

        UUPSDemoLogicV2 upgradedApp = UUPSDemoLogicV2(address(proxy));
        vm.prank(otherUser);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", otherUser));
        upgradedApp.add1();

        vm.startPrank(owner);
        upgradedApp.add1();
        upgradedApp.add2();
        vm.stopPrank();
        assertEq(upgradedApp.value(), 3);
    }

    /**
     * @notice 不带迁移 calldata 的升级不会重置代理中已有的版本状态。
     */
    function test_UpgradeWithoutMigrationPreservesStoredVersion() public {
        UUPSDemoLogicV2 logicV2 = new UUPSDemoLogicV2();

        vm.prank(owner);
        app.upgradeToAndCall(address(logicV2), "");

        UUPSDemoLogicV2 upgradedApp = UUPSDemoLogicV2(address(proxy));
        assertEq(upgradedApp.version(), "UUPSDemoLogicV1");
    }

    /**
     * @notice 通过代理调用 proxiableUUID 会回滚。
     * @dev 这是 UUPS 里很重要的一条保护，防止把 proxy 误认成 implementation。
     */
    function test_ProxiableUUIDThroughProxyReverts() public {
        vm.expectRevert(UUPS_UNAUTHORIZED_CALL_CONTEXT);
        app.proxiableUUID();
    }
}
