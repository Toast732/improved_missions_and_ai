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

ADDON_VERSION = "(0.0.1.7)"
IS_DEVELOPMENT_VERSION = string.match(ADDON_VERSION, "(%d%.%d%.%d%.%d)")

SHORT_ADDON_NAME = "IMAI"

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

---@enum DebugTypes
debug_types = {
	[-1] = "all",
	[0] = "chat",
	"error",
	"profiler",
	"map",
	"graph_node",
	"driving",
	"vehicle",
	"function",
	"traceback"
}

g_savedata = {
	tick_counter = 0,
	vehicles = {
		ai = {
			loaded = {}, -- used to index data, to only iterate loaded vehicles
			unloaded = {}, -- used to index data, to only iterate unloaded vehicles
			data = {},
			totals = {
				types = {
					land = 0,
					sea = 0,
					heli = 0,
					plane = 0
				}
			}
		}
	},
	towns = {
		data = {} -- where the town data is stored
	},
	citizens = {
		data = {} -- where the citizens are stored
	},
	zones = {
		reservable = {} -- used for zones used for jobs, or recreation, so two npcs cannot use the same zone
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
	debug = {
		chat = {
			enabled = false,
			default = false,
			needs_setup_on_reload = false
		},
		error = {
			enabled = false,
			default = false,
			needs_setup_on_reload = false
		},
		profiler = {
			enabled = false,
			default = false,
			needs_setup_on_reload = false
		},
		map = {
			enabled = false,
			default = false,
			needs_setup_on_reload = false
		},
		graph_node = {
			enabled = false,
			default = false,
			needs_setup_on_reload = false
		},
		driving = {
			enabled = false,
			default = false,
			needs_setup_on_reload = false
		},
		vehicle = {
			enabled = false,
			default = false,
			needs_setup_on_reload = false
		},
		["function"] = {
			enabled = false,
			default = false,
			needs_setup_on_reload = true
		},
		traceback = {
			enabled = false,
			default = false,
			needs_setup_on_reload = true,
			stack = {},
			stack_size = 0,
			funct_names = {},
			funct_count = 0
		}
	},
	graph_nodes = {
		init = false,
		init_debug = false,
		nodes = {}
	},
	libraries = {}
}

-- libraries

require("libraries.addon.utils.objects.object")

require("libraries.addon.commands.command.command") -- command handler, used to register commands.

require("libraries.imai.ai.citizens.citizens")

require("libraries.ai") -- functions relating to their AI
require("libraries.cache") -- functions relating to the cache
require("libraries.compatibility") -- functions used for making the mod backwards compatible
require("libraries.addon.script.debugging") -- functions for debugging
require("libraries.map") -- functions for drawing on the map
require("libraries.utils.math") -- custom math functions
require("libraries.addon.script.matrix") -- custom matrix functions
require("libraries.addon.script.pathfinding") -- functions for pathfinding
require("libraries.addon.script.players") -- functions relating to Players
require("libraries.setup") -- functions for script/world setup.
require("libraries.spawningUtils") -- functions used by the spawn vehicle function
require("libraries.utils.string") -- custom string functions
require("libraries.utils.tables") -- custom table functions
require("libraries.tags") -- functions related to getting tags from components inside of mission and environment locations
require("libraries.ticks") -- functions related to ticks and time
require("libraries.vehicle") -- functions related to vehicles, and parsing data on them

function onCreate(is_world_create)

	-- start the timer for when the world has started to be setup
	local world_setup_time = s.getTimeMillisec()

	-- setup settings
	if not g_savedata.settings then
		g_savedata.settings = {
			MAX_FAMILIES_PER_TOWN = property.slider("Maximum Families Per Town", 0, 20, 1, 7),
			MAX_OCCUPIED_HOUSES_PERCENTAGE = property.slider("Maximum percentage of houses with residents per town", 0, 100, 5, 75) * 0.01
		}
	end

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

		--d.print("setting up reservable zones...", true, 0)
		
		--Zones.setup()
	end

	d.print("Loaded Script: "..s.getAddonData((s.getAddonIndex())).name..", Version: "..ADDON_VERSION, true, 0, -1)

	d.print(("World setup complete! took: %.3fs"):format(Ticks.millisecondsSince(world_setup_time)/1000), true, 0, -1)
end

function onPlayerJoin(steam_id, name, peer_id, is_admin, is_auth)
	Players.onJoin(tostring(steam_id), peer_id)
end

function onTick(game_ticks)

	g_savedata.tick_counter = g_savedata.tick_counter + 1
	--server.setGameSetting("npc_damage", true)
	--d.print("onTick", false, 0)
	Citizens.onTick(game_ticks)
end

--------------------------------------------------------------------------------
--
-- Other
--
--------------------------------------------------------------------------------

---@param id integer the tick you want to check that it is
---@param rate integer the total amount of ticks, for example, a rate of 60 means it returns true once every second* (if the tps is not low)
---@return boolean isTick if its the current tick that you requested
function isTickID(id, rate)
	return (g_savedata.tick_counter + id) % rate == 0
end

---@param start_ms number the time you want to see how long its been since (in ms)
---@return number ms_since how many ms its been since <start_ms>
function millisecondsSince(start_ms)
	return s.getTimeMillisec() - start_ms
end