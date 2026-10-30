--!strict
-- Persistent Test build; Robux purchases remain disabled until separately implemented and accepted.
return table.freeze({
	buildVersion = "beta-implementation-0.1.0-dev",
	environment = "Test",
	balanceVersion = "balance-0.1.0",
	persistenceEnabled = true,
	monetizationEnabled = false,
	randomOperationsEnabled = true,
	analyticsEnabled = true,
	diagnosticsEnabled = true, -- Recorder is additionally restricted to environment Test.
	-- Bind only IDs of the project's uploaded audio. Empty IDs intentionally stay silent.
	audio = {music="rbxassetid://98622163948938",collect="rbxassetid://128692726294692",confirm="rbxassetid://99174934550714"},
})
