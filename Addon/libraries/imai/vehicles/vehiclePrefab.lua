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

-- Library Version 0.0.3

--[[


	Library Setup


]]

-- required libraries
require("libraries.addon.components.spawning.componentSpawner")
require("libraries.addon.components.tags")

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[ 
	Used to create a prefab of a vehicle, which stores the info to spawn the vehicle

	Also, can be used to find a vehicle you'd like to spawn, specifying filters such as wanting to be red, be land vehicle, and be a sedan, etc.
]]

-- library name
VehiclePrefab = {}

--[[


	Classes


]]

---@class VehiclePrefab
---@field name string The name of the vehicle prefab, as set in the component's name field.
---@field tags Tags The tags of the vehicle prefab, as set in the component's tags field.
---@field transform_offset SWMatrix the transform offset of the vehicle prefab. Useful for trying to have it load in at the right height.
---@field spawning_data SpawningData the spawning data used to spawn the vehicle prefab.
---@field mass number The mass of the vehicle prefab, gotten via spawning the vehicle and getting the mass of the vehicle.
---@field voxels number The voxels of the vehicle prefab, gotten via spawning the vehicle and getting the voxels of the vehicle.
---@field available boolean Whether or not the vehicle prefab is available, if false, that means that this component likely no longer exists.
---@field setup boolean If the prefab has been properly setup, as in, with the mass and voxels set. This is never naturally reset.

---@class PrefabToInitialise
---@field name string the name of the vehicle prefab

---@class PrefabInitialising
---@field name string the name of the vehicle prefab
---@field group_id integer the group_id of the spawning group
---@field awaiting_vehicles table<integer, integer> a list of the vehicle ids that are awaiting to be spawned for initialisation.

--[[


	Constants


]]

-- The maximum number of groups that can be spawned at once to be initialised.
PREFAB_INITIALISER_MAX_GROUPS = 7

-- The height relative to the player at which the vehicles are spawned at.
PREFAB_INITIALISER_RELATIVE_SPAWN_HEIGHT = -1000

--[[


	Variables


]]

g_savedata.vehicle_prefab = {
	---@type table<string, VehiclePrefab> indexed by the name of the vehicle (component name), and stores the prefabs.
	prefabs = {},

	---@type table<integer, PrefabInitialising> indexed by the group_id, and stores the prefabs that are being initialised, stored in g_savedata in case of a script reload.
	initialising_prefabs = {}
}

--- Stores the prefabs that are to be initialised.
---@type table<integer, PrefabToInitialise>
prefabs_to_initialise = {}

--[[


	Functions


]]

--- Function for getting a prefab from it's name.
---@param prefab_name string the name of the prefab to get.
---@return VehiclePrefab|nil the prefab, or nil if it does not exist.
function VehiclePrefab.getPrefab(prefab_name)
	return g_savedata.vehicle_prefab.prefabs[prefab_name]
end

--[[

	Callbacks

]]

--- Function for generating a list of prefabs, should be called in setupMain().
function VehiclePrefab.generatePrefabs()

	-- Despawn prefabs that were being initialised, as they may no longer exist.
	for group_id, prefab_initialising in pairs(g_savedata.vehicle_prefab.initialising_prefabs) do
		-- Despawn the group
		server.despawnVehicleGroup(group_id, true)

		-- Set the prefab's mass and voxels back to 0
		g_savedata.vehicle_prefab.prefabs[prefab_initialising.name].mass = 0
		g_savedata.vehicle_prefab.prefabs[prefab_initialising.name].voxels = 0
	end

	-- Clear the list of initialising prefabs
	---@type table<integer, PrefabInitialising>
	g_savedata.vehicle_prefab.initialising_prefabs = {}

	d.print(("(VehiclePrefab.generatePrefabs) Setting existing prefabs to unavailable."), true, 0)

	-- Go through all existing prefabs, and set their "available" to false, to mark that they may not exist anymore.
	for prefab_index = 1, #g_savedata.vehicle_prefab.prefabs do
		-- Get the prefab
		local prefab = g_savedata.vehicle_prefab.prefabs[prefab_index]

		-- Set it to unavailable
		prefab.available = false
	end

	--- Function for preparing a vehicle prefab and storing it.
	---@param addon_index integer the index of the addon the component is from.
	---@param location_index integer the index of the location the component is from.
	---@param component_index integer the index of the component the vehicle prefab is from.
	---@param location_data SWLocationData the data of the location.
	---@param component_data SWAddonComponentData the data of the component.
	local function prepareAndStorePrefab(addon_index, location_index, component_index, location_data, component_data)

		d.print(("(VehiclePrefab.generatePrefabs) Setting up prefab %s"):format(component_data.display_name), true, 0)
		
		--[[
			Get the spawning data
		]]

		-- First, create the spawning filter
		local spawning_filter = ComponentSpawner.createFilter()

		-- Set the env mod handling to that it cannot be an env mod
		spawning_filter:setEnvModHandling(COMPONENT_FILTER_ENV_MOD_HANDLING.NOT_ALLOWED)

		-- Set the spawning filter's location name to the location name of the component
		spawning_filter:addLocationName(location_data.name, false)

		-- Set the spawning filter's tags to be all of the tags of this component
		for tag_index = 1, #component_data.tags do
			-- Get the tag
			local tag = component_data.tags[tag_index]

			-- Add the tag to the spawning filter
			spawning_filter:addTag(tag, false)
		end

		-- Get the spawning data
		local spawning_data = spawning_filter:getSpawningData(SPAWNING_DATA_FALLBACK.FIRST)

		-- Set the prefab data.
		---@type VehiclePrefab
		local prefab_data = {
			name = component_data.display_name,
			tags = component_data.tags,
			transform_offset = component_data.transform,
			spawning_data = spawning_data,
			mass = 0,
			voxels = 0,
			available = true,
			setup = false
		}

		-- Check if this prefab already exists
		if g_savedata.vehicle_prefab.prefabs[prefab_data.name] then
			-- Get it's existing data
			local existing_prefab = g_savedata.vehicle_prefab.prefabs[prefab_data.name]

			-- If it's setup
			if existing_prefab.setup then

				d.print(("(VehiclePrefab.generatePrefabs) Found existing voxel and mass data for prefab %s"):format(component_data.display_name), true, 0)

				-- Then set the new prefab's setup as true
				prefab_data.setup = true

				-- And set the new prefab's mass and voxels to the existing prefab's mass and voxels
				prefab_data.mass = existing_prefab.mass
				prefab_data.voxels = existing_prefab.voxels
			end
		end

		-- If this prefab is not setup
		if not prefab_data.setup then
			-- Put it into the list of prefabs to initialise
			table.insert(prefabs_to_initialise,
				{
					name = prefab_data.name
				}
			)

			d.print(("(VehiclePrefab.generatePrefabs) Added prefab %s to list of prefabs to initialise."):format(component_data.display_name), true, 0)
		end

		-- Save the prefab.
		g_savedata.vehicle_prefab.prefabs[prefab_data.name] = prefab_data
	end

	--[[
		Go through all components, and check if they're a drivable vehicle (for IMAI), 
		and if so, add them to the list of prefabs.
	]]

	d.print(("(VehiclePrefab.generatePrefabs) Finding and storing prefabs."), true, 0)

	-- The number of prefabs found
	local found_prefabs = 0

	-- Get the number of addons
	local addon_count = server.getAddonCount()

	-- Iterate through all addons.
	for addon_index = 0, addon_count - 1 do

		-- Get the addon's data.
		local addon_data = server.getAddonData(addon_index)

		-- Iterate through all locations in the addon.
		for location_index = 0, addon_data.location_count - 1 do

			-- Get the location's data.
			local location_data = server.getLocationData(addon_index, location_index)

			-- Skip if this location is an env mod, as we only want mission locations
			if location_data.env_mod then
				goto continue_location
			end

			-- Iterate through all components in the location.
			for component_index = 0, location_data.component_count - 1 do

				-- Get the component
				local component_data = server.getLocationComponentData(addon_index, location_index, component_index)

				-- If the component's tags does not contain "imai", skip it
				if not Tags.has(component_data.tags, "imai") then
					goto continue_component
				end

				-- If the component's tags does not contain "vehicle", skip it
				if not Tags.has(component_data.tags, "vehicle") then
					goto continue_component
				end

				-- If the component's tags does not contain "drivable", skip it	
				--if not Tags.hasTag(component_data.tags, "drivable") then
				--	goto continue_component
				--end

				-- Prepare and store the prefab
				prepareAndStorePrefab(addon_index, location_index, component_index, location_data, component_data)

				-- Increment the number of prefabs
				found_prefabs = found_prefabs + 1

				::continue_component::
			end

			::continue_location::
		end
	end

	d.print(("(VehiclePrefab.generatePrefabs) Completed setting up prefabs, found %d prefabs."):format(found_prefabs), true, 0)
end

--- Function for handling the initialisation of prefabs, should be called in onTick()
---@param game_ticks integer the number of ticks since the last onTick call.
function VehiclePrefab.onTick(game_ticks)

	-- If there are no prefabs to initialise, return
	if #prefabs_to_initialise == 0 then
		--d.print("(VehiclePrefab.onTick) No prefabs to initialise.", true, 0)
		return
	end

	--[[
		Get the player we should spawn the prefabs relative to
	]]

	local players = server.getPlayers()

	-- Check if there are any players
	if #players == 0 then
		-- if not, return.
		return
	end

	-- Get the first player in the list, and use them.
	local peer_id = players[1].id

	-- Get their position
	local player_position, is_success = server.getPlayerPos(peer_id)

	-- If that failed, iterate through all players to try to find one that works.
	if not is_success then
		for player_index = 2, #players do
			-- Get the player
			local player = players[player_index]

			-- Get their position
			player_position, is_success = server.getPlayerPos(player.id)

			-- If that succeeded, break
			if is_success then
				break
			end
		end
	end

	-- if even the loop failed, return.
	if not is_success then
		--d.print(("(VehiclePrefab.onTick) Failed to get a player's position to spawn prefabs relative to."), true, 1)
		return
	end

	-- Set the spawning position
	local spawning_position = player_position

	-- Set the spawning position's y to the relative spawn height
	spawning_position[14] = spawning_position[14] + PREFAB_INITIALISER_RELATIVE_SPAWN_HEIGHT

	-- iterate through all of the prefabs to initialise, and spawn them, until we hit the limit, start from the top, as we will be removing them as we go.
	for prefab_index = #prefabs_to_initialise, 1, -1 do
		-- If we've hit the limit, break
		if #g_savedata.vehicle_prefab.initialising_prefabs >= PREFAB_INITIALISER_MAX_GROUPS then
			break
		end

		--[[
			Otherwise, spawn it, and add this prefab to the list of initialising prefabs
		]]

		-- Get this prefab's data
		local prefab_to_initialise = prefabs_to_initialise[prefab_index]

		-- Get the prefab data
		local prefab_data = g_savedata.vehicle_prefab.prefabs[prefab_to_initialise.name]

		-- Print that we're initialising this prefab
		d.print(("(VehiclePrefab.onTick) Initialising Prefab %s"):format(prefab_data.name), true, 0)

		-- Spawn the prefab
		local component_data, component_is_success = ComponentSpawner.spawn(prefab_data.spawning_data, spawning_position)

		-- Print where it was spawned
		--d.print(("(VehiclePrefab.onTick) Spawned prefab %s at\nx: %0.1f\ny: %0.1f\nz:%0.1f"):format(prefab_data.name, spawning_position[13], spawning_position[14], spawning_position[15]), true, 0)

		-- Skip if that failed
		if not component_is_success then
			d.print(("(VehiclePrefab.onTick) Failed to spawn prefab %s, skipping."):format(prefab_data.name), true, 1)

			goto continue_prefab
		end

		--[[
			Get the vehicles in this group, 
			not handling the case where it fails cause well... we would've already spawned it, 
				so just skipping would mean we would just leave it there anyways.
				And if we did skip it, then it wouldn't be removed from the list, resulting it to be spawned again next tick.
				So it's better to have one glitched vehicle rather than infinite glitched vehicles.
		]]
		local vehicle_ids, _ = server.getVehicleGroup(component_data.group_id)

		-- Add this prefab to the list of initialising prefabs
		g_savedata.vehicle_prefab.initialising_prefabs[component_data.group_id] = {
			name = prefab_data.name,
			group_id = component_data.group_id,
			awaiting_vehicles = vehicle_ids
		}

		-- Set all of the vehicle_ids to be invulnerable.
		for vehicle_index = 1, #vehicle_ids do
			-- Get the vehicle_id
			local vehicle_id = vehicle_ids[vehicle_index]

			-- Set the vehicle to be invulnerable
			server.setVehicleInvulnerable(vehicle_id, true)
		end

		-- Remove self from the list of prefabs to initialise
		table.remove(prefabs_to_initialise, prefab_index)

		::continue_prefab::
	end
end

--- Function called whenever a vehicle loads, used for initialising prefabs, automatically bound.
---@param vehicle_id integer the vehicle_id of the vehicle that loaded.
function VehiclePrefab.onVehicleLoad(vehicle_id)
	-- If there are no initialising prefabs, return
	if table.length(g_savedata.vehicle_prefab.initialising_prefabs) == 0 then
		-- Print that there are no initialising prefabs
		--d.print("(VehiclePrefab.onVehicleLoad) No initialising prefabs.", true, 0)
		return
	end

	-- Get the vehicle's data
	local vehicle_data = server.getVehicleData(vehicle_id)

	-- If this group_id does not exist in the list of initialising prefabs, return
	if not g_savedata.vehicle_prefab.initialising_prefabs[vehicle_data.group_id] then
		-- Print that this group_id does not exist in the list of initialising prefabs
		--d.print(("(VehiclePrefab.onVehicleLoad) Group %d does not exist in the list of initialising prefabs."):format(vehicle_data.group_id), true, 0)
		return
	end

	-- Otherwise, get the component data of this vehicle
	local component_data, _ = server.getVehicleComponents(vehicle_id)

	-- Get the name of the component
	local component_name = g_savedata.vehicle_prefab.initialising_prefabs[vehicle_data.group_id].name

	-- Increment the prefab data's mass and voxels with the data
	g_savedata.vehicle_prefab.prefabs[component_name].mass = g_savedata.vehicle_prefab.prefabs[component_name].mass + component_data.mass
	g_savedata.vehicle_prefab.prefabs[component_name].voxels = g_savedata.vehicle_prefab.prefabs[component_name].voxels + component_data.voxels

	-- Despawn this vehicle
	server.despawnVehicle(vehicle_id, true)

	-- Remove this vehicle_id from the list of awaiting vehicles
	for vehicle_index = 1, #g_savedata.vehicle_prefab.initialising_prefabs[vehicle_data.group_id].awaiting_vehicles do
		-- Get the vehicle_id
		local awaiting_vehicle_id = g_savedata.vehicle_prefab.initialising_prefabs[vehicle_data.group_id].awaiting_vehicles[vehicle_index]

		-- If this is the vehicle_id we are looking for
		if awaiting_vehicle_id == vehicle_id then
			-- Remove it from the list
			table.remove(g_savedata.vehicle_prefab.initialising_prefabs[vehicle_data.group_id].awaiting_vehicles, vehicle_index)

			-- Break
			break
		end
	end

	-- If this was the last vehicle to load, then we can set the prefab as setup.
	if #g_savedata.vehicle_prefab.initialising_prefabs[vehicle_data.group_id].awaiting_vehicles == 0 then
		-- Set the prefab as setup
		g_savedata.vehicle_prefab.prefabs[component_name].setup = true

		-- Despawn the group (just in case)
		server.despawnVehicleGroup(vehicle_data.group_id, true)

		-- Remove this group from the list of initialising prefabs
		g_savedata.vehicle_prefab.initialising_prefabs[vehicle_data.group_id] = nil

		d.print(("(VehiclePrefab.onVehicleLoad) Fully initialised prefab %s"):format(component_name), true, 0)
	-- Otherwise, just print that part of it was setup.
	else
		-- Print that part of the prefab has been initialised
		d.print(("(VehiclePrefab.onVehicleLoad) Initialised part of prefab %s"):format(component_name), true, 0)
	end
end

-- Bind the callback to onVehicleLoad, with a low priority.
Binder.bind.onVehicleLoad(VehiclePrefab.onVehicleLoad, 0)

--[[

	Commands

]]

--- Command to reset the "setup" state of the prefabs, for debugging purposes.
Command.registerCommand(
	"reset_prefab_setup_states",
	---@param full_message string the full message
	---@param peer_id integer the peer_id of the sender
	---@param arg table the arguments of the command.
	function(full_message, peer_id, arg)
		-- Iterate through all prefabs
		for prefab_name, prefab in pairs(g_savedata.vehicle_prefab.prefabs) do
			-- Reset setup
			prefab.setup = false

			-- Reset mass to 0
			prefab.mass = 0

			-- Reset voxels to 0
			prefab.voxels = 0

			-- Print that this prefab was reset
			d.print(("(VehiclePrefab.reset_prefab_setup_states) Reset prefab %s's setup state."):format(prefab_name), true, 0, peer_id)
		end

		-- Print that all of them were reset
		d.print("(VehiclePrefab.reset_prefab_setup_states) Reset all prefab setup states.", true, 0, peer_id)
	end,
	"admin",
	"Resets the setup state of all prefabs, for debugging purposes.",
	"Resets the setup state of all prefabs.",
	{""}
)