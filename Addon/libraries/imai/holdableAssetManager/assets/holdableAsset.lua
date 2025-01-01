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
---@field asset_type AssetType The type of asset this is.

---@class HoldableAssetDefinition
---@field asset_type AssetType

---@alias HoldableAssets table<HoldableAsset>
--[[


	Constants


]]

---@type table<AssetType, HoldableAssetDefinition>
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
	BUILDING = 1
}

--[[


	Functions


]]

--- This function is used to define a new asset type.
---@param asset_type ASSET_TYPE The asset type to define.
function HoldableAssetManager.HoldableAsset.registerAssetType(asset_type)
end

--- This function is used to create the base definition of a holdable asset. This should only really be used by definitions, rather than actual implementations.
---@param asset_type AssetType the asset type this is.
---@return HoldableAsset holdable_asset the created asset.
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
	table.insert(g_savedata.libraries.asset_manager.holdable_assets.assets, holdable_asset)

	-- Return the asset.
	return g_savedata.libraries.asset_manager.holdable_assets.assets[#g_savedata.libraries.asset_manager.holdable_assets.assets]
end