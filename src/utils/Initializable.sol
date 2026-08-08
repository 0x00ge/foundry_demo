// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.3.0) (proxy/utils/Initializable.sol)

pragma solidity ^0.8.20;

/**
 * @dev 这是一个基础合约，用于帮助编写可升级合约，或任何将通过代理部署的合约。
 * 由于代理合约不会使用构造函数，通常会将构造逻辑移动到外部初始化函数中，通常称为 `initialize`。
 * 然后需要保护这个初始化函数，使其只能被调用一次。本合约提供的 {initializer} 修饰符将起到此作用。
 *
 * 初始化函数使用版本号。一旦版本号被使用，它就会被消耗且不能再次使用。
 * 这种机制防止了每个“步骤”的重复执行，但允许在升级添加需要初始化的模块时创建新的初始化步骤。
 *
 * 例如：
 *
 * [.hljs-theme-light.nopadding]
 * ```solidity
 * contract MyToken is ERC20Upgradeable {
 *     function initialize() initializer public {
 *         __ERC20_init("MyToken", "MTK");
 *     }
 * }
 *
 * contract MyTokenV2 is MyToken, ERC20PermitUpgradeable {
 *     function initializeV2() reinitializer(2) public {
 *         __ERC20Permit_init("MyToken");
 *     }
 * }
 * ```
 *
 * 提示：为避免将代理留在未初始化的状态，应尽早调用初始化函数，
 * 将编码后的函数调用作为 `_data` 参数传递给 {ERC1967Proxy-constructor}。
 *
 * 注意：当与继承一起使用时，必须小心不要两次调用父级初始化函数，
 * 或确保所有初始化函数都是幂等的。Solidity 的构造函数不会自动验证这一点。
 *
 * [注意]
 * ====
 * 避免让合约处于未初始化状态。
 *
 * 未初始化的合约可能被攻击者接管。这既适用于代理，也适用于其实现合约，
 * 这可能会影响代理。为防止实现合约被使用，你应该在构造函数中调用 {_disableInitializers} 函数，
 * 以便在部署时自动锁定它：
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() {
 *     _disableInitializers();
 * }
 * ```
 * ====
 */
abstract contract Initializable {
    /**
     * @dev 可初始化合约的存储结构。
     *
     * 它基于自定义的 ERC-7201 命名空间实现，以降低与可升级合约一起使用时发生存储冲突的风险。
     *
     * @custom:storage-location erc7201:openzeppelin.storage.Initializable
     */
    struct InitializableStorage {
        /**
         * @dev 指示合约已被初始化。
         */
        uint64 _initialized;
        /**
         * @dev 指示合约正在初始化过程中。
         */
        bool _initializing;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.Initializable")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant INITIALIZABLE_STORAGE = 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;

    /**
     * @dev 合约已经被初始化。
     */
    error InvalidInitialization();

    /**
     * @dev 合约未处于初始化状态。
     */
    error NotInitializing();

    /**
     * @dev 当合约被初始化或重新初始化时触发。
     */
    event Initialized(uint64 version);

    /**
     * @dev 修饰器，定义了一个受保护的初始化函数，最多可被调用一次。
     * 在其作用域内，可以使用 `onlyInitializing` 函数来初始化父合约。
     *
     * 类似于 `reinitializer(1)`，但在构造函数上下文中，`initializer` 可以被调用任意次数。
     * 构造函数中的这种行为在测试中很有用，但不应在生产中使用。
     *
     * 触发 {Initialized} 事件。
     */
    modifier initializer() {
        // solhint-disable-next-line var-name-mixedcase
        InitializableStorage storage $ = _getInitializableStorage();

        // 缓存值以避免重复的 SLOAD
        bool isTopLevelCall = !$._initializing;
        uint64 initialized = $._initialized;

        // 允许的调用：
        // - 初始设置：合约未处于初始化状态且之前没有版本被初始化
        // - 构造：合约以版本1初始化（无重新初始化）且当前合约刚被部署
        bool initialSetup = initialized == 0 && isTopLevelCall;
        bool construction = initialized == 1 && address(this).code.length == 0;

        if (!initialSetup && !construction) {
            revert InvalidInitialization();
        }
        $._initialized = 1;
        if (isTopLevelCall) {
            $._initializing = true;
        }
        _;
        if (isTopLevelCall) {
            $._initializing = false;
            emit Initialized(1);
        }
    }

    /**
     * @dev 修饰器，定义了一个受保护的重新初始化函数，最多可被调用一次，
     * 且仅在合约之前未被初始化为更高版本时才能调用。
     * 在其作用域内，可以使用 `onlyInitializing` 函数来初始化父合约。
     *
     * 重新初始化器可以在原始初始化步骤之后使用，这对于配置通过升级添加的、需要初始化的模块是必不可少的。
     *
     * 当 `version` 为 1 时，此修饰器类似于 `initializer`，但标记为 `reinitializer` 的函数不能被嵌套。
     * 如果在另一个上下文中调用，执行将回退。
     *
     * 注意：版本可以以大于1的增量跳跃；这意味着如果多个重新初始化器共存于一个合约中，
     * 按正确顺序执行它们取决于开发者或操作员。
     *
     * 警告：将版本设置为 2**64 - 1 将阻止任何未来的重新初始化。
     *
     * 触发 {Initialized} 事件。
     */
    modifier reinitializer(uint64 version) {
        // solhint-disable-next-line var-name-mixedcase
        InitializableStorage storage $ = _getInitializableStorage();

        if ($._initializing || $._initialized >= version) {
            revert InvalidInitialization();
        }
        $._initialized = version;
        $._initializing = true;
        _;
        $._initializing = false;
        emit Initialized(version);
    }

    /**
     * @dev 修饰器，用于保护初始化函数，使其只能被带有 {initializer} 和 {reinitializer} 修饰符的函数直接或间接调用。
     */
    modifier onlyInitializing() {
        _checkInitializing();
        _;
    }

    /**
     * @dev 如果合约未处于初始化状态，则回退。参见 {onlyInitializing}。
     */
    function _checkInitializing() internal view virtual {
        if (!_isInitializing()) {
            revert NotInitializing();
        }
    }

    /**
     * @dev 锁定合约，阻止任何未来的重新初始化。这不能作为初始化调用的一部分。
     * 在合约构造函数中调用此函数将阻止该合约被初始化或重新初始化为任何版本。
     * 建议使用此函数来锁定旨在通过代理调用的实现合约。
     *
     * 首次成功执行时触发 {Initialized} 事件。
     */
    function _disableInitializers() internal virtual {
        // solhint-disable-next-line var-name-mixedcase
        InitializableStorage storage $ = _getInitializableStorage();

        if ($._initializing) {
            revert InvalidInitialization();
        }
        if ($._initialized != type(uint64).max) {
            $._initialized = type(uint64).max;
            emit Initialized(type(uint64).max);
        }
    }

    /**
     * @dev 返回已初始化的最高版本。参见 {reinitializer}。
     */
    function _getInitializedVersion() internal view returns (uint64) {
        return _getInitializableStorage()._initialized;
    }

    /**
     * @dev 如果合约当前正在初始化，则返回 `true`。参见 {onlyInitializing}。
     */
    function _isInitializing() internal view returns (bool) {
        return _getInitializableStorage()._initializing;
    }

    /**
     * @dev 指向存储槽的指针。允许集成者通过自定义存储位置来覆盖它。
     *
     * 注意：建议遵循 ERC-7201 公式来推导存储位置。
     */
    function _initializableStorageSlot() internal pure virtual returns (bytes32) {
        return INITIALIZABLE_STORAGE;
    }

    /**
     * @dev 返回指向存储命名空间的指针。
     */
    // solhint-disable-next-line var-name-mixedcase
    function _getInitializableStorage() private pure returns (InitializableStorage storage $) {
        bytes32 slot = _initializableStorageSlot();
        assembly {
            $.slot := slot
        }
    }
}