--[[


	Library Setup


]]

-- required libraries
require("libraries.addon.script.debugging")

-- library name
Zones = {}

--[[


	Variables
   

]]

--[[


	Classes


]]

--[[


	Functions         


]]

function Zones.setup()
	local reservable_zones_list = s.getZones("npc_reservable")

	for zone_index, zone_data in pairs(reservable_zones_list) do
		g_savedata.zones.reservable[zone_index] = {
			reserved = false
		}
	end
end

---@param zone_index integer the index (id) of the zone
---@return boolean state if it reserved or not
function Zones.isReserved(zone_index)
	if not g_savedata.zones.reservable[zone_index] then
		d.print("(Zones.isReserved) zone_index is invalid, this zone is not stored!", true, 1)
		return
	end

	return g_savedata.zones.reservable[zone_index].reserved
end

---@param zone_index integer the index (id) of the zone
---@param state boolean the state to set
function Zones.setReserved(zone_index, state)
	if not g_savedata.zones.reservable[zone_index] then
		d.print("(Zones.setReserved) zone_index is invalid, this zone is not stored!", true, 1)
		return
	end

	g_savedata.zones.reservable[zone_index].reserved = state
end