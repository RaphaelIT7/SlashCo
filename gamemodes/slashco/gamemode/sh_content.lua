SlashCo = SlashCo or {}

function SlashCo.FindWorkshopID(mapName)
	local mapPath = "maps/" .. game.GetMap() .. ".bsp"
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
		print("Current map is from Addon " .. title)
		resource.AddWorkshop(wsid) -- Adds the current map to the server download.
	end
end

if CLIENT then
	net.Receive("slashco_PrecacheMap", function() -- Goal is to reduce loading time by starting the map download in the lobby already.
		local wsid = net.ReadString()
		local title = net.ReadString()

		steamworks.FileInfo(wsid, function(result)
			if result.installed then return end -- The map is already installed :3

			steamworks.DownloadUGC(wsid, function(path, file)
				if path then
					print("Successfully precached \"" .. title .. "\" (" .. wsid .. ") for the next round")
				else
					print("Failed to precache \"" .. title .. "\" (" .. wsid .. ")")
				end
			end)
		end)
	end)
else
	function SlashCo.PrecacheNextMap()
		local mapName = SlashCo.LobbyData.SelectedMap
		local wsid, title = SlashCo.FindWorkshopID(mapName)
		if not wsid then
			print("Failed to precache next map as it wasn't found in any addon! (" .. mapName .. ")")
			return
		end

		net.Start("slashco_PrecacheMap")
			net.WriteString(wsid)
			net.WriteString(title)
		net.Broadcast()
	end
end