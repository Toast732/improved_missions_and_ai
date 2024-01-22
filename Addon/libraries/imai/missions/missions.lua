--[[

Copyright 2024 Liam Matthews

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

]]

-- Library Version 0.0.3

--[[


	Library Setup


]]

-- required libraries
require("libraries.utils.tables")
require("libraries.addon.commands.command.command")
require("libraries.imai.missions.objectives.objective")

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[ 
	LIBRARY DESCRIPTION
]]

-- library name
Missions = {}

--[[


	Classes


]]

---@class Mission
---@field internal_name string the internal name of the mission.
---@field objectives Objectives the objectives of the mission.

---@alias Missions table<integer, Mission>

---@class DefinedMission
---@field internal_name string the internal name of the mission.
---@field name string the name of the mission.
---@field startMission fun(...) the function to call to start the mission.
---@field onCompletion fun(mission: Mission) the function to call when the mission is completed, as in, when there's no more objectives.

--[[


	Constants


]]

-- The tickrate of missions, the number of ticks between each time the mission is ticked.
MISSION_TICK_RATE = 15

--[[


	Variables


]]

g_savedata.missions = g_savedata.missions or {
	---@type Missions
	missions_list = {}
}

---@type table<string, DefinedMission> a table of defined missions, indexed by the internal name.
defined_missions = {}

--[[


	Functions


]]

--- Define a mission, should be used by the included missions.
---@param internal_name string the internal name of the mission.
---@param name string the name of the mission.
---@param startMission fun(...) the function to call to start the mission.
---@param onCompletion fun(mission: Mission) the function to call when the mission is completed, as in, when there's no more objectives.
function Missions.define(internal_name, name, startMission, onCompletion)
	-- Create the defined mission
	local defined_mission = {
		internal_name = internal_name,
		name = name,
		startMission = startMission,
		onCompletion = onCompletion
	}

	-- add it to the defined missions list
	defined_missions[internal_name] = defined_mission
end

--- Create a mission from a set of objectives.
---@param internal_name string the internal name of the mission.
---@param objectives Objectives the objectives of the mission.
---@return Mission mission the created mission.
function Missions.create(internal_name, objectives)
	-- Create the mission
	local mission = {
		internal_name = internal_name,
		objectives = objectives
	}

	-- add it to the missions list
	table.insert(g_savedata.missions.missions_list, mission)

	-- Return the mission
	return mission
end

--- Tick the missions
---@param game_ticks integer the amount of game ticks that have passed since the last tick.
function Missions.onTick(game_ticks)

	-- get the number of missions
	local mission_count = #g_savedata.missions.missions_list

	--[[
		iterate through all missions, split it evenly among MISSION_TICK_RATE ticks.
		
		Operation:
		- start at the last mission with the matching tick id
		- dont go lower than 1
		- decrement by the MISSION_TICK_RATE each time.
		
		Allows us to evenly split it among the ticks, without requiring us to iterate through
		each one to check if it matches the tick_id.
	]]
	for mission_index = mission_count - g_savedata.tick_counter % MISSION_TICK_RATE, 1, -MISSION_TICK_RATE do

		-- get the mission
		local mission = g_savedata.missions.missions_list[mission_index]

		-- get the number of objectives in this mission
		local objective_count = #mission.objectives

		-- iterate through all of the objectives
		for objective_index = objective_count, 1, -1 do

			local objective = mission.objectives[objective_index]

			-- tick the objective
			local completion_status = Objective.checkCompletion(objective)

			if completion_status == OBJECTIVE_COMPLETION_STATUS.COMPLETED then
				server.notify(
					-1,
					"Mission Objective",
					"A mission objective has been completed.",
					8
				)

				-- remove the objective
				table.remove(mission.objectives, objective_index)
			elseif completion_status == OBJECTIVE_COMPLETION_STATUS.FAILED then
				server.notify(
					-1,
					"Mission Objective",
					"A mission objective has been failed.",
					2
				)
				
				-- remove the objective
				table.remove(mission.objectives, objective_index)
			end
		end

		-- if the number of objectives in this mission is 0, remove the mission.
		if #mission.objectives == 0 then
			table.remove(g_savedata.missions.missions_list, mission_index)

			server.notify(
				-1,
				"Mission",
				"A mission has been completed.",
				4
			)
		end
	end
end

--[[


	Definitions


]]

-- Define a command to start a mission
Command.registerCommand(
	"start_mission",
	---@param full_message string the full message
	---@param peer_id integer the peer_id of the sender
	---@param arg table the arguments of the command.
	function(full_message, peer_id, arg)
		-- Check if the mission is defined
		if defined_missions[arg[1]] == nil then
			d.print(("Mission %s is not defined."):format(arg[1]), false, 1, peer_id)
			return
		end

		g_savedata.included_missions.scripted.transport.demo.started = false

		-- Call the mission start function
		defined_missions[arg[1]].startMission()
	end,
	"admin_script",
	"Starts the specified mission.",
	"Starts the specified mission, specified mission name must be it's internal name.",
	{"start_mission <internal_mission_name> [mission_args...]"}
)

-- Define a command to list all registered missions.
Command.registerCommand(
	"list_defined_missions",
	---@param full_message string the full message
	---@param peer_id integer the peer_id of the sender
	---@param arg table the arguments of the command.
	function(full_message, peer_id, arg)
		-- get the number of missions
		local mission_count = table.length(defined_missions)

		-- if there are no missions, return
		if mission_count == 0 then
			d.print("There are no missions.", false, 1, peer_id)
			return
		end

		-- iterate through all missions
		for internal_mission_name, mission_definition in pairs(defined_missions) do

			-- if the mission definition does not exist for whatever reason, go to the next mission to prevent an error
			if mission_definition == nil then
				d.print(("Failed to find definition for mission \"%s\"."):format(internal_mission_name), false, 1, peer_id)
				goto continue
			end

			-- print the mission
			d.print(
				("Mission Internal Name: \"%s\"\nMission Name: \"%s\""):format(mission_definition.internal_name, mission_definition.name),
				false,
				0,
				peer_id
			)

			::continue::
		end
	end,
	"admin",
	"Lists all missions, with their internal name, and their proper name. The internal names are useful for when trying to manually start a mission.",
	"Lists all missions.",
	{"list_missions"}
)

-- Define a command to stop a mission.
Command.registerCommand(
	"stop_mission",
	---@param full_message string the full message
	---@param peer_id integer the peer_id of the sender
	---@param arg table the arguments of the command.
	function(full_message, peer_id, arg)

		-- get the mission_index
		local mission_index = tonumber(arg[1])

		-- Check if the mission exists
		if g_savedata.missions.missions_list[mission_index] == nil then
			d.print(("%s is not a valid index. There is no mission with that index."):format(arg[1]), false, 1, peer_id)
			return
		end

		-- get the mission
		local mission = g_savedata.missions.missions_list[mission_index]

		-- remove the mission
		table.remove(g_savedata.missions.missions_list, mission_index)

		-- get it's definition
		local mission_definition = defined_missions[mission.internal_name]

		-- if it's function definition does not exist for whatever reason, return to prevent an error
		if mission_definition == nil then
			return
		end

		-- remove all objectives
		for objective_index = #mission.objectives, 1, -1 do
			Objective.remove(mission.objectives[objective_index])
		end

		-- Call the mission stop function
		mission_definition.onCompletion(mission)
	end,
	"admin_script",
	"Stops the specified mission.",
	"Stops the specified mission, from it's mission_index.",
	{"stop_mission <mission_index>"}
)