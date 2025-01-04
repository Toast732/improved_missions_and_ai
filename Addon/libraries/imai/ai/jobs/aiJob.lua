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
require("libraries.imai.buildings.buildings")

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[ 
	Handles AI Jobs individually.

	An AI Job can be duplicated, for example, if a building has 2 office positions, the jobs are the same,
		But the objects for the job are seperate, that way it can be handled specifically for that citizen,
		that way it's easy to control things like their individual performance, for wage and such.
]]

-- library name
AIJob = {}

--[[


	Classes


]]

---@alias AIJobID integer

---@class JobHours The hours that this job is for.
---@field start_time number The start hour of the job.
---@field end_time number The end hour of the job.

---@class DirtyAIJob
---@field id AIJobID The ID of the job.
---@field usable_prop_id UsablePropID The ID of the usable prop for the job.
---@field title string The name of the job.
---@field paygrade AIJobPaygrade The paygrade of the job.
---@field worker CitizenID? The worker in the job, if there is one.
---@field building BuildingID The building the job is in.
---@field performance AIJobPerformance The performance of the worker in the job.
---@field company CompanyID The company the job is for.
---@field position_index integer The index of the position in the prop. starting at 1, used to split how long the worker will be working by the number of positions.
---@field hours JobHours The hours the job is for.

---@class AIJob: DirtyAIJob
---@field getPay fun(self: AIJob, hours_worked: number): number The function for getting the pay for the worker.
---@field assignCitizen fun(self: AIJob, citizen_id: CitizenID): boolean The function for assigning a citizen to the job, returns false if the job is already filled.
---@field unassignCitizen fun(self: AIJob): boolean The function for unassigning a worker from the job, returns false if the job is not filled.
---@field getFit fun(self: AIJob, citizen_id: CitizenID): number Gets how well the citizen fits for the job, returns a number from 0-1. (0 being the worst, 1 being the best.
---@field getNameIdentifier fun(self: AIJob): string Gets the name identifier for the job, includes workplace name, job title, and position index.

--- How an individual employee is performing in their job, used for things like wage increases, and promotions.
---@class AIJobPerformance
---@field raise_performance number Their performance in the job which counts towards a raise, requires to be 1 or more to get the raise, after, it's reset.
---@field promotion_performance number Their performance in the job which counts towards a promotion, does not reset.
---@field repremands number The number of repremands the worker has had, if they have too many, they will be fired.

--[[


	Constants


]]

--- Paygrades, converts an integer number to their wage. Wages are in Pound Sterling.
---@enum AIJobPaygrade
AI_JOB_PAYGRADES = {
	--[[
		Minimum wage for those under 18: https://www.gov.uk/national-minimum-wage-rates

		For those above 18, it will automatically be bumped up to their minimum wage.
	]]
	[1] = 6.4, -- Absolute Minimum, Shouldn't be used frequently.
	[2] = 10.4, -- Around average for Sales and Customer Service Occupations
	[3] = 14, -- Around average for Skilled Trades
	[4] = 17, -- Inbetween.
	[5] = 21, -- Around average for managers, directors, etc.
	[6] = 25, -- Extra.
	[7] = 30, -- Extra.
	[8] = 35 -- Extra.
}

--[[


	Variables


]]

--[[


	Functions


]]

-- Function for creating a new job from the usable prop's data
---@param usable_prop UsableProp The usable prop for the job.
---@param position_index number The index of the position in the prop. starting at 1, used to split how long the worker will be working by the number of positions.
function AIJob.create(usable_prop, position_index)

	-- Get the ID to use.
	local id = g_savedata.libraries.ai_jobs.next_id

	-- Find the building this prop is in.
	---@type BuildingID|nil
	local job_building_id = nil

	-- Iterate through the buildings to find the building.
	for _, building_data in pairs(g_savedata.libraries.buildings.stored_buildings) do

		-- If the building has the prop, set it.
		if Building.hasProp(building_data, usable_prop.id) then
			job_building_id = building_data.id
			break
		end
	end

	-- If the building was not found, print an error and return.
	if not job_building_id then
		d.print(("<line>: (AIJob.create) Error: Failed to find the building for the job prop with the ID of."):format(
			usable_prop.id
		), true, 1)
		return
	end

	-- Create the new job.
	---@type DirtyAIJob
	local new_job = {
		id = id,
		usable_prop_id = usable_prop.id,
		title = usable_prop.name,
		paygrade = AI_JOB_PAYGRADES[1],
		worker = nil,
		building = job_building_id,
		performance = {
			raise_performance = 0,
			promotion_performance = 0,
			repremands = 0
		},
		---@diagnostic disable-next-line: assign-type-mismatch
		company = 0,
		position_index = position_index,
		hours = {
			start_time = 0,
			end_time = 0
		}
	}

	-- Increment the next ID.
	g_savedata.libraries.ai_jobs.next_id = g_savedata.libraries.ai_jobs.next_id + 1

	-- Get the job's workplace data.
	local workplace_data = Building.getWorkplaceData(g_savedata.libraries.buildings.stored_buildings[job_building_id])

	-- Make sure we got the data.
	if workplace_data then
		-- Set the job in the workplace data.
		table.insert(workplace_data.ai_jobs, new_job.id)
	end

	-- Return the new job after updating it.
	return AIJob.clean(new_job)
end

-- Function for updating a job's data, used upon reload.
---@param job DirtyAIJob|AIJob The job to update.
---@return AIJob job The updated job.
function AIJob.clean(job)

	-- Get the job's prop.
	local prop = g_savedata.libraries.usable_props.props[job.usable_prop_id]

	-- Update the job's title.
	job.title = prop.name

	-- Update the job's paygrade.

	-- Get the job's paygrade.
	local paygrade = Tags.getValue(prop.tags, "paygrade", false) --[[@as number]] or 1

	job.paygrade = AI_JOB_PAYGRADES[paygrade]

	--[[
		Update the job's hours.
	]]

	-- Get the workplace's prefab data.
	local workplace_prefab_data = Building.getWorkplacePrefabData(g_savedata.libraries.buildings.stored_buildings[job.building])

	-- Get the number of positions the job has.
	local positions = Tags.getValue(prop.tags, "positions", false) --[[@as number]] or 1

	---@return JobHours job_hours The hours the job is for.
	local function getJobHours()
		-- Calculate how long the worker will be working this position for.
		local job_hours = workplace_prefab_data.total_hours / positions

		-- Get the time the worker will start working.
		local start_time = workplace_prefab_data.start_time + (job_hours * (job.position_index - 1))

		-- Get the time the worker will end working.
		local end_time = start_time + job_hours

		-- Return the job hours.
		return {
			start_time = start_time,
			end_time = end_time
		}
	end

	-- Set the job's hours.
	job.hours = getJobHours()

	-- Return the updated job.
	return AIJob.setupOOP(job)
end

--- Function for setting up OOP functions for the job.
---@param job DirtyAIJob|AIJob The job to setup OOP for.
---@return AIJob job The job with OOP functions.
function AIJob.setupOOP(job)

	-- Create the function for getting the worker's pay.
	---@param self AIJob
	---@param hours_worked number The number of hours the worker worked.
	---@return number pay amount the worker should be paid.
	job.getPay = function(self, hours_worked)
		--TODO: Account for age based minimum wage, skipping it for now, as ages are not implemented.
		return self.paygrade * hours_worked
	end

	--- Create the function for assigning a citizen to the job.
	---@param self AIJob
	---@param citizen_id CitizenID The citizen to assign to the job.
	---@return boolean is_success if the citizen was assigned to the job.
	job.assignCitizen = function(self, citizen_id)
		-- If the job is already filled, return false.
		if self.worker then
			return false
		end

		-- Set the worker.
		self.worker = citizen_id

		-- Reset the performance
		self.performance = {
			raise_performance = 0,
			promotion_performance = 0,
			repremands = 0
		}

		-- Return true.
		return true
	end

	--- Create the function for unassigning a worker from a job.
	---@param self AIJob
	job.unassignCitizen = function(self)
		-- If the job is not filled, return false.
		if not self.worker then
			return false
		end

		-- Unassign the worker.
		self.worker = nil

		-- Return true.
		return true
	end

	--- Create the function for getting how well a citizen fits for the job.
	---@param self AIJob
	---@param citizen_id CitizenID The citizen to check against.
	---@return number fit The fit of the citizen for the job, from 0-1.
	job.getFit = function(self, citizen_id)
		--TODO: Implement this function properly.
		return 1
	end

	-- Gets the name identifier for the job, includes workplace name, job title, and position index.
	job.getNameIdentifier = function(self)
		-- Get the workplace name.
		local workplace_name = g_savedata.libraries.buildings.stored_buildings[self.building].name

		-- Return the name identifier.
		return ("%s (Shift %d) at %s"):format(
			self.title,
			self.position_index,
			workplace_name
		)
	end

	-- Return the job.
	return job --[[@as AIJob]]
end