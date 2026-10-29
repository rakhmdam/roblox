--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local world = require(shared:WaitForChild("WorldConfig"))
local balance = require(shared:WaitForChild("Balance"))
local Renderer = {}

function Renderer.start()
	local folder = Instance.new("Folder")
	folder.Name = "PersonalResources"
	folder.Parent = workspace
	local nodes: {[number]: Part} = {}
	local labels: {[number]: TextLabel} = {}
	local billboards: {[number]: BillboardGui} = {}
	local selection = Instance.new("Highlight")
	selection.FillTransparency = 0.8
	selection.OutlineColor = Color3.fromRGB(255, 235, 148)
	selection.Parent = folder
	for id, v in world.positions do
		local part = Instance.new("Part")
		part.Name = "Junk_" .. tostring(id)
		part.Size = Vector3.new(2.6, 2.1, 2.6)
		part.Position = Vector3.new(v[1], v[2], v[3])
		part.Anchored = true
		part.CanCollide = false
		part:SetAttribute("NodeId", id)
		part.Parent = folder
		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.fromOffset(170, 44)
		billboard.StudsOffset = Vector3.new(0, 2.5, 0)
		billboard.MaxDistance = 26
		billboard.AlwaysOnTop = true
		billboard.Parent = part
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = Color3.fromRGB(29, 50, 52)
		label.BackgroundTransparency = 0.15
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextSize = 13
		label.Font = Enum.Font.GothamMedium
		label.Parent = billboard
		nodes[id] = part
		labels[id] = label
		billboards[id] = billboard
	end
	local slime = Instance.new("Model")
	slime.Name = "Росток"
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(2.7, 2, 2.5)
	body.Color = Color3.fromRGB(146, 221, 119)
	body.Material = Enum.Material.SmoothPlastic
	body.Anchored = true
	body.CanCollide = false
	body.CanQuery = false
	body.Parent = slime
	for _, x in {-0.5, 0.5} do
		local eye = body:Clone()
		eye.Name = "Eye"
		eye.Size = Vector3.new(0.23, 0.35, 0.2)
		eye.Color = Color3.fromRGB(28, 50, 48)
		eye.Position = Vector3.new(x, 0.2, -1.12)
		eye.Parent = slime
	end
	local leaf = body:Clone()
	leaf.Name = "Leaf"
	leaf.Size = Vector3.new(0.5, 1, 0.3)
	leaf.Position = Vector3.new(0.3, 1.2, 0)
	leaf.Color = Color3.fromRGB(48, 137, 79)
	leaf.Parent = slime
	slime.PrimaryPart = body
	local active = false
	local selected: number? = nil
	RunService.RenderStepped:Connect(function(dt)
		if not active then return end
		local character = Players.LocalPlayer.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if not root or not root:IsA("BasePart") then slime.Parent = nil; return end
		slime.Parent = folder
		local destination = root.Position + Vector3.new(3, -1.8, 2)
		if selected then destination = nodes[selected].Position + Vector3.new(2, 0.2, 0) end
		destination += Vector3.new(0, math.abs(math.sin(os.clock() * 5)) * 0.4, 0)
		slime:PivotTo(slime:GetPivot():Lerp(CFrame.new(destination), 1 - math.exp(-dt * 8)))
	end)
	return function(snapshot: any)
		active = snapshot.profile.equipped and snapshot.profile.slimeUid ~= nil
		if not active then slime.Parent = nil end
		selected = snapshot.selected
		selection.Adornee = if selected then nodes[selected] else nil
		for _, node in snapshot.nodes do
			local part = nodes[node.id]
			local alive = node.hp > 0
			part.Transparency = if alive then 0 else 1
			part.CanQuery = alive
			part.Color = if node.material == "Metal" then Color3.fromRGB(152, 176, 189)
				else Color3.fromRGB(222, 179, 112)
			billboards[node.id].Enabled = alive
			labels[node.id].Text = balance.rarityNames[node.rarity] .. " · " .. node.material
				.. "\n" .. tostring(math.ceil(node.hp)) .. "/" .. tostring(node.maxHp)
		end
	end
end

return Renderer
