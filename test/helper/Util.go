package helper

func FlowUFix64ToFloat64(amount uint64) (f float64) {
	return float64(amount / 100000000.0)
}
