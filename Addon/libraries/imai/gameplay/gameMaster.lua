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
require("libraries.imai.buildings.buildings")
require("libraries.addon.components.usableProps.usableProps")

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[ 
	The Game Master - Controls things like spawning citizens on creation, and other things.
]]

-- library name
GameMaster = {}

--[[


	Classes


]]

--[[


	Constants


]]

-- The priority of the setupMain callback.
GAMEMASTER_SETUP_MAIN_PRIORITY = USABLE_PROPS_SETUP_MAIN_PRIORITY + 1

-- The minimum ratio of citizens to spawn in a house.
CITIZEN_SPAWN_RATIO_MIN = 0.45

-- The maximum ratio of citizens to spawn in a house.
CITIZEN_SPAWN_RATIO_MAX = 1.00

--[[


	Variables


]]

--[[


	Functions


]]

--- Called in the setupMain callback.
function GameMaster.setupMain(is_world_create)

	--TODO: Remove later, for debug, put as todo so it's marked.
	is_world_create = true

	-- If the world was created.
	if is_world_create then
		-- Spawn the citizens.
		GameMaster.spawnCitizens()
	end
end

-- Bind the setupMain callback.
Binder.bind.setupMain(GameMaster.setupMain, GAMEMASTER_SETUP_MAIN_PRIORITY)

--- Spawns the citizens.
function GameMaster.spawnCitizens()
	-- Get all of the towns.
	local towns = g_savedata.libraries.towns.stored_towns

	-- Iterate through all of the towns.
	for town_index, town in ipairs(towns) do
		
		-- In this town, iterate through each building.
		for _, building_id in ipairs(town.buildings) do
			
			-- Get the building
			local building = g_savedata.libraries.buildings.stored_buildings[building_id]

			-- Check if the building is residential.
			if Building.isType(building, BUILDING_TYPE.RESIDENTIAL) then

				-- Get the residential data.
				local residential_data = Building.getResidentialPrefabData(building)
				
				-- Get the number of citizens to spawn.
				local num_citizens = math.random(
					math.floor(residential_data.max_residents * CITIZEN_SPAWN_RATIO_MIN),
					math.floor(residential_data.max_residents * CITIZEN_SPAWN_RATIO_MAX)
				)

				-- For each of the citizens to spawn, get a bed to spawn them in, and spawn them in it.
				for _ = 1, num_citizens do
					-- Find a bed to spawn the citizen in.
					local bed_props = UsableProps.selectRandomPropWithType(
						building.usable_props,
						USABLE_PROP_TYPE.BED,
						1,
						true
					)

					-- If there are no bed props, then skip this citizen.
					if bed_props == nil then
						d.print(("<line>: (GameMaster.spawnCitizens) Failed to find a bed prop in building %s!"):format(building.name), true, 1)
						goto continue
					end

					d.print(("Found Prop: %d"):format(bed_props[1]), true, 0)

					-- Get the bed prop.
					local bed_prop = g_savedata.libraries.usable_props.props[bed_props[1]]

					-- Create the citizen.
					local new_citizen = Citizens.create(
						bed_prop.transform,
						0
					)

					-- Spawn the citizen.
					Citizens.spawn(new_citizen)

					is_success = bed_prop:addEntity(new_citizen.object_id)

					d.print(("Is Success: %s"):format(tostring(is_success)), true, 0)

					d.print(("Test: %s"):format(#g_savedata.libraries.usable_props.props[bed_props[1]].entities), true, 0)

					::continue::
				end
			end
		end
	end
end