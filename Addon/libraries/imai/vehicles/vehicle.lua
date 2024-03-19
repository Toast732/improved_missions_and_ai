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
require("libraries.imai.vehicles.vehiclePrefab")
require("libraries.imai.vehicles.vehicleUtilities.speedTracker")

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[ 
	LIBRARY DESCRIPTION
]]

-- library name
Vehicle = {}

--[[


	Classes


]]

---@alias GenericVIN integer the generic vehicle identifier number, used to identify generic vehicles from eachother, without needing to rely on group_ids or vehicle_ids.

---@class GenericVehicle
---@field generic_vin GenericVIN the generic vehicle identifier number for this vehicle.
---@field prefab_name string the name of the prefab for this vehicle.
---@field group_id integer the group_id of this vehicle.
---@field vehicle_ids table<integer, integer> the vehicle_ids in this vehicle.
---@field speed_tracker_ids table<integer, VehicleSpeedTrackerID> the speed tracker id for this vehicle. Indexed by the vehicle_id.

--[[


	Constants


]]

--[[


	Variables


]]

g_savedata.libraries.generic_vehicles = {

	---@type table<GenericVIN, GenericVehicle>
	vehicles = {}, -- Stores all of the generic vehicles, indexed by their generic VIN.

	---@type GenericVIN
	next_generic_vin = 1 -- The next generic VIN to assign.

}

--[[


	Functions


]]

--- Function for spawning a new generic vehicle from the prefab data, at a specific transform.
---@param prefab_name string the name of the prefab for the vehicle.
---@param transform SWMatrix the transform to spawn the vehicle at.
---@return GenericVIN generic_vin the generic vehicle identifier number for this vehicle.
---@return boolean is_success if it successfully spawned the vehicle.
function Vehicle.spawn(prefab_name, transform)

	-- Get the generic VIN for this vehicle
	local generic_vin = g_savedata.libraries.generic_vehicles.next_generic_vin

	-- Increment the next generic VIN
	g_savedata.libraries.generic_vehicles.next_generic_vin = g_savedata.libraries.generic_vehicles.next_generic_vin + 1

	-- Get the prefab data
	local prefab_data = VehiclePrefab.getPrefab(prefab_name)

	-- If we failed to get the prefab data, return early.
	if not prefab_data then
		d.print(("(Vehicle.spawn) Failed to get the prefab data for prefab %s, aborting creation of the generic vehicle."):format(prefab_name), true, 1)
		return -1, false
	end

	-- Spawn a vehicle from the spawning data stored in the prefab
	local component_data, is_success = ComponentSpawner.spawn(prefab_data.spawning_data, transform)

	-- If we failed to spawn the vehicle, return early.
	if not is_success then
		d.print(("(Vehicle.spawn) Failed to spawn the vehicle from the prefab %s, aborting creation of the generic vehicle."):format(prefab_name), true, 1)
		return -1, false
	end

	-- Create the generic vehicle data
	local generic_vehicle = {
		generic_vin = generic_vin,
		prefab_name = prefab_name,
		group_id = component_data.group_id,
		vehicle_ids = component_data.vehicle_ids,
		speed_tracker_ids = {}
	}

	-- Add the generic vehicle to the list of generic vehicles
	g_savedata.libraries.generic_vehicles.vehicles[generic_vin] = generic_vehicle

	-- Return the generic vehicle identifier number
	return generic_vin, true
end

--- Function for getting the speed of the vehicle, in m/s.
---@param generic_vin GenericVIN the generic VIN of the vehicle.
---@param vehicle_id integer|nil the specific vehicle_id to grab the speed of, nil to just grab the main body's speed.
---@return number speed the speed of the vehicle.
---@return boolean is_success if it successfully got the speed.
function Vehicle.getSpeed(generic_vin, vehicle_id)
	-- Get the vehicle from the generic vin
	local vehicle = g_savedata.libraries.generic_vehicles.vehicles[generic_vin]

	-- If the vehicle_id was not specified, default it to the main body_id.
	vehicle_id = vehicle_id or vehicle.vehicle_ids[1]

	-- Get the speed tracker_id for this vehicle_id
	local speed_tracker_id = vehicle.speed_tracker_ids[vehicle_id]

	-- If we failed, return.
	if not speed_tracker_id then
		d.print(("(Vehicle.getSpeed) Failed to get the speed_tracker_id for vehicle id %s with the generic vin of %s. Make sure that it's actually created!"):format(vehicle_id, generic_vin), true, 1)
		return 0, false
	end

	-- Otherwise, get the speed tracker via the tracker id.
	local speed_tracker_data = g_savedata.libraries.vehicle_speed_tracker.trackers[speed_tracker_id]

	-- If we failed to get the data, return early.
	if not speed_tracker_data then
		d.print(("(Vehicle.getSpeed) Failed to get the data for speed tracker with id %s, Generic VIN: %s, Vehicle ID: %s"):format(speed_tracker_id, generic_vin, vehicle_id), true, 1)
		return 0, false
	end

	-- Otherwise, return the speed
	return speed_tracker_data.speed, true
end

--- Function for getting a generic vehicle from their vin.
---@param generic_vin GenericVIN the generic vehicle identifier number.
---@return GenericVehicle|nil generic_vehicle the generic vehicle data.
function Vehicle.getGenericVehicle(generic_vin)
	return g_savedata.libraries.generic_vehicles.vehicles[generic_vin]
end