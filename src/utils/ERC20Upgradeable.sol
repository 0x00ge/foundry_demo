// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.5.0) (token/ERC20/ERC20.sol)

pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {ContextUpgradeable} from "../../utils/ContextUpgradeable.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

/**
 * @dev {IERC20} 接口的实现。
 *
 * 此实现对代币的创建方式不敏感，这意味着供应机制必须在派生合约中通过 {_mint} 添加。
 *
 * 提示：有关详细说明，请参阅我们的指南
 * https://forum.openzeppelin.com/t/how-to-implement-erc20-supply-mechanisms/226[如何实现供应机制]。
 *
 * {decimals} 的默认值为 18。如需更改，应重写此函数以返回不同的值。
 *
 * 我们遵循通用的 OpenZeppelin 合约准则：函数在失败时回退而不是返回 `false`。
 * 这种行为虽然常规，但与 ERC-20 应用程序的预期并不冲突。
 */
abstract contract ERC20Upgradeable is Initializable, ContextUpgradeable, IERC20, IERC20Metadata, IERC20Errors {
    /// @custom:storage-location erc7201:openzeppelin.storage.ERC20
    struct ERC20Storage {
        mapping(address account => uint256) _balances;

        mapping(address account => mapping(address spender => uint256)) _allowances;

        uint256 _totalSupply;

        string _name;
        string _symbol;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ERC20")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ERC20StorageLocation = 0x52c63247e1f47db19d5ce0460030c497f067ca4cebf71ba98eeadabe20bace00;

    function _getERC20Storage() private pure returns (ERC20Storage storage $) {
        assembly {
            $.slot := ERC20StorageLocation
        }
    }

    /**
     * @dev 设置 {name} 和 {symbol} 的值。
     *
     * 这两个值都是不可变的：只能在构造期间设置一次。
     */
    function __ERC20_init(string memory name_, string memory symbol_) internal onlyInitializing {
        __ERC20_init_unchained(name_, symbol_);
    }

    function __ERC20_init_unchained(string memory name_, string memory symbol_) internal onlyInitializing {
        ERC20Storage storage $ = _getERC20Storage();
        $._name = name_;
        $._symbol = symbol_;
    }

    /**
     * @dev 返回代币的名称。
     */
    function name() public view virtual returns (string memory) {
        ERC20Storage storage $ = _getERC20Storage();
        return $._name;
    }

    /**
     * @dev 返回代币的符号，通常是名称的缩写版本。
     */
    function symbol() public view virtual returns (string memory) {
        ERC20Storage storage $ = _getERC20Storage();
        return $._symbol;
    }

    /**
     * @dev 返回用于用户表示的小数位数。
     * 例如，如果 `decimals` 等于 `2`，则余额 `505` 应显示为 `5.05` (`505 / 10 ** 2`)。
     *
     * 代币通常选择 18 作为值，以模拟 Ether 和 Wei 之间的关系。
     * 除非被重写，否则这是此函数返回的默认值。
     *
     * 注意：此信息仅用于 _显示_ 目的：它绝不影响合约的任何算术运算，
     * 包括 {IERC20-balanceOf} 和 {IERC20-transfer}。
     */
    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    /// @inheritdoc IERC20
    function totalSupply() public view virtual returns (uint256) {
        ERC20Storage storage $ = _getERC20Storage();
        return $._totalSupply;
    }

    /// @inheritdoc IERC20
    function balanceOf(address account) public view virtual returns (uint256) {
        ERC20Storage storage $ = _getERC20Storage();
        return $._balances[account];
    }

    /**
     * @dev 参见 {IERC20-transfer}。
     *
     * 要求：
     *
     * - `to` 不能是零地址。
     * - 调用者必须拥有至少 `value` 的余额。
     */
    function transfer(address to, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, value);
        return true;
    }

    /// @inheritdoc IERC20
    function allowance(address owner, address spender) public view virtual returns (uint256) {
        ERC20Storage storage $ = _getERC20Storage();
        return $._allowances[owner][spender];
    }

    /**
     * @dev 参见 {IERC20-approve}。
     *
     * 注意：如果 `value` 是最大值 `uint256`，则 `transferFrom` 不会更新授权额度。
     * 这在语义上等同于无限授权。
     *
     * 要求：
     *
     * - `spender` 不能是零地址。
     */
    function approve(address spender, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, value);
        return true;
    }

    /**
     * @dev 参见 {IERC20-transferFrom}。
     *
     * 跳过发出 {Approval} 事件以指示授权额度更新。ERC 并不要求此操作。
     * 参见 {xref-ERC20-_approve-address-address-uint256-bool-}[_approve]。
     *
     * 注意：如果当前授权额度是最大值 `uint256`，则不更新授权额度。
     *
     * 要求：
     *
     * - `from` 和 `to` 不能是零地址。
     * - `from` 必须拥有至少 `value` 的余额。
     * - 调用者必须对 `from` 的代币拥有至少 `value` 的授权额度。
     */
    function transferFrom(address from, address to, uint256 value) public virtual returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        return true;
    }

    /**
     * @dev 将 `value` 数量的代币从 `from` 转移到 `to`。
     *
     * 此内部函数等同于 {transfer}，可用于实现自动代币费用、削减机制等。
     *
     * 发出 {Transfer} 事件。
     *
     * 注意：此函数不是虚函数，应重写 {_update} 代替。
     */
    function _transfer(address from, address to, uint256 value) internal {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(from, to, value);
    }

    /**
     * @dev 将 `value` 数量的代币从 `from` 转移到 `to`，或者如果 `from`（或 `to`）是零地址，则进行铸造（或销毁）。
     * 所有对转账、铸造和销毁的自定义操作都应通过重写此函数来完成。
     *
     * 发出 {Transfer} 事件。
     */
    function _update(address from, address to, uint256 value) internal virtual {
        ERC20Storage storage $ = _getERC20Storage();
        if (from == address(0)) {
            // 需要检查溢出：其余代码假定 totalSupply 永远不会溢出。
            $._totalSupply += value;
        } else {
            uint256 fromBalance = $._balances[from];
            if (fromBalance < value) {
                revert ERC20InsufficientBalance(from, fromBalance, value);
            }
            unchecked {
                // 不可能溢出：value <= fromBalance <= totalSupply。
                $._balances[from] = fromBalance - value;
            }
        }

        if (to == address(0)) {
            unchecked {
                // 不可能溢出：value <= totalSupply 或 value <= fromBalance <= totalSupply。
                $._totalSupply -= value;
            }
        } else {
            unchecked {
                // 不可能溢出：balance + value 最多为 totalSupply，我们知道它适合 uint256。
                $._balances[to] += value;
            }
        }

        emit Transfer(from, to, value);
    }

    /**
     * @dev 创建 `value` 数量的代币并将其分配给 `account`，通过从零地址转移来实现。
     * 依赖于 `_update` 机制。
     *
     * 发出 {Transfer} 事件，其中 `from` 设为零地址。
     *
     * 注意：此函数不是虚函数，应重写 {_update} 代替。
     */
    function _mint(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(address(0), account, value);
    }

    /**
     * @dev 销毁 `account` 中的 `value` 数量的代币，降低总供应量。
     * 依赖于 `_update` 机制。
     *
     * 发出 {Transfer} 事件，其中 `to` 设为零地址。
     *
     * 注意：此函数不是虚函数，应重写 {_update} 代替。
     */
    function _burn(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        _update(account, address(0), value);
    }

    /**
     * @dev 将 `value` 设置为 `spender` 对 `owner` 代币的授权额度。
     *
     * 此内部函数等同于 `approve`，可用于设置某些子系统的自动授权额度等。
     *
     * 发出 {Approval} 事件。
     *
     * 要求：
     *
     * - `owner` 不能是零地址。
     * - `spender` 不能是零地址。
     *
     * 对此逻辑的重写应针对带有额外 `bool emitEvent` 参数的变体进行。
     */
    function _approve(address owner, address spender, uint256 value) internal {
        _approve(owner, spender, value, true);
    }

    /**
     * @dev {_approve} 的变体，带有一个可选标志以启用或禁用 {Approval} 事件。
     *
     * 默认情况下（调用 {_approve} 时），该标志设置为 true。另一方面，在 `transferFrom` 操作期间，
     * `_spendAllowance` 进行的授权更改会将标志设置为 false。这样可以节省 gas，因为在 `transferFrom` 操作期间不会发出任何 `Approval` 事件。
     *
     * 任何希望在 `transferFrom` 操作上继续发出 `Approval` 事件的人都可以通过以下重写强制将标志设置为 true：
     *
     * ```solidity
     * function _approve(address owner, address spender, uint256 value, bool) internal virtual override {
     *     super._approve(owner, spender, value, true);
     * }
     * ```
     *
     * 要求与 {_approve} 相同。
     */
    function _approve(address owner, address spender, uint256 value, bool emitEvent) internal virtual {
        ERC20Storage storage $ = _getERC20Storage();
        if (owner == address(0)) {
            revert ERC20InvalidApprover(address(0));
        }
        if (spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }
        $._allowances[owner][spender] = value;
        if (emitEvent) {
            emit Approval(owner, spender, value);
        }
    }

    /**
     * @dev 根据花费的 `value` 更新 `owner` 对 `spender` 的授权额度。
     *
     * 在无限授权的情况下不更新授权额度。
     * 如果没有足够的授权额度，则回退。
     *
     * 不发出 {Approval} 事件。
     */
    function _spendAllowance(address owner, address spender, uint256 value) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance < type(uint256).max) {
            if (currentAllowance < value) {
                revert ERC20InsufficientAllowance(spender, currentAllowance, value);
            }
            unchecked {
                _approve(owner, spender, currentAllowance - value, false);
            }
        }
    }
}