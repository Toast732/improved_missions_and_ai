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
require("libraries.pathing.pathfinding")

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[ 
	Handles the creation of routes by interfacing with pathfinding.lua.

	Stores routes by a hash, in order to avoid recalculating the same route over and over again, when we could just pull the ones we've already calculated.
]]

-- library name
Routing = {}

--[[


	Classes


]]

---@alias StoredPathID integer the id of a stored path

---@class Route
---@field stored_path_id StoredPathID the id of the stored path
---@field route_type string the type of route
---@field path_index integer the index that the vehicle is at on the path
---@field start_matrix SWMatrix the start of the route
---@field end_matrix SWMatrix the end of the route

---@alias PathHash string the hash of a path, format is: start x + | + start y + | + start z + | + end x + | + end y + | + end z + | + route type

--[[


	Constants


]]

-- The distance the node must be to the tile border to be checked for if it failed merging.
FAILED_NODE_TILE_BORDER_DISTANCE = 4

-- The distance the node must be to another node for it to be considered merged
NODE_MERGE_DISTANCE = 10 -- Thanks antie

--[[


	Variables


]]

g_savedata.routing = {
	---@type table<StoredPathID, Path>
	stored_paths = {}, -- A table of stored paths, used for getting a path from an id, to avoid needing to store the same path multiple times, and to avoid needing to re-calculating them for the same start/end positions.

	---@type StoredPathID
	next_path_id = 1, -- The next path id to use

	---@type table<PathHash, StoredPathID>
	path_hashes = {}, -- A table of path hashes to stored path ids, used for checking if a path has already been stored

	---@type SWUI_ID
	failed_node_merge_ui_id = nil -- The ui id of the failed node merge ui
}

--- The stored defined operations, for operating vehicles of that class.

--[[


	Functions


]]

--- Function for getting a path hash
---@param start_matrix SWMatrix the start of the route
---@param end_matrix SWMatrix the end of the route
---@param route_type string the type of route
---@return PathHash hash the hash of the route
function Routing.getPathHash(start_matrix, end_matrix, route_type)
	-- create the hash
	local hash = ("%0.1f|%0.1f|%0.1f|%0.1f|%0.1f|%0.1f|%s"):format(
		start_matrix[13],
		start_matrix[14],
		start_matrix[15],
		end_matrix[13],
		end_matrix[14],
		end_matrix[15],
		route_type
	)

	-- return the hash
	return hash
end

--- Function for storing a path
---@param path Path the path to store
---@param path_hash PathHash the hash of the path
---@return integer path_id path id of the stored path, if path has already been stored, returns it's id.
function Routing.storePath(path, path_hash)
	-- Check if the path has already been stored
	if g_savedata.routing.path_hashes[path_hash] then
		-- return existing id
		return g_savedata.routing.path_hashes[path_hash]
	end

	-- store the path
	g_savedata.routing.stored_paths[g_savedata.routing.next_path_id] = path

	-- store the path hash
	g_savedata.routing.path_hashes[path_hash] = g_savedata.routing.next_path_id

	-- increment the next path id
	g_savedata.routing.next_path_id = g_savedata.routing.next_path_id + 1

	return g_savedata.routing.next_path_id - 1
end

--- Function for resetting all stored paths
function Routing.resetStoredPaths()
	-- reset the stored paths
	g_savedata.routing.stored_paths = {}

	-- reset the path hashes
	g_savedata.routing.path_hashes = {}
end

--- Function for getting a path from the id
---@param path_id StoredPathID the id of the path to get
---@return Path? path the path, nil if no path.
function Routing.getPathFromID(path_id)
	-- return the path
	return g_savedata.routing.stored_paths[path_id]
end

--- Function for getting a path id from the hash
---@param path_hash PathHash the hash of the path to get
---@return StoredPathID? path_id the id of the path, nil if no path.
function Routing.getPathIDFromHash(path_hash)
	-- return the path id
	return g_savedata.routing.path_hashes[path_hash]
end

--- Function for getting a path from the hash
---@param path_hash PathHash the hash of the path to get
---@return Path? path the path, nil if no path.
function Routing.getPathFromHash(path_hash)
	-- get the path id
	local path_id = Routing.getPathIDFromHash(path_hash)

	-- if the path id is nil
	if not path_id then
		-- return nil, as there is no path
		return nil
	end

	-- return the path
	return g_savedata.routing.stored_paths[path_id]
end

--[[


	Definitions


]]

require("libraries.imai.vehicles.routing.vehicleTypes.land")

--[[

	Commands

]]

--- Command for showing all graph nodes that possibly failed merging, resulting in the path not crossing the tile border properly.
-- Define a command to test out getting a land path
Command.registerCommand(
	"show_failed_merge_nodes",
	---@param full_message string the full message
	---@param peer_id integer the peer_id of the sender
	---@param arg table the arguments of the command.
	function(full_message, peer_id, arg)

		-- Make sure the ui_id for the failed node merge ui is set
		g_savedata.routing.failed_node_merge_ui_id = g_savedata.routing.failed_node_merge_ui_id or server.getMapID()

		-- Remove all of the previous drawn circles
		server.removeMapID(-1, g_savedata.routing.failed_node_merge_ui_id)

		---@class NodeToMergeCheckData
		---@field node_data NodeData the node data
		---@field position Vector3 the position of the node

		-- Define a list of graph nodes that are within the distance to the tile border
		---@type table<integer, NodeToMergeCheckData>
		local nodes_to_check = {}

		-- Iterate through every single graph node
		for x, x_table in pairs(g_savedata.graph_nodes.nodes) do
			
			-- Iterate through all of the nodes on this x axis
			for z, node_data in pairs(x_table) do

				-- Get the node's position as a vector2
				local node_position_vec2 = Vector2.new(
					tonumber(x) --[[@as number]],
					tonumber(z) --[[@as number]]
				)

				-- Get the closest tile border distance for this node
				local closest_tile_border_distance = Pathfinding.distanceToClosestTileBorder(node_position_vec2)

				-- Check if the node is within the distance to the tile border
				if closest_tile_border_distance <= FAILED_NODE_TILE_BORDER_DISTANCE then
					-- Add the node to the list of nodes to check
					table.insert(nodes_to_check, {
						node_data = node_data,
						position = Vector3.new(
							node_position_vec2.x,
							node_data.y,
							node_position_vec2.y
						)
					})
				end
			end
		end

		-- Define a list of nodes that failed merging
		---@type table<integer, NodeToMergeCheckData>
		local failed_merge_nodes = {}

		-- Iterate through all of the nodes to check
		for node_index = 1, #nodes_to_check do
			-- Get the node to check
			local node_to_check = nodes_to_check[node_index]

			-- If this node has any nodes within it's merge distance
			local has_nodes_within_merge_distance = false

			-- Iterate through all of the nodes to check against
			for node_to_check_against_index = 1, #nodes_to_check do
				-- Get the node to check against
				local node_to_check_against = nodes_to_check[node_to_check_against_index]

				-- Skip if the nodes are the same
				if node_index == node_to_check_against_index then
					goto continue
				end

				-- Skip if the nodes are not within the merge distance
				if Vector3.euclideanDistance(node_to_check.position, node_to_check_against.position) > NODE_MERGE_DISTANCE then
					goto continue
				end

				-- Skip if this node is on the same tile
				if server.getTile(Vector3.toMatrix(node_to_check.position)).name == server.getTile(Vector3.toMatrix(node_to_check_against.position)).name then
					goto continue
				end

				-- Set that this node has nodes within it's merge distance
				has_nodes_within_merge_distance = true

				-- Break
				break

				---@diagnostic disable-next-line: code-after-break
				::continue::
			end

			-- If this node has no nodes within it's merge distance
			if not has_nodes_within_merge_distance then
				-- Add it to the list of failed merge nodes
				table.insert(failed_merge_nodes, node_to_check)
			end
		end

		-- Iterate through all of the failed merge nodes, and draw them.
		for node_index = 1, #failed_merge_nodes do
			-- Get the node
			local node = failed_merge_nodes[node_index]

			-- Draw the node
			Map.addMapCircle(peer_id, g_savedata.routing.failed_node_merge_ui_id, Vector3.toMatrix(node.position), 10, 1, 255, 0, 0, 255, 15)
		end

		d.print(("Drew %d nodes that possibly failed to merge."):format(#failed_merge_nodes), true, 0, peer_id)
	end,
	"admin",
	"Shows all graph nodes that possibly failed merging, resulting in the path not crossing the tile border properly.",
	"Shows all graph nodes that possible failed merging.",
	{""}
)