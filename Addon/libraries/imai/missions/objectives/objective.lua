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

-- Library Version 0.0.1

--[[


	Library Setup


]]

-- required libraries

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

---@alias DestinationType
---| "zone" meaning the destination is a zone.
---| "matrix" meaning the destination is a matrix.

---@class Destination
---@field type DestinationType the type of destination.
---@field zone SWZone|nil the zone the destination is in. Only used if the type is "zone".
---@field position SWVoxelPos|nil the position of the destination. Only used if the type is "matrix". Stored as voxel pos to avoid higher memory usage.
---@field radius number|nil the radius of the destination. Only used if the type is "matrix".

--[[


	Variables


]]

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
		zone = zone
	}

	-- return the destination
	return destination
end

--- Create a destination using a matrix.
---@param dest_matrix SWMatrix the matrix to use as the destination.
---@param radius number the radius of the destination.
---@return Destination destination the destination.
function Objective.destination.matrix(dest_matrix, radius)

	-- extract position from the matrix (I assume this function properly applies the rotations, scaling, etc to the matrix.)
	local x, y, z = matrix.position(dest_matrix)

	-- Turn into 3D position ("SWVoxelPos")
	---@type SWVoxelPos
	local dest_pos = {
		x = x,
		y = y,
		z = z
	}

	-- create the destination using the matrix
	---@type Destination
	local destination = {
		type = "matrix",
		position = dest_pos,
		radius = radius
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

	-- extract position from the matrix (I assume this function properly applies the rotations, scaling, etc to the matrix.)
	local current_x, current_y, current_z = matrix.position(current_matrix)

	-- get the distance from the current position to the target position
	local destination_distance = math.euclideanDistance(
		current_x,
		destination.position.x,
		current_z,
		destination.position.z,
		current_y,
		destination.position.y
	)

	-- return if the distance from the current position to the target position is within the radius
	return destination_distance <= destination.radius
end