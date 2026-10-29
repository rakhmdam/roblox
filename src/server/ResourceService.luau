--!strict
local R={}
local function distance(a: {number},b: {number}): number
	return math.sqrt((a[1]-b[1])^2+(a[2]-b[2])^2+(a[3]-b[3])^2)
end
function R.positions(island: string,c: any): {{number}}
	local result={}
	for row=0,5 do for col=0,5 do
		local x=if col<3 then -25+col*8 else 9+(col-3)*8
		table.insert(result,{c.islands[island].x+x,2.8,-25+row*6})
	end end
	return result
end
function R.node(id: number,island: string,p: any,nodes: {any},random: any,c: any,g: any): any
	local simple=0
	for _,n in nodes do if n.hp>0 and n.rarity<=2 then simple+=1 end end
	local rarity=g.roll(c.junkWeights,random)
	if simple<12 or (island=="shore" and p.tutorial.step<=3) then rarity=1 end
	local material=c.materials[g.roll(c.islands[island].materials,random)]
	local hp=math.ceil(c.islands[island].hp*c.hpMultipliers[rarity])
	return {id=id,island=island,rarity=rarity,material=material,
		family=table.find(c.materials,material),hp=hp,maxHp=hp,
		coins=math.floor(c.islands[island].coins*c.coinMultipliers[rarity]),amount=c.amounts[rarity],
		position=R.positions(island,c)[id],helperWorked=false,state="Idle",readyAt=0}
end
function R.activate(s: any,island: string,random: any,c: any,g: any)
	s.fields=s.fields or {}
	if not s.fields[island] then
		local nodes={}; for id=1,36 do nodes[id]=R.node(id,island,s.profile,nodes,random,c,g) end
		s.fields[island]=nodes
	end
	s.nodes=s.fields[island]; s.selected=nil; s.attackClocks=s.attackClocks or {}; s.hitCounts=s.hitCounts or {}
end
function R.tick(s: any,now: number,wall: number,random: any,c: any,g: any,canHit: any): boolean
	if not c.islands[s.location] then return false end
	local changed=false
	for id,node in s.nodes do
		if node.hp<=0 and now>=node.readyAt then
			s.nodes[id]=R.node(id,s.location,s.profile,s.nodes,random,c,g); changed=true
		end
	end
	if not s.playing or s.modal or s.busy then return changed end
	local node=if type(s.selected)=="number" then s.nodes[s.selected] else nil
	if not node or node.hp<=0 then return changed end
	if g.cargoCount(s.profile)>=c.bag.values[s.profile.equipment.bagTier] then s.selected=nil; return true end
	if not canHit(node.position,24) then
		s.outsideSince=s.outsideSince or now
		if now-s.outsideSince>1 then s.selected=nil; return true end
		return changed
	end
	s.outsideSince=nil
	node.state="Working"
	local function hit(target: any,power: number,helper: boolean)
		if target.hp<=0 or g.cargoCount(s.profile)>=c.bag.values[s.profile.equipment.bagTier] then return end
		target.hp=math.max(0,target.hp-power); target.helperWorked=target.helperWorked or helper; changed=true
		if target.hp<=0 then
			local ok=g.collect(s.profile,target,target.helperWorked,s.nextUid(),c)
			assert(ok,"Capacity checked before damage")
			target.state="RespawnCooldown"; target.readyAt=now+random(8,12)
		end
	end
	for _,uid in s.profile.team do
		if node.hp<=0 then break end
		local power,interval,role=g.damage(s.profile,uid,node.material,wall,c)
		if not s.attackClocks[uid] then s.attackClocks[uid]=now end
		local last=s.attackClocks[uid]
		if now-last>=interval then
			s.attackClocks[uid]=now; s.hitCounts[uid]=(s.hitCounts[uid] or 0)+1
			hit(node,power,true)
			if role=="Sweeper" and s.hitCounts[uid]%5==0 then
				local closest,range=nil,6.001
				for _,other in s.nodes do
					local d=distance(node.position,other.position)
					if other~=node and other.hp>0 and d<range then closest=other; range=d end
				end
				if closest then hit(closest,power*0.3,true) end
			end
		end
	end
	if node.hp>0 and canHit(node.position,14) then
		if not s.attackClocks.manual then s.attackClocks.manual=now end
		local power,interval=g.damage(s.profile,nil,node.material,wall,c)
		if now-(s.attackClocks.manual or now)>=interval then s.attackClocks.manual=now; hit(node,power,false) end
	end
	if node.hp<=0 then
		s.selected=nil
		if s.profile.settings.autoRepeat and s.profile.tutorial.step>=7 then
			for _,candidate in s.nodes do
				if candidate.hp>0 and canHit(candidate.position,14) then s.selected=candidate.id; break end
			end
		end
	end
	return changed
end
return R
