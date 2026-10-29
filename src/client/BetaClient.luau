--!strict
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Input=game:GetService("UserInputService")
local Http=game:GetService("HttpService")
local shared=ReplicatedStorage:WaitForChild("Shared")
local C=require(shared:WaitForChild("Catalog"))
local text=require(shared:WaitForChild("Strings"))
local Renderer=require(script.Parent:WaitForChild("BetaRenderer"))
local Config=require(shared:WaitForChild("BuildConfig"))
local Audio=require(script.Parent:WaitForChild("AudioController"))
local Client={}
function Client.start()
	local player=Players.LocalPlayer
	local remote=ReplicatedStorage:WaitForChild("BetaSession") :: RemoteEvent
	local renderer=Renderer.start()
	local audio=Audio.start(Config)
	local lastCargo=0
	local state: any=nil
	local lang="ru"
	local currentPanel=""
	local tab="tool"
	local selectedIsland="shore"
	local chosenDecor="planter"
	local selectedSlime: string?=nil
	local recycleSelection: {[string]: boolean}={}
	local pending: any=nil
	local lastView=0
	local panelRevision=-1
	local lastGoal=0
	local goalChangedAt=os.clock()
	local goalStation: string?=nil
	local function t(key: string): string return text(key,lang) end
	local function named(item: any): string return item[lang] or item.en end
	local gui=Instance.new("ScreenGui"); gui.Name="SlimeSalvage"; gui.ResetOnSpawn=false; gui.IgnoreGuiInset=false
	gui.Parent=player:WaitForChild("PlayerGui")
	local hud=Instance.new("TextLabel"); hud.Size=UDim2.new(1,-24,0,90); hud.Position=UDim2.fromOffset(12,8)
	hud.BackgroundColor3=Color3.fromRGB(25,48,51); hud.TextColor3=Color3.fromRGB(241,241,216)
	hud.TextSize=15; hud.TextWrapped=true; hud.Font=Enum.Font.GothamMedium; hud.Text=t("connecting"); hud.Parent=gui
	local toast=hud:Clone(); toast.Name="Message"; toast.Size=UDim2.new(1,-24,0,48); toast.Position=UDim2.fromOffset(12,154)
	toast.Visible=false; toast.ZIndex=20; toast.Parent=gui
	local function notify(message: string)
		toast.Text=message; toast.Visible=true
		local captured=message
		task.delay(5,function() if toast.Text==captured then toast.Visible=false end end)
	end
	local function request(action: string,payload: any?)
		if action~="Sync" and not state then return end
		if state and state.busy and action~="Sync" then notify(t("saving")); return end
		local r={protocolVersion=2,requestId=Http:GenerateGUID(false),action=action,payload=payload or {},
			sessionNonce=if state then state.sessionNonce else nil}
		local transient={Sync=true,Play=true,Pause=true,Modal=true,Travel=true,VisitBase=true,ReturnHome=true,SelectTarget=true,SelectEvent=true,CancelTarget=true}
		if not transient[action] then
			if pending then notify(t("saving")); return end
			pending={request=r,sentAt=os.clock()}
		end
		remote:FireServer(r)
	end
	local function frame(parent: Instance,size: UDim2,position: UDim2): Frame
		local f=Instance.new("Frame"); f.Size=size; f.Position=position; f.BackgroundColor3=Color3.fromRGB(35,61,64); f.Parent=parent
		local corner=Instance.new("UICorner"); corner.CornerRadius=UDim.new(0,10); corner.Parent=f; return f
	end
	local function button(parent: Instance,title: string,callback: ()->(),enabled: boolean?): TextButton
		local b=Instance.new("TextButton"); b.Size=UDim2.new(1,-12,0,46); b.Text=title
		b.BackgroundColor3=if enabled==false then Color3.fromRGB(104,121,119) else Color3.fromRGB(164,213,146)
		b.TextColor3=Color3.fromRGB(25,46,42); b.Font=Enum.Font.GothamMedium; b.TextSize=15; b.TextWrapped=true
		b.AutoButtonColor=enabled~=false; b.Active=enabled~=false; b.Parent=parent
		if enabled~=false then b.Activated:Connect(callback) end
		local corner=Instance.new("UICorner"); corner.CornerRadius=UDim.new(0,7); corner.Parent=b; return b
	end
	local function label(parent: Instance,value: string): TextLabel
		local l=Instance.new("TextLabel"); l.Size=UDim2.new(1,-12,0,44); l.AutomaticSize=Enum.AutomaticSize.Y
		l.Text=value; l.TextColor3=Color3.fromRGB(236,238,219); l.BackgroundTransparency=1
		l.Font=Enum.Font.Gotham; l.TextSize=16; l.TextWrapped=true; l.TextXAlignment=Enum.TextXAlignment.Left; l.Parent=parent; return l
	end
	local function vertical(parent: Instance)
		local layout=Instance.new("UIListLayout"); layout.Padding=UDim.new(0,7); layout.SortOrder=Enum.SortOrder.LayoutOrder; layout.Parent=parent
		local pad=Instance.new("UIPadding"); pad.PaddingTop=UDim.new(0,8); pad.PaddingLeft=UDim.new(0,8); pad.PaddingBottom=UDim.new(0,12); pad.Parent=parent
	end
	local menu=frame(gui,UDim2.fromOffset(280,180),UDim2.new(0.5,-140,0.5,-70)); vertical(menu)
	menu.Visible=false
	local panel=frame(gui,UDim2.new(0.92,0,0.66,0),UDim2.fromScale(0.04,0.32)); panel.Visible=false; panel.ZIndex=5
	local panelTitle=label(panel,""); panelTitle.Size=UDim2.new(1,-140,0,44); panelTitle.Position=UDim2.fromOffset(12,0)
	local content=Instance.new("ScrollingFrame"); content.Size=UDim2.new(1,-16,1,-64); content.Position=UDim2.fromOffset(8,56)
	content.BackgroundTransparency=1; content.ScrollBarThickness=6; content.CanvasSize=UDim2.new(); content.AutomaticCanvasSize=Enum.AutomaticSize.Y
	content.ScrollingDirection=Enum.ScrollingDirection.Y; content.Parent=panel
	local toolbar=frame(gui,UDim2.new(1,-24,0,48),UDim2.fromOffset(12,102))
	local toolbarLayout=Instance.new("UIGridLayout"); toolbarLayout.CellSize=UDim2.new(1/7,-4,0,48); toolbarLayout.CellPadding=UDim2.fromOffset(4,0); toolbarLayout.Parent=toolbar
	local renderPanel: ()->()
	local function open(name: string)
		currentPanel=name; panel.Visible=name~=""; menu.Visible=state~=nil and not state.playing and name==""
		request("Modal",{open=name~=""}); renderPanel()
	end
	local close=button(panel,"×",function() open("") end)
	close.Size=UDim2.fromOffset(110,44); close.Position=UDim2.new(1,-120,0,6)
	local function confirm(title: string,callback: ()->())
		content:ClearAllChildren(); vertical(content); label(content,title)
		button(content,t("confirm"),function() callback(); renderPanel() end)
		button(content,t("cancel"),renderPanel)
	end
	local function spend(title: string,action: string,payload: any)
		confirm(title,function() request(action,payload) end)
	end
	local function money(price: number): string return tostring(price).." "..t("coins") end
	local function keys(tableValue: any): {string}
		local ids={}; for id in tableValue do table.insert(ids,id) end; table.sort(ids); return ids
	end
	local function islandControls()
		for _,id in C.order do
			button(content,(if selectedIsland==id then "✓ " else "")..named(C.islands[id]),function() selectedIsland=id; renderPanel() end)
		end
	end
	local function slimeTitle(uid: string): string
		local s=state.profile.slimes[uid]; local species=C.species[s.speciesId]
		return named(if s.evolutionId then C.evolutions[s.speciesId] else species).." · "..t("level").." "..s.level.." · "..t("rank").." "..s.rank
	end
	local function teamList(recycle: boolean)
		local p=state.profile
		for _,id in keys(p.slimes) do
			local s=p.slimes[id]
			local equipped=table.find(p.team,id)~=nil
			button(content,(if equipped then "✓ " elseif s.locked then "★ " else "")..slimeTitle(id),function()
				if recycle then recycleSelection[id]=not recycleSelection[id]; renderPanel()
				else selectedSlime=id; currentPanel="slime"; renderPanel() end
			end)
			if recycle and recycleSelection[id] then label(content,t("selected").." ✓") end
		end
	end
	renderPanel=function()
		content:ClearAllChildren(); vertical(content)
		close.Text=t("close")
		if not state or currentPanel=="" then return end
		local p=state.profile
		panelTitle.Text=t(currentPanel)
		if currentPanel=="map" then
			button(content,t("returnHome"),function() open(""); request("ReturnHome") end)
			for _,id in C.order do
				local item=C.islands[id]
				label(content,named(item).." · "..(if id=="shore" then "Plastic / Metal" elseif id=="bay" then "Metal · Breaker" else "Crystal · Sweeper"))
				if p.unlockedIslands[id] then button(content,t("travel"),function() request("Travel",{island=id}); open("") end)
				else
					button(content,t("unlock")..": "..money(item.price),function() spend(named(item).." — "..money(item.price),"UnlockIsland",{island=id}) end,
						p.coins>=item.price and p.unlockedIslands[C.order[item.index-1]]==true)
				end
			end
			label(content,t("guests"))
			for _,base in state.bases do
				if base.userId~=player.UserId then button(content,base.name.." · "..t("visit"),function() request("VisitBase",{userId=base.userId}); open("") end,base.guests) end
			end
		elseif currentPanel=="settings" then
			button(content,t("language")..": "..lang,function() request("UpdateSettings",{language=if lang=="ru" then "en" else "ru"}) end)
			for _,key in {"music","sound","lowEffects","reducedMotion","autoRepeat","allowGuests"} do
				button(content,t(key)..": "..t(if p.settings[key] then "active" else "inactive"),function() request("UpdateSettings",{[key]=not p.settings[key]}) end)
			end
		elseif currentPanel=="news" or currentPanel=="help" then
			label(content,t(if currentPanel=="news" then "newsText" else "helpText"))
			if p.tutorial.step<7 then button(content,t("skip"),function() spend(t("skip"),"SkipTutorial",{}) end) end
		elseif currentPanel=="recycler" then
			label(content,t("preview")..": "..money(state.preview.coins)..(if p.tutorial.step==4 then " +15 "..t("coins") else ""))
			for _,material in C.materials do label(content,material..": +"..state.preview.materials[material]) end
			button(content,t("process"),function() spend(t("process").." — "..money(state.preview.coins),"ProcessCargo",{}) end,state.preview.coins>0)
		elseif currentPanel=="shop" then
			for _,kind in {"tool","bag","storage","consumables","decor","trait"} do
				button(content,t(kind),function() tab=kind; renderPanel() end)
			end
			if C[tab] and table.find({"tool","bag","storage"},tab) then
				local tier=p.equipment[tab.."Tier"]; local item=C[tab]
				label(content,t(tab).." "..tier.." · "..item.values[tier])
				if item.prices[tier+1] then
					local price=item.prices[tier+1]
					button(content,t("buy").." "..t(tab).." "..(tier+1).." · "..money(price).." · "..named(C.islands[C.order[item.access[tier+1]]]),
						function() spend(t(tab).." "..(tier+1).." — "..money(price),"BuyUpgrade",{kind=tab,expectedTier=tier}) end,
						p.coins>=price and p.unlockedIslands[C.order[item.access[tier+1]]]==true)
				else label(content,t("MaxTier")) end
			elseif tab=="consumables" then
				local highest=if p.unlockedIslands.cave then "cave" elseif p.unlockedIslands.bay then "bay" else "shore"
				local price=C.islands[highest].tea
				label(content,t("tea").." · "..math.max(0,p.boosts.workTeaExpiresAt-state.serverTime).."s")
				button(content,t("buy").." · "..money(price),function() spend(t("tea").." — "..money(price),"BuyTea",{}) end,p.tutorial.step>=7 and p.coins>=price)
			elseif tab=="decor" then
				for _,id in C.decorOrder do
					local item=C.decor[id]
					button(content,named(item).." · "..(if p.base.ownedDecor[id] then "✓" else money(item.price)),function()
						if p.base.ownedDecor[id] then chosenDecor=id; currentPanel="decor"; renderPanel()
						else spend(named(item).." — "..money(item.price),"BuyDecoration",{itemId=id}) end
					end,p.base.ownedDecor[id] or (p.coins>=item.price and p.unlockedIslands[item.island]==true))
				end
			elseif tab=="trait" then
				label(content,t("traitNote"))
				button(content,t("tool"),function() selectedSlime=nil; currentPanel="trait"; renderPanel() end)
				teamList(false)
			end
		elseif currentPanel=="team" then
			label(content,t("team")..": "..#p.team.." / "..(if p.unlockedIslands.bay then 3 elseif p.tutorial.step>=7 then 2 else 1))
			button(content,t("autoTeam"),function()
				local ranked=keys(p.slimes)
				local function score(id: string): number
					local s=p.slimes[id]; local species=C.species[s.speciesId]
					local power=C.islands[species.island].power*C.rarityPower[species.rarity]*(1+0.12*(s.level-1))*(1+0.1*s.rank)*(if s.evolutionId then 1.2 else 1)
					if (if s.evolutionId then C.evolutions[s.speciesId].role else species.role)=="Breaker" and state.location=="bay" then power*=1.35 end
					return power
				end
				table.sort(ranked,function(a,b) local sa,sb=score(a),score(b); return if sa==sb then a<b else sa>sb end)
				local limit=if p.unlockedIslands.bay then 3 elseif p.tutorial.step>=7 then 2 else 1
				local team={}
				for _,id in p.team do if p.slimes[id].locked then table.insert(team,id) end end
				for _,id in ranked do if #team<limit and not table.find(team,id) then table.insert(team,id) end end
				spend(t("autoTeam"),"EquipTeam",{uids=team})
			end)
			button(content,t("recycle"),function() currentPanel="recycle"; renderPanel() end)
			teamList(false)
		elseif currentPanel=="slime" then
			local id=selectedSlime
			if not id then currentPanel="team"; renderPanel(); return end
			local s=p.slimes[id]
			if not s then currentPanel="team"; renderPanel(); return end
			local species=C.species[s.speciesId]; local evo=C.evolutions[s.speciesId]
			panelTitle.Text=slimeTitle(id)
			label(content,(if lang=="en" then C.rarityEn else C.rarityRu)[species.rarity].." · "..t(if s.evolutionId then evo.role else species.role).." · "..(s.traitId or "—"))
			local equipped=table.find(p.team,id)
			button(content,t(if equipped then "unequip" else "equip"),function()
				local team=table.clone(p.team)
				if equipped then table.remove(team,equipped) else table.insert(team,id) end
				request("EquipTeam",{uids=team})
			end)
			button(content,t(if s.locked then "unlockSlime" else "lock"),function() request("LockSlime",{uid=id,locked=not s.locked}) end)
			if s.level<10 then
				local price=math.ceil(20*C.islands[species.island].factor*s.level^1.7)
				button(content,t("level").." +1 · "..money(price),function() spend(t("level").." +1 — "..money(price),"LevelSlime",{uid=id,expectedLevel=s.level}) end,p.coins>=price)
			end
			if s.rank<3 then
				local price=C.rankPrices[s.rank+1]*C.rankFactors[species.rarity]
				button(content,t("rank").." +1 · "..price.." "..t("fragments"),function() spend(t("rank").." +1 — "..price.." "..species.island,"RankSlime",{uid=id,expectedRank=s.rank}) end,p.fragments[species.island]>=price)
			end
			if evo and not s.evolutionId then
				local title=t("evolve")..": "..named(evo).." · "..money(evo.coins).." + "..evo.amount.." "..evo.material
				button(content,title,function() spend(title,"EvolveSlime",{uid=id,recipeId=evo.id}) end,s.level>=3 and p.unlockedIslands[evo.island] and p.coins>=evo.coins and p.materials[evo.material]>=evo.amount)
			end
			button(content,t("trait"),function() currentPanel="trait"; renderPanel() end)
		elseif currentPanel=="recycle" then
			label(content,t("destructive")); teamList(true)
			local ids=keys(recycleSelection)
			local chosen={}; for _,id in ids do if recycleSelection[id] then table.insert(chosen,id) end end
			local reward={shore=0,bay=0,cave=0}
			for _,id in chosen do if p.slimes[id] then local sp=C.species[p.slimes[id].speciesId]; reward[sp.island]+=C.recycle[sp.rarity] end end
			label(content,t("preview")..": "..reward.shore.." / "..reward.bay.." / "..reward.cave.." "..t("fragments"))
			button(content,t("recycle").." ("..#chosen..")",function()
				spend(t("destructive").."\n"..t("recycle")..": "..#chosen,"RecycleSlimes",{uids=chosen})
			end,#chosen>0 and #chosen<=20)
		elseif currentPanel=="nursery" then
			islandControls()
			local item=C.islands[selectedIsland]; local weights=state.chances[selectedIsland]
			local total=0; for _,w in weights do total+=w end
			label(content,t("chanceNote"))
			local pity=p.incubators[selectedIsland]
			label(content,t("pity")..": "..(10-pity.sinceRare).." / "..(50-pity.sinceEpic).." / "..(200-pity.sinceLegendary))
			for i,id in C.sets[selectedIsland] do label(content,named(C.species[id])..": "..string.format("%.4f%%",weights[i]/total*100)) end
			button(content,t("incubate").." · "..money(item.incubation),function()
				spend(t("chanceNote").."\n"..money(item.incubation),"Incubate",{island=selectedIsland})
			end,p.unlockedIslands[selectedIsland] and p.coins>=item.incubation)
			for _,id in C.sets[selectedIsland] do
				local species=C.species[id]; local price=C.craft[species.rarity]
				button(content,t("craft")..": "..named(species).." · "..price.." "..t("fragments"),function()
					spend(named(species).." — "..price.." "..t("fragments"),"CraftSlime",{island=selectedIsland,speciesId=id})
				end,p.unlockedIslands[selectedIsland] and p.fragments[selectedIsland]>=price)
			end
		elseif currentPanel=="trait" then
			label(content,t("traitNote"))
			local offer=p.pendingTraitOffer
			if offer then
				label(content,offer.target..": "..offer.traitId)
				button(content,t("keep"),function() request("ResolveTrait",{offerId=offer.id,accept=false}) end)
				button(content,t("accept"),function() request("ResolveTrait",{offerId=offer.id,accept=true}) end)
			else
				local target=selectedSlime or "tool"
				local origin=if p.unlockedIslands.cave then "cave" elseif p.unlockedIslands.bay then "bay" else "shore"
				if target~="tool" and p.slimes[target] then origin=C.species[p.slimes[target].speciesId].island end
				local price=C.islands[origin].trait
				button(content,t("roll").." · "..money(price),function() spend(t("traitNote").."\n"..money(price),"RollTrait",{target=target}) end,p.unlockedIslands.bay and p.coins>=price)
			end
		elseif currentPanel=="decor" then
			panelTitle.Text=t("decor").." · "..named(C.decor[chosenDecor])
			for i=1,12 do
				local current=p.base.decorationSlots[tostring(i)]
				button(content,t("place").." "..i.." · "..(if current then named(C.decor[current]) else "—"),function()
					spend(t("place").." "..i,"PlaceDecoration",{itemId=chosenDecor,slot=i})
				end,i<=p.base.restorationTier*3 and state.location=="home")
				if current then button(content,t("clear").." "..i,function() request("PlaceDecoration",{itemId="",slot=i}) end,state.location=="home") end
			end
		elseif currentPanel=="collection" then
			label(content,t("materials")..": Plastic "..p.materials.Plastic.." · Metal "..p.materials.Metal.." · Crystal "..p.materials.Crystal)
			label(content,t("fragments")..": shore "..p.fragments.shore.." · bay "..p.fragments.bay.." · cave "..p.fragments.cave)
			local count=0; for _ in p.collections.slimeSpeciesIds do count+=1 end
			label(content,t("collection")..": "..count.." / 15")
			for _,id in C.speciesOrder do label(content,(if p.collections.slimeSpeciesIds[id] then "✓ " else "— ")..named(C.species[id])) end
			for _,island in C.order do for family=1,3 do for rarity=1,5 do
				local key=island.."/"..family.."/"..rarity
				label(content,named(C.islands[island]).." · "..C.materials[family].." · "..(if lang=="en" then C.rarityEn else C.rarityRu)[rarity]..": "..(p.collections.junkCountsByKey[key] or 0))
			end end end
			for _,recipe in C.evolutions do label(content,(if p.collections.evolutions[recipe.id] then "✓ " else "— ")..named(recipe)) end
		elseif currentPanel=="event" then
			label(content,t("eventNote"))
			label(content,tostring(state.event.hp).." / "..tostring(state.event.maxHp).." · "..tostring(state.event.cycles).." / 10")
			button(content,t("eventJoin"),function() open(""); request("SelectEvent") end,state.event.active)
		end
		panelRevision=p.revision
	end
	local function rebuildNavigation()
		menu:ClearAllChildren(); vertical(menu)
		button(menu,t("play"),function() request("Play"); open("") end)
		button(menu,t("settings"),function() open("settings") end)
		button(menu,t("news"),function() open("news") end)
		for _,child in toolbar:GetChildren() do if child:IsA("GuiButton") then child:Destroy() end end
		for _,name in {"map","team","collection","help","settings","event","menu"} do
			button(toolbar,t(name),function()
				if name=="menu" then request("Pause"); open("") else open(name) end
			end)
		end
	end
	rebuildNavigation()
	local station=button(gui,"",function()
		if goalStation then open(goalStation); if goalStation=="nursery" then request("ViewNursery") end end
	end)
	station.Size=UDim2.fromOffset(245,48); station.Position=UDim2.new(0.5,-122,1,-64); station.Visible=false
	remote.OnClientEvent:Connect(function(snapshot: any)
		if snapshot.phase~="Ready" then
			hud.Text=t(if snapshot.phase=="LoadError" then "loadError" else "loading")
			if snapshot.phase=="LoadError" then notify(t("loadError").." "..tostring(snapshot.errorCode)) end
			return
		end
		if snapshot.viewRevision<=lastView then return end
		lastView=snapshot.viewRevision
		local oldLang=lang
		state=snapshot; state.receivedAt=os.clock(); lang=state.profile.settings.language
		audio.settings(state.profile.settings)
		local cargo=0; for _,g in state.profile.cargo do cargo+=g.count end
		if cargo>lastCargo then audio.play("collect") end
		lastCargo=cargo
		renderer.update(snapshot)
		menu.Visible=not state.playing and currentPanel==""; toolbar.Visible=state.playing
		if oldLang~=lang then rebuildNavigation() end
		if snapshot.requestId and pending and pending.request.requestId==snapshot.requestId and snapshot.errorCode~="Saving" then
			pending=nil
			if snapshot.errorCode then notify(t(snapshot.errorCode)) else
				local result=snapshot.result
				notify(t("completed")..(if result and result.speciesId then " · "..named(C.species[result.speciesId]) else ""))
				audio.play("confirm")
			end
		elseif snapshot.errorCode then notify(t(snapshot.errorCode)) end
		if state.busy then notify(t("saving")) end
		if state.profile.pendingTraitOffer and currentPanel=="" then open("trait") end
		if currentPanel~="" and (panelRevision~=state.profile.revision or oldLang~=lang) then renderPanel() end
	end)
	local function targetAt(pos: Vector2)
		if not state or not state.playing or currentPanel~="" or state.busy then return end
		local camera=workspace.CurrentCamera; if not camera then return end
		local ray=camera:ScreenPointToRay(pos.X,pos.Y)
		local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Include; params.FilterDescendantsInstances={renderer.folder}
		local hit=workspace:Raycast(ray.Origin,ray.Direction*240,params)
		if hit then
			if hit.Instance:GetAttribute("EventTarget") then request("SelectEvent")
			elseif hit.Instance:GetAttribute("NodeId") then request("SelectTarget",{nodeId=hit.Instance:GetAttribute("NodeId")}) end
		end
	end
	Input.InputBegan:Connect(function(input,processed)
		if processed then return end
		if input.UserInputType==Enum.UserInputType.MouseButton1 then targetAt(Vector2.new(input.Position.X,input.Position.Y))
		elseif input.KeyCode==Enum.KeyCode.E and goalStation then open(goalStation); if goalStation=="nursery" then request("ViewNursery") end
		elseif input.KeyCode==Enum.KeyCode.Escape and currentPanel~="" then open("") end
	end)
	Input.TouchTapInWorld:Connect(function(pos,processed) if not processed then targetAt(pos) end end)
	task.spawn(function()
		while true do
			task.wait(0.3)
			if not state then request("Sync"); continue end
			local p=state.profile
			local amount=0; for _,g in p.cargo do amount+=g.count end
			if lastGoal~=p.tutorial.step then lastGoal=p.tutorial.step; goalChangedAt=os.clock() end
			local location=if C.islands[state.location] then named(C.islands[state.location]) else t("home")
			hud.Text="SLIME SALVAGE · "..location.." · "..money(p.coins).." · "..t("bag").." "..amount.."/"..C.bag.values[p.equipment.bagTier]
				.."\n"..t("goal"..p.tutorial.step)
			if amount>=C.bag.values[p.equipment.bagTier] then hud.Text..="\n"..t("BagFull") end
			if p.tutorial.step<7 and os.clock()-goalChangedAt>30 then hud.Text..="\n"..t("hint") end
			local remaining=state.event.nextAt-(state.serverTime+(os.clock()-(state.receivedAt or os.clock())))
			if state.returning then hud.Text..="\n"..t("returnHome") end
			if state.event.active then hud.Text..="\n"..t("event").." · "..math.ceil(state.event.hp).." HP"
			elseif remaining<=30 then hud.Text..="\n"..t("event").." · "..math.max(0,math.floor(remaining)).."s" end
			goalStation=nil
			local root=if player.Character then player.Character:FindFirstChild("HumanoidRootPart") else nil
			if root and root:IsA("BasePart") and state.location~="visit" then
				local origin=if C.islands[state.location] then Vector3.new(C.islands[state.location].x,0,0)
					else Vector3.new(((state.slot-1)%4-1.5)*150,0,-240-math.floor((state.slot-1)/4)*150)
				local range=16
				for name,offset in {recycler=Vector3.new(-16,4,18),shop=Vector3.new(16,3,18),nursery=Vector3.new(-17,2,-15)} do
					local d=(root.Position-origin-offset).Magnitude
					if d<range then goalStation=name; range=d end
				end
			end
			station.Visible=goalStation~=nil and state.playing and currentPanel==""
			station.Text="E · "..t(goalStation or "recycler")
			if pending and os.clock()-pending.sentAt>10 then
				pending.sentAt=os.clock(); remote:FireServer(pending.request)
			end
		end
	end)
end
return Client
