--[[


	Library Setup


]]


-- required libraries
require("libraries.addon.components.tags")
require("libraries.addon.script.debugging")
require("libraries.addon.script.matrix")
require("libraries.addon.vehicles.ai")

--require("libraries.icm.spawnModifiers")

-- library name
Pathfinding = {}

-- shortened library name
p = Pathfinding

--[[


	Variables
   

]]

s = s or server

--[[


	Classes


]]

---@class ICMPathfindPoint
---@field x number the x coordinate of the graph node
---@field y number the y coordinate of the graph node
---@field z number the z coordinate of the graph node

--[[


	Functions         


]]

function Pathfinding.resetPath(vehicle_object)
	for _, v in pairs(vehicle_object.path) do
		server.removeMapID(-1, v.ui_id)
	end

	vehicle_object.path = {}
end

-- makes the vehicle go to its next path
---@param vehicle_object vehicle_object the vehicle object which is going to its next path
---@return number|nil more_paths the number of paths left, nil if error
---@return boolean is_success if it successfully went to the next path
function Pathfinding.nextPath(vehicle_object)

	--? makes sure vehicle_object is not nil
	if not vehicle_object then
		d.print("(Vehicle.nextPath) vehicle_object is nil!", true, 1)
		return nil, false
	end

	--? makes sure the vehicle_object has paths
	if not vehicle_object.path then
		d.print("(Vehicle.nextPath) vehicle_object.path is nil! vehicle_id: "..tostring(vehicle_object.id), true, 1)
		return nil, false
	end

	if vehicle_object.path[1] then
		if vehicle_object.path[0] then
			server.removeMapID(-1, vehicle_object.path[0].ui_id)
		end
		vehicle_object.path[0] = {
			x = vehicle_object.path[1].x,
			y = vehicle_object.path[1].y,
			z = vehicle_object.path[1].z,
			ui_id = vehicle_object.path[1].ui_id
		}
		table.remove(vehicle_object.path, 1)
	end

	return #vehicle_object.path, true
end

---@param vehicle_object vehicle_object the vehicle you want to add the path for
---@param target_dest SWMatrix the destination for the path
---@param translate_forward_distance number? the increment of the distance, used to slowly try moving the vehicle's matrix forwards, if its at a tile's boundery, and its unable to move, used by the function itself, leave undefined.
function Pathfinding.addPath(vehicle_object, target_dest, translate_forward_distance)

	-- path tags to exclude
	local exclude = ""

	if g_savedata.info.mods.NSO then
		exclude = "not_NSO" -- exclude non NSO graph nodes
	else
		exclude = "NSO" -- exclude NSO graph nodes
	end

	if vehicle_object.vehicle_type == VEHICLE.TYPE.TURRET then 
		AI.setState(vehicle_object, VEHICLE.STATE.STATIONARY)
		return

	elseif vehicle_object.vehicle_type == VEHICLE.TYPE.BOAT then
		local dest_x, dest_y, dest_z = matrix.position(target_dest)

		local path_start_pos = nil

		if #vehicle_object.path > 0 then
			local waypoint_end = vehicle_object.path[#vehicle_object.path]
			path_start_pos = matrix.translation(waypoint_end.x, waypoint_end.y, waypoint_end.z)
		else
			path_start_pos = vehicle_object.transform
		end

		-- makes sure only small ships can take the tight areas
		
		if vehicle_object.size ~= "small" then
			exclude = exclude..",tight_area"
		end

		-- calculates route
		local path_list = server.pathfind(path_start_pos, matrix.translation(target_dest[13], 0, target_dest[15]), "ocean_path", exclude)

		for _, path in pairs(path_list) do
			if not path.y then
				path.y = 0
			end
			if path.y > 1 then
				break
			end 
			table.insert(vehicle_object.path, { 
				x = path.x,
				y = path.y,
				z = path.z,
				ui_id = server.getMapID() 
			})
		end
	elseif vehicle_object.vehicle_type == VEHICLE.TYPE.LAND then
		--local dest_x, dest_y, dest_z = m.position(target_dest)

		local path_start_pos = nil

		if #vehicle_object.path > 0 then
			local waypoint_end = vehicle_object.path[#vehicle_object.path]

			if translate_forward_distance then
				local second_last_path_pos
				if #vehicle_object.path < 2 then
					second_last_path_pos = vehicle_object.transform
				else
					local second_last_path = vehicle_object.path[#vehicle_object.path - 1]
					second_last_path_pos = matrix.translation(second_last_path.x, second_last_path.y, second_last_path.z)
				end

				local yaw, _ = math.angleToFace(second_last_path_pos[13], waypoint_end.x, second_last_path_pos[15], waypoint_end.z)

				path_start_pos = matrix.translation(waypoint_end.x + translate_forward_distance * math.sin(yaw), waypoint_end.y, waypoint_end.z + translate_forward_distance * math.cos(yaw))
			
				--[[server.addMapLine(-1, vehicle_object.ui_id, m.translation(waypoint_end.x, waypoint_end.y, waypoint_end.z), path_start_pos, 1, 255, 255, 255, 255)
			
				d.print("path_start_pos (existing paths)", false, 0)
				d.print(path_start_pos)]]
			else
				path_start_pos = matrix.translation(waypoint_end.x, waypoint_end.y, waypoint_end.z)
			end
		else
			path_start_pos = vehicle_object.transform

			if translate_forward_distance then
				path_start_pos = matrix.multiply(vehicle_object.transform, matrix.translation(0, 0, translate_forward_distance))
				--[[server.addMapLine(-1, vehicle_object.ui_id, vehicle_object.transform, path_start_pos, 1, 150, 150, 150, 255)
				d.print("path_start_pos (no existing paths)", false, 0)
				d.print(path_start_pos)]]
			else
				path_start_pos = vehicle_object.transform
			end
		end

		start_x, start_y, start_z = m.position(vehicle_object.transform)

		local exclude_offroad = false

		local squad_index, squad = Squad.getSquad(vehicle_object.id)
		if squad.command == SQUAD.COMMAND.CARGO then
			for c_vehicle_id, c_vehicle_object in pairs(squad.vehicles) do
				if g_savedata.cargo_vehicles[c_vehicle_id] then
					exclude_offroad = not g_savedata.cargo_vehicles[c_vehicle_id].route_data.can_offroad
					break
				end
			end
		end

		if not vehicle_object.can_offroad or exclude_offroad then
			exclude = exclude..",offroad"
		end

		local vehicle_list_id = sm.getVehicleListID(vehicle_object.name)
		local y_modifier = g_savedata.vehicle_list[vehicle_list_id].vehicle.transform[14]

		local dest_at_vehicle_y = matrix.translation(target_dest[13], vehicle_object.transform[14], target_dest[15])

		local path_list = server.pathfind(path_start_pos, dest_at_vehicle_y, "land_path", exclude)
		for path_index, path in pairs(path_list) do

			local path_matrix = matrix.translation(path.x, path.y, path.z)

			local distance = matrix.distance(vehicle_object.transform, path_matrix)

			if path_index ~= 1 or #path_list == 1 or matrix.distance(vehicle_object.transform, dest_at_vehicle_y) > matrix.distance(dest_at_vehicle_y, path_matrix) and distance >= 7 then
				
				if not path.y then
					--d.print("not path.y\npath.x: "..tostring(path.x).."\npath.y: "..tostring(path.y).."\npath.z: "..tostring(path.z), true, 1)
					break
				end

				table.insert(vehicle_object.path, { 
					x =  path.x, 
					y = (path.y + y_modifier), 
					z = path.z, 
					ui_id = server.getMapID() 
				})
			end
		end

		if #vehicle_object.path > 1 then
			-- remove paths which are a waste (eg, makes the vehicle needlessly go backwards when it could just go to the next waypoint)
			local next_path_matrix = matrix.translation(vehicle_object.path[2].x, vehicle_object.path[2].y, vehicle_object.path[2].z)
			if matrix.xzDistance(vehicle_object.transform, next_path_matrix) < matrix.xzDistance(matrix.translation(vehicle_object.path[1].x, vehicle_object.path[1].y, vehicle_object.path[1].z), next_path_matrix) then
				p.nextPath(vehicle_object)
			end
		end

		--[[
			checks if the vehicle is basically stuck, and if its at a tile border, if it is, 
			try moving matrix forwards slightly, and keep trying till we've got a path, 
			or until we reach a set max distance, to avoid infinite recursion.
		]]

		local max_attempt_distance = 30
		local max_attempt_increment = 5

		translate_forward_distance = translate_forward_distance or 0

		if translate_forward_distance < max_attempt_distance then
			local last_path = vehicle_object.path[#vehicle_object.path]

			-- if theres no last path, just set it as the vehicle's positon.
			if not last_path then
				last_path = {
					x = vehicle_object.transform[13],
					z = vehicle_object.transform[15]
				}
			end

			-- checks if we're within the max_attempt_distance of any tile border
			local tile_x_border_distance = math.abs((last_path.x-250)%1000-250)
			local tile_z_border_distance = math.abs((last_path.z-250)%1000-250)

			if tile_x_border_distance <= max_attempt_distance or tile_z_border_distance <= max_attempt_distance then
				-- increments the translate_forward_distance
				translate_forward_distance = translate_forward_distance + max_attempt_increment

				d.print(("(Pathfinding.addPath) moving the pathfinding start pos forwards by %sm"):format(translate_forward_distance), true, 0)

				Pathfinding.addPath(vehicle_object, target_dest, translate_forward_distance)
			end
		else
			d.print(("(Pathfinding.addPath) despite moving the pathfinding start pos forward by %sm, pathfinding still failed for vehicle with id %s, aborting to avoid infinite recursion"):format(translate_forward_distance, vehicle_object.id), true, 0)
		end
	else
		table.insert(vehicle_object.path, { 
			x = target_dest[13], 
			y = target_dest[14], 
			z = target_dest[15], 
			ui_id = s.getMapID() 
		})
	end
	vehicle_object.path[0] = {
		x = vehicle_object.transform[13],
		y = vehicle_object.transform[14],
		z = vehicle_object.transform[15],
		ui_id = s.getMapID()
	}

	AI.setState(vehicle_object, VEHICLE.STATE.PATHING)
end

-- Credit to woe
function Pathfinding.updatePathfinding()
	local old_pathfind = server.pathfind --temporarily remember what the old function did
	local old_pathfindOcean = server.pathfindOcean
	function server.pathfind(matrix_start, matrix_end, required_tags, avoided_tags) --permanantly do this new function using the old name.
		local path = old_pathfind(matrix_start, matrix_end, required_tags, avoided_tags) --do the normal old function
		--d.print("(updatePathfinding) getting path y", true, 0)
		return p.getPathY(path) --add y to all of the paths.
	end
	function server.pathfindOcean(matrix_start, matrix_end)
		local path = old_pathfindOcean(matrix_start, matrix_end)
		return p.getPathY(path)
	end
end

local path_res = "%0.1f"

-- Credit to woe
function Pathfinding.getPathY(path)
	if not g_savedata.graph_nodes.init then --if it has never built the node's table
		p.createPathY() --build the table this one time
		g_savedata.graph_nodes.init = true --never build the table again unless you run traverse() manually
	end
	for each in pairs(path) do
		if g_savedata.graph_nodes.nodes[(path_res):format(path[each].x)] and g_savedata.graph_nodes.nodes[(path_res):format(path[each].x)][(path_res):format(path[each].z)] then --if y exists
			path[each].y = g_savedata.graph_nodes.nodes[(path_res):format(path[each].x)][(path_res):format(path[each].z)].y --add it to the table that already contains x and z
			--d.print("path["..each.."].y: "..tostring(path[each].y), true, 0)
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

	local start_time = s.getTimeMillisec()
	d.print("Creating Path Y...", true, 0)
	local total_paths = 0
	local empty_matrix = matrix.translation(0, 0, 0)
	for addon_index = 0, s.getAddonCount() - 1 do
		local ADDON_DATA = s.getAddonData(addon_index)
		if ADDON_DATA.location_count and ADDON_DATA.location_count > 0 then
			for location_index = 0, ADDON_DATA.location_count - 1 do
				local LOCATION_DATA = s.getLocationData(addon_index, location_index)
				if LOCATION_DATA.env_mod and LOCATION_DATA.component_count > 0 then
					for component_index = 0, LOCATION_DATA.component_count - 1 do
						local COMPONENT_DATA = s.getLocationComponentData(
							addon_index, location_index, component_index
						)
						if COMPONENT_DATA.type == "zone" then
							local graph_node = isGraphNode(COMPONENT_DATA.tags[1])
							if graph_node then

								local transform_matrix = tile_locations[LOCATION_DATA.tile]
								if not transform_matrix then
									tile_locations[LOCATION_DATA.tile] = s.getTileTransform(
										empty_matrix,
										LOCATION_DATA.tile,
										100000
									)

									transform_matrix = tile_locations[LOCATION_DATA.tile]
								end

								if transform_matrix then
									local real_transform = matrix.multiplyXZ(COMPONENT_DATA.transform, transform_matrix)
									local x = (path_res):format(real_transform[13])
									local last_tag = COMPONENT_DATA.tags[#COMPONENT_DATA.tags]
									g_savedata.graph_nodes.nodes[x] = g_savedata.graph_nodes.nodes[x] or {}
									g_savedata.graph_nodes.nodes[x][(path_res):format(real_transform[15])] = { 
										y = real_transform[14],
										type = graph_node,
										NSO = last_tag == "NSO" and 1 or last_tag == "not_NSO" and 2 or 0
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