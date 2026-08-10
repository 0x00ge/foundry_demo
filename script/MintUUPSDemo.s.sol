// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/UUPSDemoLogicV1.sol";

/**
 * @title MintUUPSDemo
 * @notice 通过 UUPS 代理向目标地址铸造代币。
 * @dev
 * 环境变量：
 * - PRIVATE_KEY：代理 owner 的私钥，必填
 * - PROXY_ADDR：UUPS 代理地址，必填
 * - MINT_TO：接收代币的目标地址，必填
 * - MINT_AMOUNT：铸造数量，按代币最小单位填写，必填
 */
contract MintUUPSDemo is Script {
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address proxyAddress = vm.envAddress("PROXY_ADDR");
        address target = vm.envAddress("MINT_TO");
        uint256 amount = vm.envUint("MINT_AMOUNT");

        UUPSDemoLogicV1 token = UUPSDemoLogicV1(proxyAddress);
        address caller = vm.addr(privateKey);
        require(token.owner() == caller, "UUPS mint: caller is not proxy owner");
        require(target != address(0), "UUPS mint: target is zero address");
        require(amount > 0, "UUPS mint: amount is zero");

        vm.startBroadcast(privateKey);
        token.mint(target, amount);
        vm.stopBroadcast();

        console2.log("proxy:", proxyAddress);
        console2.log("mintTo:", target);
        console2.log("amount:", amount);
        console2.log("balance:", token.balanceOf(target));
        console2.log("totalSupply:", token.totalSupply());
    }
}
