// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title TransparentProxyDemoLogicV1
 * @notice 配合 OpenZeppelin 透明代理使用的生产级最小逻辑合约（V1）。
 * @dev
 * V1 与 UUPS 示例保持相同的业务接口和存储顺序：
 * - version：当前业务版本
 * - value：一个简单业务数值
 * - initialize(owner)：只设置 owner 和 V1 版本，value 使用默认值 0
 * - add1：V1 的业务函数
 *
 * 由于它是“实现合约”，真正的状态会存进代理地址对应的存储里，
 * 而不是存进这个逻辑合约自身。
 */
contract TransparentProxyDemoLogicV1 is Initializable, OwnableUpgradeable {
    /// @notice 当前业务实现版本，实际状态保存在代理地址。
    string public version;

    /// @notice 一个简单数值，用于验证升级前后的代理状态保持不变。
    uint256 public value;

    /**
     * @notice 禁止直接初始化实现合约。
     * @dev 代理拥有独立存储，因此不会影响代理存储执行 initialize。
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice 通过代理执行 V1 初始化。
     * @param initialOwner 初始 owner。
     * @dev `initializer` 只允许代理存储执行一次；value 保持默认值 0。
     */
    function initialize(address initialOwner) public initializer {
        __Ownable_init(initialOwner);
        version = "TransparentProxyDemoLogicV1";
    }

    /**
     * @notice 设置业务数值。
     * @dev 只有代理存储中的 owner 可以修改。
     */
    function setValue(uint256 newValue) external onlyOwner {
        value = newValue;
    }

    /**
     * @notice 在当前业务数值上增加 1。
     * @dev 用于验证 V1 业务函数和 owner 权限。
     */
    function add1() external onlyOwner {
        value += 1;
    }
}
