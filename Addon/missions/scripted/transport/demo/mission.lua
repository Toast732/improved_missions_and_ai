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

-- Mission Version 0.0.1

--[[


	Mission Setup


]]

-- required libraries
require("libraries.imai.missions.objectives.types.transportObject")

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[ 
	Testing mission for demoing transport missions.
]]

-- library name
IncludedMissions.scripted.transport.demo = {}

--[[


	Classes


]]

--[[


	Variables


]]

g_savedata.included_missions.scripted.transport.demo = g_savedata.included_missions.scripted.transport.demo or {
	started = false
}

INTERNAL_MISSION_NAME = "scripted.transport.demo"
MISSION_NAME = "Transport Objects DEMO"

--[[


	Functions


]]

--[[
	start the mission
]]
function IncludedMissions.scripted.transport.demo.create()
	
	-- only allow 1 instance.
	if g_savedata.included_missions.scripted.transport.demo.started then
		return
	end

	-- Create the objects to transport. (3 small boxes)
	-- position is next to ETrain Terminal.

	local object_id1 = server.spawnObject(matrix.translation(2232, 10, -25970), 2)
	local object_id2 = server.spawnObject(matrix.translation(2232, 12, -25970), 2)
	local object_id3 = server.spawnObject(matrix.translation(2230, 10, -25970), 2)

	-- Create the destination.
	local destination = Objective.destination.matrix(matrix.translation(2239, 11.25, -26000), 5)

	-- Create the objectives.
	objective1, destination = Objective.type.transportObject.create(object_id1, destination)
	objective2, destination = Objective.type.transportObject.create(object_id2, destination)
	objective3, destination = Objective.type.transportObject.create(object_id3, destination)

	-- Create the mission
	Missions.create(
		INTERNAL_MISSION_NAME,
		{
			objective1,
			objective2,
			objective3
		}
	)

	-- set started to true
	g_savedata.included_missions.scripted.transport.demo.started = true
end

--[[


	Definitions


]]

-- define the mission
Missions.define(
	INTERNAL_MISSION_NAME,
	MISSION_NAME,
	IncludedMissions.scripted.transport.demo.create,
	function(mission)
		-- set started to false.
		g_savedata.included_missions.scripted.transport.demo.started = false
	end
)