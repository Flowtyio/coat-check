package test

import (
	"github.com/zeebo/assert"
	"testing"

	"github.com/bjartek/go-with-the-flow/v2/gwtf"

	"coat-check/test/helper"
)

func TestCreateTicket_FT_success(t *testing.T) {
	f := gwtf.NewGoWithTheFlowInMemoryEmulator()
	// get example token setup on our creator account
	err := helper.ConfigureAndMintExampleToken(Creator, f)
	assert.Nil(t, err)

}
