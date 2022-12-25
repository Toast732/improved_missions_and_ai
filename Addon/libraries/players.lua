-- required libraries
require("libraries.debugging")
require("libraries.matrix")

-- library name
Players = {}

-- shortened library name
pl = Players

--[[


	Variables
   

]]

local addon_contributors = {
	["76561198258457459"] = {
		name = "Toastery",
		role = "Author",
		debug = { -- the debug to automatically enable for them
			0, -- chat debug
			3, -- map debug
		}
	},
	["76561198443297702"] = {
		name = "Mr Lennyn",
		role = "Author",
		debug = { -- the debug to automatically enable for them
			0, -- chat debug
			3, -- map debug
		}
	}
}

--[[


	Functions         


]]

function Players.onJoin(steam_id, peer_id)

	if not g_savedata.players.individual_data[steam_id] then -- this player has never joined before

		Players.add(steam_id, peer_id)

	else -- this player has joined before

		local player = Players.dataBySID(steam_id) -- get the player's data

		Players.updateData(player) -- update the player's data
	end
end

function Players.setupOOP(player)
	-- update name
	function player:updateName()
		self.name = s.getPlayerName(self.peer_id)
	end

	-- update peer_id
	function player:updatePID(peer_id)
		if peer_id then
			self.peer_id = peer_id
		else
			for _, peer in pairs(s.getPlayers()) do
				if tostring(peer.steam_id) == self.steam_id then
					self.peer_id = peer.id
				end
			end
		end
	end

	function player:updateOID()
		self.object_id = s.getPlayerCharacterID(self.peer_id)
	end

	-- checks if the player has this debug type enabled
	function player:getDebug(debug_id)
		if debug_id == -1 then
			-- check for all
			for _, enabled in pairs(self.debug) do
				if enabled then
					-- a debug is enabled
					return true 
				end
			end
			-- no debugs are enabled
			return false
		end

		return self.debug[d.DIDtoDT(debug_id)]
	end

	function player:setDebug(debug_id, enabled)
		if debug_id == -1 then -- set all debug to the specified state
			for debug_id, enabled in pairs(self.debug) do
				self:setDebug(debug_id, enabled)
			end
		else
			self.debug[d.DIDtoDT(debug_id)] = enabled
		end
	end

	-- checks if the player is a contributor to the addon
	function player:isContributor()
		return addon_contributors[self.steam_id] ~= nil
	end

	function player:isOnline()
		-- "failure proof" method of checking if the player is online
		-- by going through all online players, as in certain scenarios
		-- only using onPlayerJoin and onPlayerLeave will cause issues.
		for _, peer in pairs(s.getPlayers()) do
			if tostring(peer.steam_id) == self.steam_id then
				return true
			end
		end 
		return false
	end

	return player
end

function Players.updateData(player)

	player = Players.setupOOP(player)

	-- update player's online status
	if player:isOnline() then
		g_savedata.players.online[player.peer_id] = player.steam_id
	else
		g_savedata.players.online[player.peer_id] = player.steam_id
	end

	-- update their name
	player:updateName()

	-- update their peer_id
	player:updatePID()

	-- update their object_id
	player:updateOID()

	return player
end

function Players.add(steam_id, peer_id)

	player = {
		name = s.getPlayerName(peer_id),
		peer_id = peer_id,
		steam_id = steam_id,
		object_id = s.getPlayerCharacterID(peer_id),
		debug = {},
		acknowledgements = {} -- used for settings to confirm that the player knows the side affects of what they're setting the setting to
	}

	-- populate debug data
	for i = 1, #debug_types do
		player.debug[d.DIDtoDT(i)] = false
	end

	-- functions for the player

	player = Players.updateData(player)

	g_savedata.players.individual_data[steam_id] = player

	-- enable their selected debug modes by default if they're a addon contributor
	if player:isContributor() then
		local enabled_debugs = {}

		-- enable the debugs they specified
		for i = 1, #addon_contributors[steam_id].debug do
			player:setDebug(addon_contributors[steam_id].debug[i], true)
			table.insert(enabled_debugs, addon_contributors[steam_id].debug[i])
		end

		-- if this contributor has debugs which automatically gets enabled
		if #enabled_debugs > 0 then

			local msg_enabled_debugs = ""

			-- prepare the debug types which were enabled to be put into a message
			msg_enabled_debugs = d.DIDtoDT(enabled_debugs[1])
			if #enabled_debugs > 1 then
				for i = 2, #enabled_debugs do -- start at position 2, as we've already added the one at positon 1.
					if i == #enabled_debugs then -- if this is the last debug type
						msg_enabled_debugs = ("%s and %s"):format(msg_enabled_debugs, d.DIDtoDT(enabled_debugs[i]))
					else
						msg_enabled_debugs = ("%s, %s"):format(msg_enabled_debugs, d.DIDtoDT(enabled_debugs[i]))
					end
				end
			end

			d.print(("Automatically enabled %s debug for you, %s, thank you for your contributions!"):format(msg_enabled_debugs, player.name), false, 0, player.peer_id, 5)
		else -- if they have no debugs types that get automatically enabled
			d.print(("Thank you for your contributions, %s!"):format(player.name), false, 0, player.peer_id, 6)
		end
	end

	d.print(("Setup Player %s"):format(player.name), true, 0, -1, 7)
end

function Players.dataBySID(steam_id)
	return g_savedata.players.individual_data[steam_id]
end

function Players.dataByPID(peer_id)

	local steam_id = Players.getSteamID(peer_id)

	-- ensure we got steam_id
	if not steam_id then 
		return
	end

	-- ensure player's data exists
	if not g_savedata.players.individual_data[steam_id] then
		return
	end

	-- return player's data
	return g_savedata.players.individual_data[steam_id]
end

---@param player_list Players[] the list of players to check
---@param target_pos Matrix the position that you want to check
---@param min_dist number the minimum distance between the player and the target position
---@param ignore_y boolean if you want to ignore the y level between the two or not
---@return boolean no_players_nearby returns true if theres no players which distance from the target_pos was less than the min_dist
function Players.noneNearby(player_list, target_pos, min_dist, ignore_y)
	local players_clear = true
	for player_index, player in pairs(player_list) do
		if ignore_y and m.xzDistance(s.getPlayerPos(player.id), target_pos) < min_dist then
			players_clear = false
		elseif not ignore_y and m.distance(s.getPlayerPos(player.id), target_pos) < min_dist then
			players_clear = false
		end
	end
	return players_clear
end

---@param peer_id integer the peer_id of the player you want to get the steam id of
---@return string steam_id the steam id of the player, nil if not found
function Players.getSteamID(peer_id)
	if not g_savedata.players.online[peer_id] then
		-- slower, but reliable fallback method
		for _, peer in pairs(s.getPlayers()) do
			if peer.id == peer_id then
				return tostring(peer.steam_id)
			end
		end
		s.announce("Critical Error", "Failed to get steam id of peer_id: "..peer_id, -1, -1, 9)
		debug.log("SW IMAI Critical Error")
		return false
	end

	return g_savedata.players.online[peer_id]
end

---@param steam_id string the steam_id of the player you want to get the object ID of
---@return integer object_id the object ID of the player
function Players.objectIDFromSteamID(steam_id)
	if not steam_id then
		d.print("(pl.objectIDFromSteamID) steam_id was never provided!", true, 1, -1, 10)
		return nil
	end

	if not g_savedata.players[steam_id].object_id then
		g_savedata.players[steam_id].object_id = s.getPlayerCharacterID(g_savedata.player_data[steam_id].peer_id)
	end

	return g_savedata.players[steam_id].object_id
end

-- returns true if the peer_id is a player id
function Players.isPlayer(peer_id)
	return (peer_id and peer_id ~= -1 and peer_id ~= 65535)
end