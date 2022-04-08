package helper

import (
	"fmt"

	"github.com/bjartek/go-with-the-flow/v2/gwtf"
)

const (
	DefaultTokenBalance = 1000
)

func ConfigureExampleToken(accountName string, flow *gwtf.GoWithTheFlow) (err error) {
	_, err = flow.TransactionFromFile("helpers/setup_account_ft").SignProposeAndPayAs(accountName).RunE()
	return
}

func MintExampleToken(accountName string, amount float64, flow *gwtf.GoWithTheFlow) (err error) {
	_, err = flow.TransactionFromFile("helpers/mint_example_ft").AccountArgument(accountName).UFix64Argument(fmt.Sprintf("%.2f", amount)).SignProposeAndPayAsService().RunE()
	return
}

func ConfigureAndMintWithAmountExampleToken(accountName string, amount float64, flow *gwtf.GoWithTheFlow) (err error) {
	err = ConfigureExampleToken(accountName, flow)
	if err != nil {
		return
	}

	err = MintExampleToken(accountName, amount, flow)
	return
}

func ConfigureAndMintExampleToken(accountName string, flow *gwtf.GoWithTheFlow) (err error) {
	err = ConfigureAndMintWithAmountExampleToken(accountName, DefaultTokenBalance, flow)
	return
}

func GetExampleTokenBalance(accountName string, flow *gwtf.GoWithTheFlow) (amount float64, err error) {
	val, err := flow.ScriptFromFile("get_balance_example_token").AccountArgument(accountName).RunReturns()
	amount = FlowUFix64ToFloat64(val.ToGoValue().(uint64))
	return
}
