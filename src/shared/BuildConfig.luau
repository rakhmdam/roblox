--!strict
-- This build deliberately has no DataStore or purchase integration.
return table.freeze({
	buildVersion = "beta-implementation-0.1.0-dev",
	environment = "Test",
	balanceVersion = "balance-0.1.0",
	persistenceEnabled = true,
	monetizationEnabled = false,
	randomOperationsEnabled = true,
	analyticsEnabled = true,
	-- Bind only IDs of the project's uploaded audio. Empty IDs intentionally stay silent.
	audio = {music="rbxassetid://77885621577161",collect="rbxassetid://117150528054674",confirm="rbxassetid://104458299374083"},
})
