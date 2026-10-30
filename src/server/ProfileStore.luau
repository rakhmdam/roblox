--!strict
local DataStoreService=game:GetService("DataStoreService")
local RunService=game:GetService("RunService")
local HttpService=game:GetService("HttpService")
local Schema=require(script.Parent:WaitForChild("ProfileSchema"))
local Lease=require(script.Parent:WaitForChild("Lease"))
local Store={}
Store.__index=Store
function Store.new(config: any,catalog: any): any
	assert(table.find({"Test","Beta","Production"},config.environment),"Invalid environment")
	assert(not (RunService:IsStudio() and config.environment=="Production"),"Studio may not write Production")
	return setmetatable({catalog=catalog,ds=DataStoreService:GetDataStore("SlimeSalvage_"..config.environment.."_v1")},Store)
end

function Store.load(self: any,userId: number): (any,string?)
	local token=HttpService:GenerateGUID(false)
	local start=os.clock()
	for attempt=1,5 do
		local reason="LoadFailed"
		local ok,record=pcall(function()
			return self.ds:UpdateAsync("u_"..tostring(userId),function(old: any)
				local now=os.time()
				local result,err=Lease.acquire(old,token,now,function() return Schema.new(now,self.catalog) end,
					function(data: any) return Schema.validate(data,self.catalog) end)
				if not result then reason=err end
				return result
			end)
		end)
		if ok and record and record.lease and record.lease.token==token then
			return {key="u_"..tostring(userId),token=token,expires=record.lease.expires,
				data=record.data,savedRevision=record.data.revision,lastCommit=record.commitId},nil
		end
		if ok and reason~="ProfileLocked" and reason~="LoadFailed" then return nil,reason end
		if os.clock()-start>=40 then break end
		if attempt<5 then task.wait(math.min(8,2^(attempt-1))+math.random()) end
	end
	return nil,"LoadFailed"
end

function Store.save(self: any,handle: any,candidate: any,writeId: string,release: boolean?): (boolean,string?)
	local valid,err=Schema.validate(candidate,self.catalog)
	if not valid then return false,err end
	local encodedOk,encoded=pcall(function() return HttpService:JSONEncode(candidate) end)
	if not encodedOk or #encoded>200000 then return false,"ProfileSize" end
	local expected=handle.savedRevision
	local reason="SaveFailed"
	local ok,record=pcall(function()
		return self.ds:UpdateAsync(handle.key,function(old: any)
			-- A previous response can be lost after a successful write. Confirm the same write,
			-- never roll a new result or overwrite a newer revision during a retry.
			local result,err=Lease.write(old,handle.token,expected,candidate,writeId,release,os.time())
			if not result then reason=err end
			return result
		end)
	end)
	if not ok or not record or record.commitId~=writeId then return false,reason end
	handle.savedRevision=candidate.revision
	handle.expires=if release then 0 else record.lease.expires
	handle.data=candidate
	return true,nil
end
return Store
