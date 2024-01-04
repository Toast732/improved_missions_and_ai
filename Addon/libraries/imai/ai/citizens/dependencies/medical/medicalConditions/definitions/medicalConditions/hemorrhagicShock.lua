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
	Some of the data for behaviour in here has been referenced from
	Hooper N, Armstrong TJ. Hemorrhagic Shock. [Updated 2022 Sep 26]. In: StatPearls [Internet]. Treasure Island (FL): StatPearls Publishing; 2023 Jan-. Available from: https://www.ncbi.nlm.nih.gov/books/NBK470382/
	Specifically for the different classes of hemorrhagic shock for the thresholds.
]]

--[[


	Library Setup


]]

-- required libraries
require("libraries.imai.ai.citizens.dependencies.medical.medicalConditions.definitions.medicalConditions.bleeds") -- requires bleeding system to get how much blood the citizen has.

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[ 
	LIBRARY DESCRIPTION
]]

-- library name
LibraryName = {}

--[[


	Classes


]]

--[[


	Variables


]]

-- decrement for the hemorrhagic shock severity
HEMORRHAGIC_SEVERITY_DECREASE = 1/(time.minute*20)

-- increment for the hemorrhagic shock severity
HEMORRHAGIC_SEVERITY_INCREASE = 1/(time.hour*20)

--[[


	Functions


]]

-- Define the medical condition
medicalCondition.create(
	"hemorrhagic_shock",
	true,
	{
		stage = 0,
		severity = 0 -- severity of their blood loss, 0 is perfectly fine, 1 is really bad.
	},
	---@param citizen Citizen
	function(citizen)
		local hemorrhagic_shock = citizen.medical_data.medical_conditions.hemorrhagic_shock
		local bleeds = citizen.medical_data.medical_conditions.bleeds

		-- How much blood they've lost from their maximum blood contents.
		local blood_lost_ratio = 1-(bleeds.custom_data.blood.current/bleeds.custom_data.blood.max)

		--[[
			Update Hemorrhagic Shock Stage
		]]

		if blood_lost_ratio > 0.4 then -- class 4 hemorrhagic shock, over 40% blood loss.
			hemorrhagic_shock.custom_data.stage = 4
		elseif blood_lost_ratio > 0.3 then -- class 3 hemorragic shock, over 30% blood loss.
			hemorrhagic_shock.custom_data.stage = 3
		elseif blood_lost_ratio > 0.15 then -- class 2 hemorragic shock, over 15% blood loss.
			hemorrhagic_shock.custom_data.stage = 2
		elseif blood_lost_ratio > 0.07 then -- class 1 hemorragic shock, over 7% blood loss. (The book never specifies the minimum blood loss for class 1, just "up to 15%", so I put it as 7% to avoid class 1 hemorrhagic shock being usless to know.)
			hemorrhagic_shock.custom_data.stage = 1
		else -- no hemorrhagic shock.
			hemorrhagic_shock.custom_data.stage = 0
		end

		--[[
			Update Hemorrhagic Shock Blood Loss Severity
		]]
		
		-- if the stage is 0, decrease severity
		if hemorrhagic_shock.custom_data.stage == 0 then
			hemorrhagic_shock.custom_data.severity = math.max(0, hemorrhagic_shock.custom_data.severity - HEMORRHAGIC_SEVERITY_DECREASE)
		end

		--[[
			Update Tooltip
		]]

		-- hide the tooltip if hemorrhagic shock is 0
		hemorrhagic_shock.hidden = hemorrhagic_shock.custom_data.stage == 0

		-- set the displayname tooltip
		hemorrhagic_shock.display_name = ("Stage %s Hemorrhagic Shock"):format(hemorrhagic_shock.custom_data.stage)
	end,
	nil,
	nil
)