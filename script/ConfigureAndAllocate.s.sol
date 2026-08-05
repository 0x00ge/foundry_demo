// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {MyTokenIsERC20} from "../src/MyTokenIsERC20.sol";

contract ConfigureAndAllocate is Script {
    function run() external {
        // 使用现有的代理地址
        address proxyAddress = 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9;
        MyTokenIsERC20 token = MyTokenIsERC20(proxyAddress);
        
        // 配置资金池地址
        MyTokenIsERC20.MyTokenIsERC20Pool memory pools = MyTokenIsERC20.MyTokenIsERC20Pool({
            miningPool: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
            directSalePool: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
            investorSalePool: 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC,
            ecosystemPool: 0x90F79bf6EB2c4f870365E982E1f101E93b906,
            foundationPool: 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65
        });
        
        // 开始广播（使用部署者的私钥）
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. 设置资金池地址（owner 操作）
        token.setPoolAddressByOwner(pools);
        console.log("Pool addresses configured successfully");
        
        // 2. 执行代币分配（manager 操作）
        // 因为 owner 和 manager 是同一个地址，可以直接调用
        token.setPoolAllocateByManager();
        console.log("Token allocation completed successfully");
        
        vm.stopBroadcast();
        
        // 打印结果
        console.log("=== Allocation Results ===");
        console.log("Total Supply:", token.totalSupply());
        console.log("Mining Pool (30%):", token.balanceOf(pools.miningPool));
        console.log("Direct Sale (20%):", token.balanceOf(pools.directSalePool));
        console.log("Investor Sale (10%):", token.balanceOf(pools.investorSalePool));
        console.log("Ecosystem (10%):", token.balanceOf(pools.ecosystemPool));
        console.log("Foundation (30%):", token.balanceOf(pools.foundationPool));
        console.log("Is Allocation Done:", token.isAllocation());
    }
}
