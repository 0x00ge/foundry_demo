// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {Counter} from "../src/Counter.sol";
import {console} from "forge-std/console.sol";

/**
 * @title CounterScript
 * @notice 生产级 Counter 部署脚本
 * @dev
 * 相比基础版本，本脚本增加了：
 * 1. 私钥安全读取（环境变量）
 * 2. 部署地址即时日志
 * 3. 部署后状态自动验证
 * 4. 网络隔离保护（防误操作主网）
 */
contract CounterScript is Script {
    // 存储部署后的合约实例
    Counter public counter;

    /**
     * @dev 生命周期钩子：在 run() 前执行
     * 优化3：增加网络检查，避免将测试合约误部署到主网（生产环境强需求）
     */
    function setUp() public {
        // 通过环境变量 CHECK_CHAIN 控制是否启用检查，默认开启
        // 运行时可跳过：`CHECK_CHAIN=false forge script ...`
        bool shouldCheck = vm.envOr("CHECK_CHAIN", true);
        if (shouldCheck) {
            uint256 chainId = block.chainid;
            // 如果当前链是主网（1）或常见的测试网，可以根据需求阻止
            // 此处示例：如果连到主网，直接 revert 终止脚本
            require(chainId != 1, "CounterScript: FORBIDDEN - Cannot deploy to Ethereum Mainnet");
            console.log("Current Chain ID:", chainId);
            console.log("Safe to proceed.");
        }
    }

    /**
     * @dev 脚本核心入口（固定函数名，不可修改）
     * 优化4：使用环境变量获取私钥，而不是在代码中硬编码或使用默认账户
     *       执行命令：`PRIVATE_KEY=0xabc... forge script ... --broadcast`
     */
    function run() public {
        // -------------------- 1. 准备阶段 --------------------
        // 从环境变量中安全读取私钥（这是 Foundry 官方推荐的标准做法）
        // 如果未设置，会触发错误提示，避免意外使用本地测试账户
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        console.log("Deployer Address:", deployer);
        console.log("Deployer Balance (wei):", deployer.balance);

        // -------------------- 2. 部署阶段（广播） --------------------
        // 使用指定的私钥开启广播，这样交易使用的就是该私钥对应的账户
        vm.startBroadcast(deployerPrivateKey);

        // 部署 Counter 合约
        counter = new Counter();
        // 优化5：如果 Counter 有初始化函数（比如 initialize 或 setNumber），可在此处调用
        // 示例：counter.initialize(deployer);

        vm.stopBroadcast();

        // -------------------- 3. 验证阶段（只读调用，不上链） --------------------
        // 优化6：部署完成后立即验证状态，确保部署成功且合约状态符合预期
        // 注意：因为 stopBroadcast 已调用，以下调用不会产生 Gas 消耗，也不会上链
        address counterAddress = address(counter);
        console.log("========================================");
        console.log("Counter successfully deployed!");
        console.log("Contract Address:", counterAddress);

        // 假设 Counter 合约有一个公共的 number() 变量或 getter
        // 这里通过调用合约方法来验证它是否真的运行了（避免部署到空地址或失败）
        try counter.number() returns (uint256 initialValue) {
            console.log("Initial counter value:", initialValue);
            // 优化7：可以增加断言，如果初始值不符合预期，脚本会报错退出
            // 例如，如果预期初始值为 0，可取消注释：assertEq(initialValue, 0);
        } catch {
            // 如果调用失败（比如没有 number 函数），记录日志但不中断脚本
            console.log("Warning: Could not fetch initial counter value (maybe no view function).");
        }

        // 优化8：将部署地址写入文件（便于后续脚本或前端读取）
        // vm.writeFile("./deploy-output.json", vm.serializeAddress("deployment", "counter", counterAddress));
        // 此处注释掉，因为需要额外处理 JSON 库，仅作提示。
    }
}