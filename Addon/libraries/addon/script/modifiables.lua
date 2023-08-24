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

-- Library Version 0.0.1

--[[


	Library Setup


]]

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[ 
	Adds a new type of variable called a modifiable, stores a table of modifiers and applies them automatically
	Gives them each ids and each has optional expiries.
]]

-- library name
Modifiables = {}

--[[


	Classes


]]

---@class Modifier
---@field expires boolean if this modifier expires
---@field expires_at integer the tick this expires at
---@field modifier number the modifier.

---@class Modifiable
---@field modifiers table<string, Modifier>
---@field default_value number the value before it gets any modifiers applied

--[[


	Variables


]]

---# Prepares a table to store Modifiables
---@param t table the table which to store the modifiables
---@return Modifiable t the table prepared with modifiables
function Modifiables.prepare(t, default_value)
	t.modifiers = {}
	t.default_value = default_value

	return t
end

---# Sets or adds a modifier
---@param t Modifiable the table with the modifiables
---@param modifier_name string the name of the modifier 
---@param modifier number the value for this modifier
---@param expiry integer? the tick this will expire on, set nil to not update expirey, set to -1 to never expire.
function Modifiables.set(t, modifier_name, modifier, expiry)
	if t.modifiers[modifier_name] then
		if expiry then
			t.modifiers[modifier_name].expires_at = expiry
			t.modifiers[modifier_name].expires = expiry ~= -1
		end

		t.modifiers[modifier_name].modifier = modifier
	else
		t.modifiers[modifier_name] = {
			expires_at = expiry or -1,
			expires = expiry ~= -1,
			modifier = modifier
		}
	end
end

---# Gets the value of a modifiable.
---@param t Modifiable
---@return number modified_variable
function Modifiables.get(t)
	local value = t.default_value

	for modifier_name, modifier in pairs(t.modifiers) do
		-- if this modifier has expired
		if modifier.expires and modifier.expires_at <= g_savedata.tick_counter then
			t.modifiers[modifier_name] = nil
			goto next_modifier
		end

		value = value + modifier.modifier

		::next_modifier::
	end

	return value
end