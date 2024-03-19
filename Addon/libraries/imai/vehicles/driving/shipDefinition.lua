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

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[ 
	Sets up the driving behaviour of ships.
]]


-- Define/Get the sea driving type.
sea_driving_type = DrivingVehicles.define(DRIVABLE_VEHICLE_TYPE.SEA)

-- Define the ship driving style.
ship_driving_type = sea_driving_type:defineStyle("ship_basic")

-- Define the general driving state
ship_general_driving_state = ship_driving_type:defineState("general")

-- Define the normal ship driving condition (driving normally).
ship_normal_driving_condition = ship_general_driving_state:defineCondition(
	"normal",
	0,
	true,
	function(vehicle)
		-- Get an empty seat input identity.
		local seat_input = DrivableVehicle.getSeatInputIdentity()

		-- Return the seat input
		return seat_input
	end
)