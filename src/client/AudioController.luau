--!strict
local SoundService=game:GetService("SoundService")
local A={}
function A.start(config: any): any
	local music=Instance.new("Sound"); music.Name="SlimeMusic"; music.Looped=true; music.Volume=0.15; music.Parent=SoundService
	local effect=Instance.new("Sound"); effect.Name="SlimeEffect"; effect.Volume=0.25; effect.Parent=SoundService
	if config.audio.music~="" then music.SoundId=config.audio.music end
	local settings: any={music=false,sound=false}
	local previous=0
	return {
		settings=function(value: any)
			settings=value
			if settings.music and music.SoundId~="" then if not music.IsPlaying then music:Play() end else music:Pause() end
		end,
		play=function(kind: string)
			if not settings.sound or os.clock()-previous<0.15 or config.audio[kind]=="" then return end
			previous=os.clock(); effect.SoundId=config.audio[kind]; effect:Play()
		end,
	}
end
return A
