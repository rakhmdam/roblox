--!strict
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Http=game:GetService("HttpService")
local shared=ReplicatedStorage:WaitForChild("Shared")
local C=require(shared:WaitForChild("Catalog"))
local Config=require(shared:WaitForChild("BuildConfig"))
local Protocol=require(shared:WaitForChild("Protocol"))
local Schema=require(script.Parent:WaitForChild("ProfileSchema"))
local Game=require(script.Parent:WaitForChild("GameDomain"))
local Store=require(script.Parent:WaitForChild("ProfileStore"))
local Resources=require(script.Parent:WaitForChild("ResourceService"))
local Base=require(script.Parent:WaitForChild("BaseService"))
local Analytics=require(script.Parent:WaitForChild("Analytics"))
local Server={}
function Server.start()
	assert(Config.persistenceEnabled and not Config.monetizationEnabled,"Only persistent free beta is implemented")
	local store=Store.new(Config,C)
	local remote=Instance.new("RemoteEvent"); remote.Name="BetaSession"; remote.Parent=ReplicatedStorage
	local sessions: {[Player]: any}={}
	local loading: {[Player]: boolean}={}
	local random=Random.new()
	local function integer(a: number,b: number): number return random:NextInteger(a,b) end
	local function uid(): string return Http:GenerateGUID(false) end
	local function root(player: Player): BasePart?
		local char=player.Character
		local human=if char then char:FindFirstChildOfClass("Humanoid") else nil
		local part=if char then char:FindFirstChild("HumanoidRootPart") else nil
		return if human and human.Health>0 and part and part:IsA("BasePart") then part else nil
	end
	local event: any={id="",active=false,nextAt=os.time()+600,endsAt=0,hp=0,maxHp=0,cycles={},last={},rewards={}}
	local eventPosition=Vector3.new(400,5,-50)
	local function send(player: Player,s: any,errorCode: string?,requestId: string?,result: any?)
		if not player.Parent or not s.ready then return end
		s.viewRevision+=1
		local chances={}
		for _,id in C.order do chances[id]=Game.weights(s.profile,id,C) end
		local publicBases={}
		local companions={}
		for owner,other in sessions do
			table.insert(publicBases,{userId=owner.UserId,name=owner.DisplayName,slot=other.slot,guests=other.profile.settings.allowGuests})
			local team={}
			for _,id in other.profile.team do
				local slime=other.profile.slimes[id]
				table.insert(team,{uid=id,speciesId=slime.speciesId,evolutionId=slime.evolutionId})
			end
			local selected=if type(other.selected)=="number" then other.nodes[other.selected] else nil
			table.insert(companions,{userId=owner.UserId,team=team,target=if selected then selected.position else nil})
		end
		remote:FireClient(player,{phase="Ready",requestId=requestId,success=errorCode==nil,errorCode=errorCode,
			result=result,sessionNonce=s.nonce,viewRevision=s.viewRevision,profileRevision=s.profile.revision,
			profile=s.profile,location=s.location,slot=s.slot,playing=s.playing,busy=s.busy,
			nodes=if C.islands[s.location] then s.nodes else {},selected=s.selected,
			chances=chances,bases=publicBases,companions=companions,preview=Game.preview(s.profile),serverTime=os.time(),
			event={id=event.id,active=event.active,nextAt=event.nextAt,endsAt=event.endsAt,hp=event.hp,maxHp=event.maxHp,
				cycles=event.cycles[player.UserId] or 0},returning=s.returnAt~=nil})
	end
	local function teleport(player: Player,s: any,location: string,visit: any?)
		s.selected=nil; s.returnAt=nil; s.location=location; s.visit=visit
		local pos=if C.islands[location] then Vector3.new(C.islands[location].x,5,24)
			else Base.origin(if visit then visit.slot else s.slot)+Vector3.new(0,5,22)
		if C.islands[location] then Resources.activate(s,location,integer,C,Game) end
		local part=root(player)
		if part then part.CFrame=CFrame.new(pos); part.AssemblyLinearVelocity=Vector3.zero end
		s.lastPosition=pos; s.lastPositionAt=os.clock(); s.movementAllowed=true
	end
	local function near(player: Player,s: any,coordinates: {number},range: number,los: boolean?): boolean
		local part=root(player)
		local destination=Vector3.new(coordinates[1],coordinates[2],coordinates[3])
		if not part or not s.movementAllowed or (part.Position-destination).Magnitude>range then return false end
		if los then
			local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances=if player.Character then {player.Character} else {}
			if workspace:Raycast(part.Position,destination-part.Position,params) then return false end
		end
		return true
	end
	local function station(player: Player,s: any,kind: string): boolean
		if s.location=="visit" then return false end
		local origin=if s.location=="home" then Base.origin(s.slot) else Vector3.new(C.islands[s.location].x,0,0)
		local offsets={recycler=Vector3.new(-16,4,18),shop=Vector3.new(16,3,18),nursery=Vector3.new(-17,2,-15)}
		local pos=origin+offsets[kind]
		return near(player,s,{pos.X,pos.Y,pos.Z},16)
	end
	local function mutate(player: Player,s: any,action: string,payload: any,id: string)
		if s.busy or s.leaving then send(player,s,"Saving",id); return end
		local fullId=s.nonce..":"..id
		for _,op in s.profile.recentDurableOperations do
			if op.id==fullId then send(player,s,nil,id,op.result); return end
		end
		s.busy=true; s.selected=nil; s.returnAt=nil
		local before=s.profile
		local candidate=Schema.clone(before)
		local ok,result=Game.apply(candidate,action,payload,{now=os.time(),uid=uid(),random=integer,
			randomEnabled=Config.randomOperationsEnabled},C)
		if not ok then s.busy=false; send(player,s,result,id); return end
		candidate.revision+=1; candidate.updatedAt=os.time()
		table.insert(candidate.recentDurableOperations,{id=fullId,result=result})
		if #candidate.recentDurableOperations>128 then table.remove(candidate.recentDurableOperations,1) end
		send(player,s,"Saving",id)
		s.pending={data=candidate,writeId=uid(),action=action,id=id,result=result}
		task.spawn(function()
			local pending=s.pending
			local err: string?=nil
			for attempt=1,5 do
				local saved,reason=store:save(s.handle,pending.data,pending.writeId)
				if saved then
					s.profile=pending.data; s.pending=nil; s.busy=false
					Base.paint(player,s,C)
					Analytics.economy(player,action,s.profile.coins-before.coins,s.profile.coins,Config.analyticsEnabled)
					if action=="ProcessCargo" and before.tutorial.step==4 then Analytics.funnel(player,6,"FirstProcess",Config.analyticsEnabled) end
					if action=="BuyUpgrade" and before.tutorial.step==5 and s.profile.tutorial.step==6 then Analytics.funnel(player,7,"FirstUpgrade",Config.analyticsEnabled) end
					if action=="ViewNursery" and before.tutorial.step==6 then Analytics.funnel(player,8,"TutorialCompleted",Config.analyticsEnabled) end
					if action=="Incubate" or action=="CraftSlime" or action=="EvolveSlime" or action=="UnlockIsland" then Analytics.custom(player,action,Config.analyticsEnabled) end
					if action=="SkipTutorial" then Analytics.custom(player,"TutorialSkipped",Config.analyticsEnabled) end
					send(player,s,nil,id,result); return
				end
				err=reason
				if reason=="LeaseLost" or reason=="RevisionConflict" then break end
				if attempt<5 then task.wait(math.min(8,2^(attempt-1))) end
			end
			-- Unknown write outcome remains frozen. Never roll back and let the user reroll.
			s.blocked=err or "SaveFailed"; send(player,s,s.blocked,id)
			if player.Parent then player:Kick("Сохранение недоступно / Save unavailable. Rejoin to recover the last confirmed profile.") end
		end)
	end
	local function join(player: Player)
		if loading[player] or sessions[player] then return end
		loading[player]=true
		task.delay(45,function()
			if loading[player] and player.Parent then player:Kick("Profile loading timed out. Please reconnect; existing data is unchanged.") end
		end)
		remote:FireClient(player,{phase="LoadingProfile"})
		local handle,err=store:load(player.UserId)
		loading[player]=nil
		if not handle then
			if player.Parent then
				remote:FireClient(player,{phase="LoadError",errorCode=err})
				task.delay(5,function() if player.Parent then player:Kick("Профиль не загружен / Profile unavailable. "..tostring(err)) end end)
			end
			return
		end
		local slot=Base.claim(player)
		if not slot or not player.Parent then
			store:save(handle,handle.data,uid(),true)
			if slot then Base.release(slot) end
			if player.Parent then player:Kick("Server full: maximum 8 players") end
			return
		end
		local s: any={owner=player,handle=handle,profile=handle.data,slot=slot,nonce=uid(),ready=false,viewRevision=0,
			location="home",playing=false,busy=false,fields={},nodes={},attackClocks={},hitCounts={},nextUid=uid,
			nextSave=os.clock()+integer(50,70),lastPositionAt=os.clock(),movementAllowed=true,
			limits={},seenTransient={},transientOrder={},playSecond=os.clock()}
		sessions[player]=s
		Base.paint(player,s,C)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("HumanoidRootPart",10)
			if sessions[player]==s then teleport(player,s,s.location,s.visit) end
		end)
		teleport(player,s,"home")
		Analytics.funnel(player,1,"ProfileLoaded",Config.analyticsEnabled)
	end
	local function bucket(s: any,name: string,rate: number,burst: number): boolean
		local now=os.clock(); local b=s.limits[name] or {tokens=burst,at=now}
		b.tokens=math.min(burst,b.tokens+(now-b.at)*rate); b.at=now; s.limits[name]=b
		if b.tokens<1 then return false end; b.tokens-=1; return true
	end
	local stationKinds={ProcessCargo="recycler",BuyUpgrade="shop",LevelSlime="shop",RankSlime="shop",EvolveSlime="shop",
		BuyTea="shop",RollTrait="shop",BuyDecoration="shop",Incubate="nursery",CraftSlime="nursery",ViewNursery="nursery"}
	local transient={Sync=true,Play=true,Pause=true,Modal=true,Travel=true,VisitBase=true,ReturnHome=true,
		SelectTarget=true,SelectEvent=true,CancelTarget=true}
	remote.OnServerEvent:Connect(function(player: Player,r: any)
		if not Protocol.validate(r) then return end
		local s=sessions[player]
		if not s then if r.action=="Sync" then task.spawn(join,player) end; return end
		if not bucket(s,"all",12,20) then return end
		if r.action=="Sync" then s.ready=true; send(player,s); return end
		if r.sessionNonce~=s.nonce then send(player,s,"SessionExpired",r.requestId); return end
		local category=if r.action=="SelectTarget" then "target" elseif transient[r.action] then "ui" else "economy"
		if not bucket(s,category,if category=="target" then 5 elseif category=="ui" then 4 else 2,
			if category=="target" then 10 else 4) then send(player,s,"RateLimit",r.requestId); return end
		if s.busy then send(player,s,"Saving",r.requestId); return end
		if not root(player) then send(player,s,"NotAlive",r.requestId); return end
		local action,v=r.action,r.payload
		if transient[action] then
			if s.seenTransient[r.requestId] then send(player,s,nil,r.requestId); return end
			s.seenTransient[r.requestId]=true; table.insert(s.transientOrder,r.requestId)
			if #s.transientOrder>128 then s.seenTransient[table.remove(s.transientOrder,1)]=nil end
		end
		if action~="ReturnHome" then s.returnAt=nil end
		if action=="Play" then
			s.playing=true; s.modal=false
			if s.profile.tutorial.step<7 and s.location=="home" then teleport(player,s,"shore") end
			Analytics.funnel(player,2,"PlayPressed",Config.analyticsEnabled)
		elseif action=="Pause" then s.playing=false; s.selected=nil
		elseif action=="Modal" then s.modal=v.open; s.selected=nil
		elseif action=="UpdateSettings" then mutate(player,s,action,v,r.requestId); return
		elseif not s.playing then send(player,s,"NotPlaying",r.requestId); return
		elseif action=="Travel" then
			if v.island=="home" then teleport(player,s,"home")
			elseif not C.islands[v.island] or not s.profile.unlockedIslands[v.island] then send(player,s,"LockedIsland",r.requestId); return
			else teleport(player,s,v.island) end
		elseif action=="VisitBase" then
			local guest=sessions[Players:GetPlayerByUserId(v.userId)]
			if not guest or not guest.profile.settings.allowGuests then send(player,s,"GuestsDisabled",r.requestId); return end
			teleport(player,s,"visit",guest)
		elseif action=="ReturnHome" then
			local part=root(player)
			s.selected=nil; s.returnAt=os.clock()+3; s.returnStart=part.Position
		elseif action=="CancelTarget" then s.selected=nil
		elseif action=="SelectTarget" then
			local node=s.nodes[v.nodeId]
			if s.modal or not C.islands[s.location] or not node or node.hp<=0 then send(player,s,"NoTarget",r.requestId); return end
			if not near(player,s,node.position,14,true) then send(player,s,"OutOfRange",r.requestId); return end
			if Game.cargoCount(s.profile)>=C.bag.values[s.profile.equipment.bagTier] then send(player,s,"BagFull",r.requestId); return end
			s.selected=if s.selected==v.nodeId then nil else v.nodeId
			if s.selected then
				if s.profile.tutorial.step==1 then s.profile.tutorial.step=2; Analytics.funnel(player,3,"FirstTarget",Config.analyticsEnabled) end
				for _,id in s.profile.team do s.attackClocks[id]=s.attackClocks[id] or os.clock() end
				s.attackClocks.manual=s.attackClocks.manual or os.clock()
			end
		elseif action=="SelectEvent" then
			if not event.active or s.location~="bay" or s.modal or not near(player,s,{400,5,-50},14,true) then send(player,s,"NoEvent",r.requestId); return end
			s.selected="event"
		elseif s.location=="visit" then send(player,s,"Ownership",r.requestId); return
		else
			local kind=stationKinds[action]
			if kind and not station(player,s,kind) then send(player,s,"StationRange",r.requestId); return end
			if (action=="Incubate" or action=="CraftSlime") and s.location~="home" and v.island~=s.location then send(player,s,"StationRange",r.requestId); return end
			if action=="PlaceDecoration" and (s.location~="home" or v.slot<1 or v.slot>12) then send(player,s,"SlotLocked",r.requestId); return end
			mutate(player,s,action,v,r.requestId); return
		end
		send(player,s,nil,r.requestId)
	end)

	local function leave(player: Player)
		local s=sessions[player]; if not s or s.leaving then return end
		s.leaving=true
		local deadline=os.clock()+20
		while s.busy and not s.blocked and os.clock()<deadline do task.wait(0.1) end
		if not s.busy then
			s.busy=true; s.profile.revision+=1; s.profile.updatedAt=os.time()
			local writeId=uid()
			for attempt=1,3 do
				if store:save(s.handle,s.profile,writeId,true) then break end
				if os.clock()>=deadline then break end
				task.wait(1)
			end
		end
		sessions[player]=nil; Base.release(s.slot)
	end
	Players.PlayerAdded:Connect(function(player) task.spawn(join,player) end)
	Players.PlayerRemoving:Connect(leave)
	for _,p in Players:GetPlayers() do task.spawn(join,p) end
	game:BindToClose(function()
		for p in sessions do task.spawn(leave,p) end
		local deadline=os.clock()+25
		while next(sessions) and os.clock()<deadline do task.wait(0.1) end
	end)
	local function finishEvent(success: boolean)
		event.active=false
		for p,s in sessions do
			if (event.cycles[p.UserId] or 0)>=10 then event.rewards[p.UserId]={success=success} end
			if s.selected=="event" then s.selected=nil end
		end
	end
	task.spawn(function()
		local lastBroadcast=0
		local lastHeartbeat=0
		while true do
			task.wait(0.1); local now,wall=os.clock(),os.time()
			local broadcast=now-lastBroadcast>=0.3
			local heartbeat=now-lastHeartbeat>=2
			if heartbeat then lastHeartbeat=now end
			if broadcast then lastBroadcast=now end
			if not event.active and wall>=event.nextAt then
				local count=0; for _,s in sessions do if s.profile.unlockedIslands.bay then count+=1 end end
				event={id=uid(),active=true,nextAt=wall+600,endsAt=wall+180,hp=120*math.max(1,count),
					maxHp=120*math.max(1,count),cycles={},last={},rewards={}}
			end
			if event.active and wall>=event.endsAt then finishEvent(false) end
			for p,s in sessions do
				local part=root(p)
				if part then
					local old=s.lastPosition
					if old then
						local delta=Vector3.new(part.Position.X-old.X,0,part.Position.Z-old.Z).Magnitude
						s.movementAllowed=delta<=60*(now-s.lastPositionAt)+4
						if not s.movementAllowed then part.CFrame=CFrame.new(old); s.selected=nil end
					end
					s.lastPosition=part.Position; s.lastPositionAt=now
					if s.returnAt and (part.Position-s.returnStart).Magnitude>2 then s.returnAt=nil end
					if s.returnAt and now>=s.returnAt then teleport(p,s,"home") end
					if part.Position.Y< -25 then teleport(p,s,if C.islands[s.location] then s.location else "home") end
					if s.visit and (not s.visit.profile.settings.allowGuests or sessions[s.visit.owner]~=s.visit) then
						teleport(p,s,"home")
					end
				end
				if wall>=s.handle.expires and not s.busy then s.blocked="LeaseExpired"; s.busy=true; p:Kick("Profile lease expired. Please rejoin.") end
				if not s.busy then
					local oldTutorialStep=s.profile.tutorial.step
					local changed=Resources.tick(s,now,wall,integer,C,Game,function(coords: {number},range: number)
						return near(p,s,coords,range,true)
					end)
					if oldTutorialStep==2 and s.profile.tutorial.step==3 then
						Analytics.funnel(p,4,"ThreeCollected",Config.analyticsEnabled)
						Analytics.funnel(p,5,"SlimeGranted",Config.analyticsEnabled)
					end
					if now-s.playSecond>=1 then
						if s.playing then s.profile.stats.totalPlaySeconds+=math.floor(now-s.playSecond) end
						s.playSecond=now
					end
					if s.selected=="event" and event.active and s.location=="bay" and s.playing and not s.modal
						and near(p,s,{400,5,-50},24,true) then
						local power=0
						local ids=table.clone(s.profile.team)
						if near(p,s,{400,5,-50},14,true) then table.insert(ids,"manual") end
						for _,id in ids do
							local hit,interval=Game.damage(s.profile,if id=="manual" then nil else id,"Metal",wall,C)
							s.attackClocks[id]=s.attackClocks[id] or now
							if now-s.attackClocks[id]>=interval then power+=hit; s.attackClocks[id]=now end
						end
						if power>0 then
							event.cycles[p.UserId]=(event.cycles[p.UserId] or 0)+1
							event.hp=math.max(0,event.hp-math.min(10,power)); changed=true
							if event.hp<=0 then finishEvent(true) end
						end
					end
					local reward=event.rewards[p.UserId]
					if reward then
						event.rewards[p.UserId]=nil; mutate(p,s,"EventReward",reward,"event-"..event.id)
					elseif now>=s.nextSave then
						s.busy=true; s.profile.revision+=1; s.profile.updatedAt=wall
						local candidate=Schema.clone(s.profile); local writeId=uid()
						task.spawn(function()
							local saved,err=false,nil
							for attempt=1,3 do
								saved,err=store:save(s.handle,candidate,writeId)
								if saved or err=="LeaseLost" or err=="RevisionConflict" then break end
								if attempt<3 then task.wait(attempt*2) end
							end
							if saved then s.busy=false; s.nextSave=os.clock()+integer(50,70)
							else s.blocked=err; send(p,s,err); p:Kick("Autosave unavailable. Please rejoin.") end
						end)
					end
					if changed then s.dirty=true end
					if broadcast and (s.dirty or event.active or s.returnAt or heartbeat) then send(p,s); s.dirty=false end
				end
			end
		end
	end)
end
return Server
