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
require("libraries.imai.vehicles.routing.routing")

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[ 
	LIBRARY DESCRIPTION
]]

-- library name
LandRoute = {}

--[[


	Classes


]]

--[[


	Constants


]]

-- The base land consumption distance, means how many metres the vehicle has to be within the node for it to get sent to the next node in the path.
BASE_LAND_CONSUMPTION_DISTANCE = 5

--[[


	Variables


]]

g_savedata.routing.land = {
	debug_routes = {}
}

--[[


	Functions


]]

--- Function for creating a land route
---@param start_matrix SWMatrix the start of the route
---@param end_matrix SWMatrix the end of the route
---@return Route
function LandRoute.new(start_matrix, end_matrix)

	--[[
		Try getting the path from the stored paths

		First, grab the hash of the path, and then check if it's stored, if not, then create it
		but if it's created, then we can use that instead.
	]]

	-- Grab the hash
	local hash = Routing.getPathHash(start_matrix, end_matrix, "land")

	-- Check if the path is stored
	local path_id = Routing.getPathIDFromHash(hash)

	-- If the path is not stored.
	if not path_id then
		-- Create the path
		path = Pathfinding.getLandPath(start_matrix, end_matrix, BASE_LAND_CONSUMPTION_DISTANCE)

		-- Store the path
		path_id = Routing.storePath(path, hash)
	end

	-- Create the route
	---@type Route
	local route = {
		stored_path_id = path_id,
		route_type = "land",
		path_index = 1,
		start_matrix = start_matrix,
		end_matrix = end_matrix,
	}

	return route
end

-- Define a command to test out getting a land path
Command.registerCommand(
	"test_land_path",
	---@param full_message string the full message
	---@param peer_id integer the peer_id of the sender
	---@param arg table the arguments of the command.
	function(full_message, peer_id, arg)
		--- Have the player's position be the start pos, and then have them specify x, y, z for destination
		local start_matrix = server.getPlayerPos(peer_id)

		-- Get the destination
		local destination = Vector3.new(
			tonumber(arg[1]) or 0,
			tonumber(arg[2]) or 0,
			tonumber(arg[3]) or 0
		)

		-- Create the end matrix
		local end_matrix = matrix.identity()

		-- Set the end matrix position
		end_matrix[13] = destination.x
		end_matrix[14] = destination.y
		end_matrix[15] = destination.z

		-- Create the route
		local route = LandRoute.new(start_matrix, end_matrix)

		-- Store the route
		table.insert(g_savedata.routing.land.debug_routes, route)

		-- Get the path from the route
		local path = Routing.getPathFromID(route.stored_path_id)

		if not path then
			return
		end

		-- Display the path on the map.
		for path_index = 1, #path do
			local path_node = path[path_index]

			-- Display the path node
			Map.addMapCircle(
				-1,
				path_node.ui_id,
				matrix.translation(path_node.x, path_node.y, path_node.z),
				5,
				1,
				0,
				255,
				25,
				255,
				16
			)

			-- if the path_index is greater than 1, then display the line between the two nodes
			if path_index > 1 then
				local previous_path_node = path[path_index - 1]

				-- Display the line
				server.addMapLine(
					-1,
					path_node.ui_id,
					matrix.translation(previous_path_node.x, previous_path_node.y, previous_path_node.z),
					matrix.translation(path_node.x, path_node.y, path_node.z),
					1,
					0,
					255,
					25,
					255
				)
			end
		end
	end,
	"admin",
	"",
	"",
	{""}
)

-- Define a command to remove all drawn debug land nodes, and clear them from the table.
Command.registerCommand(
	"clear_land_path_debug",
	---@param full_message string the full message
	---@param peer_id integer the peer_id of the sender
	---@param arg table the arguments of the command.
	function(full_message, peer_id, arg)
		-- Remove all the map circles
		for _, route in pairs(g_savedata.routing.land.debug_routes) do
			local path = Routing.getPathFromID(route.stored_path_id)

			if not path then
				return
			end

			-- Display the path on the map.
			for path_index = 1, #path do
				local path_node = path[path_index]

				-- Display the path node
				server.removeMapID(-1, path_node.ui_id)
			end
		end

		-- Clear the table
		g_savedata.routing.land.debug_routes = {}
	end,
	"admin",
	"",
	"",
	{""}
)
