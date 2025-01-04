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

-- Library Version 0.0.2

--[[


	Library Setup


]]

-- required libraries
require("libraries.addon.components.tags")
require("libraries.imai.towns.towns")
require("libraries.imai.towns.town")

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[ 
	Defines the data for buildings.
]]

-- library name
Building = {}

--[[


	Classes


]]

---@alias BuildingID integer

---@alias BuildingTypes table<BuildingType, boolean>

--[[

	Prefab Data

]]

---@class ExtraBuildingPrefabData

--- RESIDENTIAL
---@class ResidentialBuildingPrefabData: ExtraBuildingPrefabData
---@field max_residents integer The maximum number of residents that can live here.

--- WORKPLACE
---@class WorkplaceBuildingPrefabData: ExtraBuildingPrefabData
---@field max_workers integer The maximum number of workers that can work here.
---@field jobs integer The number of ai jobs here.
---@field start_time number The time the workplace opens.
---@field end_time number The time the workplace closes.
---@field total_hours number The total hours the workplace is open.

--[[
	DATA
]]

---@class ExtraBuildingData

--- WORKPLACE
---@class WorkplaceBuildingData: ExtraBuildingData
---@field ai_jobs table<AIJobID> The AI jobs within this workplace, set by aiJob.lua.

---@class Building
---@field id BuildingID The ID of the building.
---@field town_id TownID The ID of the town this building is in.
---@field asset_id AssetID the id of this asset.
---@field name string The name of the building.
---@field transform SWMatrix The transform of the building.
---@field size Vector3 The size of the building.
---@field types BuildingTypes The types this building is.
---@field extra_prefab_data table<BuildingType, ExtraBuildingPrefabData> The extra prefab data for this building.
---@field extra_data table<BuildingType, ExtraBuildingData> The extra data for this building.
---@field usable_props UsablePropHashmap The props within this building.

--[[


	Constants


]]

---@enum BuildingType
BUILDING_TYPE = {
	RESIDENTIAL = 1,
	WORKPLACE = 2
}

--[[


	Variables


]]

--[[


	Functions


]]

-- Function to create a new building.
---@param name string The name of the building.
---@param building_id BuildingID The ID of the building.
---@param zone_data SWZone The zone data for the building.
---@return Building? building The new building, nil upon error.
function Building.create(name, building_id, zone_data)

	-- Get the town this building is in.
	local town_name = Tags.getValue(zone_data.tags, "town", true) --[[@as string]]

	-- Get the town id.
	local town_id = g_savedata.libraries.towns.town_name_to_id_hashmap[town_name]

	-- If the town id is nil, then return nil.
	if not town_id then
		
		-- Print an error.
		d.print(("The town %s does not exist."):format(town_name), true, 1)

		return
	end

	---@type Building
	local building = {
		id = building_id,
		town_id = town_id,
		asset_id = HoldableAssetManager.Asset.new(),
		name = name,
		transform = zone_data.transform,
		size = Vector3.new(zone_data.size.x, zone_data.size.y, zone_data.size.z),
		types = {},
		extra_prefab_data = {},
		extra_data = {},
		usable_props = {}
	}
	
	-- Update the building's data.
	building = Building.update(building, zone_data)

	-- Add the building to the town.
	Town.addBuilding(g_savedata.libraries.towns.stored_towns[town_id], building)

	return building
end

--- Updates the building's data.
---@param building Building The building to update.
---@param zone_data SWZone The zone data for the building.
---@return Building building The updated building.
function Building.update(building, zone_data)

	-- Update the building's size.
	building.size = Vector3.new(zone_data.size.x, zone_data.size.y, zone_data.size.z)

	-- Update the building's transform.
	building.transform = zone_data.transform

	-- Add the props to the building
	building = Building.addProps(building)

	-- Function for getting the types this building is.
	---@return BuildingTypes types The types this building is.
	local function getBuildingTypes()

		-- Create the list of types.
		local building_types = {}

		-- For each type, check if we have a tag for it.
		for type_name, type_enum in pairs(BUILDING_TYPE) do
			-- Set it to if we've got this tag.
			building_types[type_enum] = Tags.has(zone_data.tags, type_name)
		end

		return building_types
	end

	-- Update the building's types.
	building.types = getBuildingTypes()

	--[[
		NORMAL DATA
	]]

	-- Functions for creating the extra data for the building.
	local extra_data_builders = {
		[BUILDING_TYPE.WORKPLACE] = function()
			return {
				ai_jobs = {}
			}
		end
	}

	--[[
		PREFAB DATA
	]]

	-- Functions for creating the extra prefab data for the building.
	local extra_prefab_data_builders = {
		[BUILDING_TYPE.RESIDENTIAL] = function()

			-- Get the number of beds this building has, and use that for the max residents.

			-- Define the bed count.
			local bed_count = 0

			-- Iterate through all usable props in this building.
			for _, usable_prop_id in ipairs(building.usable_props) do
				-- Get the usable prop.
				local usable_prop = g_savedata.libraries.usable_props.props[usable_prop_id]

				-- If the usable prop is a bed, then add the prop's capacity to the bed count.
				if usable_prop.type == USABLE_PROP_TYPE.BED then
					bed_count = bed_count + usable_prop.capacity
				end
			end

			return {
				max_residents = bed_count
			}
		end,
		[BUILDING_TYPE.WORKPLACE] = function()

			-- Get the number of job props this building has, and use that for the max workers.

			-- Define the job prop count.
			local job_prop_count = 0

			local position_count = 0

			-- Iterate through all usable props in this building.
			for _, usable_prop_id in ipairs(building.usable_props) do
				-- Get the usable prop.
				local usable_prop = g_savedata.libraries.usable_props.props[usable_prop_id]

				-- If the usable prop is a job prop, then add the prop's positions to the job prop count.
				if usable_prop.type == USABLE_PROP_TYPE.AI_JOB then
					job_prop_count = job_prop_count + usable_prop.capacity

					-- Add the positions to the position count.
					position_count = position_count + (Tags.getValue(usable_prop.tags, "positions", false) --[[@as number]] or 1)
				end
			end

			-- Get the time the workplace opens and closes.
			local start_time = Tags.getValue(zone_data.tags, "opens", false) --[[@as number]] or 0

			local end_time = Tags.getValue(zone_data.tags, "closes", false) --[[@as number]] or 0

			-- Get the total hours the workplace is open.
			local total_hours = 0

			d.print(zone_data.tags, true, 0)

			-- If the job works past midnight (end time is less than start time), then add the hours from the start time to midnight.
			if end_time < start_time then
				total_hours = 24 - start_time
			-- Otherwise, just add the hours from the start time to the end time.
			else
				total_hours = end_time - start_time
			end


			return {
				max_workers = job_prop_count,
				jobs = job_prop_count,
				start_time = start_time,
				end_time = end_time,
				total_hours = total_hours
			}
			
		end
	}

	-- For each type this building is, create it's extra prefab, and extra data.
	for type, is_type in pairs(building.types) do
		-- If this building is this type, then create the extra prefab data.
		if is_type then

			-- Get the extra data builder
			local extra_data_builder = extra_data_builders[type]

			-- Ensure we got this type
			if extra_data_builder then
				-- Add the data via the builder.
				building.extra_prefab_data[type] = extra_data_builder()
			end

			-- Get the prefab builder
			local extra_prefab_data_builder = extra_prefab_data_builders[type]

			-- If we don't have a builder, then skip this type.
			if not extra_prefab_data_builder then
				goto continue
			end
			
			-- Add the data via the builder.
			building.extra_prefab_data[type] = extra_prefab_data_builder()
		end

		::continue::
	end

	-- Return the building.
	return building
end

--- Sets the props within this building.
---@param building Building The building to set the props for.
---@return Building building The building with the props set.
function Building.addProps(building)
	
	-- Reset the usable props property.
	building.usable_props = {} --[[@as UsablePropHashmap]]

	-- Iterate through all usable props.
	for _, usable_prop_id in ipairs(g_savedata.libraries.usable_props.iterable_props) do
		-- Get the usable prop.
		local usable_prop = g_savedata.libraries.usable_props.props[usable_prop_id]

		-- If the usable prop is within this building, then add it.
		if server.isInTransformArea(
			usable_prop.transform,
			building.transform,
			building.size.x,
			building.size.y,
			building.size.z
		) then
			table.insert(building.usable_props, usable_prop_id)
		end
	end

	-- Return the building.
	return building
end

--- Checks if this building has a prop by the prop's ID.
---@param building Building The building to check.
---@param prop_id UsablePropID The ID of the prop to check.
---@return boolean has_prop If the building has the prop.
function Building.hasProp(building, prop_id)

	-- Iterate through each prop.
	for _, usable_prop_id in ipairs(building.usable_props) do

		-- Check if the IDs match.
		if usable_prop_id == prop_id then

			-- If they do, return true.
			return true
		end
	end

	-- If we've exhuasted the list, then we don't have it, so return false.
	return false
end

--- Checks if this building is the specified type
---@param building Building The building to check.
---@param building_type BuildingType The type to check.
---@return boolean is_type If the building is the specified type.
function Building.isType(building, building_type)
	return building.types[building_type]
end

--- Get the workplace data for the building.
---@param building Building The building to get the workplace data for.
---@return WorkplaceBuildingData data The workplace data, nil if the building is not a workplace.
function Building.getWorkplaceData(building)
	return building.extra_data[BUILDING_TYPE.WORKPLACE] --[[@as WorkplaceBuildingData]]
end

-- Get the residential prefab data for the building.
---@param building Building The building to get the residential data for.
---@return ResidentialBuildingPrefabData data The residential data, nil if the building is not residential.
function Building.getResidentialPrefabData(building)
	return building.extra_prefab_data[BUILDING_TYPE.RESIDENTIAL] --[[@as ResidentialBuildingPrefabData]]
end

-- Get the workplace prefab data for the building.
---@param building Building The building to get the workplace data for.
---@return WorkplaceBuildingPrefabData data The workplace data, nil if the building is not a workplace.
function Building.getWorkplacePrefabData(building)
	return building.extra_prefab_data[BUILDING_TYPE.WORKPLACE] --[[@as WorkplaceBuildingPrefabData]]
end