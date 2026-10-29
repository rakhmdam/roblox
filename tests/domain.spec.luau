--!strict
local Domain = require("../src/server/Domain")
local balance = require("../src/shared/Balance")
local passed = 0
local function test(name: string, run: () -> ())
	run()
	passed += 1
	print("PASS " .. name)
end
local function collect(p: Domain.Profile, id: number, start: number, helper: boolean?): Domain.Node
	local node = Domain.newNode(id, 1, "Plastic", balance)
	local now = start
	while node.hp > 0 do
		now += 1.3
		if helper then Domain.hit(p, node, now, true, "starter-uid", balance) end
		Domain.hit(p, node, now, false, "starter-uid", balance)
	end
	return node
end

test("tutorial: four common items -> 39 coins -> tier 2 leaves 9", function()
	local p = Domain.newProfile(0)
	p.playing = true
	Domain.select(p)
	for id = 1, 3 do collect(p, id, id * 20) end
	assert(p.tutorial == 3 and p.slimeUid == "starter-uid" and p.equipped)
	collect(p, 4, 100, true)
	assert(p.tutorial == 4)
	assert(Domain.process(p, balance))
	assert(p.coins == 39 and p.materials.Plastic == 4 and p.count == 0)
	assert(Domain.upgrade(p, 1, balance))
	assert(p.coins == 9 and p.toolTier == 2 and p.tutorial == 6)
	assert(Domain.viewNursery(p))
	assert(p.tutorial == 7 and p.teamSlots == 2)
	Domain.skip(p, "duplicate")
	assert(p.coins == 9 and p.slimeUid == "starter-uid")
end)

test("12 common items pay exactly 72 and cannot sell twice", function()
	local p = Domain.newProfile(0)
	p.playing = true
	p.tutorial = 7
	for id = 1, 12 do collect(p, id, id * 20) end
	assert(p.count == 12)
	assert(Domain.process(p, balance))
	assert(p.coins == 72 and p.materials.Plastic == 12)
	assert(not Domain.process(p, balance))
	assert(p.coins == 72)
end)

test("bag full never damages or discards the next node", function()
	local p = Domain.newProfile(0)
	p.playing = true
	p.tutorial = 7
	for id = 1, 12 do collect(p, id, id * 20) end
	local node = Domain.newNode(13, 1, "Metal", balance)
	local ok, err = Domain.hit(p, node, 500, false, "uid", balance)
	assert(not ok and err == "BagFull" and node.hp == 12 and p.count == 12)
end)

test("overflow rejects whole sale including fragment and cargo", function()
	for _, kind in {"coins", "material", "fragment"} do
		local p = Domain.newProfile(0)
		p.playing = true
		p.tutorial = 7
		collect(p, 1, 20)
		p.fragmentRemainder = 14
		if kind == "coins" then p.coins = balance.coinLimit
		elseif kind == "material" then p.materials.Plastic = balance.materialLimit
		else p.fragments = balance.materialLimit end
		local before = p.coins
		assert(not Domain.process(p, balance))
		assert(p.count == 1 and p.coins == before and p.fragmentRemainder == 14)
	end
end)

test("manual cooldown survives target switching; paused players earn nothing", function()
	local p = Domain.newProfile(0)
	p.playing = true
	local first = Domain.newNode(1, 1, "Plastic", balance)
	local second = Domain.newNode(2, 1, "Metal", balance)
	assert(not Domain.hit(p, first, 0.79, false, "uid", balance))
	assert(Domain.hit(p, first, 0.8, false, "uid", balance))
	Domain.select(p)
	assert(not Domain.hit(p, second, 0.81, false, "uid", balance))
	assert(second.hp == 12)
	p.playing = false
	assert(not Domain.hit(p, second, 10, false, "uid", balance))
end)

test("starter and skip bonus are granted once", function()
	local p = Domain.newProfile(0)
	Domain.skip(p, "first")
	Domain.skip(p, "second")
	assert(p.coins == 15 and p.slimeUid == "first" and p.teamSlots == 2)
	assert(p.toolTier == 1 and p.skipped)
end)

test("upgrade retries, stale tiers, and maximum tier cannot double spend", function()
	local p = Domain.newProfile(0)
	p.tutorial = 5
	p.coins = 29
	assert(not Domain.upgrade(p, 1, balance))
	assert(p.coins == 29 and p.toolTier == 1)
	p.coins = 100
	assert(Domain.upgrade(p, 1, balance))
	assert(not Domain.upgrade(p, 1, balance))
	assert(not Domain.upgrade(p, 2, balance))
	assert(p.coins == 70)
end)

test("rarity boundaries and rewards agree with balance", function()
	local cases = {{1,1},{6000,1},{6001,2},{8500,2},{8501,3},{9500,3},
		{9501,4},{9900,4},{9901,5},{10000,5}}
	for _, pair in cases do assert(Domain.chooseRarity(pair[1], balance.rarityWeights) == pair[2]) end
	local node = Domain.newNode(1, 5, "Metal", balance)
	assert(node.hp == 48 and node.coins == 42 and node.amount == 8)
end)

test("personal profiles and fragment remainders are independent", function()
	local a, b = Domain.newProfile(0), Domain.newProfile(0)
	a.playing = true
	a.tutorial = 7
	a.fragmentRemainder = 14
	collect(a, 1, 20)
	Domain.process(a, balance)
	assert(a.fragments == 1 and a.fragmentRemainder == 0)
	assert(b.coins == 0 and b.count == 0 and b.fragments == 0)
end)
print(tostring(passed) .. " domain tests passed")
