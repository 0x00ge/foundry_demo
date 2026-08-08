// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.7.0) (token/ERC20/extensions/ERC20Burnable.sol)

pragma solidity ^0.8.20;

import "./ERC20Upgradeable.sol";
import {ERC20Upgradeable} from "../ERC20Upgradeable.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

/**
 * @dev {ERC20} 的扩展，允许代币持有者销毁他们自己的代币以及他们有权使用的代币，
 * 这种方式可以通过链下（通过事件分析）识别。
 */
abstract contract ERC20BurnableUpgradeable is Initializable, ERC20Upgradeable {
    function __ERC20Burnable_init() internal onlyInitializing {
    }

    function __ERC20Burnable_init_unchained() internal onlyInitializing {
    }

    /**
     * @dev 销毁调用者的 `value` 数量的代币。
     *
     * 参见 {ERC20-_burn}。
     */
    function burn(uint256 value) public virtual {
        _burn(_msgSender(), value);
    }

    /**
     * @dev 从 `account` 销毁 `value` 数量的代币，并从调用者的授权额度中扣除。
     *
     * 参见 {ERC20-_burn} 和 {ERC20-allowance}。
     *
     * 要求：
     *
     * - 调用者必须对 `account` 的代币拥有至少 `value` 的授权额度。
     */
    function burnFrom(address account, uint256 value) public virtual {
        _spendAllowance(account, _msgSender(), value);
        _burn(account, value);
    }
}