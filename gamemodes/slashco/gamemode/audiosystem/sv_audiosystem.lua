--[[
	ToDo: Implemement ambient music system
]]

-- This table contains all tables that were played, this was done to support full updates properly later on. Currently Unused.
SlashCo.AudioSystem.Sounds = SlashCo.AudioSystem.Sounds or {}

util.AddNetworkString("slashCo_AudioSystem_PlaySound")
function SlashCo.AudioSystem.PlaySound(soundPath, soundLevel, entity, volume, looping, fadeIn, identifier)
	fadeIn = fadeIn or 0
	identifier = identifier or soundPath

	net.Start("slashCo_AudioSystem_PlaySound")
		net.WriteString(soundPath)
		net.WriteUInt(entity:EntIndex(), MAX_EDICT_BITS)
		net.WriteUInt(soundLevel, 14)
		net.WriteFloat(volume)
		net.WriteBool(looping)
		net.WriteFloat(fadeIn)
		net.WriteUInt(engine.TickCount(), 32) -- To Sync
		net.WriteString(identifier)
	net.Broadcast()

	--[[table.insert(SlashCo.AudioSystem.Sounds, {
		filePath = soundPath,
		level = soundLevel,
		ent = ent:EntIndex(),
		volume = vol,
		permanent = permanent,
		startTime = CurTime()
	})]]
end

util.AddNetworkString("slashCo_AudioSystem_StopSound")
function SlashCo.AudioSystem.StopSound(identifier, fadeOut)
	fadeOut = fadeOut or 0

	net.Start("slashCo_AudioSystem_StopSound")
		net.WriteString(identifier)
		net.WriteFloat(fadeOut)
	net.Broadcast()
end