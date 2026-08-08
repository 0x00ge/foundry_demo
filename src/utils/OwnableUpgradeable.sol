// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (access/Ownable.sol)

pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";

/**
 * @dev 提供基本访问控制机制的合约模块，其中存在一个拥有特定函数独有访问权限的账户（所有者）。
 *
 * 初始所有者设置为部署者提供的地址。之后可以通过 {transferOwnership} 进行更改。
 *
 * 此模块通过继承方式使用。它将提供修饰器 `onlyOwner`，可应用于函数以限制其只能由所有者调用。
 */
abstract contract OwnableUpgradeable is Initializable, ContextUpgradeable {
    /// @custom:storage-location erc7201:openzeppelin.storage.Ownable
    struct OwnableStorage {
        address _owner;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.Ownable")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant OwnableStorageLocation = 0x9016d09d72d40fdae2fd8ceac6b6234c7706214fd39c1cd1e609a0528c199300;

    function _getOwnableStorage() private pure returns (OwnableStorage storage $) {
        assembly {
            $.slot := OwnableStorageLocation
        }
    }

    /**
     * @dev 调用方账户无权执行该操作。
     */
    error OwnableUnauthorizedAccount(address account);

    /**
     * @dev 所有者不是有效的所有者账户（例如 `address(0)`）。
     */
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev 初始化合约，将部署者提供的地址设置为初始所有者。
     */
    function __Ownable_init(address initialOwner) internal onlyInitializing {
        __Ownable_init_unchained(initialOwner);
    }

    function __Ownable_init_unchained(address initialOwner) internal onlyInitializing {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    /**
     * @dev 如果调用方不是所有者，则抛出异常。
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev 返回当前所有者的地址。
     */
    function owner() public view virtual returns (address) {
        OwnableStorage storage $ = _getOwnableStorage();
        return $._owner;
    }

    /**
     * @dev 如果发送方不是所有者，则抛出异常。
     */
    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    /**
     * @dev 放弃合约的所有权。之后将无法调用 `onlyOwner` 函数。
     * 只能由当前所有者调用。
     *
     * 注意：放弃所有权后，合约将没有所有者，从而禁用任何仅对所有者可用的功能。
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev 将合约的所有权转移到新账户 (`newOwner`)。
     * 只能由当前所有者调用。
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    /**
     * @dev 将合约的所有权转移到新账户 (`newOwner`)。
     * 内部函数，无访问限制。
     */
    function _transferOwnership(address newOwner) internal virtual {
        OwnableStorage storage $ = _getOwnableStorage();
        address oldOwner = $._owner;
        $._owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}