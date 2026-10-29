--!strict
-- Pure session economy. No Roblox services, yielding, network, or persistence.
export type Cargo = { count: number, coins: number, amount: number, material: string }
export type Profile = {
	coins: number, materials: {[string]: number}, cargo: {[string]: Cargo},
	count: number, processed: number, fragmentRemainder: number, fragments: number,
	toolTier: number, collected: number, tutorial: number, skipped: boolean,
	slimeUid: string?, equipped: boolean, starterGranted: boolean,
	bonusGranted: boolean, teamSlots: number, playing: boolean,
	lastManual: number, lastSlime: number,
}
export type Node = {
	id: number, hp: number, maxHp: number, rarity: number, material: string,
	coins: number, amount: number, readyAt: number, helperWorked: boolean,
}
local Domain = {}

function Domain.newProfile(now: number): Profile
	return { coins=0, materials={Plastic=0, Metal=0, Crystal=0}, cargo={},
		count=0, processed=0, fragmentRemainder=0, fragments=0, toolTier=1,
		collected=0, tutorial=1, skipped=false, slimeUid=nil, equipped=false,
		starterGranted=false, bonusGranted=false, teamSlots=1, playing=false,
		lastManual=now, lastSlime=now }
end

function Domain.newNode(id: number, rarity: number, material: string, balance: any): Node
	assert(rarity >= 1 and rarity <= 5 and rarity % 1 == 0)
	local hp = math.ceil(12 * balance.hpMultipliers[rarity])
	return {id=id, hp=hp, maxHp=hp, rarity=rarity, material=material,
		coins=math.floor(6 * balance.coinMultipliers[rarity]),
		amount=balance.materialAmounts[rarity], readyAt=0, helperWorked=false}
end

function Domain.chooseRarity(roll: number, weights: {number}): number
	assert(roll >= 1 and roll <= 10000 and roll % 1 == 0)
	local edge = 0
	for i, weight in weights do
		edge += weight
		if roll <= edge then return i end
	end
	error("Invalid rarity weights")
end

function Domain.select(profile: Profile)
	if profile.tutorial == 1 then profile.tutorial = 2 end
end

local function grantStarter(profile: Profile, uid: string)
	if profile.starterGranted then return end
	profile.starterGranted = true
	profile.slimeUid = uid
	profile.equipped = true
end

function Domain.skip(profile: Profile, uid: string)
	if profile.tutorial >= 7 then return end
	if not profile.bonusGranted and profile.coins > 1000000000 - 15 then return end
	grantStarter(profile, uid)
	if not profile.bonusGranted then
		profile.coins += 15
		profile.bonusGranted = true
	end
	profile.teamSlots = 2
	profile.tutorial = 7
	profile.skipped = true
end

function Domain.hit(profile: Profile, node: Node, now: number, helper: boolean,
	uid: string, balance: any): (boolean, string?)
	if not profile.playing or node.hp <= 0 then return false, "NoTarget" end
	if profile.count >= balance.bagCapacity then return false, "BagFull" end
	if helper then
		if not profile.equipped or not profile.slimeUid then return false, "NoSlime" end
		if now - profile.lastSlime < balance.slimeInterval then return false, "Cooldown" end
		profile.lastSlime = now
		node.hp = math.max(0, node.hp - balance.slimePower)
		node.helperWorked = true
	else
		if now - profile.lastManual < balance.manualInterval then return false, "Cooldown" end
		profile.lastManual = now
		node.hp = math.max(0, node.hp - balance.toolPower[profile.toolTier])
	end
	if node.hp > 0 then return true, nil end
	local key = "shore/" .. node.material .. "/" .. tostring(node.rarity)
	local group = profile.cargo[key]
	if not group then
		group = {count=0, coins=node.coins, amount=node.amount, material=node.material}
		profile.cargo[key] = group
	end
	group.count += 1
	profile.count += 1
	profile.collected += 1
	node.readyAt = now + balance.respawnSeconds
	if profile.tutorial == 2 and profile.collected >= 3 then
		grantStarter(profile, uid)
		profile.tutorial = 3
	elseif profile.tutorial == 3 and node.helperWorked then
		profile.tutorial = 4
	end
	return true, nil
end

function Domain.preview(profile: Profile): (number, {[string]: number})
	local coins = 0
	local materials: {[string]: number} = {Plastic=0, Metal=0, Crystal=0}
	for _, group in profile.cargo do
		coins += group.count * group.coins
		materials[group.material] += group.count * group.amount
	end
	return coins, materials
end

function Domain.process(profile: Profile, balance: any): (boolean, string?)
	if profile.count == 0 then return false, "EmptyBag" end
	local coins, materials = Domain.preview(profile)
	local bonus = if profile.tutorial == 4 and not profile.bonusGranted then 15 else 0
	local fragments = math.floor((profile.fragmentRemainder + profile.count) / 15)
	if profile.coins + coins + bonus > balance.coinLimit
		or profile.fragments + fragments > balance.materialLimit then return false, "Limit" end
	for material, amount in materials do
		if profile.materials[material] + amount > balance.materialLimit then return false, "Limit" end
	end
	-- Everything validated before the first mutation.
	profile.coins += coins + bonus
	for material, amount in materials do profile.materials[material] += amount end
	profile.fragments += fragments
	profile.fragmentRemainder = (profile.fragmentRemainder + profile.count) % 15
	profile.processed += profile.count
	profile.count = 0
	profile.cargo = {}
	if bonus > 0 then profile.bonusGranted = true end
	if profile.tutorial == 4 then profile.tutorial = 5 end
	return true, nil
end

function Domain.upgrade(profile: Profile, expectedTier: number, balance: any): (boolean, string?)
	if profile.tutorial < 5 then return false, "FinishTutorialStep" end
	if expectedTier ~= profile.toolTier then return false, "StaleTier" end
	local nextTier = profile.toolTier + 1
	local price = balance.toolPrices[nextTier]
	if not price then return false, "MaxTier" end
	if profile.coins < price then return false, "NotEnoughCoins" end
	profile.coins -= price
	profile.toolTier = nextTier
	if profile.tutorial == 5 then profile.tutorial = 6 end
	return true, nil
end

function Domain.viewNursery(profile: Profile): (boolean, string?)
	if profile.tutorial ~= 6 then return false, "FinishTutorialStep" end
	profile.tutorial = 7
	profile.teamSlots = 2
	return true, nil
end

return Domain
