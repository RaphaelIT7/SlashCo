SlashCo = SlashCo or {}

function SlashCo.FindWorkshopID(mapName)
	if not string.EndsWith(mapName, ".bsp") then
		mapName = mapName .. ".bsp"
	end

	local mapPath = "maps/" .. mapName
	for _, addon in ipairs(engine.GetAddons()) do
		if file.Exists(mapPath, addon.title) then
			return addon.wsid, addon.title
		end
	end

	return nil, nil
end

if SERVER then
	local wsid, title = SlashCo.FindWorkshopID(game.GetMap())
	if wsid then
		print("[Content] Current map is from Addon " .. title)
		resource.AddWorkshop(wsid) -- Adds the current map to the server download.
	end
end

if CLIENT then
	net.Receive("slashco_PrecacheMap", function() -- Goal is to reduce loading time by starting the map download in the lobby already.
		local wsid = net.ReadString()
		local title = net.ReadString()

		print("Received precache signal")
		steamworks.FileInfo(wsid, function(result)
			if result.installed and not result.disabled then  -- The map is already installed :3
				print("[Content] The next map is already installed\n")
				return
			end

			steamworks.DownloadUGC(wsid, function(path, file)
				if path then
					print("[Content] Successfully precached \"" .. title .. "\" (" .. wsid .. ") for the next round")
				else
					print("[Content] Failed to precache \"" .. title .. "\" (" .. wsid .. ")")
				end
			end)
		end)
	end)
else
	util.AddNetworkString("slashco_PrecacheMap")
	function SlashCo.PrecacheNextMap()
		local mapName = SlashCo.LobbyData.SelectedMap
		local wsid, title = SlashCo.FindWorkshopID(mapName)
		if not wsid then
			print("[Content] Failed to precache next map as it wasn't found in any addon! (" .. mapName .. ")")
			return
		else
			print("[Content] Sent out precache signal for map \"" .. mapName .. "\" (\"" .. title .. "\" - " .. wsid .. ")")
		end

		net.Start("slashco_PrecacheMap")
			net.WriteString(wsid)
			net.WriteString(title)
		net.Broadcast()
	end
end