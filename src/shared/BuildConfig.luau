--!strict
-- This build deliberately has no DataStore or purchase integration.
return table.freeze({
	buildVersion = "foundation-0.0.1",
	environment = "Test",
	balanceVersion = "balance-0.1.0",
	persistenceEnabled = false,
	monetizationEnabled = false,
})
