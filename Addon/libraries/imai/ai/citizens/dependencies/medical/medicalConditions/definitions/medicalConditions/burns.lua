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
require("libraries.addon.utils.objects.fires.fires")

medicalCondition.create(
	"burns",
	true,
	{
		degree = 0, -- the degree of the burn
		affected_area = 0, -- the % of their body that is covered in the burn
		burn_temp = 0, -- the temperature of the burn 
		burn_decay = 0
	},
	---@param citizen Citizen
	function(citizen, game_ticks)
		-- tick every second

		local tick_rate = 1
		if not isTickID(0, tick_rate) then
			return
		end

		local tick_mult = tick_rate/60

		local burn = citizen.medical_conditions.burns

		if not burn.custom_data.burn_temp then
			burn.custom_data = {
				degree = 0, -- the degree of the burn
				affected_area = 0, -- the % of their body that is covered in the burn
				burn_temp = 0, -- the temperature of the burn 
				in_fire = false
			}
		end

		if not burn.custom_data.burn_decay then
			burn.custom_data.burn_decay = 0
		end

		-- if the citizen's burn temp is over 44
		if burn.custom_data.burn_temp >= 44 then
			local burn_rate = 0.05

			-- if the citizen is currently burning
			if burn.custom_data.burn_decay > 0 then
				burn_rate = 0.125
			end

			local rate = (burn.custom_data.burn_temp*burn_rate)^2.5*0.0001*tick_mult

			burn.custom_data.degree = math.min(rate * 4 + (1 - rate)^0.98 * burn.custom_data.degree, 4)
		end

		burn.custom_data.burn_temp = math.max(burn.custom_data.burn_temp - 0.2*tick_mult, 30)

		burn.custom_data.burn_decay = burn.custom_data.burn_decay - 1*tick_mult

		-- update the shown condition
		--[[if burn.custom_data.degree < 1 then
			burn.hidden = true
			return
		end]]

		-- update stability

		Modifiables.set(citizen.stability, "burns", math.max(-100,(burn.custom_data.degree*-2)*burn.custom_data.affected_area), -1)

		burn.hidden = false

		local degree = "Zeroth"
		if burn.custom_data.degree >= 4 then
			degree = "Fourth"
		elseif burn.custom_data.degree >= 3 then
			degree = "Third"
		elseif burn.custom_data.degree >= 2 then
			degree = "Second"
		elseif burn.custom_data.degree >= 1 then
			degree = "First"
		end

		burn.display_name = ("%s Degree Burn\nDegree: %0.3f\nBurn Temp: %0.3f\nIs In Fire: %s\nBody %% Burnt: %0.2f"):format(degree, burn.custom_data.degree, burn.custom_data.burn_temp, burn.custom_data.burn_decay > 0, burn.custom_data.affected_area)
	end,
	---@param citizen Citizen
	---@param health_change number
	function(citizen, health_change)
		-- discard if they were healed
		if health_change > 0 then
			return
		end

		-- check for nearby fires
		local closest_fire_distance, closest_fire, got_closest_fire = Fires.distTo.closestLoaded.lit(citizen.transform)

		-- if theres no loaded lit fires.
		if not got_closest_fire then
			return
		end

		local burn = citizen.medical_conditions.burns

		if not burn.custom_data.burn_temp then
			burn.custom_data = {
				degree = 0, -- the degree of the burn
				affected_area = 0, -- the % of their body that is covered in the burn
				burn_temp = 0, -- the temperature of the burn 
				in_fire = false
			}
		end

		if not burn.custom_data.burn_decay then
			burn.custom_data.burn_decay = 0
		end

		if closest_fire_distance > 5 then
			return
		end
		
		--d.print(("%s has been detected to have taken %0.4f damage, assuming to have been from a fire."):format(citizen.name.full, health_change), false, 0)
		--citizen.medical_conditions.burns.hidden = false
		--citizen.medical_conditions.burns.display_name = "Crisp"

		--server.setGameSetting("npc_damage", false)
		--server.setCharacterData(citizen.object_id, 100, true, true)
		--server.setGameSetting("npc_damage", true)
		--server.setCharacterData(citizen.object_id, 100, true, true)

		burn.custom_data.affected_area = math.min(burn.custom_data.affected_area + 0.02, 100)

		burn.custom_data.burn_temp = math.min(burn.custom_data.burn_temp + math.abs(health_change)*5, 120)

		burn.custom_data.burn_decay = 2
	end
)