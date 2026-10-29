--!strict
local RunService=game:GetService("RunService")
local Service=game:GetService("AnalyticsService")
local C=require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Catalog"))
local Analytics={}
local function fields(island: string?,category: string?): any
	return {[Enum.AnalyticsCustomFieldKeys.CustomField01.Name]=C.balanceVersion,
		[Enum.AnalyticsCustomFieldKeys.CustomField02.Name]=island or "none",
		[Enum.AnalyticsCustomFieldKeys.CustomField03.Name]=category or "gameplay"}
end
function Analytics.funnel(player: Player,step: number,name: string,enabled: boolean)
	if not enabled or RunService:IsStudio() then return end
	task.spawn(function() pcall(function() Service:LogOnboardingFunnelStepEvent(player,step,name,fields()) end) end)
end
function Analytics.economy(player: Player,action: string,change: number,balance: number,enabled: boolean,context: any?)
	if not enabled or change==0 or RunService:IsStudio() then return end
	task.spawn(function() pcall(function()
		Service:LogEconomyEvent(player,if change>0 then Enum.AnalyticsEconomyFlowType.Source else Enum.AnalyticsEconomyFlowType.Sink,
			"Coins",math.abs(change),balance,"Gameplay",if context then context.sku else action,
			fields(if context then context.island else nil,action))
	end) end)
end
function Analytics.custom(player: Player,name: string,enabled: boolean,island: string?)
	if not enabled or RunService:IsStudio() then return end
	task.spawn(function() pcall(function() Service:LogCustomEvent(player,name,1,fields(island,name)) end) end)
end
return Analytics
