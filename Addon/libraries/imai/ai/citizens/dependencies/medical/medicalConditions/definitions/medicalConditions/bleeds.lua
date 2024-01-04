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
Bleed = {}

-- required libraries

--[[


	Variables


]]

---@type table<string, number>
SEVERITY_MULTIPLIERS = {
	pistol = 2.5,
	smg = 2.5,
	rifle = 4,
	speargun = 10 -- So this is how game devs catch their whales... Squeezed for every last drop.
}

-- Base threshold for severity when a tourniquet is required.
BASE_TOURNIQUET_SEVERITY_THRESHOLD = 0.15

MAX_BLOOD_PER_MINUTE = 75
MIN_BLOOD_PER_MINUTE = 2

MAX_BLOOD_LOSS_PER_MINUTE = 700

--[[


	Functions


]]

--TODO: when the info such as items worn, have this calculation integrate the citizen's data.
---# Calculates bleeding severity based on how much damage they took, and the estimated source<br>
--- This function is kept seperate as the calculated severity could be used for debug or for early breaks.
---@param citizen Citizen the citizen this will be applied to (Used for additional calculations based on some data about them)
---@param damage number the damage the citizen recieved
---@param damage_source string what caused the damage.
---@return number severity the severity to be used with Bleed.apply
function Bleed.damageToSeverity(citizen, damage, damage_source)
	-- get the severity multiplier, defaults to 1
	local severity_multiplier = SEVERITY_MULTIPLIERS[damage_source] or 1

	-- calculate the severity
	local severity = damage * -0.0065 * severity_multiplier

	return severity
end


---# Returns the required treatment to treat the bleeding.
---@param citizen Citizen
---@return "bandage"|"tourniquet"|"none" required_treatment the treatment that the citizen requires.
function Bleed.getRequiredTreatment(citizen)
	local severity = citizen.medical_data.medical_conditions.bleeds.custom_data.severity

	-- if the severity is 0 or less
	if severity <= 0 then
		-- then no treatment is required.
		return "none"
	end

	-- if this can be treated with a bandage
	if severity < BASE_TOURNIQUET_SEVERITY_THRESHOLD then
		-- if they already have a bandage
		local _, bandage_applied, _ = Inventory.hasItem(citizen.inventory.id, "bandage")
		-- no need to apply a bandage.
		if bandage_applied then
			return "none"
		end

		-- bandage should be applied
		return "bandage"
	end

	-- this should be treated with a tourniquet.
	
	-- if a tourniquet is already applied.
	local tourniquet_data, _, has_tourniquet, got_inventory = Inventory.hasItem(citizen.inventory.id, "tourniquet")

	-- failed to get their inventory
	if not got_inventory then
		d.print(("<line>: Failed to get inventory for citizen: %s"):format(citizen.name.full), true, 1)
		return "tourniquet"
	end

	-- they dont have a tourniquet, so say that they need a tourniquet.
	if not has_tourniquet then
		return "tourniquet"
	end

	-- safety check
	if tourniquet_data then
		-- tourniquet is already tightened and properly applied.
		if tourniquet_data.data.tightened then
			return "none"
		end

		-- the tourniquet needs to be tightened, so say that they require a tourniquet.
		return "tourniquet"
	end

	d.print(("<line>: Failed to get tourniquet data for citizen %s when they should have a tourniquet"):format(citizen.name.full), true, 1)
	return "tourniquet"
end

---# Applies Bleeding, severity affects how much blood they lose <br>
--- This is not at all 1:1 to real life, as that would require far too much resesearch, and many variables we would need cannot be gotten in stormworks.
---@param citizen Citizen
---@param severity number
function Bleed.apply(citizen, severity)
	local bleeds = citizen.medical_data.medical_conditions.bleeds

	bleeds.custom_data.severity = bleeds.custom_data.severity + severity
end

--[[
	Define conditons and treatments
]]

-- Define the medical condition
medicalCondition.create(
	"bleeds",
	true,
	{
		severity = 0, -- value for the severity of their bleeding
		blood = {
			max = 5000,
			current = 5000
		}
	},
	---@param citizen Citizen
	---@param game_ticks number
	function(citizen, game_ticks)
		local bleeds = citizen.medical_data.medical_conditions.bleeds

		-- if the citizen's current blood amount is less than the max
		if bleeds.custom_data.blood.max > bleeds.custom_data.blood.current then
			--[[
				produce blood
			]]

			-- calculate how much blood to produce this tick
			local blood_production = math.clamp(
				math.linearScale(
					bleeds.custom_data.blood.current,
					bleeds.custom_data.blood.max*0.75,
					bleeds.custom_data.blood.max,
					MAX_BLOOD_PER_MINUTE,
					MIN_BLOOD_PER_MINUTE),
				MIN_BLOOD_PER_MINUTE,
				MAX_BLOOD_PER_MINUTE
			)*0.00027777777

			bleeds.custom_data.blood.current = math.clamp(
				bleeds.custom_data.blood.current + blood_production,
				0,
				bleeds.custom_data.blood.max
			)
		end

		--[[
			update tooltip & tick blood loss
		]]

		-- if theres no bleeding
		if bleeds.custom_data.severity <= 0 then
			-- remove tooltip
			bleeds.hidden = true
			return
		end

		-- check if they have a bandage
		local _, _, has_bandage, _ = Inventory.hasItem(citizen.inventory.id, "bandage")

		-- check if they have a tourniquet
		local tourniquet_data, _, has_tourniquet, _ = Inventory.hasItem(citizen.inventory.id, "tourniquet")

		local base_blood_loss = MAX_BLOOD_LOSS_PER_MINUTE*bleeds.custom_data.severity*0.00027777777

		-- if the bleeding is in the bandage range
		if bleeds.custom_data.severity < BASE_TOURNIQUET_SEVERITY_THRESHOLD then
			
			if has_bandage then
				-- hide tooltip, no bleeding
				bleeds.hidden = true
				return
			end

			-- mild bleeding
			bleeds.custom_data.blood.current = bleeds.custom_data.blood.current - base_blood_loss*0.5

			-- set tooltip
			bleeds.hidden = false
			bleeds.display_name = "Mild Bleeding (Treat with Bandage)"
			return
		end

		-- the bleeding is in the tourniquet range

		local bleeding_severity = bleeds.custom_data.severity < 0.3 and "Moderate" or "Severe"

		bleeds.display_name = bleeding_severity.." Bleeding"

		-- a tourniquet has not been applied
		if not has_tourniquet then

			-- heavy bleeding
			bleeds.custom_data.blood.current = bleeds.custom_data.blood.current - base_blood_loss

			bleeds.display_name = bleeds.display_name.." (Treat with tourniquet)"
			bleeds.hidden = false
		elseif tourniquet_data and not tourniquet_data.data.tightened then
			-- tourniquet needs to be tightened

			-- ever so slightly less heavy bleeding
			bleeds.custom_data.blood.current = bleeds.custom_data.blood.current - base_blood_loss*0.999

			bleeds.display_name = bleeds.display_name.." (Tourniquet needs tightened)"
			bleeds.hidden = false
		else

			-- still some minor bleeding.
			bleeds.custom_data.blood.current = bleeds.custom_data.blood.current - base_blood_loss*0.05

			-- tourniquet is applied and tightened, no need to display anything.
			bleeds.hidden = true
		end
	end,
	function(citizen, health_change, damage_source) 
		-- discard if they were healed
		if health_change > 0 then
			return
		end

		-- get the severity
		local severity = Bleed.damageToSeverity(citizen, health_change, damage_source)

		-- if the severity change is more than 0, then apply the bleeds required treatment.
		if severity > 0 then
			Treatments.apply(citizen, "bleeds")
		end

		-- apply bleeding
		Bleed.apply(citizen, severity)
	end,
	nil
)

-- Define the condition in order to treat blood loss (bleeding)
Treatments.defineTreatmentCondition(
	"blood_loss",
	nil,
	nil,
	---@param citizen Citizen
	function(citizen)
		-- get the current severity of their bleeding
		-- local severity = citizen.medical_data.medical_conditions.bleeds.custom_data.severity

		--! OPTIMISATION: I might not need to do much processing here?

		-- figure out what treatment this citizen requires
		local required_treatment = Bleed.getRequiredTreatment(citizen)

		-- this patient no longer requires treatment, so return true to remove this condition. (shouldn't get here, but in case it does, this should mitigate some bugs)
		if required_treatment == "none" then
			Treatments.print(("<line>: Citizen %s has been treated, they had a required treatment of: %s"):format(citizen.name.full, required_treatment), false, 0)
			return true
		end

		-- apply the bandage
		if required_treatment == "bandage" then
			Treatments.print(("<line>: Citizen %s has been treated, they had a required treatment of: %s"):format(citizen.name.full, required_treatment), false, 0)
			return true
		end

		if required_treatment == "tourniquet" then
			local tourniquet, _, has_tourniquet, _ = Inventory.hasItem(citizen.inventory.id, "tourniquet")

			-- if they dont have a tourniquet
			if not has_tourniquet then
				-- apply a tourniquet
				Inventory.addItem(citizen.inventory.id, Item.create("tourniquet", true), true)

				-- the tourniquet still needs to be tightened, so return false
				return false
			end

			-- they have a tourniquet, so tighten it and return true, as the tourniquet has been properly applied.

			-- make sure we actually got the tourniquet item to avoid an error.
			if tourniquet then
				-- tighten the tourniquet
				Treatments.print(("<line>: Citizen %s has been treated, they had a required treatment of: %s"):format(citizen.name.full, required_treatment), false, 0)
				tourniquet.data.tightened = true
			end

			-- say that the bleeding has been treated.
			Treatments.print(("<line>: Citizen %s has been treated, they had a required treatment of: %s"):format(citizen.name.full, required_treatment), false, 0)
			return true
		end

		-- shouldn't normally be able to get here...
		d.print(("<line>: Reached an area in the code that shouldn't normally be reached, required_treatment: %s, citizen: %s"):format(required_treatment, citizen.name.full), true, 1)

		return false
	end,
	nil
)

-- Define the treatment for bleeding, used more for display and handling when its been treated.
Treatments.create(
	"bleeds",
	function(citizen)
	end,
	function(citizen)
	end,
	nil,
	nil,
	"blood_loss"
)

--[[
	Item Prefab Definitions
]]

-- Define bandages
Item.createPrefab(
	"bandage",
	nil,
	{
		applied_time = 0
	}
)

-- Define Tourniquets
Item.createPrefab(
	"tourniquet",
	nil,
	{
		applied_time = 0,
		tightened = false
	}
)