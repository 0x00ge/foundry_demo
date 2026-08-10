// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title UUPSDemoLogicV2
 * @notice UUPS 的第二版实现合约。
 */
contract UUPSDemoLogicV2 is Initializable, OwnableUpgradeable, UUPSUpgradeable  {
    /// @notice 当前业务实现版本，实际状态保存在代理地址。
    string public version;

    /// @notice 一个简单数值，用于验证升级前后的代理状态保持不变。
    uint256 public value;

    /**
     * @notice 禁止直接初始化实现合约。
     * @dev
     * 实现合约和代理合约拥有不同的存储。这里只锁定实现合约自己的存储，
     * 不会影响 ERC1967Proxy 在代理存储中执行 initialize。
     *
     * 如果实现合约可以被直接初始化，攻击者可能取得实现合约上的 owner，
     * 进而误导依赖实现地址的业务或运维流程。因此所有实现合约都应锁定初始化。
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice 通过代理执行 V2 初始化。
     * @param initialOwner 初始 owner。
     * @dev
     * `initializer` 将初始化版本标记为 2，只允许代理存储成功执行一次。
     * 代理构造时传入的 calldata 会通过 delegatecall 执行本函数，
     * 因此这里的 address(this) 是代理地址，owner 和 version 都会写入代理。
     * value 不在初始化阶段设置，使用 Solidity 默认值 0。
     */
    function initialize(address initialOwner) public initializer {
        __Ownable_init(initialOwner);
        version = "UUPSDemoLogicV2";
    }

    /**
     * @notice 设置业务数值。
     * @dev 只有代理存储中的 owner 可以修改。
     */
    function setValue(uint256 newValue) external onlyOwner {
        value = newValue;
    }

    /**
     * @notice UUPS 升级授权钩子。
     * @dev
     * UUPSUpgradeable 会在执行升级前调用本函数。
     * `onlyOwner` 使用的是代理存储中的 owner，因此直接调用实现合约不会获得升级权限。
     * @param newImplementation 新实现地址。
     */
    function _authorizeUpgrade(address newImplementation) internal view override onlyOwner {
        // 参数由 UUPSUpgradeable 用于后续兼容性检查，这里只负责权限判断。
        newImplementation;
    }

    /**
     * @notice 在当前业务数值上增加增量。
     * @dev 这是普通业务函数，用来验证升级前后代理状态和权限仍然有效。
     */
    function add1() external onlyOwner {
        value += 1;
    }

    /**
     * @notice 在当前业务数值上增加增量。
     * @dev 这是普通业务函数，用来验证升级前后代理状态和权限仍然有效。
     */
    function add2() external onlyOwner {
        value += 2;
    }
}
