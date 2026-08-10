// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {UUPSDemoLogicV1} from "./UUPSDemoLogicV1.sol";

/**
 * @title UUPSDemoLogicV2
 * @notice UUPS 的第二版实现合约。
 * @dev
 * V2 保持 V1 的继承顺序和已有状态布局，只复用已有的 version/value 状态。
 * 升级时通过 upgradeToAndCall 传入 initializeV2()，在代理存储中执行版本迁移。
 */
contract UUPSDemoLogicV2 is UUPSDemoLogicV1 {
    /**
     * @notice V2 的一次性迁移入口。
     * @dev
     * `reinitializer(2)` 表示这是初始化版本 2，只能在版本 1 已完成且尚未迁移时执行。
     * 生产升级中应把 V2 的存储迁移、默认值设置和版本标记放在这里，
     * 并通过 upgradeToAndCall 原子完成“切换实现 + 执行迁移”。
     */
    function initializeV2() external reinitializer(2) onlyOwner {
        _setVersion();
    }

    /**
     * @notice 将代理存储中的版本标记更新为 V2。
     */
    function _setVersion() internal override {
        version = "UUPSDemoLogicV2";
    }
}
