package helper

import (
	"fmt"
	"github.com/bjartek/go-with-the-flow/v2/gwtf"
)

func MintFlowTokensToAccount(account string, amount float64, flow *gwtf.GoWithTheFlow) (err error) {
	_, err = flow.TransactionFromFile("helpers/mint_flow_tokens").
		AccountArgument(account).
		UFix64Argument(fmt.Sprintf("%f", amount)).
		SignProposeAndPayAsService().
		RunE()
	return
}

func GetFlowTokenBalanceFloat64(accountName string, flow *gwtf.GoWithTheFlow) (amount float64, err error) {
	val, err := GetFlowTokenBalance(accountName, flow)
	if err != nil {
		return
	}

	amount = FlowUFix64ToFloat64(val)
	return
}

func GetFlowTokenBalance(accountName string, flow *gwtf.GoWithTheFlow) (amount uint64, err error) {
	val, err := flow.ScriptFromFile("get_flow_token_balance").AccountArgument(accountName).RunReturns()
	if err != nil {
		return
	}
	amount = val.ToGoValue().(uint64)
	return
}
