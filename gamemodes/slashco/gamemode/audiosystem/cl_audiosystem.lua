SlashCo.AudioSystem.Channels = SlashCo.AudioSystem.Channels or {} -- All IGModAudioChannel instances
SlashCo.AudioSystem.BackgroundChannel = SlashCo.AudioSystem.BackgroundChannel or nil

--[[local slashco_enable_backgroundmusic = CreateClientConVar("slashco_enable_backgroundmusic", "1", true, false)

function SlashCo.AudioSystem.ShouldPlayBackgroundMusic()
	if not slashco_enable_backgroundmusic:GetBool() then return false end -- Client wants to not hear any music.

	return GetGlobal2Bool("SlashCo:ShouldPlayBackgroundMusic", false)
end]]

-- Simple function. Adds sound/ to the given fileName to properly work with sound.PlayFile
local function ToSound(fileName)
	if fileName:StartsWith("sound/") then
		return fileName
	end
	
	return "sound/" .. fileName
end

function SlashCo.AudioSystem.NukeChannels()
	for channel, _ in pairs(SlashCo.AudioSystem.Channels) do
		SlashCo.AudioSystem.DestroyChannel(channel, 1)
	end

	SlashCo.AudioSystem.BackgroundChannel = nil
end

-- Removes any invalid channels in case stop sound was executed.
function SlashCo.AudioSystem.CheckChannels()
	for channel, _ in pairs(SlashCo.AudioSystem.Channels) do
		if not IsValid(channel) then
			SlashCo.AudioSystem.Channels[channel] = nil
		end
	end
end

function SlashCo.AudioSystem.CreateChannel(soundFile, mode, callback)
	sound.PlayFile(ToSound(soundFile), mode, function(channel, errCode, errStr)
		if not IsValid(channel) then
			Error("[SlashCo] Failed to create audio channel! (" .. errCode .. ", " .. errStr .. ")")
			return
		end

		SlashCo.AudioSystem.CheckChannels()
		SlashCo.AudioSystem.Channels[channel] = true
		callback(channel)
	end)
end

function SlashCo.AudioSystem.DestroyChannel(channel, fadeOutTime)
	if channel:GetState() == GMOD_CHANNEL_PLAYING then
		local vol = channel:GetVolume()
		if vol > 0 then
			timer.Remove("SlashCo:FadeInAudioChannel" .. channel:GetFileName()) -- Remove any fadeIn timer that might exist
			local timerName = "SlashCo:ShutdownAudioChannel" .. channel:GetFileName()
			local updateFreq = 0.05
			local volumeDecrement = vol / math.ceil(fadeOutTime / updateFreq)
			timer.Create(timerName, updateFreq, 0, function() -- Let the sound fade away
				if !IsValid(channel) or vol <= 0 then
					timer.Remove(timerName)
					channel:Stop()
					SlashCo.AudioSystem.CheckChannels()
					SlashCo.AudioSystem.Channels[channel] = nil
					return
				end

				vol = channel:GetVolume() - volumeDecrement
				channel:SetVolume(vol)
			end)

			return
		end
	end

	SlashCo.AudioSystem.CheckChannels()
	SlashCo.AudioSystem.Channels[channel] = nil
end

function SlashCo.AudioSystem.FadeIn(channel, fadeInTime, targetVol)
	targetVol = targetVol or 1
	fadeInTime = fadeInTime or 1

	local vol = channel:GetVolume()
	local timerName = "SlashCo:FadeInAudioChannel" .. channel:GetFileName()
	local updateFreq = 0.05
	local volumeIncrement = targetVol / math.ceil(fadeInTime / updateFreq)
	timer.Create(timerName, updateFreq, 0, function() -- Let the sound fade away
		if !IsValid(channel) or vol >= 1 then
			timer.Remove(timerName)
			return
		end

		vol = channel:GetVolume() + volumeIncrement
		channel:SetVolume(vol)
	end)
end

function SlashCo.AudioSystem.StopBackgroundMusic()
	SlashCo.AudioSystem.DestroyChannel(SlashCo.AudioSystem.BackgroundChannel, 1)
	SlashCo.AudioSystem.BackgroundChannel = nil
end

-- Returns the calculated time a channel is supposed to be at, it accounts for looping sounds
function SlashCo.AudioSystem.CalculateTime(channel, tickCount)
	local calculateTime = (engine.TickCount() - tickCount) * engine.TickInterval()
	local fileLength = channel:GetLength()
	return calculateTime - (fileLength * math.floor(calculateTime / fileLength))
end

-- Returns the current background music time syncronized with all players.
function SlashCo.AudioSystem.GetBackgroundMusicTime()
	return SlashCo.AudioSystem.CalculateTime(SlashCo.AudioSystem.BackgroundChannel, GetGlobal2Int("SlashCo:StartTimeBackgroundMusic"))
end

function SlashCo.AudioSystem.PlayBackgroundMusic(fileName)
	if not SlashCo.AudioSystem.ShouldPlayBackgroundMusic() then return end

	local backgroundMusic = ToSound(fileName or SlashCo.AudioSystem.GetBackgroundMusic())
	if IsValid(SlashCo.AudioSystem.BackgroundChannel) then
		if SlashCo.AudioSystem.BackgroundChannel:GetFileName() == backgroundMusic then return end

		SlashCo.AudioSystem.StopBackgroundMusic()
	end

	SlashCo.AudioSystem.CreateChannel(backgroundMusic, "mono noplay", function(channel)
		SlashCo.AudioSystem.BackgroundChannel = channel

		channel:SetVolume(0)
		channel:Play()
		channel:EnableLooping(true)
		SlashCo.AudioSystem.BackgroundChannel:SetTime(SlashCo.AudioSystem.GetBackgroundMusicTime())
		SlashCo.AudioSystem.FadeIn(channel, 5)
	end)
end

-- This is a NW2 Proxy function.
local function OnBackgroundMusicChange(ent, name, old, new)
	SlashCo.AudioSystem.PlayBackgroundMusic(new)
end

-- This is a NW2 Proxy function.
local function OnBackgroundMusicStateChange(ent, name, old, new)
	if not new then
		if IsValid(SlashCo.AudioSystem.BackgroundChannel) then
			SlashCo.AudioSystem.StopBackgroundMusic()
		end
	else
		SlashCo.AudioSystem.PlayBackgroundMusic()
	end
end

function SlashCo.AudioSystem.Init()
	local world = game.GetWorld()

	--[[
		Setting up the proxies in case the background music changes.
		then we manually call the var proxy because the NW2Vars at this point were already networked so our proxy won't catch the initial value.
	]]
	world:SetNW2VarProxy("SlashCo:BackgroundMusic", OnBackgroundMusicChange)
	OnBackgroundMusicChange(world, "SlashCo:BackgroundMusic", nil, SlashCo.AudioSystem.GetBackgroundMusic())

	world:SetNW2VarProxy("SlashCo:ShouldPlayBackgroundMusic", OnBackgroundMusicStateChange)
	OnBackgroundMusicStateChange(world, "SlashCo:ShouldPlayBackgroundMusic", nil, SlashCo.AudioSystem.ShouldPlayBackgroundMusic())
end

hook.Add("InitPostEntity", "SlashCo:AudioSystem", SlashCo.AudioSystem.Init)
if game.GetWorld() != NULL then
	SlashCo.AudioSystem.Init()
end

local function UpdateBackgroundMusic()
	if not SlashCo.AudioSystem.ShouldPlayBackgroundMusic() then return end

	if not IsValid(SlashCo.AudioSystem.BackgroundChannel) then
		SlashCo.AudioSystem.PlayBackgroundMusic()
	else
		if SlashCo.AudioSystem.BackgroundChannel:GetState() != GMOD_CHANNEL_PLAYING then -- Fk stopsound
			SlashCo.AudioSystem.BackgroundChannel:Play()
		end
	end

	local backgroundMusicTime = SlashCo.AudioSystem.GetBackgroundMusicTime()
	if not math.IsNearlyEqual(SlashCo.AudioSystem.BackgroundChannel:GetTime(), backgroundMusicTime, 1) then -- Allow a tolerance of 1 second difference.
		SlashCo.AudioSystem.BackgroundChannel:SetTime(backgroundMusicTime)
	end
end

function SlashCo.AudioSystem.Think()
	UpdateBackgroundMusic()
end
hook.Add("Think", "SlashCo:AudioSystem", SlashCo.AudioSystem.Think)