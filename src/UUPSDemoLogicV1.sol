// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title UUPSDemoLogicV1
 * @notice 一个最小可用的 UUPS 实现合约（V1）。
 * @dev
 * UUPS 的特点是：
 * 1. 代理本体只负责转发，不单独放一个 ProxyAdmin。
 * 2. 升级逻辑写在实现合约里，由实现合约自己决定谁有权限升级。
 * 3. 真正升级时，调用的是实现合约暴露出来的 `upgradeToAndCall`。
 *
 * 这个 V1 只保留最少的业务状态：
 * - owner：业务管理员
 * - value：一个简单数值，方便验证代理存储是否正确
 */
contract UUPSDemoLogicV1 is OwnableUpgradeable, UUPSUpgradeable {

    uint256 public version;

    uint256 public value;

    /**
     * @notice 锁定实现合约自身的初始化状态。
     * @dev 代理拥有独立存储，因此仍可通过代理执行 initialize。
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice 通过代理执行的初始化函数，只能调用一次。
     * @param initialOwner 初始 owner。
     * @param initialValue 初始数值。
     * @dev
     * 实现合约自身已在构造时禁用初始化。由于是 UUPS + ERC1967Proxy 组合，
     * 真正执行 initialize 的地方是代理地址。
     * 初始化完成后，状态会写进代理自己的存储，而不是写进逻辑合约地址。
     */
    function initialize(address initialOwner) public initializer {
        __Ownable_init(initialOwner);
        version = 1;
    }

    /**
     * @notice 设置版本。
     * @dev 内部钩子函数，用于在升级到新实现合约时更新版本号。
     */
    function _setVersion() internal virtual {
    }

    /**
     * @notice 设置数值。
     * @dev 只有 owner 可以改，方便测试访问控制。
     */
    function setValue(uint256 newValue) external view {
        value = newValue;
    }

    /**
     * @notice UUPS 升级授权钩子。
     * @dev 只有 owner 才能升级实现合约。
     * @param newImplementation 新实现地址。
     */
    function _authorizeUpgrade(address newImplementation) internal view override onlyOwner {
    }
}
