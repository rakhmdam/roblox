--!strict
local Game=require("../src/server/GameDomain")
local Schema=require("../src/server/ProfileSchema")
local Lease=require("../src/server/Lease")
local Protocol=require("../src/shared/Protocol")
local C: any=require("../src/shared/Catalog")
local Resources=require("../src/server/ResourceService")
local total=0
local function test(name: string,run: ()->()) run(); total+=1; print("PASS "..name) end
local serial=0
local function context(random: any?): any
	serial+=1
	return {now=10000,uid="uid-"..serial,random=random or function(a: number,_b: number) return a end,randomEnabled=true}
end
local function profile(): any return Schema.new(10000,C) end
local function action(p: any,a: string,v: any?,ctx: any?): (any,any)
	local candidate=Schema.clone(p)
	local ok,result=Game.apply(candidate,a,v or {},ctx or context(),C)
	assert(ok,tostring(result).." in "..a)
	local valid,err=Schema.validate(candidate,C); assert(valid,tostring(err))
	return candidate,result
end
local function reject(p: any,a: string,v: any?,code: string)
	local ok,err=Game.apply(Schema.clone(p),a,v or {},context(),C)
	assert(not ok and err==code,tostring(err).." expected "..code)
end
local function node(island: string,material: string,rarity: number?): any
	local r=rarity or 1
	return {island=island,material=material,rarity=r,family=table.find(C.materials,material),
		coins=math.floor(C.islands[island].coins*C.coinMultipliers[r]),amount=C.amounts[r]}
end
local function collect(p: any,count: number,island: string?,material: string?)
	for _=1,count do assert(Game.collect(p,node(island or "shore",material or "Plastic"),true,"starter",C)) end
end
test("fresh profile, future schema and corruption",function()
	local p=profile(); assert(Schema.validate(p,C))
	p.schemaVersion=2; assert(not Schema.validate(p,C))
	p=profile(); p.coins=0/0; assert(not Schema.validate(p,C))
	p=profile(); p.equipment.bagTier=0; assert(not Schema.validate(p,C))
end)
test("six-step tutorial gives 39, then tier II leaves 9",function()
	local p=profile(); p.tutorial.step=2
	collect(p,3); assert(p.tutorial.step==3 and Game.count(p.slimes)==1)
	collect(p,1); assert(p.tutorial.step==4)
	p=action(p,"ProcessCargo"); assert(p.coins==39 and p.materials.Plastic==4)
	p=action(p,"BuyUpgrade",{kind="tool",expectedTier=1}); assert(p.coins==9 and p.tutorial.step==6)
	p=action(p,"ViewNursery"); assert(p.tutorial.step==7 and Game.slots(p)==2)
	p=action(p,"SkipTutorial"); assert(p.coins==9 and Game.count(p.slimes)==1)
end)
test("skip preserves starter and grants bonus only once",function()
	local p=action(profile(),"SkipTutorial")
	local id=p.starterUid
	p=action(p,"SkipTutorial")
	assert(p.coins==15 and p.starterUid==id and p.equipment.toolTier==1)
end)
test("full bag and sale idempotence",function()
	local p=profile(); collect(p,12)
	assert(not Game.collect(p,node("shore","Metal"),false,"x",C))
	p=action(p,"ProcessCargo"); assert(p.coins==72 and p.materials.Plastic==12)
	reject(p,"ProcessCargo",nil,"EmptyBag")
end)
test("sale snapshots value, preserves per-island remainders",function()
	local p=profile(); p.equipment.bagTier=5; p.unlockedIslands.bay=true
	collect(p,14); p=action(p,"ProcessCargo")
	assert(p.fragments.shore==0 and p.fragmentProgress.shore==14)
	collect(p,1,"bay","Metal"); p=action(p,"ProcessCargo")
	assert(p.fragmentProgress.bay==1 and p.fragmentProgress.shore==14)
	collect(p,1); p.cargo["shore/Plastic/1"].coinValueEach=7
	p=action(p,"ProcessCargo"); assert(p.fragments.shore==1 and p.fragmentProgress.shore==0 and p.coins==115)
end)
test("all reward overflows reject before cargo removal",function()
	for _,kind in {"coins","material","fragments"} do
		local p=profile(); collect(p,1)
		if kind=="coins" then p.coins=C.coinLimit elseif kind=="material" then p.materials.Plastic=C.itemLimit
		else p.fragments.shore=C.itemLimit; p.fragmentProgress.shore=14 end
		reject(p,"ProcessCargo",nil,"Limit"); assert(Game.cargoCount(p)==1)
	end
end)
test("island sequence and duplicate unlock",function()
	local p=profile(); p.coins=20000
	reject(p,"UnlockIsland",{island="cave"},"LockedIsland")
	p=action(p,"UnlockIsland",{island="bay"}); assert(p.coins==18500 and Game.slots(p)==3)
	p=action(p,"UnlockIsland",{island="bay"}); assert(p.coins==18500)
	p=action(p,"UnlockIsland",{island="cave"}); assert(p.coins==9500)
end)
test("all upgrade costs, prerequisites and stale retries",function()
	local p=profile(); p.coins=100000
	p=action(p,"BuyUpgrade",{kind="bag",expectedTier=1}); assert(p.coins==99940 and C.bag.values[p.equipment.bagTier]==20)
	reject(p,"BuyUpgrade",{kind="bag",expectedTier=1},"StaleState")
	reject(p,"BuyUpgrade",{kind="storage",expectedTier=1},"LockedIsland")
	p.unlockedIslands.bay=true; p.unlockedIslands.cave=true
	for _,kind in {"tool","bag","storage"} do
		while p.equipment[kind.."Tier"]<#C[kind].values do p=action(p,"BuyUpgrade",{kind=kind,expectedTier=p.equipment[kind.."Tier"]}) end
		reject(p,"BuyUpgrade",{kind=kind,expectedTier=p.equipment[kind.."Tier"]},"MaxTier")
	end
end)
test("team uniqueness, ownership and slot caps",function()
	local p=profile(); Game.starter(p,"a"); p.slimes.b=Schema.clone(p.slimes.a)
	reject(p,"EquipTeam",{uids={"a","b"}},"TeamLimit")
	p.tutorial.step=7
	reject(p,"EquipTeam",{uids={"a","a"}},"Ownership")
	reject(p,"EquipTeam",{uids={"missing"}},"Ownership")
	p=action(p,"EquipTeam",{uids={"a","b"}}); assert(#p.team==2)
end)
test("all 15 species can be crafted and recycled without profit",function()
	local p=profile(); p.unlockedIslands.bay=true; p.unlockedIslands.cave=true; p.equipment.storageTier=3
	Game.starter(p,"starter"); p.team={}
	for _,id in C.speciesOrder do
		local species=C.species[id]; p.fragments[species.island]=1000
		local before=p.fragments[species.island]
		local result: any=nil; p,result=action(p,"CraftSlime",{island=species.island,speciesId=id})
		p=action(p,"RecycleSlimes",{uids={result.uid}})
		assert(p.fragments[species.island]<before and Game.count(p.slimes)==1)
	end
end)
test("storage full prevents spend and pity changes",function()
	local p=profile(); p.coins=1000
	for i=1,30 do p.slimes[tostring(i)]={speciesId="shore_sprout",level=1,rank=0,locked=false} end
	reject(p,"Incubate",{island="shore"},"StorageFull")
	assert(p.coins==1000 and p.incubators.shore.sinceRare==0)
end)
test("guarantee priority, thresholds and reset",function()
	local p=profile(); p.coins=100000
	p.incubators.shore={sinceRare=9,sinceEpic=49,sinceLegendary=199}
	local w=Game.weights(p,"shore",C); assert(w[1]==0 and w[4]==0 and w[5]==100)
	local result: any=nil; p,result=action(p,"Incubate",{island="shore"}); assert(result.speciesId=="shore_sun")
	assert(p.incubators.shore.sinceRare==0 and p.incubators.shore.sinceEpic==0 and p.incubators.shore.sinceLegendary==0)
	p.incubators.shore.sinceEpic=49
	p,result=action(p,"Incubate",{island="shore"}); assert(result.speciesId=="shore_pollen")
	p.incubators.shore.sinceRare=9
	p,result=action(p,"Incubate",{island="shore"}); assert(result.speciesId=="shore_moss")
end)
test("all cumulative RNG boundaries",function()
	local edges={1,5500,5501,8200,8201,9400,9401,9900,9901,10000}
	for i,n in edges do assert(Game.roll(C.slimeWeights,function() return n end)==math.ceil(i/2)) end
end)
test("100000 fixed-seed ordinary rolls approximate base weights",function()
	local seed=51; local counts={0,0,0,0,0}
	local function random(a: number,b: number): number seed=(seed*16807)%2147483647; return a+seed%(b-a+1) end
	for _=1,100000 do local i=Game.roll(C.slimeWeights,random); counts[i]+=1 end
	for i,w in C.slimeWeights do assert(math.abs(counts[i]-w*10)<600) end
end)
test("10000 pity-aware rolls never exceed guarantee gaps",function()
	local p=profile(); p.coins=100000000
	local seed=93
	local function random(a: number,b: number): number seed=(seed*16807)%2147483647; return a+seed%(b-a+1) end
	for _=1,10000 do
		p=action(p,"Incubate",{island="shore"},context(random))
		local pity=p.incubators.shore; assert(pity.sinceRare<=9 and pity.sinceEpic<=49 and pity.sinceLegendary<=199)
		p.slimes={}
	end
end)
test("all three evolutions retain level, rank, UID and rarity",function()
	for id,recipe in C.evolutions do
		local p=profile(); p.unlockedIslands.bay=true; p.unlockedIslands.cave=true; p.coins=10000
		p.materials[recipe.material]=1000
		p.slimes.uid={speciesId=id,level=3,rank=2,locked=true}
		p=action(p,"EvolveSlime",{uid="uid",recipeId=recipe.id})
		assert(p.slimes.uid.speciesId==id and p.slimes.uid.level==3 and p.slimes.uid.rank==2 and p.slimes.uid.locked)
		reject(p,"EvolveSlime",{uid="uid",recipeId=recipe.id},"Recipe")
	end
end)
test("level and rank limits and known price",function()
	local p=profile(); p.coins=100000; p.fragments.shore=1000; Game.starter(p,"uid")
	p=action(p,"LevelSlime",{uid="uid",expectedLevel=1}); assert(p.coins==99980 and p.slimes.uid.level==2)
	reject(p,"LevelSlime",{uid="uid",expectedLevel=1},"StaleState")
	for rank=0,2 do p=action(p,"RankSlime",{uid="uid",expectedRank=rank}) end
	assert(p.fragments.shore==983)
	reject(p,"RankSlime",{uid="uid",expectedRank=3},"MaxTier")
end)
test("mixed protected recycle list is fully rejected",function()
	local p=profile(); Game.starter(p,"starter"); p.team={}
	p.slimes.a={speciesId="shore_tide",level=1,rank=0,locked=false}
	p.slimes.b={speciesId="shore_tide",level=1,rank=0,locked=true}
	reject(p,"RecycleSlimes",{uids={"a","b"}},"ProtectedSlime")
	reject(p,"RecycleSlimes",{uids={"starter"}},"ProtectedSlime")
	reject(p,"RecycleSlimes",{uids={"a","a"}},"ProtectedSlime")
	assert(p.slimes.a and p.fragments.shore==0)
end)
test("trait offers are preserved until resolution and block evolution",function()
	local p=profile(); p.coins=5000; p.unlockedIslands.bay=true
	Game.starter(p,"uid"); p.slimes.uid.level=3
	p=action(p,"RollTrait",{target="uid"}); assert(p.coins==4960 and p.pendingTraitOffer.traitId=="sturdy")
	local offer=p.pendingTraitOffer.id
	reject(p,"RollTrait",{target="tool"},"PendingOffer")
	reject(p,"EvolveSlime",{uid="uid",recipeId="iron_sprout"},"PendingOffer")
	local saved=Schema.clone(p); assert(Schema.validate(saved,C) and saved.pendingTraitOffer.id==offer)
	p=action(p,"ResolveTrait",{offerId=offer,accept=true}); assert(p.slimes.uid.traitId=="sturdy" and not p.pendingTraitOffer)
	reject(p,"ResolveTrait",{offerId=offer,accept=true},"StaleState")
end)
test("tea adds duration, not strength, and rejects over-cap portion",function()
	local p=profile(); p.coins=10000; p.tutorial.step=7
	for _=1,3 do p=action(p,"BuyTea") end
	assert(p.boosts.workTeaExpiresAt==10900 and p.coins==9910)
	reject(p,"BuyTea",nil,"TeaLimit")
	local damage,interval=Game.damage(p,nil,"Metal",10000,C)
	assert(damage==4 and math.abs(interval-0.8/1.1)<0.00001)
end)
test("damage cap, breaker bonus, support aura and evolution",function()
	local p=profile(); p.tutorial.step=7; p.boosts.workTeaExpiresAt=11000
	p.slimes.a={speciesId="bay_titan",level=10,rank=3,locked=false,traitId="nimble"}
	p.slimes.b={speciesId="shore_pollen",level=1,rank=0,locked=false}
	p.slimes.c={speciesId="cave_prism",level=1,rank=0,locked=false}; p.team={"a","b","c"}
	local power,interval=Game.damage(p,"a","Metal",10000,C)
	assert(math.abs(power-7*1.6*2.08*1.3*1.35)<0.00001 and math.abs(interval-1)<0.00001)
	local _,manual=Game.damage(p,nil,"Metal",10000,C); assert(math.abs(manual-0.8/1.1)<0.00001)
end)
test("decor purchase and rearrangement do not charge twice",function()
	local p=profile(); p.coins=1000
	p=action(p,"BuyDecoration",{itemId="planter"}); assert(p.coins==950)
	p=action(p,"BuyDecoration",{itemId="planter"}); assert(p.coins==950)
	p=action(p,"PlaceDecoration",{itemId="planter",slot=1})
	p=action(p,"PlaceDecoration",{itemId="planter",slot=2}); assert(p.coins==950)
	reject(p,"PlaceDecoration",{itemId="planter",slot=4},"SlotLocked")
	p=action(p,"PlaceDecoration",{itemId="",slot=1}); assert(not p.base.decorationSlots["1"])
end)
test("event rewards and cooldown are persistent",function()
	local p=action(profile(),"EventReward",{success=true})
	assert(p.coins==100 and p.fragments.bay==2 and p.lastEventRewardAt==10000)
	reject(Schema.clone(p),"EventReward",{success=true},"RewardCooldown")
end)
test("lease ownership, expiry and late server writes",function()
	local function fresh() return profile() end
	local function validate(p: any) return Schema.validate(p,C) end
	local a=Lease.acquire(nil,"A",100,fresh,validate); assert(a and a.lease.expires==280)
	local b,err=Lease.acquire(a,"B",101,fresh,validate); assert(not b and err=="ProfileLocked")
	b=Lease.acquire(a,"B",281,fresh,validate); assert(b and b.lease.token=="B")
	local write=Lease.write(b,"A",0,profile(),"w",false,282); assert(not write)
	local released=Lease.write(b,"B",0,profile(),"w",true,282); assert(released and not released.lease)
	assert(not Lease.write(released,"A",0,profile(),"w2",false,283))
end)
test("lost response retry reuses exact result and revision",function()
	local old={data=profile(),lease={token="A",expires=200}}
	local candidate=Schema.clone(old.data); candidate.revision=1; candidate.coins=44
	local written=Lease.write(old,"A",0,candidate,"operation",false,101)
	local again=Lease.write(written,"A",0,candidate,"operation",false,102)
	assert(again and again.data.coins==44 and again.data.revision==1)
	assert(not Lease.write(written,"A",0,profile(),"different",false,102))
end)
test("protocol rejects unknown fields, nonfinite, oversize and client economy",function()
	local function request(actionName: string,payload: any): any return {protocolVersion=2,requestId="req-1",sessionNonce="nonce",action=actionName,payload=payload} end
	assert(Protocol.validate(request("BuyUpgrade",{kind="tool",expectedTier=1})))
	assert(not Protocol.validate(request("BuyUpgrade",{kind="tool",expectedTier=1,price=0})))
	assert(not Protocol.validate(request("SelectTarget",{nodeId=0/0})))
	assert(not Protocol.validate(request("SelectTarget",{nodeId=math.huge})))
	assert(not Protocol.validate(request("SelectTarget",{nodeId=-1})))
	assert(not Protocol.validate(request("EventReward",{success=true})))
	assert(not Protocol.validate(request("UpdateSettings",{admin=true})))
	assert(not Protocol.validate(request("Travel",{island=string.rep("a",1000)})))
	assert(not Protocol.validate(request("EquipTeam",{uids={[500]="uid"}})))
	assert(Protocol.validate(request("PlaceDecoration",{itemId="",slot=1})))
end)
test("actual resource service: cooldown, independent fields, respawn and pause",function()
	local function random(a: number,_b: number) return a end
	local s: any={profile=profile(),location="shore",playing=true,modal=false,busy=false,
		nextUid=function() return "starter" end,attackClocks={manual=0},hitCounts={}}
	Resources.activate(s,"shore",random,C,Game)
	s.profile.tutorial.step=2; s.selected=1
	local function canHit(_coords: any,_range: number) return true end
	Resources.tick(s,0.79,10000,random,C,Game,canHit); assert(s.nodes[1].hp==12)
	Resources.tick(s,0.8,10000,random,C,Game,canHit); assert(s.nodes[1].hp==8)
	s.selected=2
	Resources.tick(s,0.81,10000,random,C,Game,canHit); assert(s.nodes[2].hp==12)
	s.selected=1
	Resources.tick(s,1.6,10000,random,C,Game,canHit)
	Resources.tick(s,2.41,10000,random,C,Game,canHit)
	assert(Game.cargoCount(s.profile)==1 and s.nodes[1].hp==0 and not s.selected)
	s.modal=true; s.selected=2
	Resources.tick(s,4,10000,random,C,Game,canHit); assert(s.nodes[2].hp==12)
	Resources.tick(s,11,10000,random,C,Game,canHit); assert(s.nodes[1].hp==12)
	Resources.activate(s,"bay",random,C,Game); assert(s.nodes[1].island=="bay" and s.nodes[1].position[1]>300)
	assert(#s.fields.shore==36 and #s.fields.bay==36)
end)
test("out-of-range grace cancels work without rewards",function()
	local function random(a: number,_b: number) return a end
	local s: any={profile=profile(),location="shore",playing=true,modal=false,busy=false,
		nextUid=function() return "starter" end,attackClocks={manual=0},hitCounts={}}
	Resources.activate(s,"shore",random,C,Game); s.selected=1
	local function blocked(_coords: any,_range: number) return false end
	Resources.tick(s,1,10000,random,C,Game,blocked); assert(s.selected==1)
	Resources.tick(s,2.1,10000,random,C,Game,blocked); assert(not s.selected and Game.cargoCount(s.profile)==0)
end)
print(tostring(total).." beta domain tests passed")
