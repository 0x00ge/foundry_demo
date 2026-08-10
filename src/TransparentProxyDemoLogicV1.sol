// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title TransparentProxyDemoLogicV1
 * @notice 配合 OpenZeppelin 透明代理使用的生产级最小逻辑合约（V1）。
 * @dev
 * 这个合约只保留生产代理合约必须示范的几件事：
 * - 使用 Initializable/OwnableUpgradeable，避免构造函数初始化业务状态
 * - constructor 里禁用实现合约自身初始化
 * - initialize 只能通过代理成功执行一次
 * - add：在原值基础上叠加
 *
 * 由于它是“实现合约”，真正的状态会存进代理地址对应的存储里，
 * 而不是存进这个逻辑合约自身。
 */
contract TransparentProxyDemoLogicV1 is OwnableUpgradeable {
    /// @notice 一个简单数值，用来验证 delegatecall 后状态写到了代理上。
    uint256 public value;

    /**
     * @notice 锁定实现合约自身的初始化状态。
     * @dev 代理拥有独立存储，因此仍可通过代理执行 initialize。
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice 通过代理初始化业务状态。
     * @param initialOwner 初始 owner。
     * @param initialValue 初始数值。
     * @dev 只能在代理存储中成功初始化一次；实现合约自身已在构造时禁用初始化。
     */
    function initialize(address initialOwner, uint256 initialValue) public initializer {
        __Ownable_init(initialOwner);
        value = initialValue;
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
}
