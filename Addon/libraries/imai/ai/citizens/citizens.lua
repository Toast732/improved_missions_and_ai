--[[
	
Copyright 2023 Liam Matthews

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

-- required libraries
require("libraries.addon.script.debugging")
require("libraries.utils.math")
require("libraries.tags")
require("libraries.zones")
require("libraries.addon.script.modifiables")

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

-- library name
Citizens = {}

---@alias citizenID integer

--[[


	Variables


]]

g_savedata.libraries.citizens = {
	citizen_list = {}, ---@type table<integer, Citizen>
	next_citizen_id = 1 ---@type citizenID The next citizen ID to assign.
}

--g_savedata.libraries.citizens = g_savedata.libraries.citizens

-- based off from 2021 employment rates in scotland
-- https://www.gov.scot/publications/scotlands-labour-market-people-places-regions-protected-characteristics-statistics-annual-population-survey-2021/pages/4/
local employment_rate = 73.2

--[[
	list of first names

	Some of the names may be imporperly sorted, as some may actually be neutral or not, however
	we cannot get the citizen's gender or specify it, so for right now it doesn't really matter.
]]
local first_names = {
	male = {
		"Anderson",
		"Andre'",
		"Andrew",
		"Andy",
		"Angus",
		"Archie",
		"Arthur",
		"Bearnard",
		"Bhaltair",
		"Blair",
		"Blake",
		"Brody",
		"Bruce",
		"Callum",
		"Cameron",
		"Carr",
		"Clyde",
		"Coby",
		"Colin",
		"Creighton",
		"Cromwell",
		"Dan",
		"Dave",
		"David",
		"Donald",
		"Doug",
		"Douglas",
		"Drew",
		"Eanraig",
		"Evan",
		"Gilbert",
		"Gordan",
		"Grant",
		"Ian",
		"Jack",
		"Kameron",
		"Keith",
		"Kerr",
		"Kirk",
		"Liam",
		"Logan",
		"Ludovic",
		"Malcom",
		"Matthew",
		"Max",
		"Maxwell",
		"Micheal",
		"Mitch",
		"Neill",
		"Ness",
		"Norval",
		"Peydon",
		"Ramsey",
		"Ray",
		"Robert",
		"Ron",
		"Roy",
		"Shawn",
		"Stuart",
		"Travis",
		"Todd",
		"Tom",
		"Troy",
		"Wallace"
	},
	female = {
		"Bonnie",
		"Loran"
	},
	neutral = {
		"Ash",
		"Lindsay",
		"Lindsey",
		"Jamie",
		"Paydon"
	}
}

-- list of last names
local last_names = {
	"Armstrong",
	"Davidson",
	"Douglass",
	"Elliot",
	"Fletcher",
	"Howard",
	"Jackson",
	"Kenney",
	"Kendrick",
	"Laird",
	"MacAlister",
	"MacArthur",
	"MacBeth",
	"MacCallum",
	"MacDonald",
	"Macintosh",
	"MacKendrick",
	"Quinn",
	"Reed",
	"Reid",
	"Smith",
	"Ross",
	"Scott",
	"Tory"
}

-- minimum and maximum sleep duration
local sleep_duration_parametres = {
	min = 5,
	max = 11
}

-- if the distance from this task to the next task is less or equal to this distance (m), then they can just walk.
local walking_distance = 500

-- jobs
local npc_job_list = {
	fisher = {
		vehicle = {
			required_vehicle_tags = {
				"fishing_boat"
			}
		},
		no_vehicle = {
			required_zone_tags = {
				"fishing_dock"
			},
			prefers_local = true, -- if it prefers zones within their town
			prefers_closer = true -- if it prefers zones closer to their home
		},
		use_vehicle_chance = 75, -- chance in % for using a vehicle, 0 for never, 100 for always
		min_distance = 50, -- metres
		max_distance = 3000, -- metres
		--min_duration = time.hour*3, -- duration starts once they get to destination
		--max_duration = time.hour*8
	}
}

--[[


	Classes


]]

---@class CitizenName
---@field first string their first name
---@field last string their last name
---@field full string their first + last name

---@class Citizen
---@field name CitizenName the citizen's name
---@field transform SWMatrix the citizen's matrix
---@field schedule table the citizen's schedule
---@field outfit_type SWOutfitTypeEnum the citizen's outfit type
---@field object_id integer|nil the citizen's object_id, nil if the citizen has not yet been spawned.
---@field id citizenID the citizen's ID.
---@field medical_conditions table<string, medicalCondition> the list of medical conditions that this citizen has.
---@field health number the amount of health the citizen has.
---@field stability Modifiable the stability of the citizen
---@field incapacitated boolean if the citizen is incapacitated, not set by the game but set by medical conditions.

--[[


	Functions


]]

---@param last_name ?string the last name to override, used for if they have a family last name
---@return CitizenName CitizenName the citizen's name data
function Citizens.generateName(last_name)

	local available_first_names = {}
	-- make a list of all names, that way names don't get picked more often just cause theres few names for that gender
	for _, names in pairs(first_names) do
		for name_index = 1, #names do
			table.insert(available_first_names, names[name_index])
		end
	end

	-- generate first name
	local first_name = available_first_names[math.random(#available_first_names)]

	-- only generate last name if not specified
	local last_name = last_name or last_names[math.random(#last_names)]

	-- combine into full name
	local full_name = ("%s %s"):format(first_name, last_name)

	return {
		first = first_name,
		last = last_name,
		full = full_name
	}
end

--[[function Citizens.getBestObjectiveZone(citizen, objective_data, valid_zones)

	local local_zones = {} -- zones within their hometown
	local global_zones = {} -- zones outside of their hometown
	for zone_index, zone_data in pairs(valid_zones) do

		local distance = m.xzDistance(zone_data.transform, citizen.home_data.transform)

		local new_zone_data = zone_data

		new_zone_data.index = zone_index

		new_zone_data.distance = distance

		if Tags.getValue(zone_data.tags, "town", true) == citizen.home_data.town_name then -- if this zone is in their home town
			table.insert(local_zones, new_zone_data)
		else -- if this zone is not in their home town
			table.insert(global_zones, new_zone_data)
		end
	end

	local function checkZones(zones)
		table.sort(zones, function(a, b) return a.distance < b.distance)

		for _, zone_data in ipairs(zones) do
			if not Zones.isReserved(zone_data.index) then
				return zone_data
			end
		end
	end

	checkZones(local_zones)

	checkZones(global_zones)

	d.print("(Citizens.getBestObjectiveZone) failed to find a valid zone!", true, 1)
	return false
end]]

--[[function Citizens.generateSchedule(citizen)
	-- random sleep duration within parametres
	local sleep_duration = math.randomDecimals(sleep_duration_parametres.min, sleep_duration_parametres.max)

	-- floor it to nearest 30m
	sleep_duration = math.floor(sleep_duration*2)*0.5

	local schedule = {
		{
			action = "sleep",
			duration = sleep_duration
		}
	}

	-- if this citizen has a job
	local has_job = math.randomDecimals(0, 100) <= employment_rate

	if has_job then
		-- choose a random job
		local job_data = npc_job_list[math.random(#npc_job_list)]

		local uses_vehicle_rand = math.randomDecimals(0, 100)
		
		local uses_vehicle = uses_vehicle_rand <= job_data.use_vehicle_chance and uses_vehicle_rand ~= 0

		if uses_vehicle then
		else
			local valid_zones = s.getZones(table.unpack(job_data.no_vehicle.required_zone_tags))

			local objective_zone = Citizens.getBestObjectiveZone(citizen, job_data, valid_zones)
		end
	end
end]]

---# Update a citizen's tooltip.
---@param citizen Citizen the citizen who's tooltip to update
function Citizens.updateTooltip(citizen)
	local tooltip = "\n"..citizen.name.full

	-- add their stability bar
	tooltip = ("%s\n\nStability\n|%s|"):format(tooltip, string.toBar(math.min(100, math.max(0, Modifiables.get(citizen.stability)/100)), 16, "=", "  "))
	
	-- add their medical conditions to the tooltip
	tooltip = ("%s\n\n%s"):format(tooltip, medicalCondition.getTooltip(citizen))

	local object_data = server.getObjectData(citizen.object_id)

	tooltip = ("%s\n\nDebug Data\nINCAP O: %s C: %s"):format(tooltip, 
		object_data.incapacitated and "T" or "F",
		citizen.incapacitated and "T" or "F"
	)

	server.setCharacterTooltip(citizen.object_id, tooltip)
end

---# Updates the citizen's data based on their stability, such as cardiac arrest.
function Citizens.updateStability(citizen)
	local stability = Modifiables.get(citizen.stability)

	-- if the stability is 0 or less, than give the citizen cardiac arrest
	if stability <= 0 then
		-- if the citizen doesn't already have cardiac arrest
		if not citizen.medical_conditions.cardiac_arrest.custom_data.cardiac_arrest then
			medicalCondition.assignCondition(citizen, "cardiac_arrest", true)
		end
	end
end

function Citizens.create(transform, outfit_type)
	local citizen = { ---@type Citizen
		name = Citizens.generateName(),
		transform = transform,
		schedule = {},
		outfit_type = outfit_type,
		object_id = nil,
		id = g_savedata.libraries.citizens.next_citizen_id,
		medical_conditions = {},
		health = 100,
		stability = Modifiables.prepare({}, 100),
		incapacitated = false
	}

	

	-- register the medical conditions.
	for medical_condition_name, medical_condition_data in pairs(medical_conditions) do
		citizen.medical_conditions[medical_condition_name] = {
			name = medical_condition_name,
			display_name = "",
			custom_data = table.copy.deep(medical_condition_data.custom_data),
			hidden = medical_condition_data.hidden
		}
	end

	g_savedata.libraries.citizens.next_citizen_id = g_savedata.libraries.citizens.next_citizen_id + 1

	table.insert(g_savedata.libraries.citizens.citizen_list, citizen)

	return citizen
	
	--citizen.schedule = Citizens.generateSchedule(citizen)
end

---@param citizen Citizen the cititzen to spawn
---@return boolean was_spawned if the citizen was spawned
function Citizens.spawn(citizen)

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
	Citizens.updateTooltip(citizen)

	return true
end

function Citizens.remove(citizen)

	-- if this citzen has been spawned
	if citizen.object_id then
		-- despawn the citizen if they exist
		if server.getCharacterData(citizen.object_id) then
			-- despawn the character
			server.despawnObject(citizen.object_id, true)
		end
	end

	-- remove this citizen from the citizen list
	for citizen_index = 1, #g_savedata.libraries.citizens.citizen_list do
		-- if this citizen is the one we're trying to remove
		if g_savedata.libraries.citizens.citizen_list[citizen_index].id == citizen.id then
			-- remove it from g_savedata
			table.remove(g_savedata.libraries.citizens.citizen_list, citizen_index)
			return
		end
	end
end

--[[
	onTick
]]
function Citizens.onTick(game_ticks)
	-- go through all citizens

	--d.print(("#g_savedata.libraries.citizens.citizens_list: %s\n#g_savedata.libraries.citizens.citizens_list: %s"):format(#g_savedata.libraries.citizens.citizen_list, #g_savedata.libraries.citizens.citizen_list), false, 0)
	for citizen_index = 1, #g_savedata.libraries.citizens.citizen_list do
		local citizen = g_savedata.libraries.citizens.citizen_list[citizen_index]

		--d.print("Test", false, 0)

		-- update their transform
		local new_transform, is_success = server.getObjectPos(citizen.object_id)

		-- ensure it was gotten.
		if is_success then
			citizen.transform = new_transform
		end

		--server.setCharacterData(citizen.object_id, 100, true, true)

		-- detect changes in their health
		local object_data = server.getObjectData(citizen.object_id)

		if not citizen.medical_conditions.burns.custom_data.degree then
			citizen.medical_conditions.burns.custom_data = {
				degree = 0, -- the degree of the burn
				affected_area = 0, -- the % of their body that is covered in the burn
				burn_temp = 0, -- the temperature of the burn 
				burn_decay = 0
			}
		end

		Citizens.updateStability(citizen)

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

		if citizen.incapacitated then -- if the citizen should be incapacitated
			if not object_data.incapacitated then -- if the citizen should be incapacitated, but isn't
				server.killCharacter(citizen.object_id)
				d.print(("Attempting to kill citizen %s"):format(citizen.name.full), false, 0)
			end
		elseif object_data.hp < 99 then -- if the citizen's health is below 99, and they're not incapacitated
			server.reviveCharacter(citizen.object_id)
		end

		--[[if citizen.medical_conditions.burns.custom_data.degree < 4 then
			if object_data.hp < 99 then
				server.reviveCharacter(citizen.object_id)
			end
		elseif object_data.dead then
			server.reviveCharacter(citizen.object_id)
			server.setCharacterData(citizen.object_id, 5, true, true)
			d.print(("Attempting to revive %s"):format(citizen.name.full), false, 0)
		elseif not object_data.incapacitated then
			server.killCharacter(citizen.object_id)
		end]]

		-- update their tooltip
		Citizens.updateTooltip(citizen)
	end
end

--[[
	onCitizenDamaged
]]
function Citizens.onCitizenDamaged(citizen, damage_amount)

	local function identifyDamageSource()

		if damage_amount > 0 then
			return ""
		end

		local damages = {
			pistol = -15,
			smg = -16.25,
			rifle = -20,
			speargun = -80
		}
		
		local damage_reduction = 0

		citizen.previous_damages = citizen.previous_damages or {}

		for damage_index = #citizen.previous_damages, 1, -1 do
			local ticks_since = g_savedata.tick_counter - citizen.previous_damages[damage_index]

			-- only tracks to 3 seconds ago (187~ ticks), but cut to 75 as thats when the effect starts to get very little.
			if ticks_since >= 75 then
				table.remove(citizen.previous_damages, damage_index)
				goto next_damage
			end

			-- calculate the damage reduction
			damage_reduction = math.min(5, math.max(0, damage_reduction + 5-(2.1820366458058706*math.log(ticks_since)-3.7543876998534)))

			-- already reached the max damage reduction, so we can break.
			if damage_reduction == 5 then
				break
			end

			::next_damage::
		end

		local closest_damage = math.huge
		local closest_damage_source = "none"
		local closest_damage_diff = math.huge

		for damage_source, damage_source_amount in pairs(damages) do
			local damage_diff = math.abs(damage_source_amount - (damage_amount - damage_reduction))
			if damage_diff < closest_damage_diff then
				closest_damage_diff = damage_diff
				closest_damage = damage_source_amount
				closest_damage_source = damage_source
			end
		end

		d.print(("%s took %0.3f damage, closest match for damage source found was %s with a difference of %0.5f (damage reduction of %0.5f)"):format(
			citizen.name.full,
			damage_amount,
			closest_damage_source,
			closest_damage_diff,
			damage_reduction
		), false, 0)

		table.insert(citizen.previous_damages, g_savedata.tick_counter)

		return closest_damage_source

	end

	local closest_damage_source = identifyDamageSource()

	if damage_amount <= 0 then
		--d.print(("Citizen %s took %s damage.\nticks since last damage: %s\nticks since last health change:%s"):format(citizen.name.full, damage_amount, g_savedata.tick_counter - (citizen.last_damage_tick or 0), g_savedata.tick_counter - (citizen.last_health_change_tick or 0)), false, 0)
		citizen.last_damage_tick = g_savedata.tick_counter
	end
	citizen.last_health_change_tick = g_savedata.tick_counter
	-- update the medical conditions for this citizen
	medicalCondition.onCitizenDamaged(citizen, damage_amount, closest_damage_source)
end

-- intercept onObjectDespawn calls

--[[

	scripts to be put after this one

]]

--[[
	definitions
]]
require("libraries.imai.ai.citizens.dependencies.medical.medicalConditions.medicalCondition")
require("libraries.imai.ai.citizens.definitions.commands")