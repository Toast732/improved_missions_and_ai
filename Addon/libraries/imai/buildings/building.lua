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

---@class ExtraBuildingPrefabData

---@class ResidentialBuildingData: ExtraBuildingPrefabData
---@field max_residents integer The maximum number of residents that can live here.

---@class Building
---@field id BuildingID The ID of the building.
---@field town_id TownID The ID of the town this building is in.
---@field name string The name of the building.
---@field transform SWMatrix The transform of the building.
---@field size Vector3 The size of the building.
---@field types BuildingTypes The types this building is.
---@field extra_prefab_data table<BuildingType, ExtraBuildingPrefabData> The extra prefab data for this building.
---@field usable_props UsablePropHashmap The props within this building.

--[[


	Constants


]]

---@enum BuildingType
BUILDING_TYPE = {
	RESIDENTIAL = 1
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
		name = name,
		transform = zone_data.transform,
		size = Vector3.new(zone_data.size.x, zone_data.size.y, zone_data.size.z),
		types = {},
		extra_prefab_data = {},
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
		end
	}

	-- For each type this building is, create it's extra prefab data.
	for type, is_type in pairs(building.types) do
		-- If this building is this type, then create the extra prefab data.
		if is_type then

			-- Get the builder
			local builder = extra_prefab_data_builders[type]

			-- If we don't have a builder, then skip this type.
			if not builder then
				goto continue
			end
			
			-- Add the data via the builder.
			building.extra_prefab_data[type] = builder()
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

--- Checks if this building is the specified type
---@param building Building The building to check.
---@param building_type BuildingType The type to check.
---@return boolean is_type If the building is the specified type.
function Building.isType(building, building_type)
	return building.types[building_type]
end

-- Get the residential data for the building.
---@param building Building The building to get the residential data for.
---@return ResidentialBuildingData data The residential data, nil if the building is not residential.
function Building.getResidentialData(building)
	return building.extra_prefab_data[BUILDING_TYPE.RESIDENTIAL] --[[@as ResidentialBuildingData]]
end