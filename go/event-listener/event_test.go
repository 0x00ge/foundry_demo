package main

import (
	"fmt"
	"math/big"
	"strings"
	"testing"

	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/log"
)

const DistributeRewardEventABI = "DistributeReward(address,address,uint256)"

var DistributeRewardEventABIHash = crypto.Keccak256Hash([]byte(DistributeRewardEventABI))

const RewardManagerAddr = "0x72A6a0cbFD619D004bcde04B96572Ef8981e9A8f"

func TestEthClient_GetTxReceiptByHash(t *testing.T) {
	fmt.Println("test start for tx receipt")
	clint, err := NewEthClient("https://bsc-testnet.bnbchain.org")
	if err != nil {
		fmt.Println("New bnb client fail", err)
	}
	txReceipt, err := clint.GetTxReceiptByHash("0x679b68c114cdc514ee6a14f8e255b16d34fe8633a424074fca95d7235285633e")
	if err != nil {
		fmt.Println("get tx receipt fail", err)
	}

	addressType, err := abi.NewType("address", "address", nil)
	if err != nil {
		fmt.Println("new addressType abi type fail", err)
	}

	uint256Type, err := abi.NewType("uint256", "uint256", nil)
	if err != nil {
		fmt.Println("new uint256Type abi type fail", err)
	}

	rewardManagerArgs := abi.Arguments{
		{
			Name:    "tokenAddress",
			Type:    addressType,
			Indexed: true,
		}, {
			Name:    "recipient",
			Type:    addressType,
			Indexed: false,
		}, {
			Name:    "amount",
			Type:    uint256Type,
			Indexed: false,
		},
	}
	var rewardManager = make(map[string]interface{})
	for _, rLog := range txReceipt.Logs {
		fmt.Println("address====", rLog.Address.String())
		if strings.ToLower(rLog.Address.String()) != strings.ToLower(RewardManagerAddr) {
			log.Error("reward manager addr fail", "rLogAddress", rLog.Address.String(), "rewardManagerAddr", RewardManagerAddr)
			continue
		}
		if rLog.Topics[0] != DistributeRewardEventABIHash {
			log.Error("event abi hash is not same", "rLogAddress", rLog.Topics[0], "DistributeRewardEventABIHash", DistributeRewardEventABIHash)
			continue
		}
		if len(rLog.Data) > 0 {
			err = rewardManagerArgs.UnpackIntoMap(rewardManager, rLog.Data)
			if err != nil {
				fmt.Println("unpack data into mapping fail", err)
				continue
			}

			if rewardManager != nil {
				fmt.Println("tokenAddress====", rewardManager["tokenAddress"])
				fmt.Println("recipient====", rewardManager["recipient"])
				fmt.Println("amount====", rewardManager["amount"])
			}
		}
	}
}

func TestEthClient_GetLogs(t *testing.T) {
	startBlock := big.NewInt(119584932)
	endBlock := big.NewInt(119584934)
	var contractList []common.Address
	addressCm := common.HexToAddress(RewardManagerAddr)
	contractList = append(contractList, addressCm)
	clint, err := NewEthClient("https://bsc-testnet.bnbchain.org")
	if err != nil {
		fmt.Println("connect ethereum fail", "err", err)
		return
	}
	logList, err := clint.GetLogs(startBlock, endBlock, contractList)
	if err != nil {
		fmt.Println("get log fail", "err", err)
		return
	}

	addressType, err := abi.NewType("address", "address", nil)
	if err != nil {
		fmt.Println("new addressType abi type fail", err)
	}

	uint256Type, err := abi.NewType("uint256", "uint256", nil)
	if err != nil {
		fmt.Println("new uint256Type abi type fail", err)
	}

	rewardManagerArgs := abi.Arguments{
		{
			Name:    "tokenAddress",
			Type:    addressType,
			Indexed: true,
		}, {
			Name:    "recipient",
			Type:    addressType,
			Indexed: false,
		}, {
			Name:    "amount",
			Type:    uint256Type,
			Indexed: false,
		},
	}

	var rewardManager = make(map[string]interface{})
	for _, rLog := range logList {
		fmt.Println(rLog.Address.String())
		if strings.ToLower(rLog.Address.String()) != strings.ToLower(RewardManagerAddr) {
			log.Error("reward manager addr fail", "rLogAddress", rLog.Address.String(), "rewardManagerAddr", RewardManagerAddr)
			continue
		}
		if rLog.Topics[0] != DistributeRewardEventABIHash {
			log.Error("event abi hash is not same", "rLogAddress", rLog.Topics[0], "DistributeRewardEventABIHash", DistributeRewardEventABIHash)
			continue
		}
		if len(rLog.Data) > 0 {
			err := rewardManagerArgs.UnpackIntoMap(rewardManager, rLog.Data)
			if err != nil {
				fmt.Println("Unpack data into map fail", "err", err)
				continue
			}
			if rewardManager != nil {
				fmt.Println("tokenAddress====", rewardManager["tokenAddress"])
				fmt.Println("recipient====", rewardManager["recipient"])
				fmt.Println("amount====", rewardManager["amount"])
			}
			return
		}
	}
}
