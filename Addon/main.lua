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

local ADDON_VERSION = "(0.0.1.4)"
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
require("libraries.ai") -- functions relating to their AI
require("libraries.cache") -- functions relating to the cache
require("libraries.compatibility") -- functions used for making the mod backwards compatible
require("libraries.debugging") -- functions for debugging
require("libraries.map") -- functions for drawing on the map
require("libraries.math") -- custom math functions
require("libraries.matrix") -- custom matrix functions
require("libraries.pathfinding") -- functions for pathfinding
require("libraries.players") -- functions relating to Players
require("libraries.setup") -- functions for script/world setup.
require("libraries.spawningUtils") -- functions used by the spawn vehicle function
require("libraries.string") -- custom string functions
require("libraries.tables") -- custom table functions
require("libraries.tags") -- functions related to getting tags from components inside of mission and environment locations
require("libraries.ticks") -- functions related to ticks and time
require("libraries.vehicle") -- functions related to vehicles, and parsing data on them

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

	p.updatePathfinding()

	if is_world_create then
		d.print("setting up world...", true, 0)

		d.print("getting y level of all graph nodes...", true, 0)
		-- cause createPathY to execute, which will get the y level of all graph nodes
		-- otherwise the game would freeze for a bit after the player loaded in, looking like the game froze
		-- instead it looks like its taking a bit longer to create the world.

		local empty_matrix = m.identity()

		s.pathfind(empty_matrix, empty_matrix, "", "")
	end

	d.print("Loaded Script: "..s.getAddonData((s.getAddonIndex())).name..", Version: "..ADDON_VERSION, true, 0, -1, 3)

	d.print(("World setup complete! took: %.3fs"):format(Ticks.millisecondsSince(world_setup_time)/1000), true, 0, -1, 4)
end

function onPlayerJoin(steam_id, name, peer_id, is_admin, is_auth)
	Players.onJoin(tostring(steam_id), peer_id)
end