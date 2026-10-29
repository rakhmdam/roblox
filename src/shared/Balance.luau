--!strict
return table.freeze({
	version = "balance-0.1.0",
	toolPower = {4, 6}, toolPrices = {0, 30}, bagCapacity = 12,
	manualInterval = 0.8, slimeInterval = 1.2, slimePower = 2,
	manualRange = 14, stationRange = 16, respawnSeconds = 10,
	coinLimit = 1000000000, materialLimit = 1000000,
	rarityNames = {"Обычный", "Необычный", "Редкий", "Эпический", "Легендарный"},
	rarityWeights = {6000, 2500, 1000, 400, 100},
	hpMultipliers = {1, 1.3, 1.8, 2.6, 4},
	coinMultipliers = {1, 1.6, 2.5, 4, 7}, materialAmounts = {1, 2, 3, 5, 8},
})
