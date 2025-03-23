GM.Name = "SlashCo"
GM.Author = "Octo, Manti, Text"
GM.Email = "N/A"
GM.Website = "N/A"
GM.TeamBased = true
GM.States = {
	LOBBY = 1,
	IN_GAME = 2
}
GM.State = GM.State or GM.States.LOBBY

include("player_class/player_survivor.lua")
include("player_class/player_slasher_base.lua")
include("player_class/player_lobby.lua")

SlashCo = SlashCo or {}

SlashCo.GasPerGen = 4 --Default number of gas cans required to fill up a generator
SlashCo.Generators = 2 --Default number of generators
SlashCo.GensNeeded = 2 --Default number of generators needed
SlashCo.GeneratorModel = "models/slashco/other/generator/generator.mdl" --Model path for the generators
SlashCo.HelicopterModel = "models/slashco/other/helicopter/helicopter.mdl" --Model path for the helicopter
SlashCo.GhostPingDelay = 480

SlashCo.HelicopterVoices = {
	INTRO = 1,
	APPROACH = 2,
	LAND = 3,
	BEACON = 4,
}

SlashCo.DangerLevel = {
	Unknown = 0,
	[0] = "Unknown",

	Moderate = 1,
	[1] = "Moderate",

	Considerable = 2,
	[2] = "Considerable",

	Devastating = 3,
	[3] = "Devastating",
}

SlashCo.SlasherClass = {
	Unknown = 0,
	[0] = "Unknown",

	Cryptid = 1,
	[1] = "Cryptid",

	Demon = 2,
	[2] = "Demon",

	Umbra = 3,
	[3] = "Umbra",
}

SlashCo.RoundState = {
	[0] = WON_ALL_ALIVE,
	WON_ALL_ALIVE = 0,

	[1] = WON_SOME_DEAD,
	WON_SOME_DEAD = 1,

	[2] = WON_ALL_DEAD,
	WON_ALL_DEAD = 2,

	[3] = LOST,
	LOST = 3,

	[4] = WON_DISTRESS,
	WON_DISTRESS = 4,

	[5] = TEST,
	TEST = 5,
}

GameData = GameData or {} -- A table containing data that is frequently used.
GameData.Map = game.GetMap()
GameData.Lobby = "sc_lobby" -- Map name of the lobby
GameData.IsLobby = GameData.Map == GameData.Lobby

if CLIENT then
	--GameData.LocalPlayer = nil
	--GameData.LocalSteamID = nil
	--GameData.LocalSteamID64 = nil

	function GM:InitPostEntity()
		GameData.LocalPlayer = LocalPlayer()
		GameData.LocalSteamID = GameData.LocalPlayer:SteamID()
		GameData.LocalSteamID64 = GameData.LocalPlayer:SteamID64()
	end
end

local lang_files, _ = file.Find("slashco/lang/*.lua", "LUA")
for _, v in ipairs(lang_files) do
	AddCSLuaFile("slashco/lang/" .. v)
end

local lang_patches, _ = file.Find("slashco/patch/lang/*.lua", "LUA")
for _, v in ipairs(lang_patches) do
	AddCSLuaFile("slashco/patch/lang/" .. v)
end

function GM:Initialize()
	-- Do stuff
end

function GM:CreateTeams()
	if not GAMEMODE.TeamBased then
		return
	end

	TEAM_SURVIVOR = 1
	team.SetUp(TEAM_SURVIVOR, "Survivor", Color(255, 255, 255))

	TEAM_SLASHER = 2
	team.SetUp(TEAM_SLASHER, "Slasher", Color(255, 0, 0))

	TEAM_LOBBY = 3
	team.SetUp(TEAM_LOBBY, "Lobby", Color(230, 255, 230))

	team.SetUp(TEAM_SPECTATOR, "Spectator", Color(135, 206, 235))
end

local DoorSlamWhitelist = {
	["models/props_c17/door03_left.mdl"] = true,
	["models/props_doors/doormain_rural01_small.mdl"] = true,
	["models/props_doors/doormainmetal01.mdl"] = true,
	["models/props_c17/door01_left.mdl"] = true,
	["models/props_c17/door_fg.mdl"] = true,
	["models/props_doors/doormain01.mdl"] = true,
	["models/props_doors/doorglassmain01.mdl"] = true,
	["models/props_doors/door_rotate_112.mdl"] = true,
	["models/props_doors/doormainmetalwindow01.mdl"] = true,
	["models/props_c17/door01_addg_medium.mdl"] = true
}

function SlashCo.CheckDoorWL(ent)
	return DoorSlamWhitelist[ent:GetModel()]
end

function SlashCo.Dampen(speed, from, to)
	return Lerp(1 - math.exp(-speed * FrameTime()), from, to)
end

SCInfo = {}

SCInfo.Offering = {
	{
		Name = "Exposure",
		Rarity = 1,
		GasCanMod = 0
	},
	{
		Name = "Satiation",
		Rarity = 1,
		GasCanMod = 0
	},
	{
		Name = "Drainage",
		Rarity = 2,
		GasCanMod = 6
	},
	{
		Name = "Duality",
		Rarity = 3,
		GasCanMod = 0
	},
	{
		Name = "Singularity",
		Rarity = 3,
		GasCanMod = 6
	},
	{
		Name = "Nightmare",
		Rarity = 3,
		GasCanMod = 0
	}
}

SCInfo.Maps = {
	["error"] = {
		NAME = "Missing map!",
		DEFAULT = true,
		SIZE = 1,
		MIN_PLAYERS = 1,
		LEVELS = {
			500
		}
	},
}

local configs, _ = file.Find("slashco/configs/maps/*", "LUA")

local game_playable = false

if SERVER then
	SCInfo.MinimumMapPlayers = 6
end

for _, v in ipairs(configs) do
	local config = util.JSONToTable(file.Read("slashco/configs/maps/" .. v, "LUA"))
	if not config then
		continue
	end

	local mapid = string.Replace(v, ".lua", "")
	SCInfo.Maps[mapid] = SCInfo.Maps[mapid] or {}

	if type(config.Manifest) == "table" then
		if config.Manifest.DoNotUseThisConfig then
			SCInfo.Maps[mapid] = nil
			continue
		end

		SCInfo.Maps[mapid].NAME = config.Manifest.Name or "Unspecified Map Name"
		SCInfo.Maps[mapid].DEFAULT = config.Manifest.Default --wtf does this do...
		SCInfo.Maps[mapid].MIN_PLAYERS = config.Manifest.MinimumPlayers or 1
	else
		SCInfo.Maps[mapid].NAME = "Unspecified Map Name"
		SCInfo.Maps[mapid].MIN_PLAYERS = 1
	end

	if SERVER then
		SCInfo.MinimumMapPlayers = math.min(SCInfo.Maps[mapid].MIN_PLAYERS, SCInfo.MinimumMapPlayers)
	end

	game_playable = true
end

if SERVER and not game_playable then
	timer.Simple(30, function()
		for _, play in ipairs(player.GetAll()) do
			play:ChatPrint([[[SlashCo] WARNING! There are no maps mounted! The gamemode is not playable!
                
Download the Maps at the Gamemode's workshop page under the "Required Items" section.]])
		end
	end)
end

-- determine if a position is far enough away from generators and survivors
function SlashCo.IsPositionLegalForSlashers(pos, noSurvivorCheck, distFactor)
	local dist = (600 + GetGlobal2Int("SlashCoMapSize", 1) * 150) * (distFactor or 1)

	for _, v in ipairs(ents.FindInSphere(pos, dist)) do
		if v:GetClass() == "sc_generator" then
			return false
		end
	end

	if noSurvivorCheck then
		return true
	end

	for _, v in ipairs(team.GetPlayers(TEAM_SURVIVOR)) do
		if v:GetPos():Distance(pos) < dist then
			return false
		end
	end

	return true
end

SlashCo.Objectives = {
	generator = {
		hasCount = true
	},
	helicopter = {},
	heliwait = {},
	trash = {
		hasCount = true,
		optional = true
	},
	mop = {
		hasCount = true,
		optional = true
	},
	trap = {
		hasCount = true,
		optional = true
	},
	page = {
		hasCount = true,
		optional = true
	},
}

SlashCo.ObjStatus = {
	INCOMPLETE = 0,
	COMPLETE = 1,
	FAILED = 2
}