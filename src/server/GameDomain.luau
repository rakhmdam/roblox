--!strict
-- Catalog is injected: this module is executable in standalone Luau tests.
local Game = {}
export type Profile = {[string]: any}
function Game.count(t: {[any]: any}): number
	local n=0; for _ in t do n+=1 end; return n
end
function Game.cargoCount(p: Profile): number
	local n=0; for _,g in p.cargo do n+=g.count end; return n
end
function Game.slots(p: Profile): number
	return if p.unlockedIslands.bay then 3 elseif p.tutorial.step>=7 then 2 else 1
end
function Game.highest(p: Profile): string
	local unlocked: any=p.unlockedIslands
	return if unlocked.cave then "cave" elseif unlocked.bay then "bay" else "shore"
end
function Game.weights(p: Profile, island: string, c: any): {number}
	local pity=p.incubators[island]
	local first=if pity.sinceLegendary>=199 then 5 elseif pity.sinceEpic>=49 then 4 elseif pity.sinceRare>=9 then 3 else 1
	local weights={}
	for i,w in c.slimeWeights do weights[i]=if i>=first then w else 0 end
	return weights
end
function Game.roll(weights: {number}, random: (number,number)->number): number
	local total=0; for _,w in weights do total+=w end
	local result=random(1,total)
	for index,w in weights do result-=w; if result<=0 then return index end end
	error("Invalid random result")
end
local function spend(p: Profile, price: number): boolean
	if p.coins<price then return false end
	p.coins-=price; return true
end
local function grantSlime(p: Profile, species: string, uid: string)
	p.slimes[uid]={speciesId=species,level=1,rank=0,locked=false}
	p.collections.slimeSpeciesIds[species]=true
end
function Game.starter(p: Profile, uid: string)
	local rewards=p.tutorial.grantedRewardIds
	if not rewards.starter then
		grantSlime(p,"shore_sprout",uid)
		p.starterUid=uid
		table.insert(p.team,uid)
		rewards.starter=true
	end
end
function Game.collect(p: Profile, node: any, helperWorked: boolean, uid: string, c: any): (boolean,string?)
	if Game.cargoCount(p)>=c.bag.values[p.equipment.bagTier] then return false,"BagFull" end
	local key=node.island.."/"..node.material.."/"..tostring(node.rarity)
	local g=p.cargo[key]
	if not g then
		g={island=node.island,material=node.material,count=0,coinValueEach=node.coins,
			materialAmountEach=node.amount,balanceVersion=c.balanceVersion}
		p.cargo[key]=g
	end
	g.count+=1
	local collection=node.island.."/"..tostring(node.family).."/"..tostring(node.rarity)
	p.collections.junkCountsByKey[collection]=(p.collections.junkCountsByKey[collection] or 0)+1
	if p.tutorial.step==2 and node.rarity==1 then
		p.tutorial.counters.collected+=1
		if p.tutorial.counters.collected>=3 then Game.starter(p,uid); p.tutorial.step=3 end
	elseif p.tutorial.step==3 and helperWorked then p.tutorial.step=4 end
	return true,nil
end
function Game.preview(p: Profile): any
	local result={coins=0,materials={Plastic=0,Metal=0,Crystal=0},islands={shore=0,bay=0,cave=0}}
	for _,g in p.cargo do
		result.coins+=g.count*g.coinValueEach
		result.materials[g.material]+=g.count*g.materialAmountEach
		result.islands[g.island]+=g.count
	end
	return result
end
function Game.damage(p: Profile, uid: string?, material: string, now: number, c: any): (number,number,string)
	local tea=if p.tutorial.step>=7 and p.boosts.workTeaExpiresAt>now then 0.1 else 0
	local trait=p.equipment.toolTrait
	local power=c.tool.values[p.equipment.toolTier]
	local rate,role,interval=tea,"Manual",0.8
	if uid then
		local slime=p.slimes[uid]
		local species=c.species[slime.speciesId]
		role=species.role
		if slime.evolutionId then role=c.evolutions[slime.speciesId].role end
		trait=slime.traitId
		power=c.islands[species.island].power*c.rarityPower[species.rarity]
			*(1+0.12*(slime.level-1))*(1+0.1*slime.rank)*(if slime.evolutionId then 1.2 else 1)
		interval=1.2
		for _,teamUid in p.team do
			local mate=p.slimes[teamUid]
			if c.species[mate.speciesId].role=="Support" then rate+=0.05; break end
		end
		if role=="Support" then power*=0.9 end
		if role=="Breaker" and material=="Metal" then power*=1.35 end
	end
	if trait=="nimble" then rate+=0.05 end
	if trait=="sturdy" then power*=1.05
	elseif (trait=="metalwork" and material=="Metal") or (trait=="crystalwork" and material=="Crystal") then power*=1.08 end
	return power,interval/(1+math.min(0.2,rate)),role
end

-- Applies to an isolated candidate profile. Returning false means discard the entire candidate.
function Game.apply(p: Profile, action: string, v: any, context: any, c: any): (boolean,any)
	local now=context.now
	if action=="SkipTutorial" then
		if p.tutorial.step>=7 then return true,{} end
		if not p.tutorial.grantedRewardIds.bonus and p.coins>c.coinLimit-15 then return false,"Limit" end
		Game.starter(p,context.uid)
		if not p.tutorial.grantedRewardIds.bonus then p.coins+=15; p.tutorial.grantedRewardIds.bonus=true end
		p.tutorial.state="Skipped"; p.tutorial.step=7
	elseif action=="ProcessCargo" then
		if Game.cargoCount(p)==0 then return false,"EmptyBag" end
		local reward=Game.preview(p)
		local bonus=if p.tutorial.step==4 and not p.tutorial.grantedRewardIds.bonus then 15 else 0
		if p.coins+reward.coins+bonus>c.coinLimit then return false,"Limit" end
		for material,n in reward.materials do if p.materials[material]+n>c.itemLimit then return false,"Limit" end end
		for island,n in reward.islands do
			if p.fragments[island]+math.floor((p.fragmentProgress[island]+n)/15)>c.itemLimit then return false,"Limit" end
		end
		p.coins+=reward.coins+bonus
		for material,n in reward.materials do p.materials[material]+=n end
		for island,n in reward.islands do
			p.fragments[island]+=math.floor((p.fragmentProgress[island]+n)/15)
			p.fragmentProgress[island]=(p.fragmentProgress[island]+n)%15
		end
		p.stats.totalProcessed+=Game.cargoCount(p); p.cargo={}
		for tier,threshold in c.restoration do if p.stats.totalProcessed>=threshold then p.base.restorationTier=tier end end
		if p.tutorial.step==4 then
			p.tutorial.grantedRewardIds.bonus=true
			p.tutorial.step=if p.equipment.toolTier>=2 then 6 else 5
		end
	elseif action=="BuyUpgrade" then
		local kind=v.kind; local catalog=c[kind]
		if not table.find({"tool","bag","storage"},kind) then return false,"UnknownId" end
		local key=kind.."Tier"; local tier=p.equipment[key]
		if tier~=v.expectedTier then return false,"StaleState" end
		local price=catalog.prices[tier+1]
		if not price then return false,"MaxTier" end
		if c.islands[Game.highest(p)].index<catalog.access[tier+1] then return false,"LockedIsland" end
		if not spend(p,price) then return false,"NotEnoughCoins" end
		p.equipment[key]=tier+1
		if kind=="tool" and p.tutorial.step==5 then p.tutorial.step=6 end
	elseif action=="ViewNursery" then
		if p.tutorial.step==6 then p.tutorial.step=7; p.tutorial.state="Completed" end
	elseif action=="UnlockIsland" then
		local island=c.islands[v.island]
		if not island then return false,"UnknownId" end
		if p.unlockedIslands[v.island] then return true,{} end
		if not p.unlockedIslands[c.order[island.index-1]] then return false,"LockedIsland" end
		if not spend(p,island.price) then return false,"NotEnoughCoins" end
		p.unlockedIslands[v.island]=true
	elseif action=="EquipTeam" then
		if #v.uids>Game.slots(p) then return false,"TeamLimit" end
		local used={}
		for _,uid in v.uids do if not p.slimes[uid] or used[uid] then return false,"Ownership" end; used[uid]=true end
		p.team=table.clone(v.uids)
	elseif action=="LockSlime" then
		if not p.slimes[v.uid] then return false,"Ownership" end
		p.slimes[v.uid].locked=v.locked
	elseif action=="LevelSlime" or action=="RankSlime" or action=="EvolveSlime" then
		local slime=p.slimes[v.uid]
		if not slime then return false,"Ownership" end
		local offer: any=p.pendingTraitOffer
		if action=="EvolveSlime" and offer and offer.target==v.uid then return false,"PendingOffer" end
		local species=c.species[slime.speciesId]; local island=c.islands[species.island]
		if action=="LevelSlime" then
			if slime.level~=v.expectedLevel then return false,"StaleState" end
			if slime.level>=10 then return false,"MaxTier" end
			if not spend(p,math.ceil(20*island.factor*slime.level^1.7)) then return false,"NotEnoughCoins" end
			slime.level+=1
		elseif action=="RankSlime" then
			if slime.rank~=v.expectedRank then return false,"StaleState" end
			if slime.rank>=3 then return false,"MaxTier" end
			local price=c.rankPrices[slime.rank+1]*c.rankFactors[species.rarity]
			if p.fragments[species.island]<price then return false,"NotEnoughFragments" end
			p.fragments[species.island]-=price; slime.rank+=1
		else
			local recipe=c.evolutions[slime.speciesId]
			if not recipe or recipe.id~=v.recipeId or slime.evolutionId or slime.level<3 then return false,"Recipe" end
			if not p.unlockedIslands[recipe.island] then return false,"LockedIsland" end
			if p.materials[recipe.material]<recipe.amount then return false,"NotEnoughMaterials" end
			if not spend(p,recipe.coins) then return false,"NotEnoughCoins" end
			p.materials[recipe.material]-=recipe.amount; slime.evolutionId=recipe.id
			p.collections.evolutions[recipe.id]=true
		end
	elseif action=="Incubate" or action=="CraftSlime" then
		if not c.islands[v.island] or not p.unlockedIslands[v.island] then return false,"LockedIsland" end
		if Game.count(p.slimes)>=c.storage.values[p.equipment.storageTier] then return false,"StorageFull" end
		local species: string
		if action=="CraftSlime" then
			local item=c.species[v.speciesId]
			if not item or item.island~=v.island then return false,"UnknownId" end
			local price=c.craft[item.rarity]
			if p.fragments[v.island]<price then return false,"NotEnoughFragments" end
			p.fragments[v.island]-=price; species=item.id
		else
			if not context.randomEnabled then return false,"FeatureDisabled" end
			if not spend(p,c.islands[v.island].incubation) then return false,"NotEnoughCoins" end
			local rarity=Game.roll(Game.weights(p,v.island,c),context.random)
			species=c.sets[v.island][rarity]
			local pity=p.incubators[v.island]
			pity.sinceRare=if rarity>=3 then 0 else pity.sinceRare+1
			pity.sinceEpic=if rarity>=4 then 0 else pity.sinceEpic+1
			pity.sinceLegendary=if rarity>=5 then 0 else pity.sinceLegendary+1
		end
		grantSlime(p,species,context.uid)
		return true,{uid=context.uid,speciesId=species}
	elseif action=="RecycleSlimes" then
		if #v.uids<1 or #v.uids>20 or Game.count(p.slimes)-#v.uids<1 then return false,"ProtectedSlime" end
		local seen,awards={}, {shore=0,bay=0,cave=0}
		for _,uid in v.uids do
			local s=p.slimes[uid]
			if not s or seen[uid] or s.locked or uid==p.starterUid or table.find(p.team,uid)
				or (p.pendingTraitOffer and p.pendingTraitOffer.target==uid) then return false,"ProtectedSlime" end
			seen[uid]=true; local species=c.species[s.speciesId]
			awards[species.island]+=c.recycle[species.rarity]
		end
		for island,n in awards do if p.fragments[island]+n>c.itemLimit then return false,"Limit" end end
		for island,n in awards do p.fragments[island]+=n end
		for _,uid in v.uids do p.slimes[uid]=nil end
	elseif action=="BuyTea" then
		if p.tutorial.step<7 then return false,"TutorialFirst" end
		local remaining=math.max(0,p.boosts.workTeaExpiresAt-now)
		if remaining+300>900 then return false,"TeaLimit" end
		if not spend(p,c.islands[Game.highest(p)].tea) then return false,"NotEnoughCoins" end
		p.boosts.workTeaExpiresAt=now+remaining+300
	elseif action=="RollTrait" then
		if not context.randomEnabled then return false,"FeatureDisabled" end
		if not p.unlockedIslands.bay then return false,"LockedIsland" end
		if p.pendingTraitOffer then return false,"PendingOffer" end
		local origin=Game.highest(p)
		if v.target=="tool" then if p.equipment.toolTier<3 then return false,"LevelRequired" end
		else
			local s=p.slimes[v.target]; if not s then return false,"Ownership" end
			if s.level<3 then return false,"LevelRequired" end
			origin=c.species[s.speciesId].island
		end
		if not spend(p,c.islands[origin].trait) then return false,"NotEnoughCoins" end
		p.pendingTraitOffer={id=context.uid,target=v.target,traitId=c.traits[Game.roll(c.traitWeights,context.random)]}
		return true,p.pendingTraitOffer
	elseif action=="ResolveTrait" then
		local offer=p.pendingTraitOffer
		if not offer or offer.id~=v.offerId then return false,"StaleState" end
		if v.accept then
			if offer.target=="tool" then p.equipment.toolTrait=offer.traitId
			else p.slimes[offer.target].traitId=offer.traitId end
		end
		p.pendingTraitOffer=nil
	elseif action=="BuyDecoration" then
		local item=c.decor[v.itemId]
		if not item then return false,"UnknownId" end
		if p.base.ownedDecor[v.itemId] then return true,{} end
		if not p.unlockedIslands[item.island] then return false,"LockedIsland" end
		if not spend(p,item.price) then return false,"NotEnoughCoins" end
		p.base.ownedDecor[v.itemId]=true
	elseif action=="PlaceDecoration" then
		if v.slot>p.base.restorationTier*3 then return false,"SlotLocked" end
		if v.itemId~="" and not p.base.ownedDecor[v.itemId] then return false,"Ownership" end
		p.base.decorationSlots[tostring(v.slot)]=if v.itemId=="" then nil else v.itemId
	elseif action=="UpdateSettings" then
		for key,value in v do
			if type(p.settings[key])~=type(value) then return false,"InvalidSetting" end
			if key=="language" and value~="ru" and value~="en" then return false,"InvalidSetting" end
			p.settings[key]=value
		end
	elseif action=="EventReward" then
		if now-p.lastEventRewardAt<600 then return false,"RewardCooldown" end
		local coins=if v.success then 100 else 20
		local fragments=if v.success then 2 else 1
		if p.coins+coins>c.coinLimit or p.fragments.bay+fragments>c.itemLimit then return false,"Limit" end
		p.coins+=coins; p.fragments.bay+=fragments; p.lastEventRewardAt=now
	else return false,"UnknownAction" end
	return true,{}
end
return Game
