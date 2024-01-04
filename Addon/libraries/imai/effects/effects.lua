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

--[[


	Library Setup


]]

Effects = {}

-- required libraries
require("libraries.addon.script.debugging")

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

g_savedata.libraries.effects = {
	---@type table<integer, Effect>
	effects = {}
}

--[[


	Variables


]]

---@type table<string, DefinedEffect>
defined_effects = {}

--- Indexed by effect name, and then by object type.
---@type table<string, table<string, boolean>>
effect_applicable_objects = {}

--[[


	Classes


]]

---@class DefinedEffect effect's data stored in defined_effects
---@field name string the name of the effect
---@field applicable_objects table<integer, string> stores the objects which this can apply to, strings function as patterns (can define {".*"} to allow it to apply to all objects.)
---@field call_onEffectApply function? called whenever the effect is applied, param1 is the object data, param2 is the duration of the effect (in ticks), param3 is the strength of the effect
---@field call_onEffectRemove function? called when the effect is removed or expires, param1 is the object data.
---@field call_onTick function? called every tick, param1 is object data, param 2 is game_ticks

---@class Effect Effects stored in g_savedata, stores the currently active effects.
---@field name string the name of the applied effect.
---@field indexing_data table the indexing data to index the object's data.
---@field expiry integer? the tick this expires on, no value means it never naturally expires.

--[[


	Functions


]]

---# Define an effect.
---@param name string the name of the effect
---@param applicable_objects table<integer, string> stores the objects which this can apply to, strings function as patterns (can define {".*"} to allow it to apply to all objects.)
---@param call_onEffectApply function? called whenever the effect is applied, param1 is the object data, param2 is the duration of the effect (in ticks), param3 is the strength of the effect
---@param call_onEffectRemove function? called when the effect is removed or expires, param1 is the object data.
---@param call_onTick function? called every tick, param1 is object data, param 2 is game_ticks
function Effects.define(name, applicable_objects, call_onEffectApply, call_onEffectRemove, call_onTick)
	defined_effects[name] = {
		name = name,
		applicable_objects = applicable_objects,
		call_onEffectApply = call_onEffectApply,
		call_onEffectRemove = call_onEffectRemove,
		call_onTick = call_onTick
	}

	-- sets the applicable effects for the objects (so we dont have to iterate through each time we want to apply an object)
	for applicable_object_index = 1, #applicable_objects do
		effect_applicable_objects[name] = effect_applicable_objects[name] or {} -- make sure table is defined, if not define it.

		effect_applicable_objects[name][applicable_objects[applicable_object_index]] = true -- say that this effect is applicable to this object type.
	end
end

---# Apply an effect.
---@param name string the name of the effect.
---@param object table the object to apply this effect to.
---@param duration number the duration of this effect (in seconds), setting to 0 or below results in the effect being permanent.
---@param strength number? the strength of this effect, defaults to 1.
---@return boolean is_success if the effect was successfully applied.
function Effects.apply(name, object, duration, strength)

	-- get the effect's definition
	local effect_definition = defined_effects[name]
	
	-- if this effect does not exist.
	if not effect_definition then
		d.print(("<line>: Attempted to apply effect \"%s\", yet the effect is not defined!"):format(name), true, 1)
		return false
	end

	-- if the object does not contain the object_type param
	if not object.object_type then
		d.print(("<line>: Attempted to apply effect \"%s\", But the given object does not contain the object_type field! object_data:\n\"%s\""):format(name, string.fromTable(object)), true, 1)
		return false
	end

	-- if the object cannot have this effect applied.
	if not effect_applicable_objects[name] or not effect_applicable_objects[name][object.object_type] then
		d.print(("<line>: Attempted to apply effect \"%s\" to an object with type: \"%s\", however that object type cannot have that effect applied!"):format(name, object.object_type), true, 1)
		return false
	end

	-- Get the indexing data.
	local indexing_data, is_success = References.getIndexingData(object)

	-- if getting the indexing data failed
	if not is_success then
		d.print(("<line>: Attempted to apply effect \"%s\" to an object with type: \"%s\", however getting the indexing data via References.getIndexingData Failed!"):format(name, object.object_type), true, 1)
		return false
	end

	-- default strength to 1 if not defined
	strength = strength or 1

	-- convert duration from seconds to ticks
	--TODO: Add a thing to check if the tps is 62.5 vs 60, to provide a more accurate and consistent experience from singleplayer and multiplayer (right now just assumes 60 for mp for simplicity with math)
	duration = duration*60

	-- Apply the effect
	if effect_definition.call_onEffectApply then 
		effect_definition.call_onEffectApply(object, duration, strength)
	end

	---@type number|nil
	local expiry = duration + g_savedata.tick_counter

	-- set expiry to nil if the duration is 0 or less (never expire)
	if duration < 1 then
		expiry = nil
	end

	-- store the effect data
	table.insert(g_savedata.libraries.effects.effects, {
		name = name,
		indexing_data = indexing_data,
		expiry = expiry
	})

	-- return that the effect was applied.
	return true
end

---# Remove an effect
---@param object table the object to remove the effect from
---@param name string the name of the effect to remove
---@return boolean removed if the effect was removed, returns false if an error occured or if the effect was not applied in the first place.
---@return boolean is_success returns false if there was an error in the process of removing an effect.
function Effects.remove(object, name)
	-- if the object was never given
	if not object then
		d.print(("<line>: Attempted to remove effect \"%s\", yet the object given is nil!"):format(name), true, 1)
		return false, false
	end

	-- get the effect's definition
	local effect_definition = defined_effects[name]
	
	-- if this effect does not exist.
	if not effect_definition then
		d.print(("<line>: Attempted to remove effect \"%s\", yet the effect is not defined!"):format(name), true, 1)
		return false, false
	end

	-- if the object does not contain the object_type param
	if not object.object_type then
		d.print(("<line>: Attempted to remove effect \"%s\", But the given object does not contain the object_type field! object_data:\n\"%s\""):format(name, string.fromTable(object)), true, 1)
		return false, false
	end

	-- get the indexing data for this object (used to identify which effects in the effects table is for this object)
	local indexing_data, is_success = References.getIndexingData(object)

	-- if getting the indexing data failed
	if not is_success then
		d.print(("<line>: Attempted to remove effect \"%s\" from an object with type: \"%s\", however getting the indexing data via References.getIndexingData Failed!"):format(name, object.object_type), true, 1)
		return false, false
	end

	-- iterate through all effects in search of the one to remove.
	for effect_index = 1, #g_savedata.libraries.effects.effects do
		local effect = g_savedata.libraries.effects.effects[effect_index]

		-- if the name of the effect is not the one we're looking for, skip it.
		if effect.name ~= name then
			goto next_effect
		end

		-- if the assigned object type for this effect is not the one we're looking for, skip it.
		if effect.indexing_data.object_type ~= object.object_type then
			goto next_effect
		end

		-- if this is not the object we're looking for, skip it.
		if not table.equals(effect.indexing_data, indexing_data) then
			goto next_effect
		end

		--[[
			this is the effect we're looking to remove
		]]

		-- Remove the effect
		if effect_definition.call_onEffectRemove then
			effect_definition.call_onEffectRemove(object)
		end

		-- remove it from the effects table
		table.remove(g_savedata.libraries.effects.effects, effect_index)

		-- return that we successfully removed it (ugly ass code but this is to avoid eof error)
		do return true, true end

		::next_effect::
	end

	-- effect was not found, so it wasn't removed, however there were no errors.
	return false, true
end

---# Remove all effects from a given object
---@param object table the object to remove the effect from
---@return integer removed_count the number of effects that were removed.
---@return boolean is_success returns false if there was an error in the process of removing the effects
function Effects.removeAll(object)
	-- if the object was never given
	if not object then
		d.print("<line>: Attempted to remove all effects from an object, yet the object given is nil!", true, 1)
		return 0, false
	end

	-- if the object does not contain the object_type param
	if not object.object_type then
		d.print(("<line>: Attempted to remove all effects from an object, But the given object does not contain the object_type field! object_data:\n\"%s\""):format(string.fromTable(object)), true, 1)
		return 0, false
	end

	-- get the indexing data for this object (used to identify which effects in the effects table is for this object)
	local indexing_data, is_success = References.getIndexingData(object)

	-- if getting the indexing data failed
	if not is_success then
		d.print(("<line>: Attempted to remove all effects from an object from an object with type: \"%s\", however getting the indexing data via References.getIndexingData Failed!"):format(object.object_type), true, 1)
		return 0, false
	end

	local remove_count = 0

	--[[
		iterate through all effects in search of the one to remove.
		Start from the top and work down to avoid issues where we will skip effects due to table.remove.
	]]
	for effect_index = #g_savedata.libraries.effects.effects, 1, -1 do
		local effect = g_savedata.libraries.effects.effects[effect_index]

		-- if the assigned object type for this effect is not the one we're looking for, skip it.
		if effect.indexing_data.object_type ~= object.object_type then
			goto next_effect
		end

		-- if this is not the object we're looking for, skip it.
		if not table.equals(effect.indexing_data, indexing_data) then
			goto next_effect
		end

		-- get the effect's definition
		local effect_definition = defined_effects[effect.name]
		
		-- if this effect does not exist.
		if not effect_definition then
			d.print(("<line>: When iterating through all effects for object_type \"%s\", An effect with the name \"%s\" was found in g_savedata, but it doesn't have a definition!"):format(object.object_type, effect.name), true, 1)
			goto next_effect
		end

		--[[
			this is the effect on this object, remove it.
		]]

		-- Remove the effect
		if effect_definition.call_onEffectRemove then
			effect_definition.call_onEffectRemove(object)
		end

		-- remove it from the effects table
		table.remove(g_savedata.libraries.effects.effects, effect_index)

		-- increment the remove count.
		remove_count = remove_count + 1

		::next_effect::
	end

	-- effect was not found, so it wasn't removed, however there were no errors.
	return remove_count, true
end

---# Check if an object has an effect<br>
--- Code is basically the same as Effects.remove, except the effect does not get removed.
---@param object table the object to check if it has the effect
---@param name string the name of the effect to check if the object has
---@return boolean has_effect if the effect was found, returns false if an error occured or if the effect is not on the object.
---@return boolean is_success returns false if there was an error in the process of finding the effect.
function Effects.has(object, name)
	-- get the effect's definition
	local effect_definition = defined_effects[name]
	
	-- if this effect does not exist.
	if not effect_definition then
		d.print(("<line>: Attempted to find effect \"%s\", yet the effect is not defined!"):format(name), true, 1)
		return false, false
	end

	-- if the object does not contain the object_type param
	if not object.object_type then
		d.print(("<line>: Attempted to find effect \"%s\", But the given object does not contain the object_type field! object_data:\n\"%s\""):format(name, string.fromTable(object)), true, 1)
		return false, false
	end

	-- get the indexing data for this object (used to identify which effects in the effects table is for this object)
	local indexing_data, is_success = References.getIndexingData(object)

	-- if getting the indexing data failed
	if not is_success then
		d.print(("<line>: Attempted to find effect \"%s\" from an object with type: \"%s\", however getting the indexing data via References.getIndexingData Failed!"):format(name, object.object_type), true, 1)
		return false, false
	end

	-- iterate through all effects in search of the one we're looking for.
	for effect_index = 1, #g_savedata.libraries.effects.effects do
		local effect = g_savedata.libraries.effects.effects[effect_index]

		-- if the name of the effect is not the one we're looking for, skip it.
		if effect.name ~= name then
			goto next_effect
		end

		-- if the assigned object type for this effect is not the one we're looking for, skip it.
		if effect.indexing_data.object_type ~= object.object_type then
			goto next_effect
		end

		-- if this is not the object we're looking for, skip it.
		if not table.equals(effect.indexing_data, indexing_data) then
			goto next_effect
		end

		--[[
			this is the effect we're looking for.
		]]

		-- return that we successfully found it (ugly ass code but this is to avoid eof error)
		do return true, true end

		::next_effect::
	end

	-- effect was not found, however there were no errors.
	return false, true
end

--[[
	Callbacks
]]

---# onTick
---@param game_ticks integer the number of ticks since the last tick, 1 during normal gameplay, 400 when sleeping.
function Effects.onTick(game_ticks)
	--[[
		iterate through all effects and tick them,
		start at highest index and count down, as when we remove the effects, that will shift the indexes, going top down ensures that we dont get any mixups.
	]]
	for effect_index = #g_savedata.libraries.effects.effects, 1, -1 do
		local effect = g_savedata.libraries.effects.effects[effect_index]

		-- check if this effect has expired
		if effect.expiry and effect.expiry <= g_savedata.tick_counter then
			--[[
				remove this effect
				Seems like it may be a waste to get the object data twice in the same function,
				however only 1 or the other can occur in the same tick, so we don't have to worry
				about making an optimisation system for it.
			]]

			-- get the object's data
			local object, is_success = References.getData(effect.indexing_data)
			
			-- if getting the object's data failed.
			if not is_success then
				d.print(("<line>: Attempted to expire effect \"%s\", yet the object this effect is linked to was not found! indexing_data:\n\"%s\""):format(effect.name, string.fromTable(effect.indexing_data)), true, 1)
				goto next_effect
			end

			-- remove the effect
			Effects.remove(object, effect.name)

			-- go to the next effect
			goto next_effect
		end

		-- get the effect's definition
		local effect_definition = defined_effects[effect.name]

		-- if this effect definition does not exist.
		if not effect_definition then
			d.print(("<line>: Attempted to tick effect \"%s\", yet the effect is not defined!"):format(effect.name), true, 1)
			goto next_effect
		end

		-- only get the object's data if this has a tick function, otherwise its just a waste
		if effect_definition.call_onTick then
			-- get the object's data
			local object, is_success = References.getData(effect.indexing_data)
			
			-- if getting the object's data failed.
			if not is_success then
				d.print(("<line>: Attempted to tick effect \"%s\", yet the object this effect is linked to was not found! indexing_data:\n\"%s\""):format(effect.name, string.fromTable(effect.indexing_data)), true, 1)
				goto next_effect
			end

			-- tick the effect
			effect_definition.call_onTick(object, game_ticks)
		end

		::next_effect::
	end
end