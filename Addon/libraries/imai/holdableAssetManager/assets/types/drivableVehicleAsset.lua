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
require("libraries.imai.holdableAssetManager.assets.holdableAsset")

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[ 
	Drivable Vehicle Asset Definition.
]]

---@class DrivableVehicleAsset: HoldableAsset
---@field drivable_vehicle_id DrivableVehicleID the ID of the drivable vehicle this is for.

-- Register the drivable vehicle asset type
HoldableAssetManager.HoldableAsset.registerAssetType(
	ASSET_TYPE.DRIVABLE_VEHICLE
)

--- This function is used to create a new drivable vehicle asset.
---@param drivable_vehicle_id DrivableVehicleID The ID of the drivable vehicle.
---@return AssetID The ID of the asset.
function HoldableAssetManager.HoldableAsset.createDrivableVehicleAsset(drivable_vehicle_id)
	-- Create the base asset.
	local asset_id = HoldableAssetManager.HoldableAsset.createBaseAsset(ASSET_TYPE.DRIVABLE_VEHICLE)

	-- Get the asset.
	local asset = HoldableAssetManager.HoldableAsset.getAsset(asset_id) --[[@as DrivableVehicleAsset]]

	-- Add the drivable vehicle ID.
	asset.drivable_vehicle_id = drivable_vehicle_id

	-- Return the asset ID.
	return asset_id
end