// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/**
 * @title TransparentProxyDemoLogic
 * @notice 配合透明代理使用的极简演示逻辑合约。
 * @dev
 * 这个合约故意写得非常小，只保留几个最容易验证代理行为的点：
 * - initialize：初始化 owner 和初始值
 * - setValue：只有 owner 可以改值
 * - add：在原值基础上叠加
 * - transferOwnership：演示代理升级前后的状态仍然保留
 *
 * 由于它是“实现合约”，真正的状态会存进代理地址对应的存储里，
 * 而不是存进这个逻辑合约自身。
 */
contract TransparentProxyDemoLogic {
    /// @notice 当前业务 owner。
    address public owner;

    /// @notice 一个简单数值，用来验证 delegatecall 后状态写到了代理上。
    uint256 public value;

    /// @dev 防止重复初始化。
    bool private initialized;

    /// @notice 当调用者不是 owner 时抛出。
    error NotOwner();

    /// @notice 当初始化被重复调用时抛出。
    error AlreadyInitialized();

    /// @notice 当地址参数为空时抛出。
    error ZeroAddress();

    /**
     * @notice 初始化逻辑合约状态。
     * @param owner_ 业务 owner。
     * @param initialValue 初始数值。
     * @dev 只能初始化一次。
     */
    function initialize(address owner_, uint256 initialValue) external {
        if (initialized) revert AlreadyInitialized();
        if (owner_ == address(0)) revert ZeroAddress();

        initialized = true;
        owner = owner_;
        value = initialValue;
    }

    /// @dev 只有 owner 才能执行。
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    /**
     * @notice 直接写入一个新值。
     * @dev 这个函数最适合拿来验证 proxy 是否真的把状态写进了代理存储。
     */
    function setValue(uint256 newValue) external onlyOwner {
        value = newValue;
    }

    /**
     * @notice 在当前值基础上增加一个增量。
     * @dev 用来验证普通业务调用路径。
     */
    function add(uint256 delta) external onlyOwner {
        value += delta;
    }

    /**
     * @notice 转移业务 owner。
     * @param newOwner 新 owner 地址。
     */
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        owner = newOwner;
    }
}
