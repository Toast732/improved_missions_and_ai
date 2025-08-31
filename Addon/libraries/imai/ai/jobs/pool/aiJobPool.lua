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
require("libraries.imai.ai.jobs.aiJobs")

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[ 
	Used for job hiring cycles, to choose the best candidates for the job, and to let the citizens decide their job.
]]

-- library name
AIJobPool = {}

--[[


	Classes


]]

---@class AIJobPool
---@field citizens table<integer, CitizenID>
---@field jobs table<integer, AIJobID>
---@field addCitizen fun(self: AIJobPool, citizen_id: CitizenID) adds a citizen to the AIJobPool.
---@field compute fun(self: AIJobPool) computes the jobs, and assigns the jobs.

---@class AIJobOptionForCitizen
---@field job_id JobID the job id.
---@field want number how much the citizen weighs the job for how much they want it.

---@class AIJobOptionForJob
---@field citizen_id CitizenID the citizen id.
---@field fit number how much the job feels the citizen fits the job.

--[[


	Constants


]]

--[[


	Variables


]]

--[[


	Functions


]]


--- Creates a new AIJobPool.
---@return AIJobPool
function AIJobPool.create()

	d.print("(AIJobPool.create) Creating a new job pool...", true, 0)

	--- Create the AIJobPool.
	---@type AIJobPool
	local aiJobPool = {
		citizens = {},
		jobs = {},
		-- Add a citizen to the AIJobPool.
		---@param self AIJobPool
		---@param citizen_id CitizenID
		addCitizen = function(self, citizen_id)
			table.insert(self.citizens, citizen_id)
		end,
		-- Compute the jobs, and assign the jobs.
		---@param self AIJobPool
		compute = function(self)
			d.print("(AIJobPool.compute) Starting the hiring cycle...", true, 0)

			-- Set the number of citizens hired.
			local citizens_hired = 0

			---@param job_id JobID the job id.
			local function removeJob(job_id)
				for i = #self.jobs, 1, -1 do
					if self.jobs[i] == job_id then
						table.remove(self.jobs, i)
					end
				end
			end

			---@param citizen_id CitizenID the citizen id.
			local function removeCitizen(citizen_id)
				for i = #self.citizens, 1, -1 do
					if self.citizens[i] == citizen_id then
						table.remove(self.citizens, i)
					end
				end
			end

			-- Create a list that stores the job's top picks for each cycle.
			---@type table<JobID, table<integer, AIJobOptionForJob>>
			local job_top_picks = {}

			-- For each job, assign the job to the best citizen.
			for _, job_id in pairs(self.jobs) do

				-- Get the job
				---@type AIJob
				local job = g_savedata.libraries.ai_jobs.jobs[job_id]

				-- Create a list of applicants and how the job weighs the citizen.
				---@type table<integer, AIJobOptionForJob>
				local job_applicants = {}

				-- For each citizen, add the citizen to the job's list of applicants.
				for _, citizen_id in ipairs(self.citizens) do

					-- Get the job's fit for the citizen.
					local fit = job:getFit(citizen_id)

					-- Add the citizen to the job's list of applicants.
					table.insert(job_applicants, {
						citizen_id = citizen_id,
						fit = fit
					})
				end

				-- Sort the job's applicants by fit.
				table.sort(job_applicants, function(a, b)
					return a.fit > b.fit
				end)

				-- Add the job's top pick to the job_top_picks.
				job_top_picks[job_id] = job_applicants
			end
			
			--[[
			
				Start the hiring cycle, starting off at each job's top pick, and then let the citizen choose from the jobs which selected them for that cycle.

				So for the first cycle, it gets the citizen each job's top selection, and then adds that option to the citizen's options
				Then the citizen chooses from the options.
				Then the cycle repeats until all citizens are assigned to a job, or we run out of jobs.
			
			]]

			for _ = 1, #self.citizens do

				-- Store the citizen's options
				---@type table<CitizenID, table<integer, JobID>>
				local citizen_options = {}

				for job_id, job_top_picks in pairs(job_top_picks) do
					-- Get the top pick for the job.
					local top_pick = job_top_picks[1].citizen_id

					if citizen_options[top_pick] then
						table.insert(citizen_options[top_pick], job_id)
					else
						citizen_options[top_pick] = {job_id}
					end

					-- Remove the top pick from the job's top picks. (Citizen will either pick this one, or another one. We need not re-offer.)
					table.remove(job_top_picks, 1)
				end

				-- Iterate through the citizens, and let them choose from the options.
				for citizen_id, options in pairs(citizen_options) do

					-- Get the citizen.
					local citizen = Citizens.getData(citizen_id)

					-- Ensure the citizen exists.
					if not citizen then
						d.print(("<line> (AIJobPool.compute) Error: Citizen with id %d does not exist."):format(citizen_id), true, 1)
						goto continue
					end

					-- Go through the citizen's options, and if the job is already assigned to somebody else, remove it from their options.
					for i = #options, 1, -1 do
						if g_savedata.libraries.ai_jobs.jobs[options[i]].worker then
							table.remove(options, i)
						end
					end

					-- Get the citizen's choice by letting the citizen choose from the one they desire the most.

					-- Store the citizen's choice.
					---@type JobID|nil
					local choice = nil

					-- Store the highest desire
					local highest_desire = math.mininteger

					-- For each option, get the citizen's desire for the job.
					for _, option in ipairs(options) do
						local desire = citizen:getJobDesire(g_savedata.libraries.ai_jobs.jobs[option])

						-- If the desire is higher than the highest desire, set the choice to this option.
						if desire > highest_desire then
							choice = option
							highest_desire = desire
						end
					end

					-- If the citizen chose a job, assign the citizen to the job.
					if choice then

						-- Get the job.
						---@type AIJob
						local job = g_savedata.libraries.ai_jobs.jobs[choice]

						-- Assign the citizen to the job.
						job:assignCitizen(citizen_id)

						table.insert(citizen.jobs, job.id)

						-- Find all instances of this citizen in the job_top_picks, and remove them.
						for _, job_top_picks in pairs(job_top_picks) do
							for i = #job_top_picks, 1, -1 do
								if job_top_picks[i].citizen_id == citizen_id then
									table.remove(job_top_picks, i)
								end
							end
						end

						-- Increment the number of citizens hired.
						citizens_hired = citizens_hired + 1

						-- Remove this citizen from the citizens in this object.
						removeCitizen(citizen_id)

						-- Remove this job from the jobs in this object.
						removeJob(choice)

						-- Print that the citizen was hired.
						d.print(("(AIJobPool.compute) Citizen %s was hired for job %s!"):format(citizen.name.full, job.title), true, 0)
					end

					::continue::
				end
			end

			-- Print the number of citizens hired, and not hired.
			d.print(("<line> (AIJobPool.compute) Hiring cycle complete! %d citizens were hired, and %d citizens were not hired."):format(citizens_hired, #self.citizens), true, 0)
		end
	}

	-- add each job with no worker to the job pool.
	for _, job in pairs(g_savedata.libraries.ai_jobs.jobs) do
		if not job.worker then
			table.insert(aiJobPool.jobs, job.id)
		end
	end

	-- Return the AIJobPool.
	return aiJobPool
end