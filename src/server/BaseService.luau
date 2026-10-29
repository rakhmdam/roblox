--!strict
local Base={}
local Art=require(script.Parent:WaitForChild("DecorationArt"))
local slots: {[number]: Player}={}
function Base.origin(slot: number): Vector3
	return Vector3.new(((slot-1)%4-1.5)*150,0,-240-math.floor((slot-1)/4)*150)
end
function Base.claim(player: Player): number?
	for slot=1,8 do if not slots[slot] then slots[slot]=player; return slot end end
	return nil
end
function Base.release(slot: number)
	slots[slot]=nil
	local model=workspace:FindFirstChild("Base"..tostring(slot))
	if model then
		model:SetAttribute("OwnerId",nil)
		local decor=model:FindFirstChild("PlacedDecor"); if decor then decor:ClearAllChildren() end
		local restored=model:FindFirstChild("RestorationArt"); if restored then restored:ClearAllChildren() end
	end
end
function Base.paint(player: Player,s: any,c: any)
	local model=workspace:FindFirstChild("Base"..tostring(s.slot))
	if not model then return end
	local signature=tostring(s.profile.base.restorationTier)
	for slot=1,12 do signature..="/"..(s.profile.base.decorationSlots[tostring(slot)] or "-") end
	if s.baseArtSignature==signature then return end
	s.baseArtSignature=signature
	model:SetAttribute("OwnerId",player.UserId); model:SetAttribute("Restoration",s.profile.base.restorationTier)
	local garden=model:FindFirstChild("Garden")
	if garden and garden:IsA("BasePart") then
		local colors={Color3.fromRGB(143,142,100),Color3.fromRGB(126,157,92),Color3.fromRGB(104,172,91),Color3.fromRGB(85,192,107)}
		garden.Color=colors[s.profile.base.restorationTier]
	end
	local restored=model:FindFirstChild("RestorationArt")
	if not restored then restored=Instance.new("Folder"); restored.Name="RestorationArt"; restored.Parent=model end
	restored:ClearAllChildren()
	local tier=s.profile.base.restorationTier
	local origin=Base.origin(s.slot)
	if tier>=2 then
		for _,x in {-8,8} do Art.create("planter",origin+Vector3.new(x,1.5,29),restored) end
	end
	if tier>=3 then
		Art.create("bench",origin+Vector3.new(12,1.5,-30),restored)
		Art.create("banner",origin+Vector3.new(-12,1.5,-30),restored)
	end
	if tier>=4 then
		for _,x in {-8,8} do Art.create("lantern",origin+Vector3.new(x,1.5,38),restored) end
		Art.create("crystal",origin+Vector3.new(0,1.5,-30),restored)
	end
	local folder=model:FindFirstChild("PlacedDecor")
	if not folder then folder=Instance.new("Folder"); folder.Name="PlacedDecor"; folder.Parent=model end
	folder:ClearAllChildren()
	for slot,id in s.profile.base.decorationSlots do
		local n=tonumber(slot) :: number
		if c.decor[id] then
			Art.create(id,Base.origin(s.slot)+Vector3.new(if n%2==0 then 27 else -27,1.5,-24+math.floor((n-1)/2)*9),folder)
		end
	end
end
return Base
