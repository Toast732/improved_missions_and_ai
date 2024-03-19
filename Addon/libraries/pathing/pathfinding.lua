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

require("libraries.utils.vector2")

require("libraries.addon.components.tags")
require("libraries.addon.script.debugging")
require("libraries.addon.script.matrix")
require("libraries.addon.vehicles.ai")

--require("libraries.icm.spawnModifiers")

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

-- library name
Pathfinding = {}

--[[


	Constants


]]

-- Increment the distance by 5m each time.
PATHFINDING_NUDGE_DISTANCE_INCREMENT = 5

-- The max nudge distance until we increment the angle again.
PATHFINDING_NUDGE_DISTANCE_MAX = 30

-- Increment angle by a quarter pi (45 degrees) each time, when the nudge distance is reached.
PATHFINDING_NUDGE_ANGLE_INCREMENT = math.pi/4

-- Increment the angle until we reach the max angle. (360 degrees)
PATHFINDING_NUDGE_ANGLE_MAX = math.tau

-- The maximum number of nodes in path until it stops trying to add more, to avoid infinite recursion.
PATHFINDING_MAX_NODES = 700

-- The distance the final path has to be to either the x or z tile border in order to try to start nudging.
PATHFINDING_START_NUDGING_DISTANCE = 30

--[[


	Variables
   

]]

--[[


	Classes


]]

---@class PathNode
---@field x integer the x coordinate of the path node
---@field y integer the y coordinate of the path node
---@field z integer the z coordinate of the path node
---@field ui_id SWUI_ID the ui id of the path node for debug
---@field consumption_distance number the consumption distance for the path node.

--- The path to follow, starting from the end and to the beginning,<br>the last node [#path] is always the destination, [1] is the node we're currently going to, and [0] is the previous one.
---@alias Path table<integer, PathNode>

---@enum YPathfinderNodeDataNSO
---| '0' # the node is not specific to vanilla or NSO
---| '1' # the node is specific for NSO
---| '2' # the node is specific for vanilla


---@class YPathfinderNodeData
---@field y number the y coordinate of the node
---@field type "land_path"|"ocean_path"	the type of the node
---@field NSO YPathfinderNodeDataNSO if the node is for NSO or not
---@field cdm number the consumption distance multiplier for the node. Short formed, to try to keep the save file size a bit lower.

--[[


	Functions


]]

--[[

	Internal Usage

]]

-- Get the distance to the closest tile border
---@param vector Vector2 the vector2 to get the distance to the closest tile border from
---@return number distance the distance to the closest tile border
function Pathfinding.distanceToClosestTileBorder(vector)

	--* Tiles are 1000m by 1000m, so we can just get the distance to the closest tile border by getting the distance to the closest 500m by 500m border.

	-- Get the x distance
	local x_distance = math.abs((vector.x-250)%1000-250)

	-- Get the z distance
	local z_distance = math.abs((vector.y-250)%1000-250)

	return math.min(x_distance, z_distance)
end

-- Get the angle between the two nodes
---@param node1 PathNode the first node
---@param node2 PathNode the second node
---@return number angle the angle between the two nodes
function angleBetweenNodes(node1, node2)
	-- Get the vector2 of the first node
	local node1_vector = Vector2.new(node1.x, node1.z)

	-- Get the vector2 of the second node
	local node2_vector = Vector2.new(node2.x, node2.z)

	-- Get the angle between the two nodes
	return Vector2.angleBetween(node1_vector, node2_vector)
end

--- Returns if two pathfind nodes are the same
---@param node1 PathNode the first node
---@param node2 PathNode the second node
---@return boolean is_same if the two nodes are the same
function isPathNodeEqual(node1, node2)
	-- if x is different, return false
	if node1.x ~= node2.x then
		return false
	-- if y is different, return false
	elseif node1.y ~= node2.y then
		return false
	-- if z is different, return false
	elseif node1.z ~= node2.z then
		return false
	-- if ui_id is different, return false
	elseif node1.ui_id ~= node2.ui_id then
		return false
	end

	-- otherwise, return true, they are the same
	return true
end

--- Converts a SW node into a PathNode
---@param sw_node SWPathFindPoint the SW node to turn into a PathNode
---@param base_consume_distance number the base consume distance for the path.
---@return PathNode path_node the path node
function pathNodeFromSWNode(sw_node, base_consume_distance)

	-- If the node is missing the y and/or cdm fields, then print an error.
	---@diagnostic disable-next-line: undefined-field
	if not sw_node.y or not sw_node.cdm then
		d.print(("<line>: the given sw_node is missing the y and/or cdm fields!\nx: %s\nz: %s"):format(sw_node.x, sw_node.z), true, 1)
	end

	return {
		x = sw_node.x,
		---@diagnostic disable-next-line: undefined-field
		y = sw_node.y or 0,
		z = sw_node.z,
		ui_id = server.getMapID(),
		---@diagnostic disable-next-line: undefined-field
		consumption_distance = base_consume_distance * (sw_node.cdm or 1)
	}
end

--- Converts a Matrix into a PathNode
---@param matrix_transform SWMatrix the Matrix to turn into a PathNode
---@param base_consume_distance number the base consume distance for the path.
---@return PathNode path_node the path node
function pathNodeFromMatrix(matrix_transform, base_consume_distance)
	return {
		x = matrix_transform[13],
		y = matrix_transform[14],
		z = matrix_transform[15],
		ui_id = server.getMapID(),
		consumption_distance = base_consume_distance
	}
end

--- Converts a node list returned by the modified server.pathfind or modified server.pathfindOcean into a Path.
---@param node_list table the node list returned by the modified server.pathfind or modified server.pathfindOcean
---@return Path path the path
function getPathFromNodeList(node_list, base_consume_distance)
	-- Define the path
	---@type Path
	local path = {}

	-- Iterate through each node in the node list.
	for node_index = 1, #node_list do
		-- Convert it to a PathNode and add it to the path.
		table.insert(path, pathNodeFromSWNode(node_list[node_index], base_consume_distance))
	end

	-- Return the path
	return path
end

--- Merges two paths together, putting the second path after the first path.<br><h3>NOTE: This function may also modify the original given path1, but this is not accounted for to save on performance.</h3>
---@param path1 Path the first path (the path to be put first)
---@param path2 Path the second path (the pathto be put after the first path)
---@return Path path the merged path
function mergePaths(path1, path2)

	-- for each node in path2, add it to the end of path1
	for node_index = 1, #path2 do
		table.insert(path1, path2[node_index])
	end

	-- return the merged path
	return path1
end

-- Get the pathfinding exclusion tags
---@return string exclude the pathfinding exclusion tags
function getPathfindingExclusionTags()
	-- define the exclude variable
	local exclude = ""

	-- if NSO is enabled, then exclude vanilla only graph nodes.
	if g_savedata.info.mods.NSO then
		exclude = "not_NSO"
	-- otherwise, exclude NSO only graph nodes.
	else
		exclude = "NSO"
	end

	-- return exclusion tags
	return exclude
end

--- More reliable pathfinding, that will nudge the pathfinding start position incrementing bit by bit in each direction if the end position is near a tile border<br> as sometimes, it will be unable to pass through the tile borders normally.
---@param matrix_start SWMatrix the start position of the path
---@param matrix_end SWMatrix the end position of the path
---@param required_tags string the tags that the path must have
---@param avoided_tags string the tags that the path must not have
---@param base_consume_distance number the base consume distance for the path.
---@param previous_path_count integer? the number of nodes in the previous "parent" path, used by the function itself, leave undefined.
---@return Path path the path, trying to avoid being stuck on tile borders.
function nudgePathfind(matrix_start, matrix_end, required_tags, avoided_tags, base_consume_distance, previous_path_count)

	-- default previous_path_count to 0
	previous_path_count = previous_path_count or 0

	-- Define the path
	---@type Path
	local path = {
		pathNodeFromMatrix(matrix_start, base_consume_distance)
	}

	--- Function to finalise the path, by adding the matrix_end to the end of the path.
	---@param path Path the path to finalise
	---@return Path path the finalised path
	local function finalisePath(path)
		-- Add the matrix_end to the end of the path
		table.insert(path, pathNodeFromMatrix(matrix_end, base_consume_distance))

		-- Return the finalised path
		return path
	end
	
	--- Function to check if we should nudge the pathfinding again, this checks if it's possible that we're stuck on the tile border.
	---@param check_path Path the path to check if we should nudge.
	---@return boolean should_nudge if we should nudge the pathfinding again.
	local function shouldNudge(check_path)
		-- Get the number of nodes
		local node_count = #check_path

		--- Return false if we're over the 5000 node limit
		if node_count + previous_path_count >= PATHFINDING_MAX_NODES then
			return false
		end

		-- Get the last node.
		local last_node = check_path[node_count]

		-- Get a vector2 of the last node
		local last_node_vector = Vector2.new(last_node.x, last_node.z)

		-- Get the distance to the closest tile border
		local distance_to_closest_tile_border = Pathfinding.distanceToClosestTileBorder(last_node_vector)

		-- If we're within the start nudge distance, then we should nudge.
		if distance_to_closest_tile_border <= PATHFINDING_START_NUDGING_DISTANCE then
			return true
		end

		-- Otherwise, we do not need to nudge.
		return false
	end

	-- Get the inital path
	local initial_path = server.pathfind(matrix_start, matrix_end, required_tags, avoided_tags)

	-- Merge the initial path with the path
	path = mergePaths(path, getPathFromNodeList(initial_path, base_consume_distance))

	d.print(("Node Count: %s"):format(#path + previous_path_count), true, 0)

	-- Check if we do not need to nudge, if we don't need to, then just return early.
	if not shouldNudge(path) then
		-- finalise the path
		return finalisePath(path)
	end

	--- Function to get the path from the nudging operation, as a function, so we can just return to exit the loop completely.
	---@return Path path the path from the nudging operation
	local function startNudging()
		-- Get the number of nodes in the path
		local node_count = #path

		-- Get the last node
		local last_node = path[node_count]

		-- Get the angle from the second last node to the last node
		local starting_angle = angleBetweenNodes(path[node_count-1], last_node)

		-- Get the vector 2 of the last node
		local last_node_vector = Vector2.new(last_node.x, last_node.z)

		-- Iterate through each angle, starting at the starting_angle from the above calculation, and then until we hit the limit + starting_angle from above, and incrementing by the angle increment.
		for nudge_angle = starting_angle, PATHFINDING_NUDGE_ANGLE_MAX + starting_angle, PATHFINDING_NUDGE_ANGLE_INCREMENT do

			-- Iterate through each distance, starting at the increment, until we hit the limit, and incrementing by the distance increment.
			for nudge_distance = PATHFINDING_NUDGE_DISTANCE_INCREMENT, PATHFINDING_NUDGE_DISTANCE_MAX, PATHFINDING_NUDGE_DISTANCE_INCREMENT do

				-- Draw blue triangle at the nudge position
				Map.addMapCircle(
					-1,
					server.getMapID(),
					matrix.translation(
						last_node_vector.x + nudge_distance * math.sin(nudge_angle),
						last_node.y,
						last_node_vector.y + nudge_distance * math.cos(nudge_angle)
					),
					5,
					1,
					0,
					25,
					255,
					255,
					3
				)
				
				-- Get the vector from the polar coordinates using the nudge_distance and nudge_angle
				local nudge_vector = Vector2.fromPolar(nudge_distance, nudge_angle)

				-- Add the nudge vector to the last node vector
				local nudged_last_node_vector = Vector2.add(last_node_vector, nudge_vector)

				-- Create the matrix for the nudged last node
				local nudged_new_start_matrix = matrix.translation(
					nudged_last_node_vector.x,
					last_node.y,
					nudged_last_node_vector.y
				)

				-- Get the path from the nudged last node
				local nudged_node_list = server.pathfind(nudged_new_start_matrix, matrix_end, required_tags, avoided_tags)

				-- Convert the node list into a path
				local nudged_path = getPathFromNodeList(nudged_node_list, base_consume_distance)

				--[[
					If the last node of the nudged path is the same as the last node of the current path, 
					then continue to the next iteration, as we've not moved past the tile border.
				]]
				if isPathNodeEqual(nudged_path[#nudged_path], last_node) then
					goto continue
				end

				--[[
					We've found a path with a different last node, so we can merge the paths together, and then return the path, but before we do, 
					send the path to nudgePathfind again, to check if it's now stuck on a tile border in another area.
				]]

				-- Merge the paths together
				path = mergePaths(path, nudged_path)

				--[[
					return the path after we check it again for nudging
				]]

				--* "do end" required to avoid it yelling that it expected EOF :)
				do
					return mergePaths(
						path,
						-- nudge the pathfinding again, and return the result, as we want to make sure we did not get stuck on another tile border.
						nudgePathfind(
							matrix.translation( -- Set the start matrix as our last matrix.
								nudged_path[#nudged_path].x,
								nudged_path[#nudged_path].y,
								nudged_path[#nudged_path].z
							),
							matrix_end,
							required_tags,
							avoided_tags,
							base_consume_distance,
							#path + previous_path_count
						)
					)
				end

				::continue::
			end
		end

		-- Just in case if we somehow get here, return an empty table.
		return {}
	end

	--[[
		Otherwise, we need to nudge, so start nudging, and return the result after finalising it.
	]]
	return finalisePath(startNudging())
end

--[[

	External Usage

]]

--- Gets the path for a land vehicle
---@param origin SWMatrix the origin, start position of the path
---@param destination SWMatrix the destination, end position of the path
---@param base_consume_distance number the base consumption distance for the path.
---@return Path path
function Pathfinding.getLandPath(origin, destination, base_consume_distance)
	-- get the tags to exclude
	local exclude = getPathfindingExclusionTags()

	-- Set the inclusion tag to "land_path"
	local include = "land_path"

	-- Get the path
	local path = nudgePathfind(origin, destination, include, exclude, base_consume_distance)

	-- Return the path
	return path
end

-- ---@param vehicle_object vehicle_object the vehicle you want to add the path for
-- ---@param target_dest SWMatrix the destination for the path
-- ---@param translate_forward_distance number? the increment of the distance, used to slowly try moving the vehicle's matrix forwards, if its at a tile's boundery, and its unable to move, used by the function itself, leave undefined.
-- function Pathfinding.addPath(vehicle_object, target_dest, translate_forward_distance)

-- 	-- path tags to exclude
-- 	local exclude = ""

-- 	if g_savedata.info.mods.NSO then
-- 		exclude = "not_NSO" -- exclude non NSO graph nodes
-- 	else
-- 		exclude = "NSO" -- exclude NSO graph nodes
-- 	end

-- 	if vehicle_object.vehicle_type == VEHICLE.TYPE.TURRET then 
-- 		AI.setState(vehicle_object, VEHICLE.STATE.STATIONARY)
-- 		return

-- 	elseif vehicle_object.vehicle_type == VEHICLE.TYPE.BOAT then
-- 		local dest_x, dest_y, dest_z = matrix.position(target_dest)

-- 		local path_start_pos = nil

-- 		if #vehicle_object.path > 0 then
-- 			local waypoint_end = vehicle_object.path[#vehicle_object.path]
-- 			path_start_pos = matrix.translation(waypoint_end.x, waypoint_end.y, waypoint_end.z)
-- 		else
-- 			path_start_pos = vehicle_object.transform
-- 		end

-- 		-- makes sure only small ships can take the tight areas
		
-- 		if vehicle_object.size ~= "small" then
-- 			exclude = exclude..",tight_area"
-- 		end

-- 		-- calculates route
-- 		local path_list = server.pathfind(path_start_pos, matrix.translation(target_dest[13], 0, target_dest[15]), "ocean_path", exclude)

-- 		for _, path in pairs(path_list) do
-- 			if not path.y then
-- 				path.y = 0
-- 			end
-- 			if path.y > 1 then
-- 				break
-- 			end 
-- 			table.insert(vehicle_object.path, { 
-- 				x = path.x,
-- 				y = path.y,
-- 				z = path.z,
-- 				ui_id = server.getMapID()
-- 			})
-- 		end
-- 	elseif vehicle_object.vehicle_type == VEHICLE.TYPE.LAND then
-- 		--local dest_x, dest_y, dest_z = m.position(target_dest)

-- 		local path_start_pos = nil

-- 		if #vehicle_object.path > 0 then
-- 			local waypoint_end = vehicle_object.path[#vehicle_object.path]

-- 			if translate_forward_distance then
-- 				local second_last_path_pos
-- 				if #vehicle_object.path < 2 then
-- 					second_last_path_pos = vehicle_object.transform
-- 				else
-- 					local second_last_path = vehicle_object.path[#vehicle_object.path - 1]
-- 					second_last_path_pos = matrix.translation(second_last_path.x, second_last_path.y, second_last_path.z)
-- 				end

-- 				local yaw, _ = math.angleToFace(second_last_path_pos[13], waypoint_end.x, second_last_path_pos[15], waypoint_end.z)

-- 				path_start_pos = matrix.translation(waypoint_end.x + translate_forward_distance * math.sin(yaw), waypoint_end.y, waypoint_end.z + translate_forward_distance * math.cos(yaw))
			
-- 				--[[server.addMapLine(-1, vehicle_object.ui_id, m.translation(waypoint_end.x, waypoint_end.y, waypoint_end.z), path_start_pos, 1, 255, 255, 255, 255)
			
-- 				d.print("path_start_pos (existing paths)", false, 0)
-- 				d.print(path_start_pos)]]
-- 			else
-- 				path_start_pos = matrix.translation(waypoint_end.x, waypoint_end.y, waypoint_end.z)
-- 			end
-- 		else
-- 			path_start_pos = vehicle_object.transform

-- 			if translate_forward_distance then
-- 				path_start_pos = matrix.multiply(vehicle_object.transform, matrix.translation(0, 0, translate_forward_distance))
-- 				--[[server.addMapLine(-1, vehicle_object.ui_id, vehicle_object.transform, path_start_pos, 1, 150, 150, 150, 255)
-- 				d.print("path_start_pos (no existing paths)", false, 0)
-- 				d.print(path_start_pos)]]
-- 			else
-- 				path_start_pos = vehicle_object.transform
-- 			end
-- 		end

-- 		start_x, start_y, start_z = m.position(vehicle_object.transform)

-- 		local exclude_offroad = false

-- 		local squad_index, squad = Squad.getSquad(vehicle_object.id)
-- 		if squad.command == SQUAD.COMMAND.CARGO then
-- 			for c_vehicle_id, c_vehicle_object in pairs(squad.vehicles) do
-- 				if g_savedata.cargo_vehicles[c_vehicle_id] then
-- 					exclude_offroad = not g_savedata.cargo_vehicles[c_vehicle_id].route_data.can_offroad
-- 					break
-- 				end
-- 			end
-- 		end

-- 		if not vehicle_object.can_offroad or exclude_offroad then
-- 			exclude = exclude..",offroad"
-- 		end

-- 		local vehicle_list_id = sm.getVehicleListID(vehicle_object.name)
-- 		local y_modifier = g_savedata.vehicle_list[vehicle_list_id].vehicle.transform[14]

-- 		local dest_at_vehicle_y = matrix.translation(target_dest[13], vehicle_object.transform[14], target_dest[15])

-- 		local path_list = server.pathfind(path_start_pos, dest_at_vehicle_y, "land_path", exclude)
-- 		for path_index, path in pairs(path_list) do

-- 			local path_matrix = matrix.translation(path.x, path.y, path.z)

-- 			local distance = matrix.distance(vehicle_object.transform, path_matrix)

-- 			if path_index ~= 1 or #path_list == 1 or matrix.distance(vehicle_object.transform, dest_at_vehicle_y) > matrix.distance(dest_at_vehicle_y, path_matrix) and distance >= 7 then
				
-- 				if not path.y then
-- 					--d.print("not path.y\npath.x: "..tostring(path.x).."\npath.y: "..tostring(path.y).."\npath.z: "..tostring(path.z), true, 1)
-- 					break
-- 				end

-- 				table.insert(vehicle_object.path, { 
-- 					x =  path.x, 
-- 					y = (path.y + y_modifier), 
-- 					z = path.z, 
-- 					ui_id = server.getMapID() 
-- 				})
-- 			end
-- 		end

-- 		if #vehicle_object.path > 1 then
-- 			-- remove paths which are a waste (eg, makes the vehicle needlessly go backwards when it could just go to the next waypoint)
-- 			local next_path_matrix = matrix.translation(vehicle_object.path[2].x, vehicle_object.path[2].y, vehicle_object.path[2].z)
-- 			if matrix.xzDistance(vehicle_object.transform, next_path_matrix) < matrix.xzDistance(matrix.translation(vehicle_object.path[1].x, vehicle_object.path[1].y, vehicle_object.path[1].z), next_path_matrix) then
-- 				p.nextPath(vehicle_object)
-- 			end
-- 		end

-- 		--[[
-- 			checks if the vehicle is basically stuck, and if its at a tile border, if it is, 
-- 			try moving matrix forwards slightly, and keep trying till we've got a path, 
-- 			or until we reach a set max distance, to avoid infinite recursion.
-- 		]]

-- 		local max_attempt_distance = 30
-- 		local max_attempt_increment = 5

-- 		translate_forward_distance = translate_forward_distance or 0

-- 		if translate_forward_distance < max_attempt_distance then
-- 			local last_path = vehicle_object.path[#vehicle_object.path]

-- 			-- if theres no last path, just set it as the vehicle's positon.
-- 			if not last_path then
-- 				last_path = {
-- 					x = vehicle_object.transform[13],
-- 					z = vehicle_object.transform[15]
-- 				}
-- 			end

-- 			-- checks if we're within the max_attempt_distance of any tile border
-- 			local tile_x_border_distance = math.abs((last_path.x-250)%1000-250)
-- 			local tile_z_border_distance = math.abs((last_path.z-250)%1000-250)

-- 			if tile_x_border_distance <= max_attempt_distance or tile_z_border_distance <= max_attempt_distance then
-- 				-- increments the translate_forward_distance
-- 				translate_forward_distance = translate_forward_distance + max_attempt_increment

-- 				d.print(("(Pathfinding.addPath) moving the pathfinding start pos forwards by %sm"):format(translate_forward_distance), true, 0)

-- 				Pathfinding.addPath(vehicle_object, target_dest, translate_forward_distance)
-- 			end
-- 		else
-- 			d.print(("(Pathfinding.addPath) despite moving the pathfinding start pos forward by %sm, pathfinding still failed for vehicle with id %s, aborting to avoid infinite recursion"):format(translate_forward_distance, vehicle_object.id), true, 0)
-- 		end
-- 	else
-- 		table.insert(vehicle_object.path, { 
-- 			x = target_dest[13], 
-- 			y = target_dest[14], 
-- 			z = target_dest[15], 
-- 			ui_id = server.getMapID() 
-- 		})
-- 	end
-- 	vehicle_object.path[0] = {
-- 		x = vehicle_object.transform[13],
-- 		y = vehicle_object.transform[14],
-- 		z = vehicle_object.transform[15],
-- 		ui_id = server.getMapID()
-- 	}

-- 	AI.setState(vehicle_object, VEHICLE.STATE.PATHING)
-- end

-- Credit to woe
function Pathfinding.updatePathfinding()
	local old_pathfind = server.pathfind --temporarily remember what the old function did
	local old_pathfindOcean = server.pathfindOcean
	function server.pathfind(matrix_start, matrix_end, required_tags, avoided_tags) --permanantly do this new function using the old name.
		local path = old_pathfind(matrix_start, matrix_end, required_tags, avoided_tags) --do the normal old function
		--d.print("(updatePathfinding) getting path y", true, 0)
		return Pathfinding.getPathY(path) --add y to all of the paths.
	end
	function server.pathfindOcean(matrix_start, matrix_end)
		local path = old_pathfindOcean(matrix_start, matrix_end)
		return Pathfinding.getPathY(path)
	end
end

local node_decimal_places = 0

-- Credit to woe
function Pathfinding.getPathY(path)
	if not g_savedata.graph_nodes.init then --if it has never built the node's table
		Pathfinding.createPathY() --build the table this one time
		g_savedata.graph_nodes.init = true --never build the table again unless you run traverse() manually
	end
	for each in pairs(path) do

		local x = math.round(path[each].x, node_decimal_places)
		local z = math.round(path[each].z, node_decimal_places)

		if g_savedata.graph_nodes.nodes[x] and g_savedata.graph_nodes.nodes[x][z] then --if y exists
			path[each].y = g_savedata.graph_nodes.nodes[x][z].y --add it to the table that already contains x and z
			--d.print("path["..each.."].y: "..tostring(path[each].y), true, 0)
			path[each].cdm = g_savedata.graph_nodes.nodes[x][z].cdm
		end
	end
	return path --return the path with the added, or not, y values.
end

-- Credit to woe
function Pathfinding.createPathY() --this looks through all env mods to see if there is a "zone" then makes a table of y values based on x and z as keys.

	local isGraphNode = function(tag)
		if tag == "land_path" or tag == "ocean_path" then
			return tag
		end
		return false
	end

	-- indexed by name, this is so we dont have to constantly call server.getTileTransform for the same tiles. 
	local tile_locations = {}

	local start_time = server.getTimeMillisec()
	d.print("Creating Path Y...", true, 0)
	local total_paths = 0
	local empty_matrix = matrix.translation(0, 0, 0)
	for addon_index = 0, server.getAddonCount() - 1 do
		local ADDON_DATA = server.getAddonData(addon_index)
		if ADDON_DATA.location_count and ADDON_DATA.location_count > 0 then
			for location_index = 0, ADDON_DATA.location_count - 1 do
				local LOCATION_DATA = server.getLocationData(addon_index, location_index)
				if LOCATION_DATA.env_mod and LOCATION_DATA.component_count > 0 then
					for component_index = 0, LOCATION_DATA.component_count - 1 do
						local COMPONENT_DATA = server.getLocationComponentData(
							addon_index, location_index, component_index
						)
						if COMPONENT_DATA.type == "zone" then
							local graph_node = isGraphNode(COMPONENT_DATA.tags[1])
							if graph_node then

								local transform_matrix = tile_locations[LOCATION_DATA.tile]
								if not transform_matrix then
									tile_locations[LOCATION_DATA.tile] = server.getTileTransform(
										empty_matrix,
										LOCATION_DATA.tile,
										100000
									)

									transform_matrix = tile_locations[LOCATION_DATA.tile]
								end

								if transform_matrix then
									local real_transform = matrix.multiplyXZ(COMPONENT_DATA.transform, transform_matrix)
									local x = math.round(real_transform[13], node_decimal_places)
									local last_tag = COMPONENT_DATA.tags[#COMPONENT_DATA.tags]
									g_savedata.graph_nodes.nodes[x] = g_savedata.graph_nodes.nodes[x] or {}
									g_savedata.graph_nodes.nodes[x][math.round(real_transform[15], node_decimal_places)] = {
										y = real_transform[14],
										type = graph_node,
										NSO = last_tag == "NSO" and 1 or last_tag == "not_NSO" and 2 or 0 --[[@as YPathfinderNodeDataNSO]],
										cdm = Tags.getValue(COMPONENT_DATA.tags, "consume_distance_multiplier", false) --[[@as number]] or 1
									}
									total_paths = total_paths + 1
								end
							end
						end
					end
				end
			end
		end
	end
	d.print("Got Y level of all paths\nNumber of nodes: "..total_paths.."\nTime taken: "..(millisecondsSince(start_time)/1000).."s", true, 0)
end

-- function Pathfinding.resetPath(vehicle_object)
-- 	for _, v in pairs(vehicle_object.path) do
-- 		server.removeMapID(-1, v.ui_id)
-- 	end

-- 	vehicle_object.path = {}
-- end

-- -- makes the vehicle go to its next path
-- ---@param vehicle_object vehicle_object the vehicle object which is going to its next path
-- ---@return number|nil more_paths the number of paths left, nil if error
-- ---@return boolean is_success if it successfully went to the next path
-- function Pathfinding.nextPath(vehicle_object)

-- 	--? makes sure vehicle_object is not nil
-- 	if not vehicle_object then
-- 		d.print("(Vehicle.nextPath) vehicle_object is nil!", true, 1)
-- 		return nil, false
-- 	end

-- 	--? makes sure the vehicle_object has paths
-- 	if not vehicle_object.path then
-- 		d.print("(Vehicle.nextPath) vehicle_object.path is nil! vehicle_id: "..tostring(vehicle_object.id), true, 1)
-- 		return nil, false
-- 	end

-- 	if vehicle_object.path[1] then
-- 		if vehicle_object.path[0] then
-- 			server.removeMapID(-1, vehicle_object.path[0].ui_id)
-- 		end
-- 		vehicle_object.path[0] = {
-- 			x = vehicle_object.path[1].x,
-- 			y = vehicle_object.path[1].y,
-- 			z = vehicle_object.path[1].z,
-- 			ui_id = vehicle_object.path[1].ui_id
-- 		}
-- 		table.remove(vehicle_object.path, 1)
-- 	end

-- 	return #vehicle_object.path, true
-- end