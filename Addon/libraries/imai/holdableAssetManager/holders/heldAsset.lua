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
require("libraries.imai.holdableAssetManager.holders.assetRelationship")

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[ 
	This is used to store the information used to link assets and their holders, storing data such as their relationship, who granted them access, etc.
]]

-- library name
HoldableAssetManager.HeldAssets = {}

--[[


	Classes


]]

---@alias HeldAssetID integer

---@class HeldAsset This links an asset to a holder, which then stores data such as their relationship.
---@field held_asset_id HeldAssetID
---@field asset_id AssetID The asset this held asset is linked to
---@field relationship AssetRelationship The relationship between this holder and this asset
---@field grantor_holder_id AssetHolderID? Who granted this holder access to this asset, if applicable.

---@alias HeldAssets table<HeldAsset>

--[[


	Constants


]]

--[[


	Variables


]]

--[[


	Functions


]]

