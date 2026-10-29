--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BuildConfig"))
local balance = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Balance"))
local Renderer = require(script.Parent:WaitForChild("SceneRenderer"))
local remote = ReplicatedStorage:WaitForChild("Session") :: RemoteEvent
local player = Players.LocalPlayer
local snapshot: any = nil
local revision = 0
local lastRequestAt = 0
local render = Renderer.start()

local function request(action: string, value: any?)
	if os.clock() - lastRequestAt < 0.22 then return end
	lastRequestAt = os.clock()
	remote:FireServer({protocolVersion=1, action=action, value=value,
		requestId=HttpService:GenerateGUID(false), nonce=if snapshot then snapshot.nonce else nil})
end

local gui = Instance.new("ScreenGui")
gui.Name = "BuildStatus"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")
local status = Instance.new("TextLabel")
status.Name = "Status"
status.Size = UDim2.new(1, -32, 0, 102)
status.Position = UDim2.fromOffset(16, 12)
status.BackgroundColor3 = Color3.fromRGB(30, 53, 54)
status.BackgroundTransparency = 0.15
status.TextColor3 = Color3.fromRGB(240, 242, 220)
status.TextWrapped = true
status.TextSize = 15
status.Font = Enum.Font.GothamMedium
status.Text = "SLIME SALVAGE · " .. config.buildVersion
	.. "\nПодключение… Прогресс этой сборки не сохраняется."
status.Parent = gui

local message = status:Clone()
message.Name = "Message"
message.Size = UDim2.new(1, -32, 0, 55)
message.Position = UDim2.fromOffset(16, 174)
message.Text = ""
message.Visible = false
message.Parent = gui

local menu = Instance.new("Frame")
menu.Name = "Menu"
menu.AnchorPoint = Vector2.new(0.5, 0.5)
menu.Position = UDim2.fromScale(0.5, 0.5)
menu.Size = UDim2.fromOffset(280, 150)
menu.BackgroundColor3 = Color3.fromRGB(30, 53, 54)
menu.Parent = gui
local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 4)
list.Parent = menu

local function button(parent: Instance, text: string, callback: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 46)
	b.BackgroundColor3 = Color3.fromRGB(152, 207, 137)
	b.TextColor3 = Color3.fromRGB(26, 48, 43)
	b.Text = text
	b.TextSize = 15
	b.TextWrapped = true
	b.Font = Enum.Font.GothamMedium
	b.Activated:Connect(callback)
	b.Parent = parent
	return b
end
local play = button(menu, "Играть", function() request("Play") end)
button(menu, "Что нового", function()
	message.Visible = true
	message.Text = "Берег: сбор, Росток, переработка, инструмент II. Сохранений пока нет."
end)
button(menu, "Как играть", function()
	message.Visible = true
	message.Text = "Нажми на хлам рядом. У станций появятся действия. Повторный выбор отменяет сбор."
end)

local actions = Instance.new("Frame")
actions.Size = UDim2.new(1, -32, 0, 48)
actions.Position = UDim2.fromOffset(16, 118)
actions.BackgroundTransparency = 1
actions.Visible = false
actions.Parent = gui
local actionList = Instance.new("UIGridLayout")
actionList.CellSize = UDim2.new(0.25, -4, 0, 48)
actionList.CellPadding = UDim2.fromOffset(4, 0)
actionList.Parent = actions
local stationAction: string? = nil
local station = button(actions, "Подойди к станции", function()
	if stationAction then request(stationAction, if stationAction == "Upgrade" then snapshot.profile.toolTier else nil) end
end)
local equip = button(actions, "Росток", function()
	request("Equip", not snapshot.profile.equipped)
end)
local skip = button(actions, "Пропустить обучение", function() request("Skip") end)
button(actions, "Меню / остановить сбор", function() request("Pause") end)

local tasks = {
	"Выбери хлам на берегу: подойди и нажми.",
	"Собери три предмета — получишь Ростка.",
	"Собери один предмет вместе с Ростком.",
	"Подойди к зелёному переработчику и продай груз.",
	"Подойди к коричневой мастерской: инструмент II за 30 монет.",
	"Посети фиолетовый питомник и посмотри вероятности.",
	"Обучение завершено! Бухта и дальнейшие улучшения появятся позже.",
}
local errors: {[string]: string} = {
	OutOfRange="Подойди ближе к ресурсу (до 14 studs).", BagFull="Рюкзак полон — отнеси груз переработчику.",
	StationRange="Подойди ближе к станции.", EmptyBag="Рюкзак пуст.",
	NotEnoughCoins="Не хватает монет.", MaxTier="В этом срезе доступен инструмент до уровня II.",
	FinishTutorialStep="Сначала выполни текущий шаг обучения.", Limit="Лимит склада: груз не списан.",
	NotPlaying="Нажми «Играть» и дождись появления персонажа.",
}
remote.OnClientEvent:Connect(function(state: any)
	if state.revision <= revision then return end
	revision = state.revision
	snapshot = state
	render(state)
	local p = state.profile
	play.Text = "Играть"
	menu.Visible = not p.playing
	actions.Visible = p.playing
	local value = 0
	for _, group in p.cargo do value += group.count * group.coins end
	status.Text = "SLIME SALVAGE · Зелёный берег · " .. tostring(p.coins) .. " монет"
		.. " · Рюкзак " .. tostring(p.count) .. "/12 (" .. tostring(value) .. " монет)"
		.. "\n" .. tasks[p.tutorial] .. "\nВнутренний тест: прогресс не сохраняется."
	equip.Text = if p.equipped then "Росток: убрать из команды" else "Росток: в команду"
	equip.Visible = p.slimeUid ~= nil
	skip.Visible = p.tutorial < 7
	if state.errorCode then
		message.Visible = true
		message.Text = errors[state.errorCode] or "Действие отклонено. Повтори после обновления состояния."
		task.delay(4, function() if snapshot == state then message.Visible = false end end)
	elseif p.playing then message.Visible = false end
	if p.tutorial == 7 and stationAction == "Nursery" then
		message.Visible = true
		message.Text = "Питомник (покупка ещё недоступна): Росток 55%, Капля 27%, Моховик 12%, Пыльцевик 5%, Солнечный 1%."
	end
end)

local function selectAt(screenPosition: Vector2)
	if not snapshot or not snapshot.profile.playing then return end
	local camera = workspace.CurrentCamera
	if not camera then return end
	local ray = camera:ViewportPointToRay(screenPosition.X, screenPosition.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = {workspace:WaitForChild("PersonalResources")}
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 200, params)
	if hit then request("Select", hit.Instance:GetAttribute("NodeId")) end
end
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		selectAt(Vector2.new(input.Position.X, input.Position.Y))
	elseif input.KeyCode == Enum.KeyCode.E and stationAction and snapshot then
		request(stationAction, if stationAction == "Upgrade" then snapshot.profile.toolTier else nil)
	end
end)
UserInputService.TouchTapInWorld:Connect(function(position, processed)
	if not processed then selectAt(position) end
end)

task.spawn(function()
	while true do
		task.wait(0.3)
		if not snapshot then request("Sync"); continue end
		local root = if player.Character then player.Character:FindFirstChild("HumanoidRootPart") else nil
		local art = workspace:FindFirstChild("ShoreArt")
		stationAction = nil
		local closest = balance.stationRange
		if root and root:IsA("BasePart") and art then
			for name, action in {RecyclerSample="Process", WorkshopSample="Upgrade", NurserySample="Nursery"} do
				local part = art:FindFirstChild(name)
				if part and part:IsA("BasePart") then
					local distance = (root.Position - part.Position).Magnitude
					if distance < closest then closest = distance; stationAction = action end
				end
			end
		end
		station.Visible = stationAction ~= nil
		station.Text = if stationAction == "Process" then "E · Переработать весь груз"
			elseif stationAction == "Upgrade" then "E · Инструмент II: 30 монет"
			else "E · Питомник: вероятности"
	end
end)
