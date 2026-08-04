# MyTokenIsERC20 可升级代理 ERC20 代币 完整学习文档

**版本**：2026-08-04  
**作者**：Claude 整理  
**目标**：完全不懂 Solidity 的新手也能看懂并上手

---

## 1. 合约概述

**MyTokenIsERC20** 是 **可升级代理（Transparent Proxy）** 模式下的 ERC20 代币。

### 核心特点
- 可升级：实现合约可升级，业务地址不变
- Ownable 权限（owner + manager 分离）
- 自定义 manager + 五个资金池
- 一键分配模式（poolAllocate 只能调用一次）
- 固定 6 位小数（MaxTotalSupply = 10 亿 * 10^6）

### 核心角色
| 角色     | 权限     | 主要功能                     | 限制          |
|----------|----------|------------------------------|---------------|
| A        | 部署方   | 部署实现 + Proxy + 初始化    | 部署时       |
| B        | owner    | setPoolAddress（配置五池）   | 分配前可多次 |
| C        | manager  | poolAllocate（铸币分配）     | 仅调用一次    |
| D        | 任意地址 | transfer / approve / burn    | 分配后正常使用 |

---

## 2. 依赖库文件（OpenZeppelin Upgradeable）

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20BurnableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
```

**重要说明**：
- `Initializable`：必须继承，用于 `initializer` 修饰器
- `OwnableUpgradeable`：带升级的 Ownable
- `ERC20Upgradeable`：带升级的 ERC20
- `ERC20BurnableUpgradeable`：带升级的 Burnable

---

## 3. 完整合约代码（MyTokenIsERC20.sol）

```solidity
contract MyTokenIsERC20 is
    Initializable,
    OwnableUpgradeable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable
{
    // =============================================================
    //                          数据结构
    // =============================================================
    struct MyTokenIsERC20Pool {
        address miningPool;
        address directSalePool;
        address investorSalePool;
        address ecosystemPool;
        address foundationPool;
    }

    // =============================================================
    //                          状态变量
    // =============================================================
    address public manager;
    bool public isAllocation;
    MyTokenIsERC20Pool public myTokenIsERC20Pool;

    uint256 private constant MaxTotalSupply = 1_000_000_000 * 10**6;

    // =============================================================
    //                          构造函数
    // =============================================================
    constructor() {
        _disableInitializers();   // 关键！禁止实现合约直接被 initialize
    }

    // =============================================================
    //                          初始化
    // =============================================================
    function initialize(address _owner, address _manager) public initializer {
        require(_owner != address(0), "MyTokenIsERC20 initialize : _owner can't be zero address");
        
        __ERC20_init("MyTokenIsERC20USDT", "OHANA");
        __ERC20Burnable_init();
        __Ownable_init(_owner);
        _transferOwnership(_owner);
        
        manager = _manager;
        isAllocation = false;
    }

    // =============================================================
    //                          修饰器
    // =============================================================
    modifier onlyManager() {
        require(msg.sender == manager, "MyTokenIsERC20 onlyManager : only manager can call this function");
        _;
    }

    // =============================================================
    //                          业务函数
    // =============================================================
    function setManager(address _manager) external onlyOwner {
        manager = _manager;
        emit SetManager(_manager, msg.sender); // 建议添加 emit
    }

    function setPoolAddress(MyTokenIsERC20Pool memory _pool) external onlyOwner {
        require(!isAllocation, "MyTokenIsERC20 setPoolAddress : already allocated");
        _beforePoolAddress(_pool);
        myTokenIsERC20Pool = _pool;
        emit SetPoolAddress(_pool);
    }

    function poolAllocate() external onlyManager {
        require(!isAllocation, "MyTokenIsERC20 poolAllocate : already allocated");
        _mint(myTokenIsERC20Pool.miningPool, (MaxTotalSupply * 3) / 10);  // 30%
        _mint(myTokenIsERC20Pool.directSalePool, (MaxTotalSupply * 2) / 10); // 20%
        _mint(myTokenIsERC20Pool.investorSalePool, MaxTotalSupply / 10); // 10%
        _mint(myTokenIsERC20Pool.ecosystemPool, MaxTotalSupply / 10); // 10%
        _mint(myTokenIsERC20Pool.foundationPool, (MaxTotalSupply * 3) / 10); // 30%
        
        isAllocation = true;
    }

    function decimals() public view override returns (uint8) {
        return 6;
    }

    function tokenBalance(address _address) external view returns (uint256) {
        return balanceOf(_address);
    }

    // =============================================================
    //                          内部检查
    // =============================================================
    function _beforePoolAddress(MyTokenIsERC20Pool memory _pool) internal virtual {
        require(_pool.miningPool != address(0), "Missing MiningPool address");
        require(_pool.directSalePool != address(0), "Missing DirectSalePool address");
        require(_pool.investorSalePool != address(0), "Missing InvestorSalePool address");
        require(_pool.ecosystemPool != address(0), "Missing EcosystemPool address");
        require(_pool.foundationPool != address(0), "Missing FoundationPool address");
    }
}
```

---

## 4. 部署流程（代理模式）

### 部署脚本（script/MyTokenIsERC20.s.sol）

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {MyTokenIsERC20} from "../src/MyTokenIsERC20.sol";
import {console, Script} from "forge-std/Script.sol";

contract MyTokenIsERC20Script is Script {
    function run() public {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address managerAddress = vm.envAddress("MANAGER_ADDRESS");
        address deployer = vm.addr(privateKey);

        vm.startBroadcast(privateKey);

        MyTokenIsERC20 impl = new MyTokenIsERC20();
        
        bytes memory initData = abi.encodeCall(
            MyTokenIsERC20.initialize,
            (deployer, managerAddress)
        );

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(impl),
            deployer,
            initData
        );

        console.log("Proxy 地址:", address(proxy));
        console.log("实现合约地址:", address(impl));

        vm.stopBroadcast();
    }
}
```

**运行命令**：
```bash
forge script script/MyTokenIsERC20.s.sol:MyTokenIsERC20Script \
  --rpc-url https://... \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify
```

---

## 5. 升级模式（Upgradeable）

### 升级实现合约

```solidity
// 通过 ProxyAdmin 升级
ProxyAdmin(0xProxyAdminAddr).upgradeAndCall(
    proxyAddress,
    newImplementationAddress,
    ""   // 升级后可直接调用
);
```

**注意**：
- 业务永远调用 **Proxy 地址**
- 升级时只换实现合约，Proxy 地址不变

---

## 6. 代理模式调用树（完整版）

```
时间 ────────────────────────────────────────────────────────────────►

A（部署方） 
  ├─ 部署实现合约 MyTokenIsERC20
  ├─ 部署 TransparentUpgradeableProxy
  └─ Proxy.initialize(owner=B, manager=C)

B（owner） ───────────────────────────────────────────────────────────
  ├─ setManager(C')
  └─ setPoolAddress(五池地址)   // 分配前可多次

C（manager） ────────────────────────────────────────────────────────
  └─ poolAllocate()   // 仅 1 次，铸币到五池

D（任意地址） ───────────────────────────────────────────────────────
  ├─ transfer / approve / burn / balanceOf
```

---

## 7. 学习建议（新手必读）

1. **永远不要直接调用实现合约**
2. **initialize 只能调用一次**（用 `initializer` 修饰器）
3. **代理模式下，所有业务走 Proxy 地址**
4. **分配后 `isAllocation = true`**，配置和再次分配均失败
5. **五个池必须在分配前配置好**，否则 mint 到 0 地址会回滚

---

## 8. 后续文件位置

- `src/MyTokenIsERC20.sol` —— 核心合约
- `script/MyTokenIsERC20.s.sol` —— 部署脚本
- `test/MyTokenIsERC20.t.sol` —— 测试用例

---

**文档结束**

---

现在这个文件已经包含了**库文件、完整代码、部署、升级、代理模式、调用流程**等所有内容。

你可以直接打开这个文件学习。需要我再补充其他内容（比如完整测试用例、Foundry 命令行使用等）吗？