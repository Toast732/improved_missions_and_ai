--? Copyright 2024 Liam Matthews

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

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

ADDON_VERSION = "(0.0.1.18)"
IS_DEVELOPMENT_VERSION = string.match(ADDON_VERSION, "(%d%.%d%.%d%.%d)")

SHORT_ADDON_NAME = "IMAI"

local just_migrated = false

-- shortened library names
local m = matrix
local s = server

time = { -- the time unit in ticks, irl time, not in game
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
			enabled = true,
			default = true,
			needs_setup_on_reload = true,
			stack = {}, -- the stack of function calls.
			stack_size = 0, -- the size of the stack, used so we don't actually have to remove things from the stack to save on performance.
			funct_names = {}, -- the names of the functions in the stack, so we can use numberical ids in the stack instead for performance and memory usage.
			funct_count = 0 -- the total number of functions, used to optimise the setup phase for tracebacks.
		}
	},
	graph_nodes = {
		init = false,
		init_debug = false,
		---@type table<string, table<string, YPathfinderNodeData>> the graph nodes, indexed by x coordinate, then z.
		nodes = {}
	},
	libraries = {}
}

-- libraries
require("requiredFiles")

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

	Pathfinding.updatePathfinding()

	if is_world_create then
		d.print("setting up world...", true, 0)

		d.print("getting y level of all graph nodes...", true, 0)
		-- cause createPathY to execute, which will get the y level of all graph nodes
		-- otherwise the game would freeze for a bit after the player loaded in, looking like the game froze
		-- instead it looks like its taking a bit longer to create the world.

		local empty_matrix = matrix.identity()

		s.pathfind(empty_matrix, empty_matrix, "", "")
	end

	-- send out discovery message (AddonDiscoveryAPI)
	server.command(([[AddonDiscoveryAPI discovery "%s" --category:"Gameplay" --version:"%s"]]):format(SHORT_ADDON_NAME, ADDON_VERSION))

	d.print("Loaded Script: "..s.getAddonData((s.getAddonIndex())).name..", Version: "..ADDON_VERSION, true, 0, -1)

	ac.executeOnReply( -- setup world after 1 tick, to prevent issues with the addon indexes getting mixed up
		SHORT_ADDON_NAME, -- addon we're expecting the reply from
		"onCreate()", -- the message content
		0, -- the port to recieve this from
		function()
			setupMain(is_world_create)
		end, -- function to execute when we get the reply
		1, -- how many times this can be triggered
		20 -- how many seconds to wait till we expire it
	)

	ac.sendCommunication("onCreate()", 0)
end

--- Called 1 tick after the world has been created, to prevent issues with the addon indexes getting mixed up
---@param is_world_create boolean if the world is being created
function setupMain(is_world_create)

	-- start the timer for when the world has started to be setup
	local world_setup_time = server.getTimeMillisec()

	-- Setup the prefabs
	VehiclePrefab.generatePrefabs()

	g_savedata.info.setup = true

	for debug_type, debug_setting in pairs(g_savedata.debug) do
		if (debug_setting.needs_setup_on_reload and debug_setting.enabled) or (is_world_create and debug_setting.default) then
			local debug_id = d.debugIDFromType(debug_type)

			if debug_setting.needs_setup_on_reload then
				d.handleDebug(debug_type, true, 0)
			end

			d.setDebug(debug_id, -1, true)

		end
	end

	
	d.print(("%s setup complete! took: %.3f%s"):format(SHORT_ADDON_NAME, millisecondsSince(world_setup_time)/1000, "s"), true, 0)

	-- this one will reset every reload/load of the world, this ensures that tracebacks wont be enabled before setupMain is finished.
	addon_setup = true
end

function onPlayerJoin(steam_id, name, peer_id, is_admin, is_auth)
	if not g_savedata.info.setup then
		d.print("Setting up IMAI for the first time, this may take a few seconds.", false, 0, peer_id)
	end

	eq.queue(
		function()
			return is_dlc_weapons and addon_setup
		end,
		function(self)

			local peer_id = self:getVar("peer_id")
			local steam_id = self:getVar("steam_id")

			Players.onJoin(steam_id, peer_id)

			local player = Players.dataBySID(steam_id)

			if player then
				for debug_type, debug_data in pairs(g_savedata.debug) do
					if debug_data.auto_enable then
						d.setDebug(d.debugIDFromType(debug_type), peer_id, true)
					end
				end
			end
		end,
		{
			peer_id = peer_id,
			steam_id = tostring(steam_id)
		},
		1,
		-1
	)
end

function onTick(game_ticks)

	if g_savedata.debug.traceback.enabled then
		ac.sendCommunication("DEBUG.TRACEBACK.ERROR_CHECKER", 0)
	end

	g_savedata.tick_counter = g_savedata.tick_counter + 1
	--server.setGameSetting("npc_damage", true)
	--d.print("onTick", false, 0)

	VehiclePrefab.onTick(game_ticks)

	VehicleSpeedTracker.onTick(game_ticks)

	Effects.onTick(game_ticks)

	Citizens.onTick(game_ticks)

	Missions.onTick(game_ticks)

	Animator.onTick(game_ticks)

	DrivableVehicle.onTick(game_ticks)
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