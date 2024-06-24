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
require("libraries.addon.callbacks.binder.binder")
require("libraries.addon.components.spawning.componentSpawner") -- Doesn't spawn anything, just used for the filtering it has.
require("libraries.addon.components.zoneLinker")
require("libraries.imai.buildings.buildings")
require("libraries.addon.components.usableProps.usableProp")

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[
	Used to create and get all usable props, such as beds.
]]

-- library name
UsableProps = {}

--[[


	Classes


]]

---@alias UsablePropID integer

---@alias UsableProps table<UsablePropID, UsableProp>

---@alias UsablePropHashmap table<intger, UsablePropID>

--[[


	Constants


]]

-- The priority of the setupMain callback.
USABLE_PROPS_SETUP_MAIN_PRIORITY = BUILDINGS_SETUP_MAIN_PRIORITY - 1

--[[


	Variables


]]

g_savedata.libraries.usable_props = {
	---@type UsableProps the usable props.
	props = {},

	--- Stores the ids of the usable props, but is iterable via ipairs, for enhanced performance.
	---@type table<int, UsablePropID>
	iterable_props = {},

	-- The next usable prop id.
	---@type UsablePropID
	next_id = 1
}

--[[


	Functions


]]

--- Called when setupMain is called.
---@param is_world_create boolean if the world is being created.
function UsableProps.setupMain(is_world_create)

	-- Get the current time so we can figure out how long setting up the props took.
	local start_time = server.getTimeMillisec()

	--[[
		Setup the oop functions for each of the usable props.
	]]

	-- Iterate through each usable prop.
	for _, usable_prop_id in ipairs(g_savedata.libraries.usable_props.iterable_props) do
		-- Update the usable prop's oop functions.
		g_savedata.libraries.usable_props.props[usable_prop_id] = UsableProp.setupOOP(g_savedata.libraries.usable_props.props[usable_prop_id])
	end
	
	-- Create the filter for usable props.
	local usable_prop_filter = ComponentSpawner.createFilter()

	-- Filter it to only components with the tag "usable_prop".
	usable_prop_filter:addTag("usable_prop")

	-- Get all of the usable prop's spawning data.
	local usable_props_spawning_data, got_spawning_data = usable_prop_filter:getAllSpawningData()

	-- If we failed to find any, abort.
	if not got_spawning_data then
		d.print(("<line>: (UsableProps.setupMain) Failed to get any usable prop's spawning data!"), true, 1)
		return
	end

	-- Create a new list of usable props, will replace g_savedata.libraries.usable_props.props.
	---@type UsableProps
	local new_usable_props = {}

	-- Define the number of new props made
	local new_props_made = 0

	-- Define the number of props updated
	local props_updated = 0

	-- Iterate through each usable prop that was found.
	for _, spawning_data in pairs(usable_props_spawning_data) do

		-- Get it's SWAddonComponentData.
		local addon_component_data, is_success = server.getLocationComponentData(
			spawning_data.addon_index,
			spawning_data.location_index,
			spawning_data.component_index
		)

		-- Get it's location data
		local location_data = server.getLocationData(spawning_data.addon_index, spawning_data.location_index)

		-- If the component data was not found, skip.
		if not is_success then
			d.print(("<line>: (UsableProps.setupMain) Failed to get the SWAddonComponentData for the spawning data at addon_index: %d, location_index: %d, component_index: %d!"):format(
				spawning_data.addon_index,
				spawning_data.location_index,
				spawning_data.component_index
			), true, 1)

			goto continue
		end

		-- Get the zone data for the component data.
		local zone_data = ZoneLinker.getZoneData(addon_component_data, location_data)

		-- If the zone data was not found, skip.
		if not zone_data then
			d.print(("<line>: (UsableProps.setupMain) Failed to get the zone data for the SWAddonComponentData at addon_index: %d, location_index: %d, component_index: %d!"):format(
				spawning_data.addon_index,
				spawning_data.location_index,
				spawning_data.component_index
			), true, 1)

			goto continue
		end

		-- Store if we found a match.
		local found_match = false

		-- Iterate through each stored usable prop.
		for _, usable_prop_id in ipairs(g_savedata.libraries.usable_props.iterable_props) do

			-- Get the usable prop.
			local usable_prop = g_savedata.libraries.usable_props.props[usable_prop_id]

			-- If they match, set the match we found.
			if usable_prop:matches(addon_component_data, zone_data) then
				
				-- Set that we found a match.
				found_match = true

				-- Update the usable prop's data, and store it.
				new_usable_props[usable_prop.id] = UsableProp.update(usable_prop, addon_component_data, zone_data)

				props_updated = props_updated + 1

				break
			end
		end

		-- If we didn't find a match, create a new usable prop.
		if not found_match then
			-- Create the new usable prop.
			local new_usable_prop = UsableProp.new(addon_component_data, zone_data)

			new_props_made = new_props_made + 1

			-- If the new usable prop is nil, skip.
			if new_usable_prop == nil then
				goto continue
			end

			-- Store the new usable prop.
			new_usable_props[new_usable_prop.id] = new_usable_prop
		end

		::continue::
	end

	-- Set the new usable props.
	g_savedata.libraries.usable_props.props = new_usable_props

	-- Create the iterable props.
	g_savedata.libraries.usable_props.iterable_props = {}

	-- Iterate through each usable prop.
	for usable_prop_id, _ in pairs(g_savedata.libraries.usable_props.props) do
		-- Store the usable prop id.
		table.insert(g_savedata.libraries.usable_props.iterable_props, usable_prop_id)
	end

	-- Print that the usable props were setup.
	d.print(("Usable Props setup! New Props Made: %d, Props Updated: %d, Time Taken: %dms"):format(
		new_props_made,
		props_updated,
		Ticks.millisecondsSince(start_time)
	), true, 0)
end

--- Selects a random number of props with the given type.
---@param usablePropHashmap UsablePropHashmap The hashmap of usable props to select from.
---@param type UsablePropType The type of prop to select.
---@param amount integer The amount of props to select.
---@param skip_at_capacity boolean If we should skip props that are at capacity.
---@return UsablePropHashmap? usable_props The selected props, nil if failed.
function UsableProps.selectRandomPropWithType(usablePropHashmap, type, amount, skip_at_capacity)
	-- Create a list of props with the given type.
	local props_with_type = {}

	-- Iterate through each usable prop.
	for _, usable_prop_id in ipairs(usablePropHashmap) do
		-- Get the usable prop.
		local usable_prop = g_savedata.libraries.usable_props.props[usable_prop_id]

		-- If the usable prop's type is the same as the given type, add it to the list.
		if usable_prop.type == type then

			-- If we should skip at capacity, and the prop is at capacity, skip.
			if not skip_at_capacity or #usable_prop.entities < usable_prop.capacity then
				table.insert(props_with_type, usable_prop_id)
			end
		end
	end

	-- If we didn't find any, return nil.
	if #props_with_type == 0 then
		d.print(("<line>: (UsableProps.selectRandomPropWithType) Failed to find any props with the type %d!"):format(type), true, 1)
		return nil
	end

	-- If we have less props than the amount, return nil.
	if #props_with_type < amount then
		d.print(("<line>: (UsableProps.selectRandomPropWithType) Failed to find enough props with the type %d!"):format(type), true, 1)
		return nil
	end

	-- Create a new hashmap of the props.
	local selected_props = {}

	-- Select the amount of props.
	for i = 1, amount do
		-- Generate a random number.
		local random_prop_index = math.random(1, #props_with_type)

		-- Get a random prop.
		local random_prop_id = props_with_type[random_prop_index]

		-- Store the prop.
		table.insert(selected_props, random_prop_id)
		
		-- Remove the prop from the list.
		props_with_type[random_prop_index] = nil
	end

	return selected_props
end

--- Returns the hashmap of all usable props with the type.
---@param prop_type UsablePropType The type of prop to get.
---@return UsablePropHashmap? usable_props The hashmap of usable props, nil if failed.
function UsableProps.getPropsWithType(prop_type)
	-- Create a new hashmap of the props.
	---@type UsablePropHashmap
	local props_with_type = {}

	-- Iterate through each usable prop.
	for _, usable_prop_id in ipairs(g_savedata.libraries.usable_props.iterable_props) do
		-- Get the usable prop.
		local usable_prop = g_savedata.libraries.usable_props.props[usable_prop_id]

		-- If the usable prop's type is the same as the given type, add it to the list.
		if usable_prop.type == prop_type then
			table.insert(props_with_type, usable_prop_id)
		end
	end

	-- If we didn't find any, return nil.
	if #props_with_type == 0 then
		d.print(("<line>: (UsableProps.getPropsWithType) Failed to find any props with the type %d!"):format(prop_type), true, 1)
		return nil
	end

	return props_with_type
end

-- Bind the setupMain callback.
Binder.bind.setupMain(UsableProps.setupMain, USABLE_PROPS_SETUP_MAIN_PRIORITY)