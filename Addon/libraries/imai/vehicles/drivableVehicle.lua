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
require("libraries.utils.unitConversions")
require("libraries.utils.vector3")

require("libraries.addon.callbacks.binder.binder")

require("libraries.imai.vehicles.vehicle")
require("libraries.imai.vehicles.routing.vehicleTypes.land")

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[ 
	Stores and handles the data for drivable vehicles.

	Also has the onTick for driving the actual vehicles.
]]

--TODO: Formation system. Could be used for things like a convoy, fighters keeping formation, police car pit maneuver, etc.

-- library name
DrivableVehicle = {}

--[[


	Classes


]]

---@alias DrivableVehicleID integer

---@class DrivableVehicle
---@field drivable_vehicle_id DrivableVehicleID the id of the drivable vehicle.
---@field generic_vin GenericVIN the generic vehicle identifier number for this vehicle.
---@field prefab_name string the name of the prefab for the vehicle.
---@field transform SWMatrix the transform of the vehicle.
---@field route Route|nil the route for this vehicle.
---@field vehicle_type DrivableVehicleType the type of vehicle this is.
---@field max_speed number the max speed of the vehicle in m/s.
---@field driving_style string the driving style of the vehicle.

---@class SeatInput
---@field axis_w number the input for the w/s axis, -1 to 1 (1 is w, -1 is s).
---@field axis_d number the input for the a/d axis, -1 to 1 (1 is d, -1 is a).
---@field axis_up number the input for the up/down arrow key axis, -1 to 1 (1 is up, -1 is down).
---@field axis_left number the input for the left/right arrow key axis, -1 to 1 (1 is left, -1 is right).
---@field button1 boolean the input for the key 1.
---@field button2 boolean the input for the key 2.
---@field button3 boolean the input for the key 3.
---@field button4 boolean the input for the key 4.
---@field button5 boolean the input for the key 5.
---@field button6 boolean the input for the key 6.
---@field trigger boolean the input for the trigger (space).


--[[


	Constants


]]

---@enum DrivableVehicleType
DRIVABLE_VEHICLE_TYPE = {
	AIR = 0,
	LAND = 1,
	SEA = 2,
	UNKNOWN = 3
}

--- The number of ticks to split the loaded drivable vehicles by.
LOADED_DRIVABLE_VEHICLE_UPDATE_RATE = 5

UNLOADED_DRIVABLE_VEHICLE_UPDATE_RATE = 1--time.second*5

--[[


	Variables


]]

g_savedata.libraries.drivable_vehicles = {
	---@type table<DrivableVehicleID, DrivableVehicle>
	vehicles = {}, -- Stores all of the drivable vehicles, indexed by drivable vehicle id.

	---@type table<integer, DrivableVehicleID>
	loaded = {}, -- Stores all of the loaded drivable vehicles, stores the drivable vehicle id.

	---@type table<integer, DrivableVehicleID>
	unloaded = {}, -- Stores all of the unloaded drivable vehicles, stores the drivable vehicle id.

	---@type table<integer, DrivableVehicleID>
	vehicle_id_map = {}, -- Indexed by vehicle_id, stores the drivable vehicle id.

	---@type DrivableVehicleID
	next_drivable_vehicle_id = 1 -- The next drivable vehicle id to assign.
}

--[[


	Functions


]]

--- Function for spawning a new drivable vehicle from the prefab data at a specific transform.
---@param prefab_name string the name of the prefab for the vehicle.
---@param transform SWMatrix the transform to spawn the vehicle at.
---@return DrivableVehicleID integer the id of the spawned vehicle.
---@return boolean is_success if it successfully spawned the vehicle.
function DrivableVehicle.spawn(prefab_name, transform)
	-- Spawn the generic vehicle and get the VIN
	local generic_vin, is_success = Vehicle.spawn(prefab_name, transform)

	-- If the vehicle failed to be spawned, return early.
	if not is_success then
		d.print(("(DrivableVehicle.spawn) Failed to spawn vehicle with prefab name %s, aborting creation of the drivable vehicle."):format(prefab_name), true, 0)
		return -1, false
	end

	-- Get the drivable vehicle id
	local drivable_vehicle_id = g_savedata.libraries.drivable_vehicles.next_drivable_vehicle_id

	-- Increment the next drivable vehicle id
	g_savedata.libraries.drivable_vehicles.next_drivable_vehicle_id = g_savedata.libraries.drivable_vehicles.next_drivable_vehicle_id + 1

	--[[
		Get the vehicle type from the tag "medium".
	]]

	-- default to unknown.
	local drivable_vehicle_type = DRIVABLE_VEHICLE_TYPE.UNKNOWN

	-- Get the prefab's data
	local prefab_data = VehiclePrefab.getPrefab(prefab_name)

	-- If we failed to get the prefab data, return early.
	if not prefab_data then
		d.print(("(DrivableVehicle.spawn) Failed to get the prefab data for prefab %s, aborting creation of the drivable vehicle."):format(prefab_name), true, 1)
		return -1, false
	end

	-- Get the medium
	local medium = Tags.getValue(prefab_data.tags, "medium", true)

	-- If the medium is "air", set the vehicle type to air.
	if medium == "air" then
		drivable_vehicle_type = DRIVABLE_VEHICLE_TYPE.AIR
	-- If the medium is "land", set the vehicle type to land.
	elseif medium == "land" then
		drivable_vehicle_type = DRIVABLE_VEHICLE_TYPE.LAND
	-- If the medium is "sea", set the vehicle type to sea.
	elseif medium == "sea" then
		drivable_vehicle_type = DRIVABLE_VEHICLE_TYPE.SEA
	end

	-- Get the max speed of the vehicle, default to 0 if not specified, tag is in kmh format.
	local raw_max_speed = Tags.getValue(prefab_data.tags, "max_speed", false) --[[@as number]] or 0

	-- Get the max speed in m/s
	local max_speed = UnitConversions.kilometresPerHour.toMetresPerSecond(raw_max_speed)

	-- Get the driving style
	local driving_style = Tags.getValue(prefab_data.tags, "driving_style", false) --[[@as string]] or "unknown"

	-- Create the drivable vehicle
	---@type DrivableVehicle
	local drivable_vehicle = {
		drivable_vehicle_id = drivable_vehicle_id,
		generic_vin = generic_vin,
		prefab_name = prefab_name,
		transform = transform,
		route = nil,
		max_speed = max_speed,
		vehicle_type = drivable_vehicle_type,
		driving_style = driving_style
	}

	-- Add the drivable vehicle to g_savedata
	g_savedata.libraries.drivable_vehicles.vehicles[drivable_vehicle_id] = drivable_vehicle

	-- Add the drivable vehicle to the unloaded list
	table.insert(g_savedata.libraries.drivable_vehicles.unloaded, drivable_vehicle_id)

	-- Get the vehicle using the generic vin
	local generic_vehicle = Vehicle.getGenericVehicle(generic_vin)

	-- If the vehicle is nil, return early.
	if not generic_vehicle then
		d.print(("(DrivableVehicle.spawn) Failed to get the vehicle with generic vin %d, aborting creation of the drivable vehicle."):format(generic_vin), true, 1)
		return -1, false
	end

	-- Add the drivable vehicle to the vehicle id map
	g_savedata.libraries.drivable_vehicles.vehicle_id_map[generic_vehicle.vehicle_ids[1]] = drivable_vehicle_id

	-- Return the drivable vehicle id
	return drivable_vehicle_id, true
end

--- Function for setting the target position for a drivable vehicle.
---@param drivable_vehicle_id DrivableVehicleID the id of the drivable vehicle.
---@param target_matrix SWMatrix the target position for the vehicle.
---@return boolean is_success if it successfully updated fthe route.
function DrivableVehicle.updateTargetPosition(drivable_vehicle_id, target_matrix)

	-- Get the drivable vehicle
	local drivable_vehicle = g_savedata.libraries.drivable_vehicles.vehicles[drivable_vehicle_id]

	-- Define the route variable
	local route

	-- If the vehicle type is land, use land calculation.
	if drivable_vehicle.vehicle_type == DRIVABLE_VEHICLE_TYPE.LAND then
		route = LandRoute.new(drivable_vehicle.transform, target_matrix)
	end

	-- Set the route.
	drivable_vehicle.route = route

	-- Return true that it was a success.
	return true
end

--- Function for getting an empty seat input identity
---@return SeatInput seat_input the empty seat input identity.
function DrivableVehicle.getSeatInputIdentity()
	---@type SeatInput
	return {
		axis_w = 0,
		axis_d = 0,
		axis_up = 0,
		axis_left = 0,
		button1 = false,
		button2 = false,
		button3 = false,
		button4 = false,
		button5 = false,
		button6 = false,
		trigger = false
	}
end

--- Function for getting a vehicle's target speed.
---@param drivable_vehicle DrivableVehicle the vehicle to get the target speed for.
---@return number target_speed the target speed of the vehicle.
function DrivableVehicle.getTargetSpeed(drivable_vehicle)
	-- In the future, will be alot more complex, taking into account vehicles ahead, and trying to keep a distance from them, as well as speed limits. But for now, just return the max speed.
	return drivable_vehicle.max_speed
end

--- Function for removing a vehicle from the loaded list.
---@param drivable_vehicle_id DrivableVehicleID the drivable vehicle id to remove from the loaded list.
function DrivableVehicle.removeVehicleFromLoaded(drivable_vehicle_id)
	-- Go through all vehicles in the loaded list.
	for loaded_vehicle_index = 1, #g_savedata.libraries.drivable_vehicles.loaded do
		-- Check if this is the drivable vehicle id we're looking for.
		if g_savedata.libraries.drivable_vehicles.loaded[loaded_vehicle_index] == drivable_vehicle_id then
			-- Remove it from the list.
			table.remove(g_savedata.libraries.drivable_vehicles.loaded, loaded_vehicle_index)
			-- Break, as we found what we're looking for, and there's no reason to look further.
			break
		end
	end
end

--- Function for removing a vehicle from the unloaded list.
---@param drivable_vehicle_id DrivableVehicleID the drivable vehicle id to remove from the unloaded list.
function DrivableVehicle.removeVehicleFromUnloaded(drivable_vehicle_id)
	-- Go through all vehicles in the unloaded list.
	for unloaded_vehicle_index = 1, #g_savedata.libraries.drivable_vehicles.unloaded do
		-- Check if this is the drivable vehicle id we're looking for.
		if g_savedata.libraries.drivable_vehicles.unloaded[unloaded_vehicle_index] == drivable_vehicle_id then
			-- Remove it from the list.
			table.remove(g_savedata.libraries.drivable_vehicles.unloaded, unloaded_vehicle_index)
			-- Break, as we found what we're looking for, and there's no reason to look further.
			break
		end
	end
end

--[[

	Callbacks

]]

--- Ticks the drivable vehicles.
function DrivableVehicle.onTick(game_ticks)
	-- Go through the loaded vehicles for this tick and update them.
	for loaded_vehicle_index = g_savedata.tick_counter % LOADED_DRIVABLE_VEHICLE_UPDATE_RATE + 1, #g_savedata.libraries.drivable_vehicles.loaded, LOADED_DRIVABLE_VEHICLE_UPDATE_RATE do
		-- Get the loaded vehicle id.
		local loaded_vehicle_id = g_savedata.libraries.drivable_vehicles.loaded[loaded_vehicle_index]
		-- Get the loaded vehicle.
		local loaded_vehicle = g_savedata.libraries.drivable_vehicles.vehicles[loaded_vehicle_id]
	end

	-- Go through the unloaded vehicles for this tick and update them.
	for unloaded_vehicle_index = g_savedata.tick_counter % UNLOADED_DRIVABLE_VEHICLE_UPDATE_RATE + 1, #g_savedata.libraries.drivable_vehicles.unloaded, UNLOADED_DRIVABLE_VEHICLE_UPDATE_RATE do
		-- Get the unloaded vehicle id.
		local unloaded_vehicle_id = g_savedata.libraries.drivable_vehicles.unloaded[unloaded_vehicle_index]

		-- Get the unloaded vehicle.
		local unloaded_vehicle = g_savedata.libraries.drivable_vehicles.vehicles[unloaded_vehicle_id]

		-- If this vehicle does not have a route, then skip this vehicle.
		if not unloaded_vehicle.route then
			goto continue
		end

		-- Get the path.
		local path = Routing.getPathFromID(unloaded_vehicle.route.stored_path_id)

		-- Check if the path recieved is not nil.
		if not path then
			goto continue
		end

		-- Get the desired speed of the vehicle
		local movement_speed = DrivableVehicle.getTargetSpeed(unloaded_vehicle)

		-- Calculate how far the vehicle should travel this tick
		local distance_can_travel = movement_speed * (UNLOADED_DRIVABLE_VEHICLE_UPDATE_RATE / time.second)
		
		-- Get the generic vehicle for this vehicle
		local generic_vehicle = Vehicle.getGenericVehicle(unloaded_vehicle.generic_vin)

		-- If the generic vehicle is nil, then skip this vehicle.
		if not generic_vehicle then
			goto continue
		end

		-- Update the current position of this vehicle.
		unloaded_vehicle.transform, is_success = server.getVehiclePos(generic_vehicle.vehicle_ids[1])

		-- If we failed to get it's position, skip.
		if not is_success then
			goto continue
		end

		---@type SWUI_ID
		local ui_id = generic_vehicle.group_id + 100005 --[[@as SWUI_ID]]

		server.removeMapObject(-1, ui_id)
		--server.addMapObject(-1, ui_id, 1, 12, 0, 0, 0, 0, generic_vehicle.vehicle_ids[1], 0, generic_vehicle.prefab_name, 0, generic_vehicle.prefab_name)
		server.addMapObject(-1, ui_id, 0, 12, unloaded_vehicle.transform[13], unloaded_vehicle.transform[15], 0, 0, 0, 0, generic_vehicle.prefab_name, 0, generic_vehicle.prefab_name)

		--d.print(("Vehicle %d is at\nx: %s\nz: %s"):format(unloaded_vehicle.generic_vin, unloaded_vehicle.transform[13], unloaded_vehicle.transform[15]), true, 0)
		--goto continue

		--[[
			Move the vehicle along it's path.
		]]

		-- Get the prefab
		local prefab = VehiclePrefab.getPrefab(unloaded_vehicle.prefab_name)

		-- If the prefab is nil, skip this vehicle.
		if not prefab then
			goto continue
		end

		-- Get the vehicle's offset as a vector.
		local vehicle_offset_vector = Vector3.fromMatrix(prefab.transform_offset, true)

		-- Set the last_pos to the transform of the vehicle. This will be moved along the path.
		local last_position = Vector3.fromMatrix(unloaded_vehicle.transform, true)

		-- Iterate through the path.
		for path_index = unloaded_vehicle.route.path_index, #path do
			-- Get the node
			local node = path[path_index]

			-- Create a vector for the position of this node
			local node_position = Vector3.add(Vector3.new(node.x, node.y, node.z), vehicle_offset_vector)

			-- Calculate the distance from last_position to the node of this path, set to minimum 0.0001, to avoid division by 0.
			local distance_to_waypoint = math.max(Vector3.euclideanDistance(last_position, node_position), 0.0001)

			-- Get the progress the vehicle can travel along this path.
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

				-- Increment the path index the vehicle is on.
				unloaded_vehicle.route.path_index = unloaded_vehicle.route.path_index + 1
			else
				-- Travel along the path by progress.
				last_position = Vector3.lerp(last_position, node_position, progress)

				-- Break, as we cannot move any more.
				break
			end
		end

		-- Move the group to the last position.
		server.moveVehicle(generic_vehicle.vehicle_ids[1], Vector3.toMatrix(last_position))

		::continue::
	end
end

--[[
	Binds
]]


-- Bind to onVehicleLoad, to add the vehicle to the loaded list.
Binder.bind.onVehicleLoad(
	---@param vehicle_id integer the vehicle_id of the spawned vehicle.
	function(vehicle_id)

		-- Get the drivable vehicle id.
		local drivable_vehicle_id = g_savedata.libraries.drivable_vehicles.vehicle_id_map[vehicle_id]

		-- Check if this vehicle is a drivable vehicle, if not, return.
		if not drivable_vehicle_id then
			return
		end

		-- Remove the vehicle from the unloaded list.
		DrivableVehicle.removeVehicleFromUnloaded(drivable_vehicle_id)

		-- Add the vehicle to the loaded list.
		table.insert(g_savedata.libraries.drivable_vehicles.loaded, drivable_vehicle_id)
	end
)

-- Bind to onVehicleUnload, to remove the vehicle from the loaded list.
Binder.bind.onVehicleUnload(
	---@param vehicle_id integer the vehicle_id of the spawned vehicle.
	function(vehicle_id)
		-- Get the drivable vehicle id.
		local drivable_vehicle_id = g_savedata.libraries.drivable_vehicles.vehicle_id_map[vehicle_id]

		-- Check if this vehicle is a drivable vehicle, if not, return.
		if not drivable_vehicle_id then
			return
		end

		-- Remove the vehicle from the loaded list.
		DrivableVehicle.removeVehicleFromLoaded(drivable_vehicle_id)

		-- Add the vehicle to the unloaded list.
		table.insert(g_savedata.libraries.drivable_vehicles.unloaded, drivable_vehicle_id)
	end
)

Command.registerCommand(
	"test_land_vehicle",
	function()
		local drivable_vehicle_id, is_success = DrivableVehicle.spawn("Test Land Vehicle", matrix.translation(-6024, 50, -29117))
		
		DrivableVehicle.updateTargetPosition(drivable_vehicle_id, matrix.translation(-21310, 50, -28852))
	end,
	"admin",
	"Temporary Debug Command.",
	"Temporary Debug Command.",
	{""}
)