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

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[ 
	Used for individual handling of citizens.
]]

-- library name
Citizen = {}

--[[


	Classes


]]

---@alias CitizenID integer

---@class CitizenName
---@field first string their first name
---@field last string their last name
---@field full string their first + last name

---@class Status
---@field name string the internal name for the status
---@field tooltip string the tooltip for the status
---@field priority number the priority for this status. Highest priority will be shown.

---@class CitizenVehicleData
---@field linked_vehicles table<integer, nil> the vehicles linked to this citizen.
---@field occupating_vehicle_id integer the vehicle_id the citizen is an occupant of. -1 for none.

---@class DirtyCitizen
---@field name CitizenName the citizen's name
---@field transform SWMatrix the citizen's matrix
---@field schedule table the citizen's schedule
---@field outfit_type SWOutfitTypeEnum the citizen's outfit type
---@field object_id integer|nil the citizen's object_id, nil if the citizen has not yet been spawned.
---@field id CitizenID the citizen's ID.
---@field medical_data citizenMedicalData the medical data for the citizen
---@field health number the amount of health the citizen has.
---@field inventory Inventory the inventory of the citizen, use only for reading, use the functions directly when writing to avoid issues with the table not referencing the original.
---@field suppress_next_health_change boolean if the next health change should be suppressed, used to avoid false positives from the addon's health overrides.
---@field object_type "citizen"
---@field statuses table<integer, Status> stores the statuses of the citizen.
---@field vehicle_data CitizenVehicleData
---@field home_building_id BuildingID the building_id of the citizen's home.
---@field jobs table<JobID> the jobs the citizen has.

---@class Citizen: DirtyCitizen a citizen with the OOP functions added.
---@field updateTooltip fun(self: Citizen) Updates the citizen's tooltip.
---@field updateStability fun(self: Citizen) Updates the citizen's stability.
---@field getJobDesire fun(self: Citizen, job: AIJob): number Gets how much the citizen wants the job.

--[[


	Constants


]]

--[[


	Variables


]]

-- minimum and maximum sleep duration
local sleep_duration_parametres = {
	min = 5,
	max = 11
}

--[[


	Functions


]]

---@param transform SWMatrix
---@param outfit_type SWOutfitTypeEnum
---@return Citizen citizen the new citizen
function Citizen.create(transform, outfit_type)
	---@type DirtyCitizen
	local citizen = {
		name = Citizens.generateName(),
		transform = transform,
		schedule = {},
		outfit_type = outfit_type,
		object_id = nil,
		id = g_savedata.libraries.citizens.next_citizen_id,
		health = 100,
		medical_data = {
			medical_conditions = {},
			required_treatments = {},
			stability = Modifiables.prepare({}, 100),
			incapacitated = false
		},
		inventory = Inventory.create(), -- READ ONLY (May change to only store the inventory id at some point)
		suppress_next_health_change = false,
		object_type = "citizen",
		statuses = {},
		vehicle_data = {
			linked_vehicles = {},
			occupating_vehicle_id = -1
		},
		home_building_id = -1,
		jobs = {}
	}

	-- register the medical conditions.
	for medical_condition_name, medical_condition_data in pairs(medical_conditions) do
		citizen.medical_data.medical_conditions[medical_condition_name] = {
			name = medical_condition_name,
			display_name = "",
			custom_data = table.copy.deep(medical_condition_data.custom_data),
			hidden = medical_condition_data.hidden
		}
	end

	g_savedata.libraries.citizens.next_citizen_id = g_savedata.libraries.citizens.next_citizen_id + 1

	table.insert(g_savedata.libraries.citizens.citizen_list, citizen)

	return Citizen.setup(citizen)
	
	--citizen.schedule = Citizens.generateSchedule(citizen)
end

--- Adds the oop functions to the citizen.
---@param citizen DirtyCitizen|Citizen the citizen to add the oop functions to
---@return Citizen citizen the citizen with the oop functions added
function Citizen.setup(citizen)
	---@cast citizen Citizen

	--[[
	
		Setup the general functions

	]]
	
	---# Update a citizen's tooltip.
	---@param self Citizen
	citizen.updateTooltip = function(self)
		-- Define the tooltip string.
		local tooltip = "\n"

		-- Get the highest priority status for this citizen.
		local highest_status = Citizens.Status.getHighest(citizen)
		if highest_status.tooltip ~= "" then
			-- add the status at the top of the tooltip
			tooltip = ("%s%s\n"):format(tooltip, highest_status.tooltip)
		end

		-- Add the citizen's name to the tooltip
		tooltip = tooltip..citizen.name.full

		-- Add their medical conditions to the tooltip
		tooltip = ("%s\n\n%s"):format(tooltip, medicalCondition.getTooltip(citizen))

		-- Always end the tooltip with a new line, if it doesn't
		local tooltip_length = tooltip:len()
		if tooltip:sub(tooltip_length, tooltip_length) ~= "\n" then
			tooltip = tooltip.."\n"
		end

		-- Set their tooltip.
		server.setCharacterTooltip(citizen.object_id, tooltip)
	end

	--[[

		Setup the medical functions

	]]

	---# Updates the citizen's data based on their stability, such as cardiac arrest.
	---@param self Citizen
	citizen.updateStability = function(self)
		local stability = Modifiables.get(self.medical_data.stability)

		-- if the stability is 0 or less, then give the citizen cardiac arrest
		if stability <= 0 then
			-- if the citizen doesn't already have cardiac arrest
			if not citizen.medical_data.medical_conditions.cardiac_arrest.custom_data.cardiac_arrest then
				medicalCondition.assignCondition(citizen, "cardiac_arrest", true)
			end
		end
	end

	--[[
	
		Setup the Job Related Functions
		
	]]

	---# Gets how much the citizen wants the job.
	---@param self Citizen
	---@param job AIJob the job to get the desire for
	---@return number desire the desire for the job.
	citizen.getJobDesire = function(self, job)

		-- Get the usable prop for the job.
		local prop = g_savedata.libraries.usable_props.props[job.usable_prop_id]

		-- Get the citizen's home.
		local home_building = g_savedata.libraries.buildings.stored_buildings[self.home_building_id]

		-- get the distance to the job.
		local distance = matrix.xzDistance(home_building.transform, prop.transform)

		-- Set the base desire to 1.
		local desire = 1

		-- If the citizen is already working, then multiply the desire by 0.5, for each job they have.
		for _ in pairs(self.jobs) do
			desire = desire * 0.5
		end

		-- Make the desire multiplier affected by the citizen's distance. (from *1 at 0m away, to *0.5 at 25,000m away)
		desire = desire * math.linearScale(distance, 0, 25000, 1, 0.5)

		-- Return the desire.
		return desire
	end

	return citizen
end

---@param citizen Citizen the cititzen to spawn
---@return boolean was_spawned if the citizen was spawned
function Citizen.spawn(citizen)

	-- citizen is already spawned.
	if citizen.object_id then
		return false
	end

	-- spawn the citizen
	local object_id, is_success = server.spawnCharacter(citizen.transform, citizen.outfit_type)

	-- the citizen was saved (They failed to spawn, they were saved from the sw community)
	if not is_success then
		d.print(("Failed to spawn citizen, outfit type: %s, transform: %s"):format(citizen.outfit_type, string.fromTable(citizen.transform)), true, 1)
		return false
	end

	-- citizen was spawned (Good luck.)
	citizen.object_id = object_id

	-- update their tooltip
	citizen:updateTooltip()

	return true
end

--- Ticks the citizen.
---@param citizen Citizen the citizen to tick
---@param game_ticks integer the amount of game ticks that have passed
function Citizen.tick(citizen, game_ticks)

	-- update their transform
	local new_transform, is_success = server.getObjectPos(citizen.object_id)

	-- ensure it was gotten.
	if is_success then
		citizen.transform = new_transform
	end
	
	--[[
	
		Ticking Citizen's medical system.
	
	]]

	do
		-- detect changes in their health
		local object_data = server.getObjectData(citizen.object_id)

		if not citizen.medical_data.medical_conditions.burns.custom_data.degree then
			citizen.medical_data.medical_conditions.burns.custom_data = {
				degree = 0, -- the degree of the burn
				affected_area = 0, -- the % of their body that is covered in the burn
				burn_temp = 0, -- the temperature of the burn 
				burn_decay = 0
			}
		end

		-- Update the citizen's stability.
		citizen:updateStability()

		-- just ensure the data isn't bad to avoid an error
		if object_data and object_data.hp then
			local health_change = object_data.hp - citizen.health

			-- the citizen's health changed
			if health_change ~= 0 then
				Citizens.onCitizenDamaged(citizen, health_change)
				-- update the citizen's health
				citizen.health = object_data.hp
			end
		else
			d.print(("<line>: Failed to get object_data for citizen \"%s\""):format(citizen.name.full), false, 1)
		end

		-- tick their medical conditions
		medicalCondition.onTick(citizen, game_ticks)

		-- check if this citizen has the applying_first_aid effect.
		local applying_first_aid, _ = Effects.has(citizen, "applying_first_aid")

		if citizen.medical_data.incapacitated then -- if the citizen should be incapacitated
			if not object_data.incapacitated then -- if the citizen should be incapacitated, but isn't
				server.killCharacter(citizen.object_id)
				d.print(("Attempting to kill citizen %s"):format(citizen.name.full), false, 0)
			end
		elseif applying_first_aid then
			--server.setCharacterData(citizen.object_id, 50, true, true)
		elseif not applying_first_aid then -- if we're not applying first aid, then allow the health to be overridden.
			if object_data.hp < 97 then -- if the citizen's health is below 97
				server.reviveCharacter(citizen.object_id)
				-- suppress the next health change to avoid it being mistooken for healing
				citizen.suppress_next_health_change = true
			elseif object_data.hp > 97 then

				server.setCharacterData(citizen.object_id, 97, true, true)

				-- suppress the next health change to avoid it being mistooken for taking damage
				citizen.suppress_next_health_change = true
			end
		end
	end -- End ticking medical

	-- Update the citizen's tooltip
	citizen:updateTooltip()

end