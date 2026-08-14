package main

import (
	"context"
	"math/big"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/ethereum/go-ethereum/log"
	"github.com/ethereum/go-ethereum/rpc"
)

// EthClient 封装了 go-ethereum 的 ethclient.Client，
// 提供与以太坊节点交互的常用方法。
type EthClient struct {
	client *ethclient.Client // 底层以太坊 RPC 客户端
}

// NewEthClient 根据给定的 RPC URL 创建一个新的 EthClient 实例。
// 参数:
//   - rpcUrl: 以太坊节点的 RPC 端点地址（例如 http://localhost:8545）
//
// 返回值:
//   - *EthClient: 初始化成功的客户端实例
//   - error: 如果连接失败或其他错误，返回非 nil 错误
func NewEthClient(rpcUrl string) (*EthClient, error) {
	// 使用 context.Background() 建立与节点的连接
	client, err := ethclient.DialContext(context.Background(), rpcUrl)
	if err != nil {
		log.Error("new eth client fail", "err", err)
		return nil, err
	}
	return &EthClient{client: client}, err
}

// GetTxReceiptByHash 通过交易哈希获取交易收据。
// 对应 JSON-RPC 方法 eth_getTransactionReceipt。
// 参数:
//   - txHash: 交易哈希的十六进制字符串（带 0x 前缀）
//
// 返回值:
//   - *types.Receipt: 交易收据对象，如果交易未确认或不存在则可能为 nil
//   - error: 如果查询失败则返回错误
func (eth *EthClient) GetTxReceiptByHash(txHash string) (*types.Receipt, error) {
	return eth.client.TransactionReceipt(context.Background(), common.HexToHash(txHash))
}

// GetLogs 根据区块范围及合约地址列表获取所有相关日志。
// 对应 JSON-RPC 方法 eth_getLogs。
// 参数:
//   - startBlock: 起始区块号（包含），可为 nil 表示从创世块开始
//   - endBlock: 结束区块号（包含），可为 nil 表示到最新块
//   - contractAddressList: 要过滤的合约地址列表，若为空则检索所有合约的日志
//
// 返回值:
//   - []types.Log: 匹配的日志切片
//   - error: 如果查询失败则返回错误
func (eth *EthClient) GetLogs(startBlock, endBlock *big.Int, contractAddressList []common.Address) ([]types.Log, error) {
	filterQueryParams := ethereum.FilterQuery{
		FromBlock: startBlock,
		ToBlock:   endBlock,
		Addresses: contractAddressList,
	}
	return eth.client.FilterLogs(context.Background(), filterQueryParams)
}

// GetBlockReceipt 根据区块哈希获取该区块内所有交易的收据，
// 并可选择只返回与给定合约地址相关的收据（通过 Addresses 过滤）。
// 对应 JSON-RPC 方法 eth_getBlockReceipts。
// 参数:
//   - blockHash: 区块哈希
//   - contractAddressList: 用于过滤收据的合约地址列表。注意：go-ethereum 的 BlockReceipts
//     方法本身不支持直接按地址过滤，该方法返回区块内所有收据，调用方可根据需要自行过滤。
//     此处保留参数以保持接口一致性，但在本实现中未使用过滤逻辑。
//
// 返回值:
//   - []*types.Receipt: 该区块内所有交易收据的切片
//   - error: 如果查询失败则返回错误
func (eth *EthClient) GetBlockReceipt(blockHash common.Hash, contractAddressList []common.Address) ([]*types.Receipt, error) {
	// 调用 ethclient 的 BlockReceipts 方法，传入区块哈希及是否包含未最终确认的区块（true 表示需要最终确认的块）
	blockReceipt, err := eth.client.BlockReceipts(context.Background(), rpc.BlockNumberOrHashWithHash(blockHash, true))
	if err != nil {
		log.Error("GetBlockReceipt fail", "err", err)
		return nil, err
	}
	// 注意：此处未对 contractAddressList 进行过滤，如需过滤，可在返回前遍历收据并检查其日志中的地址。
	return blockReceipt, nil
}
