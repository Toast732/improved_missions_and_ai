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
require("libraries.addon.utils.objects.characters.inventory.item")

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[ 
	Adds a sort of inventory system, the inventory can be expanded past the normal
	inventory, and can contain custom items, these items cannot add their own models or
	change the name when held, but they can be simulated as different. These can also
	be made hidden, worn, and have no in game counterpart (Hidden items and ones with no
	in game counterpart cannot be put in the in game inventory.)

	As of current, all items are hidden, as the functionality where they need to exist is not yet required.
]]

---@class Inventory
---@field items table<integer, Item> All of the items this character has
---@field active table<integer, Item> The items this character has active
---@field id integer the inventory id.

g_savedata.libraries.inventory = {
	inventories = {},
	next_inventory_id = 1
}

Inventory = {}

---@return Inventory inventory the created inventory.
function Inventory.create()

	-- create the inventory
	g_savedata.libraries.inventory.inventories[g_savedata.libraries.inventory.next_inventory_id] = {
		items = {},
		active = {},
		id = g_savedata.libraries.inventory.next_inventory_id
	}

	-- increment the next inventory id
	g_savedata.libraries.inventory.next_inventory_id = g_savedata.libraries.inventory.next_inventory_id + 1

	return g_savedata.libraries.inventory.inventories[g_savedata.libraries.inventory.next_inventory_id - 1]
end

---@param inventory_id integer the id of the inventory which you want to get.
---@return Inventory? inventory the inventory with the associated id, returns nil if that inventory does not exist.
function Inventory.get(inventory_id)

	-- get the inventory
	local inventory = g_savedata.libraries.inventory.inventories[inventory_id]

	-- if it does not exist
	if not inventory then
		d.print(("<line>: Attempted to get non existing inventory with id: %s"):format(inventory_id), true, 1)
	end

	-- return inventory.
	return inventory
end


function Inventory.addItem(inventory_id, item, is_active)

	-- get the inventory
	local inventory = Inventory.get(inventory_id)

	-- if it failed to get the inventory
	if not inventory then
		-- return that we failed to get it.
		return false
	end
	
	-- add it to the item list
	table.insert(inventory.items, item)

	-- if this item should be active
	if is_active then
		-- add it to the active item list
		table.insert(inventory.active, item)
	end
end

---@param item_name string the name of the item you want to see if it exists
---@return Item? item the item if it exists, returns nil if not found.
---@return boolean exists if this item exists
---@return boolean active if the inventory has this item active
---@return boolean is_success if it was able to check the inventories (false means that it failed to get the inventory, so the given inventory id is invalid.)
function Inventory.hasItem(inventory_id, item_name)
	local inventory = Inventory.get(inventory_id)

	if not inventory then
		return nil, false, false, false
	end

	-- check active list
	for item_index = 1, #inventory.active do
		local item = inventory.active[item_index]
		if item.name == item_name then
			return item, true, true, true
		end
	end

	-- check full item list, as its not active
	for item_index = 1, #inventory.items do
		local item = inventory.items[item_index]
		if item.name == item_name then
			return item, true, false, true
		end
	end

	-- item does not exist in this inventory
	return nil, false, false, true
end