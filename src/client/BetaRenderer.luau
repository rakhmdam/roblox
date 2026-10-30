--!strict
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local TweenService=game:GetService("TweenService")
local Debris=game:GetService("Debris")
local C=require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Catalog"))
local text=require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Strings"))
local Renderer={}
local rarityColors={Color3.fromRGB(206,217,212),Color3.fromRGB(127,221,143),Color3.fromRGB(114,180,255),Color3.fromRGB(207,141,249),Color3.fromRGB(255,213,106)}
local colors={Color3.fromRGB(145,218,112),Color3.fromRGB(121,204,230),Color3.fromRGB(93,155,106),
	Color3.fromRGB(235,198,110),Color3.fromRGB(255,223,96),Color3.fromRGB(149,176,174),
	Color3.fromRGB(170,154,131),Color3.fromRGB(158,175,204),Color3.fromRGB(231,138,91),
	Color3.fromRGB(104,142,165),Color3.fromRGB(163,143,217),Color3.fromRGB(233,193,230),
	Color3.fromRGB(130,202,208),Color3.fromRGB(202,172,240),Color3.fromRGB(235,231,255)}
local function part(parent: Instance,name: string,size: Vector3,offset: Vector3,color: Color3): Part
	local p=Instance.new("Part"); p.Name=name; p.Size=size; p.Position=offset; p.Color=color
	p.Anchored=true; p.CanCollide=false; p.CanTouch=false; p.Parent=parent; return p
end
local function label(parent: Instance,text: string): TextLabel
	local gui=Instance.new("BillboardGui"); gui.Size=UDim2.fromOffset(170,48); gui.StudsOffset=Vector3.new(0,3,0)
	gui.MaxDistance=45; gui.AlwaysOnTop=true; gui.Parent=parent
	local l=Instance.new("TextLabel"); l.Size=UDim2.fromScale(1,1); l.BackgroundTransparency=0.2
	l.BackgroundColor3=Color3.fromRGB(25,46,50); l.TextColor3=Color3.new(1,1,1); l.TextSize=13
	l.TextWrapped=true; l.Font=Enum.Font.GothamMedium; l.Text=text; l.Parent=gui; return l
end
function Renderer.start(): any
	local localPlayer=Players.LocalPlayer
	local mouse=localPlayer:GetMouse()
	local folder=Instance.new("Folder"); folder.Name="BetaClientArt"; folder.Parent=workspace
	local nodes: {[number]: any}={}; local slimes: {[string]: any}={}
	local highlight=Instance.new("Highlight"); highlight.FillTransparency=0.8
	highlight.OutlineColor=Color3.fromRGB(255,232,133); highlight.Parent=folder
	local eventModel=Instance.new("Model"); eventModel.Name="GiantWreck"
	local wreck=part(eventModel,"Wreck",Vector3.new(8,7,7),Vector3.zero,Color3.fromRGB(143,119,92))
	wreck:SetAttribute("EventTarget",true); eventModel.PrimaryPart=wreck
	for _,offset in {Vector3.new(-2,1,0),Vector3.new(2,-1,0),Vector3.new(0,2,1)} do
		local beam=part(eventModel,"HullRib",Vector3.new(9,0.45,0.6),offset,Color3.fromRGB(86,110,119))
		beam.CFrame*=CFrame.Angles(0,0,0.2); beam.CanQuery=false
	end
	local cabin=part(eventModel,"BrokenCabin",Vector3.new(4,3,4),Vector3.new(0,4,0),Color3.fromRGB(196,168,110)); cabin.CanQuery=false
	local window=part(eventModel,"CabinWindow",Vector3.new(2,1,0.2),Vector3.new(0,4,-2.1),Color3.fromRGB(78,127,143)); window.CanQuery=false
	local eventLabel=label(wreck,""); eventModel:PivotTo(CFrame.new(400,5,-50))
	local pointer=part(folder,"TutorialPointer",Vector3.one,Vector3.zero,Color3.new(1,1,1))
	pointer.Transparency=1; pointer.CanQuery=false
	local pointerLabel=label(pointer,"▼"); pointerLabel.TextSize=36; pointerLabel.BackgroundTransparency=1
	local snapshot: any=nil
	local function impact(position: Vector3,color: Color3,completed: boolean)
		if snapshot and (snapshot.profile.settings.lowEffects or snapshot.profile.settings.reducedMotion) then return end
		local ring=part(folder,"Impact",Vector3.new(.1,2.8,2.8),position-Vector3.new(0,.6,0),color)
		ring.Shape=Enum.PartType.Cylinder; ring.CanQuery=false; ring.Transparency=.4
		ring.CFrame*=CFrame.Angles(0,0,math.pi/2)
		local diameter=if completed then 4.8 else 3.5
		TweenService:Create(ring,TweenInfo.new(.25),{Size=Vector3.new(.1,diameter,diameter),Transparency=1}):Play()
		Debris:AddItem(ring,.3)
	end
	local function makeSlime(speciesId: string,evolved: boolean): Model
		local model=Instance.new("Model"); model.Name=speciesId
		local index=table.find(C.speciesOrder,speciesId) or 1
		local color=colors[index]
		local body=part(model,"Body",Vector3.new(2.7,2,2.5),Vector3.zero,color)
		body.Shape=Enum.PartType.Ball; body.Material=if evolved then Enum.Material.Metal else Enum.Material.SmoothPlastic
		for _,x in {-0.5,0.5} do
			local eye=part(model,"Eye",Vector3.new(0.23,0.34,0.2),Vector3.new(x,0.2,-1.12),Color3.fromRGB(25,45,46)); eye.Shape=Enum.PartType.Ball
			local glint=part(model,"EyeGlint",Vector3.new(.08,.1,.07),Vector3.new(x-.04,.28,-1.22),Color3.new(1,1,1)); glint.Shape=Enum.PartType.Ball
			local blush=part(model,"Cheek",Vector3.new(.34,.17,.12),Vector3.new(x*1.5,-.05,-1.05),Color3.fromRGB(237,163,154)); blush.Shape=Enum.PartType.Ball
		end
		local mouth=part(model,"Smile",Vector3.new(.3,.12,.12),Vector3.new(0,-.18,-1.24),Color3.fromRGB(48,69,66)); mouth.Shape=Enum.PartType.Ball
		local function detail(name: string,size: Vector3,pos: Vector3,tint: Color3,shape: Enum.PartType?): Part
			local p=part(model,name,size,pos,tint); if shape then p.Shape=shape end; return p
		end
		-- Silhouettes distinguish species even without their labels or colors.
		if speciesId=="shore_sprout" then
			for _,side in {-1,1} do
				local leaf=detail("Leaf",Vector3.new(1.2,0.3,0.6),Vector3.new(side*0.5,1.35,0),Color3.fromRGB(83,167,88),Enum.PartType.Ball)
				leaf.CFrame*=CFrame.Angles(0,0,side*0.5)
			end
		elseif speciesId=="shore_tide" then
			detail("Droplet",Vector3.new(0.9,1.3,0.9),Vector3.new(0,1.2,0),Color3.fromRGB(172,235,255),Enum.PartType.Ball)
		elseif speciesId=="shore_moss" then
			for i=-1,1 do detail("Moss",Vector3.new(0.9,0.7,0.9),Vector3.new(i*0.8,0.85,0.2),Color3.fromRGB(60,123,78),Enum.PartType.Ball) end
		elseif speciesId=="shore_pollen" then
			for i=0,4 do local a=i*math.pi*2/5; detail("Petal",Vector3.new(0.7,0.3,0.7),Vector3.new(math.cos(a)*0.6,1.25,math.sin(a)*0.6),Color3.fromRGB(255,233,169),Enum.PartType.Ball) end
		elseif speciesId=="shore_sun" then
			for i=0,7 do local a=i*math.pi/4; detail("SunRay",Vector3.new(0.35,0.45,0.35),Vector3.new(math.cos(a)*1.4,0.6+math.sin(a)*1.3,0.4),Color3.fromRGB(255,192,64)) end
		elseif speciesId=="bay_scrap" then
			detail("Lid",Vector3.new(2.4,0.25,2.3),Vector3.new(0,1.1,0),Color3.fromRGB(111,140,145))
		elseif speciesId=="bay_bolt" then
			detail("BoltHead",Vector3.new(1.5,0.4,1.3),Vector3.new(0,1.2,0),Color3.fromRGB(203,196,175))
		elseif speciesId=="bay_magnet" then
			for _,side in {-1,1} do detail("Pole",Vector3.new(0.5,1,0.6),Vector3.new(side*0.7,1.2,0),if side<0 then Color3.fromRGB(232,119,113) else Color3.fromRGB(116,173,228)) end
		elseif speciesId=="bay_furnace" then
			local fire=detail("FurnaceGlow",Vector3.new(0.8,0.5,0.2),Vector3.new(0,-0.4,-1.15),Color3.fromRGB(255,172,79)); fire.Material=Enum.Material.Neon
			detail("Chimney",Vector3.new(0.55,1,0.55),Vector3.new(0.7,1.25,0.4),Color3.fromRGB(109,100,96))
		elseif speciesId=="bay_titan" then
			for _,side in {-1,1} do detail("Armor",Vector3.new(0.8,1.1,1.5),Vector3.new(side*1.2,0.2,0),Color3.fromRGB(153,178,192)) end
		elseif speciesId=="cave_shard" or speciesId=="cave_quartz" then
			for i=-1,1 do
				local shard=detail("Shard",Vector3.new(0.45,if i==0 then 1.5 else 0.9,0.45),Vector3.new(i*0.6,1.1,0.2),color:Lerp(Color3.new(1,1,1),0.4))
				shard.CFrame*=CFrame.Angles(0,math.pi/4,-i*0.3)
			end
		elseif speciesId=="cave_echo" then
			for _,side in {-1,1} do detail("Ear",Vector3.new(0.5,1.2,0.4),Vector3.new(side*1,1,0),Color3.fromRGB(109,181,188),Enum.PartType.Ball) end
		elseif speciesId=="cave_prism" then
			for i=-1,1 do detail("PrismFin",Vector3.new(0.3,1.1,0.9),Vector3.new(i*0.6,1.15,0),Color3.fromHSV((i+1)/3,0.35,1)) end
		elseif speciesId=="cave_nova" then
			for i=0,4 do local a=i*math.pi*2/5; local star=detail("Star",Vector3.new(0.35,0.35,0.35),Vector3.new(math.cos(a)*1.5,1+math.sin(a),0),Color3.fromRGB(230,218,255),Enum.PartType.Ball); star.Material=Enum.Material.Neon end
		end
		if evolved then
			for _,side in {-1,1} do detail("EvolutionPlate",Vector3.new(0.4,1.2,1.9),Vector3.new(side*1.25,0,0),Color3.fromRGB(196,211,221)) end
		end
		local role=if evolved then C.evolutions[speciesId].role else C.species[speciesId].role
		local accent=part(model,"Role",Vector3.new(0.45,1,0.4),Vector3.new(0.2,1.3,0),color:Lerp(Color3.new(1,1,1),0.3))
		accent.Shape=if role=="Collector" then Enum.PartType.Ball elseif role=="Support" then Enum.PartType.Cylinder else Enum.PartType.Block
		if role=="Breaker" then accent.Size=Vector3.new(2.6,0.4,0.7) end
		if role=="Sweeper" then accent.CFrame*=CFrame.Angles(0,0,0.7) end
		if C.species[speciesId].rarity==5 then
			local crown=part(model,"Crown",Vector3.new(2.3,0.3,1.8),Vector3.new(0,1.7,0),Color3.fromRGB(246,209,104))
			crown.Material=Enum.Material.Neon
		end
		for _,p in model:GetChildren() do if p:IsA("BasePart") then p.CanQuery=false end end
		model.PrimaryPart=body; return model
	end
	RunService.RenderStepped:Connect(function(dt)
		if not snapshot then return end
		local character=localPlayer.Character
		local root=if character then character:FindFirstChild("HumanoidRootPart") else nil
		local nearest: number?=nil
		local closest=14
		if root and root:IsA("BasePart") then
			for id,entry in nodes do
				local distance=(entry.part.Position-root.Position).Magnitude
				if entry.model.Parent==folder and distance<closest then nearest=id; closest=distance end
			end
		end
		local hovered=mouse.Target
		local hoverId=if hovered then hovered:GetAttribute("NodeId") else nil
		for id,entry in nodes do
			entry.label.Parent.Enabled=snapshot.playing and (id==snapshot.selected or id==hoverId or id==nearest)
		end
		for _,item in slimes do
			local owner=Players:GetPlayerByUserId(item.userId)
			local root=if owner and owner.Character then owner.Character:FindFirstChild("HumanoidRootPart") else nil
			if not root or not root:IsA("BasePart") then item.model.Parent=nil; continue end
			item.model.Parent=folder
			local destination=root.Position+Vector3.new((item.index-2)*3.5,-1.8,3.5)
			if item.target then destination=Vector3.new(item.target[1],item.target[2],item.target[3])+Vector3.new(item.index*2-4,0,2) end
			if not snapshot.profile.settings.reducedMotion then destination+=Vector3.new(0,math.abs(math.sin(os.clock()*5+item.index))*0.45,0) end
			local facing=if item.target then Vector3.new(item.target[1],destination.Y,item.target[3]) else Vector3.new(root.Position.X,destination.Y,root.Position.Z)
			local pose=if (facing-destination).Magnitude>.1 then CFrame.lookAt(destination,facing) else CFrame.new(destination)
			if not snapshot.profile.settings.reducedMotion then
				if os.clock()-item.createdAt<1.2 then
					pose+=Vector3.new(0,math.abs(math.sin((os.clock()-item.createdAt)*math.pi*2))*0.7,0)
				elseif item.target then pose*=CFrame.Angles(0,0,math.sin(os.clock()*7)*.08) end
			end
			if (item.model:GetPivot().Position-destination).Magnitude>70 then item.model:PivotTo(pose)
			else item.model:PivotTo(item.model:GetPivot():Lerp(pose,1-math.exp(-dt*8))) end
		end
	end)
	return {
		folder=folder,
		preview=function(speciesId: string,evolved: boolean,parent: Instance): Model
			local model=makeSlime(speciesId,evolved); model.Parent=parent; return model
		end,
		update=function(state: any)
			snapshot=state
			local seen={}
			for _,node in state.nodes do
				seen[node.id]=true
				local entry=nodes[node.id]
				if not entry or entry.family~=node.family then
					if entry then entry.model:Destroy() end
					local model=Instance.new("Model"); model.Name="Junk"..tostring(node.id)
					local materialColors={Color3.fromRGB(216,177,115),Color3.fromRGB(148,177,190),Color3.fromRGB(171,139,216)}
					local p=part(model,"Body",Vector3.new(2.6,2.1,2.6),Vector3.zero,materialColors[node.family])
					p.Shape=if node.family==1 then Enum.PartType.Cylinder elseif node.family==2 then Enum.PartType.Block else Enum.PartType.Ball
					p.Material=if node.family==2 then Enum.Material.Metal elseif node.family==3 then Enum.Material.Glass else Enum.Material.SmoothPlastic
					p:SetAttribute("NodeId",node.id); model.PrimaryPart=p
					local function scrap(name: string,size: Vector3,position: Vector3,color: Color3,shape: Enum.PartType?): Part
						local piece=part(model,name,size,position,color); piece:SetAttribute("NodeId",node.id)
						if shape then piece.Shape=shape end; return piece
					end
					if node.family==1 then
						p.Size=Vector3.new(2,1.4,2); p.Color=Color3.fromRGB(212,174,117)
						local bottle=scrap("Bottle",Vector3.new(.7,1.8,.7),Vector3.new(-.8,.4,.6),Color3.fromRGB(119,182,164),Enum.PartType.Cylinder)
						bottle.CFrame*=CFrame.Angles(0,0,1.3)
						scrap("BottleCap",Vector3.new(.3,.3,.3),Vector3.new(-.7,1.3,.6),Color3.fromRGB(230,210,153))
						scrap("CrushedCup",Vector3.new(.85,.8,.85),Vector3.new(.8,.5,-.5),Color3.fromRGB(231,222,182),Enum.PartType.Cylinder)
					elseif node.family==2 then
						p.Size=Vector3.new(2.2,1.4,2.2)
						local plate=scrap("BentPlate",Vector3.new(2.6,.25,1.4),Vector3.new(0,1,0),Color3.fromRGB(114,145,153))
						plate.CFrame*=CFrame.Angles(0,.3,.25)
						for _,side in {-1,1} do
							local pipe=scrap("RustPipe",Vector3.new(1.8,.55,.55),Vector3.new(side*.7,.4,.5),Color3.fromRGB(173,128,91),Enum.PartType.Cylinder)
							pipe.CFrame*=CFrame.Angles(0,0,1.1)
						end
					else
						p.Size=Vector3.new(2.4,.9,2.4); p.Color=Color3.fromRGB(113,108,144); p.Material=Enum.Material.Slate
						for i=-1,1 do
							local shard=scrap("CrystalShard",Vector3.new(.7,if i==0 then 2 else 1.3,.7),Vector3.new(i*.7,.7,0),Color3.fromRGB(178+i*12,151+i*10,226))
							shard.CFrame*=CFrame.Angles(0,.7,-i*.2); shard.Material=Enum.Material.Glass
						end
					end
					local band=part(model,"RarityBand",Vector3.new(2.85,0.15,2.85),Vector3.new(0,-0.75,0),rarityColors[node.rarity])
					band.CanQuery=false
					entry={model=model,part=p,label=label(p,""),band=band,family=node.family}; nodes[node.id]=entry
				end
				entry.model:PivotTo(CFrame.new(node.position[1],node.position[2],node.position[3]))
				if entry.hp and node.hp<entry.hp then
					impact(Vector3.new(node.position[1],node.position[2],node.position[3]),rarityColors[node.rarity],node.hp<=0)
				end
				entry.hp=node.hp
				entry.model.Parent=if node.hp>0 then folder else nil
				local rarityNames=if state.profile.settings.language=="en" then C.rarityEn else C.rarityRu
				entry.label.Text=({"●","◆","★","✦","♛"})[node.rarity].." "..rarityNames[node.rarity].." · "..text(node.material,state.profile.settings.language).."\n"..math.ceil(node.hp).." / "..node.maxHp
				entry.band.Color=rarityColors[node.rarity]; entry.label.TextColor3=rarityColors[node.rarity]
				entry.label.Parent.AlwaysOnTop=not state.profile.settings.lowEffects
			end
			for id,entry in nodes do if not seen[id] then entry.model:Destroy(); nodes[id]=nil end end
			local target=if type(state.selected)=="number" then nodes[state.selected] else nil
			if not target and state.profile.tutorial.step<=3 then
				local root=Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
				local range=math.huge
				if root and root:IsA("BasePart") then
					for _,candidate in nodes do local d=(root.Position-candidate.part.Position).Magnitude
						if candidate.model.Parent==folder and d<range then range=d; target=candidate end end
				end
			end
			highlight.Adornee=if target then target.model else nil
			highlight.FillTransparency=if state.profile.settings.lowEffects then 1 else 0.8
			local tutorialStep=state.profile.tutorial.step
			pointer.Parent=if tutorialStep<7 and state.playing and (tutorialStep>=4 or target~=nil) then folder else nil
			if tutorialStep<=3 and target then pointer.Position=target.part.Position+Vector3.new(0,2,0)
			elseif tutorialStep>=4 and tutorialStep<=6 then
				local origin=if C.islands[state.location] then Vector3.new(C.islands[state.location].x,0,0)
					else Vector3.new(((state.slot-1)%4-1.5)*150,0,-240-math.floor((state.slot-1)/4)*150)
				local offset=if tutorialStep==4 then Vector3.new(-16,6,18) elseif tutorialStep==5 then Vector3.new(16,6,18) else Vector3.new(-17,6,-15)
				pointer.Position=origin+offset
			end
			seen={}
			for _,companion in state.companions do
				for index,s in companion.team do
					local key=tostring(companion.userId)..":"..s.uid; seen[key]=true
					local signature=s.speciesId..tostring(s.evolutionId)
					if not slimes[key] or slimes[key].signature~=signature then
						if slimes[key] then slimes[key].model:Destroy() end
						slimes[key]={model=makeSlime(s.speciesId,s.evolutionId~=nil),signature=signature,userId=companion.userId,index=index,createdAt=os.clock()}
					end
					slimes[key].index=index; slimes[key].target=companion.target
				end
			end
			for key,item in slimes do if not seen[key] then item.model:Destroy(); slimes[key]=nil end end
			eventModel.Parent=if state.event.active then folder else nil
			eventLabel.Text=if state.profile.settings.language=="en" then "Giant Wreck" else "Большой обломок"
			eventLabel.Text..="\n"..tostring(math.ceil(state.event.hp)).." / "..tostring(state.event.maxHp)
		end,
	}
end
return Renderer
