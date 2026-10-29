--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BuildConfig"))
local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "BuildStatus"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")
local status = Instance.new("TextLabel")
status.Name = "Status"
status.Size = UDim2.new(1, -32, 0, 72)
status.Position = UDim2.fromOffset(16, 12)
status.BackgroundColor3 = Color3.fromRGB(30, 53, 54)
status.BackgroundTransparency = 0.15
status.TextColor3 = Color3.fromRGB(240, 242, 220)
status.TextWrapped = true
status.TextSize = 18
status.Font = Enum.Font.GothamMedium
status.Text = "SLIME SALVAGE · " .. config.buildVersion
	.. "\nТестовая сцена. Сбор и сохранения ещё не подключены."
status.Parent = gui
