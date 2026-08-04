# MyTokenIsERC20 调用流程

`MyTokenIsERC20` 是**可升级代理**下的 ERC20。  
下面用 **A / B / C / D** 四个角色画调用树；**每个角色单独一条分支**，互不混写。

| 角色 | 身份 | 做什么 |
|------|------|--------|
| **A** | 部署方 | 部署实现 + Proxy，并完成 `initialize` |
| **B** | owner | 配置 manager、资金池 |
| **C** | manager | 一次性铸币分配 |
| **D** | 任意地址 | 日常转账 / 授权 / 销毁 / 查询 |

> 所有业务调用都打在 **Proxy 地址** 上，不要打实现合约。

---

## 总览：谁在什么时候出场

```
时间 ────────────────────────────────────────────────────────────────►

A（部署方）
 │
 ├─ 1) 部署实现合约 MyTokenIsERC20
 ├─ 2) 部署 Proxy（指向实现）
 └─ 3) Proxy.initialize(owner=B, manager=C)
          │
          ▼  初始化完成，合约可被配置
          │
B（owner）──────────────────────────────────────────────────────────
 │
 ├─ 4) setManager(C')?          // 可选：换 manager
 └─ 5) setPoolAddress(五池)     // 分配前可多次
          │
          ▼  五池地址就绪
          │
C（manager）────────────────────────────────────────────────────────
 │
 └─ 6) poolAllocate()           // 仅一次 → isAllocation = true
          │
          ▼  五池余额就绪，开放流通
          │
D（任意地址）───────────────────────────────────────────────────────
 │
 └─ 7) transfer / approve / burn / balanceOf / tokenBalance …
```

---

## 分支 A — 部署方

A 只负责「把合约立起来」，之后通常不再参与业务。

```
A（部署方）
 │
 ├─► new MyTokenIsERC20()
 │         │
 │         └─ constructor()
 │                └─ _disableInitializers()   // 禁止实现合约被 initialize
 │
 ├─► new Proxy(impl)   // ERC1967 / Transparent / UUPS 等
 │
 └─► Proxy.initialize(_owner = B, _manager = C)   // 仅 1 次
           │
           ├─ require(_owner != 0)
           ├─ __ERC20_init(NAME, SYMBOL)          // "MyTokenIsERC20USDT" / "OHANA"
           ├─ __ERC20Burnable_init()
           ├─ __Ownable_init(_owner)              // owner = B
           ├─ _transferOwnership(_owner)
           ├─ manager = _manager                  // manager = C
           └─ isAllocation = false
```

**约束**

| 函数 | 谁可调 | 次数 | 前置 |
|------|--------|------|------|
| `initialize` | 任意（在 Proxy 上） | **1 次** | 未初始化 |

---

## 分支 B — owner

B 是配置角色，**不负责铸币**。分配完成前可反复改配置；分配后配置入口锁死。

```
B（owner）
 │
 │  onlyOwner
 │
 ├──► setManager(_manager)
 │         │
 │         ├─ manager = _manager
 │         └─ emit SetManager(new, old)
 │
 ├──► setPoolAddress(pool)                 // 分配前可多次
 │         │
 │         ├──► _beforeAllocation()
 │         │         └─ require(!isAllocation)
 │         │
 │         ├──► _beforePoolAddress(pool)
 │         │         ├─ miningPool       != 0
 │         │         ├─ directSalePool   != 0
 │         │         ├─ investorSalePool != 0
 │         │         ├─ ecosystemPool    != 0
 │         │         └─ foundationPool   != 0
 │         │
 │         ├─ myTokenIsERC20Pool = pool
 │         └─ emit SetPoolAddress(pool)
 │
 └──► transferOwnership(newOwner)          // Ownable 继承
           └─ owner 移交（后续配置由新 owner 执行）
```

**约束**

| 函数 | 谁可调 | 次数 | 前置 |
|------|--------|------|------|
| `setManager` | B（owner） | 多次 | — |
| `setPoolAddress` | B（owner） | 分配前多次 | `!isAllocation` + 五池非零 |
| `transferOwnership` | B（owner） | 多次 | Ownable 规则 |

**伪代码**

```solidity
// B 发交易
token.setManager(0xC...);   // 可选

token.setPoolAddress(
  MyTokenIsERC20.MyTokenIsERC20Pool({
    miningPool:        0xM...,
    directSalePool:    0xD...,
    investorSalePool:  0xI...,
    ecosystemPool:     0xE...,
    foundationPool:    0xF...
  })
);
```

---

## 分支 C — manager

C 只做一件事：按比例一次性铸满五池。**必须先等 B 配好池地址**，否则会 mint 到 `address(0)` 被 OZ ERC20 回滚。

```
C（manager）
 │
 │  onlyManager
 │
 └──► poolAllocate()                       // 仅 1 次
           │
           ├──► _beforeAllocation()
           │         └─ require(!isAllocation)
           │
           ├──► _mint × 5（总量 MaxTotalSupply）
           │         ├─ miningPool       ──► 30%
           │         ├─ directSalePool   ──► 20%
           │         ├─ investorSalePool ──► 10%
           │         ├─ ecosystemPool    ──► 10%
           │         └─ foundationPool   ──► 30%
           │
           └─ isAllocation = true
                 // 之后 B 的 setPoolAddress、C 的 poolAllocate 均失败
```

**约束**

| 函数 | 谁可调 | 次数 | 前置 |
|------|--------|------|------|
| `poolAllocate` | C（manager） | **1 次** | `!isAllocation`；五池已由 B 配置 |

**伪代码**

```solidity
// 必须用 C（manager）地址发交易
token.poolAllocate();
```

---

## 分支 D — 任意地址（日常使用）

D 在 C 完成分配后即可正常使用（持币 / 授权方可转账、销毁）。查询类无权限限制。

```
D（任意地址）
 │
 │  无业务角色限制（遵循 ERC20 自身规则）
 │
 ├──► 查询
 │      ├─ decimals()            // 固定返回 6
 │      ├─ tokenBalance(addr)    // 封装 balanceOf
 │      ├─ balanceOf(addr)
 │      ├─ totalSupply()
 │      ├─ allowance(owner, spender)
 │      └─ name() / symbol()
 │
 ├──► 授权
 │      ├─ approve(spender, amount)
 │      ├─ increaseAllowance / decreaseAllowance   // 若继承提供
 │      └─ …
 │
 ├──► 转账
 │      ├─ transfer(to, amount)                    // 需自身有余额
 │      └─ transferFrom(from, to, amount)          // 需授权
 │
 └──► 销毁
        ├─ burn(amount)                            // 烧自己的
        └─ burnFrom(account, amount)               // 烧已授权的
```

**约束**

| 函数 | 谁可调 | 次数 | 前置 |
|------|--------|------|------|
| `decimals` / `tokenBalance` 等 view | 任意 | 多次 | — |
| `transfer` / `approve` / `burn` 等 | 持币或授权方 | 多次 | ERC20 规则 |

**伪代码**

```solidity
// D 发交易
token.transfer(to, amount);
token.approve(spender, amount);
token.burn(amount);
token.tokenBalance(user);
```

---

## 角色 × 可调函数（对照表）

```
                    ┌──────────────────────┐
                    │   外部调用方          │
                    └──────────┬───────────┘
       ┌───────────┬───────────┼───────────┬───────────┐
       │           │           │           │           │
       ▼           ▼           ▼           ▼           ▼
   ┌───────┐  ┌───────┐  ┌───────┐  ┌───────┐  ┌──────────┐
   │   A   │  │   B   │  │   C   │  │   D   │  │  实现合约 │
   │ 部署方 │  │ owner │  │manager│  │任意地址│  │ （勿直接调）│
   └───┬───┘  └───┬───┘  └───┬───┘  └───┬───┘  └──────────┘
       │          │          │          │
       │ 部署+初始化│ onlyOwner│onlyManager│ 无角色限制
       ▼          ▼          ▼          ▼
 ┌───────────┐ ┌────────────┐ ┌────────────┐ ┌─────────────────┐
 │ deploy    │ │ setManager │ │poolAllocate│ │ decimals        │
 │ initialize│ │ setPool…   │ │ （仅 1 次） │ │ tokenBalance    │
 │           │ │ transferOwn│ │            │ │ transfer/approve│
 │           │ │            │ │            │ │ burn …          │
 └───────────┘ └────────────┘ └────────────┘ └─────────────────┘
```

---

## 分配比例

| 资金池 | 字段 | 比例 |
|--------|------|------|
| 挖矿/激励池 | `miningPool` | 30% |
| 直销池 | `directSalePool` | 20% |
| 投资者销售池 | `investorSalePool` | 10% |
| 生态建设池 | `ecosystemPool` | 10% |
| 基金会池 | `foundationPool` | 30% |
| **合计** | | **100%** |

最大总供应量：`MaxTotalSupply = 1_000_000_000 * 10**6`（10 亿枚，6 位小数）。

---

## 要点

1. **A 部署 → B 配置 → C 分配 → D 使用**，顺序不可乱。
2. 业务入口一律打 **Proxy**，实现合约已 `_disableInitializers()`。
3. `poolAllocate` 前必须先 `setPoolAddress`，否则 mint 到 `address(0)` 回滚。
4. 分配后 `isAllocation = true`，B 的配置与 C 的再分配全部锁死。
5. B 与 C 职责分离：owner 管配置，manager 管铸币。

---

## Foundry 脚本侧对照

```
A ──► deploy impl + proxy
A ──► proxy.initialize(B, C)
         │
B ──► setPoolAddress(五池)
         │
C ──► poolAllocate()
         │
         ▼
D ──► transfer / approve / burn / tokenBalance …
      （五池余额就绪，开放转账）
```
