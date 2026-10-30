--!strict
local Format={}
function Format.number(value: number): string
	local digits=tostring(math.floor(value))
	local result=string.reverse(digits):gsub("(%d%d%d)","%1 "):reverse():gsub("^ ","")
	return result
end
function Format.duration(seconds: number): string
	local n=math.max(0,math.ceil(seconds))
	return string.format("%d:%02d",math.floor(n/60),n%60)
end
return Format
