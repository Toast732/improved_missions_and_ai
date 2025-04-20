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
	Driving Commute Definition.

	A driving commute is where this citizen drives from one location to another.
]]


-- Create the CommuteDrivingOptionData class.
---@class CommuteDrivingOptionData: CommuteBaseOptionData
---@field drivable_vehicle_id DrivableVehicleID The ID of the drivable vehicle the citizen will drive.

-- Register the driving commute type
Commuting.registerCommuteType(
	"Driving",
	false,
	---@returns table<integer, CommuteDrivingOptionData>
	function(citizen_id, origin, destination)

		-- Get the citizen
		local citizen = Citizens.getData(citizen_id)

		-- Ensure the citizen is not nil
		if not citizen then
			d.print(("<line>: Driving Commute (GetOptions): Citizen %s not found"):format(citizen_id), true, 1)
			return {}
		end

		-- Get the citizen's asset holder profile
		local asset_holder = citizen:getAssetHolder()

		-- Get the drivable vehicle assets the citizen can access.
		local drivable_vehicle_assets = asset_holder:getHeldAssetsOfType(ASSET_TYPE.DRIVABLE_VEHICLE)

		--TODO Go through each, and check if they're available at this time

		--TODO Filter out ones unreasonable (eg: is at the destination, so no reason to drive, though, this might be better to handle elsewhere)

		-- Create the options data
		local options_data = {} ---@type table<integer, CommuteDrivingOptionData>

		-- Go through each drivable vehicle asset
		for held_asset_index = 1, #drivable_vehicle_assets do

			-- Get the held asset.
			local held_asset = drivable_vehicle_assets[held_asset_index]

			-- Get the asset this is for.
			local drivable_vehicle_asset = g_savedata.libraries.asset_manager.holdable_assets.assets[held_asset.asset_id] --[[@as DrivableVehicleAsset]]

			-- Create the option data
			---@type CommuteDrivingOptionData
			local option_data = {
				citizen_id = citizen_id,
				drivable_vehicle_id = drivable_vehicle_asset.drivable_vehicle_id
			}

			-- Add the option data to the options data
			table.insert(options_data, option_data)
		end

		-- Return the options data
		return options_data
	end,
	---@param option_data CommuteDrivingOptionData
	function(option_data)
		return #option_data > 0
	end,
	---@param option_data CommuteDrivingOptionData
	function(option_data, origin, destination)

		-- Get the drivable vehicle associated with the given id.
		local drivable_vehicle = g_savedata.libraries.drivable_vehicles.vehicles[option_data.drivable_vehicle_id]

		-- Ensure the drivable vehicle is not nil
		if not drivable_vehicle then
			d.print(("<line>: Driving Commute (GetRoute): Drivable Vehicle %s not found"):format(option_data.drivable_vehicle_id), true, 1)
			return {}
		end

		-- Do a land pathfind between the two points.
		local route = LandRoute.new(
			Vector3.toMatrix(Vector3.fromMatrix(drivable_vehicle.transform, true)),
			Vector3.toMatrix(destination)
		)

		return route
	end,
	---@param option_data CommuteDrivingOptionData
	function(option_data, route)

		-- Get the path for this route
		local path = Routing.getPathFromID(route.stored_path_id)

		-- Make sure we got the path.
		if not path then
			d.print(("<line> Driving Commute (GetCommuteTime): No path found for route %s"):format(route.stored_path_id), true, 1)
			return math.maxinteger
		end

		-- Get the distance of the path
		local distance = Pathfinding.getTotalPathDistance(path)

		-- Get the drivable vehicle from the ID.
		local drivable_vehicle = g_savedata.libraries.drivable_vehicles.vehicles[option_data.drivable_vehicle_id]

		-- Get the driving speed of the vehicle (m/s)
		local driving_speed = drivable_vehicle.max_speed

		-- Get the time it takes to walk this distance
		--TODO: Account for game time speed
		local time = distance / driving_speed

		-- Turn the time into a game timestamp
		return GameTimestamp.secondsToTimestamp(time)
	end,
	---@param option_data CommuteDrivingOptionData
	function(option_data, route)

		if option_data.cost then
			return option_data.cost
		end

		-- Get the path for this route
		local path = Routing.getPathFromID(route.stored_path_id)

		-- Make sure we got the path.
		if not path then
			d.print(("<line> Driving Commute (GetCost): No path found for route %s"):format(route.stored_path_id), true, 1)
			return math.maxinteger
		end

		-- Get the distance of the path
		local distance = Pathfinding.getTotalPathDistance(path)

		-- Get the driving cost for the citizen (per metre)
		local driving_cost = 0.05

		-- Get the cost of this commute
		option_data.cost = distance * driving_cost

		-- Get the cost of this commute
		return option_data.cost
	end,
	---@param option_data CommuteDrivingOptionData
	function(option_data, route)

		-- Get the citizen
		local citizen = Citizens.getData(option_data.citizen_id)

		-- Ensure the citizen is not nil
		if not citizen then
			d.print(("<line>: Driving Commute (GetCost): Citizen %s not found"):format(option_data.citizen_id), true, 1)
			return true
		end

		return Vector3.euclideanDistance(
			Vector3.fromMatrix(citizen.transform, true),
			Vector3.fromMatrix(route.end_matrix, true)
		) < 20
	end,
	nil,
	---@param option_data CommuteDrivingOptionData
	function(option_data, route)
		-- Get the drivable vehicle from it's id.
		local drivable_vehicle = g_savedata.libraries.drivable_vehicles.vehicles[option_data.drivable_vehicle_id]

		-- Ensure the drivable vehicle is not nil
		if not drivable_vehicle then
			d.print(("<line>: Driving Commute (startActions): Drivable Vehicle %s not found"):format(option_data.drivable_vehicle_id), true, 1)
			return
		end

		-- Set the drivable vehicle's route
		drivable_vehicle.route = route

		-- Set the driver to be seated.
		DrivableVehicle.setSeated(
			drivable_vehicle,
			option_data.citizen_id,
			DRIVABLE_VEHICLE_SEAT_TYPE.DRIVER
		)
	end,
	nil
)