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

--[[


	Library Setup


]]

medicalCondition.create(
	"cardiac_arrest",
	true,
	{
		incapacitated_at = 0,
		cardiac_arrest = false
	},
	nil,
	---@param citizen Citizen
	---@param health_change number
	function(citizen, health_change)
		--d.print(("Citizen \"%s\" took %0.3f damage."):format(citizen.name.full, health_change), false, 0)

		-- if it was not a defib
		if health_change ~= 10 then
			return
		end

		local cardiac_arrest = citizen.medical_data.medical_conditions.cardiac_arrest

		-- if this citizen is not suffering cardiac arrest
		if not cardiac_arrest.custom_data.cardiac_arrest then
			return
		end

		-- get how long its been since they became incapacitated
		local incapacitated_duration = g_savedata.tick_counter - cardiac_arrest.custom_data.incapacitated_at

		-- from a 35% chance to resurrect at 10 minutes, to a 95% chance to resurrect at 0 seconds.
		local resurrect_chance = math.linearScale(
			incapacitated_duration,
			36000,
			0,
			0.35,
			0.95
		)

		local resurrect_random_number = math.randomDecimals(0, 1)

		-- if the resurrect failed
		if resurrect_random_number > resurrect_chance then
			server.notify(-1, "Resurrect",("Resurrecting %s failed."):format(citizen.name.full), 2)
			return
		end

		-- give the citizen + 35 stability for 5 minutes
		Modifiables.set(citizen.medical_data.stability, "defibrillator", 35, 18000)

		server.notify(-1, "Resurrect",("Resurrecting %s succeeded."):format(citizen.name.full), 4)

		-- ressurect succeeded, set the citizen as no longer under cardiac arrest.
		medicalCondition.assignCondition(citizen, "cardiac_arrest", false)
	end,
	---@param citizen Citizen
	---@param new_state boolean if the citizen will now have cardiac arrest or not
	function(citizen, new_state)
		local cardiac_arrest = citizen.medical_data.medical_conditions.cardiac_arrest

		if cardiac_arrest.custom_data.cardiac_arrest ~= new_state then
			-- set the state of this medical condition
			cardiac_arrest.custom_data.cardiac_arrest = new_state

			-- set the time of the incapacitation
			cardiac_arrest.custom_data.incapacitated_at = g_savedata.tick_counter

			-- set if this citizen should be incapacitated
			citizen.medical_data.incapacitated = new_state

			-- set if this should be hidden
			cardiac_arrest.hidden = not new_state

			-- set the display name
			cardiac_arrest.display_name = "Cardiac Arrest"

			--[[if new_state then
				-- say that this citizen is currently having cardiac arrest
				cardiac_arrest.custom_data.cardiac_arrest = true

				-- "kill" incapacitate the character
				-- server.killCharacter(citizen.object_id)

				-- set the time the citizen was incapacitated at
				cardiac_arrest.custom_data.incapacitated_at = g_savedata.tick_counter

				-- set that this citizen should be incapacitated
				citizen.incapacitated = true
			else
			end]]
		end
	end
)