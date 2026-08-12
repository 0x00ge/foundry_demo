

### 环境

- 部署账户：0xDC03164a68335A61D0792aA1F6418E62528b8Cbe
- 部署私钥：0xdab672c164c371e30650db8a53e4b6d0c4a63edfc1d1f7e839c174e4f2fc7943
- 测试网：https://bsc-testnet-dataseed.bnbchain.org
- 测试key：Q7RRJ6VZ43JIB8J97JU2U9SYBS8N29EGQY
- 目标地址：0xa9A6A25E8875ec942444B404c9d9Ca0B0C6dF17F

### 部署脚本

```bash
forge script script/DeployUUPSDemo.s.sol:DeployUUPSDemo \
  --private-key 0xdab672c164c371e30650db8a53e4b6d0c4a63edfc1d1f7e839c174e4f2fc7943 \
  --rpc-url https://bsc-testnet-dataseed.bnbchain.org \
  --etherscan-api-key Q7RRJ6VZ43JIB8J97JU2U9SYBS8N29EGQY \
  --verify \
  --broadcast
```

```bash
forge script script/DeployUUPSDemo.s.sol:DeployUUPSDemo \
  --rpc-url https://bsc-testnet-dataseed.bnbchain.org \
  --etherscan-api-key Q7RRJ6VZ43JIB8J97JU2U9SYBS8N29EGQY \
  --verify \
  --broadcast
```

### 输出结果

```bash
zhongtao@zhongtaodeMacBook-Pro foundry_demo % forge script script/DeployUUPSDemo.s.sol:DeployUUPSDemo \
  --rpc-url https://bsc-testnet-dataseed.bnbchain.org \
  --etherscan-api-key Q7RRJ6VZ43JIB8J97JU2U9SYBS8N29EGQY \
  --verify \
  --broadcast
[⠊] Compiling...
No files changed, compilation skipped
Warning: Detected artifacts built from source files that no longer exist. Run `forge clean` to make sure builds are in sync with project files.
 - /Users/zhongtao/IdeaProjects/solidityProjects/foundry_demo/src/utils/ERC20Upgradeable.sol
 - /Users/zhongtao/IdeaProjects/solidityProjects/foundry_demo/src/TransparentProxyDemoLogic.sol
 - /Users/zhongtao/IdeaProjects/solidityProjects/foundry_demo/src/utils/Initializable.sol
 - /Users/zhongtao/IdeaProjects/solidityProjects/foundry_demo/src/MyTokenContract.sol
 - /Users/zhongtao/IdeaProjects/solidityProjects/foundry_demo/src/utils/OwnableUpgradeable.sol
 - /Users/zhongtao/IdeaProjects/solidityProjects/foundry_demo/src/UUPSDemoLogic.sol
 - /Users/zhongtao/IdeaProjects/solidityProjects/foundry_demo/src/TransparentProxy.sol
 - /Users/zhongtao/IdeaProjects/solidityProjects/foundry_demo/src/utils/EmptyContract.sol
 - /Users/zhongtao/IdeaProjects/solidityProjects/foundry_demo/src/utils/ERC20BurnableUpgradeable.sol
Script ran successfully.

== Logs ==
  logic: 0xE0a314080f0479d508eb5E44791334ddb3B05d3D
  proxy: 0x5097f8757503d14F6F92fdC1B947B7B9AFb6a726
  owner: 0xDC03164a68335A61D0792aA1F6418E62528b8Cbe
  implementation: 0xE0a314080f0479d508eb5E44791334ddb3B05d3D
  version: UUPSDemoLogicV1

## Setting up 1 EVM.

==========================

Chain 97

Estimated gas price: 0.1 gwei

Estimated total gas used for script: 3027947

Estimated amount required: 0.0003027947 BNB

==========================

##### bsc-testnet
✅  [Success] Hash: 0x2fcc9d19c4bc0a4943d5bef6c8f7f796b0c6c681358c091cc0e31e1214c64131
Contract: UUPSDemoLogicV1
Contract Address: 0x5097f8757503d14F6F92fdC1B947B7B9AFb6a726
Block: 124600771
Paid: 0.0000268413 BNB (268413 gas * 0.1 gwei)


##### bsc-testnet
✅  [Success] Hash: 0x55cbd772bb7c0ca2453e599af0f7d9e7f3423bf3fc8726fe41de13dc918ff1ba
Contract: ERC1967Proxy
Contract Address: 0xE0a314080f0479d508eb5E44791334ddb3B05d3D
Block: 124600771
Paid: 0.0002060778 BNB (2060778 gas * 0.1 gwei)

✅ Sequence #1 on bsc-testnet | Total Paid: 0.0002329191 BNB (2329191 gas * avg 0.1 gwei)
                                                                                                                                                                                                                                         

==========================

ONCHAIN EXECUTION COMPLETE & SUCCESSFUL.
##
Start verification for (2) contracts
Start verifying contract `0xE0a314080f0479d508eb5E44791334ddb3B05d3D` deployed on bsc-testnet
EVM version: osaka
Compiler version: 0.8.35
ETHERSCAN_API_KEY is set, defaulting to Etherscan verifier. Unset it or pass `--verifier sourcify` (or another provider) to override.

Submitting verification for [src/UUPSDemoLogicV1.sol:UUPSDemoLogicV1] 0xE0a314080f0479d508eb5E44791334ddb3B05d3D.
Submitted contract for verification:
        Response: `OK`
        GUID: `k9fu5bpcbr6upxghcr6vcwzpq3u9d36rtukdcenqmrjw5vi7xx`
        URL: https://testnet.bscscan.com/address/0xe0a314080f0479d508eb5e44791334ddb3b05d3d
Contract verification status:
Response: `NOTOK`
Details: `Pending in queue`
Warning: Verification is still pending...; waiting 15 seconds before trying again (7 tries remaining)
Contract verification status:
Response: `OK`
Details: `Pass - Verified`
Contract successfully verified
Start verifying contract `0x5097f8757503d14F6F92fdC1B947B7B9AFb6a726` deployed on bsc-testnet
EVM version: osaka
Compiler version: 0.8.35
Constructor args: 000000000000000000000000e0a314080f0479d508eb5e44791334ddb3b05d3d00000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000024c4d66de8000000000000000000000000dc03164a68335a61d0792aa1f6418e62528b8cbe00000000000000000000000000000000000000000000000000000000
ETHERSCAN_API_KEY is set, defaulting to Etherscan verifier. Unset it or pass `--verifier sourcify` (or another provider) to override.

Submitting verification for [lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy] 0x5097f8757503d14F6F92fdC1B947B7B9AFb6a726.
Submitted contract for verification:
        Response: `OK`
        GUID: `4njjsv4les6f6kij3tqmqm7iatn9v3wqkufv3sfew4rwpngqc1`
        URL: https://testnet.bscscan.com/address/0x5097f8757503d14f6f92fdc1b947b7b9afb6a726
Contract verification status:
Response: `NOTOK`
Details: `Pending in queue`
Warning: Verification is still pending...; waiting 15 seconds before trying again (7 tries remaining)
Contract verification status:
Response: `NOTOK`
Details: `Already Verified`
Contract source code already verified
All (2) contracts were verified!

Transactions saved to: /Users/zhongtao/IdeaProjects/solidityProjects/foundry_demo/broadcast/DeployUUPSDemo.s.sol/97/run-latest.json

Sensitive values saved to: /Users/zhongtao/IdeaProjects/solidityProjects/foundry_demo/cache/DeployUUPSDemo.s.sol/97/run-latest.json


```

