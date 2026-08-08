// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/**
 * @title MyTokenContract
 * @notice 可升级的 ERC20 代币合约（基于 OpenZeppelin Upgradeable）
 * @dev
 *  - 使用 Initializable 模式，禁止构造函数初始化，避免实现合约被直接初始化
 *  - 继承 OwnableUpgradeable：owner 拥有最高管理权限（设置 admin、池地址等）
 *  - 继承 ERC20Upgradeable / ERC20BurnableUpgradeable：标准代币 + 销毁能力
 *  - 额外维护 admin 角色与多资金池地址，用于一次性代币分配
 *
 * 权限分层：
 *  - owner：核心配置（setAdmin、setPoolAddress）
 *  - admin：业务操作（poolAllocate 执行铸币分配）
 *
 * 生命周期（建议调用顺序）：
 *  1. 代理部署后调用 initialize(owner, admin)
 *  2. owner 调用 setPoolAddress 配置五个资金池
 *  3. admin 调用 poolAllocate 按比例铸币到各池（仅一次）
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
     * @notice 代币分配相关的五个资金池地址
     * @dev 用于 poolAllocate 将代币按业务场景一次性铸币到不同池子
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

    // 业务管理员地址；仅 admin 可调用带 onlyAdmin 的函数（如 poolAllocate）
    address public admin;

    // 代币全称（initialize 时写入 ERC20 存储）
    string private constant NAME = "OHANATOKEN";

    // 代币符号（initialize 时写入 ERC20 存储）
    string private constant SYMBOL = "OHANA";

    /**
     * @dev 最大总供应量：10 亿枚，按 6 位小数计量
     *      即 1_000_000_000 * 10^6 = 1e15（最小单位）
     * @notice 已 override decimals() 为 6，与 MaxTotalSupply 计量一致
     */
    uint256 private constant MaxTotalSupply = 1_000_000_000 * 10 ** 6;

    // 是否已完成代币分配；为 true 后不可再 setPoolAddress / poolAllocate
    bool public isAllocation;

    // 当前配置的五个资金池地址（需在 poolAllocate 前由 owner 设置）
    MyTokenContractPool public MyTokenContractPool;

    /**
     * @notice admin 地址变更时触发
     * @param _newAddress 新的 admin 地址（indexed，便于按地址过滤日志）
     * @param _oldAddress 旧的 admin 地址
     */
    event SetAdmin(address indexed _newAddress, address _oldAddress);

    /**
     * @notice 资金池地址配置成功时触发
     * @dev struct 作为 indexed 参数时，event topic 中是整个 struct 的 keccak256 哈希，
     *      无法按单个池地址过滤；data 区仍可完整解码
     * @param _MyTokenContractPool 新的资金池配置
     */
    event SetPoolAddress(MyTokenContractPool indexed _MyTokenContractPool);

    // =============================================================
    //                          构造函数
    // =============================================================

    /**
     * @notice 实现合约构造函数
     * @dev 调用 _disableInitializers()，防止实现合约本身被 initialize；
     *      真正的初始化应在代理合约上调用 initialize
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice 代理合约初始化入口（仅可调用一次）
     * @dev
     *  - initializer 修饰器保证只初始化一次
     *  - 依次初始化 ERC20、Burnable、Ownable
     *  - __Ownable_init(_owner) 内部已设置 owner；此处额外调用 _transferOwnership 为冗余，可保留作显式强调
     *  - 设置 admin，并将 isAllocation 置为 false
     * @param _owner   合约 owner（不可为零地址）
     * @param _admin 初始 admin 地址（当前未校验非零，调用方需自行保证）
     */
    function initialize(address _owner, address _admin) public initializer {
        require(
            _owner != address(0),
            "MyTokenContract initialize : _owner can't be zero address"
        );
        __ERC20_init(NAME, SYMBOL);
        __ERC20Burnable_init();
        __Ownable_init(_owner);
        _transferOwnership(_owner);
        admin = _admin;
        isAllocation = false;
    }

    /**
     * @notice 仅 admin 可调用
     * @dev 与 onlyOwner 区分：owner 管核心配置，admin 管日常业务操作（如 poolAllocate）
     */
    modifier onlyAdmin() {
        require(
            msg.sender == admin,
            "MyTokenContract onlyAdmin : only admin can call this function"
        );
        _;
    }

    /**
     * @notice 设置 / 更换 admin
     * @dev 仅 owner 可调用；当前允许设为零地址（将导致 onlyAdmin 函数无人可调），调用方需谨慎
     * @param _admin 新的 admin 地址
     */
    function setAdminByOwner(address _admin) external onlyOwner {
        address oldAddress = admin;
        admin = _admin;
        emit SetAdmin(_admin, oldAddress);
    }

    /**
     * @notice 配置五个资金池地址
     * @dev 仅 owner 可调用；要求尚未分配（!isAllocation），且各池地址非零
     *      分配完成前可多次调用以更新配置；分配后不可再改
     * @param _MyTokenContractPool 资金池地址结构体
     */
    function setPoolAddressByOwner(MyTokenContractPool memory _MyTokenContractPool) external onlyOwner {
        _beforePoolAllocation();
        _beforePoolAddress(_MyTokenContractPool);
        MyTokenContractPool = _MyTokenContractPool;
        emit SetPoolAddress(_MyTokenContractPool);
    }

    /**
     * @notice 按预设比例向五个资金池一次性铸币分配
     * @dev
     *  - 仅 admin 可调用
     *  - 要求尚未分配（!isAllocation）
     *  - 不在此函数内再次校验池地址；调用前必须先 setPoolAddress
     *    （若池地址仍为 0，_mint 到零地址会按 OZ ERC20 规则回滚）
     *  - 铸币总量 = MaxTotalSupply（100%），分配后 isAllocation = true，不可重复
     *
     * 分配明细：
     *  - miningPool       30%
     *  - directSalePool   20%
     *  - investorSalePool 10%
     *  - ecosystemPool    10%
     *  - foundationPool   30%
     */
    function setPoolAllocateByAdmin() external onlyAdmin {
        _beforePoolAllocation();
        _mint(MyTokenContractPool.miningPool, (MaxTotalSupply * 3) / 10); // 30%
        _mint(MyTokenContractPool.directSalePool, (MaxTotalSupply * 2) / 10); // 20%
        _mint(MyTokenContractPool.investorSalePool, MaxTotalSupply / 10); // 10%
        _mint(MyTokenContractPool.ecosystemPool, MaxTotalSupply / 10); // 10%
        _mint(MyTokenContractPool.foundationPool, (MaxTotalSupply * 3) / 10); // 30%
        isAllocation = true;
    }

    /**
     * @notice 返回代币精度
     * @dev 覆盖 OpenZeppelin 默认的 18，固定为 6（与 MaxTotalSupply 的 10^6 计量一致）
     * @return 小数位数（6）
     */
    function decimals() public view virtual override returns (uint8) {
        return 6;
    }

    /**
     * @notice 查询某地址的代币余额
     * @dev 对 balanceOf 的封装，便于外部统一 token 接口调用
     * @param _address 要查询的地址
     * @return 该地址的代币余额
     */
    function tokenBalance(address _address) external view virtual returns (uint256) {
        return balanceOf(_address);
    }

    /**
     * @notice 分配前检查：确保尚未完成分配
     * @dev 若 isAllocation 已为 true，则回滚，防止重复分配或在分配后改池地址
     */
    function _beforePoolAllocation() internal virtual {
        require(
            !isAllocation,
            "MyTokenContract _beforePoolAllocation : OHANA is already allocate"
        );
    }

    /**
     * @notice 校验资金池地址完整性
     * @dev 五个池地址均不能为零地址，否则回滚
     * @param _pool 待校验的资金池配置
     */
    function _beforePoolAddress(MyTokenContractPool memory _pool) internal virtual {
        require(
            _pool.miningPool != address(0),
            "MyTokenContract _beforePoolAddress: Missing MiningPool address"
        );
        require(
            _pool.directSalePool != address(0),
            "MyTokenContract _beforePoolAddress: Missing DirectSalePool address"
        );
        require(
            _pool.investorSalePool != address(0),
            "MyTokenContract _beforePoolAddress: Missing InvestorSalePool address"
        );
        require(
            _pool.ecosystemPool != address(0),
            "MyTokenContract _beforePoolAddress: Missing EcosystemPool address"
        );
        require(
            _pool.foundationPool != address(0),
            "MyTokenContract _beforePoolAddress: Missing FoundationPool address"
        );
    }
}