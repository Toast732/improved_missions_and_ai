--[[


	Library Setup


]]

-- required libraries
require("libraries.debugging")
require("libraries.math")
require("libraries.tags")
require("libraries.zones")

-- library name
Citizens = {}

-- shortened library name
c = Citizens

--[[


	Variables


]]

-- based off from 2021 employment rates in scotland
-- https://www.gov.scot/publications/scotlands-labour-market-people-places-regions-protected-characteristics-statistics-annual-population-survey-2021/pages/4/
local employment_rate = 73.2

-- list of first names
local first_names = {
	"a",
	"b",
	"c"
}

-- list of last names
local last_names = {
	"1",
	"2",
	"3"
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
		min_duration = time.hour*3, -- duration starts once they get to destination
		max_duration = time.hour*8
	}
}

--[[


	Classes


]]

---@class Citizen_Name
---@field first string their first name
---@field last string their last name
---@field full string their first + last name

---@class Citizen
---@field name Citizen_Name

--[[


	Functions


]]

---@param last_name ?string the last name to override, used for if they have a family last name
---@return Citizen_Name Citizen_Name the citizen's name data
function Citizens.generateName(last_name)

	-- generate first name
	local first_name = first_names[math.random(#first_names)]

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

function Citizens.getBestObjectiveZone(citizen, objective_data, valid_zones)

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
end

function Citizens.generateSchedule(citizen)
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
		
		local uses_vehicle = uses_vehicle_rand <= job_data.use_vehicle_chance && uses_vehicle_rand ~= 0

		if uses_vehicle then
		else
			local valid_zones = s.getZones(table.unpack(job_data.no_vehicle.required_zone_tags))

			local objective_zone = Citizens.getBestObjectiveZone(citizen, job_data, valid_zones)
		end
	end
end

function Citizens.create(house)
	local citizen = {
		name = Citizens.generateName(),
		home_data = house
	}

	citizen.schedule = Citizens.generateSchedule(citizen)

	Citizens.setupOOP(citizen)
end

function Citizens.setupOOP(citizen)

	function citizen:setFirstName(first_name)
		self.name.first = first_name
		self.name.full = ("%s %s"):format(first_name, self.name.last)
	end

	function citizen:setLastName(last_name)
		self.name.last = last_name
		self.name.full = ("%s %s"):format(self.name.first, last_name)
	end
end