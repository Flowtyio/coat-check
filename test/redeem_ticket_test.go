package test

import (
	"testing"

	"github.com/bjartek/go-with-the-flow/v2/gwtf"
	"github.com/stretchr/testify/assert"

	"coat-check/test/helper"
)

func TestRedeemTicket_FT_success(t *testing.T) {
	tokenAmount := 100.0
	f := gwtf.NewGoWithTheFlowInMemoryEmulator()

	err := helper.ConfigureAndMintExampleToken(Creator, f)
	assert.Nil(t, err)

	err = helper.ConfigureExampleToken(Redeemer, f)
	assert.Nil(t, err)

	err = helper.MintFlowTokensToAccount(Creator, tokenAmount, f)
	assert.Nil(t, err)

	creatorFlowBalance, _ := helper.GetFlowTokenBalance(Creator, f)
	creatorETBalance, _ := helper.GetExampleTokenBalance(Creator, f)
	redeemerETBalance, _ := helper.GetExampleTokenBalance(Redeemer, f)
	assert.Equal(t, uint64(0), redeemerETBalance)

	ticketID, err := helper.CreateExampleTokenTicket(Creator, Redeemer, tokenAmount, f)
	assert.Nil(t, err)
	assert.NotNil(t, ticketID)

	creatorFlowBalanceAfterCreate, _ := helper.GetFlowTokenBalance(Creator, f)
	creatorETBalanceAfterCreate, _ := helper.GetExampleTokenBalance(Creator, f)
	redeemerETBalanceAfterCreate, _ := helper.GetExampleTokenBalance(Redeemer, f)

	assert.Greater(t, creatorFlowBalance, creatorFlowBalanceAfterCreate)
	assert.Greater(t, creatorETBalance, creatorETBalanceAfterCreate)
	assert.Equal(t, redeemerETBalance, redeemerETBalanceAfterCreate)

	// redeem the ticket.
	events, err := f.TransactionFromFile("valet/redeem_ticket_example_token").
		UInt64Argument(ticketID).
		SignProposeAndPayAs(Redeemer).
		RunE()
	assert.Nil(t, err)
	assert.Equal(t, 4, len(events))
	assert.Equal(t, "A.f8d6e0586b0a20c7.ExampleToken.TokensDeposited", events[0].Type) // give the redeemer our ticket's example tokens
	assert.Equal(t, "A.0ae53cb6e3f42a79.FlowToken.TokensWithdrawn", events[1].Type)    // withdraw the flow tokens which were given by the creator for making the ticket
	assert.Equal(t, "A.0ae53cb6e3f42a79.FlowToken.TokensDeposited", events[2].Type)    // return the flow tokens to the creator
	assert.Equal(t, "A.f8d6e0586b0a20c7.CoatCheck.TicketRedeemed", events[3].Type)     // mark the ticket as redeemed

	creatorFlowBalanceAfterRedeem, _ := helper.GetFlowTokenBalance(Creator, f)
	creatorETBalanceAfterRedeem, _ := helper.GetExampleTokenBalance(Creator, f)
	redeemerETBalanceAfterRedeem, _ := helper.GetExampleTokenBalance(Redeemer, f)
	assert.Equal(t, creatorFlowBalance, creatorFlowBalanceAfterRedeem)
	assert.Equal(t, creatorETBalance, creatorETBalanceAfterRedeem+redeemerETBalanceAfterRedeem)
	redeemerExampleTokensFloat := helper.FlowUFix64ToFloat64(redeemerETBalanceAfterRedeem)
	assert.Equal(t, redeemerExampleTokensFloat, tokenAmount)
}
