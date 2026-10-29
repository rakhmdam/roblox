--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local shared = ReplicatedStorage:WaitForChild("Shared")
local config = require(shared:WaitForChild("BuildConfig"))
local balance = require(shared:WaitForChild("Balance"))
local world = require(shared:WaitForChild("WorldConfig"))
local Domain = require(script.Parent:WaitForChild("Domain"))
type Session = {
	profile: Domain.Profile, nodes: {Domain.Node}, nonce: string,
	selected: number?, revision: number, tokens: number, tokenAt: number,
	seen: {[string]: boolean}, requestOrder: {string}, ready: boolean,
}
local sessions: {[Player]: Session} = {}
local rng = Random.new()
local art = workspace:WaitForChild("ShoreArt")
assert(config.environment == "Test" and not config.persistenceEnabled and not config.monetizationEnabled)
local remote = Instance.new("RemoteEvent")
remote.Name = "Session"
remote.Parent = ReplicatedStorage

local function position(id: number): Vector3
	local v = world.positions[id]
	return Vector3.new(v[1], v[2], v[3])
end

local function makeNode(id: number, profile: Domain.Profile): Domain.Node
	local rarity = Domain.chooseRarity(rng:NextInteger(1, 10000), balance.rarityWeights)
	if profile.collected < 4 then rarity = 1 end
	return Domain.newNode(id, rarity, if rng:NextNumber() < 0.7 then "Plastic" else "Metal", balance)
end

local function send(player: Player, session: Session, errorCode: string?)
	if not session.ready then return end
	session.revision += 1
	remote:FireClient(player, {revision=session.revision, nonce=session.nonce,
		profile=session.profile, nodes=session.nodes, selected=session.selected, errorCode=errorCode})
end

local function rootFor(player: Player): BasePart?
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then return root end
	return nil
end

local function near(player: Player, target: Vector3, distance: number): boolean
	local root = rootFor(player)
	if not root or (root.Position - target).Magnitude > distance then return false end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = if player.Character then {player.Character} else {}
	return workspace:Raycast(root.Position, target - root.Position, params) == nil
end

local function atStation(player: Player, name: string): boolean
	local root = rootFor(player)
	local station = art:FindFirstChild(name)
	return root ~= nil and station ~= nil and station:IsA("BasePart")
		and (root.Position - station.Position).Magnitude <= balance.stationRange
end

local function add(player: Player)
	if sessions[player] then return end
	local now = os.clock()
	local profile = Domain.newProfile(now)
	local nodes = {}
	for id = 1, #world.positions do nodes[id] = makeNode(id, profile) end
	sessions[player] = {profile=profile, nodes=nodes, nonce=HttpService:GenerateGUID(false),
		selected=nil, revision=0, tokens=10, tokenAt=now, seen={}, requestOrder={}, ready=false}
end
Players.PlayerAdded:Connect(add)
Players.PlayerRemoving:Connect(function(player) sessions[player] = nil end)
for _, player in Players:GetPlayers() do add(player) end

remote.OnServerEvent:Connect(function(player: Player, request: any)
	local s = sessions[player]
	if not s then return end
	local now = os.clock()
	s.tokens = math.min(10, s.tokens + (now - s.tokenAt) * 5)
	s.tokenAt = now
	if s.tokens < 1 then return end
	s.tokens -= 1
	if typeof(request) ~= "table" then return end
	local keys = 0
	for key in request do
		keys += 1
		if key ~= "action" and key ~= "requestId" and key ~= "nonce" and key ~= "value"
			and key ~= "protocolVersion" then return end
	end
	if keys > 5 or request.protocolVersion ~= 1 or typeof(request.action) ~= "string"
		or #request.action > 24 or typeof(request.requestId) ~= "string"
		or #request.requestId > 64 or not string.match(request.requestId, "^[%w%-]+$") then return end
	if request.action == "Sync" then s.ready = true; send(player, s); return end
	if request.nonce ~= s.nonce then send(player, s, "SessionExpired"); return end
	if s.seen[request.requestId] then send(player, s); return end
	s.seen[request.requestId] = true
	table.insert(s.requestOrder, request.requestId)
	if #s.requestOrder > 128 then s.seen[table.remove(s.requestOrder, 1)] = nil end
	local p = s.profile
	local err: string? = nil
	if request.action == "Play" then
		if not p.playing then p.lastManual = now; p.lastSlime = now end
		p.playing = true
	elseif request.action == "Pause" then p.playing = false; s.selected = nil
	elseif not p.playing or not rootFor(player) then err = "NotPlaying"
	elseif request.action == "Skip" then Domain.skip(p, HttpService:GenerateGUID(false))
	elseif request.action == "Cancel" then s.selected = nil
	elseif request.action == "Select" then
		local id = request.value
		if typeof(id) ~= "number" or id ~= id or id % 1 ~= 0 or id < 1 or id > #s.nodes then err = "NoTarget"
		elseif not near(player, position(id), balance.manualRange) then err = "OutOfRange"
		elseif s.nodes[id].hp <= 0 then err = "NoTarget"
		elseif p.count >= balance.bagCapacity then err = "BagFull"
		else
			s.selected = if s.selected == id then nil else id
			if s.selected then Domain.select(p) end
		end
	elseif request.action == "Process" then
		s.selected = nil
		if not atStation(player, "RecyclerSample") then err = "StationRange"
		else local _, reason = Domain.process(p, balance); err = reason end
	elseif request.action == "Upgrade" then
		s.selected = nil
		if not atStation(player, "WorkshopSample") then err = "StationRange"
		elseif typeof(request.value) ~= "number" then err = "StaleTier"
		else local _, reason = Domain.upgrade(p, request.value, balance); err = reason end
	elseif request.action == "Nursery" then
		s.selected = nil
		if not atStation(player, "NurserySample") then err = "StationRange"
		else local _, reason = Domain.viewNursery(p); err = reason end
	elseif request.action == "Equip" then
		if typeof(request.value) ~= "boolean" or not p.slimeUid then err = "NoSlime"
		else p.equipped = request.value; s.selected = nil end
	else err = "UnknownAction" end
	send(player, s, err)
end)

task.spawn(function()
	local lastSend = 0
	while true do
		task.wait(0.1)
		local now = os.clock()
		local publish = now - lastSend >= 0.2
		if publish then lastSend = now end
		for player, s in sessions do
			local changed = false
			for id, node in s.nodes do
				if node.hp <= 0 and now >= node.readyAt then
					s.nodes[id] = makeNode(id, s.profile)
					changed = true
				end
			end
			local id = s.selected
			if id then
				if not s.profile.playing or not near(player, position(id), balance.manualRange) then
					s.selected = nil; changed = true
				else
					local node = s.nodes[id]
					local uid = s.profile.slimeUid or HttpService:GenerateGUID(false)
					Domain.hit(s.profile, node, now, true, uid, balance)
					Domain.hit(s.profile, node, now, false, uid, balance)
					if node.hp <= 0 or s.profile.count >= balance.bagCapacity then s.selected = nil end
					if publish or not s.selected then changed = true end
				end
			end
			if changed then send(player, s) end
		end
	end
end)
print("Slime Salvage shore slice ready; session data only")
