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
require("libraries.utils.vector3")

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[ 
	LIBRARY DESCRIPTION
]]

-- library name
Objective = {
	type = {},
	destination = {}
}

--[[


	Classes


]]

---@class Objective
---@field money_reward number the amount of money to reward the player with when they complete it.
---@field research_reward number the amount of research points to reward the player with when they complete it.
---@field type string the type of objective.

---@alias Objectives table<int, Objective>

---@alias DestinationType
---| "zone" meaning the destination is a zone.
---| "matrix" meaning the destination is a matrix.

---@class Destination
---@field type DestinationType the type of destination.
---@field zone SWZone|nil the zone the destination is in. Only used if the type is "zone".
---@field position Vector3|nil the position of the destination. Only used if the type is "matrix". Stored as voxel pos to avoid higher memory usage.
---@field radius number|nil the radius of the destination. Only used if the type is "matrix".
---@field instances integer the amount of instances of this destination. Used to know if it can be removed or not.
---@field animator_id AnimatorID? The animator id for this destination.

---@class DefinedObjective
---@field name string the name of the objective.
---@field checkCompletion fun(objective: Objective):ObjectiveCompletionStatus the function to check if the objective is complete.
---@field removeObjective fun(objective: Objective) the function to call when the objective is completed.

--[[


	Constants


]]

-- Completition status of an objective.
---@enum ObjectiveCompletionStatus
OBJECTIVE_COMPLETION_STATUS = {
	IN_PROGRESS = 0,
	COMPLETED = 1,
	FAILED = 2
}

--[[


	Variables


]]

g_savedata.objectives = g_savedata.objectives or {
	---@type table<int, Destination>
	destinations = {}
}

-- stores the defined objectives, indexed by the type of the objective.
---@type table<string, DefinedObjective>
defined_objectives = {}

--[[


	Functions


]]

--[[

	Destination Functions

]]

--- Create a destination using a zone.
---@param zone SWZone the zone to use as the destination.
---@return Destination destination the destination.
function Objective.destination.zone(zone)
	-- create the destination using the zone
	---@type Destination
	local destination = {
		type = "zone",
		zone = zone,
		instances = 0
	}

	-- return the destination
	return destination
end

--- Create a destination using a matrix.
---@param dest_matrix SWMatrix the matrix to use as the destination.
---@param radius number the radius of the destination.
---@return Destination destination the destination.
function Objective.destination.matrix(dest_matrix, radius)

	-- turn the dest matrix into a vector 3
	local dest_pos = Vector3.fromMatrix(dest_matrix, false)

	-- create the destination using the matrix
	---@type Destination
	local destination = {
		type = "matrix",
		position = dest_pos,
		radius = radius,
		instances = 0
	}

	-- return the destination
	return destination
end

--- Check if a matrix is within the destination
---@param current_matrix SWMatrix the matrix to check.
---@param destination Destination the destination to check.
---@return boolean is_in_destination whether or not the matrix is in the destination.
function Objective.destination.hasReachedDestination(current_matrix, destination)
	-- check if the destination is a zone
	if destination.type == "zone" then
		-- check if the matrix is in the zone
		return server.isInTransformArea(
			matrix,
			destination.zone.transform,
			destination.zone.size.x,
			destination.zone.size.y,
			destination.zone.size.z
		)
	end

	--* this destination is a matrix.

	-- get vector3 of the current matrix
	local current_pos = Vector3.fromMatrix(current_matrix, false)

	-- get the distance from the current position to the target position
	local destination_distance = Vector3.manhattanDistance(
		current_pos,
		destination.position
	)

	-- return if the distance from the current position to the target position is within the radius
	return destination_distance <= destination.radius
end

--- Add an instance of this destination, used so it knows if it can be removed or not.
---@param destination Destination the destination to add an instance of.
---@return Destination destination the destination with an added instance.
function Objective.destination.addInstance(destination)
	-- add an instance
	destination.instances = destination.instances + 1

	-- return the destination
	return destination
end

--- Remove an instance of this destination, used so it knows if it can be removed or not.
---@param destination Destination the destination to remove an instance of.
---@return Destination destination the destination with a removed instance.
function Objective.destination.removeInstance(destination)
	-- remove an instance
	destination.instances = destination.instances - 1

	return destination
end

--[[

	Objective Functions

]]

--[[
	Internal Usage Functions
]]

--- Define a new objective type. (Should only be used when creating new objective types)
---@param name string the name of the objective type.
---@param checkCompletion fun(objective: Objective):ObjectiveCompletionStatus the function to check if the objective is complete.
---@param removeObjective fun(objective: Objective) the function to call when the objective is completed.
function Objective.defineType(name, checkCompletion, removeObjective)
	-- create the objective type
	defined_objectives[name] = {
		name = name,
		checkCompletion = checkCompletion,
		removeObjective = removeObjective
	}
end

--[[
	External Usage Functions
]]

--- Checks if an objective is completed
---@param objective Objective the objective to check.
---@return ObjectiveCompletionStatus status the completition status of the objective.
function Objective.checkCompletion(objective)
	-- check if the objective type is defined
	if not defined_objectives[objective.type] then
		d.print(("<line>: Objective type \"%s\" is not defined."):format(objective.type), true, 1)
		return OBJECTIVE_COMPLETION_STATUS.FAILED
	end

	-- check if the objective is completed
	return defined_objectives[objective.type].checkCompletion(objective)
end

--- Remove an objective
---@param objective Objective the objective to remove.
function Objective.remove(objective)
	-- check if the objective type is defined
	if not defined_objectives[objective.type] then
		d.print(("<line>: Objective type \"%s\" is not defined."):format(objective.type), true, 1)
		return
	end

	-- remove the objective
	defined_objectives[objective.type].removeObjective(objective)
end