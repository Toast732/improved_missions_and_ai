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
require("libraries.addon.components.tags")

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[ 
	Library to get spawning data for a component, and then spawn it from that data.
]]

-- library name
ComponentSpawner = {
	filter = {}
}

--[[


	Classes


]]

---@class SpawningData
---@field addon_index integer the addon index of the component.
---@field location_index integer the location index of the component.
---@field component_index integer the component index of the component.

---@class ComponentFilterSegment
---@field tags Tags the tags to match.
---@field location_names table<int, string> the location names to match.

---@class ComponentFilter
---@field include ComponentFilterSegment the data that must match.
---@field exclude ComponentFilterSegment the data that must not match.
---@field env_mod_handling ComponentFilterEnvModHandlingOptions how to handle env mods. Defaults to COMPONENT_FILTER_ENV_MOD_HANDLING.EITHER
---@field addTag fun(self: ComponentFilter, tag: string, exclude: boolean?) adds a tag to the filter.
---@field addLocationName fun(self: ComponentFilter, location_name: string, exclude: boolean?) adds a location name to the filter.
---@field setEnvModHandling fun(self: ComponentFilter, env_mod_handling: ComponentFilterEnvModHandlingOptions) sets the env mod handling of the filter.
---@field getSpawningData fun(self: ComponentFilter, fallback: SpawningDataFallbackOptions?) gets the spawning data from the filter.

--[[


	Constants


]]

---@enum SpawningDataFallbackOptions
SPAWNING_DATA_FALLBACK = {
	FIRST = 0,
	RANDOM = 1
}

---@enum ComponentFilterEnvModHandlingOptions
COMPONENT_FILTER_ENV_MOD_HANDLING = {
	EITHER = 0, -- can be either an env mod or not.
	REQUIRED = 1, -- required to be an env mod.
	NOT_ALLOWED = 2, -- not allowed to be an env mod.
}

--[[


	Variables


]]

--[[


	Functions


]]

--- Creates a blank filter.
---@return ComponentFilter filter Warning, cannot be stored and g_savedata and should not be.
function ComponentSpawner.createFilter()
	filter = {
		include = {
			tags = {},
			location_names = {}
		}, -- required data, all must match
		exclude = {
			tags = {},
			location_names = {}
		}, -- excluded data, none can match
		env_mod_handling = COMPONENT_FILTER_ENV_MOD_HANDLING.EITHER
	}

	--[[
		add the filter functions.
	]]

	--- Function for adding a tag to a filter.
	---@param self ComponentFilter the filter to add the tag to.
	---@param tag string the tag to add to the filter
	---@param exclude boolean? whether or not to add the tag to the exclude tags. If false or nil, adds to include.
	function filter:addTag(tag, exclude)
		-- if this is an exclude tag
		if exclude then
			-- add it to the exclude list
			table.insert(self.exclude.tags, tag)
		-- otherwise, if this is an include tag
		else
			-- add it to the include list.
			table.insert(self.include.tags, tag)
		end
	end

	--- Function for adding a location name to a filter.
	---@param self ComponentFilter the filter to add the location name to.
	---@param location_name string the location name to add to the filter.
	---@param exclude boolean? whether or not to add the location name to the exclude location names. If false or nil, adds to include.
	function filter:addLocationName(location_name, exclude)
		-- if this is an exclude location name
		if exclude then
			-- add it to the exclude list
			table.insert(self.exclude.location_names, location_name)
		-- otherwise, if this is an include location name
		else
			-- add it to the include list.
			table.insert(self.include.location_names, location_name)
		end
	end

	--- Function for setting the env mod handling of a filter.
	---@param self ComponentFilter the filter to set the env mod handling of.
	---@param env_mod_handling ComponentFilterEnvModHandlingOptions the env mod handling to set.
	function filter:setEnvModHandling(env_mod_handling)
		self.env_mod_handling = env_mod_handling
	end

	--- Function for getting the spawning data from a filter
	---@param self ComponentFilter the filter to get the spawning data from.
	---@param fallback SpawningDataFallbackOptions? the fallback option to use if there is no spawning data found. If nil, defaults to SPAWNING_DATA_FALLBACK.FIRST
	---@return SpawningData spawning_data the spawning data found.
	---@return boolean is_success if the spawning data was found.
	function filter:getSpawningData(fallback)
		-- default fallback option to SPAWNING_DATA_FALLBACK.FIRST
		fallback = fallback or SPAWNING_DATA_FALLBACK.FIRST

		--[[
			Get the spawning data.

			Operation:
				1. Iterate through all addons.
					1.1 Iterate through all locations in the addon.
					1.2 Discard location if it matches any exclude location_names.
					1.3 Discard location if it does not match all of the include location_names.
						1.1.1 Iterate through all components in the location.
						1.1.2 Discard component if any of the tags match any exclude tag.
						1.1.3 Discard component if the tags do not match all of the include tags.
		]]

		---@type table<int, SpawningData> the spawning data found.
		local matching_spawning_data = {}

		-- get the number of addons
		local addon_count = server.getAddonCount()

		-- iterate through all addons
		for addon_index = 0, addon_count - 1 do

			-- get the addon's data
			local addon_data = server.getAddonData(addon_index)

			-- iterate through all locations in this addon
			for location_index = 0, addon_data.location_count - 1 do

				-- get the location's data
				local location_data, location_is_success = server.getLocationData(addon_index, location_index)

				-- discard if location_is_success is false.
				if not location_is_success then
					goto discard_location
				end

				-- if env mod handling is required.
				if self.env_mod_handling == COMPONENT_FILTER_ENV_MOD_HANDLING.REQUIRED then
					-- if this location is not an env mod, discard the location.
					if not location_data.env_mod then
						goto discard_location
					end
				elseif self.env_mod_handling == COMPONENT_FILTER_ENV_MOD_HANDLING.NOT_ALLOWED then
					-- if this location is an env mod, discard the location.
					if location_data.env_mod then
						goto discard_location
					end
				end

				-- go through all of the exclude location names
				for _, exclude_location_name in ipairs(self.exclude.location_names) do
					-- if this location name matches the exclude location name, discard the location.
					if location_data.name:match(exclude_location_name) then
						goto discard_location
					end
				end

				-- go through all of the include location names
				for _, include_location_name in ipairs(self.include.location_names) do
					-- if this location name does not match the include location name, discard the location.
					if not location_data.name:match(include_location_name) then
						goto discard_location
					end
				end

				-- go through all components in this location
				for component_index = 0, location_data.component_count - 1 do

					-- get the component's data
					local component_data, component_is_success = server.getLocationComponentData(addon_index, location_index, component_index)
				
					-- discard if component_is_success is false.
					if not component_is_success then
						goto discard_component
					end

					-- go through all exclude tags
					for _, exclude_tag in ipairs(self.exclude.tags) do
						-- if this component has the exclude tag, discard the component.
						if Tags.has(component_data.tags, exclude_tag) then
							goto discard_component
						end
					end

					-- go through all include tags
					for _, include_tag in ipairs(self.include.tags) do
						-- if this component does not have the include tag, then exclued the component.
						if not Tags.has(component_data.tags, include_tag) then
							goto discard_component
						end
					end

					-- add this as matching spawning data.
					table.insert(matching_spawning_data, 
						{
							addon_index = addon_index,
							location_index = location_index,
							component_index = component_index
						}
					)
					::discard_component::
				end
				::discard_location::
			end
		end

		-- get the number of matches
		local match_count = #matching_spawning_data

		-- if there are no matches, return that it failed
		if match_count == 0 then
			return {
				addon_index = 0,
				location_index = 0,
				component_index = 0
			}, false
		end

		-- if the fallback option is SPAWNING_DATA_FALLBACK.FIRST
		if fallback == SPAWNING_DATA_FALLBACK.FIRST then
			-- return the first match
			return matching_spawning_data[1], true
		-- otherwise, this is using the random fallback.
		else
			-- return a random match
			return matching_spawning_data[math.random(1, match_count)], true
		end
	end

	return filter
end

--- Spawns a component from the spawning data.
---@param spawning_data SpawningData the spawning data to spawn the component from.
---@param matrix SWMatrix the matrix to spawn the component at.
---@param parent_vehicle_id integer? optional parent's vehicle_id to parent to.
---@return SWAddonComponentSpawned component_data
---@return boolean is_success
function ComponentSpawner.spawn(spawning_data, matrix, parent_vehicle_id)

	-- spawn the component
	local component_data, is_success = server.spawnAddonComponent(
		matrix,
		spawning_data.addon_index,
		spawning_data.location_index,
		spawning_data.component_index,
		parent_vehicle_id
	)

	-- return data
	return component_data, is_success
end