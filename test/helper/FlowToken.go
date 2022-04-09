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
