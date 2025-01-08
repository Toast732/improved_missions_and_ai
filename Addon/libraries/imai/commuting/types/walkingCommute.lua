--[[
	
Copyright 2025 Liam Matthews

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
require("libraries.imai.commuting.communting")

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[ 
	Walking Commute Definition.
]]

-- Create the CommuteWalkingOptionData class.
---@class CommuteWalkingOptionData: CommuteBaseOptionData

-- Register the walking commute type
Commuting.registerCommuteType(
	"Walking",
	true,
	---@returns table<integer, CommuteWalkingOptionData>
	function(citizen_id, origin, destination)
		return {
			{
				citizen_id = citizen_id
			}
		}
	end,
	---@param options_data table<integer, CommuteWalkingOptionData>
	function(options_data)
		return #options_data > 0
	end,
	---@param option_data CommuteWalkingOptionData
	function(option_data, origin, destination)
		-- Do a land pathfind between the two points.
		local route = LandRoute.new(
			Vector3.toMatrix(origin),
			Vector3.toMatrix(destination)
		)

		return route
	end,
	---@param option_data CommuteWalkingOptionData
	function(option_data, route)

		-- Get the path for this route
		local path = Routing.getPathFromID(route.stored_path_id)

		-- Make sure we got the path.
		if not path then
			d.print(("<line> Walking Commute (GetCommuteTime): No path found for route %s"):format(route.stored_path_id), true, 1)
			return math.maxinteger
		end

		-- Get the distance of the path
		local distance = Pathfinding.getTotalPathDistance(path)

		-- Get the walking speed of the citizen (m/s)
		local walking_speed = 1.8

		-- Get the time it takes to walk this distance
		--TODO: Account for game time speed
		local time = distance / walking_speed

		-- Turn the time into a game timestamp
		return GameTimestamp.secondsToTimestamp(time)
	end,
	---@param option_data CommuteWalkingOptionData
	function(option_data, route)

		if option_data.cost then
			return option_data.cost
		end

		-- Get the path for this route
		local path = Routing.getPathFromID(route.stored_path_id)

		-- Make sure we got the path.
		if not path then
			d.print(("<line> Walking Commute (GetCost): No path found for route %s"):format(route.stored_path_id), true, 1)
			return math.maxinteger
		end

		-- Get the distance of the path
		local distance = Pathfinding.getTotalPathDistance(path)

		-- Get the walking cost of the citizen (per metre)
		local walking_cost = 0.1

		-- Update the cost.
		option_data.cost = distance * walking_cost

		-- Get the cost of this commute
		return option_data.cost
	end,
	---@param option_data CommuteWalkingOptionData
	function(option_data, route)

		-- Get the citizen
		local citizen = Citizens.getData(option_data.citizen_id)

		-- Ensure the citizen is not nil
		if not citizen then
			d.print(("<line>: Walking Commute (checkCompletion): Citizen %s not found"):format(option_data.citizen_id), true, 1)
			return true
		end

		return Vector3.euclideanDistance(
			Vector3.fromMatrix(citizen.transform, true),
			Vector3.fromMatrix(route.end_matrix, true)
		) < 1
	end,
	---@param option_data CommuteWalkingOptionData
	function(option_data, route, game_ticks)

		-- Get the citizen
		local citizen = Citizens.getData(option_data.citizen_id)

		-- Ensure the citizen is not nil
		if not citizen then
			d.print(("<line>: Walking Commute (getCost): Citizen %s not found"):format(option_data.citizen_id), true, 1)
			return
		end

		-- Calculate the maximum distance the citizen can move this tick.
		local distance_can_travel = 30.5 * (game_ticks/62.5)

		-- Get the path.
		local path = Routing.getPathFromID(route.stored_path_id)

		-- Check if we got the path.
		if not path then
			d.print(("<line>: Failed to get the path for citizen \"%s\""):format(citizen.name.full), false, 1)
			return
		end

		-- Set the last_pos to the transform of the citizen. This will be moved along the path.
		local last_position = Vector3.fromMatrix(citizen.transform, true)

		-- Iterate through the path.
		for path_index = route.path_index, #path.path_list do
			-- Get the node
			local node = path.path_list[path_index]

			-- Create a vector for the position of this node
			local node_position = Vector3.new(node.x, node.y, node.z)

			-- Calculate the distance from last_position to the node of this path, set to minimum 0.0001, to avoid division by 0.
			local distance_to_waypoint = math.max(Vector3.euclideanDistance(last_position, node_position), 0.0001)

			-- Get the progress the citizen can travel along this path.
			local progress = math.min(distance_can_travel / distance_to_waypoint, 1)

			--[[
				Set last pos to the position of the node if progress is 1

				Otherwise, travel along the path by progress.
			]]

			-- Remove how much we're travelling from the distance to the waypoint.
			distance_can_travel = distance_can_travel - distance_to_waypoint * progress
			
			-- Check if the progress is 1
			if progress == 1 then
				-- Set the last position to the node position.
				last_position = node_position

				-- Increment the path index the citizen is on.
				route.path_index = route.path_index + 1
				--d.print("moved to next node.")
			else
				-- Travel along the path by progress.
				last_position = Vector3.lerp(last_position, node_position, progress)

				-- Break, as we cannot move any more.
				--d.print("cannot move anymore!")
				break
			end
		end

		-- Set the citizen's transform to the new position.
		citizen.transform = Vector3.toMatrix(last_position)

		--d.print(("Citizen %s is now at %s"):format(citizen.name.full, string.fromTable(last_position)), false, 0)

		server.removeMapObject(-1, citizen.object_id + 14784)

		server.addMapObject(-1, citizen.object_id + 14784, 0, 1, citizen.transform[13], citizen.transform[15], 0, 0, 0, 0, citizen.name.full, 10, citizen.name.full, 255, 255, 255, 255)

		-- Set the citizen's object's position to the new position.
		is_success = server.setObjectPos(citizen.object_id, citizen.transform)
	end
)