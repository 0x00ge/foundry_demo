// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/**
 * @title MyTokenContract
 * @notice 基于 OpenZeppelin Upgradeable 的可升级 ERC20 代币合约。
 * @dev
 *  - 使用 Initializable 防止实现合约被直接初始化。
 *  - 继承 OwnableUpgradeable：owner 拥有最高管理权限（设置 admin、资金池地址）。
 *  - 继承 ERC20Upgradeable / ERC20BurnableUpgradeable：标准代币功能 + 销毁能力。
 *  - 额外维护 admin 角色与五个资金池地址，用于一次性代币分配。
 *
 * 权限分层：
 *  - owner：核心配置（setAdmin、setPoolAddress）
 *  - admin：业务操作（执行一次性铸币分配）
 *
 * 推荐生命周期：
 *  1. 部署代理后，调用 initialize(owner, admin)。
 *  2. owner 调用 setPoolAddressByOwner 配置五个资金池地址。
 *  3. admin 调用 setPoolTokenByAdmin 铸造并分配代币到各池（仅一次）。
 *
 * 分配比例（合计 100%）：
 *  - miningPool        30%
 *  - directSalePool    20%
 *  - investorSalePool  10%
 *  - ecosystemPool     10%
 *  - foundationPool    30%
 */

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20BurnableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";

contract MyTokenContract is
    Initializable,
    OwnableUpgradeable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable
{
    /**
     * @notice 存放五个用于代币分配的资金池地址。
     * @dev 由 setPoolTokenByAdmin 使用，按业务需求将代币铸造到各个池。
     * @param miningPool        挖矿/激励池（30%）
     * @param directSalePool    直销池（20%）
     * @param investorSalePool  投资者销售池（10%）
     * @param ecosystemPool     生态建设池（10%）
     * @param foundationPool    基金会池（30%）
     */
    struct MyTokenContractPool {
        address miningPool;
        address directSalePool;
        address investorSalePool;
        address ecosystemPool;
        address foundationPool;
    }

    // 管理员地址；仅该地址可调用带 onlyAdmin 修饰器的函数（如 setPoolTokenByAdmin）。
    address public admin;

    // 代币全称（在初始化时写入 ERC20 存储）。
    string private constant NAME = "OHANATOKEN";

    // 代币符号（在初始化时写入 ERC20 存储）。
    string private constant SYMBOL = "OHANA";

    /**
     * @dev 最大总供应量：10 亿枚代币，精度为 6 位小数。
     *      以最小单位表示：1_000_000_000 * 10^6 = 1e15。
     * @notice decimals() 被重写为返回 6，与此常量的精度保持一致。
     */
    uint256 private constant MaxTotalSupply = 1_000_000_000 * 10 ** 6;

    // 是否已完成代币分配。一旦为 true，setPoolAddressByOwner 和 setPoolTokenByAdmin 将被锁定。
    bool public isAllocation;

    // 当前配置的五个资金池地址（必须在调用 setPoolTokenByAdmin 前由 owner 设置）。
    MyTokenContractPool public MyTokenContractPool;

    /**
     * @notice 当管理员地址变更时触发。
     * @param _newAddress 新管理员地址（indexed，便于按地址过滤）。
     * @param _oldAddress 旧管理员地址。
     */
    event SetAdmin(address indexed _newAddress, address _oldAddress);

    /**
     * @notice 资金池地址配置成功时触发。
     * @dev 当结构体被标记为 indexed 时，事件 topic 为整个结构体的 keccak256 哈希，
     *      因此无法按单个池地址过滤；但完整结构体仍可在 data 区解码获取。
     * @param _MyTokenContractPool 新的资金池配置。
     */
    event SetPool(MyTokenContractPool indexed _MyTokenContractPool);

    /**
     * @notice 实现合约的构造函数。
     * @dev 调用 _disableInitializers() 以防止实现合约被直接初始化。
     *      真正的初始化必须通过代理调用 initialize() 完成。
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice 代理合约的初始化入口（仅可调用一次）。
     * @dev
     *  - initializer 修饰器保证仅初始化一次。
     *  - 依次初始化 ERC20、Burnable、Ownable。
     *  - __Ownable_init(_owner) 会设置 owner；admin 单独存储。
     *  - 设置 admin 地址，并将 isAllocation 置为 false。
     * @param _owner  合约 owner（不可为零地址）。
     * @param _admin  初始管理员地址（未校验是否为零地址，调用方需自行保证）。
     */
    function initialize(address _owner, address _admin) public initializer {
        require(
            _owner != address(0),
            "MyTokenContract initialize : _owner can't be zero address"
        );
        __ERC20_init(NAME, SYMBOL);
        __ERC20Burnable_init();
        __Ownable_init(_owner);
        admin = _admin;
        isAllocation = false;
    }

    /**
     * @notice 将访问权限限制为管理员地址。
     * @dev 与 onlyOwner 区分：owner 管理核心配置，admin 管理业务操作（如代币分配）。
     */
    modifier onlyAdmin() {
        require(
            msg.sender == admin,
            "MyTokenContract onlyAdmin : only admin can call this function"
        );
        _;
    }

    /**
     * @notice 设置或更换管理员地址。
     * @dev 仅 owner 可调用。允许设为零地址（这将导致 onlyAdmin 修饰的函数无人可调用）—— 调用方需谨慎操作。
     * @param _admin 新的管理员地址。
     */
    function setAdminByOwner(address _admin) external onlyOwner {
        address oldAddress = admin;
        admin = _admin;
        emit SetAdmin(_admin, oldAddress);
    }

    /**
     * @notice 配置五个资金池地址。
     * @dev 仅 owner 可调用。要求尚未进行分配（!isAllocation），且各池地址均非零。
     *      在分配前可多次调用以更新配置；分配后将被锁定。
     * @param _MyTokenContractPool 资金池地址结构体。
     */
    function setPoolAddressByOwner(MyTokenContractPool memory _MyTokenContractPool) external onlyOwner {
        _beforeSetPoolAllocation();
        _beforeSetPool(_MyTokenContractPool);
        MyTokenContractPool = _MyTokenContractPool;
        emit SetPool(_MyTokenContractPool);
    }

    /**
     * @notice 按预定义比例将全部最大供应量铸造并分配到五个资金池。
     * @dev
     *  - 仅管理员可调用。
     *  - 要求尚未进行分配（!isAllocation）。
     *  - 此函数内不再校验池地址；必须先调用 setPoolAddressByOwner 配置地址。
     *    （若有池地址为零，_mint 到零地址将根据 OZ ERC20 规则回滚。）
     *  - 铸造总量为 MaxTotalSupply（100%），并将 isAllocation 置为 true，防止重复执行。
     *
     * 分配明细：
     *  - miningPool       30%
     *  - directSalePool   20%
     *  - investorSalePool 10%
     *  - ecosystemPool    10%
     *  - foundationPool   30%
     */
    function setPoolTokenByAdmin() external onlyAdmin {
        _beforeSetPoolAllocation();
        _mint(MyTokenContractPool.miningPool, (MaxTotalSupply * 3) / 10); // 30%
        _mint(MyTokenContractPool.directSalePool, (MaxTotalSupply * 2) / 10); // 20%
        _mint(MyTokenContractPool.investorSalePool, MaxTotalSupply / 10); // 10%
        _mint(MyTokenContractPool.ecosystemPool, MaxTotalSupply / 10); // 10%
        _mint(MyTokenContractPool.foundationPool, (MaxTotalSupply * 3) / 10); // 30%
        isAllocation = true;
    }

    /**
     * @notice 返回代币使用的小数位数。
     * @dev 覆盖 OpenZeppelin 默认的 18，固定为 6，以与 MaxTotalSupply 的 10^6 精度保持一致。
     * @return 小数位数（6）。
     */
    function decimals() public view virtual override returns (uint8) {
        return 6;
    }

    /**
     * @notice 检查是否尚未进行分配。
     * @dev 若 isAllocation 为 true，则回滚，防止重复分配或分配后重配池地址。
     */
    function _beforeSetPoolAllocation() internal virtual {
        require(
            !isAllocation,
            "MyTokenContract _beforePoolAllocation : OHANA is already allocate"
        );
    }

    /**
     * @notice 校验五个资金池地址均非零。
     * @dev 若有任何地址为零，则回滚。
     * @param _pool 待校验的资金池配置。
     */
    function _beforeSetPool(MyTokenContractPool memory _pool) internal virtual {
        require(
            _pool.miningPool != address(0),
            "MyTokenContract _beforeSetPool: Missing MiningPool address"
        );
        require(
            _pool.directSalePool != address(0),
            "MyTokenContract _beforeSetPool: Missing DirectSalePool address"
        );
        require(
            _pool.investorSalePool != address(0),
            "MyTokenContract _beforeSetPool: Missing InvestorSalePool address"
        );
        require(
            _pool.ecosystemPool != address(0),
            "MyTokenContract _beforeSetPool: Missing EcosystemPool address"
        );
        require(
            _pool.foundationPool != address(0),
            "MyTokenContract _beforeSetPool: Missing FoundationPool address"
        );
    }
}