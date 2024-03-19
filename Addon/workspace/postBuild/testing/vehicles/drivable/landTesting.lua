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

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[ 
	LIBRARY DESCRIPTION
]]

--[[


	Classes


]]

--[[


	Constants


]]

--[[


	Variables


]]

--[[


	Functions


]]

registerTest("landTesting", function()

	-- Create a mockup prefab for a drivable land vehicle
	---@type VehiclePrefab
	local vehicle_prefab = {
		name = "test_vehicle",
		components = {
			{
				type = "VehicleComponent",
				name = "vehicle",
				vehicleType = "land"
			}
		},
		spawning_data = {
			component_index = 0,
			location_index = 0,
			addon_index = 0
		},
		mass = 1000,
		voxels = 5000,
		tags = {"imai", "land", "drivable"},
		setup = true,
		available = true
	}

	-- Add the prefab to the vehicle prefabs list.
	g_savedata.vehicle_prefab["test_vehicle"] = vehicle_prefab

	-- Create a mockup vehicle
	---@type Vehicle
	local vehicle = {
		prefab_name = "test_vehicle",
		group_id = 1,
		vehicle_ids = {1},
		speed_tracker_ids = {}
	}

	return true
end)