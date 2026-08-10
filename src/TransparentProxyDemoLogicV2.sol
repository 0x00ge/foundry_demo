// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title TransparentProxyDemoLogicV2
 * @notice 透明代理的第二版实现合约。
 * @dev
 * V2 与 V1 使用完全一致的继承顺序和已有存储布局，只新增 add2 业务函数。
 * 透明代理升级使用空 calldata，因此代理中已有的 version/value/owner 状态会保留。
 */
contract TransparentProxyDemoLogicV2 is Initializable, OwnableUpgradeable {
    /**
     * @notice 当前业务实现版本，实际状态保存在代理地址。
     */
    string public version;

    /**
     * @notice 一个简单数值，用于验证升级前后的代理状态保持不变。
     */
    uint256 public value;

    /**
     * @notice 禁止直接初始化 V2 实现合约。
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice V2 自身的初始化入口。
     * @dev 正常从 V1 升级到 V2 时不会调用它；代理已有初始化版本和业务状态。
     */
    function initialize(address initialOwner) public initializer {
        __Ownable_init(initialOwner);
        version = "TransparentProxyDemoLogicV2";
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
     */
    function add1() external onlyOwner {
        value += 1;
    }

    /**
     * @notice 在当前业务数值上增加 2。
     * @dev 这是 V2 新增的业务能力，用于验证实现地址已经切换到 V2。
     */
    function add2() external onlyOwner {
        value += 2;
    }
}
