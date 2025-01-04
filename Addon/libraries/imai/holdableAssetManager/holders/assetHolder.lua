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
---@field getHeldAssetsOfType fun(self: AssetHolder, asset_type: ASSET_TYPE): table<integer, HeldAsset> function to get all held assets of a certain type.

---@alias AssetHolders table<AssetHolderID, AssetHolder>


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

	-- Setup the functions for the asset holder.
	asset_holder = HoldableAssetManager.AssetHolder.setup(asset_holder)

	-- Increment the next_asset_holder_id
	g_savedata.libraries.asset_manager.asset_holders.next_asset_holder_id = g_savedata.libraries.asset_manager.asset_holders.next_asset_holder_id + 1

	-- Store the asset holder.
	g_savedata.libraries.asset_manager.asset_holders.holders[asset_holder.asset_holder_id] = asset_holder

	-- Return their ID.
	return asset_holder.asset_holder_id
end

--- Sets up the oop functions for an asset holder.
---@param asset_holder DirtyAssetHolder|AssetHolder the asset holder to setup the functions for.
---@return AssetHolder asset_holder the asset holder with the functions setup.
function HoldableAssetManager.AssetHolder.setup(asset_holder)

	--- Function to get all held assets of a certain type.
	---@param self AssetHolder the asset holder to get the assets from.
	---@param asset_type ASSET_TYPE the type of asset to get.
	---@return table<integer, HeldAsset> held_assets the held assets of that type.
	asset_holder.getHeldAssetsOfType = function(self, asset_type)
		local assets = {}

		-- Loop through all held assets, and add them to the list if they match the type.
		for _, held_asset in pairs(asset_holder.held_assets) do

			-- If the asset type matches, add it to the list.
			if held_asset.asset_type == asset_type then

				-- Add the asset to the list.
				table.insert(assets, held_asset)
			end
		end

		-- Return the assets.
		return assets
	end

	-- Return the asset holder. Cast to AssetHolder.
	return asset_holder --[[@as AssetHolder]]
end