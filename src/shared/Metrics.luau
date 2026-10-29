--!strict
-- Bounded local recorder for the private Test build. No telemetry or profile writes.
local Metrics={}
function Metrics.new(capacity: number): any
	assert(capacity>=1 and capacity%1==0)
	return {capacity=capacity,values={},next=1}
end
function Metrics.add(recorder: any,milliseconds: number)
	if milliseconds~=milliseconds or milliseconds<0 or milliseconds==math.huge then return end
	recorder.values[recorder.next]=milliseconds
	recorder.next=recorder.next%recorder.capacity+1
end
function Metrics.summary(recorder: any): any
	local values=table.clone(recorder.values); table.sort(values)
	local n=#values
	if n==0 then return {count=0,median=0,p95=0,max=0} end
	return {count=n,median=values[math.max(1,math.ceil(n*.5))],p95=values[math.ceil(n*.95)],max=values[n]}
end
return Metrics
