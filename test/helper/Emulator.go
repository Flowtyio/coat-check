package helper

import (
	"github.com/bjartek/go-with-the-flow/v2/gwtf"
	"github.com/onflow/flow-cli/pkg/flowkit/config"
	"github.com/onflow/flow-cli/pkg/flowkit/output"
)

func NewGWTF() *gwtf.GoWithTheFlow {
	return gwtf.NewGoWithTheFlow(config.DefaultPaths(), "emulator", true, output.ErrorLog).InitializeContracts().CreateAccounts("emulator-account")
}
