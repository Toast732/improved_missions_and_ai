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
require("libraries.addon.components.tags")
require("libraries.addon.callbacks.binder.binder")
require("libraries.imai.buildings.building")

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[ 
	Stores the buildings and handles their setup.
]]

-- library name
Buildings = {}

--[[


	Classes


]]

--[[


	Constants


]]

-- The priority of the setupMain callback.
BUILDINGS_SETUP_MAIN_PRIORITY = TOWNS_SETUP_MAIN_PRIORITY + 1

--[[


	Variables


]]

g_savedata.libraries.buildings = {

	-- The stored Buildings.
	---@type table<BuildingID, Building>
	stored_buildings = {},

	-- The next ID to use for a building.
	---@type BuildingID
	next_id = 1
}

--[[


	Functions


]]

--- Called when the main setup is called.
---@param is_world_create boolean if the world is being created.
function Buildings.setupMain(is_world_create)

	-- Set the start time.
	local start_time = server.getTimeMillisec()

	-- Create a new list of buildings, will replace g_savedata.libraries.buildings.stored_buildings.
	---@type table<BuildingID, Building>
	local new_stored_buildings = {}

	-- Define the number of new buildings made.
	local new_buildings_made = 0

	-- Define the number of buildings that were updated.
	local buildings_updated = 0

	-- Get all the building zones.
	local building_zones = server.getZones("building")

	-- Loop through all the buildings.
	for _, building_zone in ipairs(building_zones) do

		-- Store if this building already exists.
		local building_exists = false

		-- Check if the building already exists.
		for _, building in pairs(g_savedata.libraries.buildings.stored_buildings) do
			-- If the building's name is the same as the zone's name, it's not new.
			if building.name == building_zone.name then
				building_exists = true

				building.extra_prefab_data = {}

				-- Update the building's data.
				building = Building.update(building, building_zone)

				-- Store the updated building.
				new_stored_buildings[building.id] = building

				-- Increment the number of buildings updated.
				buildings_updated = buildings_updated + 1

				break
			end
		end

		-- If the building doesn't yet exist, create it.
		if not building_exists then
			-- Create a new building.
			local new_building = Building.create(
				building_zone.name,
				g_savedata.libraries.buildings.next_id,
				building_zone
			)

			-- If the building is nil, then skip it.
			if new_building == nil then
				goto continue
			end

			-- Store the building.
			new_stored_buildings[g_savedata.libraries.buildings.next_id] = new_building

			-- Increment the next ID.
			g_savedata.libraries.buildings.next_id = g_savedata.libraries.buildings.next_id + 1

			-- Print that the building was created.
			d.print(("Building %s created."):format(new_building.name), true, 0)

			-- Increment the number of new buildings made.
			new_buildings_made = new_buildings_made + 1
		end

		::continue::
	end

	-- Set the new stored buildings.
	g_savedata.libraries.buildings.stored_buildings = new_stored_buildings

	d.print(("Buildings Setup! New Buildings Made: %d, Buildings Updated: %d, Time Taken: %dms"):format(
		new_buildings_made,
		buildings_updated,
		Ticks.millisecondsSince(start_time)
	), true, 0)
end

-- Bind the setupMain callback.
Binder.bind.setupMain(Buildings.setupMain, BUILDINGS_SETUP_MAIN_PRIORITY)