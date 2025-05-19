SlashCo.AudioSystem.Channels = SlashCo.AudioSystem.Channels or {} -- All IGModAudioChannel instances, use pairs to iterate as it will have holes.
SlashCo.AudioSystem.ParentedChannels = SlashCo.AudioSystem.ParentedChannels or {}
SlashCo.AudioSystem.PrecacheSounds = SlashCo.AudioSystem.PrecacheSounds or {}
SlashCo.AudioSystem.BackgroundChannel = SlashCo.AudioSystem.BackgroundChannel or nil
SlashCo.AudioSystem.ChannelIDs = SlashCo.AudioSystem.ChannelIDs or 0 -- Incremental number to assign channel id's

--[[local slashco_enable_backgroundmusic = CreateClientConVar("slashco_enable_backgroundmusic", "1", true, false)

function SlashCo.AudioSystem.ShouldPlayBackgroundMusic()
	if not slashco_enable_backgroundmusic:GetBool() then return false end -- Client wants to not hear any music.

	return GetGlobal2Bool("SlashCo:ShouldPlayBackgroundMusic", false)
end]]

-- Strips away any spaces & adds the additional stuff.
local function AppendMode(mode, addition)
	return mode:Trim() .. " " .. addition
end

function SlashCo.AudioSystem.NukeChannels()
	for channel, _ in pairs(SlashCo.AudioSystem.Channels) do
		SlashCo.AudioSystem.DestroyChannel(channel, 1)
	end

	for _, precacheData in pairs(SlashCo.AudioSystem.PrecacheSounds) do
		precacheData.channel:__gc()
	end

	SlashCo.AudioSystem.BackgroundChannel = nil
end

-- Removes any invalid channels in case stop sound was executed.
function SlashCo.AudioSystem.CheckChannels()
	for channel, channelData in pairs(SlashCo.AudioSystem.Channels) do
		if not IsValid(channel) then
			SlashCo.AudioSystem.Channels[channel] = nil
		end
	end
end

function SlashCo.AudioSystem.GetChannelID(channel)
	return SlashCo.AudioSystem.Channels[channel].ID
end

-- NOTE: The callback is not called if the channel wasn't created.
function SlashCo.AudioSystem.CreateChannel(soundFile, mode, callback)
	if not soundFile or soundFile == "" then return end

	soundFile = SlashCo.AudioSystem.ToSound(soundFile)
	sound.PlayFile(soundFile, mode, function(channel, errCode, errStr)
		if not IsValid(channel) then
			--ErrorNoHaltWithStack("[SlashCo] Failed to create audio channel! (" .. errCode .. ", " .. errStr .. "," .. soundFile .. ")\n")
			return
		end

		SlashCo.AudioSystem.CheckChannels()
		SlashCo.AudioSystem.ChannelIDs = SlashCo.AudioSystem.ChannelIDs + 1
		SlashCo.AudioSystem.Channels[channel] = { -- ToDo: Actually implement this logic
			deleteWhenFinished = false,
			ID = SlashCo.AudioSystem.ChannelIDs,
		}
		callback(channel)
	end)
end

function SlashCo.AudioSystem.SetChannelIdentifier(channel, identifier)
	SlashCo.AudioSystem.Channels[channel].identifier = identifier
end

function SlashCo.AudioSystem.GetChannelByIdentifier(identifier)
	for channel, channelData in pairs(SlashCo.AudioSystem.Channels) do
		if channelData.identifier == identifier then
			return channel
		end
	end

	return nil
end

-- Precaches a sound that can then be played using the given identifier
function SlashCo.AudioSystem.PrecacheSound(soundFile, mode, identifier, callback)
	local existingPrecacheData = SlashCo.AudioSystem.PrecacheSounds[identifier]
	if existingPrecacheData and IsValid(existingPrecacheData.channel) then
		existingPrecacheData.channel:__gc()
	end

	local precacheData = {
		mode = AppendMode(mode, "noplay"),
		soundFile = SlashCo.AudioSystem.ToSound(soundFile),
		channel = nil,
		creating = true, -- Were creating the channel.
	}
	SlashCo.AudioSystem.PrecacheSounds[identifier] = precacheData

	SlashCo.AudioSystem.CreateChannel(precacheData.soundFile, precacheData.mode, function(channel)
		precacheData.channel = channel
		precacheData.creating = false

		if callback then
			callback(channel)
		end
	end)
end

-- Returns the given precached channel using the identifier, returns nil on failure. If given a callback, it will use that function which will be more reliable.
function SlashCo.AudioSystem.GetPrecachedChannel(identifier, callback, precacheData)
	local precacheData = SlashCo.AudioSystem.PrecacheSounds[identifier]
	if not precacheData then
		if precacheData then
			SlashCo.AudioSystem.PrecacheSound(precacheData.soundFile, precacheData.mode, identifier, function(channel)
				if callback then
					callback(channel)
				end
			end)
		end

		return
	end

	if not IsValid(precacheData.channel) then -- The channel got invalidated somehow, lets recreate it.
		precacheData.creating = true
		SlashCo.AudioSystem.CreateChannel(precacheData.soundFile, precacheData.mode, function(channel)
			precacheData.channel = channel
			precacheData.creating = false

			if callback then
				callback(channel)
			end
		end)
		return
	end

	if callback then
		callback(precacheData.channel)
	else
		return precacheData.channel
	end
end

-- This causes the channel to follow the entities position, BUT the channel WONT be removed if the entity is removed.
function SlashCo.AudioSystem.ParentChannelToEntity(channel, entity)
	local entityIndex = 0
	if isnumber(entity) then
		entityIndex = entity
		entity = nil
	else
		entityIndex = entity:EntIndex()
		if not IsValid(entity) then
			entity = nil
		end
	end

	SlashCo.AudioSystem.ParentedChannels[channel] = {
		ent = entity,
		entIndex = entityIndex,
	}
end

-- Fades out and destroys the channel.
function SlashCo.AudioSystem.DestroyChannel(channel, fadeOutTime)
	if IsValid(channel) and channel:GetState() == GMOD_CHANNEL_PLAYING then
		local vol = channel:GetVolume()
		if vol > 0 then
			local id = SlashCo.AudioSystem.GetChannelID(channel)
			timer.Remove("SlashCo:FadeInAudioChannel" .. id) -- Remove any fadeIn timer that might exist
			local timerName = "SlashCo:ShutdownAudioChannel" .. id
			local updateFreq = 0.05
			local volumeDecrement = vol / math.ceil(fadeOutTime / updateFreq)
			timer.Create(timerName, updateFreq, 0, function() -- Let the sound fade away
				if !IsValid(channel) or vol <= 0 then
					timer.Remove(timerName)
					channel:Stop()
					SlashCo.AudioSystem.CheckChannels()
					SlashCo.AudioSystem.Channels[channel] = nil
					SlashCo.AudioSystem.ParentedChannels[channel] = nil
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
	SlashCo.AudioSystem.ParentedChannels[channel] = nil
end

-- Fades the channel's volume to the target volume.
function SlashCo.AudioSystem.FadeTo(channel, fadeInTime, targetVol)
	targetVol = targetVol or 1
	fadeInTime = fadeInTime or 1

	local vol = channel:GetVolume()
	local lowerVol = targetVol < vol
	local id = SlashCo.AudioSystem.GetChannelID(channel)
	local timerName = "SlashCo:FadeInAudioChannel" .. id
	local updateFreq = 0.05
	local volumeIncrement = math.abs(targetVol - vol) / math.ceil(fadeInTime / updateFreq)
	timer.Create(timerName, updateFreq, 0, function() -- Let the sound fade away
		local reachedTarget = false
		if lowerVol then
			reachedTarget = targetVol >= vol
		else
			reachedTarget = vol >= targetVol
		end

		if !IsValid(channel) or reachedTarget then
			timer.Remove(timerName)
			return
		end

		if lowerVol then
			vol = channel:GetVolume() - volumeIncrement
		else
			vol = channel:GetVolume() + volumeIncrement
		end

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

local lastCreation = 0 -- Doesn't need autorefresh so were fine.
function SlashCo.AudioSystem.PlayBackgroundMusic(fileName)
	if not SlashCo.AudioSystem.ShouldPlayBackgroundMusic() then return end
	if fileName == "" then
		fileName = nil
	end

	local backgroundMusic = SlashCo.AudioSystem.ToSound(fileName or SlashCo.AudioSystem.GetBackgroundMusic())
	if IsValid(SlashCo.AudioSystem.BackgroundChannel) then
		if SlashCo.AudioSystem.BackgroundChannel:GetFileName() == backgroundMusic then return end

		SlashCo.AudioSystem.StopBackgroundMusic()
	end

	-- Delay creations so that it won't try to create a channel while it already tried and is waiting for the callback.
	if (lastCreation + 5) > CurTime() then return end
	lastCreation = CurTime()

	SlashCo.AudioSystem.CreateChannel(backgroundMusic, "mono noplay", function(channel)
		SlashCo.AudioSystem.BackgroundChannel = channel

		channel:SetVolume(0)
		channel:Play()
		channel:EnableLooping(true)
		SlashCo.AudioSystem.BackgroundChannel:SetTime(SlashCo.AudioSystem.GetBackgroundMusicTime())
		SlashCo.AudioSystem.FadeTo(channel, 5, SlashCo.AudioSystem.GetBackgroundMusicVolume())
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

local function OnBackgroundMusicVolumeChange(ent, name, old, new)
	if IsValid(SlashCo.AudioSystem.BackgroundChannel) then
		SlashCo.AudioSystem.FadeTo(SlashCo.AudioSystem.BackgroundChannel, 5, new)
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

	world:SetNW2VarProxy("SlashCo:BackgroundMusicVolume", OnBackgroundMusicVolumeChange)
	OnBackgroundMusicVolumeChange(world, "SlashCo:BackgroundMusicVolume", nil, SlashCo.AudioSystem.GetBackgroundMusicVolume())
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

		local backgroundMusicTime = SlashCo.AudioSystem.GetBackgroundMusicTime()
		if not math.IsNearlyEqual(SlashCo.AudioSystem.BackgroundChannel:GetTime(), backgroundMusicTime, 1) and not GameData.IsSinglePlayer then -- Allow a tolerance of 1 second difference, if were in single player we don't care.
			SlashCo.AudioSystem.BackgroundChannel:SetTime(backgroundMusicTime)
		end
	end
end

local function UpdateChannelPositions()
	for channel, entTbl in pairs(SlashCo.AudioSystem.ParentedChannels) do
		--[[
			Why don't we remove the channel if the parent is gone?
			Because on full updates, the parent might disappear and then reappear.
		]]
		local ent = entTbl.ent or Entity(entTbl.entIndex)
		if not IsValid(ent) then continue end

		entTbl.ent = ent -- In case for some reason the entity didn't exist yet, could happen on full updates?
		channel:SetPos(ent:GetPos())
	end
end

function SlashCo.AudioSystem.Think()
	UpdateBackgroundMusic()
	UpdateChannelPositions()
end

hook.Add("Think", "SlashCo:AudioSystem", SlashCo.AudioSystem.Think)

function SlashCo.AudioSystem.PlaySound(soundPath, soundLevel, entity, volume, looping, fadeIn, identifier, tickCount)
	fadeIn = fadeIn or 0
	tickCount = tickCount or engine.TickCount()

	SlashCo.AudioSystem.StopSound(identifier, 0.5)

	local entIndex = isnumber(entity) and entity or (IsValid(entity) and entity:EntIndex() or 0)
	SlashCo.AudioSystem.CreateChannel(soundPath, entIndex == 0 and "mono" or "3d", function(channel)
		if fadeIn != 0 then
			channel:SetVolume(0)
		else
			channel:SetVolume(volume)
		end

		channel:Play()
		channel:EnableLooping(looping)
		channel:SetTime(SlashCo.AudioSystem.CalculateTime(channel, tickCount))

		if identifier then
			SlashCo.AudioSystem.SetChannelIdentifier(channel, identifier)
		end

		if fadeIn != 0 then
			SlashCo.AudioSystem.FadeTo(channel, fadeIn, volume)
		end

		if entIndex != 0 then
			SlashCo.AudioSystem.ParentChannelToEntity(channel, entIndex)
		end

		if soundLevel != 0 then
			channel:Set3DFadeDistance(soundLevel ^ 1.25, soundLevel ^ 1.5)
		end
	end)
end

function SlashCo.AudioSystem.StopSound(identifier, fadeOut)
	local channel = SlashCo.AudioSystem.GetChannelByIdentifier(identifier)
	if not channel then return end

	SlashCo.AudioSystem.DestroyChannel(channel, fadeOut)
end

net.Receive("slashCo_AudioSystem_PlaySound", function()
	local soundPath = net.ReadString()
	local entIndex = net.ReadUInt(MAX_EDICT_BITS)
	local soundLevel = net.ReadUInt(14)
	local volume = net.ReadFloat()
	local looping = net.ReadBool()
	local fadeIn = net.ReadFloat()
	local tickCount = net.ReadUInt(32)
	local identifier = net.ReadString()

	SlashCo.AudioSystem.PlaySound(soundPath, soundLevel, entIndex, volume, looping, fadeIn, identifier, tickCount)
end)

net.Receive("slashCo_AudioSystem_StopSound", function()
	local identifier = net.ReadString()
	local fadeOut = net.ReadFloat()

	SlashCo.AudioSystem.StopSound(identifier, fadeOut)
end)