--[[
	
Copyright 2025 Liam Matthews

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
require("libraries.imai.holdableAssetManager.holdableAssetManager") -- require here, to ensure it's put above this file.

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[ 
	This defines the class for a holdable asset.
]]

-- library name
HoldableAssetManager.HoldableAsset = {}

--[[


	Classes


]]

---@alias AssetID integer

---@class HoldableAsset
---@field asset_id AssetID
---@field asset_type ASSET_TYPE The type of asset this is.

---@class HoldableAssetDefinition
---@field asset_type ASSET_TYPE

---@alias HoldableAssets table<AssetID, HoldableAsset>
--[[


	Constants


]]

---@type table<ASSET_TYPE, HoldableAssetDefinition>
HOLDABLE_ASSET_DEFINITIONS = {}

--[[


	Variables


]]

g_savedata.libraries.asset_manager.holdable_assets = {
	---@type HoldableAssets
	assets = {},

	---@type AssetID
	next_asset_id = 1
}

---@enum ASSET_TYPE
ASSET_TYPE = {
	BUILDING = 1,
	DRIVABLE_VEHICLE = 2
}

--[[


	Functions


]]

--- This function is used to define a new asset type.
---@param asset_type ASSET_TYPE The asset type to define.
function HoldableAssetManager.HoldableAsset.registerAssetType(asset_type)
end

--- This function is used to create the base definition of a holdable asset. This should only really be used by definitions, rather than actual implementations.
---@param asset_type ASSET_TYPE the asset type this is.
---@return AssetID asset_id the created asset's ID.
function HoldableAssetManager.HoldableAsset.createBaseAsset(asset_type)
	-- Create the asset.
	---@type HoldableAsset
	local holdable_asset = {
		asset_id = g_savedata.libraries.asset_manager.holdable_assets.next_asset_id,
		asset_type = asset_type
	}

	-- Increment the next_asset_id
	g_savedata.libraries.asset_manager.holdable_assets.next_asset_id = g_savedata.libraries.asset_manager.holdable_assets.next_asset_id + 1

	-- Store the asset.
	g_savedata.libraries.asset_manager.holdable_assets.assets[holdable_asset.asset_id] = holdable_asset

	-- Return the asset id.
	return holdable_asset.asset_id
end

--- This function is used to get an asset by it's ID.
---@param asset_id AssetID The ID of the asset to get.
---@return HoldableAsset asset The asset.
function HoldableAssetManager.HoldableAsset.getAsset(asset_id)
	return g_savedata.libraries.asset_manager.holdable_assets.assets[asset_id]
end