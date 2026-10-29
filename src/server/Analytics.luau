--!strict
local RunService=game:GetService("RunService")
local Service=game:GetService("AnalyticsService")
local Analytics={}
function Analytics.funnel(player: Player,step: number,name: string,enabled: boolean)
	if not enabled or RunService:IsStudio() then return end
	task.spawn(function() pcall(function() Service:LogFunnelStepEvent(player,"Onboarding","",step,name) end) end)
end
function Analytics.economy(player: Player,action: string,change: number,balance: number,enabled: boolean)
	if not enabled or change==0 or RunService:IsStudio() then return end
	task.spawn(function() pcall(function()
		Service:LogEconomyEvent(player,if change>0 then Enum.AnalyticsEconomyFlowType.Source else Enum.AnalyticsEconomyFlowType.Sink,
			"Coins",math.abs(change),balance,"Gameplay",action)
	end) end)
end
function Analytics.custom(player: Player,name: string,enabled: boolean)
	if not enabled or RunService:IsStudio() then return end
	task.spawn(function() pcall(function() Service:LogCustomEvent(player,name,1) end) end)
end
return Analytics
