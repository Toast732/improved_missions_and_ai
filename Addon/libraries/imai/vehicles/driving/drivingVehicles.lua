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
require("libraries.imai.vehicles.drivableVehicle")

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[ 
	Used to define the ways of driving vehicles, by the type of vehicle, driving style, driving state, and driving conditions.
	As an example, for a land vehicle, you could define a driving style of "tank", with the additional styles of "attack_vehicle", and conditions such as "turn_to_target",
		which is only triggered if a certain condition is hit.

		The conditions are in a priority hiarchy, and it goes on a basis by the current state, starting from the highest priority
			If that condition is not met, it instead goes to the next highest priority.
			Or, if that condition is not defined for the current state, it instead checks it on the general vehicle state.
]]

-- library name
DrivingVehicles = {}

--[[


	Classes


]]

---@class DrivingTypeData
---@field vehicle_type DrivableVehicleType the type of vehicle this is.
---@field driving_styles table<DrivingStyleName, DrivingStyle> the driving styles for this vehicle type.
---@field defineStyle fun(self: DrivingTypeData, style_name: DrivingStyleName):DrivingStyle the function to define a driving style for this vehicle type.

---@alias DrivingStyleName string The driving style for this vehicle type, for example, "tank".

---@class DrivingStyle
---@field driving_style DrivingStyleName the name of the driving style of this vehicle, for example, "tank".
---@field driving_states table<DrivingStateName, DrivingState> the driving states for this driving style.
---@field defineState fun(self: DrivingStyle, state_name: DrivingStateName):DrivingState the function to define a driving state for this driving style.

---@alias DrivingStateName string the name of the driving state of this vehicle, for example, "attack_vehicle".

---@class DrivingState
---@field driving_state DrivingStateName the name of the driving state of this vehicle, for example, "attack_vehicle".
---@field conditions table<DrivingConditionPriority, DrivingCondition> the conditions for this driving state.
---@field defineCondition fun(self: DrivingState, condition_name: DrivingConditionName, priority: DrivingConditionPriority, condition_function: (fun(vehicle: DrivableVehicle):boolean)|boolean, behaviour: fun(vehicle: DrivableVehicle):SeatInput) the function to define a driving condition for this driving state.

---@alias DrivingConditionName string the name of the driving condition of this vehicle, for example, "turn_to_target".
---@alias DrivingConditionPriority integer the priority of the driving condition, highest priority is checked first.

---@class DrivingCondition
---@field driving_condition DrivingConditionName the name of the driving condition of this vehicle, for example, "turn_to_target".
---@field priority integer the priority of this condition, highest priority is checked first.
---@field condition_function boolean|fun(vehicle: DrivableVehicle):boolean the function that checks if this condition is met.
---@field behaviour fun(vehicle: DrivableVehicle):SeatInput the behaviour to execute if this condition is met. The buttons do not work like vanilla, and instead, true will just have the button be on, and false will have it be off, instead of toggling it.

--[[


	Constants


]]

--[[


	Variables


]]

--[[
	Stores the driving data for all of the vehicle types.
]]

---@type table<DrivableVehicleType, DrivingTypeData>
driving_types = {}

--[[


	Functions


]]

--- Defines a driving type for a vehicle type. If it already exists, it will return the existing driving type data.
---@param vehicle_type DrivableVehicleType the type of vehicle to define the driving type for.
---@return DrivingTypeData driving_type_data driving type data for this vehicle type.
function DrivingVehicles.define(vehicle_type)

	-- Check if it already exists
	if driving_types[vehicle_type] then
		-- If it does, return the existing one.
		return driving_types[vehicle_type]
	end

	-- Create the driving type data for this vehicle type.
	---@type DrivingTypeData
	local driving_type_data = {
		vehicle_type = vehicle_type,
		driving_styles = {},
		defineStyle = DrivingVehicles.defineStyle
	}

	-- Add the driving type data to the driving types.
	driving_types[vehicle_type] = driving_type_data

	-- Return the driving type data.
	return driving_types[vehicle_type]
end

--- Defines a driving style for a vehicle type.
---@param self DrivingTypeData
---@param style_name DrivingStyleName
---@return DrivingStyle driving_style the driving style for this vehicle type.
function DrivingVehicles.defineStyle(self, style_name)
	
	-- Check if it already exists
	if self.driving_styles[style_name] then
		-- If it does, return the existing one.
		return self.driving_styles[style_name]
	end

	-- Create the driving style for this vehicle type.
	---@type DrivingStyle
	local driving_style = {
		driving_style = style_name,
		driving_states = {},
		defineState = DrivingVehicles.defineState
	}

	-- Add the driving style to the driving styles.
	self.driving_styles[style_name] = driving_style

	-- Return the driving style.
	return self.driving_styles[style_name]
end

--- Defines a driving state for a driving style.
---@param self DrivingStyle
---@param state_name DrivingStyleName
function DrivingVehicles.defineState(self, state_name)

	-- Check if it already exists
	if self.driving_states[state_name] then
		-- If it does, return the existing one.
		return self.driving_states[state_name]
	end

	--- Create the driving state for this driving style.
	---@type DrivingState
	local driving_state = {
		driving_state = state_name,
		conditions = {},
		defineCondition = DrivingVehicles.defineCondition
	}

	-- Add the driving state to the driving states.
	self.driving_states[state_name] = driving_state

	-- Return the driving state.
	return self.driving_states[state_name]
end

--- Defines a driving condition for a driving state.
---@param self DrivingState
---@param condition_name DrivingConditionName
---@param priority DrivingConditionPriority
---@param condition_function boolean|fun(vehicle: DrivableVehicle):boolean
---@param behaviour fun(vehicle: DrivableVehicle):SeatInput the behaviour to execute if this condition is met. The buttons do not work like vanilla, and instead, true will just have the button be on, and false will have it be off, instead of toggling it.
function DrivingVehicles.defineCondition(self, condition_name, priority, condition_function, behaviour)
	-- Create the driving condition for this driving state.
	---@type DrivingCondition
	local driving_condition = {
		driving_condition = condition_name,
		priority = priority,
		condition_function = condition_function,
		behaviour = behaviour
	}

	-- Add the condition to the conditions.
	table.insert(self.conditions, driving_condition)

	-- Sort the conditions by priority.
	table.sort(self.conditions, function(a, b)
		return a.priority > b.priority
	end)
end

require("libraries.imai.vehicles.driving.drivingTypeDefinitions")