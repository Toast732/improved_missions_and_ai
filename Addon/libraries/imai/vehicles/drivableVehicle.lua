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
	Stores and handles the data for drivable vehicles.
]]

-- library name
DrivableVehicle = {}

--[[


	Classes


]]

--[[


	Constants


]]

--[[


	Variables


]]

g_savedata.drivable_vehicles = {
	vehicles = {},
	loaded = {},
	unloaded = {}
}

--[[


	Functions


]]

--[[

	Callbacks

]]

--- Ticks the loaded drivable vehicles.
function DrivableVehicle.onTick(game_ticks)
end

--[[

	Driving Behaviour Types

]]

--- Land Vehicle driving behaviour.
