// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/TransparentProxy.sol";
import "../src/TransparentProxyDemoLogic.sol";
import "../src/TransparentProxyDemoLogicV2.sol";

/**
 * @title TransparentProxyTest
 * @notice 最小透明代理测试集。
 * @dev
 * 测试重点不是“业务逻辑多复杂”，而是把透明代理最核心的行为钉牢：
 * - 初始化是否正确写入代理存储
 * - 普通用户是否会被正确转发到实现合约
 * - 管理员是否会被拦下，不能误走业务函数
 * - 升级后逻辑是否切换成功，且旧状态仍然保留
 */
contract TransparentProxyTest is Test {
    bytes32 internal constant IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    bytes32 internal constant ADMIN_SLOT =
        0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    address internal proxyAdmin;
    address internal owner;
    address internal otherUser;

    TransparentProxyDemoLogic internal logicV1;
    TransparentProxy internal proxy;
    TransparentProxyDemoLogic internal app;

    function setUp() public {
        proxyAdmin = address(0xA11CE);
        owner = address(0xB0B);
        otherUser = address(0xC0C);

        logicV1 = new TransparentProxyDemoLogic();

        bytes memory initData = abi.encodeWithSelector(
            TransparentProxyDemoLogic.initialize.selector,
            owner,
            uint256(7)
        );

        proxy = new TransparentProxy(address(logicV1), proxyAdmin, initData);
        app = TransparentProxyDemoLogic(address(proxy));
    }

    /**
     * @notice 检查代理初始化后的存储是否正确。
     * @dev 这里直接读 EIP-1967 槽位，最直观，也能避免跟实现合约函数名冲突。
     */
    function test_ProxyStoresImplementationAndAdmin() public {
        address storedImplementation = address(
            uint160(uint256(vm.load(address(proxy), IMPLEMENTATION_SLOT)))
        );
        address storedAdmin = address(uint160(uint256(vm.load(address(proxy), ADMIN_SLOT))));

        assertEq(storedImplementation, address(logicV1));
        assertEq(storedAdmin, proxyAdmin);
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
     * @notice 普通用户可以正常走 delegatecall，业务状态会写回代理。
     */
    function test_UserCanCallImplementationThroughProxy() public {
        vm.prank(owner);
        app.setValue(88);

        assertEq(app.value(), 88);
    }

    /**
     * @notice 管理员不允许直接走普通业务函数。
     * @dev 这是透明代理最重要的行为之一。
     */
    function test_AdminCannotFallbackToImplementation() public {
        vm.prank(proxyAdmin);
        vm.expectRevert(TransparentProxy.AdminCannotFallback.selector);
        app.setValue(99);
    }

    /**
     * @notice 非 owner 调用实现合约自身的权限函数仍然会被实现合约拒绝。
     */
    function test_ImplementationAccessControlStillWorks() public {
        vm.prank(otherUser);
        vm.expectRevert(TransparentProxyDemoLogic.NotOwner.selector);
        app.add(5);
    }

    /**
     * @notice 升级到新实现后，代理地址不变，但能力切换到新逻辑。
     */
    function test_UpgradeImplementationKeepsState() public {
        vm.prank(owner);
        app.setValue(21);

        TransparentProxyDemoLogicV2 logicV2 = new TransparentProxyDemoLogicV2();

        vm.prank(proxyAdmin);
        proxy.upgradeTo(address(logicV2));

        TransparentProxyDemoLogicV2 upgradedApp = TransparentProxyDemoLogicV2(address(proxy));
        assertEq(upgradedApp.value(), 21);
        assertEq(upgradedApp.version(), 2);
    }

    /**
     * @notice 管理员可以变更为新的地址。
     */
    function test_ChangeAdmin() public {
        address newAdmin = address(0xD00D);

        vm.prank(proxyAdmin);
        proxy.changeAdmin(newAdmin);

        address storedAdmin = address(uint160(uint256(vm.load(address(proxy), ADMIN_SLOT))));
        assertEq(storedAdmin, newAdmin);

        vm.prank(proxyAdmin);
        vm.expectRevert(TransparentProxy.NotAdmin.selector);
        proxy.changeAdmin(address(0xEEEE));
    }
}
