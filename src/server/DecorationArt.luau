--!strict
-- Original geometric props. All pieces stay inside their fixed 6 x 6 slot.
local Art={}
function Art.create(id: string,origin: Vector3,parent: Instance): Model
	local model=Instance.new("Model"); model.Name=id
	local wood=Color3.fromRGB(151,104,65)
	local metal=Color3.fromRGB(100,132,143)
	local green=Color3.fromRGB(102,184,113)
	local gold=Color3.fromRGB(244,204,108)
	local violet=Color3.fromRGB(176,142,224)
	local function piece(name: string,size: Vector3,pos: Vector3,color: Color3,shape: Enum.PartType?,neon: boolean?): Part
		local p=Instance.new("Part"); p.Name=name; p.Size=size; p.Position=origin+pos; p.Color=color
		p.Anchored=true; p.CanCollide=false; p.CanTouch=false; p.CanQuery=false
		p.Material=if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
		if shape then p.Shape=shape end
		p.Parent=model; return p
	end
	if id=="planter" then
		piece("Bed",Vector3.new(4,0.8,3),Vector3.new(0,0.4,0),wood)
		piece("Soil",Vector3.new(3.6,0.2,2.6),Vector3.new(0,0.9,0),Color3.fromRGB(83,66,49))
		for i=-1,1 do
			piece("Stem",Vector3.new(0.2,1.2,0.2),Vector3.new(i,1.5,0),green)
			piece("Flower",Vector3.new(0.9,0.7,0.9),Vector3.new(i,2.2,0),gold,Enum.PartType.Ball)
		end
	elseif id=="bench" then
		for _,x in {-1.6,1.6} do piece("Leg",Vector3.new(0.5,1.5,1.8),Vector3.new(x,0.75,0),metal) end
		piece("Seat",Vector3.new(4.6,0.4,2),Vector3.new(0,1.6,0),wood)
		piece("Back",Vector3.new(4.6,1.5,0.35),Vector3.new(0,2.5,0.8),wood)
	elseif id=="lantern" then
		piece("Foot",Vector3.new(2,0.3,2),Vector3.new(0,0.15,0),metal)
		piece("Post",Vector3.new(0.35,3,0.35),Vector3.new(0,1.7,0),metal)
		piece("Light",Vector3.new(1.1,1.4,1.1),Vector3.new(0,3.7,0),gold,nil,true)
		piece("Cap",Vector3.new(1.7,0.35,1.7),Vector3.new(0,4.6,0),metal)
	elseif id=="banner" then
		piece("Foot",Vector3.new(2,0.3,2),Vector3.new(0,0.15,0),wood)
		piece("Pole",Vector3.new(0.25,4.8,0.25),Vector3.new(-1,2.5,0),metal)
		piece("Flag",Vector3.new(2.7,1.8,0.2),Vector3.new(0.4,3.8,0),green)
		piece("Emblem",Vector3.new(0.8,0.8,0.25),Vector3.new(0.4,3.8,-0.15),gold,Enum.PartType.Ball)
	elseif id=="gear" then
		local wheel=piece("Hub",Vector3.new(1,3,3),Vector3.new(0,1.8,0),metal,Enum.PartType.Cylinder)
		wheel.CFrame*=CFrame.Angles(0,math.pi/2,0)
		for i=0,7 do
			local a=i*math.pi/4
			local tooth=piece("Tooth",Vector3.new(0.8,0.8,1),Vector3.new(math.cos(a)*1.6,1.8+math.sin(a)*1.6,0),gold)
			tooth.CFrame*=CFrame.Angles(0,0,a)
		end
	elseif id=="pipe" then
		for _,x in {-1,1} do
			local p=piece("Pipe",Vector3.new(3.5,1,1),Vector3.new(x,1.75,0),metal,Enum.PartType.Cylinder)
			p.CFrame*=CFrame.Angles(0,0,math.pi/2)
			local rim=piece("Rim",Vector3.new(0.35,1.4,1.4),Vector3.new(x,3.5,0),gold,Enum.PartType.Cylinder)
			rim.CFrame*=CFrame.Angles(0,0,math.pi/2)
		end
	elseif id=="robot" then
		for _,x in {-0.7,0.7} do piece("Foot",Vector3.new(0.8,0.7,1.3),Vector3.new(x,0.35,0),metal) end
		piece("Body",Vector3.new(2.2,1.8,1.4),Vector3.new(0,1.6,0),metal)
		piece("Head",Vector3.new(2.5,1.3,1.7),Vector3.new(0,3.2,0),gold)
		for _,x in {-0.6,0.6} do piece("Eye",Vector3.new(0.35,0.35,0.2),Vector3.new(x,3.3,-0.9),green,Enum.PartType.Ball,true) end
		piece("Antenna",Vector3.new(0.2,0.7,0.2),Vector3.new(0,4.1,0),metal)
	elseif id=="crystal" or id=="prism" then
		piece("Rock",Vector3.new(4.5,0.6,3.8),Vector3.new(0,0.3,0),metal,Enum.PartType.Ball)
		for i=-1,1 do
			local shard=piece("Shard",Vector3.new(1,if i==0 then 3.5 else 2.3,1),Vector3.new(i*1.2,if i==0 then 2.1 else 1.5,0),if id=="prism" then Color3.fromHSV((i+1)/3,0.35,1) else violet,nil,true)
			shard.CFrame*=CFrame.Angles(0,math.pi/4,-i*0.2)
		end
	elseif id=="arch" then
		for _,x in {-2,2} do piece("Pillar",Vector3.new(0.8,4.2,0.8),Vector3.new(x,2.1,0),violet) end
		piece("Lintel",Vector3.new(5,0.8,1),Vector3.new(0,4.5,0),violet)
		piece("Keystone",Vector3.new(1,1,1.2),Vector3.new(0,4.5,0),gold,nil,true)
	else error("Unknown decoration: "..id) end
	model.Parent=parent; return model
end
return Art
