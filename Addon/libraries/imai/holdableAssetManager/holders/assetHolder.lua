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

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[ 
	This file is used to define and handle some of the functionality for asset holders themselves.
]]

-- library name
HoldableAssetManager.AssetHolder = {}

--[[


	Classes


]]

---@alias AssetHolderID integer

---@class DirtyAssetHolder an asset holder without the OOP functions setup.
---@field asset_holder_id AssetHolderID
---@field held_assets HeldAssets

---@class AssetHolder: DirtyAssetHolder

---@alias AssetHolders table<AssetHolder>


--[[


	Constants


]]

--[[


	Variables


]]

g_savedata.libraries.asset_manager.asset_holders = {
	---@type AssetHolders
	holders = {},

	---@type AssetHolderID
	next_asset_holder_id = 1
}

--[[


	Functions


]]

--- This function is used to simply create a new AssetHolder, and returns it's ID. If the ID is lost, it is incredibly difficult to get back, so make sure it's stored.
--- @return AssetHolderID asset_holder_id the ID of the new holder.
function HoldableAssetManager.AssetHolder.new()

	--- Create the AssetHolder.
	---@type DirtyAssetHolder
	local asset_holder = {
		asset_holder_id = g_savedata.libraries.asset_manager.asset_holders.next_asset_holder_id,
		held_assets = {}
	}

	-- Increment the next_asset_holder_id
	g_savedata.libraries.asset_manager.asset_holders.next_asset_holder_id = g_savedata.libraries.asset_manager.asset_holders.next_asset_holder_id + 1

	-- Store the asset holder.
	table.insert(g_savedata.libraries.asset_manager.asset_holders.holders, asset_holder)

	-- Return their ID.
	return asset_holder.asset_holder_id
end