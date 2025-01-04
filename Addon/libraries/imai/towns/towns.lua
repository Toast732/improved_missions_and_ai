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
require("libraries.addon.callbacks.binder.binder")
require("libraries.imai.towns.town")

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[ 
	Stores and handles the lists of all towns, and also handles the setup of them.
]]

-- library name
Towns = {}

--[[


	Classes


]]

--[[


	Constants


]]

-- The priority of the setupMain callback.
TOWNS_SETUP_MAIN_PRIORITY = 0

-- The town centre zone tag, used to get the towns.
TOWN_CENTRE_ZONE_TAG = "town_centre_zone"

--[[


	Variables


]]

g_savedata.libraries.towns = {
	
	-- The stored towns.
	---@type table<TownID, Town>
	stored_towns = {},

	-- A hashmap to turn the town's name into the town's id.
	---@type table<string, TownID>
	town_name_to_id_hashmap = {},

	-- The next town id.
	---@type TownID
	next_town_id = 1
}

--[[


	Functions


]]

--- Called when setupMain is called.
---@param is_world_create boolean if the world is being created.
function Towns.setupMain(is_world_create)

	-- Print that the towns are being setup.
	d.print("Setting up towns...", true, 0)

	-- Get the town centre zones.
	town_centre_zones = server.getZones(TOWN_CENTRE_ZONE_TAG)

	-- For each town centre zone, check if it's new.
	for _, zone_data in ipairs(town_centre_zones) do
		-- Store if it's new, default true, until found.
		local is_town_new = true

		-- Get the town's name.
		local town_name = Tags.getValue(zone_data.tags, "town", true) --[[@as string]]

		-- Iterate through the stored towns.
		for _, town in ipairs(g_savedata.libraries.towns.stored_towns) do
			-- If the town's name is the same as the zone's name, it's not new.
			if town.name == town_name then
				is_town_new = false
				break
			end
		end

		-- If it's new, create it.
		if is_town_new then
			-- Create the town.
			local new_town = Town.create(g_savedata.libraries.towns.next_town_id, town_name)

			-- Store the town.
			g_savedata.libraries.towns.stored_towns[g_savedata.libraries.towns.next_town_id] = new_town

			-- Save it in the hashmap.
			g_savedata.libraries.towns.town_name_to_id_hashmap[town_name] = g_savedata.libraries.towns.next_town_id

			-- Increment the next town id.
			g_savedata.libraries.towns.next_town_id = g_savedata.libraries.towns.next_town_id + 1

			-- Print that it was created
			d.print(("Town %s was created."):format(town_name), true, 0)
		end
	end

	-- Check if we have a town called Independent, if not, create it.
	if g_savedata.libraries.towns.town_name_to_id_hashmap["Independent"] == nil then
		-- Create the town.
		local new_town = Town.create(g_savedata.libraries.towns.next_town_id, "Independent")

		-- Store the town.
		g_savedata.libraries.towns.stored_towns[g_savedata.libraries.towns.next_town_id] = new_town

		-- Save it in the hashmap.
		g_savedata.libraries.towns.town_name_to_id_hashmap["Independent"] = g_savedata.libraries.towns.next_town_id

		-- Increment the next town id.
		g_savedata.libraries.towns.next_town_id = g_savedata.libraries.towns.next_town_id + 1

		-- Print that it was created
		d.print("Town Independent was created.", true, 0)
	end
end

-- Bind the setupMain callback.
Binder.bind.setupMain(Towns.setupMain, TOWNS_SETUP_MAIN_PRIORITY)