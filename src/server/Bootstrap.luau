--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BuildConfig"))

assert(config.environment == "Test", "Foundation build must run in Test")
assert(not config.persistenceEnabled and not config.monetizationEnabled)
assert(workspace:WaitForChild("ShoreArt"):FindFirstChild("WelcomeSpawn"))
ReplicatedStorage:SetAttribute("BuildVersion", config.buildVersion)
print("Slime Salvage foundation ready; persistence and purchases disabled")
