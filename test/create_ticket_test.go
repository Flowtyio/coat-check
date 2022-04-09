package test

import (
	"fmt"
	"github.com/zeebo/assert"
	"testing"

	"github.com/bjartek/go-with-the-flow/v2/gwtf"

	"coat-check/test/helper"
)

func TestCreateTicket_FT_success(t *testing.T) {
	tokenAmount := 100.0
	tokenAmountStr := fmt.Sprintf("%f", tokenAmount)

	f := gwtf.NewGoWithTheFlowInMemoryEmulator()

	// get example token setup on our creator account
	err := helper.ConfigureAndMintExampleToken(Creator, f)
	assert.Nil(t, err)

	err = helper.MintFlowTokensToAccount(Creator, tokenAmount, f)
	assert.Nil(t, err)

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

}
