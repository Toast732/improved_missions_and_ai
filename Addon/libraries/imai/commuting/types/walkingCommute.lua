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
require("libraries.imai.commuting.communting")

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[ 
	Walking Commute Definition.
]]

-- Register the walking commute type
Commuting.registerCommuteType(
	"Walking",
	true,
	function(citizen)
		return true
	end,
	function(citizen, origin, destination)
		-- Do a land pathfind between the two points.
		local route = LandRoute.new(
			Vector3.toMatrix(origin),
			Vector3.toMatrix(destination)
		)

		return route
	end,
	function(citizen, route)

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
	function(citizen, route)
		-- Get the path for this route
		local path = Routing.getPathFromID(route.stored_path_id)

		-- Make sure we got the path.
		if not path then
			d.print(("<line> Walking Commute (GetCost): No path found for route %s"):format(route.stored_path_id), true, 1)
			return math.maxinteger
		end

		-- Get the distance of the path
		local distance = Pathfinding.getTotalPathDistance(path)

		-- Get the walking cost of the citizen
		local walking_cost = 0.1

		-- Get the cost of this commute
		return distance * walking_cost
	end
)