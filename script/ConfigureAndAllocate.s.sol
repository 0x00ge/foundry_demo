// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {MyTokenIsERC20} from "../src/MyTokenContract.sol";

contract ConfigureAndAllocate is Script {
    function run() external {
        address proxyAddress = 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9;
        MyTokenIsERC20 token = MyTokenIsERC20(proxyAddress);
        
        // 使用硬编码的地址（去掉 0x 前缀试试）
        MyTokenIsERC20.MyTokenIsERC20Pool memory pools = MyTokenIsERC20.MyTokenIsERC20Pool({
            miningPool: address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266),
            directSalePool: address(0x70997970C51812dc3A010C7d01b50e0d17dc79C8),
            investorSalePool: address(0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC),
            ecosystemPool: address(0x90F79bf6EB2c4f870365E982E1f101E93b906),
            foundationPool: address(0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65)
        });
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        token.setPoolAddressByOwner(pools);
        console.log("Pool addresses configured");
        
        token.setPoolAllocateByManager();
        console.log("Token allocation done");
        
        vm.stopBroadcast();
        
        console.log("Total Supply:", token.totalSupply());
    }
}
