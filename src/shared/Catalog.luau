--!strict
local C = {
	schemaVersion=1, balanceVersion="balance-0.1.0", protocolVersion=2,
	coinLimit=1000000000, itemLimit=1000000,
	order={"shore", "bay", "cave"},
	islands={
		shore={index=1, ru="Зелёный берег", en="Green Shore", price=0, hp=12, coins=6, power=2,
			factor=1, incubation=80, tea=30, trait=40, materials={70,30,0}, x=0},
		bay={index=2, ru="Железная бухта", en="Iron Bay", price=1500, hp=42, coins=24, power=7,
			factor=4, incubation=360, tea=120, trait=180, materials={20,75,5}, x=400},
		cave={index=3, ru="Кристальные пещеры", en="Crystal Caves", price=9000, hp=120, coins=72, power=20,
			factor=12, incubation=1500, tea=360, trait=750, materials={10,20,70}, x=800},
	},
	materials={"Plastic", "Metal", "Crystal"},
	rarityRu={"Обычный", "Необычный", "Редкий", "Эпический", "Легендарный"},
	rarityEn={"Common", "Uncommon", "Rare", "Epic", "Legendary"},
	junkWeights={6000,2500,1000,400,100}, slimeWeights={5500,2700,1200,500,100},
	hpMultipliers={1,1.3,1.8,2.6,4}, coinMultipliers={1,1.6,2.5,4,7}, amounts={1,2,3,5,8},
	rarityPower={1,1.12,1.25,1.4,1.6}, rankFactors={1,2,3,5,8}, rankPrices={2,5,10},
	recycle={1,2,5,12,30}, craft={8,15,30,80,200},
	tool={values={4,6,9,14,21}, prices={0,30,180,900,3600}, access={1,1,1,2,3}},
	bag={values={12,20,32,48,72}, prices={0,60,240,960,3840}, access={1,1,1,2,3}},
	storage={values={30,60,100}, prices={0,600,2400}, access={1,2,3}},
	species={} :: {[string]: any}, speciesOrder={} :: {string}, sets={} :: {[string]: {string}},
	evolutions={
		shore_sprout={id="iron_sprout", ru="Железный Росток", en="Iron Sprout", island="bay", coins=250, material="Metal", amount=30, role="Breaker"},
		bay_bolt={id="magnetic_bolt", ru="Магнитный Болтик", en="Magnetic Bolt", island="bay", coins=1000, material="Metal", amount=100, role="Breaker"},
		cave_shard={id="crystal_guard", ru="Кристальный Страж", en="Crystal Guard", island="cave", coins=3000, material="Crystal", amount=120, role="Sweeper"},
	},
	traits={"sturdy", "nimble", "metalwork", "crystalwork"}, traitWeights={4000,3000,2000,1000},
	decor={} :: {[string]: any}, decorOrder={} :: {string}, restoration={0,50,200,600},
}
local rows = {
	{"shore_sprout","Росток","Sprout","Collector"}, {"shore_tide","Капля","Tide","Collector"},
	{"shore_moss","Моховик","Moss","Sweeper"}, {"shore_pollen","Пыльцевик","Pollen","Support"},
	{"shore_sun","Солнечный","Sunny","Sweeper"}, {"bay_scrap","Жестянка","Scrap","Collector"},
	{"bay_bolt","Болтик","Bolt","Breaker"}, {"bay_magnet","Магнитик","Magnet","Collector"},
	{"bay_furnace","Печник","Furnace","Breaker"}, {"bay_titan","Титан","Titan","Breaker"},
	{"cave_shard","Осколок","Shard","Collector"}, {"cave_quartz","Кварцик","Quartz","Collector"},
	{"cave_echo","Эхо","Echo","Sweeper"}, {"cave_prism","Призма","Prism","Support"},
	{"cave_nova","Нова","Nova","Sweeper"},
}
for index, row in rows do
	local island = C.order[math.ceil(index/5)]
	C.species[row[1]] = {id=row[1], ru=row[2], en=row[3], role=row[4], island=island, rarity=(index-1)%5+1}
	table.insert(C.speciesOrder, row[1])
	if not C.sets[island] then C.sets[island] = {} end
	table.insert(C.sets[island], row[1])
end
local decorations = {
	{"planter","Клумба","Planter"}, {"bench","Скамья","Bench"}, {"lantern","Фонарь","Lantern"},
	{"banner","Флаг","Banner"}, {"gear","Шестерня","Gear"}, {"pipe","Труба","Pipe"},
	{"robot","Робот","Robot"}, {"crystal","Кристалл","Crystal"}, {"arch","Арка","Arch"},
	{"prism","Призма","Prism"},
}
for index, row in decorations do
	local island = if index<=4 then "shore" elseif index<=7 then "bay" else "cave"
	C.decor[row[1]] = {ru=row[2], en=row[3], island=island, price=if index<=4 then 50 elseif index<=7 then 250 else 1000}
	table.insert(C.decorOrder, row[1])
end
return C
