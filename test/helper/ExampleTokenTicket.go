package helper

import (
	"fmt"
	"github.com/bjartek/go-with-the-flow/v2/gwtf"
)

func CreateExampleTokenTicket(creator, redeemer string, amount float64, f *gwtf.GoWithTheFlow) (ticketID uint64, err error) {
	tokenAmountStr := fmt.Sprintf("%f", amount)

	events, err := f.TransactionFromFile("valet/create_ticket_example_token").
		UFix64Argument(tokenAmountStr).
		AccountArgument(redeemer).
		SignProposeAndPayAs(creator).RunE()
	ticketID = events[5].Value.Fields[0].ToGoValue().(uint64)
	return
}
