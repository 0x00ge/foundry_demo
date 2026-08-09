// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/**
 * @title 透明代理
 * @notice 一个最小可用的透明代理实现。
 * @dev
 * 透明代理的核心规则只有三条：
 * 1. 普通用户调用任何未知函数时，都会被转发到实现合约。
 * 2. 代理管理员可以升级实现合约，也可以变更管理员。
 * 3. 管理员不能像普通用户一样直接走回调到实现合约，避免“管理员误调用业务函数”。
 *
 * 这个版本故意只保留最小能力：
 * - upgradeTo：升级实现合约
 * - changeAdmin：变更代理管理员
 * - fallback / receive：把调用转发给实现合约
 *
 * 状态存储使用 EIP-1967 标准槽位，避免与实现合约发生存储冲突。
 */
contract TransparentProxy {
    // EIP-1967: implementation slot = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)
    bytes32 private constant _IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    // EIP-1967: admin slot = bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1)
    bytes32 private constant _ADMIN_SLOT =
        0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    // 当管理员尝试走普通业务调用路径时抛出。
    error AdminCannotFallback();

    // 当调用者不是代理管理员时抛出。
    error NotAdmin();

    // 当传入零地址时抛出。
    error ZeroAddress();

    // 当新实现地址不是合约时抛出。
    error NotAContract();

    // 当 delegatecall 初始化失败时抛出。
    error InitializationFailed();

    // 实现合约升级后触发。
    event Upgraded(address indexed implementation);

    // 管理员地址变更后触发。
    event AdminChanged(address indexed previousAdmin, address indexed newAdmin);

    /**
     * @notice 构造代理并立即初始化实现合约。
     * @param implementation_ 初始实现合约地址。
     * @param admin_ 代理管理员地址。
     * @param data 初始化 calldata，通常是 initialize(...) 的编码结果。
     * @dev
     * 构造时会先写入 admin 和 implementation，再把 data 透传给实现合约做一次 delegatecall。
     * 这样代理一部署完，业务状态就已经完成初始化。
     */
    constructor(address _implementation, address _admin, bytes memory data) payable {
        if (_implementation == address(0) || _admin == address(0)) {
            revert ZeroAddress();
        }
        if (_implementation.code.length == 0) {
            revert NotAContract();
        }

        _setAdmin(_admin);
        _setImplementation(_implementation);

        if (data.length > 0) {
            _delegateCall(_implementation, data);
        }
    }

    /**
     * @notice 升级到新的实现合约。
     * @dev 只有管理员可以调用，且新地址必须是合约。
     * @param newImplementation 新实现合约地址。
     */
    function upgradeTo(address newImplementation) external {
        if (msg.sender != _admin()) revert NotAdmin();
        if (newImplementation == address(0)) revert ZeroAddress();
        if (newImplementation.code.length == 0) revert NotAContract();

        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);
    }

    /**
     * @notice 变更代理管理员。
     * @dev 只有当前管理员可以调用。
     * @param newAdmin 新管理员地址。
     */
    function changeAdmin(address newAdmin) external {
        if (msg.sender != _admin()) revert NotAdmin();
        if (newAdmin == address(0)) revert ZeroAddress();

        address previousAdmin = _admin();
        _setAdmin(newAdmin);
        emit AdminChanged(previousAdmin, newAdmin);
    }

    /**
     * @notice 接收 ETH 时的处理入口。
     * @dev
     * 透明代理允许普通用户把调用继续转发给实现合约；
     * 但管理员如果直接来调用，仍然会被拦下，避免误触业务函数。
     */
    receive() external payable {
        _fallback();
    }

    /**
     * @notice 所有未命中的函数选择器都会进入这里。
     */
    fallback() external payable {
        _fallback();
    }

    /**
     * @dev 统一的回退逻辑。
     *      如果是管理员发起的调用，直接拒绝；
     *      否则把 calldata 原样透传给实现合约。
     */
    function _fallback() internal {
        if (msg.sender == _admin()) revert AdminCannotFallback();
        _delegate(_implementation());
    }

    /**
     * @dev 读取当前实现合约地址。
     */
    function _implementation() internal view returns (address impl) {
        assembly {
            impl := sload(_IMPLEMENTATION_SLOT)
        }
    }

    /**
     * @dev 读取当前管理员地址。
     */
    function _admin() internal view returns (address adm) {
        assembly {
            adm := sload(_ADMIN_SLOT)
        }
    }

    /**
     * @dev 写入实现合约地址。
     */
    function _setImplementation(address newImplementation) internal {
        assembly {
            sstore(_IMPLEMENTATION_SLOT, newImplementation)
        }
    }

    /**
     * @dev 写入管理员地址。
     */
    function _setAdmin(address newAdmin) internal {
        assembly {
            sstore(_ADMIN_SLOT, newAdmin)
        }
    }

    /**
     * @dev 低级 delegatecall 封装。
     *      这里要保持“原样转发，原样返回”：
     *      - calldata 不做任何改写
     *      - 返回值和 revert data 也完整透传
     */
    function _delegate(address implementation_) internal {
        assembly {
            calldatacopy(0, 0, calldatasize())

            let result := delegatecall(gas(), implementation_, 0, calldatasize(), 0, 0)
            let size := returndatasize()

            returndatacopy(0, 0, size)

            switch result
            case 0 {
                revert(0, size)
            }
            default {
                return(0, size)
            }
        }
    }

    /**
     * @dev 构造阶段用的 delegatecall。
     *      如果初始化失败，要把实现合约的报错原样抛回去，方便排查。
     */
    function _delegateCall(address implementation_, bytes memory data) internal {
        (bool success, bytes memory returndata) = implementation_.delegatecall(data);
        if (!success) {
            if (returndata.length == 0) revert InitializationFailed();
            assembly {
                revert(add(returndata, 0x20), mload(returndata))
            }
        }
    }
}
