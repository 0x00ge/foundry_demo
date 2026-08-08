# 代理架构总览

这份文档把当前仓库里的三套代理写清楚：

1. `MyTokenContract` 使用透明代理
2. `TransparentProxy` 是你自己写的最小透明代理示例
3. `UUPSDemoLogic` 是最小 UUPS 示例

## 1. MyTokenContract

当前 `MyTokenContract` 不是 UUPS，而是透明代理体系。

对应文件：

- [src/MyTokenContract.sol](./src/MyTokenContract.sol)
- [script/DeployMyToken.s.sol](./script/DeployMyToken.s.sol)
- [test/MyTokenContractTest.t.sol](./test/MyTokenContractTest.t.sol)

### 运行方式

- 部署逻辑合约 `MyTokenContract`
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

## 2. 透明代理示例

这是一个最小透明代理实现，用来理解机制本身。

对应文件：

- [src/TransparentProxy.sol](./src/TransparentProxy.sol)
- [src/TransparentProxyDemoLogic.sol](./src/TransparentProxyDemoLogic.sol)
- [src/TransparentProxyDemoLogicV2.sol](./src/TransparentProxyDemoLogicV2.sol)
- [script/DeployTransparentProxy.s.sol](./script/DeployTransparentProxy.s.sol)
- [script/UpgradeTransparentProxy.s.sol](./script/UpgradeTransparentProxy.s.sol)
- [test/TransparentProxyTest.t.sol](./test/TransparentProxyTest.t.sol)

### 运行方式

- 部署 `TransparentProxyDemoLogic`
- 用 `TransparentProxy` 包一层
- 构造时把 `initialize` 的 calldata 一起传进去
- 通过代理调用业务函数

### 透明代理规则

- 普通用户的业务调用会被 `fallback` 转发到实现合约
- 管理员不能走普通业务调用路径
- 管理员只能做升级和改管理员

### 关键点

- 代理自己存 `implementation` 和 `admin`
- `fallback` 里用 `delegatecall`
- 升级只改实现地址，不改代理地址

## 3. UUPS 示例

UUPS 的核心思路是：升级逻辑写在实现合约里，不单独放 `ProxyAdmin`。

对应文件：

- [src/UUPSDemoLogic.sol](./src/UUPSDemoLogic.sol)
- [src/UUPSDemoLogicV2.sol](./src/UUPSDemoLogicV2.sol)
- [script/DeployUUPSDemo.s.sol](./script/DeployUUPSDemo.s.sol)
- [script/UpgradeUUPSDemo.s.sol](./script/UpgradeUUPSDemo.s.sol)
- [test/UUPSDemoTest.t.sol](./test/UUPSDemoTest.t.sol)

### 运行方式

- 部署 `UUPSDemoLogic`
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
- 一般会和 `OwnableUpgradeable` 或自定义权限控制一起用

## 4. 这三者的区别

- 透明代理：升级逻辑在代理/管理员侧
- UUPS：升级逻辑在实现合约侧
- `MyTokenContract`：你当前项目里实际用的是透明代理

## 5. 当前建议

如果你只是想把 `MyTokenContract` 继续维护下去，就按透明代理写法理解和部署。
如果你想做一套更轻的升级结构，再看 UUPS 示例就行。
