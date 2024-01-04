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
require("libraries.imai.ai.citizens.dependencies.medical.medicalConditions.definitions.medicalConditions.bleeds") -- requires bleeding system to update blood amount.

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[ 
	Adds internal bleeding, gunshot wounds have a chance to result in internal bleeding
	which cannot be stopped on the field, and the citizen will need to be transported
	to the hospital immediately.
]]

-- library name
LibraryName = {}

--[[


	Classes


]]

--[[


	Variables


]]

local INTERNAL_BLEEDING_BLOOD_LOSS_PER_MINUTE = 125

local internal_bleeding_causes = {
	pistol = {
		chance = 0.2 -- 20%
	},
	smg = {
		chance = 0.2 -- 20%
	},
	rifle = {
		chance = 0.4 -- 40%
	},
	speargun = {
		chance = 1 -- 100%
	}
}

--[[


	Functions


]]

medicalCondition.create(
	"internal_bleeding",
	true,
	{
		count = 0 -- stores how many instances of internal bleeding there is.
	},
	---@param citizen Citizen
	function(citizen)
		local internal_bleeding = citizen.medical_data.medical_conditions.internal_bleeding
		--[[
			tick internal bleeding
		]]
		
		-- if the citizen has no internal bleeding, skip
		if internal_bleeding.custom_data.count == 0 then
			internal_bleeding.hidden = true
			return
		end

		-- update tooltip
		internal_bleeding.hidden = false
		internal_bleeding.display_name = "Internal Bleeding"

		local bleeds = citizen.medical_data.medical_conditions.bleeds

		-- calculate how much blood is lost this tick.
		local blood_loss = internal_bleeding.custom_data.count*INTERNAL_BLEEDING_BLOOD_LOSS_PER_MINUTE*0.00027777777

		-- remove that much blood from the citizen.
		bleeds.custom_data.blood.current = bleeds.custom_data.blood.current - blood_loss
	end,
	---@param citizen Citizen
	---@param _ number
	---@param damage_source string
	function(citizen, _, damage_source)
		-- check if the damage source could cause internal bleeding
		if not internal_bleeding_causes[damage_source] then
			return
		end

		local internal_bleeding_cause_data = internal_bleeding_causes[damage_source]

		-- random chance if this will cause internal bleeding
		if internal_bleeding_cause_data.chance < math.randomDecimals(0, 1) then
			return
		end

		-- cause internal bleeding
		local internal_bleeding = citizen.medical_data.medical_conditions.internal_bleeding

		internal_bleeding.custom_data.count = internal_bleeding.custom_data.count + 1
	end,
	nil
)