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

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[
	The commuting system, this is what's interacted with by things such as the citizen schedule system after the base schedule has been generated.
]]

--[[
	Rules:
		1. The first and final commute types must be an interim commute type (eg: walking)
			Reasoning:
				This is to avoid situations where, for example, a citizen could try driving into their work, and prevents cases of teleporting.
		2. The same commute type cannot be used twice in a row.
			Reasoning:
				This is to avoid wasting resources, as walking straight to work will aways be better than first walking to the bus station, 
					and then walking to work from said bus station. So this will prevent such from being calculated.
]]

-- library name
Commuting = {}

--[[


	Classes


]]

---@alias CommuteCost number

--- Base class to be extended from, so each commute option can specify the custom data they require.
---@class CommuteBaseOptionData
---@field citizen Citizen the citizen this commute is for.

---@class CommuteTypeDefinition
---@field name string the name of the commute type, eg "walking"
---@field interim boolean if this commute can be used as an interim commute (eg: walking from house to the car)
---@field get_options fun(citizen: Citizen, origin: Vector3, destination: Vector3): table<CommuteBaseOptionData> the options for this commute type.
---@field is_available fun(options_data: table<CommuteBaseOptionData>): boolean if this commute type is available for this citizen.
---@field calculate_route fun(option_data: CommuteBaseOptionData, origin: Vector3, destination: Vector3): Route the route for this commute type.
---@field get_commute_time fun(option_data: CommuteBaseOptionData, route: Route): GameTimestamp the time it takes for this citizen to commute using this commute type.
---@field get_cost fun(option_data: CommuteBaseOptionData, route: Route): CommuteCost the cost of this commute type.

---@class CommuteBuilder
---@field citizen Citizen the citizen this commute is for.
---@field origin Vector3 the origin of the commute.
---@field destination Vector3 the destination of the commute.

--[[


	Constants


]]

--[[


	Variables


]]

--- The types of commutes that are registered.
---@type table<string, CommuteTypeDefinition>
commute_types = {}

--- The interim commutes that are registered.
---@type table<int, CommuteTypeDefinition>
interim_commute_types = {}

--[[


	Functions


]]

--- Function for registering a new commute type.
---@param name string the name of the commute type, eg "walking"
---@param interim boolean if this commute can be used as an interim commute (eg: walking from house to the car)
---@param get_options fun(citizen: Citizen, origin: Vector3, destination: Vector3): table<CommuteBaseOptionData> the options for this commute type.
---@param is_available fun(options_data: table<CommuteBaseOptionData>): boolean if this commute type is available for this citizen.
---@param calculate_route fun(option_data: CommuteBaseOptionData, origin: Vector3, destination: Vector3): Route the route for this commute type.
---@param get_commute_time fun(option_data: CommuteBaseOptionData, route: Route): GameTimestamp the time it takes for this citizen to commute using this commute type.
---@param get_cost fun(option_data: CommuteBaseOptionData, route: Route): CommuteCost the cost of this commute type.
function Commuting.registerCommuteType(name, interim, get_options, is_available, calculate_route, get_commute_time, get_cost)
	
	-- check if this commute type is already registered
	for _, commute_type in ipairs(commute_types) do
		if commute_type.name == name then
			d.print(("Commute type %s is already registered."):format(name), true, 1)
			return
		end
	end

	-- create the commute type definition
	---@type CommuteTypeDefinition
	local commute_type_definition = {
		name = name,
		interim = interim,
		get_options = get_options,
		is_available = is_available,
		calculate_route = calculate_route,
		get_commute_time = get_commute_time,
		get_cost = get_cost
	}

	-- create it as a commute type
	table.insert(
		commute_types,
		commute_type_definition
	)

	-- If it's an interim commute, add it to the interim commutes.
	if interim then
		table.insert(interim_commute_types, commute_types[#commute_types])
	end
end

--[[

	Definitions

]]

require("libraries.imai.commuting.types.walkingCommute")
require("libraries.imai.commuting.types.drivingCommute")