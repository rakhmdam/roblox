--!strict
local Lease={}
function Lease.acquire(old: any,token: string,now: number,newProfile: ()->any,validate: (any)->(boolean,string?)): (any,string?)
	if old==nil then old={data=newProfile()} end
	if type(old)~="table" or type(old.data)~="table" then return nil,"ProfileShape" end
	local valid,err=validate(old.data)
	if not valid then return nil,err end
	if old.lease and (type(old.lease)~="table" or type(old.lease.expires)~="number") then return nil,"LeaseShape" end
	if old.lease and old.lease.token~=token and old.lease.expires>now then return nil,"ProfileLocked" end
	return {data=old.data,lease={token=token,expires=now+180},commitId=old.commitId},nil
end
function Lease.write(old: any,token: string,expected: number,candidate: any,writeId: string,release: boolean?,now: number): (any,string?)
	if not old or not old.lease or old.lease.token~=token or old.lease.expires<=now then return nil,"LeaseLost" end
	if old.commitId~=writeId and old.data.revision~=expected then return nil,"RevisionConflict" end
	return {data=candidate,commitId=writeId,lease=if release then nil else {token=token,expires=now+180}},nil
end
return Lease
