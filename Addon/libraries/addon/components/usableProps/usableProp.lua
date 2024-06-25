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

-- Library Version 0.0.2

--[[


	Library Setup


]]

-- required libraries

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[ 
	Used for the individual handling of the usable props.
]]

-- library name
UsableProp = {}

--[[


	Classes


]]

---@class DirtyUsableProp
---@field id UsablePropID
---@field type UsablePropType
---@field transform SWMatrix
---@field name string The name of the usable prop, via the display name of the zone.
---@field tags table<integer, string> The tags for the usable prop.
---@field tags_full string The full tags for the usable prop.
---@field size Vector3 The size of the usable prop.
---@field parent_relative_transform SWMatrix
---@field parent_vehicle_id integer
---@field capacity integer The amount of entities that can use this prop at once.
---@field entities table<integer, integer> The object_ids of the entities that are currently using this prop.

---@class UsableProp: DirtyUsableProp
---@field matches fun(usable_prop: UsableProp, addon_component_data: SWAddonComponentData, zone_data: SWZone): boolean The function for checking if the usable prop matches the given data.
---@field addEntity fun(usable_prop: UsableProp, object_id: integer): boolean The function for adding an entity to the usable prop.

--[[


	Constants


]]

---@enum UsablePropType
USABLE_PROP_TYPE = {
	BED = 1,
	AI_JOB = 2
}

--[[


	Variables


]]

--[[


	Functions


]]

--- Function for turning the tags into the usable prop's type.
---@param addon_component_data SWAddonComponentData The data for the prop.
---@return UsablePropType? usable_prop_type The usable prop's type, nil if failed.
function UsableProp.getUsablePropType(addon_component_data)
	-- Find the value of the tag "prop".
	local type_value = Tags.getValue(addon_component_data.tags, "prop", true)

	-- If the value was not found, return nil.
	if not type_value then
		d.print(("<line>: (UsableProp.getUsablePropType) Failed to get the value of the tag \"prop\" for the given addon_component_data with the tags of \"%s\""):format(
			addon_component_data.tags_full
		), true, 1)
		return nil
	end

	-- Find it by indexing the enum
	local usable_prop_type = USABLE_PROP_TYPE[type_value:upper()]

	-- If it was not found, return nil.
	if not usable_prop_type then
		d.print(("<line>: (UsableProp.getUsablePropType) Failed to find the usable prop type for the value \"%s\""):format(
			type_value
		), true, 1)
		return nil
	end

	return usable_prop_type
end

--- Function for creating a new usable prop.
---@param addon_component_data SWAddonComponentData The data for the prop.
---@param zone SWZone The zone that the prop is in.
---@return UsableProp? usable_prop The created usable prop, nil if failed.
function UsableProp.new(addon_component_data, zone)
	-- Get the usable prop's type.
	local usable_prop_type = UsableProp.getUsablePropType(addon_component_data)

	-- If the usable prop's type was not found, return nil.
	if not usable_prop_type then
		return nil
	end

	-- Create the new usable prop, most of the data is temp junk data, is set properly in the update function.
	---@type DirtyUsableProp
	local dirty_usable_prop = {
		id = g_savedata.libraries.usable_props.next_id,
		type = usable_prop_type,
		name = zone.name,
		transform = zone.transform,
		tags = addon_component_data.tags,
		tags_full = addon_component_data.tags_full,
		size = Vector3.new(0, 0, 0),
		parent_relative_transform = zone.parent_relative_transform,
		parent_vehicle_id = zone.parent_vehicle_id,
		capacity = 1,
		entities = {}
	}

	-- Increment the next ID.
	g_savedata.libraries.usable_props.next_id = g_savedata.libraries.usable_props.next_id + 1

	-- Setup the OOP functions for the usable prop.
	local usable_prop = UsableProp.setupOOP(dirty_usable_prop)

	-- Return the updated usable prop.
	return UsableProp.update(usable_prop, addon_component_data, zone)
end

--- Function for updating a usable prop from the given component data and zone data.
---@param usable_prop UsableProp The dirty usable prop to update.
---@param props_addon_component_data SWAddonComponentData The data for the prop.
---@param zone SWZone The zone that the prop is in.
---@return UsableProp usable_prop The updated usable prop.
function UsableProp.update(usable_prop, props_addon_component_data, zone)

	-- Update the usable prop's name
	usable_prop.name = zone.name

	-- Update the usable prop's transform
	usable_prop.transform = zone.transform

	-- Update the usable prop's tags
	usable_prop.tags = props_addon_component_data.tags
	usable_prop.tags_full = props_addon_component_data.tags_full

	-- Update the usable prop's size
	usable_prop.size = Vector3.new(
		zone.size.x,
		zone.size.y,
		zone.size.z
	)

	-- Update the usable prop's parent relative transform
	usable_prop.parent_relative_transform = zone.parent_relative_transform

	-- Update the usable prop's parent vehicle id
	usable_prop.parent_vehicle_id = zone.parent_vehicle_id

	-- Update the usable prop's capacity
	usable_prop.capacity = Tags.getValue(props_addon_component_data.tags, "capacity", false) --[[@as integer]] or 1

	-- Return the updated usable prop.
	return usable_prop
end

--- Sets up the OOP functions for the usable props.
---@param dirty_usable_prop DirtyUsableProp|UsableProp The dirty usable prop to update, or the usable prop to update.
---@return UsableProp usable_prop The updated usable prop.
function UsableProp.setupOOP(dirty_usable_prop)
	---@cast dirty_usable_prop UsableProp

	--- Check if the usable prop matches the given data.
	---@param self UsableProp The usable prop to check against.
	---@param addon_component_data SWAddonComponentData The addon component data to check against.
	---@param zone_data SWZone The zone data to check against.
	---@return boolean matches If the usable prop matches the given data.
	dirty_usable_prop.matches = function(self, addon_component_data, zone_data)

		-- If the usable prop's type is the same, and the transform is the same, then we found a match.
		return (
			self.type == UsableProp.getUsablePropType(addon_component_data) -- if the type is the same
			and matrix.g_equals(self.transform, zone_data.transform) -- if the transform is the same.
		)
	end

	--- Attempts to add a new entity to the usable prop, returns false if the prop is full.
	---@param self UsableProp The usable prop to add the entity to.
	---@param object_id integer The object_id of the entity to add.
	---@return boolean success If the entity was successfully added.
	dirty_usable_prop.addEntity = function(self, object_id)
		-- If the usable prop is full, return false.
		if #self.entities >= self.capacity then
			return false
		end

		-- Add the entity to the usable prop.
		table.insert(self.entities, object_id)

		return true
	end

	-- Return the updated usable prop.
	return dirty_usable_prop
end
