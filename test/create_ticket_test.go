package test

import (
	"fmt"
	"testing"

	"github.com/stretchr/testify/assert"

	"coat-check/test/helper"
)

func TestCreateTicket_FT_success(t *testing.T) {
	tokenAmount := 100.0
	tokenAmountStr := fmt.Sprintf("%f", tokenAmount)

	f := helper.NewGWTF()

	// get example token setup on our creator account
	err := helper.ConfigureAndMintExampleToken(Creator, f)
	assert.Nil(t, err)

	err = helper.MintFlowTokensToAccount(Creator, tokenAmount, f)
	assert.Nil(t, err)

	creatorFlowBalance, _ := helper.GetFlowTokenBalance(Creator, f)
	creatorETBalance, _ := helper.GetExampleTokenBalance(Creator, f)

	// make a ticket for 100 ExampleTokens
	events, err := f.TransactionFromFile("valet/create_ticket_example_token").
		UFix64Argument(tokenAmountStr).
		AccountArgument(Redeemer).
		SignProposeAndPayAs(Creator).RunE()
	assert.Nil(t, err)
	assert.Equal(t, 6, len(events))
	assert.Equal(t, "A.0ae53cb6e3f42a79.FlowToken.TokensWithdrawn", events[0].Type)    // withdraw storage fee
	assert.Equal(t, "A.f8d6e0586b0a20c7.ExampleToken.TokensWithdrawn", events[1].Type) // take example tokens
	assert.Equal(t, "A.0ae53cb6e3f42a79.FlowToken.TokensWithdrawn", events[2].Type)    // take only the storage fee amount required
	assert.Equal(t, "A.0ae53cb6e3f42a79.FlowToken.TokensDeposited", events[3].Type)    // deposit the storage fee
	assert.Equal(t, "A.0ae53cb6e3f42a79.FlowToken.TokensDeposited", events[4].Type)    // refund the rest
	assert.Equal(t, "A.f8d6e0586b0a20c7.CoatCheck.TicketCreated", events[5].Type)      // a ticket was made

	// the two FlowToken deposit events should equal the amount withdrawn
	withdraw := events[0].Value.Fields[0].ToGoValue().(uint64)
	dep1 := events[3].Value.Fields[0].ToGoValue().(uint64)
	dep2 := events[4].Value.Fields[0].ToGoValue().(uint64)

	assert.Equal(t, withdraw, dep1+dep2)

	creatorFlowBalanceAfter, _ := helper.GetFlowTokenBalance(Creator, f)
	creatorETBalanceAfter, _ := helper.GetExampleTokenBalance(Creator, f)
	assert.Greater(t, creatorFlowBalance, creatorFlowBalanceAfter)
	assert.Greater(t, creatorETBalance, creatorETBalanceAfter)
}
