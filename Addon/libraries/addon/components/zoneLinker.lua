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
require("libraries.addon.script.matrix")

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[ 
	Given the SWAddonComponentData, it will try to find the zone's data which is for the given data.
]]

-- library name
ZoneLinker = {}

--[[


	Classes


]]

--[[


	Constants


]]

--[[


	Variables


]]

--[[


	Functions


]]

--- Function for getting the zone's data for the given SWAddonComponentData.
---@param component_data SWAddonComponentData The data to get the zone's data for.
---@param location_data SWLocationData The location data for the component.
---@return SWZone? zone_data The zone's data for the given SpawningData.
function ZoneLinker.getZoneData(component_data, location_data)

	-- Find all zones with the matching tags of this object.
	local zones = server.getZones(component_data.tags_full)

	-- Find the tile's location, which this component is on.
	local tile_transform_matrix, is_success = server.getTileTransform(matrix.identity(), location_data.tile)

	-- If the tile's location was not found, return nil.
	if not is_success then
		d.print(("<line>: (ZoneLinker.getZoneData) Failed to find an instance of the tile \"%s\""):format(location_data.tile), true, 1)
		return nil
	end

	-- Get the global coordinates of the component.
	local global_component_matrix = matrix.multiply(tile_transform_matrix, component_data.transform)

	-- Iterate through each zone.
	for _, zone_data in ipairs(zones) do
		-- If the zone's matrix is the same as the component's matrix, return it.
		if matrix.equals(zone_data.transform, global_component_matrix) then
			return zone_data
		end
	end

	-- Print the zone matricies.
	for _, zone_data in ipairs(zones) do
		d.print("Zone Matrix: " .. string.fromTable(zone_data.transform))
	end

	-- Print the given component's matrix.
	d.print("Component Matrix: " .. string.fromTable(global_component_matrix))
end