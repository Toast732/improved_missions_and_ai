--[[
	
Copyright 2023 Liam Matthews

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

--[[


	Library Setup


]]

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

medicalCondition = {}

---@class medicalCondition
---@field name string the name of the medical condition, eg "burn"
---@field display_name string what to show in the list of medical conditions for this citizen, set by looking at the data in your custom_data.
---@field custom_data table<any, any> your custom data to be stored with this medical condition.
---@field hidden boolean if this condition is to be hidden.

---@class medicalConditionCallbacks
---@field name string the name of the medical condition, eg "burn"
---@field onTick function? called whenever onTick is called. (param 1 is citizen, param 2 is game_ticks)
---@field onCitizenDamaged function? called whenever a citizen is damaged or healed. (param 1 is citizen, param 2 is damage_amount)

medical_conditions_callbacks = {} ---@type table<string, medicalConditionCallbacks> the table containing all of the medical condition's callbacks

medical_conditions = {} ---@type table<string, medicalCondition> the table containing all of the medical conditions themselves, for default data.

function medicalCondition.create(name, hidden, custom_data, call_onTick, call_onCitizenDamaged)
	
	-- check if this medical condition is already registered
	if medical_conditions_callbacks[name] then
		d.print(("<line>: attempt to register medical condition \"%s\" that is already registered."):format(name), true, 1)
		return
	end

	-- create it as a medicalConditionCallback.
	medical_conditions_callbacks[name] = {
		name = name,
		onTick = call_onTick,
		onCitizenDamaged = call_onCitizenDamaged
	} ---@type medicalConditionCallbacks

	-- create it as a medical condition
	medical_conditions[name] = {
		name = name,
		display_name = "",
		custom_data = custom_data,
		hidden = hidden
	}

	-- register into existing citizens who do not have the effect.
	for citizen_index = 1, #g_savedata.libraries.citizens.citizen_list do
		local citizen = g_savedata.libraries.citizens.citizen_list[citizen_index]
		
		-- if it does not exist for this citizen, register it.
		if not citizen.medical_conditions[name] then
			citizen.medical_conditions[name] = {
				name = name,
				display_name = "",
				custom_data = custom_data,
				hidden = hidden
			}
		end
	end
end

---@param citizen Citizen the citizen to get the medical condition tooltip of
function medicalCondition.getTooltip(citizen)

	local mc_string = "Conditions"

	for _, effect_data in pairs(citizen.medical_conditions) do
		
		-- if the effect is hidden, skip it
		if effect_data.hidden then
			goto continue_condition
		end

		-- add the display name
		mc_string = ("%s\n- %s"):format(mc_string, effect_data.display_name)

		::continue_condition::
	end

	return mc_string
end

--[[
	onTick
]]
function medicalCondition.onTick(citizen, game_ticks)
	-- call all medical condition onTicks for this citizen.
	for _, medical_condition_callbacks in pairs(medical_conditions_callbacks) do
		if medical_condition_callbacks.onTick then
			medical_condition_callbacks.onTick(citizen, game_ticks)
		end
	end
end

--[[
	onCitizenDamaged
]]
function medicalCondition.onCitizenDamaged(citizen, damage_amount)
	-- call all medical condition onCitizenDamaged for this citizen.
	for _, medical_condition_callbacks in pairs(medical_conditions_callbacks) do
		if medical_condition_callbacks.onCitizenDamaged then
			medical_condition_callbacks.onCitizenDamaged(citizen, damage_amount)
		end
	end
end

--[[

	scripts to be put after this one

]]

--[[
	definitions
]]
require("libraries.imai.ai.citizens.dependencies.medicalConditions.definitions.medicalConditions.burns")