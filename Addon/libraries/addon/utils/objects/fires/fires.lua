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
require("libraries.utils.math")
require("libraries.addon.utils.objects.object")

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[ 
	Adds additional functions for helping with fires,
	most notably (at time of writing) the ability to get the distance to the closest fire

	NOTE: We cannot do anything with block fires really, only world fires, so if a vehicle is on fire, this will not know of it's existance
	as its a completely different type of fire.
]]

-- library name
Fires = {}

--[[


	Variables


]]

---@class FireData
---@field object_id integer the object_id of the fire
---@field is_lit boolean if the fire is lit
---@field scale number the scale of the fire (may not actually have any use)

g_savedata.libraries.fires = {
	world_fires = {
		all = {}, ---@type table<integer, FireData> all of the fires, indexed by their object_id
		lit = {}, ---@type table<integer, integer> all of the lit fires in the world, value is their object_id
		--explosive = {}, ---@type table<integer, integer> all of the explosive fires in the world, value is their object_id
		loaded = {
			all = {}, ---@type table<integer, integer> all of the loaded fires in the world, value is their object_id
			lit = {}, ---@type table<integer, integer> all of the loaded lit fires in the world, value is their object_id
			--explosive = {} ---@type table<integer, integer> all of the loaded explosive fires in the world, value is their object_id
		}
	},
	last_updated_fires = 0
}

--g_savedata.libraries.fires = g_savedata.libraries.fires

--[[
	Updating the fires
]]
---@param force boolean? force the fires to update, skips the optimisation by not needing to update them multiple times per tick.
function Fires.update(force)
	
	-- we're not forced to update, and we've already updated the fires this tick, we can skip.
	if not force and g_savedata.tick_counter - g_savedata.libraries.fires.last_updated_fires == 0 then
		return
	end

	-- update object_data
	for object_id, fire_data in pairs(g_savedata.libraries.fires.world_fires.all) do
		local is_now_lit, is_success = server.getFireData(object_id)

		if not is_success then
			goto next_fire
		end

		if is_now_lit ~= fire_data.is_lit then
			if fire_data.is_lit then
				--[[
					remove it from the lit lists
				]]

				-- remove the fire from loaded lit fires list
				for i = 1, #g_savedata.libraries.fires.world_fires.loaded.lit do
					local fire_object_id = g_savedata.libraries.fires.world_fires.loaded.lit[i]

					if fire_object_id == object_id then
						table.remove(g_savedata.libraries.fires.world_fires.loaded.lit, i)
						break
					end
				end

				-- remove the fire from lit fires list
				for i = 1, #g_savedata.libraries.fires.world_fires.lit do
					local fire_object_id = g_savedata.libraries.fires.world_fires.lit[i]

					if fire_object_id == object_id then
						table.remove(g_savedata.libraries.fires.world_fires.lit, i)
						break
					end
				end
			else
				--[[
					add it to the lit lists
				]]

				-- check if it already exists in lit list
				local exists = false
				for i = 1, #g_savedata.libraries.fires.world_fires.lit do
					if g_savedata.libraries.fires.world_fires.lit[i] == object_id then
						exists = true
						break
					end
				end

				-- it doesn't exist in the lit list, add it
				if not exists then
					table.insert(g_savedata.libraries.fires.world_fires.lit, object_id)
				end

				-- check if the object is loaded
				for i = 1, #g_savedata.libraries.fires.world_fires.loaded.all do
					if g_savedata.libraries.fires.world_fires.loaded.all[i] == object_id then
						-- check if it already exists in loaded lit list
						local exists = false
						for i_lit = 1, #g_savedata.libraries.fires.world_fires.loaded.lit do
							if g_savedata.libraries.fires.world_fires.loaded.lit[i_lit] == object_id then
								exists = true
								break
							end
						end

						-- it doesn't exist in the loaded lit list, add it
						if not exists then
							table.insert(g_savedata.libraries.fires.world_fires.loaded.lit, object_id)
						end

						-- we dont need to check for further fires.
						break
					end
				end
			end
		end
		::next_fire::
	end
end

--[[

	Functions for finding the closest fire

]]
Fires.distTo = {
	
	closestLoaded = {
		---# Gets the distance and data on the closest loaded fire, can be lit or explosive
		---@param transform SWMatrix
		---@return number dist the distance to the closest loaded fire
		---@return integer? closest_fire the object_id of the closest fire
		---@return boolean is_success if we found a fire thats closest, returns false if none were found.
		fire = function(transform)

			local closest_dist = math.huge
			local closest_fire = nil
			for fire_index = 1, #g_savedata.libraries.fires.world_fires.loaded.all do
				local object_id = g_savedata.libraries.fires.world_fires.loaded.all[fire_index]

				local fire_transform, is_success = server.getObjectPos(object_id)

				-- if we failed to get the fire's position
				if not is_success then
					goto next_fire
				end

				local fire_dist = math.euclideanDistance(
					transform[13],
					fire_transform[13],
					transform[14],
					fire_transform[14],
					transform[15],
					fire_transform[15]
				)

				-- if this fire is closer than the closest so far
				if closest_dist > fire_dist then
					-- set it as the closest
					closest_dist = fire_dist
					closest_fire = object_id
				end

				::next_fire::
			end

			return closest_dist, closest_fire, closest_fire ~= nil
		end,
		---# Gets the distance and data on the closest loaded lit fire.
		---@param transform SWMatrix
		---@return number dist the distance to the closest loaded fire
		---@return integer? closest_fire the object_id of the closest fire
		---@return boolean is_success if we found a fire thats closest, returns false if none were found.
		lit = function(transform)

			-- update the fires, to check if any became lit.
			Fires.update()

			local closest_dist = math.huge
			local closest_fire = nil
			for fire_index = 1, #g_savedata.libraries.fires.world_fires.loaded.lit do
				local object_id = g_savedata.libraries.fires.world_fires.loaded.lit[fire_index]

				local fire_transform, is_success = server.getObjectPos(object_id)

				-- if we failed to get the fire's position
				if not is_success then
					goto next_fire
				end

				local fire_dist = math.euclideanDistance(
					transform[13],
					fire_transform[13],
					transform[14],
					fire_transform[14],
					transform[15],
					fire_transform[15]
				)

				-- if this fire is closer than the closest so far
				if closest_dist > fire_dist then
					-- set it as the closest
					closest_dist = fire_dist
					closest_fire = object_id
				end

				::next_fire::
			end

			return closest_dist, closest_fire, closest_fire ~= nil
		end
		---# Gets the distance and data on the closest loaded explosive fire.
		--explosive = function(transform)
		--end
	}
}

--[[

	Injecting into callbacks
	
]]

-- remove fires when they despawn
local old_onObjectDespawn = onObjectDespawn
function onObjectDespawn(object_id, object_data)
	-- avoid error if onObjectDespawn is not used anywhere else before.
	if old_onObjectDespawn then
		old_onObjectDespawn(object_id, object_data)
	end

	-- check if this was a stored world fire
	if not g_savedata.libraries.fires.world_fires.all[object_id] then
		return
	end

	--[[
		find all references to it, and remove them.
	]]
	for i = 1, #g_savedata.libraries.fires.world_fires.lit do
		local fire_object_id = g_savedata.libraries.fires.world_fires.lit[i]

		if fire_object_id == object_id then
			table.remove(g_savedata.libraries.fires.world_fires.lit, i)
			break
		end
	end

	for i = 1, #g_savedata.libraries.fires.world_fires.loaded.lit do
		local fire_object_id = g_savedata.libraries.fires.world_fires.loaded.lit[i]

		if fire_object_id == object_id then
			table.remove(g_savedata.libraries.fires.world_fires.loaded.lit, i)
			break
		end
	end

	for i = 1, #g_savedata.libraries.fires.world_fires.loaded.all do
		local fire_object_id = g_savedata.libraries.fires.world_fires.loaded.all[i]

		if fire_object_id == object_id then
			table.remove(g_savedata.libraries.fires.world_fires.loaded.all, i)
			break
		end
	end

	g_savedata.libraries.fires.world_fires.all[object_id] = nil
end

-- add fires into loaded when they load, and check if they exist already, if not, add them.
local old_onObjectLoad = onObjectLoad
function onObjectLoad(object_id)
	-- avoid error if onObjectLoad is not used anywhere else before.
	if old_onObjectLoad then
		old_onObjectLoad(object_id)
	end

	local object_data = server.getObjectData(object_id)

	-- check if its a fire
	if not object_data or object_data.object_type ~= 58 then
		return
	end

	local is_lit = server.getFireData(object_id)

	g_savedata.libraries.fires.world_fires.all[object_id] = {
		object_id = object_id,
		is_lit = is_lit,
		scale = object_data.scale
	}

	-- check if it already exists in loaded list
	local exists = false
	for i = 1, #g_savedata.libraries.fires.world_fires.loaded.all do
		if g_savedata.libraries.fires.world_fires.loaded.all[i] == object_id then
			exists = true
			break
		end
	end

	-- it doesn't exist in the loaded list, add it
	if not exists then
		table.insert(g_savedata.libraries.fires.world_fires.loaded.all, object_id)
	end

	-- skip lit checks if the fire is not lit
	local is_lit, is_success = server.getFireData(object_id)
	if not is_lit then
		return
	end

	-- check if it already exists in lit list
	exists = false
	for i = 1, #g_savedata.libraries.fires.world_fires.lit do
		if g_savedata.libraries.fires.world_fires.lit[i] == object_id then
			exists = true
			break
		end
	end

	-- it doesn't exist in the lit list, add it
	if not exists then
		table.insert(g_savedata.libraries.fires.world_fires.lit, object_id)
	end

	-- check if it already exists in loaded lit list
	exists = false
	for i = 1, #g_savedata.libraries.fires.world_fires.loaded.lit do
		if g_savedata.libraries.fires.world_fires.loaded.lit[i] == object_id then
			exists = true
			break
		end
	end

	-- it doesn't exist in the loaded lit list, add it
	if not exists then
		table.insert(g_savedata.libraries.fires.world_fires.loaded.lit, object_id)
	end
end

-- remove fires from the loaded list when they unload
local old_onObjectUnload = onObjectUnload
function onObjectUnload(object_id)
	-- avoid error if onObjectUnload is not used anywhere else before.
	if old_onObjectUnload then
		old_onObjectUnload(object_id)
	end

	-- check if this exists as a tracked fire
	if not g_savedata.libraries.fires.world_fires.all[object_id] then
		return
	end

	-- remove the fire from loaded lit fires list
	for i = 1, #g_savedata.libraries.fires.world_fires.loaded.lit do
		local fire_object_id = g_savedata.libraries.fires.world_fires.loaded.lit[i]

		if fire_object_id == object_id then
			table.remove(g_savedata.libraries.fires.world_fires.loaded.lit, i)
			break
		end
	end

	-- remove the fire from loaded fires list
	for i = 1, #g_savedata.libraries.fires.world_fires.loaded.all do
		local fire_object_id = g_savedata.libraries.fires.world_fires.loaded.all[i]

		if fire_object_id == object_id then
			table.remove(g_savedata.libraries.fires.world_fires.loaded.all, i)
			break
		end
	end
end