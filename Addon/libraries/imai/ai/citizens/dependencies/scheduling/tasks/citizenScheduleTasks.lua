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

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[ 
	Contains some code for handling the types of tasks for citizens (eg, walk to position, drive to position, etc.).
]]

-- library name
CitizenScheduleTasks = {}

--[[


	Classes


]]

---@class CitizenScheduleTaskBase
---@field citizen_id CitizenID the id of the citizen this task is for.
---@field name string the name of the task.
---@field task_type CitizenScheduleTaskType the type of task this is.
---@field start_time GameTimestamp the time this task starts.
---@field expiry GameTimestamp the time this task expires.
---@field started boolean whether the task has started.
---@field checkCompletion fun(self: CitizenScheduleTaskBase):boolean Checks if the task is completed, and returns true if it is.
---@field taskStartActions fun(self: CitizenScheduleTaskBase)? Actions to take when the task starts.
---@field taskEndActions fun(self: CitizenScheduleTaskBase)? Actions to take when the task ends.

---@class CitizenScheduleTaskCommute: CitizenScheduleTaskBase
---@field position Vector3 the position to commute to.
---@field radius number the radius around the position to be in.

---@class CitizenScheduleTaskWait: CitizenScheduleTaskBase


--[[


	Constants


]]

--[[


	Variables


]]

---@enum CitizenScheduleTaskType
local CitizenScheduleTaskType = {
	Base = 0,
	Wait = 1,
	Commute = 2,
}

--[[


	Functions


]]

--- Creates a base task.
---@param citizen_id CitizenID the id of the citizen this task is for.
---@param name string the name of the task.
---@param task_type CitizenScheduleTaskType the type of task this is.
---@param start_time GameTimestamp the time this task starts.
---@param expiry GameTimestamp the time this task expires.
---@param checkCompletion fun(self: CitizenScheduleTaskBase):boolean Checks if the task is completed, and returns true if it is.
---@param taskStartActions fun(self: CitizenScheduleTaskBase)? Actions to take when the task starts.
---@param taskEndActions fun(self: CitizenScheduleTaskBase)? Actions to take when the task ends.
---@return CitizenScheduleTaskBase
function CitizenScheduleTasks.createBaseTask(citizen_id, name, task_type, start_time, expiry, checkCompletion, taskStartActions, taskEndActions)
	---@type CitizenScheduleTaskBase
	local task = {
		citizen_id = citizen_id,
		name = name,
		task_type = task_type,
		start_time = start_time,
		expiry = expiry,
		started = false,
		checkCompletion = checkCompletion,
		taskStartActions = taskStartActions,
		taskEndActions = taskEndActions
	}

	return task
end

--- Creates a commute task
---@param citizen_id CitizenID the id of the citizen this task is for.
---@param name string the name of the task.
---@param start_time GameTimestamp the time this task starts.
---@param expiry GameTimestamp the time this task expires.
---@param position Vector3 the position to commute to.
---@param radius number the radius around the position to be in.
---@param taskStartActions fun(self: CitizenScheduleTaskBase)? Actions to take when the task starts.
---@param taskEndActions fun(self: CitizenScheduleTaskBase)? Actions to take when the task ends.
---@return CitizenScheduleTaskCommute
function CitizenScheduleTasks.createCommuteTask(citizen_id, name, start_time, expiry, position, radius, taskStartActions, taskEndActions)
	--- Create the base task.
	local base_task = CitizenScheduleTasks.createBaseTask(
		citizen_id,
		name,
		CitizenScheduleTaskType.Commute,
		start_time,
		expiry,
		---@param self CitizenScheduleTaskCommute
		---@return boolean
		function(self)
			-- Get the citizen.
			local citizen = Citizens.getData(self.citizen_id)

			-- If the citizen is nil, then return.
			if citizen == nil then
				d.print(("<line> (CitizenScheduleTaskCommute.checkCompletion) Error: Failed to get the citizen with id %d."):format(self.citizen_id), true, 1)
				return true
			end

			-- If the task expired, then return true.
			if GameTimestamp.now() > self.expiry then
				d.print(("<line> (CitizenScheduleTaskCommute.checkCompletion) Task expired, marked as completed. (%s > %s)"):format(GameTimestamp.now(), self.expiry), true, 0)
				return true
			end

			-- If the citizen's active_commute_id is nil, then return true.
			if citizen.active_commute_id == nil then
				d.print(("<line> (CitizenScheduleTaskCommute.checkCompletion) Commute id is nil for citizen %d, commute completed."):format(self.citizen_id), true, 0)
				return true
			end

			-- Get the commute.
			---@type ActiveCommute
			local commute = g_savedata.libraries.commuting.active_commutes[citizen.active_commute_id]

			-- If the commute is nil, then return true.
			if commute == nil then
				d.print(("<line> (CitizenScheduleTaskCommute.checkCompletion) Commute not found for citizen %d, commute completed."):format(self.citizen_id), true, 0)
				return true
			end

			-- If the current segment index is not a segment, then return true.
			if commute.commute_segments[commute.current_segment_index] == nil then
				d.print(("<line> (CitizenScheduleTaskCommute.checkCompletion) Current segment index does not have an associated segment, commute completed for citizen %d"):format(self.citizen_id), true, 0)
				return true
			end

			-- Return if the citizen is within the radius of the position.
			return Vector3.euclideanDistance(Vector3.fromMatrix(citizen.transform), self.position) <= self.radius
		end,
		---@param self CitizenScheduleTaskCommute
		function(self)
			-- Get the citizen.
			local citizen = Citizens.getData(self.citizen_id)

			-- If the citizen is nil, then return.
			if citizen == nil then
				d.print(("<line> (CitizenScheduleTaskWalkToPosition.taskStartActions) Error: Failed to get the citizen with id %d."):format(self.citizen_id), true, 1)
				return
			end

			-- Create the builder
			---@type CommuteBuilder
			local commute_builder = {
				citizen_id = self.citizen_id,
				origin = Vector3.fromMatrix(citizen.transform),
				destination = self.position
			}

			-- Create the commute for the citizen.
			local active_commute_id = Commuting.commute(commute_builder)

			-- Store the active commute id in the citizen.
			citizen.active_commute_id = active_commute_id

			-- If the taskStartActions is not nil, then call it.
			if taskStartActions then
				taskStartActions(self)
			end
		end,
		---@param self CitizenScheduleTaskCommute
		function(self)
			-- Get the citizen.
			local citizen = Citizens.getData(self.citizen_id)

			-- If the citizen is nil, then return.
			if citizen == nil then
				d.print(("<line> (CitizenScheduleTaskWalkToPosition.taskEndActions) Error: Failed to get the citizen with id %d."):format(self.citizen_id), true, 1)
				return
			end

			-- Remove the active commute.
			g_savedata.libraries.commuting.active_commutes[citizen.active_commute_id] = nil

			citizen.active_commute_id = nil

			-- If the taskEndActions is not nil, then call it.
			if taskEndActions then
				taskEndActions(self)
			end
		end
	) --[[@as CitizenScheduleTaskCommute]]

	-- Set the position and radius.
	base_task.position = position

	base_task.radius = radius

	return base_task
end

--- Creates a Wait task.
---@param citizen_id CitizenID the id of the citizen this task is for.
---@param name string the name of the task.
---@param start_time GameTimestamp the time this task starts.
---@param expiry GameTimestamp the time this task expires, this is what is checked for completion.
---@param taskStartActions fun(self: CitizenScheduleTaskBase)? Actions to take when the task starts.
---@param taskEndActions fun(self: CitizenScheduleTaskBase)? Actions to take when the task ends.
---@return CitizenScheduleTaskWait
function CitizenScheduleTasks.createWaitTask(citizen_id, name, start_time, expiry, taskStartActions, taskEndActions)
	--- Create the base task.
	local base_task = CitizenScheduleTasks.createBaseTask(
		citizen_id,
		name,
		CitizenScheduleTaskType.Wait,
		start_time,
		expiry,
		---@param self CitizenScheduleTaskWait
		function(self)
			-- Get the current timestamp.
			local current_timestamp = GameTimestamp.now()

			-- Return if the current timestamp is greater than the expiry.
			return current_timestamp > self.expiry
		end,
		taskStartActions,
		taskEndActions
	) --[[@as CitizenScheduleTaskWait]]

	return base_task
end