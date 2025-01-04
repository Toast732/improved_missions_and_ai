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

-- Library Version 0.0.1

--[[


	Library Setup


]]

-- required libraries
require("libraries.addon.script.time.gameTimestamp")
require("libraries.imai.ai.citizens.dependencies.scheduling.tasks.citizenScheduleTasks")

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[ 
	Used for citizen scheduling, where it generates and handles the citizen's schedule.
]]

-- library name
CitizenSchedule = {}

--[[


	Classes


]]

---@class CitizenSchedule: DirtyCitizenSchedule
---@field generateSchedule fun(self: CitizenSchedule) Generates the next tasks for the citizen.
---@field tick fun(self: CitizenSchedule) Ticks the schedule.

---@class DirtyCitizenSchedule
---@field tasks table<integer, CitizenScheduleTaskBase> The list of tasks in the schedule, removed when they are completed.
---@field citizen_id CitizenID The id of the citizen this schedule is for.

--[[


	Constants


]]

--[[


	Variables


]]

--[[


	Functions


]]

--- Function for creating a new CitizenSchedule
--- @return CitizenSchedule
function CitizenSchedule.new(citizen_id)
	-- create the schedule
	---@type DirtyCitizenSchedule
	local schedule = {
		tasks = {},
		citizen_id = citizen_id
	}

	-- return the schedule
	return CitizenSchedule.clean(schedule)
end

--- Function for cleaning a schedule, where it will add the oop functions (used upon reload)
---@param schedule DirtyCitizenSchedule|CitizenSchedule
---@return CitizenSchedule
function CitizenSchedule.clean(schedule)

	-- Clear the existing schedule.
	schedule.tasks = {}

	--- Function for generating the next tasks for the citizen
	---@param self CitizenSchedule
	schedule.generateSchedule = function(self)

		-- get the current timestamp, used for what we will be generating from.
		local current_timestamp = GameTimestamp.now()

		-- Clear the existing schedule.
		self.tasks = {}

		--[[

			Generate the tasks.

		]]

		-- Get the citizen.
		local citizen = Citizens.getData(self.citizen_id)

		-- If the citizen is nil, then return.
		if citizen == nil then
			d.print(("<line> (CitizenSchedule.generateSchedule) Error: Failed to get the citizen with id %d."):format(self.citizen_id), true, 1)
			return
		end

		-- Get today's timestamp.
		local today_timestamp = GameTimestamp.today()

		--[[
			Account for the citizen's jobs.
		]]

		for job_index = 1, #citizen.jobs do
			local job = g_savedata.libraries.ai_jobs.jobs[citizen.jobs[job_index]]

			-- Get the job's start time for today.
			local job_start_time = GameTimestamp.hoursToTimestamp(job.hours.start_time) + today_timestamp

			-- Get the job's end time for today.
			local job_end_time = GameTimestamp.hoursToTimestamp(job.hours.end_time) + today_timestamp

			-- If the job goes into the next day, then account for that.
			if job.hours.end_time < job.hours.start_time then
				job_end_time = job_end_time + GameTimestamp.hoursToTimestamp(24)
			end

			-- If the current time is past the end time of the job, then skip this job.
			if current_timestamp > job_end_time then
				goto continue
			end

			-- Get the job's prop
			local job_prop = g_savedata.libraries.usable_props.props[job.usable_prop_id]

			--TODO: This is bad, shouldn't be explicitly adding the commuting tasks for each task.

			-- Create the task.
			local go_to_work_task = CitizenScheduleTasks.createWalkToPositionTask(
				self.citizen_id,
				"Go To Work",
				job_start_time - GameTimestamp.hoursToTimestamp(1),
				job_end_time,
				Vector3.fromMatrix(job_prop.transform),
				0
			)

			-- Add the task to the schedule.
			table.insert(self.tasks, go_to_work_task)

			-- Create the task for the citizen to wait for their shift to start.
			local wait_for_work_task = CitizenScheduleTasks.createWaitTask(self.citizen_id, "Wait For Work", job_start_time - GameTimestamp.hoursToTimestamp(1), job_start_time)

			-- Add the task to the schedule.
			table.insert(self.tasks, wait_for_work_task)

			-- Create the task for the citizen to work.
			local work_task = CitizenScheduleTasks.createWaitTask(self.citizen_id, "Work", job_start_time, job_end_time)

			-- Add the task to the schedule.
			table.insert(self.tasks, work_task)

			-- Get the citizen's home building.
			local citizen_home_building = g_savedata.libraries.buildings.stored_buildings[citizen.home_building_id]

			-- Create a task for the worker to go home after their shift.
			local go_home_task = CitizenScheduleTasks.createWalkToPositionTask(self.citizen_id, "Return Home After Work", job_end_time, job_end_time + GameTimestamp.hoursToTimestamp(24), Vector3.fromMatrix(citizen_home_building.transform), 5)

			-- Add the task to the schedule.
			table.insert(self.tasks, go_home_task)

			::continue::
		end
	end

	-- Ticks the schedule
	---@param self CitizenSchedule
	schedule.tick = function(self)
		-- Get the current timestamp.
		local current_timestamp = GameTimestamp.now()

		-- Get the citizen.
		local citizen = Citizens.getData(self.citizen_id)

		-- If the citizen is nil, then return.
		if citizen == nil then
			d.print(("<line> (CitizenSchedule.tick) Error: Failed to get the citizen with id %d."):format(self.citizen_id), true, 1)
			return
		end

		-- If there are no tasks, then generate the schedule.
		if #self.tasks == 0 then
			self:generateSchedule()
		end

		-- If there are no tasks, then return.
		if #self.tasks == 0 then
			--d.print(("<line> (CitizenSchedule.tick) Error: Failed to generate the schedule for citizen with id %d."):format(self.citizen_id), true, 1)
			return
		end

		-- Get the current task.
		local current_task = self.tasks[1]

		-- If the current task is nil, then return.
		if current_task == nil then
			d.print(("<line> (CitizenSchedule.tick) Error: Failed to get the current task for citizen with id %d."):format(self.citizen_id), true, 1)
			return
		end

		-- If the task is not started, then check if we can.
		if not current_task.started and current_task.start_time <= current_timestamp then
			-- We can start the task, so start it.
			current_task.started = true

			d.print(("<line> (CitizenSchedule.tick) Task \"%s\" started for citizen with id %d."):format(current_task.name, self.citizen_id), true, 0)

			-- Call the task's start actions.
			if current_task.taskStartActions then
				current_task:taskStartActions()
			end
		end

		-- If the task is started, then check if it is completed.
		if current_task.started then
			-- Check if the task is completed.
			if current_task:checkCompletion() then

				-- Call the task's end actions.
				if current_task.taskEndActions then
					current_task:taskEndActions()
				end

				d.print(("<line> (CitizenSchedule.tick) Task \"%s\" completed for citizen with id %d."):format(current_task.name, self.citizen_id), true, 0)

				-- The task is completed, so remove it from the schedule.
				table.remove(self.tasks, 1)
			end
		end
	end

	-- return the schedule
	return schedule --[[@as CitizenSchedule]]
end
