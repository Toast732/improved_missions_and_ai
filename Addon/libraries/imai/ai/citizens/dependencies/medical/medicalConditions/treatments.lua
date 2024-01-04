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

-- required libraries
require("libraries.addon.commands.flags")

--[[


	Library Setup


]]

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

Treatments = {}

---@class treatmentCondition For your treatment condition, you can define any number of these functions, if they return true, then the condition will be treated.
---@field onCitizenDamaged fun(citizen: Citizen, damage_amount: number, closest_damage_source: string)|nil this function is called whenever a citizen takes damage
---@field onTick fun(citizen: Citizen, game_ticks: integer)|nil this function is called every tick
---@field onFirstAid fun(citizen: Citizen)|nil this function is called whenever the citizen is healed by a first aid kit.
---@field onDefibrillator fun(citizen: Citizen)|nil this function is called whenever the citizen gets hit by a defibrillator.

---@class treatment The
---@field name string the name for this treatment, should be the same as the linked condition, eg "bleeds"
---@field tooltip string|fun(citizen: Citizen):string the tooltip of this treatment, if as a function, param is citizen
---@field completion_actions function? This function will be executed whenever its successfully treated.
---@field failure_actions function? This function will be executed whenever they failed to treat it within the deadline.
---@field default_time integer? The default timer for when this can no longer be treated. nil means it never expires
---@field treatment_condition string the way this condition is treated

---@class requiredTreatment the treatment stored with the citizen's data
---@field name string the name of this treatment
---@field deadline integer? the deadline for when this will have failed to have been treated. nil means it never expires.

---@type table<string, treatment>
defined_treatments = {}

---@type table<string, treatmentCondition>
defined_treatment_conditions = {}

---# Allows the treatment debug to be toggled by a flag, as its quite spammy.
---@param message string the message you want to print
---@param requires_debug ?boolean if it requires <debug_type> debug to be enabled
---@param debug_type ?integer the type of message, 0 = debug (debug.chat) | 1 = error (debug.chat) | 2 = profiler (debug.profiler) 
---@param peer_id ?integer if you want to send it to a specific player, leave empty to send to all players
function Treatments.print(message, requires_debug, debug_type, peer_id)
	if g_savedata.flags.treatment_debug then
		d.print(message, requires_debug, debug_type, peer_id)
	end
end

---@param name string the name for this treatment, should be the same as the linked condition, eg "bleeds"
---@param tooltip string|function the tooltip of this treatment, if as a function, param is citizen
---@param completion_actions function? This function will be executed whenever its successfully treated.
---@param failure_actions function? This function will be executed whenever they failed to treat it within the deadline.
---@param default_time integer? The default timer for when this can no longer be treated, leave nil to have it never expire.
---@param treatment_condition string the way this condition is treated
function Treatments.create(name, tooltip, completion_actions, failure_actions, default_time, treatment_condition)
	defined_treatments[name] = {
		name = name,
		tooltip = tooltip,
		completion_actions = completion_actions,
		failure_actions = failure_actions,
		default_time = default_time,
		treatment_condition = treatment_condition
	}
end

---@param onCitizenDamaged function? this function is called whenever a citizen takes damage, args are: citizen, damage_amount, closest_damage_source
---@param onTick function? this function is called every tick, args are: citizen, game_ticks
---@param onFirstAid function? this function is called whenever the citizen is healed by a first aid kit. args are: citizen
---@param onDefibrillator function? this function is called whenever the citizen gets hit by a defibrillator. args are: citizen
function Treatments.defineTreatmentCondition(name, onCitizenDamaged, onTick, onFirstAid, onDefibrillator)
	defined_treatment_conditions[name] = {
		onCitizenDamaged = onCitizenDamaged,
		onTick = onTick,
		onFirstAid = onFirstAid,
		onDefibrillator = onDefibrillator
	}
end

---# Applies the required treatment to the target citizen.
---@param citizen Citizen
---@param treatment_name string the treatment name
---@param time_override number? the default time override. leave nil to keep default
---@return boolean applied if the required treatment was applied, false doesn't always mean an error, could instead mean that it already has the required treatment applied.
function Treatments.apply(citizen, treatment_name, time_override)
	-- if treatment is already applied
	if citizen.medical_data.required_treatments[treatment_name] then
		Treatments.print(("<line>: Treatment %s is already applied to %s"):format(treatment_name, citizen.name.full), false, 0)
		return false
	end

	-- get the treatment data
	local treatment_data = defined_treatments[treatment_name]

	-- get the wanted ticks till deadline, if output is nil or -1, then it should never expire.
	local ticks_till_deadline = time_override or treatment_data.default_time

	-- if output is -1, then set it to nil as there should be no deadline.
	ticks_till_deadline = ticks_till_deadline ~= -1 and ticks_till_deadline or nil

	-- apply the treatment
	citizen.medical_data.required_treatments[treatment_name] = {
		name = treatment_name,
		deadline = ticks_till_deadline and ticks_till_deadline + g_savedata.tick_counter or nil
	}

	Treatments.print(("Applied Required Treatment %s to %s."):format(treatment_name, citizen.name.full), false, 0)

	return true
end

--[[
	Callbacks
]]

---@param citizen Citizen the citizen
---@param treatment requiredTreatment the required treatment to check
---@param callback string the name of the treatment callback to check
---@param ... any the arguments to be sent to the callback.
function Treatments.checkCallback(citizen, treatment, callback, ...)

	-- if this treatment type is not defined
	if not defined_treatments[treatment.name] then
		d.print(("<line>: Removing Required Treatment %s from %s as it does not exist."):format(treatment.name, citizen.name.full), true, 1)
		-- remove it from this character
		citizen.medical_data.required_treatments[treatment.name] = nil

		return
	end

	local treatment_type = defined_treatments[treatment.name].treatment_condition

	-- if this treatment doesn't actaully exist
	if not defined_treatment_conditions[treatment_type] then
		d.print(("<line>: Removing Required Treatment %s from %s as it does not exist."):format(treatment.name, citizen.name.full), true, 1)
		-- remove it from this character
		citizen.medical_data.required_treatments[treatment.name] = nil

		return
	end

	-- the deadline has been hit or surpassed, if deadline is nil, skip check as this shouldn't expire
	if treatment.deadline and treatment.deadline <= g_savedata.tick_counter then
		-- remove it from this character
		citizen.medical_data.required_treatments[treatment.name] = nil

		Treatments.print(("<line>: %s Was not treated in time for citizen %s"):format(treatment.name, citizen.name.full), false, 0)

		return
	end

	-- if this callback does not exist for this treatment
	if not defined_treatment_conditions[treatment_type][callback] then
		return
	end

	-- if this callback returns false
	if not defined_treatment_conditions[treatment_type][callback](...) then
		return
	end

	Treatments.print(("Required Treatment %s on %s has been successfully treated."):format(treatment.name, citizen.name.full), false, 0)

	-- say that this condition was successfully treated
	defined_treatments[treatment.name].completion_actions(citizen)

	-- remove this required treatment
	citizen.medical_data.required_treatments[treatment.name] = nil
end

function Treatments.onCitizenDamaged(citizen, damage_amount, closest_damage_source)
	for _, treatment in pairs(citizen.medical_data.required_treatments) do
		Treatments.checkCallback(
			citizen,
			treatment,
			"onCitizenDamaged",
			citizen,
			damage_amount,
			closest_damage_source
		)
	end
end

function Treatments.onTick(citizen, game_ticks)
	for _, treatment in pairs(citizen.medical_data.required_treatments) do
		Treatments.checkCallback(
			citizen,
			treatment,
			"onTick",
			citizen,
			game_ticks
		)
	end
end

function Treatments.onFirstAid(citizen)
	for _, treatment in pairs(citizen.medical_data.required_treatments) do
		Treatments.checkCallback(
			citizen,
			treatment,
			"onFirstAid",
			citizen
		)
	end
end

function Treatments.onDefibrillator(citizen)
	for _, treatment in pairs(citizen.medical_data.required_treatments) do
		Treatments.checkCallback(
			citizen,
			treatment,
			"onDefibrillator",
			citizen
		)
	end
end

--[[
	Flags
]]

Flag.registerBooleanFlag(
	"treatment_debug",
	true,
	{
		"debug"
	},
	"admin",
	"admin",
	nil,
	"Enables or disables the debug output for treatments."
)