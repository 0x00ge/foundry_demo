// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {UUPSDemoLogicV1} from "./UUPSDemoLogicV1.sol";

/**
 * @title UUPSDemoLogicV2
 * @notice UUPS 的第二版实现合约。
 * @dev
 * 这个版本保持和 V1 完全一致的存储布局，只额外新增一个版本号函数。
 * 这样可以很直观地验证：
 * - 升级前后代理地址不变
 * - 业务状态不丢
 * - 新逻辑已经生效
 */
contract UUPSDemoLogicV2 is UUPSDemoLogicV1 {

    function _setVersion() internal virtual {
        value = 2;
    }
}
