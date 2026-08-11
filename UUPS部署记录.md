# UUPS 部署、验证与发币记录

## 1. 网络与账户

- 网络：BSC Testnet
- RPC：`https://bsc-testnet-dataseed.bnbchain.org`
- Chain ID：`97`
- 部署账户：`0xDC03164a68335A61D0792aA1F6418E62528b8Cbe`
- 目标地址：`0xa9A6A25E8875ec942444B404c9d9Ca0B0C6dF17F`
- 代币：`UUPS Demo Token`
- 符号：`UDT`
- 精度：`18`

> 私钥不会写入此记录。部署前请在当前终端设置 `PRIVATE_KEY` 环境变量。

```bash
export PRIVATE_KEY=0x...
export RPC_URL=https://bsc-testnet-dataseed.bnbchain.org
```

## 2. 部署 UUPS V1

### 执行命令

```bash
PRIVATE_KEY="$PRIVATE_KEY" forge script \
  script/DeployUUPSDemo.s.sol:DeployUUPSDemo \
  --rpc-url "$RPC_URL" \
  --broadcast \
  -vvvv
```

### 部署结果

本次部署创建了两个合约：

| 合约 | 地址 | BscScan |
| --- | --- | --- |
| `UUPSDemoLogicV1` 实现合约 | `0x9e517Dd717D8a4e9C0EeE1E7B0F8C4AA2B7280DA` | [查看](https://testnet.bscscan.com/address/0x9e517Dd717D8a4e9C0EeE1E7B0F8C4AA2B7280DA) |
| `ERC1967Proxy` 代理合约 | `0xd780bf36a60fBc85Bad5C7C65E3cd7c80b4e51fE` | [查看](https://testnet.bscscan.com/address/0xd780bf36a60fBc85Bad5C7C65E3cd7c80b4e51fE) |

> MetaMask、自定义代币和业务调用都应使用代理地址
> `0xd780bf36a60fBc85Bad5C7C65E3cd7c80b4e51fE`，不要使用实现合约地址。

### 实现合约部署回执

- 交易哈希：`0x3a549b5072746403d67112cc790f4715140b0a0a8e145e816ae55d0714b002b1`
- [查看交易](https://testnet.bscscan.com/tx/0x3a549b5072746403d67112cc790f4715140b0a0a8e145e816ae55d0714b002b1)
- Status：`1 Success`
- 区块号：`124288725`
- 区块哈希：`0x2f301aa7020a652da4f3d533e2f39077981f43371125b4a0ca24fbae3a7e2142`
- From：`0xDC03164a68335A61D0792aA1F6418E62528b8Cbe`
- To：`null`，创建合约交易
- Contract Address：`0x9e517Dd717D8a4e9C0EeE1E7B0F8C4AA2B7280DA`
- Gas Used：`2,060,778`
- Effective Gas Price：`100,000,000 wei`，即 `0.1 gwei`
- 重要事件：`Initialized(18446744073709551615)`
- 含义：实现合约已通过 `_disableInitializers()` 锁定，不能直接初始化。

### 代理合约部署回执

- 交易哈希：`0x2722240254a7f63b300948c9a01011a8f0f10741ac2c69d81c1bcfc2db40cc91`
- [查看交易](https://testnet.bscscan.com/tx/0x2722240254a7f63b300948c9a01011a8f0f10741ac2c69d81c1bcfc2db40cc91)
- Status：`1 Success`
- 区块号：`124288725`
- 区块哈希：`0x2f301aa7020a652da4f3d533e2f39077981f43371125b4a0ca24fbae3a7e2142`
- From：`0xDC03164a68335A61D0792aA1F6418E62528b8Cbe`
- To：`null`，创建合约交易
- Contract Address：`0xd780bf36a60fBc85Bad5C7C65E3cd7c80b4e51fE`
- Gas Used：`268,413`
- Effective Gas Price：`100,000,000 wei`，即 `0.1 gwei`
- 重要事件：
  - `Upgraded(implementation = 0x9e517Dd717D8a4e9C0EeE1E7B0F8C4AA2B7280DA)`
  - `OwnershipTransferred(0x0000000000000000000000000000000000000000 -> 0xDC03164a68335A61D0792aA1F6418E62528b8Cbe)`
  - `Initialized(1)`

## 3. Sourcify 源码验证

### 验证实现合约

```bash
forge verify-contract \
  0x9e517Dd717D8a4e9C0EeE1E7B0F8C4AA2B7280DA \
  src/UUPSDemoLogicV1.sol:UUPSDemoLogicV1 \
  --chain 97 \
  --verifier sourcify \
  --creation-transaction-hash \
  0x3a549b5072746403d67112cc790f4715140b0a0a8e145e816ae55d0714b002b1 \
  --watch
```

- 状态：`exact_match`
- Verification Job ID：`86282519-492d-4429-bccd-09e69f07d590`
- [查看验证任务](https://sourcify.dev/server/v2/verify/86282519-492d-4429-bccd-09e69f07d590)

### 验证 ERC1967Proxy

```bash
forge verify-contract \
  0xd780bf36a60fBc85Bad5C7C65E3cd7c80b4e51fE \
  lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy \
  --chain 97 \
  --verifier sourcify \
  --creation-transaction-hash \
  0x2722240254a7f63b300948c9a01011a8f0f10741ac2c69d81c1bcfc2db40cc91 \
  --watch
```

- 状态：`exact_match`
- Verification Job ID：`319166ac-ecd3-4a67-95d4-4454756327f0`
- [查看验证任务](https://sourcify.dev/server/v2/verify/319166ac-ecd3-4a67-95d4-4454756327f0)

## 4. 向目标地址发放 99 个代币

### 执行命令

99 个代币按 18 位精度计算为：
`99 * 10^18 = 99000000000000000000`

```bash
PRIVATE_KEY="$PRIVATE_KEY" \
PROXY_ADDR=0xd780bf36a60fBc85Bad5C7C65E3cd7c80b4e51fE \
MINT_TO=0xa9A6A25E8875ec942444B404c9d9Ca0B0C6dF17F \
MINT_AMOUNT=99000000000000000000 \
forge script \
  script/MintUUPSDemo.s.sol:MintUUPSDemo \
  --rpc-url "$RPC_URL" \
  --broadcast \
  -vvvv
```

### 发币交易回执

- 交易哈希：`0xca0b77cc1b84f6bfe30af8168994156b27503b2aa6e7504b6908e2329e345431`
- [查看交易](https://testnet.bscscan.com/tx/0xca0b77cc1b84f6bfe30af8168994156b27503b2aa6e7504b6908e2329e345431)
- Status：`1 Success`
- 区块号：`124290171`
- 区块哈希：`0x9c785a30bf1898dc47257c887d7de6d4562da604f3b10567b4938f02d11da229`
- From：`0xDC03164a68335A61D0792aA1F6418E62528b8Cbe`
- To：`0xd780bf36a60fBc85Bad5C7C65E3cd7c80b4e51fE`
- Gas Used：`76,346`
- Effective Gas Price：`100,000,000 wei`，即 `0.1 gwei`
- 重要事件：
  - `Transfer`
  - From：`0x0000000000000000000000000000000000000000`
  - To：`0xa9A6A25E8875ec942444B404c9d9Ca0B0C6dF17F`
  - Amount：`99000000000000000000`，即 `99 UDT`

## 5. 链上校验命令

```bash
PROXY_ADDR=0xd780bf36a60fBc85Bad5C7C65E3cd7c80b4e51fE

cast call "$PROXY_ADDR" 'owner()(address)' \
  --rpc-url "$RPC_URL"

cast call "$PROXY_ADDR" 'version()(string)' \
  --rpc-url "$RPC_URL"

cast call "$PROXY_ADDR" 'name()(string)' \
  --rpc-url "$RPC_URL"

cast call "$PROXY_ADDR" 'symbol()(string)' \
  --rpc-url "$RPC_URL"

cast call "$PROXY_ADDR" 'balanceOf(address)(uint256)' \
  0xa9A6A25E8875ec942444B404c9d9Ca0B0C6dF17F \
  --rpc-url "$RPC_URL"

cast call "$PROXY_ADDR" 'totalSupply()(uint256)' \
  --rpc-url "$RPC_URL"

cast storage "$PROXY_ADDR" \
  0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc \
  --rpc-url "$RPC_URL"
```

## 6. 最终链上状态

- Owner：`0xDC03164a68335A61D0792aA1F6418E62528b8Cbe`
- Version：`UUPSDemoLogicV1`
- Token Name：`UUPS Demo Token`
- Symbol：`UDT`
- Decimals：`18`
- Proxy implementation：
  `0x9e517Dd717D8A4e9C0EeE1E7B0F8C4AA2B7280DA`
- 目标地址余额：`99 UDT`
- Total Supply：`99 UDT`
- 部署总 Gas：`2,329,191`
- 发币 Gas：`76,346`
- 部署和发币总 Gas 成本：约 `0.0002405537 BNB`

本次流程实际部署了两个合约：`UUPSDemoLogicV1` 和 `ERC1967Proxy`。
发币交易只是调用代理合约，没有创建新合约。
