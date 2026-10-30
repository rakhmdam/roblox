--!strict
local Protocol={}
local schemas: {[string]: {[string]: string}}={
	Sync={},Play={},Pause={},CancelTarget={},ReturnHome={},
	SelectTarget={nodeId="int"},SelectEvent={},ProcessCargo={},ViewNursery={},SkipTutorial={},
	BuyUpgrade={kind="string",expectedTier="int"},UnlockIsland={island="string"},Travel={island="string"},
	VisitBase={userId="int"},EquipTeam={uids="uids"},LockSlime={uid="string",locked="boolean"},
	LevelSlime={uid="string",expectedLevel="int"},RankSlime={uid="string",expectedRank="int"},
	EvolveSlime={uid="string",recipeId="string"},Incubate={island="string"},
	CraftSlime={island="string",speciesId="string"},RecycleSlimes={uids="uids"},BuyTea={},
	RollTrait={target="string"},ResolveTrait={offerId="string",accept="boolean"},
	BuyDecoration={itemId="string"},PlaceDecoration={itemId="string",slot="int"},
	UpdateSettings={language="optionalString",music="optionalBoolean",sound="optionalBoolean",
		lowEffects="optionalBoolean",reducedMotion="optionalBoolean",autoRepeat="optionalBoolean",allowGuests="optionalBoolean"},
	Modal={open="boolean"},
}
local function valid(value: any,kind: string): boolean
	if kind=="optionalString" then return value==nil or valid(value,"string") end
	if kind=="optionalBoolean" then return value==nil or type(value)=="boolean" end
	if kind=="string" then return type(value)=="string" and #value<=64 and #value>0 and utf8.len(value)~=nil end
	if kind=="boolean" then return type(value)=="boolean" end
	if kind=="int" then return type(value)=="number" and value==value and value>=0 and value<=1e12 and value%1==0 end
	if kind=="uids" then
		if type(value)~="table" or #value>20 then return false end
		local keys=0
		for k,v in value do if type(k)~="number" or k%1~=0 or k<1 or k>#value or not valid(v,"string") then return false end; keys+=1 end
		return keys==#value
	end
	return false
end
function Protocol.validate(request: any): boolean
	if type(request)~="table" then return false end
	local keys=0
	for key in request do
		keys+=1
		if key~="protocolVersion" and key~="requestId" and key~="sessionNonce" and key~="action" and key~="payload" then return false end
	end
	if keys>5 or request.protocolVersion~=2 or not valid(request.requestId,"string")
		or not string.match(request.requestId,"^[%w%-]+$") or not valid(request.action,"string") then return false end
	if request.action~="Sync" and not valid(request.sessionNonce,"string") then return false end
	local schema=schemas[request.action]
	if not schema or type(request.payload)~="table" then return false end
	local n=0
	for key in request.payload do n+=1; if not schema[key] or n>10 then return false end end
	for key,kind in schema do
		if request.action=="PlaceDecoration" and key=="itemId" and request.payload[key]=="" then continue end
		if not valid(request.payload[key],kind) then return false end
	end
	return true
end
return Protocol
