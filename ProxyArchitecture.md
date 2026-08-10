# 代理架构总览

这份文档把当前仓库里的三套代理写清楚：

1. `MyTokenContractV1` 使用透明代理
2. `TransparentProxyDemoLogicV1/V2` 是 OpenZeppelin 透明代理的生产级最小示例
3. `UUPSDemoLogicV1/V2` 是 OpenZeppelin UUPS 的生产级最小示例

## 1. MyTokenContractV1

当前 `MyTokenContractV1` 不是 UUPS，而是透明代理体系。

对应文件：

- [src/MyTokenContractV1.sol](./src/MyTokenContractV1.sol)
- [script/DeployMyToken.s.sol](./script/DeployMyToken.s.sol)
- [test/MyTokenContractTest.t.sol](./test/MyTokenContractTest.t.sol)

### 运行方式

- 部署逻辑合约 `MyTokenContractV1`
- 部署 `TransparentUpgradeableProxy`
- 使用 `ProxyAdmin` 管理升级
- 通过代理地址调用 `initialize(owner, admin)`

### 权限模型

- `owner`：管理核心配置，比如 `setAdminByOwner`、`setPoolAddressByOwner`
- `admin`：执行一次性分配 `setPoolTokenByAdmin`
- 普通用户：只走 ERC20 业务函数，比如 `transfer`、`approve`、`burn`

### 关键点

- 状态写在代理地址上，不写在逻辑合约上
- 升级由 `ProxyAdmin` 负责
- 逻辑合约本身不需要实现 `upgradeTo`

### 详细调用过程

1. 部署 `MyTokenContractV1` 逻辑合约。
2. 部署 `TransparentUpgradeableProxy`，并指定：
   - 逻辑合约地址
   - `ProxyAdmin` 的 owner
   - `initialize(owner, admin)` 的初始化数据
3. 代理在构造函数里 `delegatecall` 到 `initialize`。
4. `initialize` 在代理存储里写入：
   - 代币名称
   - 代币符号
   - `owner`
   - `admin`
   - `isAllocation = false`
5. `owner` 通过代理调用 `setPoolAddressByOwner` 配置五个资金池。
6. `admin` 通过代理调用 `setPoolTokenByAdmin` 完成一次性铸币和分配。
7. 普通用户通过代理调用 `transfer`、`approve`、`transferFrom`、`burn` 等 ERC20 函数。
8. 升级时由 `ProxyAdmin` 发起 `upgradeAndCall`：
   - 先把实现地址切到新逻辑
   - 如有初始化数据，再继续执行迁移逻辑
9. 代理地址始终不变，变化的只有逻辑合约地址。

## 2. 透明代理示例

这是一个基于 OpenZeppelin `TransparentUpgradeableProxy + ProxyAdmin` 的生产级最小示例。

对应文件：

- [src/TransparentProxyDemoLogicV1.sol](./src/TransparentProxyDemoLogicV1.sol)
- [src/TransparentProxyDemoLogicV2.sol](./src/TransparentProxyDemoLogicV2.sol)
- [script/DeployTransparentProxy.s.sol](./script/DeployTransparentProxy.s.sol)
- [script/UpgradeTransparentProxy.s.sol](./script/UpgradeTransparentProxy.s.sol)
- [test/TransparentProxyTest.t.sol](./test/TransparentProxyTest.t.sol)

### 运行方式

- 部署 `TransparentProxyDemoLogicV1`
- 用 `TransparentUpgradeableProxy` 包一层
- 构造时把 `initialize` 的 calldata 一起传进去
- 代理构造时自动创建 `ProxyAdmin`
- 通过代理调用业务函数

### 透明代理规则

- 普通用户的业务调用会被 `fallback` 转发到实现合约
- 代理的真实 admin 是 `ProxyAdmin` 合约
- `ProxyAdmin` 不能走普通业务调用路径
- `ProxyAdmin` 的 owner 通过 `ProxyAdmin.upgradeAndCall` 升级代理

### 关键点

- 实现合约继承 `OwnableUpgradeable`
- 实现合约构造函数调用 `_disableInitializers()`，防止实现地址被独立初始化
- 初始化只能通过代理构造函数里的 delegatecall 完成
- 升级只改实现地址，不改代理地址和业务状态

### 详细调用过程

1. 部署 `TransparentProxyDemoLogicV1` 作为 V1 逻辑合约。
2. 部署 `TransparentUpgradeableProxy`，传入：
   - V1 地址
   - `ProxyAdmin` owner 地址
   - `initialize(owner, initialValue)` 的编码数据
3. 代理构造时部署并记录 `ProxyAdmin`。
4. 代理再对 V1 执行一次 `delegatecall` 初始化，把 owner 和 value 写入代理存储。
5. 普通用户调用 `setValue`、`add`、`transferOwnership` 等函数时：
   - 代理命中 `fallback`
   - 校验调用者不是 `ProxyAdmin`
   - 把调用原样转发给实现合约
   - 状态写回代理存储
6. `ProxyAdmin` 调用业务函数时会被直接拒绝，不能误走实现合约逻辑。
7. 升级时 `ProxyAdmin` owner 调用 `ProxyAdmin.upgradeAndCall(proxy, newImplementation, data)`：
   - `ProxyAdmin` 校验调用者是 owner
   - 代理校验调用者是自己的 admin
   - 更新 EIP-1967 implementation 槽
8. 升级后代理地址不变，后续所有普通调用都会进入新实现合约。
9. 如果需要转移升级权限，当前 `ProxyAdmin` owner 调用 `transferOwnership(newOwner)`。

## 3. UUPS 示例

UUPS 的核心思路是：升级逻辑写在实现合约里，不单独放 `ProxyAdmin`。当前示例使用 OpenZeppelin `ERC1967Proxy + UUPSUpgradeable + OwnableUpgradeable`。

对应文件：

- [src/UUPSDemoLogicV1.sol](./src/UUPSDemoLogicV1.sol)
- [src/UUPSDemoLogicV2.sol](./src/UUPSDemoLogicV2.sol)
- [script/DeployUUPSDemo.s.sol](./script/DeployUUPSDemo.s.sol)
- [script/UpgradeUUPSDemo.s.sol](./script/UpgradeUUPSDemo.s.sol)
- [test/UUPSDemoTest.t.sol](./test/UUPSDemoTest.t.sol)

### 运行方式

- 部署 `UUPSDemoLogicV1`
- 用 `ERC1967Proxy` 包一层
- 在代理构造时完成 `initialize`
- 通过实现合约暴露的 `upgradeToAndCall` 完成升级

### UUPS 规则

- 升级权限写在 `_authorizeUpgrade`
- `upgradeToAndCall` 只能通过代理调用
- `proxiableUUID()` 不能通过代理调用

### 关键点

- 代理只负责转发
- 升级入口在实现合约里
- 实现合约构造函数调用 `_disableInitializers()`，防止实现地址被独立初始化
- `_authorizeUpgrade` 用 `onlyOwner` 限定升级权限

### 详细调用过程

1. 部署 `UUPSDemoLogicV1` 作为 V1 实现合约。
2. 部署 `ERC1967Proxy`，把 V1 地址和 `initialize(owner, initialValue)` 数据一起传入。
3. 代理构造时执行初始化，把业务状态写进代理存储。
4. 普通用户通过代理调用 `setValue`、`add` 等函数：
   - 代理只做转发
   - 业务逻辑在实现合约里执行
   - 状态仍然落在代理上
5. `owner` 调用 `upgradeToAndCall(newImplementation, data)` 时：
   - 先通过 `onlyProxy` 检查，确认不是直接打到实现合约
   - 再进入 `_authorizeUpgrade`
   - `_authorizeUpgrade` 里用 `onlyOwner` 限定升级权限
   - 权限通过后，执行 UUPS 的安全升级检查
6. 若新实现合约通过 `proxiableUUID()` 校验，代理切换到新实现地址。
7. 如果传了升级后的初始化数据，代理会继续执行迁移调用。
8. 升级完成后，代理地址不变，旧状态保留，新逻辑生效。
9. 直接对实现合约地址调用 `initialize` 或 `upgradeToAndCall` 会回滚：
   - `initialize` 被 `_disableInitializers()` 锁住
   - `upgradeToAndCall` 要求必须通过代理上下文调用

## 4. 这三者的区别

- 透明代理：升级入口在 `ProxyAdmin` 侧
- UUPS：升级入口在实现合约侧
- `MyTokenContractV1`：你当前项目里实际用的是透明代理

## 5. 当前建议

如果你只是想把 `MyTokenContractV1` 继续维护下去，就按 OpenZeppelin 透明代理写法理解和部署。
如果你想做一套更轻的升级结构，再看 UUPS 示例就行。
