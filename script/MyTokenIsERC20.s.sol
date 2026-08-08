// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/MyTokenContract.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract DeployMyToken is Script {
    function run() external {
        // 从环境变量或命令行读取参数（可通过 vm.envAddress 或 set -e）
        address owner = vm.envAddress("OWNER_ADDR");      // 多签钱包
        address admin = vm.envAddress("ADMIN_ADDR");      // 业务管理员
        // 资金池地址（5个）
        address miningPool = vm.envAddress("MINING_POOL");
        address directSalePool = vm.envAddress("DIRECT_SALE_POOL");
        address investorSalePool = vm.envAddress("INVESTOR_SALE_POOL");
        address ecosystemPool = vm.envAddress("ECOSYSTEM_POOL");
        address foundationPool = vm.envAddress("FOUNDATION_POOL");

        vm.startBroadcast();

        // 1. 部署逻辑合约
        MyTokenContract logic = new MyTokenContract();

        // 2. 部署 ProxyAdmin
        ProxyAdmin proxyAdmin = new ProxyAdmin();

        // 3. 编码初始化数据
        bytes memory initData = abi.encodeWithSelector(
            MyTokenContract.initialize.selector,
            owner,
            admin
        );

        // 4. 部署透明代理
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(logic),
            address(proxyAdmin),
            initData
        );

        // 5. 可选：将 ProxyAdmin 的所有权转移给 owner（默认部署者为 owner）
        // 如果 owner 不是部署者，需转移
        if (proxyAdmin.owner() != owner) {
            proxyAdmin.transferOwnership(owner);
        }

        // 6. 通过代理配置资金池地址（owner 操作）
        MyTokenContract token = MyTokenContract(address(proxy));
        MyTokenContract.MyTokenContractPool memory pool = MyTokenContract.MyTokenContractPool({
            miningPool: miningPool,
            directSalePool: directSalePool,
            investorSalePool: investorSalePool,
            ecosystemPool: ecosystemPool,
            foundationPool: foundationPool
        });
        token.setPoolAddressByOwner(pool);

        vm.stopBroadcast();

        // 输出部署信息（便于日志）
        console.log("Logic deployed at:", address(logic));
        console.log("ProxyAdmin deployed at:", address(proxyAdmin));
        console.log("Proxy deployed at:", address(proxy));
        console.log("Token address (proxy):", address(token));
    }
}