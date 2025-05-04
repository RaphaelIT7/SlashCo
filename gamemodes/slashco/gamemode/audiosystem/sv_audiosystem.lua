--[[
	ToDo: Implemement ambient music system
]]

-- This table contains all tables that were played, this was done to support full updates properly later on. Currently Unused.
SlashCo.AudioSystem.Sounds = SlashCo.AudioSystem.Sounds or {}

util.AddNetworkString("slashCo_AudioSystem_PlaySound")
function SlashCo.AudioSystem.PlaySound(soundPath, soundLevel, ent, vol, looping, fadeIn)
	fadeIn = fadeIn or 0

	net.Start("slashCo_AudioSystem_PlaySound")
		net.WriteString(soundPath)
		net.WriteUInt(ent:EntIndex(), 13)
		net.WriteUInt(soundLevel, 14)
		net.WriteFloat(vol)
		net.WriteBool(looping)
		net.WriteFloat(fadeIn)
		net.WriteUInt(engine.TickCount(), 32) -- To Sync
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