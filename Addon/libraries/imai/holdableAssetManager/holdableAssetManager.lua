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
	This is used to store the list of assets, to keep this system modular, these are not tied directly to a citizen, but instead, use an asset_holder_id to link to
		owners.

	An asset is an something that the holder has access to. An asset is kept abstract, so it could be an object, a vehicle, a building, or just a virtual item for data storage.

	Additionally, the asset holder does not always mean ownership, and does not mean that the asset is always accessible to the holders. For example,
		a citizen may have a car, but, it's currently in use by one of their family members, so, currently, they do not have access to it.
		another possibility, is that a citizen may have a car, but it was stolen by the player, as such, the player is now an asset holder, and the citizen does not have access to it.

		The owner has the power to decide who has access to the asset, and can revoke access at any time, to anybody they lent it to. (stealing it overrides this, however.)
]]

-- library name
HoldableAssetManager = {}

--[[


	Classes


]]

--[[


	Constants


]]

--[[


	Variables


]]

g_savedata.libraries.asset_manager = {}

--[[


	Functions


]]

--[[


	Post Required Libraries


]]

require("libraries.imai.holdableAssetManager.assets.holdableAsset")
require("libraries.imai.holdableAssetManager.holders.assetHolder")
require("libraries.imai.holdableAssetManager.holders.assetRelationship")
require("libraries.imai.holdableAssetManager.holders.heldAsset")