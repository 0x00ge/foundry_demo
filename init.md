# 项目初始化与脚本命令

## 1. 仓库初始化（一次性）

```shell
# 在已有 git 仓库中强制初始化 Foundry
forge init --force --use-parent-git

# 依赖
forge install OpenZeppelin/openzeppelin-contracts
forge install OpenZeppelin/openzeppelin-contracts-upgradeable

# 生成 / 更新 remappings.txt
forge remappings > remappings.txt
```

## 2. 编译 / 测试

```shell
forge build
forge test
forge fmt
```

## 3. 本地节点（可选）

```shell
# 终端 1：起本地链
anvil
```

Anvil 默认账户（仅本地，可直接写进命令行）：

| 角色 | 地址 | 私钥 |
|------|------|------|
| 部署者 / owner | `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266` | `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80` |
| manager | `0x70997970C51812dc3A010C7d01b50e0d17dc79C8` | `0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d` |

## 4. 部署脚本（不配环境变量）

脚本：`script/MyTokenIsERC20.s.sol:MyTokenIsERC20Script`  
入口：`run(address owner, address manager)` —— owner / manager 用 `--sig` 传，**不需要** `export` / `.env` / `-e`。

### 4.1 模拟执行（不上链）

```shell
forge script script/MyTokenIsERC20.s.sol:MyTokenIsERC20Script \
  --sig "run(address,address)" \
  0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
  0x70997970C51812dc3A010C7d01b50e0d17dc79C8 \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

### 4.2 广播上链（本地 Anvil）

```shell
forge script script/MyTokenIsERC20.s.sol:MyTokenIsERC20Script \
  --sig "run(address,address)" \
  0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
  0x70997970C51812dc3A010C7d01b50e0d17dc79C8 \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --broadcast
```

### 4.3 广播 + 浏览器验证（测试网 / 主网）

把地址、RPC、私钥、API Key 换成真实值：

```shell
forge script script/MyTokenIsERC20.s.sol:MyTokenIsERC20Script \
  --sig "run(address,address)" \
  0x你的owner地址 \
  0x你的manager地址 \
  --rpc-url https://eth-sepolia.g.alchemy.com/v2/你的KEY \
  --private-key 0x你的部署私钥 \
  --broadcast \
  --verify \
  --etherscan-api-key 你的EtherscanKey
```

成功后控制台会打印：

- `owner` / `manager`
- `deploy proxyMyToken` → **业务入口（Proxy）**，后续调用打这个地址
- `deploy myTokenImplementation` → 实现合约
- `deploy myTokenProxyAdmin` → ProxyAdmin

记下 Proxy 地址，下面用 `0xTokenProxy` 表示。

## 5. 部署后配置（cast，命令行直传）

对应：**B（owner）配池 → C（manager）分配**。

### 5.1 B：setPoolAddress（owner 私钥）

```shell
cast send 0xTokenProxy \
  "setPoolAddress((address,address,address,address,address))" \
  "(0xMiningPool,0xDirectSalePool,0xInvestorSalePool,0xEcosystemPool,0xFoundationPool)" \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

### 5.2 C：poolAllocate（manager 私钥）

```shell
cast send 0xTokenProxy \
  "poolAllocate()" \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
```

### 5.3 查询

```shell
cast call 0xTokenProxy "name()(string)" --rpc-url http://127.0.0.1:8545
cast call 0xTokenProxy "symbol()(string)" --rpc-url http://127.0.0.1:8545
cast call 0xTokenProxy "decimals()(uint8)" --rpc-url http://127.0.0.1:8545
cast call 0xTokenProxy "manager()(address)" --rpc-url http://127.0.0.1:8545
cast call 0xTokenProxy "isAllocation()(bool)" --rpc-url http://127.0.0.1:8545
cast call 0xTokenProxy "tokenBalance(address)(uint256)" 0xMiningPool --rpc-url http://127.0.0.1:8545
```

## 6. 调用顺序速记

```
A  forge script ... --sig "run(address,address)" <owner> <manager> --private-key ... --broadcast
B  cast send ... setPoolAddress --private-key <owner>
C  cast send ... poolAllocate   --private-key <manager>
D  cast send/call ... transfer 等
```

更细的角色分支见：`src/MyTokenIsERC20.md`。

## 7. 说明

- **不需要** `export`、`.env`、`-e`（你这版 forge 也不支持 `-e`）。
- owner / manager 用 `--sig "run(address,address)"` 传参。
- `--private-key` 只负责签名广播，应与传入的 owner 是同一把钥匙。
- Anvil 默认私钥仅用于本地；主网换成自己的密钥，不要提交到 git。
