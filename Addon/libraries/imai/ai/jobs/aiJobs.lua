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
require("libraries.addon.components.usableProps.usableProp")
require("libraries.imai.ai.jobs.aiJob")

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[ 
	Stores and handles the list of AI jobs.
]]

-- library name
AIJobs = {}

--[[


	Classes


]]

--[[


	Constants


]]

-- The priority of the setupMain callback, put after buildings, as it requires buildings to be setup.
AI_JOBS_SETUP_MAIN_PRIORITY = BUILDINGS_SETUP_MAIN_PRIORITY + 1

--[[


	Variables


]]

g_savedata.libraries.ai_jobs = {

	--- Stores the AI Jobs.
	---@type table<AIJobID, AIJob>
	jobs = {},

	--- The next ID for an AI Job.
	---@type AIJobID
	next_id = 1
}

--[[


	Functions


]]

--- Called when the main setup is called.
---@param is_world_create boolean if the world is being created.
function AIJobs.setupMain(is_world_create)

	-- Set the start time.
	local start_time = server.getTimeMillisec()

	-- Create a new list of ai jobs, will replace g_savedata.libraries.ai_jobs.jobs.
	---@type table<AIJobID, AIJob>
	local new_ai_jobs = {}

	-- Define the number of new ai jobs made.
	local new_ai_jobs_made = 0

	-- Define the number of ai jobs that were updated.
	local ai_jobs_updated = 0

	-- Get all ai job usable props.
	local ai_job_props = UsableProps.getPropsWithType(USABLE_PROP_TYPE.AI_JOB)

	-- If it failed, print an error and return.
	if not ai_job_props then
		d.print(("<line> (AIJobs.setupMain) Error: Failed to get any ai job props."), true, 1)
		return
	end

	-- Loop through all the ai jobs.
	for _, prop_id in pairs(ai_job_props) do

		-- Get the prop.
		local ai_job_prop = g_savedata.libraries.usable_props.props[prop_id]

		-- Store if the number of ai jobs to create, set it to how many positions are offered by this job.
		local ai_jobs_to_create = Tags.getValue(ai_job_prop.tags, "positions", false) --[[@as number]] or 1

		-- Check if the ai job already exists.
		for _, ai_job in pairs(g_savedata.libraries.ai_jobs.jobs) do
			-- If the ai job's name is the same as the zone's name, it's not new.
			if ai_job.usable_prop_id == prop_id then
				ai_job_exists = true

				-- Update the ai_job's data.
				ai_job = AIJob.clean(ai_job)

				-- Print that the ai_job was updated.
				d.print(("(AIJobs.setupMain) AI Job: \"%s\" updated."):format(ai_job.title), true, 0)

				-- Store the updated ai_job.
				new_ai_jobs[ai_job.id] = ai_job

				-- Increment the number of ai_jobs updated.
				ai_jobs_updated = ai_jobs_updated + 1

				-- Decrement the number of ai jobs to create.
				ai_jobs_to_create = ai_jobs_to_create - 1

				-- If there are no more ai jobs to create, break.
				if ai_jobs_to_create == 0 then
					break
				end
			end
		end

		-- Create as many ai jobs as required.
		for _ = 1, ai_jobs_to_create do
			-- Create a new ai_job.
			local new_ai_job = AIJob.create(
				ai_job_prop
			)

			-- If the ai_job is nil, then skip it.
			if new_ai_job == nil then
				goto continue
			end

			-- Store the ai_job.
			new_ai_jobs[new_ai_job.id] = new_ai_job

			-- Print that the ai_job was created.
			d.print(("(AIJobs.setupMain) AI Job \"%s\" created."):format(new_ai_job.title), true, 0)

			-- Increment the number of new ai_jobs made.
			new_ai_jobs_made = new_ai_jobs_made + 1

			::continue::
		end
	end

	-- Set the new stored ai_jobs.
	g_savedata.libraries.ai_jobs.jobs = new_ai_jobs

	d.print(("AI Jobs Setup! New AI Jobs Made: %d, AI Jobs Updated: %d, Time Taken: %dms"):format(
		new_ai_jobs_made,
		ai_jobs_updated,
		Ticks.millisecondsSince(start_time)
	), true, 0)
end

-- Bind the setupMain callback.
Binder.bind.setupMain(AIJobs.setupMain, AI_JOBS_SETUP_MAIN_PRIORITY)