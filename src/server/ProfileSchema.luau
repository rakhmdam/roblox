--!strict
-- Reject malformed or future data; never replace an unrecognised profile with defaults.
local Schema = {}
export type Profile = {[string]: any}
function Schema.clone(value: any): any
	if type(value) ~= "table" then return value end
	local copy = {}
	for k, v in value do copy[k] = Schema.clone(v) end
	return copy
end
function Schema.new(now: number, catalog: any): Profile
	local p: Profile = {
		schemaVersion=1, revision=0, balanceVersion=catalog.balanceVersion, createdAt=now, updatedAt=now,
		coins=0, materials={Plastic=0,Metal=0,Crystal=0}, fragments={shore=0,bay=0,cave=0}, cargo={},
		equipment={toolTier=1,bagTier=1,storageTier=1}, slimes={}, team={}, unlockedIslands={shore=true},
		base={restorationTier=1,decorationSlots={},ownedDecor={}},
		tutorial={version=1,state="Active",step=1,counters={collected=0},grantedRewardIds={}},
		collections={slimeSpeciesIds={},junkCountsByKey={},evolutions={}},
		incubators={}, fragmentProgress={shore=0,bay=0,cave=0}, recentDurableOperations={}, lastEventRewardAt=0,
		settings={language="ru",music=true,sound=true,lowEffects=false,reducedMotion=false,autoRepeat=false,allowGuests=false},
		boosts={workTeaExpiresAt=0}, stats={totalProcessed=0,totalPlaySeconds=0}, cosmeticEntitlements={},
	}
	for _, id in catalog.order do p.incubators[id]={sinceRare=0,sinceEpic=0,sinceLegendary=0} end
	return p
end
local function integer(n: any, limit: number): boolean
	return type(n)=="number" and n==n and n>=0 and n<=limit and n%1==0
end
function Schema.validate(p: any, c: any): (boolean, string?)
	if type(p)~="table" or p.schemaVersion~=c.schemaVersion then return false,"SchemaVersion" end
	-- Enforce required shape before checking references or arithmetic.
	local sample = Schema.new(0,c)
	local function shape(value: any, template: any): boolean
		if type(value)~=type(template) then return false end
		if type(template)~="table" then return true end
		for key, expected in template do if not shape(value[key],expected) then return false end end
		return true
	end
	if not shape(p,sample) then return false,"ProfileShape" end
	if not integer(p.coins,c.coinLimit) or not integer(p.revision,1e15) then return false,"Wallet" end
	for _, material in c.materials do if not integer(p.materials[material],c.itemLimit) then return false,"Material" end end
	for _, id in c.order do
		if not integer(p.fragments[id],c.itemLimit) or not integer(p.fragmentProgress[id],14) then return false,"Fragments" end
		for _, key in {"sinceRare","sinceEpic","sinceLegendary"} do
			if not integer(p.incubators[id][key],1000000000) then return false,"Pity" end
		end
	end
	for _, key in {"tool","bag","storage"} do
		local tier = p.equipment[key.."Tier"]
		if not integer(tier,#c[key].values) or tier<1 then return false,"Equipment" end
	end
	local count=0
	for uid, slime in p.slimes do
		count+=1
		if type(uid)~="string" or #uid>64 or type(slime)~="table" or not c.species[slime.speciesId]
			or not integer(slime.level,10) or slime.level<1 or not integer(slime.rank,3)
			or type(slime.locked)~="boolean" then return false,"Slime" end
		if slime.evolutionId then
			local evo = c.evolutions[slime.speciesId]
			if not evo or evo.id~=slime.evolutionId then return false,"Evolution" end
		end
		if slime.traitId and not table.find(c.traits,slime.traitId) then return false,"Trait" end
	end
	if count>100 then return false,"Storage" end
	local seen={}
	local slots=if p.unlockedIslands.bay then 3 elseif p.tutorial.step>=7 then 2 else 1
	if #p.team>slots then return false,"Team" end
	for _, uid in p.team do
		if not p.slimes[uid] or seen[uid] then return false,"Team" end
		seen[uid]=true
	end
	local cargoCount, groups=0,0
	for key, g in p.cargo do
		groups+=1
		if type(key)~="string" or type(g)~="table" or not c.islands[g.island]
			or not table.find(c.materials,g.material) or not integer(g.count,72)
			or not integer(g.coinValueEach,100000) or not integer(g.materialAmountEach,100)
			or type(g.balanceVersion)~="string" then return false,"Cargo" end
		cargoCount+=g.count
	end
	if groups>45 or cargoCount>c.bag.values[p.equipment.bagTier] then return false,"CargoSize" end
	if #p.recentDurableOperations>128 then return false,"Operations" end
	for _, op in p.recentDurableOperations do
		if type(op)~="table" or type(op.id)~="string" or #op.id>130 then return false,"Operation" end
	end
	if not p.unlockedIslands.shore or (p.unlockedIslands.cave and not p.unlockedIslands.bay) then return false,"Islands" end
	for id in p.unlockedIslands do if not c.islands[id] then return false,"Island" end end
	if not integer(p.tutorial.step,7) or p.tutorial.step<1 then return false,"Tutorial" end
	if not table.find({"Active","Completed","Skipped"},p.tutorial.state) then return false,"Tutorial" end
	if not integer(p.base.restorationTier,4) or p.base.restorationTier<1 then return false,"Base" end
	for slot, id in p.base.decorationSlots do
		local slotNumber=tonumber(slot)
		if type(slot)~="string" or not slotNumber or not integer(slotNumber,12) or slotNumber<1
			or slot~=tostring(slotNumber)
			or not c.decor[id] or not p.base.ownedDecor[id] then return false,"Decoration" end
	end
	if not integer(p.stats.totalProcessed,1e12) or not integer(p.stats.totalPlaySeconds,1e12)
		or not integer(p.boosts.workTeaExpiresAt,1e12) or not integer(p.lastEventRewardAt,1e12) then return false,"Counters" end
	if p.settings.language~="ru" and p.settings.language~="en" then return false,"Language" end
	for key, default in sample.settings do if type(p.settings[key])~=type(default) then return false,"Setting" end end
	if p.pendingTraitOffer then
		local o=p.pendingTraitOffer
		if type(o)~="table" or type(o.id)~="string" or not table.find(c.traits,o.traitId)
			or (o.target~="tool" and not p.slimes[o.target]) then return false,"Offer" end
	end
	return true,nil
end
return Schema
