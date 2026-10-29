--!strict
local Base={}
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
	local folder=model:FindFirstChild("PlacedDecor")
	if not folder then folder=Instance.new("Folder"); folder.Name="PlacedDecor"; folder.Parent=model end
	folder:ClearAllChildren()
	for slot,id in s.profile.base.decorationSlots do
		local n=tonumber(slot) :: number
		local index=table.find(c.decorOrder,id) or 1
		local p=Instance.new("Part")
		p.Name=id; p.Anchored=true; p.CanCollide=false
		p.Shape=if index%3==0 then Enum.PartType.Ball elseif index%3==1 then Enum.PartType.Block else Enum.PartType.Cylinder
		p.Size=Vector3.new(2+index%3,1+index%4,2+index%2)
		p.Color=Color3.fromHSV(index/10,0.45,0.9)
		p.Position=Base.origin(s.slot)+Vector3.new(if n%2==0 then 23 else -23,2+p.Size.Y/2,-24+math.floor((n-1)/2)*9)
		p.Parent=folder
	end
end
return Base
