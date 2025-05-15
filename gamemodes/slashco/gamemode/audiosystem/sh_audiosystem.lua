SlashCo = SlashCo or {} -- We load VERY early.
SlashCo.AudioSystem = SlashCo.AudioSystem or {}

--[[
	The Background music is networked & syncronized.
	Later there will be a helper function to do this with other sounds too.
	This whole audio system is meant to efficiently syncronize and play sounds for players
]]


-- Simple function. Adds sound/ to the given fileName to properly work with sound.PlayFile
function SlashCo.AudioSystem.ToSound(fileName)
	if fileName:StartsWith("sound/") then
		return fileName
	end
	
	return "sound/" .. fileName
end

function SlashCo.AudioSystem.ShouldPlayBackgroundMusic()
	return GetGlobal2Bool("SlashCo:ShouldPlayBackgroundMusic", false)
end

function SlashCo.AudioSystem.EnableBackgroundMusic()
	SetGlobal2Bool("SlashCo:ShouldPlayBackgroundMusic", true)
end

function SlashCo.AudioSystem.DisableBackgroundMusic()
	SetGlobal2Bool("SlashCo:ShouldPlayBackgroundMusic", false)
end

function SlashCo.AudioSystem.SetBackgroundMusic(soundFile, volume)
	SetGlobal2String("SlashCo:BackgroundMusic", soundFile)
	SetGlobal2Float("SlashCo:BackgroundMusicVolume", volume or 1)
	SetGlobal2Int("SlashCo:StartTimeBackgroundMusic", engine.TickCount()) -- Timestamp to syncronize the music for everyone
end

function SlashCo.AudioSystem.GetBackgroundMusic(fallBack)
	return GetGlobal2String("SlashCo:BackgroundMusic", fallBack or "")
end

function SlashCo.AudioSystem.GetBackgroundMusicVolume(fallBack)
	return GetGlobal2Float("SlashCo:BackgroundMusicVolume", fallBack or 1)
end

function SlashCo.AudioSystem.PrecacheSound(soundFile)
	-- ToDo
end

-- Server & client files are loaded at last
if SERVER then
	include("sv_audiosystem.lua")
	AddCSLuaFile("cl_audiosystem.lua")
	AddCSLuaFile()
else
	include("cl_audiosystem.lua")
end