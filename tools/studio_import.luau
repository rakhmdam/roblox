-- Studio command-bar installer for the generated model; never an in-game entrypoint.
local RunService = game:GetService("RunService")
return function()
	assert(not RunService:IsRunning(), "Stop Play before importing")
	assert(game.GameId == 10773715101 and game.PlaceId > 0, "Open the existing Slime Salvage Test experience")
	local stage = script.Parent
	assert(stage.Parent == workspace and stage.Name == "SlimeSalvageImport", "Import the deployment model into Workspace")
	local storage = game:GetService("ServerStorage")
	assert(not storage:FindFirstChild("SlimeSalvageImportBackup"), "Inspect and remove the previous import backup first")
	local groups = {"World", "Shared", "Server", "Client", "Effects"}
	for _, name in groups do assert(stage:FindFirstChild(name), "Missing deployment group: " .. name) end
	for _, object in stage:GetDescendants() do
		if object:IsA("Script") or object:IsA("LocalScript") then
			assert(object.Disabled, "Imported entrypoints must be disabled")
		end
	end
	local settings = require(stage.Settings)
	local config = require(stage.Shared.BuildConfig)
	assert(config.environment == "Test" and config.monetizationEnabled == false, "Unexpected deployment configuration")
	local anchor = stage.World.shore:FindFirstChild("Garden")
	assert(anchor and anchor:IsA("BasePart"), "Missing world coordinate anchor")
	-- Import Roblox Model can reposition the inserted hierarchy. Restore authored coordinates.
	local correction = CFrame.new(table.unpack(settings.worldAnchor)) * anchor.CFrame:Inverse()
	local changeHistory = game:GetService("ChangeHistoryService")
	changeHistory:SetWaypoint("Before Slime Salvage import")
	for _, object in stage.World:GetDescendants() do
		if object:IsA("BasePart") then object.CFrame = correction * object.CFrame end
	end
	local backup = Instance.new("Folder")
	backup.Name = "SlimeSalvageImportBackup"
	backup.Parent = storage
	local function mount(object, destination, group)
		local previous = destination:FindFirstChild(object.Name)
		if previous then
			local folder = backup:FindFirstChild(group)
			if not folder then folder = Instance.new("Folder"); folder.Name = group; folder.Parent = backup end
			previous.Parent = folder
		end
		object.Parent = destination
	end
	for _, object in stage.World:GetChildren() do mount(object, workspace, "World") end
	workspace.CurrentCamera = workspace:FindFirstChild("Camera")
	mount(stage.Shared, game:GetService("ReplicatedStorage"), "Shared")
	for _, object in stage.Server:GetChildren() do mount(object, game:GetService("ServerScriptService"), "Server") end
	local client = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
	for _, object in stage.Client:GetChildren() do mount(object, client, "Client") end
	local lighting = game:GetService("Lighting")
	for _, object in stage.Effects:GetChildren() do mount(object, lighting, "Effects") end
	local warnings = {}
	for name, value in settings.lighting do
		local ok, err = pcall(function()
			if type(value) == "table" then value = Color3.new(table.unpack(value)) end
			if name == "LightingStyle" then value = Enum.LightingStyle.Realistic end
			lighting[name] = value
		end)
		if not ok then table.insert(warnings, name .. ": " .. tostring(err)) end
	end
	for name, value in settings.workspace do
		local ok, err = pcall(function() workspace[name] = value end)
		if not ok then table.insert(warnings, name .. ": " .. tostring(err)) end
	end
	game:GetService("ServerScriptService").Bootstrap.Disabled = false
	client.Bootstrap.Disabled = false
	workspace:SetAttribute("SlimeSalvageBuildHash", settings.sourceHash)
	stage.Name = "SlimeSalvageImportApplied"
	stage.Parent = storage
	changeHistory:SetWaypoint("After Slime Salvage import")
	print("SLIME_IMPORT_OK", settings.sourceHash, "Previous objects: ServerStorage.SlimeSalvageImportBackup")
	for _, message in warnings do warn("SLIME_IMPORT_PROPERTY", message) end
	return settings.sourceHash
end
