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

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[ 
	Adds additional functions related to handling objects, such as onObjectDespawn,
	Object.exists(), etc
]]

-- library name
Object = {}

--[[


	Variables


]]

g_savedata.libraries.objects = {
	object_list = {}, ---@type table<integer, SWObjectData> indexed by object_id, value is the object's data.
	despawned_objects = {} ---@type table<integer, true> indexed by object_id, a table of objects that have been despawned.
}

local g_objects = g_savedata.libraries.objects

---# Adds an object to the object list
---@param object_id integer the object_id of the object to add.
---@return boolean is_success if it successfully added the object to the object list, returns false if the object doesn't actually exist.
function Object.addObject(object_id)
	local object_data = server.getObjectData(object_id)

	-- the object doesn't actually exist
	if not object_data then
		d.print(("<line>: attempt to add non-existing object %s to object list"):format(object_id), true, 1)
		return false
	end

	-- add the object to the object list
	g_objects.object_list[object_id] = object_data

	return true
end

---# Checks if an object exists
---@param object_id integer the object_id of the object which we want to see if it exists.
---@return boolean exists if the object exists
function Object.exists(object_id)

	-- Early return, if it exists within our object list, we don't need to call any sw functions.
	if g_objects.object_list[object_id] then
		return true
	end

	-- This object has been despawned, it cannot exist.
	if g_objects.despawned_objects[object_id] then
		return false
	end

	-- Do a function call to the game which returns false for is_success when the object cannot be found (meaning it doesn't exist)
	local _, exists = server.getObjectSimulating(object_id)

	-- This object exists, add it to the object list
	if exists then
		Object.addObject(object_id)
	end

	return exists
end

---# Safer check for if an object exists, as it just asks the game directly instead of having its own tables
---@param object_id integer the object_id of the object which we want to see if it exists.
---@return boolean exists if the object exists
function Object.safeExists(object_id)

	-- Do a function call to the game which returns false for is_success when the object cannot be found (meaning it doesn't exist)
	local _, exists = server.getObjectSimulating(object_id)

	-- This object exists and it doesn't yet exist in the object list, add it to the object list
	if exists and not g_objects.object_list[object_id] then
		Object.addObject(object_id)
	end

	return exists
end

-- Intercept onObjectUnload calls
local old_onObjectUnload = onObjectUnload
function onObjectUnload(object_id)
	-- avoid error if onObjectUnload is not used anywhere else before.
	if old_onObjectUnload then
		old_onObjectUnload(object_id)
	end

	-- if this object no longer exists
	if not Object.safeExists(object_id) then

		local object_data = g_objects.object_list[object_id]

		-- remove this object from the object list
		g_objects.object_list[object_id] = nil

		-- add this object to the list of objects that have been despawned
		g_objects.despawned_objects[object_id] = true

		-- call a onObjectDespawn function, if it exists
		---@diagnostic disable-next-line:undefined-global
		if onObjectDespawn then
			---@diagnostic disable-next-line:undefined-global
			onObjectDespawn(object_id, object_data)
		end

		-- check if its a character, if object_data exists
		if object_data and object_data.object_type == 1 then
			-- call the onCharacterDespawn function, if it exists
			---@diagnostic disable-next-line:undefined-global
			if onCharacterDespawn then
				---@diagnostic disable-next-line:undefined-global
				onCharacterDespawn(object_id, object_data)
			end
		end
	end
end

---@param object_id integer the object_id of the object which was despawned.
---@param object_data SWObjectData? the object data of the object which was despawned. (Not always gotten, advise on not relying on the given object_data)
function onObjectDespawn(object_id, object_data)

end

---@param object_id integer the object_id of the character which was despawned.
---@param object_data SWObjectData? the object data of the character which was despawned. (Data may be incomplete, advise on not relying on the given object_data)
function onCharacterDespawn(object_id, object_data)

end