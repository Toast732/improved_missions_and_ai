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

-- Library Version 0.0.2

--[[


	Library Setup


]]

-- required libraries
require("libraries.imai.missions.objectives.objective")
require("libraries.animator.animator")

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[ 
	Contains the code for handling transporting an object.
]]

-- library name
Objective.type.transportObject = {}

--[[


	Classes


]]

---@class ObjectiveTransportObjectData
---@field object_id integer the object_id to transport
---@field destination Destination the destination to transport the object to.

---@class ObjectiveTransportObject: Objective
---@field data ObjectiveTransportObjectData the data of the objective.

--[[


	Constants


]]

-- this objective's type.
OBJECTIVE_TYPE = "transport_object"

--[[


	Variables


]]

--[[


	Functions


]]

--- Creates a new transport object objective.
---@param object_id integer the object_id to transport
---@param destination Destination the destination to transport the object to.
---@return ObjectiveTransportObject objective the created objective.
---@return Destination destination the destination.
function Objective.type.transportObject.create(object_id, destination)
	-- Create the objective.
	---@type ObjectiveTransportObject
	local objective = {
		data = {
			object_id = object_id,
			destination = destination
		},
		money_reward = 0,
		research_reward = 0,
		type = OBJECTIVE_TYPE
	}

	-- if destination instances is 0
	if destination.instances == 0 then
		-- create the destination animation.
		destination.animator_id = Animations.markers.closeDestinationRing.create(destination)
	end

	destination = Objective.destination.addInstance(destination)

	-- return the objective
	return objective, destination
end

--- Check if this transport object objective is complete. Used internally, shouldn't be used anywhere but here and in objectives.lua.
---@param objective ObjectiveTransportObject the objective to check.
---@return ObjectiveCompletionStatus status the completition status of the objective.
local function checkCompletion(objective)
	-- Get the object_id's location.
	local object_transform, is_success = server.getObjectPos(objective.data.object_id)

	--- Called by this function whenever the status is either completed or failed.
	local function onObjectiveEnd()
		-- remove 1 from the instances of the destination
		objective.data.destination = Objective.destination.removeInstance(objective.data.destination)

		-- if this is the last instance of the destination, remove the animation.
		if objective.data.destination.instances == 0 then
			Animator.removeAnimator(objective.data.destination.animator_id)
		end

		-- set the object to despawn.
		server.despawnObject(objective.data.object_id, false)
	end

	if not is_success then
		-- The object doesn't exist, so the objective is failed.
		onObjectiveEnd()
		return OBJECTIVE_COMPLETION_STATUS.FAILED
	end

	-- Check if the object is at the destination.
	local object_at_destination = Objective.destination.hasReachedDestination(
		object_transform,
		objective.data.destination
	)

	-- if the object is at the destination, return that the objective is completed.
	if object_at_destination then
		onObjectiveEnd()
		return OBJECTIVE_COMPLETION_STATUS.COMPLETED
	-- otherwise, return that the objective is in progress.
	else
		return OBJECTIVE_COMPLETION_STATUS.IN_PROGRESS
	end
end

--[[
	

	Definitions


]]

-- Define the objective
Objective.defineType(
	OBJECTIVE_TYPE,
	checkCompletion
)