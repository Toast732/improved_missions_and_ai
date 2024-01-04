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

-- required libraries

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[ 
	Adds a item system, the items can be chosen to have no in game counterpart, or be made to be linked to one
	due to limitations, the name of the item cannot be changed, and there cannot be custom models.

	As of current, all items are hidden, as the functionality where they need to exist is not yet required.
]]

---@class ItemPrefab
---@field item_name string the name of the item
---@field equipment_id SWEquipmentTypeEnum? the equipment type, leave nil to have no in game model (If theres no in game model, it cannot be shown in game)
---@field data table the custom data for this item

---@class Item
---@field id integer the item's id
---@field name string the name of the item
---@field data table the item's custom data
---@field equipment_id SWEquipmentTypeEnum? the equipment type, nil if there is none
---@field hidden boolean if the item should be hidden

g_savedata.libraries.items = {
	item_list = {}, ---@type table<integer, Item>
	item_prefabs = {}, ---@type table<string, ItemPrefab>
	next_item_id = 1
}

Item = {}

---@param item_name string the name of the item
---@param equipment_id SWEquipmentTypeEnum? the equipment type, leave nil to have no in game model (If theres no in game model, it cannot be shown in game)
---@param data table the custom data for this item
---@return boolean is_success if the prefab was successfully updated or added.
function Item.createPrefab(item_name, equipment_id, data)

	--[[
		Ensure params are correct
	]]

	local item_name_type = type(item_name)

	if item_name_type ~= "string" then
		d.print(("<line>: Expected item_name to be a string, instead got %s"):format(item_name_type), true, 1)
		return false
	end

	local equipment_id_type = type(equipment_id)

	if math.type(equipment_id) ~= "integer" and equipment_id_type ~= "nil" then
		d.print(("<line>: Expected equipment_id to be an integer or nil, instead got %s"):format(equipment_id_type), true, 1)
		return false
	end

	local data_type = type(data)

	if data_type ~= "table" then
		d.print(("<line>: Expected data to be a table, instead got %s"):format(data_type), true, 1)
		return false
	end

	-- if this item already exists
	if g_savedata.libraries.items.item_prefabs[item_name] then
		-- update it's data, as this item is already added as a prefab
		local item_data = g_savedata.libraries.items.item_prefabs[item_name]

		item_data.equipment_id = equipment_id
		item_data.data = data

		return true
	end

	-- this item does not already exist, create it
	g_savedata.libraries.items.item_prefabs[item_name] = {
		item_name = item_name,
		equipment_id = equipment_id,
		data = data
	}

	return true
end

---@param item_name string the item's name
---@param hidden boolean if the item should be hidden.
---@return Item? item the item, returns nil if it failed to spawn
---@return boolean is_success if the item was successfully spawned.
function Item.create(item_name, hidden)

	--[[
		Ensure params are correct
	]]

	local item_name_type = type(item_name)

	if item_name_type ~= "string" then
		d.print(("<line>: Expected item_name to be a string, instead got %s"):format(item_name_type), true, 1)
		return nil, false
	end

	local hidden_type = type(hidden)

	if hidden_type ~= "boolean" and hidden_type ~= "nil" then
		d.print(("<line>: Expected hidden to be a boolean or nil, instead got %s"):format(item_name_type), true, 1)
		return nil, false
	end

	--[[
		Ensure this item exists
	]]
	local item_prefab = g_savedata.libraries.items.item_prefabs[item_name]

	if not item_prefab then
		d.print(("<line>: attempted to spawn item %s, which does not exist as a prefab."):format(item_name), true, 1)
		return nil, false
	end

	local item_id = g_savedata.libraries.items.next_item_id

	---@type Item
	local item = {
		id = item_id,
		name = item_name,
		data = table.copy.deep(item_prefab.data),
		equipment_id = item_prefab.equipment_id,
		hidden = hidden
	}

	table.insert(g_savedata.libraries.items.item_list, item)

	-- increment the next item id
	g_savedata.libraries.items.next_item_id = item_id + 1

	return item, true
end

---@param item_id integer the item's id
---@return Item? item
---@return boolean is_success
function Item.get(item_id)
	--[[
		Ensure params are correct
	]]

	local item_id_type = math.type(item_id)

	if item_id_type ~= "integer" then
		d.print(("<line>: Expected item_id to be an integer, instead got %s"):format(item_id_type), true, 1)
		return nil, false
	end

	for item_index = 1, #g_savedata.libraries.items.item_list do
		local item = g_savedata.libraries.items.item_list[item_index]
		if item.id == item_id then
			return item, true
		end
	end

	d.print(("<line>: Failed to find item with id %s"):format(item_id), true, 1)
	return nil, false
end