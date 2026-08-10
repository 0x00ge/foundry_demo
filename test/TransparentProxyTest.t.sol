// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/TransparentProxyDemoLogic.sol";
import "../src/TransparentProxyDemoLogicV2.sol";
import {
    ITransparentUpgradeableProxy,
    TransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

/**
 * @title TransparentProxyTest
 * @notice OpenZeppelin 透明代理生产级最小测试集。
 * @dev
 * 测试重点不是“业务逻辑多复杂”，而是把透明代理最核心的行为钉牢：
 * - 初始化是否正确写入代理存储
 * - 普通用户是否会被正确转发到实现合约
 * - ProxyAdmin 是否是代理管理员，owner 是否可以管理 ProxyAdmin
 * - 升级后逻辑是否切换成功，且旧状态仍然保留
 */
contract TransparentProxyTest is Test {
    bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    bytes32 internal constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    address internal owner;
    address internal otherUser;

    TransparentProxyDemoLogic internal logicV1;
    TransparentUpgradeableProxy internal proxy;
    ProxyAdmin internal proxyAdmin;
    TransparentProxyDemoLogic internal app;

    function setUp() public {
        owner = address(0xB0B);
        otherUser = address(0xC0C);

        logicV1 = new TransparentProxyDemoLogic();

        bytes memory initData = abi.encodeWithSelector(TransparentProxyDemoLogic.initialize.selector, owner, uint256(7));

        proxy = new TransparentUpgradeableProxy(address(logicV1), owner, initData);
        proxyAdmin = ProxyAdmin(address(uint160(uint256(vm.load(address(proxy), ADMIN_SLOT)))));
        app = TransparentProxyDemoLogic(address(proxy));
    }

    /**
     * @notice 检查代理初始化后的存储是否正确。
     * @dev 这里直接读 EIP-1967 槽位，最直观，也能避免跟实现合约函数名冲突。
     */
    function test_ProxyStoresImplementationAndAdmin() public {
        address storedImplementation = address(uint160(uint256(vm.load(address(proxy), IMPLEMENTATION_SLOT))));
        address storedAdmin = address(uint160(uint256(vm.load(address(proxy), ADMIN_SLOT))));

        assertEq(storedImplementation, address(logicV1));
        assertEq(storedAdmin, address(proxyAdmin));
        assertEq(proxyAdmin.owner(), owner);
    }

    /**
     * @notice 初始化参数应该透过代理写入实现状态。
     * @dev owner/value 都应该落在代理存储中，而不是逻辑合约自身。
     */
    function test_InitializeThroughProxy() public {
        assertEq(app.owner(), owner);
        assertEq(app.value(), 7);
    }

    /**
     * @notice 实现合约自身不能被独立初始化。
     */
    function test_DirectImplementationInitializeReverts() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        logicV1.initialize(owner, 99);
    }

    /**
     * @notice 新版本实现合约自身也不能被独立初始化。
     */
    function test_DirectV2ImplementationInitializeReverts() public {
        TransparentProxyDemoLogicV2 logicV2 = new TransparentProxyDemoLogicV2();

        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        logicV2.initialize(owner, 99);
    }

    /**
     * @notice 代理地址只能初始化一次。
     */
    function test_ProxyCannotInitializeTwice() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        app.initialize(owner, 99);
    }

    /**
     * @notice 普通用户可以正常走 delegatecall，业务状态会写回代理。
     */
    function test_UserCanCallImplementationThroughProxy() public {
        vm.prank(owner);
        app.setValue(88);

        assertEq(app.value(), 88);
    }

    /**
     * @notice 透明代理的真实 admin 是 ProxyAdmin 合约，它不能直接走普通业务函数。
     * @dev 这是透明代理最重要的行为之一。
     */
    function test_AdminCannotFallbackToImplementation() public {
        vm.prank(address(proxyAdmin));
        vm.expectRevert(TransparentUpgradeableProxy.ProxyDeniedAdminAccess.selector);
        app.setValue(99);
    }

    /**
     * @notice 非 owner 调用实现合约自身的权限函数仍然会被实现合约拒绝。
     */
    function test_ImplementationAccessControlStillWorks() public {
        vm.prank(otherUser);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", otherUser));
        app.add(5);
    }

    /**
     * @notice 升级到新实现后，代理地址不变，但能力切换到新逻辑。
     */
    function test_UpgradeImplementationKeepsState() public {
        vm.prank(owner);
        app.setValue(21);

        TransparentProxyDemoLogicV2 logicV2 = new TransparentProxyDemoLogicV2();

        vm.prank(owner);
        proxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(address(proxy)), address(logicV2), "");

        TransparentProxyDemoLogicV2 upgradedApp = TransparentProxyDemoLogicV2(address(proxy));
        assertEq(upgradedApp.value(), 21);
        assertEq(upgradedApp.version(), 2);
        assertEq(upgradedApp.owner(), owner);
    }

    /**
     * @notice 非 ProxyAdmin owner 不能升级代理。
     */
    function test_RevertIfNonProxyAdminOwnerUpgrades() public {
        TransparentProxyDemoLogicV2 logicV2 = new TransparentProxyDemoLogicV2();

        vm.prank(otherUser);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", otherUser));
        proxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(address(proxy)), address(logicV2), "");
    }

    /**
     * @notice 透明代理的管理权通过 ProxyAdmin owner 转移。
     */
    function test_ProxyAdminOwnershipCanTransfer() public {
        address newOwner = address(0xD00D);

        vm.prank(owner);
        proxyAdmin.transferOwnership(newOwner);

        assertEq(proxyAdmin.owner(), newOwner);
    }
}
