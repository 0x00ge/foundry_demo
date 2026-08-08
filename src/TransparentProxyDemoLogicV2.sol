// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./TransparentProxyDemoLogic.sol";

/**
 * @title TransparentProxyDemoLogicV2
 * @notice 透明代理的第二版实现合约。
 * @dev
 * 这个版本故意保持和 V1 一样的存储布局，只额外增加一个纯函数，方便验证升级是否生效。
 * 代理升级时，真正变化的是 implementation 槽位指向的新逻辑地址，代理中的业务状态不会丢。
 */
contract TransparentProxyDemoLogicV2 is TransparentProxyDemoLogic {
    /**
     * @notice 返回当前逻辑版本号。
     * @dev 用这个函数来证明代理已经切换到新的实现合约。
     */
    function version() external pure returns (uint256) {
        return 2;
    }
}
