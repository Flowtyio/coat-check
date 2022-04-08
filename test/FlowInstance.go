package test

import (
	"os"
)

var (
	flowtyRoot string
)

const (
	Service  = "account"
	Creator  = "creator"
	Redeemer = "redeemer"
)

func init() {
	flowtyRoot = os.Getenv("FLOW_ROOT")
	err := os.Chdir(flowtyRoot)
	if err != nil {
		panic(err)
	}
}
