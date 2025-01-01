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
	Stores the data for the towns, handles setup of their components, and just generally manages them.
]]

-- library name
Town = {}

--[[


	Classes


]]

---@alias TownID integer

---@class Town
---@field id TownID The ID of the town.
---@field name string The name of the town.
---@field buildings table<index, BuildingID> The buildings in the town.
---@field asset_holder_id AssetHolderID the id of this asset holder.

--[[


	Constants


]]

--[[


	Variables


]]

--[[


	Functions


]]

--- Creates a new town.
---@param id TownID The ID of the town.
---@param name string The name of the town.
---@return Town town The new town.
function Town.create(id, name)

	-- Create the town.
	---@type Town
	local new_town = {
		id = id,
		name = name,
		buildings = {},
		asset_holder_id = HoldableAssetManager.AssetHolder.new()
	}

	-- Return the town.
	return new_town
end

--- Adds a building to the town.
---@param town Town The town to add the building to.
---@param building Building the building to add to the town.
function Town.addBuilding(town, building)
	-- Add the building to the town.
	table.insert(town.buildings, building.id)
end
