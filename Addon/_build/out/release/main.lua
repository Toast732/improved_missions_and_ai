 
--? Copyright 2022 Liam Matthews

--? Licensed under the Apache License, Version 2.0 (the "License");
--? you may not use this file except in compliance with the License.
--? You may obtain a copy of the License at

--?		http://www.apache.org/licenses/LICENSE-2.0

--? Unless required by applicable law or agreed to in writing, software
--? distributed under the License is distributed on an "AS IS" BASIS,
--? WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--? See the License for the specific language governing permissions and
--? limitations under the License.

--! (If gotten from Steam Workshop) LICENSE is in vehicle_0.xml
--! (If gotten from anywhere else) LICENSE is in LICENSE and vehicle_0.xml

-- Author: Toastery
-- GitHub: https://github.com/Toast732
-- Workshop: https://steamcommunity.com/id/Toastery7/myworkshopfiles/?appid=573090
--
--- Developed using LifeBoatAPI - Stormworks Lua plugin for VSCode - https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)
--- If you have any issues, please report them here: https://github.com/nameouschangey/STORMWORKS_VSCodeExtension/issues - by Nameous Changey

local ADDON_VERSION = "(0.0.1.2)"
local IS_DEVELOPMENT_VERSION = string.match(ADDON_VERSION, "(%d%.%d%.%d%.%d)")

local just_migrated = false

-- shortened library names
local m = matrix
local s = server

local time = { -- the time unit in ticks, irl time, not in game
	second = 60,
	minute = 3600,
	hour = 216000,
	day = 5184000
}

local debug_types = {
	[0] = "chat",
	[1] = "error",
	[2] = "profiler",
	[3] = "map",
	[4] = "graph_node",
	[5] = "driving",
	[6] = "vehicle"
}

g_savedata = {
	tick_counter = 0,
	vehicles = {
		ai = {
			loaded = {}, -- used to index vehicle_data, to only iterate loaded vehicles
			unloaded = {}, -- used to index vehicle_data, to only iterate unloaded vehicles
			vehicle_data = {}
		}
	},
	info = {
		version_history = {
			{
				version = ADDON_VERSION,
				ticks_played = 0,
				backup_g_savedata = {}
			}
		},
		addons = {
			improved_conquest_mode = false,
			default_missions = false,
			default_ai = false,
			ai_paths = false
		},
		mods = {
			NSO = false
		}
	},
	players = {
		online = {}, -- indexed by peer_id, value is steam_id, to index individual_data
		individual_data = {},
		global_data = {}
	},
	cache = {
		data = {},
		stats = {
			reads = 0,
			writes = 0,
			failed_writes = 0,
			resets = 0
		}
	},
	profiler = {
		working = {},
		total = {},
		display = {
			average = {},
			max = {},
			current = {}
		},
		ui_id = nil
	},
	debug = {},
	graph_nodes = {
		init = false,
		init_debug = false,
		nodes = {}
	}
}

-- libraries
-- This library is for controlling or getting things about the Enemy AI.

-- required libraries
-- required libraries
-- required libraries
---@param matrix1 SWMatrix the first matrix
---@param matrix2 SWMatrix the second matrix
function matrix.xzDistance(matrix1, matrix2) -- returns the distance between two matrixes, ignoring the y axis
	local ox, oy, oz = m.position(matrix1)
	local tx, ty, tz = m.position(matrix2)
	return m.distance(m.translation(ox, 0, oz), m.translation(tx, 0, tz))
end

---@param rot_matrix SWMatrix the matrix you want to get the rotation of
---@return number x_axis the x_axis rotation (roll)
---@return number y_axis the y_axis rotation (yaw)
---@return number z_axis the z_axis rotation (pitch)
function matrix.getMatrixRotation(rot_matrix) --returns radians for the functions: matrix.rotation X and Y and Z (credit to woe and quale)
	local z = -math.atan(rot_matrix[5],rot_matrix[1])
	rot_matrix = m.multiply(rot_matrix, m.rotationZ(-z))
	return math.atan(rot_matrix[7],rot_matrix[6]), math.atan(rot_matrix[9],rot_matrix[11]), z
end

---@param matrix1 SWMatrix the first matrix
---@param matrix2 SWMatrix the second matrix
---@return SWMatrix matrix the multiplied matrix
function matrix.multiplyXZ(matrix1, matrix2)
	local matrix3 = {table.unpack(matrix1)}
	matrix3[13] = matrix3[13] + matrix2[13]
	matrix3[15] = matrix3[15] + matrix2[15]
	return matrix3
end

--# returns the total velocity (m/s) between the two matrices
---@param matrix1 SWMatrix the first matrix
---@param matrix2 SWMatrix the second matrix
---@param ticks_between number the ticks between the two matrices
---@return number velocity the total velocity
function matrix.velocity(matrix1, matrix2, ticks_between)
	ticks_between = ticks_between or 1
	local rx = matrix2[13] - matrix1[13] -- relative x
	local ry = matrix2[14] - matrix1[14] -- relative y
	local rz = matrix2[15] - matrix1[15] -- relative z

	-- total velocity
	return math.sqrt(rx*rx+ry*ry+rz*rz) * 60/ticks_between
end

--# returns the acceleration, given 3 matrices. Each matrix must be the same ticks between eachother.
---@param matrix1 SWMatrix the most recent matrix
---@param matrix2 SWMatrix the second most recent matrix
---@param matrix3 SWMatrix the third most recent matrix
---@return number acceleration the acceleration in m/s
function matrix.acceleration(matrix1, matrix2, matrix3, ticks_between)
	local v1 = m.velocity(matrix1, matrix2, ticks_between) -- last change in velocity
	local v2 = m.velocity(matrix2, matrix3, ticks_between) -- change in velocity from ticks_between ago
	-- returns the acceleration
	return (v1-v2)/(ticks_between/60)
end


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
-- required libraries

-- library name
Tables = {}

--# check for if none of the inputted variables are nil
---@param print_error boolean if you want it to print an error if any are nil (if true, the second argument must be a name for debugging puposes)
---@param ... any variables to check
---@return boolean none_are_nil returns true of none of the variables are nil or false
function Tables.noneNil(print_error,...)
	local _ = table.pack(...)
	local none_nil = true
	for variable_index, variable in pairs(_) do
		if print_error and variable ~= _[1] or not print_error then
			if not none_nil then
				none_nil = false
				if print_error then
					d.print("(Tables.noneNil) a variable was nil! index: "..variable_index.." | from: ".._[1], true, 1)
				end
			end
		end
	end
	return none_nil
end

--# returns the number of elements in the table
---@param t table table to get the size of
---@return number count the size of the table
function Tables.length(t)
	if not t or type(t) ~= "table" then
		return 0 -- invalid input
	end

	local count = 0

	for _ in pairs(t) do -- goes through each element in the table
		count = count + 1 -- adds 1 to the count
	end

	return count -- returns number of elements
end

-- credit: woe | for this function
function Tables.tabulate(t,...)
	local _ = table.pack(...)
	t[_[1]] = t[_[1]] or {}
	if _.n>1 then
		Tables.tabulate(t[_[1]], table.unpack(_, 2))
	end
end
-- required libraries
---@param x number the number to check if is whole
---@return boolean is_whole returns true if x is whole, false if not, nil if x is nil
function math.isWhole(x) -- returns wether x is a whole number or not
	return math.tointeger(x)
end

--- if a number is nil, it sets it to 0
--- @param x number the number to check if is nil
--- @return number x the number, or 0 if it was nil
function math.noNil(x)
	return x ~= x and 0 or x
end

---@param x number the number to clamp
---@param min number the minimum value
---@param max number the maximum value
---@return number clamped_x the number clamped between the min and max
function math.clamp(x, min, max)
	return math.noNil(max<x and max or min>x and min or x)
end

--- @param min number the min number
--- @param max number the max number
function math.randomDecimals(min, max)
	return math.random()*(max-min)+min
end

--- Returns a number which is consistant if the params are all consistant
--- @param use_decimals boolean true for if you want decimals, false for whole numbers
--- @param seed number the seed for the random number generator
--- @param min number the min number
--- @param max number the max number
--- @return number seeded_number the random seeded number
function math.seededRandom(use_decimals, seed, min, max)
	local seed = seed or 1
	local min = min or 0
	local max = max or 1

	local seeded_number = 0

	-- generate a random seed
	math.randomseed(seed)

	-- generate a random number with decimals
	if use_decimals then
		seeded_number = math.randomDecimals(min, max)
	else -- generate a whole number
		seeded_number = math.random(math.floor(min), math.ceil(max))
	end

	-- make the random numbers no longer consistant with the seed
	math.randomseed(g_savedata.tick_counter)
	
	-- return the seeded number
	return seeded_number
end

---@param x number the number to wrap
---@param min number the minimum number to wrap around
---@param max number the maximum number to wrap around
---@return number x x wrapped between min and max
function math.wrap(x, min, max) -- wraps x around min and max
	return (x - min) % (max - min) + min
end

---@param t table a table of which you want a winner to be picked from, the index of the elements must be the name of the element, and the value must be a modifier (num) which when larger will increase the chances of it being chosen
---@return string win_name the name of the element which was picked at random
function math.randChance(t)
	local total_mod = 0
	for k, v in pairs(t) do
		total_mod = total_mod + v
	end
	local win_name = ""
	local win_val = 0
	for k, v in pairs(t) do
		local chance = math.randomDecimals(0, v / total_mod)
		-- d.print("chance: "..chance.." chance to beat: "..win_val.." k: "..k, true, 0)
		if chance > win_val then
			win_val = chance
			win_name = k
		end
	end
	return win_name
end

math.tau = math.pi*2


-- library name
Map = {}

--# draws a search area within the specified radius at the coordinates provided
---@param x number the x coordinate of where the search area will be drawn around (required)
---@param z number the z coordinate of where the search area will be drawn around (required)
---@param radius number the radius of the search area (required)
---@param ui_id integer the ui_id of the search area (required)
---@param peer_id integer the peer_id of the player which you want to draw the search area for (defaults to -1)
---@param label string The text that appears when mousing over the icon. Appears like a title (defaults to "")
---@param hover_label string The text that appears when mousing over the icon. Appears like a subtitle or description (defaults to "")
---@param r integer 0-255, the red value of the search area (defaults to 255)
---@param g integer 0-255, the green value of the search area (defaults to 255)
---@param b integer 0-255, the blue value of the search area (defaults to 255)
---@param a integer 0-255, the alpha value of the search area (defaults to 255)
---@return number x the x coordinate of where the search area was drawn
---@return number z the z coordinate of where the search area was drawn
---@return boolean success if the search area was drawn
function Map.drawSearchArea(x, z, radius, ui_id, peer_id, label, hover_label, r, g, b, a)

	if not x then -- if the x position of the target was not provided
		d.print("(Map.drawSearchArea) x is nil!", true, 1)
		return nil, nil, false
	end

	if not z then -- if the z position of the target was not provided
		d.print("(Map.drawSearchArea) z is nil!", true, 1)
		return nil, nil, false
	end

	if not radius then -- if the radius of the search area was not provided
		d.print("(Map.drawSearchArea) radius is nil!", true, 1)
		return nil, nil, false
	end

	if not ui_id then -- if the ui_id was not provided
		d.print("(Map.drawSearchArea) ui_id is nil!", true, 1)
		return nil, nil, false
	end

	-- default values (if not specified)

	local peer_id = peer_id or -1 -- makes the peer_id default to -1 if not provided (-1 = everybody)

	local label = label or "" -- defaults the label to "" if it was not specified
	local hover_label = hover_label or "" -- defaults the hover_label to "" if it was not specified

	local r = r or 255 -- makes the red colour default to 255 if not provided
	local g = g or 255 -- makes the green colour default to 255 if not provided
	local b = b or 255 -- makes the blue colour default to 255 if not provided
	local a = a or 255 -- makes the alpha default to 255 if not provided

	local angle = math.random() * math.pi * 2 -- gets a random angle to put the search radius focus around
	local dist = math.sqrt(math.randomDecimals(0.1, 0.9)) * radius -- gets a random distance from the target to put the search radius at

	local x_pos = dist * math.sin(angle) + x -- uses the distance and angle to make the x pos of the search radius
	local z_pos = dist * math.cos(angle) + z -- uses the distance and angle to make the z pos of the search radius

	s.addMapObject(peer_id, ui_id, 0, 2, x_pos, z_pos, 0, 0, 0, 0, label, radius, hover_label, r, g, b, a) -- draws the search radius to the map

	return x_pos, z_pos, true -- returns the x pos and z pos of the drawn search radius, and returns true that it was drawn.
end

function Map.addMapCircle(peer_id, ui_id, center_matrix, radius, width, r, g, b, a, lines) -- credit to woe
	peer_id, ui_id, center_matrix, radius, width, r, g, b, a, lines = peer_id or -1, ui_id or 0, center_matrix or m.translation(0, 0, 0), radius or 500, width or 0.25, r or 255, g or 0, b or 0, a or 255, lines or 16
	local center_x, center_z = center_matrix[13], center_matrix[15]
	for i = 0, lines do
		local x1, z1 = center_x+radius*math.cos(math.tau/lines*i), center_z+radius*math.sin(math.tau/lines*i)
		local x2, z2 = center_x+radius*math.cos(math.tau/lines*(i+1)), center_z+radius*math.sin(math.tau/lines*(i+1))
		local start_matrix, end_matrix = m.translation(x1, 0, z1), m.translation(x2, 0, z2)
		s.addMapLine(peer_id, ui_id, start_matrix, end_matrix, width, r, g, b, a)
	end
end


-- library name
Debugging = {}

-- shortened library name
d = Debugging 

---@param message string the message you want to print
---@param requires_debug boolean if it requires <debug_type> debug to be enabled
---@param debug_type integer the type of message, 0 = debug (debug.chat) | 1 = error (debug.chat) | 2 = profiler (debug.profiler) 
---@param peer_id integer if you want to send it to a specific player, leave empty to send to all players
function Debugging.print(message, requires_debug, debug_type, peer_id, djkhabwjkbahwd) -- "glorious debug function" - senty, 2022

	if IS_DEVELOPMENT_VERSION or not requires_debug or requires_debug and d.getDebug(debug_type, peer_id) or requires_debug and debug_type == 2 and d.getDebug(0, peer_id) then
		local suffix = debug_type == 1 and " Error:" or debug_type == 2 and " Profiler:" or " Debug:"
		local prefix = string.gsub(s.getAddonData((s.getAddonIndex())).name, "%(.*%)", ADDON_VERSION)..suffix

		if type(message) == "string" and IS_DEVELOPMENT_VERSION then
			if message then
				debug.log("SW IMAI "..suffix.." | "..string.gsub(message, "\n", " \\n "))
			else
				debug.log("SW IMAI "..suffix.." | (d.print) message is nil!")
			end
		end

		if type(message) ~= "table" and type(message) ~= "string" then
			message = type(message)
		end
		
		if type(message) == "table" then
			d.printTable(message, requires_debug, debug_type, peer_id, djkhabwjkbahwd)

		elseif requires_debug then
			if pl.isPlayer(peer_id) and peer_id then
				if d.getDebug(debug_type, peer_id) then
					s.announce(prefix, message, peer_id)
				end
			else
				for peer_index, peer in pairs(s.getPlayers()) do
					if d.getDebug(debug_type, peer.id) or debug_type == 2 and d.getDebug(0, peer.id) then
						s.announce(prefix, message, peer.id)
					end
				end
			end
		else
			s.announce(prefix, message, peer_id or -1)
		end
	end
end

--# prints all data which is in a table (use d.print instead of this)
---@param t table the table of which you want to print
---@param requires_debug boolean if it requires <debug_type> debug to be enabled
---@param debug_type integer the type of message, 0 = debug (debug.chat) | 1 = error (debug.chat) | 2 = profiler (debug.profiler)
---@param peer_id integer if you want to send it to a specific player, leave empty to send to all players
function Debugging.printTable(t, requires_debug, debug_type, peer_id, self_call)
	debug.log("SW IMAI self call: "..tostring(self_call))
	for k, v in pairs(t) do
		if type(v) == "table" then
			if type(k) ~= "string" or type(k) ~= "number" or type(k) ~= "boolean" or type(k) ~= "nil" then
				k = type(k)
			end
			d.printTable(v, requires_debug, debug_type, peer_id, true)
			d.print("Table: "..tostring(k), requires_debug, debug_type, peer_id)
		elseif type(v) == "string" or type(v) == "number" then
			d.print("k: "..tostring(k).." v: "..tostring(v), requires_debug, debug_type, peer_id)
		else
			d.print("k: "..tostring(k).." type(v): "..type(v), requires_debug, debug_type, peer_id, 2)
		end
	end
end

function Debugging.DIDtoDT(debug_id) -- debug id to debug type
	return debug_types[debug_id]
end

---@param debug_id integer the type of debug | 0 = debug | 1 = error | 2 = profiler | 3 = map
---@param peer_id ?integer the peer_id of the player you want to check if they have it enabled, leave blank to check globally
---@return boolean enabled if the specified type of debug is enabled
function Debugging.getDebug(debug_id, peer_id)
	if not peer_id or not pl.isPlayer(peer_id) then -- if any player has it enabled
		if debug_id == -1 then -- any debug
			for _, enabled in pairs(g_savedata.debug) do
				if enabled then 
					return true 
				end
			end
			if g_savedata.debug.chat or g_savedata.debug.profiler or g_savedata.debug.map then
				return true
			end
			return false
		end

		-- make sure this debug type is valid
		if not debug_types[debug_id] then
			d.print("(d.getDebug) debug_type "..tostring(debug_id).." is not a valid debug type!", true, 1)
			return false
		end

		-- check a specific debug
		return g_savedata.debug[debug_types[debug_type]]

	else -- if a specific player has it enabled
		local player = pl.dataByPID(peer_id)
		
		-- ensure the data for this player exists
		if not player then
			return false
		end

		return player:getDebug(debug_id)
	end
	return false
end

function Debugging.handleDebug(debug_type, enabled, peer_id, steam_id)
	if debug_type == "chat" then
		return (enabled and "Enabled" or "Disabled").." Chat Debug"
	elseif debug_type == "error" then
		return (enabled and "Enabled" or "Disabled").." Error Debug"
	elseif debug_type == "profiler" then
		if not enabled then
			-- remove profiler debug
			s.removePopup(peer_id, g_savedata.profiler.ui_id)

			-- clean all the profiler debug, if its disabled globally
			d.cleanProfilers()
		end

		return (enabled and "Enabled" or "Disabled").." Profiler Debug"
	elseif debug_type == "map" then
		if not enabled then
			-- remove map debug
			for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
				for vehicle_id, vehicle_object in pairs(squad.vehicles) do
					s.removeMapObject(peer_id, vehicle_object.ui_id)
					s.removeMapLabel(peer_id, vehicle_object.ui_id)
					s.removeMapLine(peer_id, vehicle_object.ui_id)
					for i = 0, #vehicle_object.path - 1 do
						local waypoint = vehicle_object.path[i]
						if waypoint then
							s.removeMapLine(-1, waypoint.ui_id)
						end
					end
				end
			end

			for island_index, island in pairs(g_savedata.islands) do
				updatePeerIslandMapData(peer_id, island)
			end
			
			updatePeerIslandMapData(peer_id, g_savedata.player_base_island)
			updatePeerIslandMapData(peer_id, g_savedata.ai_base_island)
		end

		return (enabled and "Enabled" or "Disabled").." Map Debug"
	elseif debug_type == "graph_node" then
		local function addNode(ui_id, x, z, node_type, NSO)
			local r = 255
			local g = 255
			local b = 255
			if node_type == "ocean_path" then
				r = 0
				g = 25
				b = 225

				if NSO == 2 then -- darker for non NSO
					b = 200
					g = 50
				elseif NSO == 1 then -- brighter for NSO
					b = 255
					g = 0
				end

			elseif node_type == "land_path" then
				r = 0
				g = 215
				b = 25

				if NSO == 2 then -- darker for non NSO
					g = 150
					b = 50
				elseif NSO == 1 then -- brighter for NSO
					g = 255
					b = 0
				end

			end
			Map.addMapCircle(peer_id, ui_id, m.translation(x, 0, z), 5, 1.5, r, g, b, 255, 5)
		end

		if enabled then
			if not g_savedata.graph_nodes.init_debug then
				for x, x_data in pairs(g_savedata.graph_nodes.nodes) do
					for z, z_data in pairs(x_data) do
						z_data.ui_id = s.getMapID()
						addNode(z_data.ui_id, x, z, z_data.type, z_data.NSO)
					end
				end
				g_savedata.graph_nodes.init_debug = true
			else
				for x, x_data in pairs(g_savedata.graph_nodes.nodes) do
					for z, z_data in pairs(x_data) do
						addNode(z_data.ui_id, x, z, z_data.type, z_data.NSO)
					end
				end
			end
		else
			for x, x_data in pairs(g_savedata.graph_nodes.nodes) do
				for z, z_data in pairs(x_data) do
					s.removeMapID(peer_id, z_data.ui_id)
				end
			end
		end

		return (enabled and "Enabled" or "Disabled").." Graph Node Debug"
	elseif debug_type == "driving" then
		if not enabled then
			for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
				for vehicle_id, vehicle_object in pairs(squad.vehicles) do
					s.removeMapObject(peer_id, vehicle_object.driving.ui_id)
				end
			end
		end
		return (enabled and "Enabled" or "Disabled").." Driving Debug"

	elseif debug_type == "vehicle" then
		if not enabled then
			-- remove vehicle debug
			for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
				for vehicle_id, vehicle_object in pairs(squad.vehicles) do
					s.removePopup(peer_id, vehicle_object.ui_id)
				end
			end
		end
		return (enabled and "Enabled" or "Disabled").." Vehicle Debug"
	end
end

function Debugging.setDebug(d_type, peer_id)

	if not peer_id then
		d.print("(Debugging.setDebug) peer_id is nil!", true, 1)
		return "peer_id was nil"
	end

	local steam_id = pl.getSteamID(peer_id)

	if not d_type then
		d.print("(Debugging.setDebug) d_type is nil!", true, 1)
		return "d_type was nil"
	end

	local debug_types = {
		[-1] = "all",
		[0] = "chat",
		[1] = "error",
		[2] = "profiler",
		[3] = "map",
		[4] = "graph_node",
		[5] = "driving",
		[6] = "vehicle"
	}

	local ignore_all = { -- debug types to ignore from enabling and/or disabling with ?imai debug all
		[-1] = "all",
		[4] = "enable"
	}

	
	if debug_types[d_type] then
		if d_type == -1 then
			local none_true = true
			for d_id, debug_type_data in pairs(debug_types) do -- disable all debug
				if g_savedata.player_data[steam_id].debug[debug_type_data] and (ignore_all[d_id] ~= "all" and ignore_all[d_id] ~= "enable") then
					none_true = false
					g_savedata.player_data[steam_id].debug[debug_type_data] = false
				end
			end

			if none_true then -- if none was enabled, then enable all
				for d_id, debug_type_data in pairs(debug_types) do -- enable all debug
					if (ignore_all[d_id] ~= "all" and ignore_all[d_id] ~= "enable") then
						g_savedata.debug[debug_type_data] = none_true
						g_savedata.player_data[steam_id].debug[debug_type_data] = none_true
						d.handleDebug(debug_type_data, none_true, peer_id, steam_id)
					end
				end
			else
				d.checkDebug()
				for d_id, debug_type_data in pairs(debug_types) do -- disable all debug
					if (ignore_all[d_id] ~= "all" and ignore_all[d_id] ~= "disable") then
						d.handleDebug(debug_type_data, none_true, peer_id, steam_id)
					end
				end
			end
			return (none_true and "Enabled" or "Disabled").." All Debug"
		else
			g_savedata.player_data[steam_id].debug[debug_types[d_type]] = not g_savedata.player_data[steam_id].debug[debug_types[d_type]]

			if g_savedata.player_data[steam_id].debug[debug_types[d_type]] then
				g_savedata.debug[debug_types[d_type]] = true
			else
				d.checkDebug()
			end

			return d.handleDebug(debug_types[d_type], g_savedata.player_data[steam_id].debug[debug_types[d_type]], peer_id, steam_id)
		end
	else
		return "Unknown debug type: "..tostring(d_type)
	end
end

function Debugging.checkDebug() -- checks all debugging types to see if anybody has it enabled, if not, disable them to save on performance
	local keep_enabled = {}

	-- check all debug types for all players to see if they have it enabled or disabled
	local player_list = s.getPlayers()
	for peer_index, peer in pairs(player_list) do
		local steam_id = pl.getSteamID(peer.id)
		for debug_type, debug_type_enabled in pairs(g_savedata.player_data[steam_id].debug) do
			-- if nobody's known to have it enabled
			if not keep_enabled[debug_type] then
				-- then set it to whatever this player's value was
				keep_enabled[debug_type] = debug_type_enabled
			end
		end
	end

	-- any debug types that are disabled for all players, we want to disable globally to save on performance
	for debug_type, should_keep_enabled in pairs(keep_enabled) do
		-- if its not enabled for anybody
		if not should_keep_enabled then
			-- disable the debug globally
			g_savedata.debug[debug_type] = should_keep_enabled
		end
	end
end

---@param unique_name string a unique name for the profiler  
function Debugging.startProfiler(unique_name, requires_debug)
	-- if it doesnt require debug or
	-- if it requires debug and debug for the profiler is enabled or
	-- if this is a development version
	if not requires_debug or requires_debug and g_savedata.debug.profiler then
		if unique_name then
			if not g_savedata.profiler.working[unique_name] then
				g_savedata.profiler.working[unique_name] = s.getTimeMillisec()
			else
				d.print("A profiler named "..unique_name.." already exists", true, 1)
			end
		else
			d.print("A profiler was attempted to be started without a name!", true, 1)
		end
	end
end

function Debugging.stopProfiler(unique_name, requires_debug, profiler_group)
	-- if it doesnt require debug or
	-- if it requires debug and debug for the profiler is enabled or
	-- if this is a development version
	if not requires_debug or requires_debug and g_savedata.debug.profiler then
		if unique_name then
			if g_savedata.profiler.working[unique_name] then
				Tables.tabulate(g_savedata.profiler.total, profiler_group, unique_name, "timer")
				g_savedata.profiler.total[profiler_group][unique_name]["timer"][g_savedata.tick_counter] = s.getTimeMillisec()-g_savedata.profiler.working[unique_name]
				g_savedata.profiler.total[profiler_group][unique_name]["timer"][(g_savedata.tick_counter-60)] = nil
				g_savedata.profiler.working[unique_name] = nil
			else
				d.print("A profiler named "..unique_name.." doesn't exist", true, 1)
			end
		else
			d.print("A profiler was attempted to be started without a name!", true, 1)
		end
	end
end

function Debugging.showProfilers(requires_debug)
	if g_savedata.debug.profiler then
		if g_savedata.profiler.total then
			if not g_savedata.profiler.ui_id then
				g_savedata.profiler.ui_id = s.getMapID()
			end
			d.generateProfilerDisplayData()

			local debug_message = "Profilers\navg|max|cur (ms)"
			debug_message = d.getProfilerData(debug_message)

			local player_list = s.getPlayers()
			for peer_index, peer in pairs(player_list) do
				if d.getDebug(2, peer.id) then
					s.setPopupScreen(peer.id, g_savedata.profiler.ui_id, "Profilers", true, debug_message, -0.92, 0)
				end
			end
		end
	end
end

function Debugging.getProfilerData(debug_message)
	for debug_name, debug_data in pairs(g_savedata.profiler.display.average) do
		debug_message = ("%s\n--\n%s: %.2f|%.2f|%.2f"):format(debug_message, debug_name, debug_data, g_savedata.profiler.display.max[debug_name], g_savedata.profiler.display.current[debug_name])
	end
	return debug_message
end

function Debugging.generateProfilerDisplayData(t, old_node_name)
	if not t then
		for node_name, node_data in pairs(g_savedata.profiler.total) do
			if type(node_data) == "table" then
				d.generateProfilerDisplayData(node_data, node_name)
			elseif type(node_data) == "number" then
				-- average the data over the past 60 ticks and save the result
				local data_total = 0
				local valid_ticks = 0
				for i = 0, 60 do
					valid_ticks = valid_ticks + 1
					data_total = data_total + g_savedata.profiler.total[node_name][(g_savedata.tick_counter-i)]
				end
				g_savedata.profiler.display.average[node_name] = data_total/valid_ticks -- average usage over the past 60 ticks
				g_savedata.profiler.display.max[node_name] = max_node -- max usage over the past 60 ticks
				g_savedata.profiler.display.current[node_name] = g_savedata.profiler.total[node_name][(g_savedata.tick_counter)] -- usage in the current tick
			end
		end
	else
		for node_name, node_data in pairs(t) do
			if type(node_data) == "table" and node_name ~= "timer" then
				d.generateProfilerDisplayData(node_data, node_name)
			elseif node_name == "timer" then
				-- average the data over the past 60 ticks and save the result
				local data_total = 0
				local valid_ticks = 0
				local max_node = 0
				for i = 0, 60 do
					if t[node_name] and t[node_name][(g_savedata.tick_counter-i)] then
						valid_ticks = valid_ticks + 1
						-- set max tick time
						if max_node < t[node_name][(g_savedata.tick_counter-i)] then
							max_node = t[node_name][(g_savedata.tick_counter-i)]
						end
						-- set average tick time
						data_total = data_total + t[node_name][(g_savedata.tick_counter-i)]
					end
				end
				g_savedata.profiler.display.average[old_node_name] = data_total/valid_ticks -- average usage over the past 60 ticks
				g_savedata.profiler.display.max[old_node_name] = max_node -- max usage over the past 60 ticks
				g_savedata.profiler.display.current[old_node_name] = t[node_name][(g_savedata.tick_counter)] -- usage in the current tick
			end
		end
	end
end

function Debugging.cleanProfilers() -- resets all profiler data in g_savedata
	if not d.getDebug(2) then
		g_savedata.profiler.working = {}
		g_savedata.profiler.total = {}
		g_savedata.profiler.display = {
			average = {},
			max = {},
			current = {}
		}
		d.print("cleaned all profiler data", true, 2)
	end
end


-- library name
AI = {}

--- @param vehicle_object vehicle_object the vehicle you want to set the state of
--- @param state string the state you want to set the vehicle to
--- @return boolean success if the state was set
function AI.setState(vehicle_object, state)
	if vehicle_object then
		if state ~= vehicle_object.state.s then
			if state == VEHICLE.STATE.HOLDING then
				vehicle_object.holding_target = vehicle_object.transform
			end
			vehicle_object.state.s = state
		end
	else
		d.print("(AI.setState) vehicle_object is nil!", true, 1)
	end
	return false
end

--# made for use with toggles in buttons (only use for toggle inputs to seats)
---@param vehicle_id integer the vehicle's id that has the seat you want to set
---@param seat_name string the name of the seat you want to set
---@param axis_ws number w/s axis
---@param axis_ad number a/d axis
---@param axis_ud number up down axis
---@param axis_lr number left right axis
---@param ... boolean buttons (1-7) (7 is trigger)
---@return boolean set_seat if the seat was set
function AI.setSeat(vehicle_id, seat_name, axis_ws, axis_ad, axis_ud, axis_lr, ...)
	
	if not vehicle_id then
		d.print("(AI.setSeat) vehicle_id is nil!", true, 1)
		return false
	end

	if not seat_name then
		d.print("(AI.setSeat) seat_name is nil!", true, 1)
		return false
	end

	local button = table.pack(...)

	-- sets any nil values to 0 or false
	axis_ws = axis_ws or 0
	axis_ad = axis_ad or 0
	axis_ud = axis_ud or 0
	axis_lr = axis_lr or 0

	for i = 1, 7 do
		button[i] = button[i] or false
	end

	g_savedata.seat_states = g_savedata.seat_states or {}


	if not g_savedata.seat_states[vehicle_id] or not g_savedata.seat_states[vehicle_id][seat_name] then

		g_savedata.seat_states[vehicle_id] = g_savedata.seat_states[vehicle_id] or {}
		g_savedata.seat_states[vehicle_id][seat_name] = {}

		for i = 1, 7 do
			g_savedata.seat_states[vehicle_id][seat_name][i] = false
		end
	end

	for i = 1, 7 do
		if button[i] ~= g_savedata.seat_states[vehicle_id][seat_name][i] then
			g_savedata.seat_states[vehicle_id][seat_name][i] = button[i]
			button[i] = true
		else
			button[i] = false
		end
	end

	s.setVehicleSeat(vehicle_id, seat_name, axis_ws, axis_ad, axis_ud, axis_lr, button[1], button[2], button[3], button[4], button[5], button[6], button[7])
	return true
end
 -- functions relating to their AI
-- required libraries

-- library name
Cache = {}

---@param location g_savedata.cache[] where to reset the data, if left blank then resets all cache data
---@param boolean success returns true if successfully cleared the cache
function Cache.reset(location) -- resets the cache
	if not location then
		g_savedata.cache = {}
	else
		if g_savedata.cache[location] then
			g_savedata.cache[location] = nil
		else
			if not g_savedata.cache_stats.failed_resets then
				g_savedata.cache_stats.failed_resets = 0
			end
			g_savedata.cache_stats.failed_resets = g_savedata.cache_stats.failed_resets + 1
			d.print("Failed to reset cache data at "..tostring(location)..", this should not be happening!", true, 1)
			return false
		end
	end
	g_savedata.cache_stats.resets = g_savedata.cache_stats.resets + 1
	return true
end

---@param location g_savedata.cache[] where to write the data
---@param data any the data to write at the location
---@return boolean write_successful if writing the data to the cache was successful
function Cache.write(location, data)

	if type(g_savedata.cache[location]) ~= "table" then
		d.print("Data currently at the cache of "..tostring(location)..": "..tostring(g_savedata.cache[location]), true, 0)
	else
		d.print("Data currently at the cache of "..tostring(location)..": (table)", true, 0)
	end

	g_savedata.cache[location] = data

	if type(g_savedata.cache[location]) ~= "table" then
		d.print("Data written to the cache of "..tostring(location)..": "..tostring(g_savedata.cache[location]), true, 0)
	else
		d.print("Data written to the cache of "..tostring(location)..": (table)", true, 0)
	end

	if g_savedata.cache[location] == data then
		g_savedata.cache_stats.writes = g_savedata.cache_stats.writes + 1
		return true
	else
		g_savedata.cache_stats.failed_writes = g_savedata.cache_stats.failed_writes + 1
		return false
	end
end

---@param location g_savedata.cache[] where to read the data from
---@return any data the data that was at the location
function Cache.read(location)
	g_savedata.cache_stats.reads = g_savedata.cache_stats.reads + 1
	if type(g_savedata.cache[location]) ~= "table" then
		d.print("reading cache data at\ng_savedata.Cache."..tostring(location).."\n\nData: "..g_savedata.cache[location], true, 0)
	else
		d.print("reading cache data at\ng_savedata.Cache."..tostring(location).."\n\nData: (table)", true, 0)
	end
	return g_savedata.cache[location]
end

---@param location g_savedata.cache[] where to check
---@return boolean exists if the data exists at the location
function Cache.exists(location)
	if g_savedata.cache[location] and g_savedata.cache[location] ~= {} and (type(g_savedata.cache[location]) ~= "table" or Tables.length(g_savedata.cache[location]) > 0) or g_savedata.cache[location] == false then
		d.print("g_savedata.Cache."..location.." exists", true, 0)

		return true
	end
	d.print("g_savedata.Cache."..location.." doesn't exist", true, 0)
	return false
end
 -- functions relating to the cache
--[[


	Library Setup


]]

-- required libraries
--[[


	Library Setup


]]

-- required libraries
-- required libraries

-- library name
Tags = {}

function Tags.has(tags, tag, decrement)
	if type(tags) ~= "table" then
		d.print("(Tags.has) was expecting a table, but got a "..type(tags).." instead! searching for tag: "..tag.." (this can be safely ignored)", true, 1)
		return false
	end

	if not decrement then
		for tag_index = 1, #tags do
			if tags[tag_index] == tag then
				return true
			end
		end
	else
		for tag_index = #tags, 1, -1 do
			if tags[tag_index] == tag then
				return true
			end 
		end
	end

	return false
end

-- gets the value of the specifed tag, returns nil if tag not found
function Tags.getValue(tags, tag, as_string)
	if type(tags) ~= "table" then
		d.print("(Tags.getValue) was expecting a table, but got a "..type(tags).." instead! searching for tag: "..tag.." (this can be safely ignored)", true, 1)
	end

	for k, v in pairs(tags) do
		if string.match(v, tag.."=") then
			if not as_string then
				return tonumber(tostring(string.gsub(v, tag.."=", "")))
			else
				return tostring(string.gsub(v, tag.."=", ""))
			end
		end
	end
	
	return nil
end


-- library name
Setup = {}

-- shortened library name
sup = Setup

--[[


	Classes


]]

--[[


	Functions         


]]


-- library name
Compatibility = {}

-- shortened library name
comp = Compatibility

--[[


	Variables
   

]]

--# stores which versions require compatibility updates
local version_updates = {}

--[[


	Classes


]]

---@class VERSION_DATA
---@field data_version string the version which the data is on currently
---@field version string the version which the mod is on
---@field versions_outdated integer how many versions the data is out of date
---@field is_outdated boolean if the data is outdated compared to the mod
---@field newer_versions table a table of versions which are newer than the current, indexed by index, value as version string

--[[


	Functions         


]]

--# creates version data for the specified version, for use in the version_history table
---@param version string the version you want to create the data on
---@return table version_history_data the data of the version
function Compatibility.createVersionHistoryData(version)

	--[[
		calculate ticks played
	]] 
	local ticks_played = g_savedata.tick_counter

	if g_savedata.info.version_history and #g_savedata.info.version_history > 0 then
		for _, version_data in ipairs(g_savedata.info.version_history) do
			ticks_played = ticks_played - (version_data.ticks_played or 0)
		end
	end

	--[[
		
	]]
	local version_history_data = {
		version = version,
		ticks_played = ticks_played,
		backup_g_savedata = {}
	}

	return version_history_data
end

--# returns g_savedata, a copy of g_savedata which when edited, doesnt actually apply changes to the actual g_savedata, useful for backing up.
function Compatibility.getSavedataCopy()

	--d.print("(comp.getSavedataCopy) getting a g_savedata copy...", true, 0)

	--[[
		credit to Woe (https://canary.discord.com/channels/357480372084408322/905791966904729611/1024355759468839074)

		returns a clone/copy of g_savedata
	]]
	
	local function clone(t)
		local copy = {}
		if type(t) == "table" then
			for key, value in next, t, nil do
				copy[clone(key)] = clone(value)
			end
		else
			copy = t
		end
		return copy
	end

	local copied_g_savedata = clone(g_savedata)
	--d.print("(comp.getSavedataCopy) created a g_savedata copy!", true, 0)

	return copied_g_savedata
end

--# migrates the version system to the new one implemented in 0.3.0.78
---@param overwrite_g_savedata boolean if you want to overwrite g_savedata, usually want to keep false unless you've already got a backup of g_savedata
---@return table migrated_g_savedata
---@return boolean is_success if it successfully migrated the versioning system
function Compatibility.migrateVersionSystem(overwrite_g_savedata)

	d.print("migrating g_savedata...", false, 0)

	--[[
		create a local copy of g_savedata, as changes we make we dont want to be applied to the actual g_savedata
	]]

	local migrated_g_savedata = comp.getSavedataCopy()

	--[[
		make sure that the version_history table doesnt exist
	]]
	if g_savedata.info.version_history then
		-- if it already does, then abort, as the version system is already migrated
		d.print("(comp.migrateVersionSystem) the version system has already been migrated!", true, 1)
		return nil, false
	end

	--[[
		create the version_history table
	]]
	if overwrite_g_savedata then
		g_savedata.info.version_history = {}
	end

	migrated_g_savedata.info.version_history = {}

	--[[
		create the version history data, with the previous version the creation version 
		sadly, we cannot reliably get the last version used for versions 0.3.0.77 and below
		so we have to make this assumption
	]]

	if overwrite_g_savedata then
		table.insert(g_savedata.info.version_history, comp.createVersionHistoryData(migrated_g_savedata.info.creation_version))
	end
	
	table.insert(migrated_g_savedata.info.version_history, comp.createVersionHistoryData(migrated_g_savedata.info.creation_version))

	d.print("migrated g_savedata", false, 0)

	return migrated_g_savedata, true
end

--# returns the version id from the provided version
---@param version string the version you want to get the id of
---@return integer version_id the id of the version
---@return boolean is_success if it found the id of the version
function Compatibility.getVersionID(version)
	--[[
		first, we want to ensure version was provided
		lastly, we want to go through all of the versions stored in the version history, if we find a match, then we return it as the id
		if we cannot find a match, we return nil and false
	]]

	-- ensure version was provided
	if not version then
		d.print("(comp.getVersionID) version was not provided!", false, 1)
		return nil, false
	end

	-- go through all of the versions saved in version_history
	for version_id, version_name in ipairs(g_savedata.info.version_history) do
		if version_name == version then
			return version_id, true
		end
	end

	-- if a version was not found, return nil and false
	return nil, false
end

--# splits a version into 
---@param version string the version you want split
---@return table version [1] = release version, [2] = majour version, [3] = minor version, [4] = commit version
function Compatibility.splitVersion(version) -- credit to woe
	local T = {}

	-- remove ( and )
	version = version:match("[%d.]+")

	for S in version:gmatch("([^%.]*)%.*") do
		T[#T+1] = tonumber(S) or S
	end

	T = {
		T[1], -- release
		T[2], -- majour
		T[3], -- minor
		T[4] -- commit
	}

	return T
end

--# returns the version from the version_id
---@param version_id integer the id of the version
---@return string version the version associated with the id
---@return boolean is_success if it successfully got the version from the id
function Compatibility.getVersion(version_id)

	-- ensure that version_id was specified
	if not version_id then
		d.print("(comp.getVersion) version_id was not provided!", false, 1)
		return nil, false
	end

	-- ensure that it is a number
	if type(version_id) ~= "number" then
		d.print("(comp.getVersion) given version_id was not a number! type: "..type(version_id).." value: "..tostring(version_id), false, 1)
		return nil, false
	end

	local version = g_savedata.info.version_history[version_id] and g_savedata.info.version_history[version_id].version or nil
	return version, version ~= nil
end

--# returns version data about the specified version, or if left blank, the current version
---@param version string the current version, leave blank if want data on current version
---@return VERSION_DATA version_data the data about the version
---@return boolean is_success if it successfully got the version data
function Compatibility.getVersionData(version)

	local version_data = {
		data_version = "",
		is_outdated = false,
		version = "",
		versions_outdated = 0,
		newer_versions = {}
	}

	local copied_g_savedata = comp.getSavedataCopy() -- local copy of g_savedata so any changes we make to it wont affect any backups we may make

	--[[
		first, we want to ensure that the version system is migrated
		second, we want to get the id of the version depending on the given version argument
		third, we want to get the data version
		fourth, we want to count how many versions out of date the data version is from the mod version
		fifth, we want to want to check if the version is outdated
		and lastly, we want to return the data
	]]

	-- (1) check if the version system is not migrated
	if not g_savedata.info.version_history then
		local migrated_g_savedata, is_success = comp.migrateVersionSystem() -- migrate the version data
		if not is_success then
			d.print("(comp.getVersionData) failed to migrate version system. This is probably not good!", false, 1)
			return nil, false
		end

		-- set copied_g_savedata as migrated_g_savedata
		copied_g_savedata = migrated_g_savedata
	end

	-- (2) get version id
	local version_id = version and comp.getVersionID(version) or #copied_g_savedata.info.version_history

	-- (3) get data version
	--d.print("(comp.getVersionData) data_version: "..tostring(copied_g_savedata.info.version_history[version_id].version))
	version_data.data_version = copied_g_savedata.info.version_history[version_id].version

	-- (4) count how many versions out of date the data is

	local current_version = comp.splitVersion(version_data.data_version)

	local ids_to_versions = {
		"Release",
		"Majour",
		"Minor",
		"Commit"
	}

	for _, version_name in ipairs(version_updates) do

		--[[
			first, we want to check if the release version is greater (x.#.#.#)
			if not, second we want to check if the majour version is greater (#.x.#.#)
			if not, third we want to check if the minor version is greater (#.#.x.#)
			if not, lastly we want to check if the commit version is greater (#.#.#.x)
		]]

		local update_version = comp.splitVersion(version_name)

		--[[
			go through each version, and check if its newer than our current version
		]]
		for i = 1, #current_version do
			if not current_version[i] or current_version[i] > update_version[i] then
				--[[
					if theres no commit version for the current version, all versions with the same stable, majour and minor version will be older.
					OR, current version is newer, then dont continue, as otherwise that could trigger a false positive with things like 0.3.0.2 vs 0.3.1.1
				]]
				d.print(("(comp.getVersionData) %s Version %s is older than current %s Version: %s"):format(ids_to_versions[i], update_version[i], ids_to_versions[i], current_version[i]), true, 0)
				break
			elseif current_version[i] < update_version[i] then
				-- current version is older, so we need to migrate data.
				table.insert(version_data.newer_versions, version_name)
				d.print(("Found new %s version: %s current version: %s"):format(ids_to_versions[i], version_name, version_data.data_version), false, 0)
				break
			end

			d.print(("(comp.getVersionData) %s Version %s is the same as current %s Version: %s"):format(ids_to_versions[i], update_version[i], ids_to_versions[i], current_version[i]), true, 0)
		end
	end

	-- count how many versions its outdated
	version_data.versions_outdated = #version_data.newer_versions

	-- (5) check if its outdated
	version_data.is_outdated = version_data.versions_outdated > 0

	return version_data, true
end

--# saves backup of current g_savedata
---@return boolean is_success if it successfully saved a backup of the savedata
function Compatibility.saveBackup()
	--[[
		first, we want to save a current local copy of the g_savedata
		second we want to ensure that the g_savedata.info.version_history table is created
		lastly, we want to save the backup g_savedata
	]]

	-- create local copy of g_savedata
	local backup_g_savedata = comp.getSavedataCopy()

	if not g_savedata.info.version_history then -- if its not created (pre 0.3.0.78)
		d.print("(comp.saveBackup) migrating version system", true, 0)
		local migrated_g_savedata, is_success = comp.migrateVersionSystem(true) -- migrate version system
		if not is_success then
			d.print("(comp.saveBackup) failed to migrate version system. This is probably not good!", false, 1)
			return false
		end

		if not g_savedata.info.version_history then
			d.print("(comp.saveBackup) successfully migrated version system, yet g_savedata doesn't contain the new version system, this is not good!", false, 1)
		end
	end

	local version_data, is_success = comp.getVersionData()
	if version_data.data_version ~= g_savedata.info.version_history[#g_savedata.info.version_history].version then
		--d.print("version_data.data_version: "..tostring(version_data.data_version).."\ng_savedata.info.version_history[#g_savedata.info.version.version_history].version: "..tostring(g_savedata.info.version_history[#g_savedata.info.version_history].version))
		g_savedata.info.version_history[#g_savedata.info.version_history + 1] = comp.createVersionHistoryData()
	end

	-- save backup g_savedata
	g_savedata.info.version_history[#g_savedata.info.version_history].backup_g_savedata = backup_g_savedata

	-- remove g_savedata backups which are from over 2 data updates ago
	local backup_versions = {}
	for version_index, version_history_data in ipairs(g_savedata.info.version_history) do
		if version_history_data.backup_g_savedata.info then
			table.insert(backup_versions, version_index)
		end
	end
	
	if #backup_versions >= 3 then
		d.print("Deleting old backup data...", false, 0)
		for backup_index, backup_version_index in ipairs(backup_versions) do
			d.print("Deleting backup data for "..g_savedata.info.version_history[backup_version_index].version, false, 0)
			backup_versions[backup_index] = nil
			g_savedata.info.version_history[backup_version_index].backup_g_savedata = {}

			if #backup_versions <= 2 then
				d.print("Deleted old backup data.", false, 0)
				break
			end
		end
	end

	return true
end

--# updates g_savedata to be compatible with the mod version, to ensure that worlds are backwards compatible.
function Compatibility.update()

	-- ensure that we're actually outdated before proceeding
	local version_data, is_success = comp.getVersionData()
	if not is_success then
		d.print("(comp.update) failed to get version data! this is probably bad!", false, 1)
		return
	end

	if not version_data.is_outdated then
		d.print("(comp.update) according to version data, the data is not outdated. This is probably not good!", false, 1)
		return
	end

	d.print("IMAI's data is "..version_data.versions_outdated.." version"..(version_data.versions_outdated > 1 and "s" or "").." out of date!", false, 0)

	-- save backup
	local backup_saved = comp.saveBackup()
	if not backup_saved then
		d.print("(comp.update) Failed to save backup. This is probably not good!", false, 1)
		return false
	end

	d.print("Creating new version history for "..version_data.newer_versions[1].."...", false, 0)
	local version_history_data = comp.createVersionHistoryData(version_data.newer_versions[1])
	g_savedata.info.version_history[#g_savedata.info.version_history+1] = version_history_data
	d.print("Successfully created new version history for "..version_data.newer_versions[1]..".", false, 0)

	-- check for  changes
	if version_data.newer_versions[1] == "" then
	end
	d.print("IMAI data is now up to date with "..version_data.newer_versions[1]..".", false, 0)

	just_migrated = true
end

--# prints outdated message and starts update
function Compatibility.outdated()
	-- print that its outdated
	d.print("IMAI data is outdated! attempting to automatically update...", false, 0)

	-- start update process
	comp.update()
end

--# verifies that the mod is currently up to date
function Compatibility.verify()
	d.print("verifying if IMAI data is up to date...", false, 0)
	--[[
		first, check if the versioning system is up to date
	]]
	if not g_savedata.info.version_history then
		-- the versioning system is not up to date
		comp.outdated()
	else
		-- check if we're outdated
		local version_data, is_success = comp.getVersionData()

		if not is_success then
			d.print("(comp.verify) failed to get version data! this is probably bad!", false, 1)
			return
		end

		-- if we're outdated
		if version_data.is_outdated then
			comp.outdated()
		end
	end
end

--# shows the message to save the game and then load the save to complete migration
function Compatibility.showSaveMessage()
	is_dlc_weapons = false
	d.print("IMAI Data has been migrated, to complete the process, please save the world, and then load the saved world. IMAI has been disabled until this is done.", false, 0)
	s.setPopupScreen(-1, s.getMapID(), "IMAI Migration", true, "Please save world and then load save to complete data migration process. IMAI has been disabled till this is complete.", 0, 0)
end

 -- functions used for making the mod backwards compatible -- functions for debugging -- functions for drawing on the map -- custom math functions -- custom matrix functions
-- required libraries

-- library name
Pathfinding = {}

-- shortened library name
p = Pathfinding

function Pathfinding.resetPath(vehicle_object)
	for _, v in pairs(vehicle_object.path) do
		s.removeMapID(-1, v.ui_id)
	end

	vehicle_object.path = {}
end

-- makes the vehicle go to its next path
---@param vehicle_object vehicle_object the vehicle object which is going to its next path
---@return number more_paths the number of paths left
---@return boolean is_success if it successfully went to the next path
function Pathfinding.nextPath(vehicle_object)

	--? makes sure vehicle_object is not nil
	if not vehicle_object then
		d.print("(Vehicle.nextPath) vehicle_object is nil!", true, 1)
		return nil, false
	end

	--? makes sure the vehicle_object has paths
	if not vehicle_object.path then
		d.print("(Vehicle.nextPath) vehicle_object.path is nil! vehicle_id: "..tostring(vehicle_object.id), true, 1)
		return nil, false
	end

	if vehicle_object.path[1] then
		if vehicle_object.path[0] then
			s.removeMapID(-1, vehicle_object.path[0].ui_id)
		end
		vehicle_object.path[0] = {
			x = vehicle_object.path[1].x,
			y = vehicle_object.path[1].y,
			z = vehicle_object.path[1].z,
			ui_id = vehicle_object.path[1].ui_id
		}
		table.remove(vehicle_object.path, 1)
	end

	return #vehicle_object.path, true
end

---@param vehicle_object vehicle_object[] the vehicle you want to add the path for
---@param target_dest SWMatrix the destination for the path
function Pathfinding.addPath(vehicle_object, target_dest)

	-- path tags to exclude
	local exclude = ""

	if g_savedata.info.mods.NSO then
		exclude = "not_NSO" -- exclude non NSO graph nodes
	else
		exclude = "NSO" -- exclude NSO graph nodes
	end

	if vehicle_object.vehicle_type == VEHICLE.TYPE.TURRET then 
		AI.setState(vehicle_object, VEHICLE.STATE.STATIONARY)
		return

	elseif vehicle_object.vehicle_type == VEHICLE.TYPE.BOAT then
		local dest_x, dest_y, dest_z = m.position(target_dest)

		local path_start_pos = nil

		if #vehicle_object.path > 0 then
			local waypoint_end = vehicle_object.path[#vehicle_object.path]
			path_start_pos = m.translation(waypoint_end.x, waypoint_end.y, waypoint_end.z)
		else
			path_start_pos = vehicle_object.transform
		end

		-- makes sure only small ships can take the tight areas
		
		if vehicle_object.size ~= "small" then
			exclude = exclude..",tight_area"
		end

		-- calculates route
		local path_list = s.pathfind(path_start_pos, m.translation(dest_x, 0, dest_z), "ocean_path", exclude)

		for path_index, path in pairs(path_list) do
			if not path.y then
				path.y = 0
			end
			if path.y > 1 then
				break
			end 
			table.insert(vehicle_object.path, { 
				x = path.x, 
				y = path.y, 
				z = path.z, 
				ui_id = s.getMapID() 
			})
		end
	elseif vehicle_object.vehicle_type == VEHICLE.TYPE.LAND then
		local dest_x, dest_y, dest_z = m.position(target_dest)

		local path_start_pos = nil

		if #vehicle_object.path > 0 then
			local waypoint_end = vehicle_object.path[#vehicle_object.path]
			path_start_pos = m.translation(waypoint_end.x, waypoint_end.y, waypoint_end.z)
		else
			path_start_pos = vehicle_object.transform
		end

		start_x, start_y, start_z = m.position(vehicle_object.transform)

		local exclude_offroad = false

		local squad_index, squad = Squad.getSquad(vehicle_object.id)
		if squad.command == SQUAD.COMMAND.CARGO then
			for c_vehicle_id, c_vehicle_object in pairs(squad.vehicles) do
				if g_savedata.cargo_vehicles[c_vehicle_id] then
					exclude_offroad = not g_savedata.cargo_vehicles[c_vehicle_id].route_data.can_offroad
					break
				end
			end
		end

		if not vehicle_object.can_offroad or exclude_offroad then
			exclude = exclude..",offroad"
		end

		local vehicle_list_id = sm.getVehicleListID(vehicle_object.name)
		local y_modifier = g_savedata.vehicle_list[vehicle_list_id].vehicle.transform[14]

		local path_list = s.pathfind(path_start_pos, m.translation(dest_x, veh_y, dest_z), "land_path", exclude)
		for path_index, path in pairs(path_list) do
			veh_x, veh_y, veh_z = m.position(vehicle_object.transform)
			distance = m.distance(vehicle_object.transform, m.translation(path.x, path.y, path.z))

			if path_index ~= 1 or #path_list == 1 or m.distance(vehicle_object.transform, m.translation(dest_x, veh_y, dest_z)) > m.distance(m.translation(dest_x, veh_y, dest_z), m.translation(path.x, path.y, path.z)) and distance >= 7 then
				
				if not path.y then
					--d.print("not path.y\npath.x: "..tostring(path.x).."\npath.y: "..tostring(path.y).."\npath.z: "..tostring(path.z), true, 1)
					break
				end
				table.insert(vehicle_object.path, { 
					x =  path.x, 
					y = (path.y + y_modifier), 
					z = path.z, 
					ui_id = s.getMapID() 
				})
			end
		end

		if #vehicle_object.path > 1 then
			-- remove paths which are a waste (eg, makes the vehicle needlessly go backwards when it could just go to the next waypoint)
			if m.xzDistance(vehicle_object.transform, m.translation(vehicle_object.path[2].x, vehicle_object.path[2].y, vehicle_object.path[2].z)) < m.xzDistance(m.translation(vehicle_object.path[1].x, vehicle_object.path[1].y, vehicle_object.path[1].z), m.translation(vehicle_object.path[2].x, vehicle_object.path[2].y, vehicle_object.path[2].z)) then
				p.nextPath(vehicle_object)
			end
		end
	else
		table.insert(vehicle_object.path, { 
			x = target_dest[13], 
			y = target_dest[14], 
			z = target_dest[15], 
			ui_id = s.getMapID() 
		})
	end
	vehicle_object.path[0] = {
		x = vehicle_object.transform[13],
		y = vehicle_object.transform[14],
		z = vehicle_object.transform[15],
		ui_id = s.getMapID()
	}

	AI.setState(vehicle_object, VEHICLE.STATE.PATHING)
end

-- Credit to woe
function Pathfinding.updatePathfinding()
	local old_pathfind = server.pathfind --temporarily remember what the old function did
	local old_pathfindOcean = server.pathfindOcean
	function server.pathfind(matrix_start, matrix_end, required_tags, avoided_tags) --permanantly do this new function using the old name.
		local path = old_pathfind(matrix_start, matrix_end, required_tags, avoided_tags) --do the normal old function
		--d.print("(updatePathfinding) getting path y", true, 0)
		return p.getPathY(path) --add y to all of the paths.
	end
	function server.pathfindOcean(matrix_start, matrix_end)
		local path = old_pathfindOcean(matrix_start, matrix_end)
		return p.getPathY(path)
	end
end

local path_res = "%0.1f"

-- Credit to woe
function Pathfinding.getPathY(path)
	if not g_savedata.graph_nodes.init then --if it has never built the node's table
		p.createPathY() --build the table this one time
		g_savedata.graph_nodes.init = true --never build the table again unless you run traverse() manually
	end
	for each in pairs(path) do
		--d.print("(p.getPathY) x: "..((path_res):format(path[each].x)).."\nz: "..((path_res):format(path[each].z)), true, 0)
		if g_savedata.graph_nodes.nodes[(path_res):format(path[each].x)] and g_savedata.graph_nodes.nodes[(path_res):format(path[each].x)][(path_res):format(path[each].z)] then --if y exists
			path[each].y = g_savedata.graph_nodes.nodes[(path_res):format(path[each].x)][(path_res):format(path[each].z)].y --add it to the table that already contains x and z
			--d.print("path["..each.."].y: "..tostring(path[each].y), true, 0)
		end
	end
	return path --return the path with the added, or not, y values.
end

-- Credit to woe
function Pathfinding.createPathY() --this looks through all env mods to see if there is a "zone" then makes a table of y values based on x and z as keys.

	local isGraphNode = function(tag)
		if tag == "land_path" or tag == "ocean_path" then
			return tag
		end
		return false
	end

	local start_time = s.getTimeMillisec()
	d.print("Creating Path Y...", true, 0)
	local total_paths = 0
	local empty_matrix = m.translation(0, 0, 0)
	for addon_index = 0, s.getAddonCount() - 1 do
		local ADDON_DATA = s.getAddonData(addon_index)
		if ADDON_DATA.location_count and ADDON_DATA.location_count > 0 then
			for location_index = 0, ADDON_DATA.location_count - 1 do
				local LOCATION_DATA, gotLocationData = s.getLocationData(addon_index, location_index)
				if LOCATION_DATA.env_mod and LOCATION_DATA.component_count > 0 then
					for component_index = 0, LOCATION_DATA.component_count - 1 do
						local COMPONENT_DATA, getLocationComponentData = s.getLocationComponentData(
							addon_index, location_index, component_index
						)
						if COMPONENT_DATA.type == "zone" then
							local graph_node = isGraphNode(COMPONENT_DATA.tags[1])
							if graph_node then
								local transform_matrix, gotTileTransform = s.getTileTransform(
									empty_matrix, LOCATION_DATA.tile, 100000
								)
								if gotTileTransform then
									local real_transform = matrix.multiplyXZ(COMPONENT_DATA.transform, transform_matrix)
									local x = (path_res):format(real_transform[13])
									local last_tag = COMPONENT_DATA.tags[#COMPONENT_DATA.tags]
									g_savedata.graph_nodes.nodes[x] = g_savedata.graph_nodes.nodes[x] or {}
									g_savedata.graph_nodes.nodes[x][(path_res):format(real_transform[15])] = { 
										y = real_transform[14],
										type = graph_node,
										NSO = last_tag == "NSO" and 1 or last_tag == "not_NSO" and 2 or 0
									}
									total_paths = total_paths + 1
								end
							end
						end
					end
				end
			end
		end
	end
	d.print("Got Y level of all paths\nNumber of nodes: "..total_paths.."\nTime taken: "..(millisecondsSince(start_time)/1000).."s", true, 0)
end
 -- functions for pathfinding -- functions relating to Players -- functions for script/world setup.
-- required libraries

-- library name
SpawningUtils = {}

-- shortened library name
su = SpawningUtils

-- spawn an individual object descriptor from a playlist location
function SpawningUtils.spawnObjectType(spawn_transform, location_index, object_descriptor, parent_vehicle_id)
	local component, is_success = s.spawnAddonComponent(spawn_transform, s.getAddonIndex(), location_index, object_descriptor.index, parent_vehicle_id)
	if is_success then
		return component.id
	else -- then it failed to spawn the addon component
		d.print("(Improved Missions and AI) Please send this debug info to the discord server:\ncomponent: "..component.."\naddon_index: "..s.getAddonIndex().."\nlocation index: "..location_index, false, 1)
		return nil
	end
end

function SpawningUtils.spawnObject(spawn_transform, location_index, object, parent_vehicle_id, spawned_objects, out_spawned_objects)
	-- spawn object

	local spawned_object_id = su.spawnObjectType(m.multiply(spawn_transform, object.transform), location_index, object, parent_vehicle_id)

	-- add object to spawned object tables

	if spawned_object_id ~= nil and spawned_object_id ~= 0 then

		local l_vehicle_type = VEHICLE.TYPE.HELI
		if Tags.has(object.tags, "vehicle_type=ai_plane") then
			l_vehicle_type = VEHICLE.TYPE.PLANE
		elseif Tags.has(object.tags, "vehicle_type=ai_boat") then
			l_vehicle_type = VEHICLE.TYPE.BOAT
		end
		if Tags.has(object.tags, "vehicle_type=ai_land") then
			l_vehicle_type = VEHICLE.TYPE.LAND
		end
		if Tags.has(object.tags, "vehicle_type=wep_turret") then
			l_vehicle_type = VEHICLE.TYPE.TURRET
		end
		if Tags.has(object.tags, "type=dlc_weapons_flag") then
			l_vehicle_type = "flag"
		end

		local l_size = "small"
		for tag_index, tag_object in pairs(object.tags) do
			if string.find(tag_object, "size=") ~= nil then
				l_size = string.sub(tag_object, 6)
			end
		end

		local object_data = { name = object.display_name, type = object.type, id = spawned_object_id, component_id = object.id, vehicle_type = l_vehicle_type, size = l_size }

		if spawned_objects ~= nil then
			table.insert(spawned_objects, object_data)
		end

		if out_spawned_objects ~= nil then
			table.insert(out_spawned_objects, object_data)
		end

		return object_data
	end

	return nil
end

function SpawningUtils.spawnObjects(spawn_transform, location_index, object_descriptors, out_spawned_objects)
	local spawned_objects = {}

	for _, object in pairs(object_descriptors) do
		-- find parent vehicle id if set

		local parent_vehicle_id = 0
		if object.vehicle_parent_component_id > 0 then
			for spawned_object_id, spawned_object in pairs(out_spawned_objects) do
				if spawned_object.type == "vehicle" and spawned_object.component_id == object.vehicle_parent_component_id then
					parent_vehicle_id = spawned_object.id
				end
			end
		end

		su.spawnObject(spawn_transform, location_index, object, parent_vehicle_id, spawned_objects, out_spawned_objects)
	end

	return spawned_objects
end
 -- functions used by the spawn vehicle function
---@param str string the string to make the first letter uppercase
---@return string str the string with the first letter uppercase
function string.upperFirst(str)
	if type(str) == "string" then
		return (str:gsub("^%l", string.upper))
	end
	return nil
end

--- @param str string the string the make friendly
--- @param remove_spaces boolean true for if you want to remove spaces, will also remove all underscores instead of replacing them with spaces
--- @param keep_caps boolean if you want to keep the caps of the name, false will make all letters lowercase
--- @return string friendly_string friendly string, nil if input_string was not a string
function string.friendly(str, remove_spaces, keep_caps) -- function that replaced underscores with spaces and makes it all lower case, useful for player commands so its not extremely picky

	if not str or type(str) ~= "string" then
		d.print("(string.friendly) str is not a string! type: "..tostring(type(str)).." provided str: "..tostring(str), true, 1)
		return nil
	end

	-- make all lowercase
	
	local friendly_string = not keep_caps and string.lower(str) or str

	-- replace all underscores with spaces
	friendly_string = string.gsub(friendly_string, "_", " ")

	-- if remove_spaces is true, remove all spaces
	if remove_spaces then
		friendly_string = string.gsub(friendly_string, " ", "")
	end

	return friendly_string
end

---@param vehicle_name string the name you want to remove the prefix of
---@param keep_caps boolean if you want to keep the caps of the name, false will make all letters lowercase
---@return string vehicle_name the vehicle name without its vehicle type prefix
function string.removePrefix(vehicle_name, keep_caps)

	if not vehicle_name then
		d.print("(string.removePrefix) vehicle_name is nil!", true, 1)
		return vehicle_name
	end

	local vehicle_type_prefixes = {
		"BOAT %- ",
		"HELI %- ",
		"LAND %- ",
		"TURRET %- ",
		"PLANE %- "
	}

	-- replaces underscores with spaces
	local vehicle_name = string.gsub(vehicle_name, "_", " ")

	-- remove the vehicle type prefix from the entered vehicle name
	for _, prefix in ipairs(vehicle_type_prefixes) do
		vehicle_name = string.gsub(vehicle_name, prefix, "")
	end

	-- makes the string friendly
	vehicle_name = string.friendly(vehicle_name, false, keep_caps)

	return vehicle_name
end
 -- custom string functions -- custom table functions -- functions related to getting tags from components inside of mission and environment locations
-- library name
Ticks = {}

---@param start_ms number the time you want to see how long its been since (in ms)
---@return number ms_since how many ms its been since <start_ms>
function Ticks.millisecondsSince(start_ms)
	return s.getTimeMillisec() - start_ms
end
 -- functions related to ticks and time
-- required libraries

-- library name
Vehicle = {}

-- shortened library name
v = Vehicle

---@param vehicle_object vehicle_object the vehicle you want to get the speed of
---@param ignore_terrain_type boolean if false or nil, it will include the terrain type in speed, otherwise it will return the offroad speed (only applicable to land vehicles)
---@param ignore_aggressiveness boolean if false or nil, it will include the aggressiveness in speed, otherwise it will return the normal speed (only applicable to land vehicles)
---@param terrain_type_override string \"road" to override speed as always on road, "offroad" to override speed as always offroad, "bridge" to override the speed always on a bridge (only applicable to land vehicles)
---@param aggressiveness_override string \"normal" to override the speed as always normal, "aggressive" to override the speed as always aggressive (only applicable to land vehicles)
---@return number speed the speed of the vehicle, 0 if not found
---@return boolean got_speed if the speed was found
function Vehicle.getSpeed(vehicle_object, ignore_terrain_type, ignore_aggressiveness, terrain_type_override, aggressiveness_override, ignore_convoy_modifier)
	if not vehicle_object then
		d.print("(Vehicle.getSpeed) vehicle_object is nil!", true, 1)
		return 0, false
	end

	local squad_index, squad = Squad.getSquad(vehicle_object.id)

	if not squad then
		d.print("(Vehicle.getSpeed) squad is nil! vehicle_id: "..tostring(vehicle_object.id), true, 1)
		return 0, false
	end

	local speed = 0

	local ignore_me = false

	if squad.command == SQUAD.COMMAND.CARGO then
		-- return the slowest vehicle in the chain's speed
		for vehicle_index, _ in pairs(squad.vehicles) do
			if g_savedata.cargo_vehicles[vehicle_index] and g_savedata.cargo_vehicles[vehicle_index].route_status == 1 then
				speed = g_savedata.cargo_vehicles[vehicle_index].path_data.speed or 0
				if speed ~= 0 and not ignore_convoy_modifier then
					speed = speed + (vehicle_object.speed.convoy_modifier or 0)
					ignore_me = true
				end
			end
		end
	end

	if speed == 0 and not ignore_me then
		speed = vehicle_object.speed.speed

		if vehicle_object.vehicle_type == VEHICLE.TYPE.LAND then
			-- land vehicle
			local terrain_type = v.getTerrainType(vehicle_object.transform)
			local aggressive = agressiveness_override or not ignore_aggressiveness and vehicle_object.is_aggressive or false
			if aggressive then
				speed = speed * VEHICLE.SPEED.MULTIPLIERS.LAND.AGGRESSIVE
			else
				speed = speed * VEHICLE.SPEED.MULTIPLIERS.LAND.NORMAL
			end

			speed = speed * VEHICLE.SPEED.MULTIPLIERS.LAND[string.upper(terrain_type)]
		end
	end

	return speed, true
end

---@param transform SWMatrix the transform of where you want to check
---@return string terrain_type the terrain type the transform is on
---@return boolean found_terrain_type if the terrain type was found
function Vehicle.getTerrainType(transform)
	local found_terrain_type = false
	local terrain_type = "offroad"
	
	if transform then
		-- prefer returning bridge, then road, then offroad
		if s.isInZone(transform, "land_ai_bridge") then
			terrain_type = "bridge"
		elseif s.isInZone(transform, "land_ai_road") then
			terrain_type = "road"
		end
	else
		d.print("(Vehicle.getTerrainType) vehicle_object is nil!", true, 1)
	end

	return terrain_type, found_terrain_type
end

---@param vehicle_id integer the id of the vehicle
---@return prefab prefab the prefab of the vehicle if it was created
---@return boolean was_created if the prefab was created
function Vehicle.createPrefab(vehicle_id)
	if not vehicle_id then
		d.print("(Vehicle.createPrefab) vehicle_id is nil!", true, 1)
		return nil, false
	end

	local vehicle_data, got_vehicle_data = s.getVehicleData(vehicle_id)

	if not got_vehicle_data then
		d.print("(Vehicle.createPrefab) failed to get vehicle data! vehicle_id: "..tostring(vehicle_id), true, 1)
		return nil, false
	end

	local vehicle_object, squad, squad_index = Squad.getVehicle(vehicle_id)

	if not vehicle_object then
		d.print("(Vehicle.createPrefab) failed to get vehicle_object! vehicle_id: "..tostring(vehicle_id), true, 1)
		return nil, false
	end

	---@class prefab
	local prefab = {
		voxels = vehicle_data.voxels,
		mass = vehicle_data.mass,
		powertrain_types = v.getPowertrainTypes(vehicle_object),
		role = vehicle_object.role,
		vehicle_type = vehicle_object.vehicle_type,
		strategy = vehicle_object.strategy,
		fully_created = (vehicle_data.mass ~= 0) -- requires to be loaded
	}

	g_savedata.prefabs[string.removePrefix(vehicle_object.name)] = prefab

	return prefab, true
end

---@param vehicle_name string the name of the vehicle
---@return prefab prefab the prefab data of the vehicle
---@return got_prefab boolean if the prefab data was found
function Vehicle.getPrefab(vehicle_name)
	if not vehicle_name then
		d.print("(Vehicle.getPrefab) vehicle_name is nil!", true, 1)
		return nil, false
	end

	vehicle_name = string.removePrefix(vehicle_name)

	if not g_savedata.prefabs[vehicle_name] then
		return nil, false
	end

	return g_savedata.prefabs[vehicle_name], true
end

---@param vehicle_object vehicle_object the vehicle_object of the vehicle you want to get the powertrain type of
---@return powertrain_types powertrain_types the powertrain type(s) of the vehicle
---@return boolean got_powertrain_type if the powertrain type was found
function Vehicle.getPowertrainTypes(vehicle_object)

	if not vehicle_object then
		d.print("(Vehicle.getPowertrainType) vehicle_object is nil!", true, 1)
		return nil, false
	end

	local vehicle_data, got_vehicle_data = s.getVehicleData(vehicle_object.id)

	if not got_vehicle_data then
		d.print("(Vehicle.getPowertrainType) failed to get vehicle data! name: "..tostring(vehicle_object.name).."\nid: "..tostring(vehicle_object.id), true, 1)
		return nil, false
	end

	local _, is_jet = s.getVehicleTank(vehicle_object.id, "Jet 1")

	local _, is_diesel = s.getVehicleTank(vehicle_object.id, "Diesel 1")

	---@class powertrain_types
	local powertrain_types = {
		jet_fuel = is_jet,
		diesel = is_diesel,
		electric = (not is_jet and not is_diesel)
	}

	return powertrain_types, true	
end

---@param requested_prefab any vehicle name or vehicle role, such as scout, will try to spawn that vehicle or type
---@param vehicle_type string the vehicle type you want to spawn, such as boat, leave nil to ignore
---@param force_spawn boolean if you want to force it to spawn, it will spawn at the ai's main base
---@param specified_island island[] the island you want it to spawn at
---@param purchase_type integer 0 for dont buy, 1 for free (cost will be 0 no matter what), 2 for free but it has lower stats, 3 for spend as much as you can but the less spent will result in lower stats. 
---@return boolean spawned_vehicle if the vehicle successfully spawned or not
---@return vehicle_object vehicle_object the vehicle's data if the the vehicle successfully spawned, otherwise its returns the error code
function Vehicle.spawn(requested_prefab, vehicle_type, force_spawn, specified_island, purchase_type)
	local plane_count = 0
	local heli_count = 0
	local army_count = 0
	local land_count = 0
	local boat_count = 0

	if not g_savedata.settings.CARGO_MODE or not purchase_type then
		-- buy the vehicle for free
		purchase_type = 1
	end
	
	for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
		for vehicle_id, vehicle_object in pairs(squad.vehicles) do
			if vehicle_object.vehicle_type ~= VEHICLE.TYPE.TURRET then army_count = army_count + 1 end
			if vehicle_object.vehicle_type == VEHICLE.TYPE.PLANE then plane_count = plane_count + 1 end
			if vehicle_object.vehicle_type == VEHICLE.TYPE.HELI then heli_count = heli_count + 1 end
			if vehicle_object.vehicle_type == VEHICLE.TYPE.LAND then land_count = land_count + 1 end
			if vehicle_object.vehicle_type == VEHICLE.TYPE.BOAT then boat_count = boat_count + 1 end
		end
	end

	if vehicle_type == "helicopter" then
		vehicle_type = "heli"
	end
	
	local selected_prefab = nil

	local spawnbox_index = nil -- turrets

	if vehicle_type == "turret" and specified_island then

		-----
		--* turret spawning
		-----

		local island = specified_island

		-- make sure theres turret spawns on this island
		if (#island.zones.turrets < 1) then
			return false, "theres no turret zones on this island!\nisland: "..island.name 
		end

		local turret_count = 0
		local unoccupied_zones = {}

		-- count the amount of turrets this island has spawned
		for turret_zone_index = 1, #island.zones.turrets do
			if island.zones.turrets[turret_zone_index].is_spawned then 
				turret_count = turret_count + 1

				-- check if this island already hit the maximum for the amount of turrets
				if turret_count >= g_savedata.settings.MAX_TURRET_AMOUNT then 
					return false, "hit turret limit for this island" 
				end

				-- check if this island already has all of the turret spawns filled
				if turret_count >= #island.zones.turrets then
					return false, "the island already has all turret spawns occupied"
				end
			else
				-- add the zone to a list to be picked from for spawning the next turret
				table.insert(unoccupied_zones, turret_zone_index)
			end
		end

		-- d.print("turret count: "..turret_count, true, 0)

		-- pick a spawn point out of the list which is unoccupied
		spawnbox_index = unoccupied_zones[math.random(1, #unoccupied_zones)]

		-- make sure theres no players nearby this turret spawn
		local player_list = s.getPlayers()
		if not force_spawn and not pl.noneNearby(player_list, island.zones.turrets[spawnbox_index].transform, 2500, true) then -- makes sure players are not too close before spawning a turret
			return false, "players are too close to the turret spawn point!"
		end

		selected_prefab = sm.spawn(true, Tags.getValue(island.zones.turrets[spawnbox_index].tags, "turret_type", true), "turret")

		if not selected_prefab then
			return false, "was unable to get a turret prefab! turret_type of turret spawn zone: "..tostring(Tags.getValue(island.zones.turrets[spawnbox_index].tags, "turret_type", true))
		end

	elseif requested_prefab then
		-- *spawning specified vehicle
		selected_prefab = sm.spawn(true, requested_prefab, vehicle_type) 
	else
		-- *spawn random vehicle
		selected_prefab = sm.spawn(false, requested_prefab, vehicle_type)
	end

	if not selected_prefab then
		d.print("(Vehicle.spawn) Unable to spawn AI vehicle! (prefab not recieved)", true, 1)
		return false, "returned vehicle was nil, prefab "..(requested_prefab and "was" or "was not").." selected"
	end

	d.print("(Vehicle.spawn) selected vehicle: "..selected_prefab.location.data.name, true, 0)

	if not requested_prefab then
		if Tags.has(selected_prefab.vehicle.tags, "vehicle_type=wep_boat") and boat_count >= g_savedata.settings.MAX_BOAT_AMOUNT then
			return false, "boat limit reached"
		elseif Tags.has(selected_prefab.vehicle.tags, "vehicle_type=wep_land") and land_count >= g_savedata.settings.MAX_LAND_AMOUNT then
			return false, "land limit reached"
		elseif Tags.has(selected_prefab.vehicle.tags, "vehicle_type=wep_heli") and heli_count >= g_savedata.settings.MAX_HELI_AMOUNT then
			return false, "heli limit reached"
		elseif Tags.has(selected_prefab.vehicle.tags, "vehicle_type=wep_plane") and plane_count >= g_savedata.settings.MAX_PLANE_AMOUNT then
			return false, "plane limit reached"
		end
		if army_count > g_savedata.settings.MAX_BOAT_AMOUNT + g_savedata.settings.MAX_LAND_AMOUNT + g_savedata.settings.MAX_HELI_AMOUNT + g_savedata.settings.MAX_PLANE_AMOUNT then
			return false, "AI hit vehicle limit!"
		end
	end

	local player_list = s.getPlayers()

	local selected_spawn = 0
	local selected_spawn_transform = g_savedata.ai_base_island.transform

	-------
	-- get spawn location
	-------

	local min_player_dist = 2500

	d.print("(Vehicle.spawn) Getting island to spawn vehicle at...", true, 0)

	if not specified_island then
		-- if the vehicle we want to spawn is an attack vehicle, we want to spawn it as close to their objective as possible
		if Tags.getValue(selected_prefab.vehicle.tags, "role", true) == "attack" or Tags.getValue(selected_prefab.vehicle.tags, "role", true) == "scout" then
			target, ally = Objective.getIslandToAttack()
			if not target then
				sm.train(PUNISH, attack, 5) -- we can no longer spawn attack vehicles
				sm.train(PUNISH, attack, 5)
				v.spawn(nil, nil, nil, nil, purchase_type)
				return false, "no islands to attack! cancelling spawning of attack vehicle"
			end
			for island_index, island in pairs(g_savedata.islands) do
				if is.canSpawn(island, selected_prefab) and (selected_spawn_transform == nil or m.xzDistance(target.transform, island.transform) < m.xzDistance(target.transform, selected_spawn_transform)) then
					selected_spawn_transform = island.transform
					selected_spawn = island_index
				end
			end
		-- (A) if the vehicle we want to spawn is a defensive vehicle, we want to spawn it on the island that has the least amount of defence
		-- (B) if theres multiple, pick the island we saw the player closest to
		-- (C) if none, then spawn it at the island which is closest to the player's island
		elseif Tags.getValue(selected_prefab.vehicle.tags, "role", true) == "defend" then
			local lowest_defenders = nil
			local check_last_seen = false
			local islands_needing_checked = {}

			for island_index, island in pairs(g_savedata.islands) do
				if is.canSpawn(island, selected_prefab) then
					if not lowest_defenders or island.defenders < lowest_defenders then -- choose the island with the least amount of defence (A)
						lowest_defenders = island.defenders -- set the new lowest defender amount on an island
						selected_spawn_transform = island.transform
						selected_spawn = island_index
						check_last_seen = false -- say that we dont need to do a tie breaker
						islands_needing_checked = {}
					elseif lowest_defenders == island.defenders then -- if two islands have the same amount of defenders
						islands_needing_checked[selected_spawn] = selected_spawn_transform
						islands_needing_checked[island_index] = island.transform
						check_last_seen = true -- we need a tie breaker
					end
				end
			end

			if check_last_seen then -- do a tie breaker (B)
				local closest_player_pos = nil
				for player_steam_id, player_transform in pairs(g_savedata.ai_knowledge.last_seen_positions) do
					for island_index, island_transform in pairs(islands_needing_checked) do
						local player_to_island_dist = m.xzDistance(player_transform, island_transform)
						if not closest_player_pos or player_to_island_dist < closest_player_pos then
							closest_player_pos = player_to_island_dist
							selected_spawn_transform = island_transform
							selected_spawn = island_index
						end
					end
				end

				if not closest_player_pos then -- if no players were seen this game, spawn closest to the closest player island (C)
					for island_index, island_transform in pairs(islands_needing_checked) do
						for player_island_index, player_island in pairs(g_savedata.islands) do
							if player_island.faction == ISLAND.FACTION.PLAYER then
								if m.xzDistance(player_island.transform, selected_spawn_transform) > m.xzDistance(player_island.transform, island_transform) then
									selected_spawn_transform = island_transform
									selected_spawn = island_index
								end
							end
						end
					end
				end
			end
		-- spawn it at a random ai island
		else
			local valid_islands = {}
			local valid_island_index = {}
			for island_index, island in pairs(g_savedata.islands) do
				if is.canSpawn(island, selected_prefab) then
					table.insert(valid_islands, island)
					table.insert(valid_island_index, island_index)
				end
			end
			if #valid_islands > 0 then
				random_island = math.random(1, #valid_islands)
				selected_spawn_transform = valid_islands[random_island].transform
				selected_spawn = valid_island_index[random_island]
			end
		end
	else
		-- if they specified the island they want it to spawn at
		if not force_spawn then
			-- if they did not force the vehicle to spawn
			if is.canSpawn(specified_island, selected_prefab) then
				selected_spawn_transform = specified_island.transform
				selected_spawn = specified_island.index
			end
		else
			--d.print("forcing vehicle to spawn at "..specified_island.index, true, 0)
			-- if they forced the vehicle to spawn
			selected_spawn_transform = specified_island.transform
			selected_spawn = specified_island.index
		end
	end

	-- try spawning at the ai's main base if it was unable to find a valid spawn
	if not g_savedata.islands[selected_spawn] and g_savedata.ai_base_island.index ~= selected_spawn then
		if force_spawn or pl.noneNearby(player_list, g_savedata.ai_base_island.transform, min_player_dist, true) then -- makes sure no player is within min_player_dist
			-- if it can spawn at the ai's main base, or the vehicle is being forcibly spawned and its not a land vehicle
			if Tags.has(g_savedata.ai_base_island.tags, "can_spawn="..string.gsub(Tags.getValue(selected_prefab.vehicle.tags, "vehicle_type", true), "wep_", "")) or force_spawn and Tags.getValue(selected_prefab.vehicle.tags, "vehicle_type", true) ~= "wep_land" then
				selected_spawn_transform = g_savedata.ai_base_island.transform
				selected_spawn = g_savedata.ai_base_island.index
			end
		end
	end

	-- if it still was unable to find a island to spawn at
	if not g_savedata.islands[selected_spawn] and selected_spawn ~= g_savedata.ai_base_island.index then
		if Tags.getValue(selected_prefab.vehicle.tags, "role", true) == "scout" then -- make the scout spawn at the ai's main base
			selected_spawn_transform = g_savedata.ai_base_island.transform
			selected_spawn = g_savedata.ai_base_island.index
		else
			d.print("(Vehicle.spawn) was unable to find island to spawn at!\nIsland Index: "..selected_spawn.."\nVehicle Type: "..string.gsub(Tags.getValue(selected_prefab.vehicle.tags, "vehicle_type", true), "wep_", "").."\nVehicle Role: "..Tags.getValue(selected_prefab.vehicle.tags, "role", true), true, 1)
			return false, "was unable to find island to spawn at"
		end
	end

	local island = g_savedata.ai_base_island.index == selected_spawn and g_savedata.ai_base_island or g_savedata.islands[selected_spawn]

	if not island then
		d.print(("(Vehicle.spawn) no island found with the selected spawn of: %s. \nVehicle type: %s Vehicle role: %s"):format(tostring(selected_spawn), string.gsub(Tags.getValue(selected_prefab.vehicle.tags, "vehicle_type", true), "wep_", ""), Tags.getValue(selected_prefab.vehicle.tags, "role", true)), false, 1)
		return false, ("(Vehicle.spawn) no island found with the selected spawn of: %s. \nVehicle type: %s Vehicle role: %s"):format(tostring(selected_spawn), string.gsub(Tags.getValue(selected_prefab.vehicle.tags, "vehicle_type", true), "wep_", ""), Tags.getValue(selected_prefab.vehicle.tags, "role", true))
	end

	d.print("(Vehicle.spawn) island: "..island.name, true, 0)

	local spawn_transform = selected_spawn_transform
	if Tags.has(selected_prefab.vehicle.tags, "vehicle_type=wep_boat") then
		if not island then
			return false, "unable to find island to spawn sea vehicle at!"
		end
		if #island.zones.sea == 0 then
			d.print("(Vehicle.spawn) island has no sea spawn zones but says it can spawn sea vehicles! island_name: "..tostring(island.name), true, 1)
			return false, "island has no sea spawn zones"
		end

		spawn_transform = island.zones.sea[math.random(1, #island.zones.sea)].transform
	elseif Tags.has(selected_prefab.vehicle.tags, "vehicle_type=wep_land") then
		if #island.zones.land == 0 then
			d.print("(Vehicle.spawn) island has no land spawn zones but says it can spawn land vehicles! island_name: "..tostring(island.name), true, 1)
			return false, "island has no land spawn zones"
		end

		spawn_transform = island.zones.land[math.random(1, #island.zones.land)].transform
	elseif Tags.has(selected_prefab.vehicle.tags, "vehicle_type=wep_turret") then
		local turret_count = 0
		local unoccupied_zones = {}

		if #island.zones.turrets == 0 then
			d.print(("(v.spawn) Unable to spawn turret, Island %s has no turret spawn zones!"):format(island.name), true, 1)
			return false, ("Island %s has no turret spawn zones!"):format(island.name)
		end

		-- count the amount of turrets this island has spawned
		for turret_zone_index = 1, #island.zones.turrets do
			if island.zones.turrets[turret_zone_index].is_spawned then 
				turret_count = turret_count + 1

				-- check if this island already hit the maximum for the amount of turrets
				if turret_count >= g_savedata.settings.MAX_TURRET_AMOUNT then 
					return false, "hit turret limit for this island" 
				end

				-- check if this island already has all of the turret spawns filled
				if turret_count >= #island.zones.turrets then
					return false, "the island already has all turret spawns occupied"
				end
			elseif Tags.has(island.zones.turrets[turret_zone_index].tags, "turret_type="..Tags.getValue(selected_prefab.vehicle.tags, "role", true)) then
				-- add the zone to a list to be picked from for spawning the next turret
				table.insert(unoccupied_zones, turret_zone_index)
			end
		end

		if #unoccupied_zones == 0 then
			d.print(("(v.spawn) Unable to spawn turret, Island %s has no free turret spawn zones with the type of %s!"):format(island.name, Tags.getValue(selected_prefab.vehicle.tags, "role", true)), true, 1)
			return false, ("Island %s has no free turret spawn zones with the type of %s!"):format(island.name, Tags.getValue(selected_prefab.vehicle.tags, "role", true))
		end

		-- pick a spawn location out of the list which is unoccupied

		spawnbox_index = unoccupied_zones[math.random(1, #unoccupied_zones)]

		spawn_transform = island.zones.turrets[spawnbox_index].transform

	elseif Tags.has(selected_prefab.vehicle.tags, "vehicle_type=wep_plane") or Tags.has(selected_prefab.vehicle.tags, "vehicle_type=wep_heli") then
		spawn_transform = m.multiply(selected_spawn_transform, m.translation(math.random(-500, 500), CRUISE_HEIGHT + 400, math.random(-500, 500)))
	end

	-- check to make sure no vehicles are too close, as this could result in them spawning inside each other
	for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
		for vehicle_id, vehicle_object in pairs(squad.vehicles) do
			if m.distance(spawn_transform, vehicle_object.transform) < (Tags.getValue(selected_prefab.vehicle.tags, "spawning_distance") or DEFAULT_SPAWNING_DISTANCE + vehicle_object.spawning_transform.distance) then
				return false, "spawn location was too close to vehicle "..vehicle_id
			end
		end
	end

	d.print("(Vehicle.spawn) calculating cost of vehicle... (purchase type: "..tostring(purchase_type)..")", true, 0)
	-- check if we can afford the vehicle
	local cost, cost_existed, was_purchased, stats_multiplier = v.purchaseVehicle(string.removePrefix(selected_prefab.location.data.name), island.name, purchase_type, true)

	d.print("(Vehicle.spawn) cost: "..tostring(cost).." Purchase Type: "..purchase_type, true, 0)

	if not was_purchased then
		return false, "was unable to afford vehicle"
	end

	-- spawn objects
	local spawned_objects = {
		survivors = su.spawnObjects(spawn_transform, selected_prefab.location.location_index, selected_prefab.survivors, {}),
		fires = su.spawnObjects(spawn_transform, selected_prefab.location.location_index, selected_prefab.fires, {}),
		spawned_vehicle = su.spawnObject(spawn_transform, selected_prefab.location.location_index, selected_prefab.vehicle, 0, nil, {}),
	}

	d.print("(Vehicle.spawn) setting up enemy vehicle: "..selected_prefab.location.data.name, true, 0)

	if spawned_objects.spawned_vehicle ~= nil then
		local vehicle_survivors = {}
		for key, char in pairs(spawned_objects.survivors) do
			local c = s.getCharacterData(char.id)
			s.setCharacterData(char.id, c.hp, true, true)
			s.setAIState(char.id, 1)
			s.setAITargetVehicle(char.id, nil)
			table.insert(vehicle_survivors, char)
		end

		local home_x, home_y, home_z = m.position(spawn_transform)

		d.print("(Vehicle.spawn) setting vehicle data...", true, 0)
		--d.print("selected_spawn: "..selected_spawn, true, 0)

		---@class vehicle_object
		local vehicle_data = { 
			id = spawned_objects.spawned_vehicle.id,
			name = selected_prefab.location.data.name,
			home_island = g_savedata.islands[selected_spawn] or g_savedata.ai_base_island,
			survivors = vehicle_survivors, 
			path = { 
				[0] = {
					x = home_x, 
					y = home_y, 
					z = home_z
				} 
			},
			state = { 
				s = VEHICLE.STATE.HOLDING,
				timer = math.floor(math.fmod(spawned_objects.spawned_vehicle.id, 300 * stats_multiplier)),
				is_simulating = false,
				convoy = {
					status = CONVOY.MOVING,
					status_reason = "",
					time_changed = -1,
					ignore_wait = false,
					waiting_for = 0
				}
			},
			previous_squad = nil,
			ui_id = s.getMapID(),
			vehicle_type = spawned_objects.spawned_vehicle.vehicle_type,
			role = Tags.getValue(selected_prefab.vehicle.tags, "role", true) or "general",
			size = spawned_objects.spawned_vehicle.size or "small",
			main_body = Tags.getValue(selected_prefab.vehicle.tags, "main_body") or 0,
			holding_index = 1,
			holding_target = m.translation(home_x, home_y, home_z),
			spawnbox_index = spawnbox_index,
			costs = {
				buy_on_load = not cost_existed,
				purchase_type = purchase_type
			},
			vision = { 
				radius = Tags.getValue(selected_prefab.vehicle.tags, "visibility_range") or VISIBLE_DISTANCE,
				base_radius = Tags.getValue(selected_prefab.vehicle.tags, "visibility_range") or VISIBLE_DISTANCE,
				is_radar = Tags.has(selected_prefab.vehicle.tags, "radar"),
				is_sonar = Tags.has(selected_prefab.vehicle.tags, "sonar")
			},
			spawning_transform = {
				distance = Tags.getValue(selected_prefab.vehicle.tags, "spawning_distance") or DEFAULT_SPAWNING_DISTANCE
			},
			speed = {
				speed = Tags.getValue(selected_prefab.vehicle.tags, "speed") or 0 * stats_multiplier,
				convoy_modifier = 0
			},
			driving = { -- used for driving the vehicle itself, holds special data depending on the vehicle type
				ui_id = s.getMapID()
			},
			capabilities = {
				gps_target = Tags.has(selected_prefab.vehicle.tags, "GPS_TARGET_POSITION"), -- if it needs to have gps coords sent for where the player is
				gps_missile = Tags.has(selected_prefab.vehicle.tags, "GPS_MISSILE"), -- used to press a button to fire the missiles
				target_mass = Tags.has(selected_prefab.vehicle.tags, "TARGET_MASS") -- sends mass of targeted vehicle mass to the creation
			},
			cargo = {
				capacity = Tags.getValue(selected_prefab.vehicle.tags, "cargo_per_type") or 0,
				current = {
					oil = 0,
					diesel = 0,
					jet_fuel = 0
				}
			},
			is_aggressive = false,
			is_killed = false,
			just_strafed = true, -- used for fighter jet strafing
			strategy = Tags.getValue(selected_prefab.vehicle.tags, "strategy", true) or "general",
			can_offroad = Tags.has(selected_prefab.vehicle.tags, "can_offroad"),
			is_resupply_on_load = false,
			transform = spawn_transform,
			transform_history = {},
			target_vehicle_id = nil,
			target_player_id = nil,
			current_damage = 0,
			health = (Tags.getValue(selected_prefab.vehicle.tags, "health", false) or 1) * stats_multiplier,
			damage_dealt = {},
			fire_id = nil,
			object_type = "vehicle"
		}

		d.print("(Vehicle.spawn) set vehicle data", true, 0)

		if #spawned_objects.fires > 0 then
			vehicle_data.fire_id = spawned_objects.fires[1].id
		end

		local squad = addToSquadron(vehicle_data)
		if Tags.getValue(selected_prefab.vehicle.tags, "role", true) == "scout" then
			setSquadCommand(squad, SQUAD.COMMAND.SCOUT)
		elseif Tags.getValue(selected_prefab.vehicle.tags, "vehicle_type", true) == "wep_turret" then
			setSquadCommand(squad, SQUAD.COMMAND.TURRET)

			-- set the zone it spawned at to say that a turret was spawned there
			if g_savedata.islands[selected_spawn] then -- set at their island
				g_savedata.islands[selected_spawn].zones.turrets[spawnbox_index].is_spawned = true
			else -- they spawned at their main base
				g_savedata.ai_base_island.zones.turrets[spawnbox_index].is_spawned = true
			end

		elseif Tags.getValue(selected_prefab.vehicle.tags, "role", true) == "cargo" then
			setSquadCommand(squad, SQUAD.COMMAND.CARGO)
		end

		local prefab, got_prefab = v.getPrefab(selected_prefab.location.data.name)

		if not got_prefab then
			v.createPrefab(spawned_objects.spawned_vehicle.id)
		end

		if cost_existed then
			local cost, cost_existed, was_purchased = v.purchaseVehicle(string.removePrefix(selected_prefab.location.data.name), (g_savedata.islands[selected_spawn].name or g_savedata.ai_base_island.name), purchase_type)
			if not was_purchased then
				vehicle_data.costs.buy_on_load = true
			end
		end

		return true, vehicle_data
	end
	return false, "spawned_objects.spawned_vehicle was nil"
end

-- spawns a ai vehicle, if it fails then it tries again, the amount of times it retrys is how ever many was given
---@param requested_prefab any vehicle name or vehicle role, such as scout, will try to spawn that vehicle or type
---@param vehicle_type string the vehicle type you want to spawn, such as boat, leave nil to ignore
---@param force_spawn boolean if you want to force it to spawn, it will spawn at the ai's main base
---@param specified_island island[] the island you want it to spawn at
---@param purchase_type integer the way you want to purchase the vehicle 0 for dont buy, 1 for free (cost will be 0 no matter what), 2 for free but it has lower stats, 3 for spend as much as you can but the less spent will result in lower stats. 
---@param retry_count integer how many times to retry spawning the vehicle if it fails
---@return boolean spawned_vehicle if the vehicle successfully spawned or not
---@return vehicle_data[] vehicle_data the vehicle's data if the the vehicle successfully spawned, otherwise its nil
function Vehicle.spawnRetry(requested_prefab, vehicle_type, force_spawn, specified_island, purchase_type, retry_count)
	local spawned = nil
	local vehicle_data = nil
	d.print("(Vehicle.spawnRetry) attempting to spawn vehicle...", true, 0)
	for i = 1, retry_count do
		spawned, vehicle_data = v.spawn(requested_prefab, vehicle_type, force_spawn, specified_island, purchase_type)
		if spawned then
			return spawned, vehicle_data
		else
			d.print("(Vehicle.spawnRetry) Spawning failed, retrying ("..retry_count-i.." attempts remaining)\nError: "..vehicle_data, true, 1)
		end
	end
	return spawned, vehicle_data
end

-- teleports a vehicle and all of the characters attached to the vehicle to avoid the characters being left behind
---@param vehicle_id integer the id of the vehicle which to teleport
---@param transform SWMatrix where to teleport the vehicle and characters to
---@return boolean is_success if it successfully teleported all of the vehicles and characters
function Vehicle.teleport(vehicle_id, transform)

	-- make sure vehicle_id is not nil
	if not vehicle_id then
		d.print("(Vehicle.teleport) vehicle_id is nil!", true, 1)
		return false
	end

	-- make sure transform is not nil
	if not transform then
		d.print("(Vehicle.teleport) transform is nil!", true, 1)
		return false
	end

	local vehicle_object, squad_index, squad = Squad.getVehicle(vehicle_id)

	local none_failed = true

	-- set char pos
	for i, char in ipairs(vehicle_object.survivors) do
		local is_success = s.setObjectPos(char.id, transform)
		if not is_success then
			d.print("(Vehicle.teleport) failed to set character position! char.id: "..char.id, true, 1)
			none_failed = false
		end
	end

	-- set vehicle pos
	local is_success = s.setVehiclePos(vehicle_id, transform)

	if not is_success then
		d.print("(Vehicle.teleport) failed to set vehicle position! vehicle_id: "..vehicle_id, true, 1)
		none_failed = false
	end

	return none_failed
end
 -- functions related to vehicles, and parsing data on them

function onCreate(is_world_create)

	-- start the timer for when the world has started to be setup
	local world_setup_time = s.getTimeMillisec()

	comp.verify() -- backwards compatibility check

	if just_migrated then
		comp.showSaveMessage()
		return
	end

	-- update player data
	g_savedata.players.online = {}

	if not is_world_create then
		for _, peer in pairs(s.getPlayers()) do
			Players.onJoin(tostring(peer.steam_id), peer.id)
		end
	end

	d.print("Loading Script: "..s.getAddonData((s.getAddonIndex())).name.." Is Complete, Version: "..ADDON_VERSION, true, 0, -1, 3)

	d.print(("World setup complete! took: %.3fs"):format(Ticks.millisecondsSince(world_setup_time)/1000), true, 0, -1, 4)
end

function onPlayerJoin(steam_id, name, peer_id, is_admin, is_auth)
	Players.onJoin(tostring(steam_id), peer_id)
end

