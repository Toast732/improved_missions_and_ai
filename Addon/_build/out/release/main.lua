 
--? Copyright 2022 Liam Matthews

--? Licensed under the Apache License, Version 2.0 (the "License");
--? you may not use this file except in compliance with the License.
--? You may obtain a copy of the License at

--?		http://www.apache.org/licenses/LICENSE-2.0

--? Unless required by applicable law or agreed to in writing, software
--? distributed under the License is distributed on an "AS IS" BASIS,
--? WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--? See the License for the specific language governing permissions and
--? limitations under the License.

--! (If gotten from Steam Workshop) LICENSE is in vehicle_0.xml
--! (If gotten from anywhere else) LICENSE is in LICENSE and vehicle_0.xml

-- Author: Toastery
-- GitHub: https://github.com/Toast732
-- Workshop: https://steamcommunity.com/id/Toastery7/myworkshopfiles/?appid=573090
--
--- Developed using LifeBoatAPI - Stormworks Lua plugin for VSCode - https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)
--- If you have any issues, please report them here: https://github.com/nameouschangey/STORMWORKS_VSCodeExtension/issues - by Nameous Changey

ADDON_VERSION = "(0.0.1.6)"
IS_DEVELOPMENT_VERSION = string.match(ADDON_VERSION, "(%d%.%d%.%d%.%d)")

SHORT_ADDON_NAME = "IMAI"

local just_migrated = false

-- shortened library names
local m = matrix
local s = server

local time = { -- the time unit in ticks, irl time, not in game
	second = 60,
	minute = 3600,
	hour = 216000,
	day = 5184000
}

---@enum DebugTypes
debug_types = {
	[-1] = "all",
	[0] = "chat",
	"error",
	"profiler",
	"map",
	"graph_node",
	"driving",
	"vehicle",
	"function",
	"traceback"
}

g_savedata = {
	tick_counter = 0,
	vehicles = {
		ai = {
			loaded = {}, -- used to index data, to only iterate loaded vehicles
			unloaded = {}, -- used to index data, to only iterate unloaded vehicles
			data = {},
			totals = {
				types = {
					land = 0,
					sea = 0,
					heli = 0,
					plane = 0
				}
			}
		}
	},
	towns = {
		data = {} -- where the town data is stored
	},
	citizens = {
		data = {} -- where the citizens are stored
	},
	zones = {
		reservable = {} -- used for zones used for jobs, or recreation, so two npcs cannot use the same zone
	},
	info = {
		version_history = {
			{
				version = ADDON_VERSION,
				ticks_played = 0,
				backup_g_savedata = {}
			}
		},
		addons = {
			improved_conquest_mode = false,
			default_missions = false,
			default_ai = false,
			ai_paths = false
		},
		mods = {
			NSO = false
		}
	},
	players = {
		online = {}, -- indexed by peer_id, value is steam_id, to index individual_data
		individual_data = {},
		global_data = {}
	},
	cache = {
		data = {},
		stats = {
			reads = 0,
			writes = 0,
			failed_writes = 0,
			resets = 0
		}
	},
	profiler = {
		working = {},
		total = {},
		display = {
			average = {},
			max = {},
			current = {}
		},
		ui_id = nil
	},
	debug = {
		chat = {
			enabled = false,
			default = false,
			needs_setup_on_reload = false
		},
		error = {
			enabled = false,
			default = false,
			needs_setup_on_reload = false
		},
		profiler = {
			enabled = false,
			default = false,
			needs_setup_on_reload = false
		},
		map = {
			enabled = false,
			default = false,
			needs_setup_on_reload = false
		},
		graph_node = {
			enabled = false,
			default = false,
			needs_setup_on_reload = false
		},
		driving = {
			enabled = false,
			default = false,
			needs_setup_on_reload = false
		},
		vehicle = {
			enabled = false,
			default = false,
			needs_setup_on_reload = false
		},
		["function"] = {
			enabled = false,
			default = false,
			needs_setup_on_reload = true
		},
		traceback = {
			enabled = false,
			default = false,
			needs_setup_on_reload = true,
			stack = {},
			stack_size = 0,
			funct_names = {},
			funct_count = 0
		}
	},
	graph_nodes = {
		init = false,
		init_debug = false,
		nodes = {}
	},
	libraries = {}
}

-- libraries
--[[
	
Copyright 2023 Liam Matthews

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

--[[


	Library Setup


]]

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[ 
	Adds additional functions related to handling objects, such as onObjectDespawn,
	Object.exists(), etc
]]

-- library name
Object = {}

--[[


	Variables


]]

g_savedata.libraries.objects = {
	object_list = {}, ---@type table<integer, SWObjectData> indexed by object_id, value is the object's data.
	despawned_objects = {} ---@type table<integer, true> indexed by object_id, a table of objects that have been despawned.
}

local g_objects = g_savedata.libraries.objects

---# Adds an object to the object list
---@param object_id integer the object_id of the object to add.
---@return boolean is_success if it successfully added the object to the object list, returns false if the object doesn't actually exist.
function Object.addObject(object_id)
	local object_data = server.getObjectData(object_id)

	-- the object doesn't actually exist
	if not object_data then
		d.print(("247: attempt to add non-existing object %s to object list"):format(object_id), true, 1)
		return false
	end

	-- add the object to the object list
	g_objects.object_list[object_id] = object_data

	return true
end

---# Checks if an object exists
---@param object_id integer the object_id of the object which we want to see if it exists.
---@return boolean exists if the object exists
function Object.exists(object_id)

	-- Early return, if it exists within our object list, we don't need to call any sw functions.
	if g_objects.object_list[object_id] then
		return true
	end

	-- This object has been despawned, it cannot exist.
	if g_objects.despawned_objects[object_id] then
		return false
	end

	-- Do a function call to the game which returns false for is_success when the object cannot be found (meaning it doesn't exist)
	local _, exists = server.getObjectSimulating(object_id)

	-- This object exists, add it to the object list
	if exists then
		Object.addObject(object_id)
	end

	return exists
end

---# Safer check for if an object exists, as it just asks the game directly instead of having its own tables
---@param object_id integer the object_id of the object which we want to see if it exists.
---@return boolean exists if the object exists
function Object.safeExists(object_id)

	-- Do a function call to the game which returns false for is_success when the object cannot be found (meaning it doesn't exist)
	local _, exists = server.getObjectSimulating(object_id)

	-- This object exists and it doesn't yet exist in the object list, add it to the object list
	if exists and not g_objects.object_list[object_id] then
		Object.addObject(object_id)
	end

	return exists
end

-- Intercept onObjectUnload calls
local old_onObjectUnload = onObjectUnload
function onObjectUnload(object_id)
	-- avoid error if onObjectUnload is not used anywhere else before.
	if old_onObjectUnload then
		old_onObjectUnload(object_id)
	end

	-- if this object no longer exists
	if not Object.safeExists(object_id) then

		local object_data = g_objects.object_list[object_id]

		-- remove this object from the object list
		g_objects.object_list[object_id] = nil

		-- add this object to the list of objects that have been despawned
		g_objects.despawned_objects[object_id] = true

		-- call a onObjectDespawn function, if it exists
		---@diagnostic disable-next-line:undefined-global
		if onObjectDespawn then
			---@diagnostic disable-next-line:undefined-global
			onObjectDespawn(object_id, object_data)
		end

		-- check if its a character, if object_data exists
		if object_data and object_data.object_type == 1 then
			-- call the onCharacterDespawn function, if it exists
			---@diagnostic disable-next-line:undefined-global
			if onCharacterDespawn then
				---@diagnostic disable-next-line:undefined-global
				onCharacterDespawn(object_id, object_data)
			end
		end
	end
end

---@param object_id integer the object_id of the object which was despawned.
---@param object_data SWObjectData? the object data of the object which was despawned. (Not always gotten, advise on not relying on the given object_data)
function onObjectDespawn(object_id, object_data)

end

---@param object_id integer the object_id of the character which was despawned.
---@param object_data SWObjectData? the object data of the character which was despawned. (Data may be incomplete, advise on not relying on the given object_data)
function onCharacterDespawn(object_id, object_data)

end
--[[
	
Copyright 2023 Liam Matthews

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
---@param str string the string to make the first letter uppercase
---@return string|nil str the string with the first letter uppercase
function string.upperFirst(str)
	if type(str) == "string" then
		return (str:gsub("^%l", string.upper))
	end
	return nil
end

--- @param str string the string the make friendly
--- @param remove_spaces boolean? true for if you want to remove spaces, will also remove all underscores instead of replacing them with spaces
--- @param keep_caps boolean? if you want to keep the caps of the name, false will make all letters lowercase
--- @return string|nil friendly_string friendly string, nil if input_string was not a string
function string.friendly(str, remove_spaces, keep_caps) -- function that replaced underscores with spaces and makes it all lower case, useful for player commands so its not extremely picky

	if not str or type(str) ~= "string" then
		d.print("(string.friendly) str is not a string! type: "..tostring(type(str)).." provided str: "..tostring(str), true, 1)
		return nil
	end

	-- make all lowercase
	
	local friendly_string = not keep_caps and string.lower(str) or str

	-- replace all underscores with spaces
	friendly_string = string.gsub(friendly_string, "_", " ")

	-- if remove_spaces is true, remove all spaces
	if remove_spaces then
		friendly_string = string.gsub(friendly_string, " ", "")
	end

	return friendly_string
end

---@param vehicle_name string the name you want to remove the prefix of
---@param keep_caps boolean? if you want to keep the caps of the name, false will make all letters lowercase
---@return string vehicle_name the vehicle name without its vehicle type prefix
function string.removePrefix(vehicle_name, keep_caps)

	if not vehicle_name then
		d.print("(string.removePrefix) vehicle_name is nil!", true, 1)
		return vehicle_name
	end

	local vehicle_type_prefixes = {
		"BOAT %- ",
		"HELI %- ",
		"LAND %- ",
		"TURRET %- ",
		"PLANE %- "
	}

	-- replaces underscores with spaces
	local vehicle_name = string.gsub(vehicle_name, "_", " ")

	-- remove the vehicle type prefix from the entered vehicle name
	for _, prefix in ipairs(vehicle_type_prefixes) do
		vehicle_name = string.gsub(vehicle_name, prefix, "")
	end

	-- makes the string friendly
	vehicle_name = string.friendly(vehicle_name, false, keep_caps)

	if not vehicle_name then
		d.print("(string.removePrefix) string.friendly() failed, and now vehicle_name is nil!", true, 1)
		return ""
	end

	return vehicle_name
end

--- Returns a string in a format that looks like how the table would be written.
---@param t table the table you want to turn into a string
---@return string str the table but in string form.
function string.fromTable(t)

	if type(t) ~= "table" then
		d.print(("(string.fromTable) t is not a table! type of t: %s t: %s"):format(type(t), t), true, 1)
	end

	local function tableToString(T, S, ind)
		S = S or "{"
		ind = ind or "  "

		local table_length = table.length(T)
		local table_counter = 0

		for index, value in pairs(T) do

			table_counter = table_counter + 1
			if type(index) == "number" then
				S = ("%s\n%s[%s] = "):format(S, ind, tostring(index))
			elseif type(index) == "string" and tonumber(index) and math.isWhole(tonumber(index)) then
				S = ("%s\n%s\"%s\" = "):format(S, ind, index)
			else
				S = ("%s\n%s%s = "):format(S, ind, tostring(index))
			end

			if type(value) == "table" then
				S = ("%s{"):format(S)
				S = tableToString(value, S, ind.."  ")
			elseif type(value) == "string" then
				S = ("%s\"%s\""):format(S, tostring(value))
			else
				S = ("%s%s"):format(S, tostring(value))
			end

			S = ("%s%s"):format(S, table_counter == table_length and "" or ",")
		end

		S = ("%s\n%s}"):format(S, string.gsub(ind, "  ", "", 1))

		return S
	end

	return tableToString(t)
end

--- returns the number of instances of that character in the string
---@param str string the string we are wanting to check
---@param char any the character(s) we are wanting to count for in str, note that this is as a lua pattern
---@return number count the number of instances of char, if there was an error, count will be 0, and is_success will be false
---@return boolean is_success if we successfully got the number of instances of the character
function string.countCharInstances(str, char)

	if type(str) ~= "string" then
		d.print(("(string.countCharInstances) str is not a string! type of str: %s str: %s"):format(type(str), str), true, 1)
		return 0, false
	end

	char = tostring(char)

	local _, count = string.gsub(str, char, "")

	return count, true
end

--- Turns a string into a boolean, returns nil if not possible.
---@param val any the value we want to turn into a boolean
---@return boolean|nil bool the string turned into a boolean, is nil if string is not able to be turned into a boolean
function string.toboolean(val)

	local val_type = type(val)
	
	if val_type == "boolean" then
		-- early out for booleans
		return val
	elseif val_type ~= "string" then
		-- non strings cannot be "true" or "false", so will never return a boolean, so just early out.
		return nil
	end

	local str = string.lower(val)

	-- not convertable, return nil
	if str ~= "true" and str ~= "false" then
		return nil
	end

	-- convert
	return str == "true"
end

--- Turns a value from a string into its proper value, eg: "true" becomes a boolean of true, and ""true"" becomes a string of "true"
---@param val any the value to convert
---@return any parsed_value the converted value
function string.parseValue(val)
	local val_type = type(val)

	-- early out (no need to convert)
	if val_type ~= "string" then
		return val
	end

	-- value as an integer
	local val_int = math.tointeger(val)
	if val_int then return val_int end

	-- value as a number
	local val_num = tonumber(val)
	if val_num then return val_num end

	-- value as a boolean
	local val_bool = string.toboolean(val)
	if val_bool ~= nil then return val_bool end

	-- value as a table
	if val:sub(1, 1) == "{" then
		local val_tab = table.fromString(val)

		if val_tab then return val_tab end
	end

	--[[
		assume its a string
	]]

	-- if it has a " at the start, remove it
	if val:sub(1, 1) == "\"" then
		val = val:sub(2, val:len())
	end

	-- if it has a " at the end, remove it
	local val_len = val:len()
	if val:sub(val_len, val_len) == "\"" then
		val = val:sub(1, val_len - 1)
	end

	-- return the string
	return val
end

-- variables for if you want to account for leap years or not.
local days_in_a_year = 365.25
local days_per_month = days_in_a_year/12

---@class timeFormatUnit -- how to format each unit, use ${plural} to have an s be added if the number is plural.
---@field prefix string the string before the number
---@field suffix string the string after the number

---@alias timeFormatUnits
---| '"millisecond"'
---| '"second"'
---| '"minute"'
---| '"hour"'
---| '"day"'
---| '"week"'
---| '"month"'
---| '"year"'

---@class timeFormat
---@field show_zeros boolean if zeros should be shown, if true, units with a value of 0 will be removed.
---@field time_zero_string string the string to show if the time specified is 0
---@field seperator string the seperator to be put inbetween each unit.
---@field final_seperator string the seperator to put for the space inbetween the last units in the list
---@field largest_first boolean if it should be sorted so the string has the highest unit be put first, set false to have the lowest unit be first.
---@field units table<timeFormatUnits, timeFormatUnit>

time_formats = {
	yMwdhmsMS = {
		show_zeros = false,
		time_zero_string = "less than 1 millisecond",
		seperator = ", ",
		final_seperator = ", and ",
		largest_first = true,
		units = {
			millisecond = {
				prefix = "",
				suffix = " millisecond${plural}"
			},
			second = {
				prefix = "",
				suffix = " second${plural}"
			},
			minute = {
				prefix = "",
				suffix = " minute${plural}"
			},
			hour = {
				prefix = "",
				suffix = " hour${plural}"
			},
			day = {
				prefix = "",
				suffix = " day${plural}"
			},
			week = {
				prefix = "",
				suffix = " week${plural}"
			},
			month = {
				prefix = "",
				suffix = " month${plural}"
			},
			year = {
				prefix = "",
				suffix = " year${plural}"
			}
		}
	},
	yMdhms = {
		show_zeros = false,
		time_zero_string = "less than 1 second",
		seperator = ", ",
		final_seperator = ", and ",
		largest_first = true,
		units = {
			second = {
				prefix = "",
				suffix = " second${plural}"
			},
			minute = {
				prefix = "",
				suffix = " minute${plural}"
			},
			hour = {
				prefix = "",
				suffix = " hour${plural}"
			},
			day = {
				prefix = "",
				suffix = " day${plural}"
			},
			month = {
				prefix = "",
				suffix = " month${plural}"
			},
			year = {
				prefix = "",
				suffix = " year${plural}"
			}
		}
	}
}

---@type table<timeFormatUnits, number> the seconds needed to make up each unit.
local seconds_per_unit = {
	millisecond = 0.001,
	second = 1,
	minute = 60,
	hour = 3600,
	day = 86400,
	week = 604800,
	month = 86400*days_per_month,
	year = 86400*days_in_a_year
}

-- 1 being smallest unit, going up to largest unit
---@type table<integer, timeFormatUnits>
local unit_heiarchy = {
	"millisecond",
	"second",
	"minute",
	"hour",
	"day",
	"week",
	"month",
	"year"
}

---[[@param formatting string the way to format it into time, wrap the following in ${}, overflow will be put into the highest unit available. t is ticks, ms is milliseconds, s is seconds, m is minutes, h is hours, d is days, w is weeks, M is months, y is years. if you want to hide the number if its 0, use : after the time type, and then optionally put the message after that you want to only show if that time unit is not 0, for example, "${s: seconds}", enter "default" to use the default formatting.]]

---@param format timeFormat the format type, check the time_formats table for examples or use one from there.
---@param time number the time in seconds, decimals can be used for milliseconds.
---@param as_game_time boolean? if you want it as in game time, leave false or nil for irl time (yet to be supported)
---@return string formatted_time the time formatted into a more readable string.
function string.formatTime(format, time, as_game_time)
	--[[if formatting == "default" then
		formatting = "${y: years, }${M: months, }${d: days, }${h: hours, }${m: minutes, }${s: seconds, }${ms: milliseconds}"]]

	-- return the time_zero_string if the given time is zero.
	if time == 0 then
		return format.time_zero_string
	end

	local leftover_time = time

	---@class formattedUnit
	---@field unit_string string the string to put for this unit
	---@field unit_name timeFormatUnits the unit's type

	---@type table<integer, formattedUnit>
	local formatted_units = {}

	-- go through all of the units, largest unit to smallest.
	for unit_index = #unit_heiarchy, 1, -1 do
		-- get it's name
		local unit_name = unit_heiarchy[unit_index]

		-- the unit's format data
		local unit_data = format.units[unit_name]

		-- unit data is nil if its not formatted, so just skip if its not in the formatting
		if not unit_data then
			goto next_unit
		end

		-- how many seconds can go into this unit
		local seconds_in_unit =  seconds_per_unit[unit_name]

		-- get the number of this unit from the given time.
		local time_unit_instances = leftover_time/seconds_in_unit

		-- skip this unit if we don't want to show zeros, and this is less than 1.
		if not format.show_zeros and math.abs(time_unit_instances) < 1 then
			goto next_unit
		end

		-- format this unit
		local unit_string = ("%s%0.0f%s"):format(unit_data.prefix, time_unit_instances, unit_data.suffix)

		-- if this unit is not 1, then add an s to where it wants the plurals to be.
		unit_string = unit_string:setField("plural", math.floor(time_unit_instances) == 1 and "" or "s")

		-- add the formatted unit to the formatted units table.
		table.insert(formatted_units, {
			unit_string = unit_string,
			unit_name = unit_name
		} --[[@as formattedUnit]])

		-- subtract the amount of time this unit used up, from the leftover time.
		leftover_time = leftover_time - math.floor(time_unit_instances)*seconds_in_unit

		::next_unit::
	end

	-- theres no formatted units, just put the message for when the time is zero.
	if #formatted_units == 0 then
		return format.time_zero_string
	end

	-- sort the formatted_units table by the way the format wants it sorted.
	table.sort(formatted_units,
		function(a, b)
			return math.xor(
				seconds_per_unit[a.unit_name] < seconds_per_unit[b.unit_name],
				format.largest_first
			)
		end
	)

	local formatted_time = formatted_units[1].unit_string

	local formatted_unit_count = #formatted_units
	for formatted_unit_index = 2, formatted_unit_count do
		if formatted_unit_index == formatted_unit_count then
			formatted_time = formatted_time..format.final_seperator..formatted_units[formatted_unit_index].unit_string
		else
			formatted_time = formatted_time..format.seperator..formatted_units[formatted_unit_index].unit_string
		end
	end

	return formatted_time
end

---# Sets the field in a string
--- for example: <br> 
---> self: "Money: ${money}" <br> field: "money" <br> value: 100 <br> **returns: "Money: 100"**
---
--- <br> This function is almost interchangable with gsub, but first checks if the string matches, which might help with performance in certain scenarios, also doesn't require the user to type the ${}, and can be cleaner to read.
---@param str string the string to set the fields in
---@param field string the field to set
---@param value any the value to set the field to
---@param skip_check boolean|nil if it should skip the check for if the field is in the string.
---@return string str the string with the field set.
function string.setField(str, field, value, skip_check)

	local field_str = ("${%s}"):format(field)
	-- early return, as the field is not in the string.
	if not skip_check and not str:match(field_str) then
		return str
	end

	-- set the field.
	str = str:gsub(field_str, tostring(value))

	return str
end

---# if a string has a field <br>
---
--- Useful for if you dont need to figure out the value to write for the field if it doesn't exist, to help with performance in certain scenarios
---@param str string the string to find the field in.
---@param field string the field to find in the string.
---@return boolean found_field if the field was found.
function string.hasField(str, field)
	return str:match(("${%s}"):format(field))
end

function string:toLiteral(literal_percent)
	if literal_percent then
		return self:gsub("([%(%)%.%%%+%-%*%?%[%^%$])", "%%%%%1")
	end

	return self:gsub("([%(%)%.%%%+%-%*%?%[%^%$])", "%%%1")
end

---# Convert a percentage into a ascii bar
---@param ratio number 0-1, 0 for empty bar, 1 for full bar
---@param segment_count integer how many segments to display
---@param on_segment string the character for an on segment
---@param off_segment string the character for an off segment
function string.toBar(ratio, segment_count, on_segment, off_segment)
	local on_segments = math.ceil(ratio*segment_count)
	return ("%s%s"):format(
		on_segment:rep(on_segments),
		off_segment:rep(segment_count-on_segments)
	)
end

---# Convert a percentage into a ascii bar, with the ability to specify the segment width to ensure its always the same width.
---@param ratio number 0-1, 0 for empty bar, 1 for full bar
---@param segment_count integer how many segments to display
---@param on_segment string the character for an on segment
---@param off_segment string the character for an off segment
---@param on_segment_width number the width of the on segments
---@param off_segment_width number the width of the off segments
function string.toBarWithWidth(ratio, segment_count, on_segment, off_segment, on_segment_width, off_segment_width)
	local on_segments = math.ceil(ratio*segment_count)
	return ("%s%s"):format(
		on_segment:rep(math.ceil(on_segments*off_segment_width/on_segment_width)),
		off_segment:rep(math.ceil((segment_count-on_segments)))
	)
end


---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[ 
	Command system, used to be able to register commands from other scripts within this addon.
	This is to keep this script clean and have the commands that relate to those specific scripts,
	be within those specific scripts.
]]

---@alias commandName string
---@alias prefix string

---@alias defaultCommandPermissions "none"|"auth"|"admin"|"script"|"auth_script"|"admin_script"

---@class command
---@field name string the name of the command
---@field function_to_execute function the function to execute when the command is called, given params are: full_message, peer_id, arg
---@field required_permission defaultCommandPermissions|string the permission this command requires
---@field description string the description of the command
---@field short_description string the short description for this command
---@field examples table<integer, string> the examples of using this command
---@field prefix string the prefix for this command

--[[
-- where all of the registered commands are stored
---@type table<string, command>
local registered_commands = {}
]]

---@type table<prefix, table<commandName, command>>
commands = {}

-- where all of the registered permissions are stored.
---@type table<defaultCommandPermissions|string, function>
local registered_command_permissions = {}

Command = {}

-- intercept onCustomCommand calls
local old_onCustomCommand = onCustomCommand
function onCustomCommand(full_message, peer_id, is_admin, is_auth, prefix, command, ...)
	-- avoid error if onCustomCommand is not used anywhere else before.
	if old_onCustomCommand then
		old_onCustomCommand(full_message, peer_id, is_admin, is_auth, prefix, command, ...)
	end

	-- avoid errors if prefix is not specified
	if not prefix then return end

	-- avoid errors if command is not specified
	if not command then return end

	-- make the prefix lowercase
	prefix = prefix:lower()

	-- if the prefix does not pertain to this addon
	if not commands[prefix] then return end

	-- make the command lowercase
	command = command:friendly()

	-- if the command does not exist for the provided prefix
	if not commands[prefix][command] then return end

	local command_data = commands[prefix][command]

	-- the permission required to execute this command, if the permission is not found, default to admin.
	local command_permission = registered_command_permissions[command_data.required_permission] or registered_command_permissions.admin

	-- if the required permission is not met
	if not command_permission(peer_id) then

		local required_permission_name = registered_command_permissions[command_data.required_permission] and command_data.required_permission or "admin"
		
		if peer_id ~= -1 then
			-- if a player tried executing the command
			d.print(("You require the permission %s to execute this command!"):format(required_permission_name), false, 1, peer_id)
		else
			-- if a script tried to execute the command
			d.print(("A script tried to call the command %s, but it does not privilages to execute this command, as it requires the permission %s"):format(command, required_permission_name), true, 1)
		end

		return
	end

	-- call the command
	command_data.function_to_execute(full_message, peer_id, table.pack(...))
end

---# Registers a command
---@param name commandName the name of the command
---@param function_to_execute function the function to execute when the command is called, params are (full_message, peer_id, args)
---@param required_permission defaultCommandPermissions|string the permission required to execute this command.
---@param description string the description of the command
---@param short_description string the shortened description of the command
---@param examples table<integer, string> examples of using the command, prefix and the command will be added to the strings automatically.
---@param prefix prefix? the prefix for the command, leave blank to use the addon's short name as the prefix.
function Command.registerCommand(name, function_to_execute, required_permission, description, short_description, examples, prefix)
	
	-- default the prefix to the short addon's name, if the prefix is not specified.
	prefix = prefix or SHORT_ADDON_NAME:lower()

	-- add the question mark to the start of the prefix if wasn't already added.
	if prefix:sub(1, 1) ~= "?" then
		prefix = "?"..prefix
	end

	-- make the name friendly
	name = name:friendly() --[[@as string]]

	-- if this command has already been registered.
	if commands[prefix] and commands[prefix][name] then
		d.print(("Attempted to register a duplicate command \"%s\""):format(name), true, 1)
		return
	end
	
	---@type command
	local command_data = {
		name = name,
		function_to_execute = function_to_execute,
		required_permission = required_permission or "admin",
		description = description or "",
		short_description = short_description or "",
		examples = examples or {},
		prefix = prefix
	}

	-- if the table of commands with this prefix does not yet exist, create it.
	commands[prefix] = commands[prefix] or {}

	-- register this command.
	commands[prefix][name] = command_data
end

---@param name string the name of this permission
---@param has_permission function the function to execute, to check if the player has permission (arg1 is peer_id)
function Command.registerPermission(name, has_permission)

	-- if the permission already exists
	if registered_command_permissions[name] then

		--[[
			this can be quite a bad error, so it bypasses debug being disabled.

			for example, library A adds a permission called "mod", for mod authors
			and then after, library B adds a permission called "mod", for moderators of the server
			
			when this fails, any commands library B will now just require the requirements for mod authors
			now you've got issues of mod authors being able to access moderator commands

			so having this always alert is to try to make this issue obvious. as if it was just silent in
			the background, suddenly you've got privilage elevation.
		]]
		d.print(("(Command.registerPermission) Permission level %s is already registered!"):format(name), false, 1)
		return
	end

	registered_command_permissions[name] = has_permission
end

--[[

	scripts to be put after this one

]]

--[[
	definitions
]]
--[[
	
Copyright 2023 Liam Matthews

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

--[[

	Registers the default command permissions.

]]

-- None Permission
Command.registerPermission(
	"none",
	function()
		return true
	end
)

-- Auth Permission
Command.registerPermission(
	"auth",
	function(peer_id)

		-- this is a script, skip check.
		if peer_id == -1 then return false end

		local players = server.getPlayers()

		for peer_index = 1, #players do
			local player = players[peer_index]

			if player.id == peer_id then
				return player.auth
			end
		end

		return false
	end
)

-- Admin Permission
Command.registerPermission(
	"admin",
	function(peer_id)

		-- this is a script, skip check.
		if peer_id == -1 then return false end

		local players = server.getPlayers()

		for peer_index = 1, #players do
			local player = players[peer_index]

			if player.id == peer_id then
				return player.admin
			end
		end

		return false
	end
)

-- Script Permission
Command.registerPermission(
	"script",
	function(peer_id)
		return peer_id == -1
	end
)

-- Auth Script Permission
Command.registerPermission(
	"auth_script",
	function(peer_id)

		-- this is a script, skip check.
		if peer_id == -1 then return true end

		local players = server.getPlayers()

		for peer_index = 1, #players do
			local player = players[peer_index]

			if player.id == peer_id then
				return player.auth
			end
		end

		return false
	end
)

-- Admin Script Permission
Command.registerPermission(
	"admin_script",
	function(peer_id)

		-- this is a script, skip check.
		if peer_id == -1 then return true end

		local players = server.getPlayers()

		for peer_index = 1, #players do
			local player = players[peer_index]

			if player.id == peer_id then
				return player.admin
			end
		end

		return false
	end
)
--[[
	
Copyright 2023 Liam Matthews

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

--[[

	Registers the default commands.

]]

-- Info command
Command.registerCommand(
	"info",
	---@param full_message string the full message
	---@param peer_id integer the peer_id of the sender
	---@param arg table the arguments of the command.
	function(full_message, peer_id, arg)
		d.print(("Addon version: %s"):format(ADDON_VERSION), false, 0, peer_id)
	end,
	"none",
	"Prints some info about the addon, such as it's version",
	"Prints some general addon info.",
	{""}
)

 -- command handler, used to register commands.
--[[
	
Copyright 2023 Liam Matthews

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

--[[


	Library Setup


]]

-- required libraries
-- required libraries
--[[


	Library Setup


]]

-- required libraries

-- library name
AddonCommunication = {}

-- shortened library name
ac = AddonCommunication

--[[


	Variables
   

]]

replies_awaiting = {}

--[[


	Classes


]]

--[[


	Functions         


]]

function AddonCommunication.executeOnReply(short_addon_name, message, port, execute_function, count, timeout)
	short_addon_name = short_addon_name or SHORT_ADDON_NAME-- default to this addon's short name
	if not message then
		d.print("(AddonCommunication.executeOnReply) message was left blank!", true, 1)
		return
	end

	port = port or 0

	if not execute_function then
		d.print("(AddonCommunication.executeOnReply) execute_function was left blank!", true, 1)
		return
	end

	count = count or 1

	timeout = timeout or -1

	local expiry = -1
	if timeout ~= -1 then
		expiry = s.getTimeMillisec() + timeout*60
	end

	table.insert(replies_awaiting, {
		short_addon_name = short_addon_name,
		message = message,
		port = port,
		execute_function = execute_function,
		count = count,
		expiry = expiry
	})
end

function AddonCommunication.tick()
	for reply_index, reply in ipairs(replies_awaiting) do
		-- check if this reply has expired
		if reply.expiry ~= -1 and s.getTimeMillisec() > reply.expiry then
			-- it has expired
			d.print(("A function awaiting a reply of %s from %s has expired."):format(reply.message, reply.short_addon_name), true, 0)
			table.remove(replies_awaiting, reply_index)
		end
	end
end

function AddonCommunication.sendCommunication(message, port)
	if not message then
		d.print("(AddonCommunication.sendCommunication) message was left blank!", true, 1)
		return
	end

	port = port or 0

	-- add this addon's short name to the list
	local prepared_message = ("%s:%s"):format(SHORT_ADDON_NAME, message)

	-- send the message
	s.httpGet(port, prepared_message)
end

function httpReply(port, message)
	-- check if we're waiting to execute a function from this reply
	for reply_index, reply in ipairs(replies_awaiting) do
		-- check if this is the same port
		if reply.port ~= port then
			goto httpReply_continue_reply
		end

		-- check if the message content is the one we're looking for
		if ("%s:%s"):format(reply.short_addon_name, reply.message) ~= message then
			goto httpReply_continue_reply
		end

		-- this is the one we're looking for!

		-- remove 1 from count
		reply.count = math.max(reply.count - 1, -1)

		-- execute the function
		reply:execute_function()

		-- if count == 0 then remove this from the replies awaiting
		if reply.count == 0 then
			table.remove(replies_awaiting, reply_index)
		end

		break

		::httpReply_continue_reply::
	end
end
-- required libraries
--[[


	Library Setup


]]

-- required libraries
-- (none)

-- library name
-- (not applicable)

-- shortened library name
-- (not applicable)

--[[


	Variables
   

]]

-- pre-calculated pi*2
math.tau = math.pi*2
-- pre-calculated pi*0.5
math.half_pi = math.pi*0.5

--[[


	Classes


]]

--[[


	Functions         


]]


--- @param x number the number to check if is whole
--- @return boolean is_whole returns true if x is whole, false if not, nil if x is nil
function math.isWhole(x) -- returns wether x is a whole number or not
	return math.type(x) == "integer"
end

--- if a number is nil, it sets it to 0
--- @param x number the number to check if is nil
--- @return number x the number, or 0 if it was nil
function math.noNil(x)
	return x ~= x and 0 or x
end

--- @param x number the number to clamp
--- @param min number the minimum value
--- @param max number the maximum value
--- @return number clamped_x the number clamped between the min and max
function math.clamp(x, min, max)
	return math.noNil(max<x and max or min>x and min or x)
end

--- @param min number the min number
--- @param max number the max number
function math.randomDecimals(min, max)
	return math.random()*(max-min)+min
end

--- Returns a number which is consistant if the params are all consistant
--- @param use_decimals boolean true for if you want decimals, false for whole numbers
--- @param seed number the seed for the random number generator
--- @param min number the min number
--- @param max number the max number
--- @return number seeded_number the random seeded number
function math.seededRandom(use_decimals, seed, min, max)
	local seed = seed or 1
	local min = min or 0
	local max = max or 1

	local seeded_number = 0

	-- generate a random seed
	math.randomseed(seed)

	-- generate a random number with decimals
	if use_decimals then
		seeded_number = math.randomDecimals(min, max)
	else -- generate a whole number
		seeded_number = math.random(math.floor(min), math.ceil(max))
	end

	-- make the random numbers no longer consistant with the seed
	math.randomseed(g_savedata.tick_counter)
	
	-- return the seeded number
	return seeded_number
end

---@param x number the number to wrap
---@param min number the minimum number to wrap around
---@param max number the maximum number to wrap around
---@return number x x wrapped between min and max
function math.wrap(x, min, max) -- wraps x around min and max
	return (x - min) % (max - min) + min
end

---@param t table a table of which you want a winner to be picked from, the index of the elements must be the name of the element, and the value must be a modifier (num) which when larger will increase the chances of it being chosen
---@return string win_name the name of the element which was picked at random
function math.randChance(t)
	local total_mod = 0
	for k, v in pairs(t) do
		total_mod = total_mod + v
	end
	local win_name = ""
	local win_val = 0
	for k, v in pairs(t) do
		local chance = math.randomDecimals(0, v / total_mod)
		-- d.print("chance: "..chance.." chance to beat: "..win_val.." k: "..k, true, 0)
		if chance > win_val then
			win_val = chance
			win_name = k
		end
	end
	return win_name
end

---@param x1 number x coordinate of position 1
---@param x2 number x coordinate of position 2
---@param z1 number z coordinate of position 1
---@param z2 number z coordinate of position 2
---@param y1 number? y coordinate of position 1 (exclude for 2D distance, include for 3D distance)
---@param y2 number? y coordinate of position 2 (exclude for 2D distance, include for 3D distance)
---@return number distance the euclidean distance between position 1 and position 2
function math.euclideanDistance(...)
	local c = table.pack(...)

	local rx = c[1] - c[2]
	local rz = c[3] - c[4]

	if c.n == 4 then
		-- 2D distance
		return math.sqrt(rx*rx+rz*rz)
	end

	-- 3D distance
	local ry = c[5] - c[6]
	return math.sqrt(rx*rx+ry*ry+rz*rz)
end

---@param x1 number x coordinate of position 1
---@param x2 number x coordinate of position 2
---@param z1 number z coordinate of position 1
---@param z2 number z coordinate of position 2
---@param y1 number? y coordinate of position 1 (exclude to just get yaw, include to get yaw and pitch)
---@param y2 number? y coordinate of position 2 (exclude to just get yaw, include to get yaw and pitch)
---@return number yaw the yaw needed to face position 2 from position 1
---@return number pitch the pitch needed to face position 2 from position 1, will return 0 if y not specified.
function math.angleToFace(...)
	local c = table.pack(...)

	-- relative x coordinate
	local rx = c[1] - c[2]
	-- relative z coordinate
	local rz = c[3] - c[4]

	local yaw = math.atan(rz, rx) - math.half_pi

	if c.n == 4 then
		return yaw, 0
	end

	-- relative y
	local ry = c[5] - c[6]

	local pitch = -math.atan(ry, math.sqrt(rx * rx + rz * rz))

	return yaw, pitch
end

--- XOR function.
---@param ... any
---@return boolean
function math.xor(...)
	-- packed table of ..., dont have to use table.pack to respect nils, as nil will just be 0 anyways.
	local t = {...}

	-- the true count
	local tc = 0

	-- for each one that is true, add 1 to true count
	for i = 1, #t do
		if t[i] then tc = tc + 1 end
	end

	-- xor can be summarized down to if the number of true inputs modulo 2 is equal to 1, so do that.
	return tc%2==1
end


---@param matrix1 SWMatrix the first matrix
---@param matrix2 SWMatrix the second matrix
---@return number distance the xz distance between the two matrices
function matrix.xzDistance(matrix1, matrix2) -- returns the euclidean distance between two matrixes, ignoring the y axis
	return math.euclideanDistance(matrix1[13], matrix2[13], matrix1[15], matrix2[15])
end

---@param rot_matrix SWMatrix the matrix you want to get the rotation of
---@return number x_axis the x_axis rotation (roll)
---@return number y_axis the y_axis rotation (yaw)
---@return number z_axis the z_axis rotation (pitch)
function matrix.getMatrixRotation(rot_matrix) --returns radians for the functions: matrix.rotation X and Y and Z (credit to woe and quale)
	local z = -math.atan(rot_matrix[5],rot_matrix[1])
	rot_matrix = m.multiply(rot_matrix, m.rotationZ(-z))
	return math.atan(rot_matrix[7],rot_matrix[6]), math.atan(rot_matrix[9],rot_matrix[11]), z
end

---@param matrix1 SWMatrix the first matrix
---@param matrix2 SWMatrix the second matrix
---@return SWMatrix matrix the multiplied matrix
function matrix.multiplyXZ(matrix1, matrix2)
	local matrix3 = {table.unpack(matrix1)}
	matrix3[13] = matrix3[13] + matrix2[13]
	matrix3[15] = matrix3[15] + matrix2[15]
	return matrix3
end

--# returns the total velocity (m/s) between the two matrices
---@param matrix1 SWMatrix the first matrix
---@param matrix2 SWMatrix the second matrix
---@param ticks_between number the ticks between the two matrices
---@return number velocity the total velocity
function matrix.velocity(matrix1, matrix2, ticks_between)
	ticks_between = ticks_between or 1
	-- total velocity
	return math.euclideanDistance(matrix1[13], matrix2[13], matrix1[15], matrix2[15], matrix1[14], matrix2[14]) * 60/ticks_between
end

--# returns the acceleration, given 3 matrices. Each matrix must be the same ticks between eachother.
---@param matrix1 SWMatrix the most recent matrix
---@param matrix2 SWMatrix the second most recent matrix
---@param matrix3 SWMatrix the third most recent matrix
---@return number acceleration the acceleration in m/s
function matrix.acceleration(matrix1, matrix2, matrix3, ticks_between)
	local v1 = m.velocity(matrix1, matrix2, ticks_between) -- last change in velocity
	local v2 = m.velocity(matrix2, matrix3, ticks_between) -- change in velocity from ticks_between ago
	-- returns the acceleration
	return (v1-v2)/(ticks_between/60)
end


-- library name
Players = {}

-- shortened library name
pl = Players

--[[


	Variables
   

]]

local debug_auto_enable_levels = {
	function() -- for Authors.
		return true
	end,
	function(player) -- for Contributors and Testers.
		return IS_DEVELOPMENT_VERSION or player:isAdmin()
	end
}

local addon_contributors = {
	["76561198258457459"] = {
		name = "Toastery",
		role = "Author",
		can_auto_enable = debug_auto_enable_levels[1],
		debug = { -- the debug to automatically enable for them
			0, -- chat debug
			3, -- map debug
		}
	},
	["76561198443297702"] = {
		name = "Mr Lennyn",
		role = "Author",
		can_auto_enable = debug_auto_enable_levels[1],
		debug = { -- the debug to automatically enable for them
			0, -- chat debug
			3, -- map debug
		}
	}
}

--[[


	Functions         


]]

function Players.onJoin(steam_id, peer_id)

	if not g_savedata.players.individual_data[steam_id] then -- this player has never joined before

		Players.add(steam_id, peer_id)

	else -- this player has joined before

		local player = Players.dataBySID(steam_id) -- get the player's data

		Players.updateData(player) -- update the player's data
	end
end

---@param player PLAYER_DATA the data of the player
---@return PLAYER_DATA player the data of the player after having all of the OOP functions added
function Players.setupOOP(player)
	-- update name
	function player:updateName()
		self.name = s.getPlayerName(self.peer_id)
	end

	-- update peer_id
	function player:updatePID(peer_id)
		if peer_id then
			self.peer_id = peer_id
		else
			for _, peer in pairs(s.getPlayers()) do
				if tostring(peer.steam_id) == self.steam_id then
					self.peer_id = peer.id
				end
			end
		end
	end

	function player:updateOID()
		self.object_id = s.getPlayerCharacterID(self.peer_id)
	end

	-- checks if the player has this debug type enabled
	function player:getDebug(debug_id)
		if debug_id == -1 then
			-- check for all
			for _, enabled in pairs(self.debug) do
				if enabled then
					-- a debug is enabled
					return true
				end
			end
			-- no debugs are enabled
			return false
		end

		return self.debug[d.debugTypeFromID(debug_id)]
	end

	function player:setDebug(debug_id, enabled)
		if debug_id == -1 then -- set all debug to the specified state
			for debug_id, enabled in pairs(self.debug) do
				self:setDebug(debug_id, enabled)
			end
		else
			-- get debug type from debug id
			local debug_type = d.debugTypeFromID(debug_id)

			-- set player's debug to be value of enabled
			self.debug[debug_type] = enabled

			-- if we're enabling this debug
			if enabled then
				-- set this debug as true for global, so the addon can start checking who has it enabled.
				g_savedata.debug[debug_type].enabled = true
			else
				-- check if we can globally disable this debug to save on performance
				d.checkDebug()
			end

			-- handle the debug (handles enabling of debugs and such)
			d.handleDebug(debug_type, enabled, self.peer_id, self.steam_id)
		end
	end

	-- returns the SWPlayer, if doesn't exist currently, will return an empty table
	function player:getSWPlayer()
		local player_list = s.getPlayers()
		for peer_index = 1, #player_list do
			local SWPlayer = player_list[peer_index]
			if SWPlayer.steam_id == self.steam_id then
				return SWPlayer, true
			end
		end

		return {}, false
	end

	-- checks if the player is an admin
	function player:isAdmin()
		return self:getSWPlayer().admin
	end

	-- checks if the player is a contributor to the addon
	function player:isContributor()
		return addon_contributors[self.steam_id] ~= nil
	end

	function player:isOnline()
		-- "failure proof" method of checking if the player is online
		-- by going through all online players, as in certain scenarios
		-- only using onPlayerJoin and onPlayerLeave will cause issues.

		return table.pack(self:getSWPlayer())[2]
	end

	return player
end

---@param player PLAYER_DATA the data of the player
---@return PLAYER_DATA player the data of the player after having all of the data updated.
function Players.updateData(player)

	player = Players.setupOOP(player)

	-- update player's online status
	if player:isOnline() then
		g_savedata.players.online[player.peer_id] = player.steam_id
	else
		g_savedata.players.online[player.peer_id] = nil
	end

	-- update their name
	player:updateName()

	-- update their peer_id
	player:updatePID()

	-- update their object_id
	player:updateOID()

	return player
end

function Players.add(steam_id, peer_id)

	player = {
		name = s.getPlayerName(peer_id),
		peer_id = peer_id,
		steam_id = steam_id,
		object_id = s.getPlayerCharacterID(peer_id),
		debug = {},
		acknowledgements = {} -- used for settings to confirm that the player knows the side affects of what they're setting the setting to
	}

	-- populate debug data
	for i = 1, #debug_types do
		player.debug[d.debugTypeFromID(i)] = false
	end

	-- functions for the player

	player = Players.updateData(player)

	g_savedata.players.individual_data[steam_id] = player

	-- enable their selected debug modes by default if they're a addon contributor
	if player:isContributor() then
		local enabled_debugs = {}

		-- enable the debugs they specified
		if addon_contributors[steam_id].can_auto_enable(player) then
			for i = 1, #addon_contributors[steam_id].debug do
				local debug_id = addon_contributors[steam_id].debug[i]
				player:setDebug(debug_id, true)
				table.insert(enabled_debugs, addon_contributors[steam_id].debug[i])
			end
		end

		-- if this contributor has debugs which automatically gets enabled
		if #enabled_debugs > 0 then

			local msg_enabled_debugs = ""

			-- prepare the debug types which were enabled to be put into a message
			msg_enabled_debugs = d.debugTypeFromID(enabled_debugs[1])
			if #enabled_debugs > 1 then
				for i = 2, #enabled_debugs do -- start at position 2, as we've already added the one at positon 1.
					if i == #enabled_debugs then -- if this is the last debug type
						msg_enabled_debugs = ("%s and %s"):format(msg_enabled_debugs, d.debugTypeFromID(enabled_debugs[i]))
					else
						msg_enabled_debugs = ("%s, %s"):format(msg_enabled_debugs, d.debugTypeFromID(enabled_debugs[i]))
					end
				end
			end

			d.print(("Automatically enabled %s debug for you, %s, thank you for your contributions!"):format(msg_enabled_debugs, player.name), false, 0, player.peer_id)
		else -- if they have no debugs types that get automatically enabled
			d.print(("Thank you for your contributions, %s!"):format(player.name), false, 0, player.peer_id)
		end
	end

	d.print(("Setup Player %s"):format(player.name), true, 0, -1)
end

---@param steam_id steam_id the steam id of the player which you want to get the data of
---@return PLAYER_DATA player_data the data of the player
function Players.dataBySID(steam_id)
	return g_savedata.players.individual_data[steam_id]
end

---@param peer_id integer the peer id of the player which you want to get the data of
---@return PLAYER_DATA|nil player_data the data of the player, nil if not found
function Players.dataByPID(peer_id)

	local steam_id = Players.getSteamID(peer_id)

	-- ensure we got steam_id
	if not steam_id then 
		return
	end

	-- ensure player's data exists
	if not g_savedata.players.individual_data[steam_id] then
		return
	end

	-- return player's data
	return g_savedata.players.individual_data[steam_id]
end

---@param player_list table<integer, SWPlayer> the list of players to check
---@param target_pos SWMatrix the position that you want to check
---@param min_dist number the minimum distance between the player and the target position
---@param ignore_y boolean if you want to ignore the y level between the two or not
---@return boolean no_players_nearby returns true if theres no players which distance from the target_pos was less than the min_dist
function Players.noneNearby(player_list, target_pos, min_dist, ignore_y)
	local players_clear = true
	for _, player in pairs(player_list) do
		if ignore_y and m.xzDistance(s.getPlayerPos(player.id), target_pos) < min_dist then
			players_clear = false
		elseif not ignore_y and m.distance(s.getPlayerPos(player.id), target_pos) < min_dist then
			players_clear = false
		end
	end
	return players_clear
end

---@param peer_id integer the peer_id of the player you want to get the steam id of
---@return string|false steam_id the steam id of the player, false if not found
function Players.getSteamID(peer_id)
	if not g_savedata.players.online[peer_id] then
		-- slower, but reliable fallback method
		for _, peer in ipairs(s.getPlayers()) do
			if peer.id == peer_id then
				return tostring(peer.steam_id)
			end
		end
		return false
	end

	return g_savedata.players.online[peer_id]
end

---@param steam_id string the steam ID of the palyer
---@return integer|nil object_id the object ID of the player, nil if not found
function Players.objectIDFromSteamID(steam_id)
	if not steam_id then
		d.print("(pl.objectIDFromSteamID) steam_id was never provided!", true, 1, -1)
		return
	end

	local player_data = pl.dataBySID(steam_id)

	if not player_data.object_id then
		player_data.object_id = s.getPlayerCharacterID(player_data.peer_id)
	end

	return player_data.object_id
end

-- returns true if the peer_id is a player id
function Players.isPlayer(peer_id)
	return (peer_id and peer_id ~= -1 and peer_id ~= 65535)
end
--[[


	Library Setup


]]

-- required libraries

-- library name
Map = {}

-- shortened library name
-- (not applicable)

--[[


	Variables
   

]]

--[[


	Classes


]]

--[[


	Functions         


]]

--# draws a search area within the specified radius at the coordinates provided
---@param x number the x coordinate of where the search area will be drawn around (required)
---@param z number the z coordinate of where the search area will be drawn around (required)
---@param radius number the radius of the search area (required)
---@param ui_id SWUI_ID the ui_id of the search area (required)
---@param peer_id integer the peer_id of the player which you want to draw the search area for (defaults to -1)
---@param label string The text that appears when mousing over the icon. Appears like a title (defaults to "")
---@param hover_label string The text that appears when mousing over the icon. Appears like a subtitle or description (defaults to "")
---@param r integer 0-255, the red value of the search area (defaults to 255)
---@param g integer 0-255, the green value of the search area (defaults to 255)
---@param b integer 0-255, the blue value of the search area (defaults to 255)
---@param a integer 0-255, the alpha value of the search area (defaults to 255)
---@return number? x the x coordinate of where the search area was drawn
---@return number? z the z coordinate of where the search area was drawn
---@return boolean success if the search area was drawn
function Map.drawSearchArea(x, z, radius, ui_id, peer_id, label, hover_label, r, g, b, a)

	if not x then -- if the x position of the target was not provided
		d.print("(Map.drawSearchArea) x is nil!", true, 1)
		return nil, nil, false
	end

	if not z then -- if the z position of the target was not provided
		d.print("(Map.drawSearchArea) z is nil!", true, 1)
		return nil, nil, false
	end

	if not radius then -- if the radius of the search area was not provided
		d.print("(Map.drawSearchArea) radius is nil!", true, 1)
		return nil, nil, false
	end

	if not ui_id then -- if the ui_id was not provided
		d.print("(Map.drawSearchArea) ui_id is nil!", true, 1)
		return nil, nil, false
	end

	-- default values (if not specified)

	local peer_id = peer_id or -1 -- makes the peer_id default to -1 if not provided (-1 = everybody)

	local label = label or "" -- defaults the label to "" if it was not specified
	local hover_label = hover_label or "" -- defaults the hover_label to "" if it was not specified

	local r = r or 255 -- makes the red colour default to 255 if not provided
	local g = g or 255 -- makes the green colour default to 255 if not provided
	local b = b or 255 -- makes the blue colour default to 255 if not provided
	local a = a or 255 -- makes the alpha default to 255 if not provided

	local angle = math.random() * math.pi * 2 -- gets a random angle to put the search radius focus around
	local dist = math.sqrt(math.randomDecimals(0.1, 0.9)) * radius -- gets a random distance from the target to put the search radius at

	local x_pos = dist * math.sin(angle) + x -- uses the distance and angle to make the x pos of the search radius
	local z_pos = dist * math.cos(angle) + z -- uses the distance and angle to make the z pos of the search radius

	server.addMapObject(peer_id, ui_id, 0, 2, x_pos, z_pos, 0, 0, 0, 0, label, radius, hover_label, r, g, b, a) -- draws the search radius to the map

	return x_pos, z_pos, true -- returns the x pos and z pos of the drawn search radius, and returns true that it was drawn.
end

function Map.addMapCircle(peer_id, ui_id, center_matrix, radius, width, r, g, b, a, lines) -- credit to woe
	peer_id, ui_id, center_matrix, radius, width, r, g, b, a, lines = peer_id or -1, ui_id or 0, center_matrix or matrix.translation(0, 0, 0), radius or 500, width or 0.25, r or 255, g or 0, b or 0, a or 255, lines or 16
	local center_x, center_z = center_matrix[13], center_matrix[15]

	local angle_per_line = math.tau/lines

	local last_angle = 0

	for i = 1, lines + 1 do
		local new_angle = angle_per_line*i

		local x1, z1 = center_x+radius*math.cos(last_angle), center_z+radius*math.sin(last_angle)
		local x2, z2 = center_x+radius*math.cos(new_angle), center_z+radius*math.sin(new_angle)
		
		local start_matrix, end_matrix = matrix.translation(x1, 0, z1), matrix.translation(x2, 0, z2)
		server.addMapLine(peer_id, ui_id, start_matrix, end_matrix, width, r, g, b, a)
		last_angle = new_angle
	end
end
-- required libraries

--# check for if none of the inputted variables are nil
---@param print_error boolean if you want it to print an error if any are nil (if true, the second argument must be a name for debugging puposes)
---@param ... any variables to check
---@return boolean none_are_nil returns true of none of the variables are nil or false
function table.noneNil(print_error,...)
	local _ = table.pack(...)
	local none_nil = true
	for variable_index, variable in pairs(_) do
		if print_error and variable ~= _[1] or not print_error then
			if not none_nil then
				none_nil = false
				if print_error then
					d.print("(table.noneNil) a variable was nil! index: "..variable_index.." | from: ".._[1], true, 1)
				end
			end
		end
	end
	return none_nil
end

--# returns the number of elements in the table
---@param t table table to get the size of
---@return number count the size of the table
function table.length(t)
	if not t or type(t) ~= "table" then
		return 0 -- invalid input
	end

	local count = 0

	for _ in pairs(t) do -- goes through each element in the table
		count = count + 1 -- adds 1 to the count
	end

	return count -- returns number of elements
end

-- credit: woe | for this function
function table.tabulate(t,...)
	local _ = table.pack(...)
	t[_[1]] = t[_[1]] or {}
	if _.n>1 then
		table.tabulate(t[_[1]], table.unpack(_, 2))
	end
end

--# function that turns strings into a table (Warning: very picky)
--- @param S string a table in string form
--- @return table T the string turned into a.table
function table.fromString(S)
	local function stringToTable(string_as_table, start_index)
		local T = {}

		local variable = nil
		local str = ""

		local char_offset = 0

		start_index = start_index or 1

		for char_index = start_index, string_as_table:len() do
			char_index = char_index + char_offset

			-- if weve gone through the entire string, accounting for the offset
			if char_index > string_as_table:len() then
				return T, char_index - start_index
			end

			-- the current character to read
			local char = string_as_table:sub(char_index, char_index)

			-- if this is the opening of a table
			if char == "{" then
				local returned_table, chars_checked = stringToTable(string_as_table, char_index + 1)

				if not variable then
					table.insert(T, returned_table)
				else
					T[variable] = returned_table
				end

				char_offset = char_offset + (chars_checked or 0)

				variable = nil

			-- if this is the closing of a table, and a start of another
			elseif string_as_table:sub(char_index, char_index + 2) == "},{" then
				if variable then
					T[variable] = str
				end

				return T, char_index - start_index + 1

			-- if this is a closing of a table.
			elseif char == "}" then
				if variable then
					T[variable] = str
				elseif str ~= "" then
					table.insert(T, str)
				end

				return T, char_index - start_index

			-- if we're recording the value to set the variable to
			elseif char == "=" then
				variable = str
				str = ""

			-- save the value of the variable
			elseif char == "," then
				if variable then
					T[variable] = str
				elseif str ~= "" then
					table.insert(T, str)
				end

				str = ""
				variable = ""

			-- write this character if its not a quote
			elseif char ~= "\"" then
				str = str..char
			end
		end
	end

	return table.pack(stringToTable(S, 1))[1]
end

--- Returns the value at the path in _ENV
---@param path string the path we want to get the value at
---@return any value the value at the path, if it reached a nil value in the given path, it will return the value up to that point, and is_success will be false.
---@return boolean is_success if it successfully got the value at the path
function table.getValueAtPath(path)
	if type(path) ~= "string" then
		d.print(("path must be a string! given path: %s type: %s"):format(path, type(path)), true, 1)
		return nil, false
	end

	local cur_path
	-- if our environment is modified, we will have to make a deep copy under the non-modified environment.
	if _ENV_NORMAL then
		cur_path = _ENV_NORMAL.table.copy.deep(_ENV, _ENV_NORMAL)
	else
		cur_path = table.copy.deep(_ENV)
	end

	local cur_path_string = "_ENV"

	for index in string.gmatch(path, "([^%.]+)") do
		if not cur_path[index] then
			d.print(("%s does not contain a value indexed by %s, given path: %s"):format(cur_path_string, index, path), false, 1)
			return cur_path, false
		end

		cur_path = cur_path[index]
	end

	return cur_path, true
end

--- Sets the value at the path in _ENV
---@param path string the path we want to set the value at
---@param set_value any the value we want to set the value of what the path is
---@return boolean is_success if it successfully got the value at the path
function table.setValueAtPath(path, set_value)
	if type(path) ~= "string" then
		d.print(("(table.setValueAtPath) path must be a string! given path: %s type: %s"):format(path, type(path)), true, 1)
		return false
	end

	local cur_path = _ENV
	-- if our environment is modified, we will have to make a deep copy under the non-modified environment.
	--[[if _ENV_NORMAL then
		cur_path = _ENV_NORMAL.table.copy.deep(_ENV, _ENV_NORMAL)
	else
		cur_path = table.copy.deep(_ENV)
	end]]

	local cur_path_string = "_ENV"

	local index_count = 0

	local last_index, got_count = string.countCharInstances(path, "%.")

	last_index = last_index + 1

	if not got_count then
		d.print(("(table.setValueAtPath) failed to get count! path: %s"):format(path))
		return false
	end

	for index in string.gmatch(path, "([^%.]+)") do
		index_count = index_count + 1

		if not cur_path[index] then
			d.print(("(table.setValueAtPath) %s does not contain a value indexed by %s, given path: %s"):format(cur_path_string, index, path), false, 1)
			return false
		end

		if index_count == last_index then
			cur_path[index] = set_value

			return true
		end

		cur_path = cur_path[index]
	end

	d.print("(table.setValueAtPath) never reached end of path?", true, 1)
	return false
end

-- a table containing a bunch of functions for making a copy of tables, to best fit each scenario performance wise.
table.copy = {

	iShallow = function(t, __ENV)
		__ENV = __ENV or _ENV
		return {__ENV.table.unpack(t)}
	end,
	shallow = function(t, __ENV)
		__ENV = __ENV or _ENV

		local t_type = __ENV.type(t)

		local t_shallow

		if t_type == "table" then
			for key, value in __ENV.next, t, nil do
				t_shallow[key] = value
			end
		end

		return t_shallow or t
	end,
	deep = function(t, __ENV)

		__ENV = __ENV or _ENV

		local function deepCopy(T)
			local copy = {}
			if __ENV.type(T) == "table" then
				for key, value in __ENV.next, T, nil do
					copy[deepCopy(key)] = deepCopy(value)
				end
			else
				copy = T
			end
			return copy
		end
	
		return deepCopy(t)
	end
}


-- library name
Debugging = {}

-- shortened library name
d = Debugging

--[[


	Variables
   

]]

--[[


	Classes


]]

--[[


	Functions         


]]

---@param message string the message you want to print
---@param requires_debug ?boolean if it requires <debug_type> debug to be enabled
---@param debug_type ?integer the type of message, 0 = debug (debug.chat) | 1 = error (debug.chat) | 2 = profiler (debug.profiler) 
---@param peer_id ?integer if you want to send it to a specific player, leave empty to send to all players
function Debugging.print(message, requires_debug, debug_type, peer_id) -- "glorious debug function" - senty, 2022
	if IS_DEVELOPMENT_VERSION or not requires_debug or requires_debug and d.getDebug(debug_type, peer_id) or requires_debug and debug_type == 2 and d.getDebug(0, peer_id) or debug_type == 1 and d.getDebug(0, peer_id) then
		local suffix = debug_type == 1 and " Error:" or debug_type == 2 and " Profiler:" or debug_type == 7 and " Function:" or debug_type == 8 and " Traceback:" or " Debug:"
		local prefix = string.gsub(s.getAddonData((s.getAddonIndex())).name, "%(.*%)", ADDON_VERSION)..suffix

		if type(message) ~= "table" and IS_DEVELOPMENT_VERSION then
			if message then
				debug.log(string.format("SW %s %s | %s", SHORT_ADDON_NAME, suffix, string.gsub(message, "\n", " \\n ")))
			else
				debug.log(string.format("SW %s %s | (d.print) message is nil!", SHORT_ADDON_NAME, suffix))
			end
		end
		
		if type(message) == "table" then -- print the message as a table.
			d.printTable(message, requires_debug, debug_type, peer_id)

		elseif requires_debug then -- if this message requires debug to be enabled
			if pl.isPlayer(peer_id) and peer_id then -- if its being sent to a specific peer id
				if d.getDebug(debug_type, peer_id) then -- if this peer has debug enabled
					server.announce(prefix, message, peer_id) -- send it to them
				end
			else
				for _, peer in ipairs(server.getPlayers()) do -- if this is being sent to all players with the debug enabled
					if d.getDebug(debug_type, peer.id) or debug_type == 2 and d.getDebug(0, peer.id) or debug_type == 1 and d.getDebug(0, peer.id) then -- if this player has debug enabled
						server.announce(prefix, message, peer.id) -- send the message to them
					end
				end
			end
		else
			server.announce(prefix, message, peer_id or -1)
		end
	end

	-- print a traceback if this is a debug error message, and if tracebacks are enabled
	if debug_type == 1 and d.getDebug(8) then
		d.trace.print(_ENV, requires_debug, peer_id)
	end
end

function Debugging.debugTypeFromID(debug_id) -- debug id to debug type
	return debug_types[debug_id]
end

function Debugging.debugIDFromType(debug_type)

	debug_type = string.friendly(debug_type)

	for debug_id, d_type in pairs(debug_types) do
		if debug_type == string.friendly(d_type) then
			return debug_id
		end
	end
end

--# prints all data which is in a table (use d.print instead of this)
---@param T table the table of which you want to print
---@param requires_debug boolean if it requires <debug_type> debug to be enabled
---@param debug_type integer the type of message, 0 = debug (debug.chat) | 1 = error (debug.chat) | 2 = profiler (debug.profiler)
---@param peer_id integer if you want to send it to a specific player, leave empty to send to all players
function Debugging.printTable(T, requires_debug, debug_type, peer_id)
	d.print(string.fromTable(T), requires_debug, debug_type, peer_id)
end

---@param debug_id integer the type of debug | 0 = debug | 1 = error | 2 = profiler | 3 = map
---@param peer_id ?integer the peer_id of the player you want to check if they have it enabled, leave blank to check globally
---@return boolean enabled if the specified type of debug is enabled
function Debugging.getDebug(debug_id, peer_id)
	if not peer_id or not pl.isPlayer(peer_id) then -- if any player has it enabled
		if debug_id == -1 then -- any debug
			for _, enabled in pairs(g_savedata.debug) do
				if enabled then 
					return true 
				end
			end
			if g_savedata.debug.chat.enabled or g_savedata.debug.profiler.enabled or g_savedata.debug.map.enabled then
				return true
			end
			return false
		end

		-- make sure this debug type is valid
		if not debug_types[debug_id] then
			d.print("(d.getDebug) debug_type "..tostring(debug_id).." is not a valid debug type!", true, 1)
			return false
		end

		-- check a specific debug
		return g_savedata.debug[debug_types[debug_id]].enabled

	else -- if a specific player has it enabled
		local player = pl.dataByPID(peer_id)
		
		-- ensure the data for this player exists
		if not player then
			return false
		end

		if type(player.getDebug) ~= "function" then -- update the OOP functions.
			player = pl.updateData(player)
		end

		return player:getDebug(debug_id)
	end
	return false
end

function Debugging.handleDebug(debug_type, enabled, peer_id)
	if debug_type == "chat" then
		return (enabled and "Enabled" or "Disabled").." Chat Debug"
	elseif debug_type == "error" then
		return (enabled and "Enabled" or "Disabled").." Error Debug"
	elseif debug_type == "profiler" then
		if not enabled then
			-- remove profiler debug
			s.removePopup(peer_id, g_savedata.profiler.ui_id)

			-- clean all the profiler debug, if its disabled globally
			d.cleanProfilers()
		end

		return (enabled and "Enabled" or "Disabled").." Profiler Debug"
	elseif debug_type == "map" then
		if not enabled then
			-- remove map debug
			for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
				for vehicle_id, vehicle_object in pairs(squad.vehicles) do
					s.removeMapObject(peer_id, vehicle_object.ui_id)
					s.removeMapLabel(peer_id, vehicle_object.ui_id)
					s.removeMapLine(peer_id, vehicle_object.ui_id)
					for i = 0, #vehicle_object.path - 1 do
						local waypoint = vehicle_object.path[i]
						if waypoint then
							s.removeMapLine(-1, waypoint.ui_id)
						end
					end
				end
			end

			for island_index, island in pairs(g_savedata.islands) do
				updatePeerIslandMapData(peer_id, island)
			end
			
			updatePeerIslandMapData(peer_id, g_savedata.player_base_island)
			updatePeerIslandMapData(peer_id, g_savedata.ai_base_island)
		end

		return (enabled and "Enabled" or "Disabled").." Map Debug"
	elseif debug_type == "graph_node" then
		local function addNode(ui_id, x, z, node_type, NSO)
			local r = 255
			local g = 255
			local b = 255
			if node_type == "ocean_path" then
				r = 0
				g = 25
				b = 225

				if NSO == 2 then -- darker for non NSO
					b = 200
					g = 50
				elseif NSO == 1 then -- brighter for NSO
					b = 255
					g = 0
				end

			elseif node_type == "land_path" then
				r = 0
				g = 215
				b = 25

				if NSO == 2 then -- darker for non NSO
					g = 150
					b = 50
				elseif NSO == 1 then -- brighter for NSO
					g = 255
					b = 0
				end

			end
			Map.addMapCircle(peer_id, ui_id, m.translation(x, 0, z), 5, 1.5, r, g, b, 255, 3)
		end

		if enabled then
			if not g_savedata.graph_nodes.init_debug then
				g_savedata.graph_nodes.ui_id = s.getMapID()
				g_savedata.graph_nodes.init_debug = true
			end

			for x, x_data in pairs(g_savedata.graph_nodes.nodes) do
				for z, z_data in pairs(x_data) do
					addNode(g_savedata.graph_nodes.ui_id, x, z, z_data.type, z_data.NSO)
				end
			end
		else
			s.removeMapID(peer_id, g_savedata.graph_nodes.ui_id)
		end

		return (enabled and "Enabled" or "Disabled").." Graph Node Debug"
	elseif debug_type == "driving" then
		if not enabled then
			for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
				for vehicle_id, vehicle_object in pairs(squad.vehicles) do
					s.removeMapObject(peer_id, vehicle_object.driving.ui_id)
				end
			end
		end
		return (enabled and "Enabled" or "Disabled").." Driving Debug"

	elseif debug_type == "vehicle" then
		if not enabled then
			-- remove vehicle debug
			for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
				for vehicle_id, vehicle_object in pairs(squad.vehicles) do
					s.removePopup(peer_id, vehicle_object.ui_id)
				end
			end
		end
		return (enabled and "Enabled" or "Disabled").." Vehicle Debug"
	elseif debug_type == "function" then
		if enabled then
			-- enable function debug (function debug prints debug output whenever a function is called)

			--- cause the game doesn't like it when you use ... for params, and thinks thats only 1 parametre being passed.
			local function callFunction(funct, name, ...)

				--[[
					all functions within this function, other than the one we're wanting to call must be called appended with _ENV_NORMAL
					as otherwise it will cause the function debug to be printed for that function, causing this function to call itself over and over again.
				]]
				
				-- pack the arguments specified into a table
				local args = _ENV_NORMAL.table.pack(...)
				
				-- if no arguments were specified, call the function with no arguments
				if #args == 0 then
					if name == "_ENV.tostring" then
						return "nil"
					elseif name == "_ENV.s.getCharacterData" or name == "_ENV.server.getCharacterData" then
						return nil
					end
					local out = _ENV_NORMAL.table.pack(funct())
					return _ENV_NORMAL.table.unpack(out)
				elseif #args == 1 then -- if only one argument, call the function with only one argument.
					local out = _ENV_NORMAL.table.pack(funct(...))
					return _ENV_NORMAL.table.unpack(out)
				end
				--[[
					if theres two or more arguments, then pack all but the first argument into a table, and then have that as the second param
					this is to trick SW's number of params specified checker, as it thinks just ... is only 1 argument, even if it contains more than 1.
				]]
				local filler = {}
				for i = 2, #args do
					_ENV_NORMAL.table.insert(filler, args[i])
				end
				local out = _ENV_NORMAL.table.pack(funct(..., _ENV_NORMAL.table.unpack(filler)))
				return _ENV_NORMAL.table.unpack(out)
			end

			local function modifyFunction(funct, name)
				--d.print(("setting up function %s()..."):format(name), true, 7)
				return (function(...)

					local returned = _ENV_NORMAL.table.pack(callFunction(funct, name, ...))

					-- switch our env to the non modified environment, to avoid us calling ourselves over and over.
					__ENV =  _ENV_NORMAL
					__ENV._ENV_MODIFIED = _ENV
					_ENV = __ENV

					-- pack args into a table
					local args = table.pack(...)

					-- build output string
					local s = ""

					-- add return values
					for i = 1, #returned do
						s = ("%s%s%s"):format(s, returned[i], i ~= #returned and ", " or "")
					end

					-- add the = if theres any returned values, and also add the function name along with ( proceeding it.
					s = ("%s%s%s("):format(s, s ~= "" and " = " or "", name)

					-- add the arguments to the function, add a ", " after the argument if thats not the last argument.
					for i = 1, #args do
						s = ("%s%s%s"):format(s, args[i], i ~= #args and ", " or "")
					end

					-- add ) to the end of the string.
					s = ("%s%s"):format(s, ")")

					-- print the string.
					d.print(s, true, 7)

					-- switch back to modified environment
					_ENV = _ENV_MODIFIED

					-- return the value to the function which called it.
					return _ENV_NORMAL.table.unpack(returned)
				end)
			end
		
			local function setupFunctionsDebug(t, n)

				-- if this table is empty, return nil.
				if t == nil then
					return nil
				end

				local T = {}
				-- default name to _ENV
				n = n or "_ENV"
				for k, v in pairs(t) do
					local type_v = type(v)
					if type_v == "function" then
						-- "inject" debug into the function
						T[k] = modifyFunction(v, ("%s.%s"):format(n, k))
					elseif type_v == "table" then
						-- go through this table looking for functions
						local name = ("%s.%s"):format(n, k)
						T[k] = setupFunctionsDebug(v, name)
					else
						-- just save as a variable
						T[k] = v
					end
				end

				-- if we've just finished doing _ENV, then we've built all of _ENV
				if n == "_ENV" then
					-- add _ENV_NORMAL to this env before we set it, as otherwise _ENV_NORMAL will no longer exist.
					T._ENV_NORMAL = _ENV_NORMAL
					d.print("Completed setting up function debug!", true, 7)
				end

				return T
			end

			-- modify all functions in _ENV to have the debug "injected"
			_ENV = setupFunctionsDebug(table.copy.deep(_ENV))
		else
			-- revert _ENV to be the non modified _ENV
			_ENV = table.copy.deep(_ENV_NORMAL)
		end
		return (enabled and "Enabled" or "Disabled").." Function Debug"
	elseif debug_type == "traceback" then
		if enabled and not _ENV_NORMAL then
			-- enable traceback debug (function debug prints debug output whenever a function is called)

			_ENV_NORMAL = nil

			_ENV_NORMAL = table.copy.deep(_ENV)

			local g_tb = g_savedata.debug.traceback

			local function removeAndReturn(...)
				g_tb.stack_size = g_tb.stack_size - 1
				return ...
			end
			local function setupFunction(funct, name)
				--d.print(("setting up function %s()..."):format(name), true, 8)
				local funct_index = nil

				-- check if this function is already indexed
				if g_tb.funct_names then
					for saved_funct_index = 1, g_tb.funct_count do
						if g_tb.funct_names[saved_funct_index] == name then
							funct_index = saved_funct_index
							break
						end
					end
				end

				-- this function is not yet indexed, so add it to the index.
				if not funct_index then
					g_tb.funct_count = g_tb.funct_count + 1
					g_tb.funct_names[g_tb.funct_count] = name

					funct_index = g_tb.funct_count
				end

				-- return this as the new function
				return (function(...)

					-- increase the stack size before we run the function
					g_tb.stack_size = g_tb.stack_size + 1

					-- add this function to the stack
					g_tb.stack[g_tb.stack_size] = {
						funct_index
					}

					-- if this function was given parametres, add them to the stack
					if ... ~= nil then
						g_tb.stack[g_tb.stack_size][2] = {...}
					end

					--[[ 
						run this function
						if theres no error, it will then be removed from the stack, and then we will return the function's returned value
						if there is an error, it will never be removed from the stack, so we can detect the error.
						we have to do this via a function call, as we need to save the returned value before we return it
						as we have to first remove it from the stack
						we could use table.pack or {}, but that will cause a large increase in the performance impact.
					]]
					return removeAndReturn(funct(...))
				end)
			end
		
			local function setupTraceback(t, n)

				-- if this table is empty, return nil.
				if t == nil then
					return nil
				end

				local T = {}

				--[[if n == "_ENV.g_savedata" then
					T = g_savedata
				end]]

				-- default name to _ENV
				n = n or "_ENV"
				for k, v in pairs(t) do
					if k ~= "_ENV_NORMAL" and k ~= "g_savedata" then
						local type_v = type(v)
						if type_v == "function" then
							-- "inject" debug into the function
							local name = ("%s.%s"):format(n, k)
							T[k] = setupFunction(v, name)
						elseif type_v == "table" then
							-- go through this table looking for functions
							local name = ("%s.%s"):format(n, k)
							T[k] = setupTraceback(v, name)
						else--if not n:match("^_ENV%.g_savedata") then
							-- just save as a variable
							T[k] = v
						end
					end
				end

				-- if we've just finished doing _ENV, then we've built all of _ENV
				if n == "_ENV" then
					-- add _ENV_NORMAL to this env before we set it, as otherwise _ENV_NORMAL will no longer exist.
					T._ENV_NORMAL = _ENV_NORMAL

					T.g_savedata = g_savedata
				end

				return T
			end

			local start_traceback_setup_time = s.getTimeMillisec()

			-- modify all functions in _ENV to have the debug "injected"
			_ENV = setupTraceback(table.copy.deep(_ENV))

			d.print(("Completed setting up tracebacks! took %ss"):format((s.getTimeMillisec() - start_traceback_setup_time)*0.001), true, 8)

			--onTick = setupTraceback(onTick, "onTick")

			-- add the error checker
			ac.executeOnReply(
				SHORT_ADDON_NAME,
				"DEBUG.TRACEBACK.ERROR_CHECKER",
				0,
				function(self)
					-- if traceback debug has been disabled, then remove ourselves
					if not g_savedata.debug.traceback.enabled then
						self.count = 0

					elseif g_savedata.debug.traceback.stack_size > 0 then
						-- switch our env to the non modified environment, to avoid us calling ourselves over and over.
						__ENV =  _ENV_NORMAL
						__ENV._ENV_MODIFIED = _ENV
						_ENV = __ENV

						d.trace.print(_ENV_MODIFIED)

						_ENV = _ENV_MODIFIED

						g_savedata.debug.traceback.stack_size = 0
					end
				end,
				-1,
				-1
			)

			ac.sendCommunication("DEBUG.TRACEBACK.ERROR_CHECKER", 0)
		elseif not enabled and _ENV_NORMAL then
			-- revert modified _ENV functions to be the non modified _ENV
			--- @param t table the environment thats not been modified, will take all of the functions from this table and put it into the current _ENV
			--- @param mt table the modified enviroment
			--[[local function removeTraceback(t, mt)
				for k, v in _ENV_NORMAL.pairs(t) do
					local v_type = _ENV_NORMAL.type(v)
					-- modified table with this indexed
					if mt[k] then
						if v_type == "table" then
							removeTraceback(v, mt[k])
						elseif v_type == "function" then
							mt[k] = v
						end
					end
				end
				return mt
			end

			_ENV = removeTraceback(_ENV_NORMAL, _ENV)]]

			__ENV = _ENV_NORMAL.table.copy.deep(_ENV_NORMAL, _ENV_NORMAL)
			__ENV.g_savedata = g_savedata
			_ENV = __ENV

			_ENV_NORMAL = nil
		end
		return (enabled and "Enabled" or "Disabled").." Tracebacks"
	end
end

function Debugging.setDebug(debug_id, peer_id, override_state)

	if not peer_id then
		d.print("(Debugging.setDebug) peer_id is nil!", true, 1)
		return "peer_id was nil"
	end

	local player_data = pl.dataByPID(peer_id)

	if not debug_id then
		d.print("(Debugging.setDebug) debug_id is nil!", true, 1)
		return "debug_id was nil"
	end

	local ignore_all = { -- debug types to ignore from enabling and/or disabling with ?impwep debug all
		[-1] = "all",
		[4] = "enable",
		[7] = "enable"
	}

	if not debug_types[debug_id] then
		return "Unknown debug type: "..tostring(debug_id)
	end

	if not player_data and peer_id ~= -1 then
		return "invalid peer_id: "..tostring(peer_id)
	end

	if peer_id == -1 then
		local function setGlobalDebug(debug_id)
			-- set that this debug should or shouldn't be auto enabled whenever a player joins for that player
			g_savedata.debug[debug_types[debug_id]].auto_enable = override_state

			for _, peer in ipairs(s.getPlayers()) do
				d.setDebug(debug_id, peer.id, override_state)
			end
		end

		if debug_id == -1 then
			for _debug_id, _ in pairs(debug_types) do
				setGlobalDebug(_debug_id)
			end

		else
			setGlobalDebug(debug_id)
		end

		return "Enabled "..debug_types[debug_id].." Globally."
	end
	
	if debug_types[debug_id] then
		if debug_id == -1 then
			local none_true = true
			for d_id, debug_type_data in pairs(debug_types) do -- disable all debug
				if player_data.debug[debug_type_data] and (ignore_all[d_id] ~= "all" and ignore_all[d_id] ~= "enable") and override_state ~= true then
					none_true = false
					player_data.debug[debug_type_data] = false
				end
			end

			if none_true and override_state ~= false then -- if none was enabled, then enable all
				for d_id, debug_type_data in pairs(debug_types) do -- enable all debug
					if (ignore_all[d_id] ~= "all" and ignore_all[d_id] ~= "enable") then
						g_savedata.debug[debug_type_data].enabled = none_true
						player_data.debug[debug_type_data] = none_true
						d.handleDebug(debug_type_data, none_true, peer_id)
					end
				end
			else
				d.checkDebug()
				for d_id, debug_type_data in pairs(debug_types) do -- disable all debug
					if (ignore_all[d_id] ~= "all" and ignore_all[d_id] ~= "disable") then
						d.handleDebug(debug_type_data, none_true, peer_id)
					end
				end
			end
			return (none_true and "Enabled" or "Disabled").." All Debug"
		else
			player_data.debug[debug_types[debug_id]] = override_state == nil and not player_data.debug[debug_types[debug_id]] or override_state

			if player_data.debug[debug_types[debug_id]] then
				g_savedata.debug[debug_types[debug_id]].enabled = true
			else
				d.checkDebug()
			end

			return d.handleDebug(debug_types[debug_id], player_data.debug[debug_types[debug_id]], peer_id)
		end
	end
end

function Debugging.checkDebug() -- checks all debugging types to see if anybody has it enabled, if not, disable them to save on performance
	local keep_enabled = {}

	-- check all debug types for all players to see if they have it enabled or disabled
	local player_list = s.getPlayers()
	for _, peer in pairs(player_list) do
		local player_data = pl.dataByPID(peer.id)
		for debug_type, debug_type_enabled in pairs(player_data.debug) do
			-- if nobody's known to have it enabled
			if not keep_enabled[debug_type] then
				-- then set it to whatever this player's value was
				keep_enabled[debug_type] = debug_type_enabled
			end
		end
	end

	-- any debug types that are disabled for all players, we want to disable globally to save on performance
	for debug_type, should_keep_enabled in pairs(keep_enabled) do
		-- if its not enabled for anybody
		if not should_keep_enabled then
			-- disable the debug globally
			g_savedata.debug[debug_type].enabled = should_keep_enabled
		end
	end
end

---@param unique_name string a unique name for the profiler  
function Debugging.startProfiler(unique_name, requires_debug)
	-- if it doesnt require debug or
	-- if it requires debug and debug for the profiler is enabled or
	-- if this is a development version
	if not requires_debug or requires_debug and g_savedata.debug.profiler.enabled then
		if unique_name then
			if not g_savedata.profiler.working[unique_name] then
				g_savedata.profiler.working[unique_name] = s.getTimeMillisec()
			else
				d.print("A profiler named "..unique_name.." already exists", true, 1)
			end
		else
			d.print("A profiler was attempted to be started without a name!", true, 1)
		end
	end
end

function Debugging.stopProfiler(unique_name, requires_debug, profiler_group)
	-- if it doesnt require debug or
	-- if it requires debug and debug for the profiler is enabled or
	-- if this is a development version
	if not requires_debug or requires_debug and g_savedata.debug.profiler.enabled then
		if unique_name then
			if g_savedata.profiler.working[unique_name] then
				table.tabulate(g_savedata.profiler.total, profiler_group, unique_name, "timer")
				g_savedata.profiler.total[profiler_group][unique_name]["timer"][g_savedata.tick_counter] = s.getTimeMillisec()-g_savedata.profiler.working[unique_name]
				g_savedata.profiler.total[profiler_group][unique_name]["timer"][(g_savedata.tick_counter-g_savedata.flags.profiler_tick_smoothing)] = nil
				g_savedata.profiler.working[unique_name] = nil
			else
				d.print("A profiler named "..unique_name.." doesn't exist", true, 1)
			end
		else
			d.print("A profiler was attempted to be started without a name!", true, 1)
		end
	end
end

function Debugging.showProfilers(requires_debug)
	if g_savedata.debug.profiler.enabled then
		if g_savedata.profiler.total then
			if not g_savedata.profiler.ui_id then
				g_savedata.profiler.ui_id = s.getMapID()
			end
			d.generateProfilerDisplayData()

			local debug_message = "Profilers\navg|max|cur (ms)"
			debug_message = d.getProfilerData(debug_message)

			local player_list = s.getPlayers()
			for peer_index, peer in pairs(player_list) do
				if d.getDebug(2, peer.id) then
					s.setPopupScreen(peer.id, g_savedata.profiler.ui_id, "Profilers", true, debug_message, -0.92, 0)
				end
			end
		end
	end
end

function Debugging.getProfilerData(debug_message)
	for debug_name, debug_data in pairs(g_savedata.profiler.display.average) do
		debug_message = ("%s\n--\n%s: %.2f|%.2f|%.2f"):format(debug_message, debug_name, debug_data, g_savedata.profiler.display.max[debug_name], g_savedata.profiler.display.current[debug_name])
	end
	return debug_message
end

function Debugging.generateProfilerDisplayData(t, old_node_name)
	if not t then
		for node_name, node_data in pairs(g_savedata.profiler.total) do
			if type(node_data) == "table" then
				d.generateProfilerDisplayData(node_data, node_name)
			elseif type(node_data) == "number" then
				-- average the data over the past <profiler_tick_smoothing> ticks and save the result
				local data_total = 0
				local valid_ticks = 0
				for i = 0, g_savedata.flags.profiler_tick_smoothing do
					valid_ticks = valid_ticks + 1
					data_total = data_total + g_savedata.profiler.total[node_name][(g_savedata.tick_counter-i)]
				end
				g_savedata.profiler.display.average[node_name] = data_total/valid_ticks -- average usage over the past <profiler_tick_smoothing> ticks
				g_savedata.profiler.display.max[node_name] = max_node -- max usage over the past <profiler_tick_smoothing> ticks
				g_savedata.profiler.display.current[node_name] = g_savedata.profiler.total[node_name][(g_savedata.tick_counter)] -- usage in the current tick
			end
		end
	else
		for node_name, node_data in pairs(t) do
			if type(node_data) == "table" and node_name ~= "timer" then
				d.generateProfilerDisplayData(node_data, node_name)
			elseif node_name == "timer" then
				-- average the data over the past <profiler_tick_smoothing> ticks and save the result
				local data_total = 0
				local valid_ticks = 0
				local max_node = 0
				for i = 0, g_savedata.flags.profiler_tick_smoothing do
					if t[node_name] and t[node_name][(g_savedata.tick_counter-i)] then
						valid_ticks = valid_ticks + 1
						-- set max tick time
						if max_node < t[node_name][(g_savedata.tick_counter-i)] then
							max_node = t[node_name][(g_savedata.tick_counter-i)]
						end
						-- set average tick time
						data_total = data_total + t[node_name][(g_savedata.tick_counter-i)]
					end
				end
				g_savedata.profiler.display.average[old_node_name] = data_total/valid_ticks -- average usage over the past <profiler_tick_smoothing> ticks
				g_savedata.profiler.display.max[old_node_name] = max_node -- max usage over the past <profiler_tick_smoothing> ticks
				g_savedata.profiler.display.current[old_node_name] = t[node_name][(g_savedata.tick_counter)] -- usage in the current tick
			end
		end
	end
end

function Debugging.cleanProfilers() -- resets all profiler data in g_savedata
	if not d.getDebug(2) then
		g_savedata.profiler.working = {}
		g_savedata.profiler.total = {}
		g_savedata.profiler.display = {
			average = {},
			max = {},
			current = {}
		}
		d.print("cleaned all profiler data", true, 2)
	end
end

function Debugging.buildArgs(args)
	local s = ""
	if args then
		local arg_len = table.length(args)
		for i = 1, arg_len do
			local arg = args[i]
			-- tempoarily disabled due to how long it makes the outputs.
			--[[if type(arg) == "table" then
				arg = string.gsub(string.fromTable(arg), "\n", " ")
			end]]

			-- wrap in "" if arg is a string
			if type(arg) == "string" then
				arg = ("\"%s\""):format(arg)
			end

			s = ("%s%s%s"):format(s, arg, i ~= arg_len and ", " or "")
		end
	end
	return s
end

function Debugging.buildReturn(args)
	return d.buildArgs(args)
end

Debugging.trace = {

	print = function(ENV, requires_debug, peer_id)
		local g_tb = ENV.g_savedata.debug.traceback

		local str = ""

		if g_tb.stack_size > 0 then
			str = ("Error in function: %s(%s)"):format(g_tb.funct_names[g_tb.stack[g_tb.stack_size][1]], d.buildArgs(g_tb.stack[g_tb.stack_size][2]))
		end

		for trace = g_tb.stack_size - 1, 1, -1 do
			str = ("%s\n    Called By: %s(%s)"):format(str, g_tb.funct_names[g_tb.stack[trace][1]], d.buildArgs(g_tb.stack[trace][2]))
		end

		d.print(str, requires_debug or false, 8, peer_id or -1)
	end
}
-- required libraries

-- library name
Tags = {}

function Tags.has(tags, tag, decrement)
	if type(tags) ~= "table" then
		d.print("(Tags.has) was expecting a table, but got a "..type(tags).." instead! searching for tag: "..tag.." (this can be safely ignored)", true, 1)
		return false
	end

	if not decrement then
		for tag_index = 1, #tags do
			if tags[tag_index] == tag then
				return true
			end
		end
	else
		for tag_index = #tags, 1, -1 do
			if tags[tag_index] == tag then
				return true
			end 
		end
	end

	return false
end

-- gets the value of the specifed tag, returns nil if tag not found
function Tags.getValue(tags, tag, as_string)
	if type(tags) ~= "table" then
		d.print("(Tags.getValue) was expecting a table, but got a "..type(tags).." instead! searching for tag: "..tag.." (this can be safely ignored)", true, 1)
	end

	for k, v in pairs(tags) do
		if string.match(v, tag.."=") then
			if not as_string then
				return tonumber(tostring(string.gsub(v, tag.."=", "")))
			else
				return tostring(string.gsub(v, tag.."=", ""))
			end
		end
	end
	
	return nil
end
--[[


	Library Setup


]]

-- required libraries

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
--[[
	
Copyright 2023 Liam Matthews

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

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[ 
	Adds a new type of variable called a modifiable, stores a table of modifiers and applies them automatically
	Gives them each ids and each has optional expiries.
]]

-- library name
Modifiables = {}

--[[


	Classes


]]

---@class Modifier
---@field expires boolean if this modifier expires
---@field expires_at integer the tick this expires at
---@field modifier number the modifier.

---@class Modifiable
---@field modifiers table<string, Modifier>
---@field default_value number the value before it gets any modifiers applied

--[[


	Variables


]]

---# Prepares a table to store Modifiables
---@param t table the table which to store the modifiables
---@return Modifiable t the table prepared with modifiables
function Modifiables.prepare(t, default_value)
	t.modifiers = {}
	t.default_value = default_value

	return t
end

---# Sets or adds a modifier
---@param t Modifiable the table with the modifiables
---@param modifier_name string the name of the modifier 
---@param modifier number the value for this modifier
---@param expiry integer? the tick this will expire on, set nil to not update expirey, set to -1 to never expire.
function Modifiables.set(t, modifier_name, modifier, expiry)
	if t.modifiers[modifier_name] then
		if expiry then
			t.modifiers[modifier_name].expires_at = expiry
			t.modifiers[modifier_name].expires = expiry ~= -1
		end

		t.modifiers[modifier_name].modifier = modifier
	else
		t.modifiers[modifier_name] = {
			expires_at = expiry or -1,
			expires = expiry ~= -1,
			modifier = modifier
		}
	end
end

---# Gets the value of a modifiable.
---@param t Modifiable
---@return number modified_variable
function Modifiables.get(t)
	local value = t.default_value

	for modifier_name, modifier in pairs(t.modifiers) do
		-- if this modifier has expired
		if modifier.expires and modifier.expires_at <= g_savedata.tick_counter then
			t.modifiers[modifier_name] = nil
			goto next_modifier
		end

		value = value + modifier.modifier

		::next_modifier::
	end

	return value
end


---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

-- library name
Citizens = {}

---@alias citizenID integer

--[[


	Variables


]]

g_savedata.libraries.citizens = {
	citizen_list = {}, ---@type table<integer, Citizen>
	next_citizen_id = 1 ---@type citizenID The next citizen ID to assign.
}

--g_savedata.libraries.citizens = g_savedata.libraries.citizens

-- based off from 2021 employment rates in scotland
-- https://www.gov.scot/publications/scotlands-labour-market-people-places-regions-protected-characteristics-statistics-annual-population-survey-2021/pages/4/
local employment_rate = 73.2

--[[
	list of first names

	Some of the names may be imporperly sorted, as some may actually be neutral or not, however
	we cannot get the citizen's gender or specify it, so for right now it doesn't really matter.
]]
local first_names = {
	male = {
		"Anderson",
		"Andre'",
		"Andrew",
		"Andy",
		"Angus",
		"Archie",
		"Arthur",
		"Bearnard",
		"Bhaltair",
		"Blair",
		"Blake",
		"Brody",
		"Bruce",
		"Callum",
		"Cameron",
		"Carr",
		"Clyde",
		"Coby",
		"Colin",
		"Creighton",
		"Cromwell",
		"Dan",
		"Dave",
		"David",
		"Donald",
		"Doug",
		"Douglas",
		"Drew",
		"Eanraig",
		"Evan",
		"Gilbert",
		"Gordan",
		"Grant",
		"Ian",
		"Jack",
		"Kameron",
		"Keith",
		"Kerr",
		"Kirk",
		"Liam",
		"Logan",
		"Ludovic",
		"Malcom",
		"Matthew",
		"Max",
		"Maxwell",
		"Micheal",
		"Mitch",
		"Neill",
		"Ness",
		"Norval",
		"Peydon",
		"Ramsey",
		"Ray",
		"Robert",
		"Ron",
		"Roy",
		"Shawn",
		"Stuart",
		"Travis",
		"Todd",
		"Tom",
		"Troy",
		"Wallace"
	},
	female = {
		"Bonnie",
		"Loran"
	},
	neutral = {
		"Ash",
		"Lindsay",
		"Lindsey",
		"Jamie",
		"Paydon"
	}
}

-- list of last names
local last_names = {
	"Armstrong",
	"Davidson",
	"Douglass",
	"Elliot",
	"Fletcher",
	"Howard",
	"Jackson",
	"Kenney",
	"Kendrick",
	"Laird",
	"MacAlister",
	"MacArthur",
	"MacBeth",
	"MacCallum",
	"MacDonald",
	"Macintosh",
	"MacKendrick",
	"Quinn",
	"Reed",
	"Reid",
	"Smith",
	"Ross",
	"Scott",
	"Tory"
}

-- minimum and maximum sleep duration
local sleep_duration_parametres = {
	min = 5,
	max = 11
}

-- if the distance from this task to the next task is less or equal to this distance (m), then they can just walk.
local walking_distance = 500

-- jobs
local npc_job_list = {
	fisher = {
		vehicle = {
			required_vehicle_tags = {
				"fishing_boat"
			}
		},
		no_vehicle = {
			required_zone_tags = {
				"fishing_dock"
			},
			prefers_local = true, -- if it prefers zones within their town
			prefers_closer = true -- if it prefers zones closer to their home
		},
		use_vehicle_chance = 75, -- chance in % for using a vehicle, 0 for never, 100 for always
		min_distance = 50, -- metres
		max_distance = 3000, -- metres
		--min_duration = time.hour*3, -- duration starts once they get to destination
		--max_duration = time.hour*8
	}
}

--[[


	Classes


]]

---@class CitizenName
---@field first string their first name
---@field last string their last name
---@field full string their first + last name

---@class Citizen
---@field name CitizenName the citizen's name
---@field transform SWMatrix the citizen's matrix
---@field schedule table the citizen's schedule
---@field outfit_type SWOutfitTypeEnum the citizen's outfit type
---@field object_id integer|nil the citizen's object_id, nil if the citizen has not yet been spawned.
---@field id citizenID the citizen's ID.
---@field medical_conditions table<string, medicalCondition> the list of medical conditions that this citizen has.
---@field health number the amount of health the citizen has.
---@field stability Modifiable the stability of the citizen

--[[


	Functions


]]

---@param last_name ?string the last name to override, used for if they have a family last name
---@return CitizenName CitizenName the citizen's name data
function Citizens.generateName(last_name)

	local available_first_names = {}
	-- make a list of all names, that way names don't get picked more often just cause theres few names for that gender
	for _, names in pairs(first_names) do
		for name_index = 1, #names do
			table.insert(available_first_names, names[name_index])
		end
	end

	-- generate first name
	local first_name = available_first_names[math.random(#available_first_names)]

	-- only generate last name if not specified
	local last_name = last_name or last_names[math.random(#last_names)]

	-- combine into full name
	local full_name = ("%s %s"):format(first_name, last_name)

	return {
		first = first_name,
		last = last_name,
		full = full_name
	}
end

--[[function Citizens.getBestObjectiveZone(citizen, objective_data, valid_zones)

	local local_zones = {} -- zones within their hometown
	local global_zones = {} -- zones outside of their hometown
	for zone_index, zone_data in pairs(valid_zones) do

		local distance = m.xzDistance(zone_data.transform, citizen.home_data.transform)

		local new_zone_data = zone_data

		new_zone_data.index = zone_index

		new_zone_data.distance = distance

		if Tags.getValue(zone_data.tags, "town", true) == citizen.home_data.town_name then -- if this zone is in their home town
			table.insert(local_zones, new_zone_data)
		else -- if this zone is not in their home town
			table.insert(global_zones, new_zone_data)
		end
	end

	local function checkZones(zones)
		table.sort(zones, function(a, b) return a.distance < b.distance)

		for _, zone_data in ipairs(zones) do
			if not Zones.isReserved(zone_data.index) then
				return zone_data
			end
		end
	end

	checkZones(local_zones)

	checkZones(global_zones)

	d.print("(Citizens.getBestObjectiveZone) failed to find a valid zone!", true, 1)
	return false
end]]

--[[function Citizens.generateSchedule(citizen)
	-- random sleep duration within parametres
	local sleep_duration = math.randomDecimals(sleep_duration_parametres.min, sleep_duration_parametres.max)

	-- floor it to nearest 30m
	sleep_duration = math.floor(sleep_duration*2)*0.5

	local schedule = {
		{
			action = "sleep",
			duration = sleep_duration
		}
	}

	-- if this citizen has a job
	local has_job = math.randomDecimals(0, 100) <= employment_rate

	if has_job then
		-- choose a random job
		local job_data = npc_job_list[math.random(#npc_job_list)]

		local uses_vehicle_rand = math.randomDecimals(0, 100)
		
		local uses_vehicle = uses_vehicle_rand <= job_data.use_vehicle_chance and uses_vehicle_rand ~= 0

		if uses_vehicle then
		else
			local valid_zones = s.getZones(table.unpack(job_data.no_vehicle.required_zone_tags))

			local objective_zone = Citizens.getBestObjectiveZone(citizen, job_data, valid_zones)
		end
	end
end]]

---# Update a citizen's tooltip.
---@param citizen Citizen the citizen who's tooltip to update
function Citizens.updateTooltip(citizen)
	local tooltip = "\n"..citizen.name.full

	-- add their stability bar
	tooltip = ("%s\n\nStability\n|%s|"):format(tooltip, string.toBar(math.min(100, math.max(0, Modifiables.get(citizen.stability)/100)), 16, "=", "  "))
	
	-- add their medical conditions to the tooltip
	tooltip = ("%s\n\n%s"):format(tooltip, medicalCondition.getTooltip(citizen))

	server.setCharacterTooltip(citizen.object_id, tooltip)
end

function Citizens.create(transform, outfit_type)
	local citizen = { ---@type Citizen
		name = Citizens.generateName(),
		transform = transform,
		schedule = {},
		outfit_type = outfit_type,
		object_id = nil,
		id = g_savedata.libraries.citizens.next_citizen_id,
		medical_conditions = {},
		health = 100,
		stability = Modifiables.prepare({}, 100)
	}

	

	-- register the medical conditions.
	for medical_condition_name, medical_condition_data in pairs(medical_conditions) do
		citizen.medical_conditions[medical_condition_name] = {
			name = medical_condition_name,
			display_name = "",
			custom_data = table.copy.deep(medical_condition_data.custom_data),
			hidden = medical_condition_data.hidden
		}
	end

	g_savedata.libraries.citizens.next_citizen_id = g_savedata.libraries.citizens.next_citizen_id + 1

	table.insert(g_savedata.libraries.citizens.citizen_list, citizen)

	return citizen
	
	--citizen.schedule = Citizens.generateSchedule(citizen)
end

---@param citizen Citizen the cititzen to spawn
---@return boolean was_spawned if the citizen was spawned
function Citizens.spawn(citizen)

	-- citizen is already spawned.
	if citizen.object_id then
		return false
	end

	-- spawn the citizen
	local object_id, is_success = server.spawnCharacter(citizen.transform, citizen.outfit_type)

	-- the citizen was saved (They failed to spawn, they were saved from the sw community)
	if not is_success then
		d.print(("Failed to spawn citizen, outfit type: %s, transform: %s"):format(citizen.outfit_type, string.fromTable(citizen.transform)), true, 1)
		return false
	end

	-- citizen was spawned (Good luck.)
	citizen.object_id = object_id

	-- update their tooltip
	Citizens.updateTooltip(citizen)

	return true
end

function Citizens.remove(citizen)

	-- if this citzen has been spawned
	if citizen.object_id then
		-- despawn the citizen if they exist
		if server.getCharacterData(citizen.object_id) then
			-- despawn the character
			server.despawnObject(citizen.object_id, true)
		end
	end

	-- remove this citizen from the citizen list
	for citizen_index = 1, #g_savedata.libraries.citizens.citizen_list do
		-- if this citizen is the one we're trying to remove
		if g_savedata.libraries.citizens.citizen_list[citizen_index].id == citizen.id then
			-- remove it from g_savedata
			table.remove(g_savedata.libraries.citizens.citizen_list, citizen_index)
			return
		end
	end
end

--[[
	onTick
]]
function Citizens.onTick(game_ticks)
	-- go through all citizens

	--d.print(("#g_savedata.libraries.citizens.citizens_list: %s\n#g_savedata.libraries.citizens.citizens_list: %s"):format(#g_savedata.libraries.citizens.citizen_list, #g_savedata.libraries.citizens.citizen_list), false, 0)
	for citizen_index = 1, #g_savedata.libraries.citizens.citizen_list do
		local citizen = g_savedata.libraries.citizens.citizen_list[citizen_index]

		--d.print("Test", false, 0)

		-- update their transform
		local new_transform, is_success = server.getObjectPos(citizen.object_id)

		-- ensure it was gotten.
		if is_success then
			citizen.transform = new_transform
		end

		--server.setCharacterData(citizen.object_id, 100, true, true)

		-- detect changes in their health
		local object_data = server.getObjectData(citizen.object_id)

		if not citizen.medical_conditions.burns.custom_data.degree then
			citizen.medical_conditions.burns.custom_data = {
				degree = 0, -- the degree of the burn
				affected_area = 0, -- the % of their body that is covered in the burn
				burn_temp = 0, -- the temperature of the burn 
				burn_decay = 0
			}
		end

		if citizen.medical_conditions.burns.custom_data.degree < 4 then
			if object_data.hp < 99 then
				server.reviveCharacter(citizen.object_id)
			end
		elseif object_data.dead then
			server.reviveCharacter(citizen.object_id)
			server.setCharacterData(citizen.object_id, 5, true, true)
			d.print(("Attempting to revive %s"):format(citizen.name.full), false, 0)
		elseif not object_data.incapacitated then
			server.killCharacter(citizen.object_id)
		end

		-- just ensure the data isn't bad to avoid an error
		if object_data and object_data.hp then
			local health_change = object_data.hp - citizen.health

			-- the citizen's health changed
			if health_change ~= 0 then
				Citizens.onCitizenDamaged(citizen, health_change)
				-- update the citizen's health
				citizen.health = object_data.hp
			end
		else
			d.print(("3871: Failed to get object_data for citizen \"%s\""):format(citizen.name.full), false, 1)
		end

		-- tick their medical conditions
		medicalCondition.onTick(citizen, game_ticks)

		-- update their tooltip
		Citizens.updateTooltip(citizen)
	end
end

--[[
	onCitizenDamaged
]]
function Citizens.onCitizenDamaged(citizen, damage_amount)

	--d.print(("Citizen %s took %s damage"):format(citizen.name.full, damage_amount), false, 0)
	-- update the medical conditions for this citizen
	medicalCondition.onCitizenDamaged(citizen, damage_amount)
end

-- intercept onObjectDespawn calls

--[[

	scripts to be put after this one

]]

--[[
	definitions
]]
--[[
	
Copyright 2023 Liam Matthews

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

--[[


	Library Setup


]]

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

medicalCondition = {}

---@class medicalCondition
---@field name string the name of the medical condition, eg "burn"
---@field display_name string what to show in the list of medical conditions for this citizen, set by looking at the data in your custom_data.
---@field custom_data table<any, any> your custom data to be stored with this medical condition.
---@field hidden boolean if this condition is to be hidden.

---@class medicalConditionCallbacks
---@field name string the name of the medical condition, eg "burn"
---@field onTick function? called whenever onTick is called. (param 1 is citizen, param 2 is game_ticks)
---@field onCitizenDamaged function? called whenever a citizen is damaged or healed. (param 1 is citizen, param 2 is damage_amount)

medical_conditions_callbacks = {} ---@type table<string, medicalConditionCallbacks> the table containing all of the medical condition's callbacks

medical_conditions = {} ---@type table<string, medicalCondition> the table containing all of the medical conditions themselves, for default data.

function medicalCondition.create(name, hidden, custom_data, call_onTick, call_onCitizenDamaged)
	
	-- check if this medical condition is already registered
	if medical_conditions_callbacks[name] then
		d.print(("3954: attempt to register medical condition \"%s\" that is already registered."):format(name), true, 1)
		return
	end

	-- create it as a medicalConditionCallback.
	medical_conditions_callbacks[name] = {
		name = name,
		onTick = call_onTick,
		onCitizenDamaged = call_onCitizenDamaged
	} ---@type medicalConditionCallbacks

	-- create it as a medical condition
	medical_conditions[name] = {
		name = name,
		display_name = "",
		custom_data = custom_data,
		hidden = hidden
	}

	-- register into existing citizens who do not have the effect.
	for citizen_index = 1, #g_savedata.libraries.citizens.citizen_list do
		local citizen = g_savedata.libraries.citizens.citizen_list[citizen_index]
		
		-- if it does not exist for this citizen, register it.
		if not citizen.medical_conditions[name] then
			citizen.medical_conditions[name] = {
				name = name,
				display_name = "",
				custom_data = custom_data,
				hidden = hidden
			}
		end
	end
end

---@param citizen Citizen the citizen to get the medical condition tooltip of
function medicalCondition.getTooltip(citizen)

	local mc_string = "Conditions"

	for _, effect_data in pairs(citizen.medical_conditions) do
		
		-- if the effect is hidden, skip it
		if effect_data.hidden then
			goto continue_condition
		end

		-- add the display name
		mc_string = ("%s\n- %s"):format(mc_string, effect_data.display_name)

		::continue_condition::
	end

	return mc_string
end

--[[
	onTick
]]
function medicalCondition.onTick(citizen, game_ticks)
	-- call all medical condition onTicks for this citizen.
	for _, medical_condition_callbacks in pairs(medical_conditions_callbacks) do
		if medical_condition_callbacks.onTick then
			medical_condition_callbacks.onTick(citizen, game_ticks)
		end
	end
end

--[[
	onCitizenDamaged
]]
function medicalCondition.onCitizenDamaged(citizen, damage_amount)
	-- call all medical condition onCitizenDamaged for this citizen.
	for _, medical_condition_callbacks in pairs(medical_conditions_callbacks) do
		if medical_condition_callbacks.onCitizenDamaged then
			medical_condition_callbacks.onCitizenDamaged(citizen, damage_amount)
		end
	end
end

--[[

	scripts to be put after this one

]]

--[[
	definitions
]]
--[[
	
Copyright 2023 Liam Matthews

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

--[[


	Library Setup


]]

-- required libraries
--[[
	
Copyright 2023 Liam Matthews

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

--[[


	Library Setup


]]

-- required libraries

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[ 
	Adds additional functions for helping with fires,
	most notably (at time of writing) the ability to get the distance to the closest fire

	NOTE: We cannot do anything with block fires really, only world fires, so if a vehicle is on fire, this will not know of it's existance
	as its a completely different type of fire.
]]

-- library name
Fires = {}

--[[


	Variables


]]

---@class FireData
---@field object_id integer the object_id of the fire
---@field is_lit boolean if the fire is lit
---@field scale number the scale of the fire (may not actually have any use)

g_savedata.libraries.fires = {
	world_fires = {
		all = {}, ---@type table<integer, FireData> all of the fires, indexed by their object_id
		lit = {}, ---@type table<integer, integer> all of the lit fires in the world, value is their object_id
		--explosive = {}, ---@type table<integer, integer> all of the explosive fires in the world, value is their object_id
		loaded = {
			all = {}, ---@type table<integer, integer> all of the loaded fires in the world, value is their object_id
			lit = {}, ---@type table<integer, integer> all of the loaded lit fires in the world, value is their object_id
			--explosive = {} ---@type table<integer, integer> all of the loaded explosive fires in the world, value is their object_id
		}
	},
	last_updated_fires = 0
}

--g_savedata.libraries.fires = g_savedata.libraries.fires

--[[
	Updating the fires
]]
---@param force boolean? force the fires to update, skips the optimisation by not needing to update them multiple times per tick.
function Fires.update(force)
	
	-- we're not forced to update, and we've already updated the fires this tick, we can skip.
	if not force and g_savedata.tick_counter - g_savedata.libraries.fires.last_updated_fires == 0 then
		return
	end

	-- update object_data
	for object_id, fire_data in pairs(g_savedata.libraries.fires.world_fires.all) do
		local is_now_lit, is_success = server.getFireData(object_id)

		if not is_success then
			goto next_fire
		end

		if is_now_lit ~= fire_data.is_lit then
			if fire_data.is_lit then
				--[[
					remove it from the lit lists
				]]

				-- remove the fire from loaded lit fires list
				for i = 1, #g_savedata.libraries.fires.world_fires.loaded.lit do
					local fire_object_id = g_savedata.libraries.fires.world_fires.loaded.lit[i]

					if fire_object_id == object_id then
						table.remove(g_savedata.libraries.fires.world_fires.loaded.lit, i)
						break
					end
				end

				-- remove the fire from lit fires list
				for i = 1, #g_savedata.libraries.fires.world_fires.lit do
					local fire_object_id = g_savedata.libraries.fires.world_fires.lit[i]

					if fire_object_id == object_id then
						table.remove(g_savedata.libraries.fires.world_fires.lit, i)
						break
					end
				end
			else
				--[[
					add it to the lit lists
				]]

				-- check if it already exists in lit list
				local exists = false
				for i = 1, #g_savedata.libraries.fires.world_fires.lit do
					if g_savedata.libraries.fires.world_fires.lit[i] == object_id then
						exists = true
						break
					end
				end

				-- it doesn't exist in the lit list, add it
				if not exists then
					table.insert(g_savedata.libraries.fires.world_fires.lit, object_id)
				end

				-- check if the object is loaded
				for i = 1, #g_savedata.libraries.fires.world_fires.loaded.all do
					if g_savedata.libraries.fires.world_fires.loaded.all[i] == object_id then
						-- check if it already exists in loaded lit list
						local exists = false
						for i_lit = 1, #g_savedata.libraries.fires.world_fires.loaded.lit do
							if g_savedata.libraries.fires.world_fires.loaded.lit[i_lit] == object_id then
								exists = true
								break
							end
						end

						-- it doesn't exist in the loaded lit list, add it
						if not exists then
							table.insert(g_savedata.libraries.fires.world_fires.loaded.lit, object_id)
						end

						-- we dont need to check for further fires.
						break
					end
				end
			end
		end
		::next_fire::
	end
end

--[[

	Functions for finding the closest fire

]]
Fires.distTo = {
	
	closestLoaded = {
		---# Gets the distance and data on the closest loaded fire, can be lit or explosive
		---@param transform SWMatrix
		---@return number dist the distance to the closest loaded fire
		---@return integer? closest_fire the object_id of the closest fire
		---@return boolean is_success if we found a fire thats closest, returns false if none were found.
		fire = function(transform)

			local closest_dist = math.huge
			local closest_fire = nil
			for fire_index = 1, #g_savedata.libraries.fires.world_fires.loaded.all do
				local object_id = g_savedata.libraries.fires.world_fires.loaded.all[fire_index]

				local fire_transform, is_success = server.getObjectPos(object_id)

				-- if we failed to get the fire's position
				if not is_success then
					goto next_fire
				end

				local fire_dist = math.euclideanDistance(
					transform[13],
					fire_transform[13],
					transform[14],
					fire_transform[14],
					transform[15],
					fire_transform[15]
				)

				-- if this fire is closer than the closest so far
				if closest_dist > fire_dist then
					-- set it as the closest
					closest_dist = fire_dist
					closest_fire = object_id
				end

				::next_fire::
			end

			return closest_dist, closest_fire, closest_fire ~= nil
		end,
		---# Gets the distance and data on the closest loaded lit fire.
		---@param transform SWMatrix
		---@return number dist the distance to the closest loaded fire
		---@return integer? closest_fire the object_id of the closest fire
		---@return boolean is_success if we found a fire thats closest, returns false if none were found.
		lit = function(transform)

			-- update the fires, to check if any became lit.
			Fires.update()

			local closest_dist = math.huge
			local closest_fire = nil
			for fire_index = 1, #g_savedata.libraries.fires.world_fires.loaded.lit do
				local object_id = g_savedata.libraries.fires.world_fires.loaded.lit[fire_index]

				local fire_transform, is_success = server.getObjectPos(object_id)

				-- if we failed to get the fire's position
				if not is_success then
					goto next_fire
				end

				local fire_dist = math.euclideanDistance(
					transform[13],
					fire_transform[13],
					transform[14],
					fire_transform[14],
					transform[15],
					fire_transform[15]
				)

				-- if this fire is closer than the closest so far
				if closest_dist > fire_dist then
					-- set it as the closest
					closest_dist = fire_dist
					closest_fire = object_id
				end

				::next_fire::
			end

			return closest_dist, closest_fire, closest_fire ~= nil
		end
		---# Gets the distance and data on the closest loaded explosive fire.
		--explosive = function(transform)
		--end
	}
}

--[[

	Injecting into callbacks
	
]]

-- remove fires when they despawn
local old_onObjectDespawn = onObjectDespawn
function onObjectDespawn(object_id, object_data)
	-- avoid error if onObjectDespawn is not used anywhere else before.
	if old_onObjectDespawn then
		old_onObjectDespawn(object_id, object_data)
	end

	-- check if this was a stored world fire
	if not g_savedata.libraries.fires.world_fires.all[object_id] then
		return
	end

	--[[
		find all references to it, and remove them.
	]]
	for i = 1, #g_savedata.libraries.fires.world_fires.lit do
		local fire_object_id = g_savedata.libraries.fires.world_fires.lit[i]

		if fire_object_id == object_id then
			table.remove(g_savedata.libraries.fires.world_fires.lit, i)
			break
		end
	end

	for i = 1, #g_savedata.libraries.fires.world_fires.loaded.lit do
		local fire_object_id = g_savedata.libraries.fires.world_fires.loaded.lit[i]

		if fire_object_id == object_id then
			table.remove(g_savedata.libraries.fires.world_fires.loaded.lit, i)
			break
		end
	end

	for i = 1, #g_savedata.libraries.fires.world_fires.loaded.all do
		local fire_object_id = g_savedata.libraries.fires.world_fires.loaded.all[i]

		if fire_object_id == object_id then
			table.remove(g_savedata.libraries.fires.world_fires.loaded.all, i)
			break
		end
	end

	g_savedata.libraries.fires.world_fires.all[object_id] = nil
end

-- add fires into loaded when they load, and check if they exist already, if not, add them.
local old_onObjectLoad = onObjectLoad
function onObjectLoad(object_id)
	-- avoid error if onObjectLoad is not used anywhere else before.
	if old_onObjectLoad then
		old_onObjectLoad(object_id)
	end

	local object_data = server.getObjectData(object_id)

	-- check if its a fire
	if not object_data or object_data.object_type ~= 58 then
		return
	end

	local is_lit = server.getFireData(object_id)

	g_savedata.libraries.fires.world_fires.all[object_id] = {
		object_id = object_id,
		is_lit = is_lit,
		scale = object_data.scale
	}

	-- check if it already exists in loaded list
	local exists = false
	for i = 1, #g_savedata.libraries.fires.world_fires.loaded.all do
		if g_savedata.libraries.fires.world_fires.loaded.all[i] == object_id then
			exists = true
			break
		end
	end

	-- it doesn't exist in the loaded list, add it
	if not exists then
		table.insert(g_savedata.libraries.fires.world_fires.loaded.all, object_id)
	end

	-- skip lit checks if the fire is not lit
	local is_lit, is_success = server.getFireData(object_id)
	if not is_lit then
		return
	end

	-- check if it already exists in lit list
	exists = false
	for i = 1, #g_savedata.libraries.fires.world_fires.lit do
		if g_savedata.libraries.fires.world_fires.lit[i] == object_id then
			exists = true
			break
		end
	end

	-- it doesn't exist in the lit list, add it
	if not exists then
		table.insert(g_savedata.libraries.fires.world_fires.lit, object_id)
	end

	-- check if it already exists in loaded lit list
	exists = false
	for i = 1, #g_savedata.libraries.fires.world_fires.loaded.lit do
		if g_savedata.libraries.fires.world_fires.loaded.lit[i] == object_id then
			exists = true
			break
		end
	end

	-- it doesn't exist in the loaded lit list, add it
	if not exists then
		table.insert(g_savedata.libraries.fires.world_fires.loaded.lit, object_id)
	end
end

-- remove fires from the loaded list when they unload
local old_onObjectUnload = onObjectUnload
function onObjectUnload(object_id)
	-- avoid error if onObjectUnload is not used anywhere else before.
	if old_onObjectUnload then
		old_onObjectUnload(object_id)
	end

	-- check if this exists as a tracked fire
	if not g_savedata.libraries.fires.world_fires.all[object_id] then
		return
	end

	-- remove the fire from loaded lit fires list
	for i = 1, #g_savedata.libraries.fires.world_fires.loaded.lit do
		local fire_object_id = g_savedata.libraries.fires.world_fires.loaded.lit[i]

		if fire_object_id == object_id then
			table.remove(g_savedata.libraries.fires.world_fires.loaded.lit, i)
			break
		end
	end

	-- remove the fire from loaded fires list
	for i = 1, #g_savedata.libraries.fires.world_fires.loaded.all do
		local fire_object_id = g_savedata.libraries.fires.world_fires.loaded.all[i]

		if fire_object_id == object_id then
			table.remove(g_savedata.libraries.fires.world_fires.loaded.all, i)
			break
		end
	end
end


medicalCondition.create(
	"burns",
	true,
	{
		degree = 0, -- the degree of the burn
		affected_area = 0, -- the % of their body that is covered in the burn
		burn_temp = 0, -- the temperature of the burn 
		burn_decay = 0
	},
	---@param citizen Citizen
	function(citizen, game_ticks)
		-- tick every second

		local tick_rate = 1
		if not isTickID(0, tick_rate) then
			return
		end

		local tick_mult = tick_rate/60

		local burn = citizen.medical_conditions.burns

		if not burn.custom_data.burn_temp then
			burn.custom_data = {
				degree = 0, -- the degree of the burn
				affected_area = 0, -- the % of their body that is covered in the burn
				burn_temp = 0, -- the temperature of the burn 
				in_fire = false
			}
		end

		if not burn.custom_data.burn_decay then
			burn.custom_data.burn_decay = 0
		end

		-- if the citizen's burn temp is over 44
		if burn.custom_data.burn_temp >= 44 then
			local burn_rate = 0.05

			-- if the citizen is currently burning
			if burn.custom_data.burn_decay > 0 then
				burn_rate = 0.125
			end

			local rate = (burn.custom_data.burn_temp*burn_rate)^2.5*0.0001*tick_mult

			burn.custom_data.degree = math.min(rate * 4 + (1 - rate)^0.98 * burn.custom_data.degree, 4)
		end

		burn.custom_data.burn_temp = math.max(burn.custom_data.burn_temp - 0.2*tick_mult, 30)

		burn.custom_data.burn_decay = burn.custom_data.burn_decay - 1*tick_mult

		-- update the shown condition
		--[[if burn.custom_data.degree < 1 then
			burn.hidden = true
			return
		end]]

		-- update stability

		Modifiables.set(citizen.stability, "burns", (burn.custom_data.degree*-2)*burn.custom_data.affected_area, -1)

		burn.hidden = false

		local degree = "Zeroth"
		if burn.custom_data.degree >= 4 then
			degree = "Fourth"
		elseif burn.custom_data.degree >= 3 then
			degree = "Third"
		elseif burn.custom_data.degree >= 2 then
			degree = "Second"
		elseif burn.custom_data.degree >= 1 then
			degree = "First"
		end

		burn.display_name = ("%s Degree Burn\nDegree: %0.3f\nBurn Temp: %0.3f\nIs In Fire: %s\nBody %% Burnt: %0.2f"):format(degree, burn.custom_data.degree, burn.custom_data.burn_temp, burn.custom_data.burn_decay > 0, burn.custom_data.affected_area)
	end,
	---@param citizen Citizen
	---@param health_change number
	function(citizen, health_change)
		-- discard if they were healed
		if health_change > 0 then
			return
		end

		-- check for nearby fires
		local closest_fire_distance, closest_fire, got_closest_fire = Fires.distTo.closestLoaded.lit(citizen.transform)

		-- if theres no loaded lit fires.
		if not got_closest_fire then
			return
		end

		local burn = citizen.medical_conditions.burns

		if not burn.custom_data.burn_temp then
			burn.custom_data = {
				degree = 0, -- the degree of the burn
				affected_area = 0, -- the % of their body that is covered in the burn
				burn_temp = 0, -- the temperature of the burn 
				in_fire = false
			}
		end

		if not burn.custom_data.burn_decay then
			burn.custom_data.burn_decay = 0
		end

		if closest_fire_distance > 5 then
			return
		end
		
		--d.print(("%s has been detected to have taken %0.4f damage, assuming to have been from a fire."):format(citizen.name.full, health_change), false, 0)
		--citizen.medical_conditions.burns.hidden = false
		--citizen.medical_conditions.burns.display_name = "Crisp"

		--server.setGameSetting("npc_damage", false)
		--server.setCharacterData(citizen.object_id, 100, true, true)
		--server.setGameSetting("npc_damage", true)
		--server.setCharacterData(citizen.object_id, 100, true, true)

		burn.custom_data.affected_area = math.min(burn.custom_data.affected_area + 0.02, 100)

		burn.custom_data.burn_temp = math.min(burn.custom_data.burn_temp + math.abs(health_change)*5, 120)

		burn.custom_data.burn_decay = 2
	end
)
--[[
	
Copyright 2023 Liam Matthews

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

--[[

	Registers the default commands.

]]

-- Spawn Citizen command
Command.registerCommand(
	"spawnCitizen",
	---@param full_message string the full message
	---@param peer_id integer the peer_id of the sender
	---@param arg table the arguments of the command.
	function(full_message, peer_id, arg)
		Citizens.spawn(Citizens.create(server.getPlayerPos(peer_id), 1))
	end,
	"admin_script",
	"Spawns a citizen at the player's position",
	"Spawns a citizen",
	{""}
)

-- Kill Citizen command
Command.registerCommand(
	"killCitizen",
	---@param full_message string the full message
	---@param peer_id integer the peer_id of the sender
	---@param arg table the arguments of the command.
	function(full_message, peer_id, arg)
		for citizen_index = #g_savedata.libraries.citizens.citizen_list, 1, -1 do
			Citizens.remove(g_savedata.libraries.citizens.citizen_list[citizen_index])
		end
	end,
	"admin_script",
	"Spawns a citizen at the player's position",
	"Spawns a citizen",
	{""}
)
-- This library is for controlling or getting things about the AI.

-- required libraries

-- library name
AI = {}

--- @param vehicle_object vehicle_object the vehicle you want to set the state of
--- @param state string the state you want to set the vehicle to
--- @return boolean success if the state was set
function AI.setState(vehicle_object, state)
	if vehicle_object then
		if state ~= vehicle_object.state.s then
			if state == VEHICLE.STATE.HOLDING then
				vehicle_object.holding_target = vehicle_object.transform
			end
			vehicle_object.state.s = state
		end
	else
		d.print("(AI.setState) vehicle_object is nil!", true, 1)
	end
	return false
end

--# made for use with toggles in buttons (only use for toggle inputs to seats)
---@param vehicle_id integer the vehicle's id that has the seat you want to set
---@param seat_name string the name of the seat you want to set
---@param axis_ws number w/s axis
---@param axis_ad number a/d axis
---@param axis_ud number up down axis
---@param axis_lr number left right axis
---@param ... boolean buttons (1-7) (7 is trigger)
---@return boolean set_seat if the seat was set
function AI.setSeat(vehicle_id, seat_name, axis_ws, axis_ad, axis_ud, axis_lr, ...)
	
	if not vehicle_id then
		d.print("(AI.setSeat) vehicle_id is nil!", true, 1)
		return false
	end

	if not seat_name then
		d.print("(AI.setSeat) seat_name is nil!", true, 1)
		return false
	end

	local button = table.pack(...)

	-- sets any nil values to 0 or false
	axis_ws = axis_ws or 0
	axis_ad = axis_ad or 0
	axis_ud = axis_ud or 0
	axis_lr = axis_lr or 0

	for i = 1, 7 do
		button[i] = button[i] or false
	end

	g_savedata.seat_states = g_savedata.seat_states or {}


	if not g_savedata.seat_states[vehicle_id] or not g_savedata.seat_states[vehicle_id][seat_name] then

		g_savedata.seat_states[vehicle_id] = g_savedata.seat_states[vehicle_id] or {}
		g_savedata.seat_states[vehicle_id][seat_name] = {}

		for i = 1, 7 do
			g_savedata.seat_states[vehicle_id][seat_name][i] = false
		end
	end

	for i = 1, 7 do
		if button[i] ~= g_savedata.seat_states[vehicle_id][seat_name][i] then
			g_savedata.seat_states[vehicle_id][seat_name][i] = button[i]
			button[i] = true
		else
			button[i] = false
		end
	end

	s.setVehicleSeat(vehicle_id, seat_name, axis_ws, axis_ad, axis_ud, axis_lr, button[1], button[2], button[3], button[4], button[5], button[6], button[7])
	return true
end
 -- functions relating to their AI
-- required libraries

-- library name
Cache = {}

---@param location g_savedata.cache[] where to reset the data, if left blank then resets all cache data
---@param boolean success returns true if successfully cleared the cache
function Cache.reset(location) -- resets the cache
	if not location then
		g_savedata.cache = {}
	else
		if g_savedata.cache[location] then
			g_savedata.cache[location] = nil
		else
			if not g_savedata.cache_stats.failed_resets then
				g_savedata.cache_stats.failed_resets = 0
			end
			g_savedata.cache_stats.failed_resets = g_savedata.cache_stats.failed_resets + 1
			d.print("Failed to reset cache data at "..tostring(location)..", this should not be happening!", true, 1)
			return false
		end
	end
	g_savedata.cache_stats.resets = g_savedata.cache_stats.resets + 1
	return true
end

---@param location g_savedata.cache[] where to write the data
---@param data any the data to write at the location
---@return boolean write_successful if writing the data to the cache was successful
function Cache.write(location, data)

	if type(g_savedata.cache[location]) ~= "table" then
		d.print("Data currently at the cache of "..tostring(location)..": "..tostring(g_savedata.cache[location]), true, 0)
	else
		d.print("Data currently at the cache of "..tostring(location)..": (table)", true, 0)
	end

	g_savedata.cache[location] = data

	if type(g_savedata.cache[location]) ~= "table" then
		d.print("Data written to the cache of "..tostring(location)..": "..tostring(g_savedata.cache[location]), true, 0)
	else
		d.print("Data written to the cache of "..tostring(location)..": (table)", true, 0)
	end

	if g_savedata.cache[location] == data then
		g_savedata.cache_stats.writes = g_savedata.cache_stats.writes + 1
		return true
	else
		g_savedata.cache_stats.failed_writes = g_savedata.cache_stats.failed_writes + 1
		return false
	end
end

---@param location g_savedata.cache[] where to read the data from
---@return any data the data that was at the location
function Cache.read(location)
	g_savedata.cache_stats.reads = g_savedata.cache_stats.reads + 1
	if type(g_savedata.cache[location]) ~= "table" then
		d.print("reading cache data at\ng_savedata.Cache."..tostring(location).."\n\nData: "..g_savedata.cache[location], true, 0)
	else
		d.print("reading cache data at\ng_savedata.Cache."..tostring(location).."\n\nData: (table)", true, 0)
	end
	return g_savedata.cache[location]
end

---@param location g_savedata.cache[] where to check
---@return boolean exists if the data exists at the location
function Cache.exists(location)
	if g_savedata.cache[location] and g_savedata.cache[location] ~= {} and (type(g_savedata.cache[location]) ~= "table" or Tables.length(g_savedata.cache[location]) > 0) or g_savedata.cache[location] == false then
		d.print("g_savedata.Cache."..location.." exists", true, 0)

		return true
	end
	d.print("g_savedata.Cache."..location.." doesn't exist", true, 0)
	return false
end
 -- functions relating to the cache
--[[


	Library Setup


]]

-- required libraries
--[[


	Library Setup


]]

-- required libraries

-- library name
Setup = {}

-- shortened library name
sup = Setup

--[[


	Classes


]]

--[[


	Functions         


]]


-- library name
Compatibility = {}

-- shortened library name
comp = Compatibility

--[[


	Variables
   

]]

--# stores which versions require compatibility updates
local version_updates = {}

--[[


	Classes


]]

---@class VERSION_DATA
---@field data_version string the version which the data is on currently
---@field version string the version which the mod is on
---@field versions_outdated integer how many versions the data is out of date
---@field is_outdated boolean if the data is outdated compared to the mod
---@field newer_versions table a table of versions which are newer than the current, indexed by index, value as version string

--[[


	Functions         


]]

--# creates version data for the specified version, for use in the version_history table
---@param version string the version you want to create the data on
---@return table version_history_data the data of the version
function Compatibility.createVersionHistoryData(version)

	--[[
		calculate ticks played
	]] 
	local ticks_played = g_savedata.tick_counter

	if g_savedata.info.version_history and #g_savedata.info.version_history > 0 then
		for _, version_data in ipairs(g_savedata.info.version_history) do
			ticks_played = ticks_played - (version_data.ticks_played or 0)
		end
	end

	--[[
		
	]]
	local version_history_data = {
		version = version,
		ticks_played = ticks_played,
		backup_g_savedata = {}
	}

	return version_history_data
end

--# returns g_savedata, a copy of g_savedata which when edited, doesnt actually apply changes to the actual g_savedata, useful for backing up.
function Compatibility.getSavedataCopy()

	--d.print("(comp.getSavedataCopy) getting a g_savedata copy...", true, 0)

	--[[
		credit to Woe (https://canary.discord.com/channels/357480372084408322/905791966904729611/1024355759468839074)

		returns a clone/copy of g_savedata
	]]
	
	local function clone(t)
		local copy = {}
		if type(t) == "table" then
			for key, value in next, t, nil do
				copy[clone(key)] = clone(value)
			end
		else
			copy = t
		end
		return copy
	end

	local copied_g_savedata = clone(g_savedata)
	--d.print("(comp.getSavedataCopy) created a g_savedata copy!", true, 0)

	return copied_g_savedata
end

--# migrates the version system to the new one implemented in 0.3.0.78
---@param overwrite_g_savedata boolean if you want to overwrite g_savedata, usually want to keep false unless you've already got a backup of g_savedata
---@return table migrated_g_savedata
---@return boolean is_success if it successfully migrated the versioning system
function Compatibility.migrateVersionSystem(overwrite_g_savedata)

	d.print("migrating g_savedata...", false, 0)

	--[[
		create a local copy of g_savedata, as changes we make we dont want to be applied to the actual g_savedata
	]]

	local migrated_g_savedata = comp.getSavedataCopy()

	--[[
		make sure that the version_history table doesnt exist
	]]
	if g_savedata.info.version_history then
		-- if it already does, then abort, as the version system is already migrated
		d.print("(comp.migrateVersionSystem) the version system has already been migrated!", true, 1)
		return nil, false
	end

	--[[
		create the version_history table
	]]
	if overwrite_g_savedata then
		g_savedata.info.version_history = {}
	end

	migrated_g_savedata.info.version_history = {}

	--[[
		create the version history data, with the previous version the creation version 
		sadly, we cannot reliably get the last version used for versions 0.3.0.77 and below
		so we have to make this assumption
	]]

	if overwrite_g_savedata then
		table.insert(g_savedata.info.version_history, comp.createVersionHistoryData(migrated_g_savedata.info.creation_version))
	end
	
	table.insert(migrated_g_savedata.info.version_history, comp.createVersionHistoryData(migrated_g_savedata.info.creation_version))

	d.print("migrated g_savedata", false, 0)

	return migrated_g_savedata, true
end

--# returns the version id from the provided version
---@param version string the version you want to get the id of
---@return integer version_id the id of the version
---@return boolean is_success if it found the id of the version
function Compatibility.getVersionID(version)
	--[[
		first, we want to ensure version was provided
		lastly, we want to go through all of the versions stored in the version history, if we find a match, then we return it as the id
		if we cannot find a match, we return nil and false
	]]

	-- ensure version was provided
	if not version then
		d.print("(comp.getVersionID) version was not provided!", false, 1)
		return nil, false
	end

	-- go through all of the versions saved in version_history
	for version_id, version_name in ipairs(g_savedata.info.version_history) do
		if version_name == version then
			return version_id, true
		end
	end

	-- if a version was not found, return nil and false
	return nil, false
end

--# splits a version into 
---@param version string the version you want split
---@return table version [1] = release version, [2] = majour version, [3] = minor version, [4] = commit version
function Compatibility.splitVersion(version) -- credit to woe
	local T = {}

	-- remove ( and )
	version = version:match("[%d.]+")

	for S in version:gmatch("([^%.]*)%.*") do
		T[#T+1] = tonumber(S) or S
	end

	T = {
		T[1], -- release
		T[2], -- majour
		T[3], -- minor
		T[4] -- commit
	}

	return T
end

--# returns the version from the version_id
---@param version_id integer the id of the version
---@return string version the version associated with the id
---@return boolean is_success if it successfully got the version from the id
function Compatibility.getVersion(version_id)

	-- ensure that version_id was specified
	if not version_id then
		d.print("(comp.getVersion) version_id was not provided!", false, 1)
		return nil, false
	end

	-- ensure that it is a number
	if type(version_id) ~= "number" then
		d.print("(comp.getVersion) given version_id was not a number! type: "..type(version_id).." value: "..tostring(version_id), false, 1)
		return nil, false
	end

	local version = g_savedata.info.version_history[version_id] and g_savedata.info.version_history[version_id].version or nil
	return version, version ~= nil
end

--# returns version data about the specified version, or if left blank, the current version
---@param version string the current version, leave blank if want data on current version
---@return VERSION_DATA version_data the data about the version
---@return boolean is_success if it successfully got the version data
function Compatibility.getVersionData(version)

	local version_data = {
		data_version = "",
		is_outdated = false,
		version = "",
		versions_outdated = 0,
		newer_versions = {}
	}

	local copied_g_savedata = comp.getSavedataCopy() -- local copy of g_savedata so any changes we make to it wont affect any backups we may make

	--[[
		first, we want to ensure that the version system is migrated
		second, we want to get the id of the version depending on the given version argument
		third, we want to get the data version
		fourth, we want to count how many versions out of date the data version is from the mod version
		fifth, we want to want to check if the version is outdated
		and lastly, we want to return the data
	]]

	-- (1) check if the version system is not migrated
	if not g_savedata.info.version_history then
		local migrated_g_savedata, is_success = comp.migrateVersionSystem() -- migrate the version data
		if not is_success then
			d.print("(comp.getVersionData) failed to migrate version system. This is probably not good!", false, 1)
			return nil, false
		end

		-- set copied_g_savedata as migrated_g_savedata
		copied_g_savedata = migrated_g_savedata
	end

	-- (2) get version id
	local version_id = version and comp.getVersionID(version) or #copied_g_savedata.info.version_history

	-- (3) get data version
	--d.print("(comp.getVersionData) data_version: "..tostring(copied_g_savedata.info.version_history[version_id].version))
	version_data.data_version = copied_g_savedata.info.version_history[version_id].version

	-- (4) count how many versions out of date the data is

	local current_version = comp.splitVersion(version_data.data_version)

	local ids_to_versions = {
		"Release",
		"Majour",
		"Minor",
		"Commit"
	}

	for _, version_name in ipairs(version_updates) do

		--[[
			first, we want to check if the release version is greater (x.#.#.#)
			if not, second we want to check if the majour version is greater (#.x.#.#)
			if not, third we want to check if the minor version is greater (#.#.x.#)
			if not, lastly we want to check if the commit version is greater (#.#.#.x)
		]]

		local update_version = comp.splitVersion(version_name)

		--[[
			go through each version, and check if its newer than our current version
		]]
		for i = 1, #current_version do
			if not current_version[i] or current_version[i] > update_version[i] then
				--[[
					if theres no commit version for the current version, all versions with the same stable, majour and minor version will be older.
					OR, current version is newer, then dont continue, as otherwise that could trigger a false positive with things like 0.3.0.2 vs 0.3.1.1
				]]
				d.print(("(comp.getVersionData) %s Version %s is older than current %s Version: %s"):format(ids_to_versions[i], update_version[i], ids_to_versions[i], current_version[i]), true, 0)
				break
			elseif current_version[i] < update_version[i] then
				-- current version is older, so we need to migrate data.
				table.insert(version_data.newer_versions, version_name)
				d.print(("Found new %s version: %s current version: %s"):format(ids_to_versions[i], version_name, version_data.data_version), false, 0)
				break
			end

			d.print(("(comp.getVersionData) %s Version %s is the same as current %s Version: %s"):format(ids_to_versions[i], update_version[i], ids_to_versions[i], current_version[i]), true, 0)
		end
	end

	-- count how many versions its outdated
	version_data.versions_outdated = #version_data.newer_versions

	-- (5) check if its outdated
	version_data.is_outdated = version_data.versions_outdated > 0

	return version_data, true
end

--# saves backup of current g_savedata
---@return boolean is_success if it successfully saved a backup of the savedata
function Compatibility.saveBackup()
	--[[
		first, we want to save a current local copy of the g_savedata
		second we want to ensure that the g_savedata.info.version_history table is created
		lastly, we want to save the backup g_savedata
	]]

	-- create local copy of g_savedata
	local backup_g_savedata = comp.getSavedataCopy()

	if not g_savedata.info.version_history then -- if its not created (pre 0.3.0.78)
		d.print("(comp.saveBackup) migrating version system", true, 0)
		local migrated_g_savedata, is_success = comp.migrateVersionSystem(true) -- migrate version system
		if not is_success then
			d.print("(comp.saveBackup) failed to migrate version system. This is probably not good!", false, 1)
			return false
		end

		if not g_savedata.info.version_history then
			d.print("(comp.saveBackup) successfully migrated version system, yet g_savedata doesn't contain the new version system, this is not good!", false, 1)
		end
	end

	local version_data, is_success = comp.getVersionData()
	if version_data.data_version ~= g_savedata.info.version_history[#g_savedata.info.version_history].version then
		--d.print("version_data.data_version: "..tostring(version_data.data_version).."\ng_savedata.info.version_history[#g_savedata.info.version.version_history].version: "..tostring(g_savedata.info.version_history[#g_savedata.info.version_history].version))
		g_savedata.info.version_history[#g_savedata.info.version_history + 1] = comp.createVersionHistoryData()
	end

	-- save backup g_savedata
	g_savedata.info.version_history[#g_savedata.info.version_history].backup_g_savedata = backup_g_savedata

	-- remove g_savedata backups which are from over 2 data updates ago
	local backup_versions = {}
	for version_index, version_history_data in ipairs(g_savedata.info.version_history) do
		if version_history_data.backup_g_savedata.info then
			table.insert(backup_versions, version_index)
		end
	end
	
	if #backup_versions >= 3 then
		d.print("Deleting old backup data...", false, 0)
		for backup_index, backup_version_index in ipairs(backup_versions) do
			d.print("Deleting backup data for "..g_savedata.info.version_history[backup_version_index].version, false, 0)
			backup_versions[backup_index] = nil
			g_savedata.info.version_history[backup_version_index].backup_g_savedata = {}

			if #backup_versions <= 2 then
				d.print("Deleted old backup data.", false, 0)
				break
			end
		end
	end

	return true
end

--# updates g_savedata to be compatible with the mod version, to ensure that worlds are backwards compatible.
function Compatibility.update()

	-- ensure that we're actually outdated before proceeding
	local version_data, is_success = comp.getVersionData()
	if not is_success then
		d.print("(comp.update) failed to get version data! this is probably bad!", false, 1)
		return
	end

	if not version_data.is_outdated then
		d.print("(comp.update) according to version data, the data is not outdated. This is probably not good!", false, 1)
		return
	end

	d.print("IMAI's data is "..version_data.versions_outdated.." version"..(version_data.versions_outdated > 1 and "s" or "").." out of date!", false, 0)

	-- save backup
	local backup_saved = comp.saveBackup()
	if not backup_saved then
		d.print("(comp.update) Failed to save backup. This is probably not good!", false, 1)
		return false
	end

	d.print("Creating new version history for "..version_data.newer_versions[1].."...", false, 0)
	local version_history_data = comp.createVersionHistoryData(version_data.newer_versions[1])
	g_savedata.info.version_history[#g_savedata.info.version_history+1] = version_history_data
	d.print("Successfully created new version history for "..version_data.newer_versions[1]..".", false, 0)

	-- check for  changes
	if version_data.newer_versions[1] == "" then
	end
	d.print("IMAI data is now up to date with "..version_data.newer_versions[1]..".", false, 0)

	just_migrated = true
end

--# prints outdated message and starts update
function Compatibility.outdated()
	-- print that its outdated
	d.print("IMAI data is outdated! attempting to automatically update...", false, 0)

	-- start update process
	comp.update()
end

--# verifies that the mod is currently up to date
function Compatibility.verify()
	d.print("verifying if IMAI data is up to date...", false, 0)
	--[[
		first, check if the versioning system is up to date
	]]
	if not g_savedata.info.version_history then
		-- the versioning system is not up to date
		comp.outdated()
	else
		-- check if we're outdated
		local version_data, is_success = comp.getVersionData()

		if not is_success then
			d.print("(comp.verify) failed to get version data! this is probably bad!", false, 1)
			return
		end

		-- if we're outdated
		if version_data.is_outdated then
			comp.outdated()
		end
	end
end

--# shows the message to save the game and then load the save to complete migration
function Compatibility.showSaveMessage()
	is_dlc_weapons = false
	d.print("IMAI Data has been migrated, to complete the process, please save the world, and then load the saved world. IMAI has been disabled until this is done.", false, 0)
	s.setPopupScreen(-1, s.getMapID(), "IMAI Migration", true, "Please save world and then load save to complete data migration process. IMAI has been disabled till this is complete.", 0, 0)
end

 -- functions used for making the mod backwards compatible -- functions for debugging
-- required libraries

-- library name
Map = {}

--# draws a search area within the specified radius at the coordinates provided
---@param x number the x coordinate of where the search area will be drawn around (required)
---@param z number the z coordinate of where the search area will be drawn around (required)
---@param radius number the radius of the search area (required)
---@param ui_id integer the ui_id of the search area (required)
---@param peer_id integer the peer_id of the player which you want to draw the search area for (defaults to -1)
---@param label string The text that appears when mousing over the icon. Appears like a title (defaults to "")
---@param hover_label string The text that appears when mousing over the icon. Appears like a subtitle or description (defaults to "")
---@param r integer 0-255, the red value of the search area (defaults to 255)
---@param g integer 0-255, the green value of the search area (defaults to 255)
---@param b integer 0-255, the blue value of the search area (defaults to 255)
---@param a integer 0-255, the alpha value of the search area (defaults to 255)
---@return number x the x coordinate of where the search area was drawn
---@return number z the z coordinate of where the search area was drawn
---@return boolean success if the search area was drawn
function Map.drawSearchArea(x, z, radius, ui_id, peer_id, label, hover_label, r, g, b, a)

	if not x then -- if the x position of the target was not provided
		d.print("(Map.drawSearchArea) x is nil!", true, 1)
		return nil, nil, false
	end

	if not z then -- if the z position of the target was not provided
		d.print("(Map.drawSearchArea) z is nil!", true, 1)
		return nil, nil, false
	end

	if not radius then -- if the radius of the search area was not provided
		d.print("(Map.drawSearchArea) radius is nil!", true, 1)
		return nil, nil, false
	end

	if not ui_id then -- if the ui_id was not provided
		d.print("(Map.drawSearchArea) ui_id is nil!", true, 1)
		return nil, nil, false
	end

	-- default values (if not specified)

	local peer_id = peer_id or -1 -- makes the peer_id default to -1 if not provided (-1 = everybody)

	local label = label or "" -- defaults the label to "" if it was not specified
	local hover_label = hover_label or "" -- defaults the hover_label to "" if it was not specified

	local r = r or 255 -- makes the red colour default to 255 if not provided
	local g = g or 255 -- makes the green colour default to 255 if not provided
	local b = b or 255 -- makes the blue colour default to 255 if not provided
	local a = a or 255 -- makes the alpha default to 255 if not provided

	local angle = math.random() * math.pi * 2 -- gets a random angle to put the search radius focus around
	local dist = math.sqrt(math.randomDecimals(0.1, 0.9)) * radius -- gets a random distance from the target to put the search radius at

	local x_pos = dist * math.sin(angle) + x -- uses the distance and angle to make the x pos of the search radius
	local z_pos = dist * math.cos(angle) + z -- uses the distance and angle to make the z pos of the search radius

	s.addMapObject(peer_id, ui_id, 0, 2, x_pos, z_pos, 0, 0, 0, 0, label, radius, hover_label, r, g, b, a) -- draws the search radius to the map

	return x_pos, z_pos, true -- returns the x pos and z pos of the drawn search radius, and returns true that it was drawn.
end

function Map.addMapCircle(peer_id, ui_id, center_matrix, radius, width, r, g, b, a, lines) -- credit to woe
	peer_id, ui_id, center_matrix, radius, width, r, g, b, a, lines = peer_id or -1, ui_id or 0, center_matrix or m.translation(0, 0, 0), radius or 500, width or 0.25, r or 255, g or 0, b or 0, a or 255, lines or 16
	local center_x, center_z = center_matrix[13], center_matrix[15]
	for i = 0, lines do
		local x1, z1 = center_x+radius*math.cos(math.tau/lines*i), center_z+radius*math.sin(math.tau/lines*i)
		local x2, z2 = center_x+radius*math.cos(math.tau/lines*(i+1)), center_z+radius*math.sin(math.tau/lines*(i+1))
		local start_matrix, end_matrix = m.translation(x1, 0, z1), m.translation(x2, 0, z2)
		s.addMapLine(peer_id, ui_id, start_matrix, end_matrix, width, r, g, b, a)
	end
end
 -- functions for drawing on the map -- custom math functions -- custom matrix functions
--[[


	Library Setup


]]


-- required libraries
-- required libraries

-- library name
Tags = {}

function Tags.has(tags, tag, decrement)
	if type(tags) ~= "table" then
		d.print("(Tags.has) was expecting a table, but got a "..type(tags).." instead! searching for tag: "..tag.." (this can be safely ignored)", true, 1)
		return false
	end

	if not decrement then
		for tag_index = 1, #tags do
			if tags[tag_index] == tag then
				return true
			end
		end
	else
		for tag_index = #tags, 1, -1 do
			if tags[tag_index] == tag then
				return true
			end 
		end
	end

	return false
end

-- gets the value of the specifed tag, returns nil if tag not found
function Tags.getValue(tags, tag, as_string)
	if type(tags) ~= "table" then
		d.print("(Tags.getValue) was expecting a table, but got a "..type(tags).." instead! searching for tag: "..tag.." (this can be safely ignored)", true, 1)
	end

	for k, v in pairs(tags) do
		if string.match(v, tag.."=") then
			if not as_string then
				return tonumber(tostring(string.gsub(v, tag.."=", "")))
			else
				return tostring(string.gsub(v, tag.."=", ""))
			end
		end
	end
	
	return nil
end
-- This library is for controlling or getting things about the Enemy AI.

-- required libraries

-- library name
AI = {}

--- @param vehicle_object vehicle_object the vehicle you want to set the state of
--- @param state string the state you want to set the vehicle to
--- @return boolean success if the state was set
function AI.setState(vehicle_object, state)
	if vehicle_object then
		if state ~= vehicle_object.state.s then
			if state == VEHICLE.STATE.HOLDING then
				vehicle_object.holding_target = vehicle_object.transform
			end
			vehicle_object.state.s = state
		end
	else
		d.print("(AI.setState) vehicle_object is nil!", true, 1)
	end
	return false
end

--# made for use with toggles in buttons (only use for toggle inputs to seats)
---@param vehicle_id integer the vehicle's id that has the seat you want to set
---@param seat_name string the name of the seat you want to set
---@param axis_ws number w/s axis
---@param axis_ad number a/d axis
---@param axis_ud number up down axis
---@param axis_lr number left right axis
---@param ... boolean buttons (1-7) (7 is trigger)
---@return boolean set_seat if the seat was set
function AI.setSeat(vehicle_id, seat_name, axis_ws, axis_ad, axis_ud, axis_lr, ...)
	
	if not vehicle_id then
		d.print("(AI.setSeat) vehicle_id is nil!", true, 1)
		return false
	end

	if not seat_name then
		d.print("(AI.setSeat) seat_name is nil!", true, 1)
		return false
	end

	local button = table.pack(...)

	-- sets any nil values to 0 or false
	axis_ws = axis_ws or 0
	axis_ad = axis_ad or 0
	axis_ud = axis_ud or 0
	axis_lr = axis_lr or 0

	for i = 1, 7 do
		button[i] = button[i] or false
	end

	g_savedata.seat_states = g_savedata.seat_states or {}


	if not g_savedata.seat_states[vehicle_id] or not g_savedata.seat_states[vehicle_id][seat_name] then

		g_savedata.seat_states[vehicle_id] = g_savedata.seat_states[vehicle_id] or {}
		g_savedata.seat_states[vehicle_id][seat_name] = {}

		for i = 1, 7 do
			g_savedata.seat_states[vehicle_id][seat_name][i] = false
		end
	end

	for i = 1, 7 do
		if button[i] ~= g_savedata.seat_states[vehicle_id][seat_name][i] then
			g_savedata.seat_states[vehicle_id][seat_name][i] = button[i]
			button[i] = true
		else
			button[i] = false
		end
	end

	s.setVehicleSeat(vehicle_id, seat_name, axis_ws, axis_ad, axis_ud, axis_lr, button[1], button[2], button[3], button[4], button[5], button[6], button[7])
	return true
end


--require("libraries.icm.spawnModifiers")

-- library name
Pathfinding = {}

-- shortened library name
p = Pathfinding

--[[


	Variables
   

]]

s = s or server

--[[


	Classes


]]

---@class ICMPathfindPoint
---@field x number the x coordinate of the graph node
---@field y number the y coordinate of the graph node
---@field z number the z coordinate of the graph node

--[[


	Functions         


]]

function Pathfinding.resetPath(vehicle_object)
	for _, v in pairs(vehicle_object.path) do
		server.removeMapID(-1, v.ui_id)
	end

	vehicle_object.path = {}
end

-- makes the vehicle go to its next path
---@param vehicle_object vehicle_object the vehicle object which is going to its next path
---@return number|nil more_paths the number of paths left, nil if error
---@return boolean is_success if it successfully went to the next path
function Pathfinding.nextPath(vehicle_object)

	--? makes sure vehicle_object is not nil
	if not vehicle_object then
		d.print("(Vehicle.nextPath) vehicle_object is nil!", true, 1)
		return nil, false
	end

	--? makes sure the vehicle_object has paths
	if not vehicle_object.path then
		d.print("(Vehicle.nextPath) vehicle_object.path is nil! vehicle_id: "..tostring(vehicle_object.id), true, 1)
		return nil, false
	end

	if vehicle_object.path[1] then
		if vehicle_object.path[0] then
			server.removeMapID(-1, vehicle_object.path[0].ui_id)
		end
		vehicle_object.path[0] = {
			x = vehicle_object.path[1].x,
			y = vehicle_object.path[1].y,
			z = vehicle_object.path[1].z,
			ui_id = vehicle_object.path[1].ui_id
		}
		table.remove(vehicle_object.path, 1)
	end

	return #vehicle_object.path, true
end

---@param vehicle_object vehicle_object the vehicle you want to add the path for
---@param target_dest SWMatrix the destination for the path
---@param translate_forward_distance number? the increment of the distance, used to slowly try moving the vehicle's matrix forwards, if its at a tile's boundery, and its unable to move, used by the function itself, leave undefined.
function Pathfinding.addPath(vehicle_object, target_dest, translate_forward_distance)

	-- path tags to exclude
	local exclude = ""

	if g_savedata.info.mods.NSO then
		exclude = "not_NSO" -- exclude non NSO graph nodes
	else
		exclude = "NSO" -- exclude NSO graph nodes
	end

	if vehicle_object.vehicle_type == VEHICLE.TYPE.TURRET then 
		AI.setState(vehicle_object, VEHICLE.STATE.STATIONARY)
		return

	elseif vehicle_object.vehicle_type == VEHICLE.TYPE.BOAT then
		local dest_x, dest_y, dest_z = matrix.position(target_dest)

		local path_start_pos = nil

		if #vehicle_object.path > 0 then
			local waypoint_end = vehicle_object.path[#vehicle_object.path]
			path_start_pos = matrix.translation(waypoint_end.x, waypoint_end.y, waypoint_end.z)
		else
			path_start_pos = vehicle_object.transform
		end

		-- makes sure only small ships can take the tight areas
		
		if vehicle_object.size ~= "small" then
			exclude = exclude..",tight_area"
		end

		-- calculates route
		local path_list = server.pathfind(path_start_pos, matrix.translation(target_dest[13], 0, target_dest[15]), "ocean_path", exclude)

		for _, path in pairs(path_list) do
			if not path.y then
				path.y = 0
			end
			if path.y > 1 then
				break
			end 
			table.insert(vehicle_object.path, { 
				x = path.x,
				y = path.y,
				z = path.z,
				ui_id = server.getMapID() 
			})
		end
	elseif vehicle_object.vehicle_type == VEHICLE.TYPE.LAND then
		--local dest_x, dest_y, dest_z = m.position(target_dest)

		local path_start_pos = nil

		if #vehicle_object.path > 0 then
			local waypoint_end = vehicle_object.path[#vehicle_object.path]

			if translate_forward_distance then
				local second_last_path_pos
				if #vehicle_object.path < 2 then
					second_last_path_pos = vehicle_object.transform
				else
					local second_last_path = vehicle_object.path[#vehicle_object.path - 1]
					second_last_path_pos = matrix.translation(second_last_path.x, second_last_path.y, second_last_path.z)
				end

				local yaw, _ = math.angleToFace(second_last_path_pos[13], waypoint_end.x, second_last_path_pos[15], waypoint_end.z)

				path_start_pos = matrix.translation(waypoint_end.x + translate_forward_distance * math.sin(yaw), waypoint_end.y, waypoint_end.z + translate_forward_distance * math.cos(yaw))
			
				--[[server.addMapLine(-1, vehicle_object.ui_id, m.translation(waypoint_end.x, waypoint_end.y, waypoint_end.z), path_start_pos, 1, 255, 255, 255, 255)
			
				d.print("path_start_pos (existing paths)", false, 0)
				d.print(path_start_pos)]]
			else
				path_start_pos = matrix.translation(waypoint_end.x, waypoint_end.y, waypoint_end.z)
			end
		else
			path_start_pos = vehicle_object.transform

			if translate_forward_distance then
				path_start_pos = matrix.multiply(vehicle_object.transform, matrix.translation(0, 0, translate_forward_distance))
				--[[server.addMapLine(-1, vehicle_object.ui_id, vehicle_object.transform, path_start_pos, 1, 150, 150, 150, 255)
				d.print("path_start_pos (no existing paths)", false, 0)
				d.print(path_start_pos)]]
			else
				path_start_pos = vehicle_object.transform
			end
		end

		start_x, start_y, start_z = m.position(vehicle_object.transform)

		local exclude_offroad = false

		local squad_index, squad = Squad.getSquad(vehicle_object.id)
		if squad.command == SQUAD.COMMAND.CARGO then
			for c_vehicle_id, c_vehicle_object in pairs(squad.vehicles) do
				if g_savedata.cargo_vehicles[c_vehicle_id] then
					exclude_offroad = not g_savedata.cargo_vehicles[c_vehicle_id].route_data.can_offroad
					break
				end
			end
		end

		if not vehicle_object.can_offroad or exclude_offroad then
			exclude = exclude..",offroad"
		end

		local vehicle_list_id = sm.getVehicleListID(vehicle_object.name)
		local y_modifier = g_savedata.vehicle_list[vehicle_list_id].vehicle.transform[14]

		local dest_at_vehicle_y = matrix.translation(target_dest[13], vehicle_object.transform[14], target_dest[15])

		local path_list = server.pathfind(path_start_pos, dest_at_vehicle_y, "land_path", exclude)
		for path_index, path in pairs(path_list) do

			local path_matrix = matrix.translation(path.x, path.y, path.z)

			local distance = matrix.distance(vehicle_object.transform, path_matrix)

			if path_index ~= 1 or #path_list == 1 or matrix.distance(vehicle_object.transform, dest_at_vehicle_y) > matrix.distance(dest_at_vehicle_y, path_matrix) and distance >= 7 then
				
				if not path.y then
					--d.print("not path.y\npath.x: "..tostring(path.x).."\npath.y: "..tostring(path.y).."\npath.z: "..tostring(path.z), true, 1)
					break
				end

				table.insert(vehicle_object.path, { 
					x =  path.x, 
					y = (path.y + y_modifier), 
					z = path.z, 
					ui_id = server.getMapID() 
				})
			end
		end

		if #vehicle_object.path > 1 then
			-- remove paths which are a waste (eg, makes the vehicle needlessly go backwards when it could just go to the next waypoint)
			local next_path_matrix = matrix.translation(vehicle_object.path[2].x, vehicle_object.path[2].y, vehicle_object.path[2].z)
			if matrix.xzDistance(vehicle_object.transform, next_path_matrix) < matrix.xzDistance(matrix.translation(vehicle_object.path[1].x, vehicle_object.path[1].y, vehicle_object.path[1].z), next_path_matrix) then
				p.nextPath(vehicle_object)
			end
		end

		--[[
			checks if the vehicle is basically stuck, and if its at a tile border, if it is, 
			try moving matrix forwards slightly, and keep trying till we've got a path, 
			or until we reach a set max distance, to avoid infinite recursion.
		]]

		local max_attempt_distance = 30
		local max_attempt_increment = 5

		translate_forward_distance = translate_forward_distance or 0

		if translate_forward_distance < max_attempt_distance then
			local last_path = vehicle_object.path[#vehicle_object.path]

			-- if theres no last path, just set it as the vehicle's positon.
			if not last_path then
				last_path = {
					x = vehicle_object.transform[13],
					z = vehicle_object.transform[15]
				}
			end

			-- checks if we're within the max_attempt_distance of any tile border
			local tile_x_border_distance = math.abs((last_path.x-250)%1000-250)
			local tile_z_border_distance = math.abs((last_path.z-250)%1000-250)

			if tile_x_border_distance <= max_attempt_distance or tile_z_border_distance <= max_attempt_distance then
				-- increments the translate_forward_distance
				translate_forward_distance = translate_forward_distance + max_attempt_increment

				d.print(("(Pathfinding.addPath) moving the pathfinding start pos forwards by %sm"):format(translate_forward_distance), true, 0)

				Pathfinding.addPath(vehicle_object, target_dest, translate_forward_distance)
			end
		else
			d.print(("(Pathfinding.addPath) despite moving the pathfinding start pos forward by %sm, pathfinding still failed for vehicle with id %s, aborting to avoid infinite recursion"):format(translate_forward_distance, vehicle_object.id), true, 0)
		end
	else
		table.insert(vehicle_object.path, { 
			x = target_dest[13], 
			y = target_dest[14], 
			z = target_dest[15], 
			ui_id = s.getMapID() 
		})
	end
	vehicle_object.path[0] = {
		x = vehicle_object.transform[13],
		y = vehicle_object.transform[14],
		z = vehicle_object.transform[15],
		ui_id = s.getMapID()
	}

	AI.setState(vehicle_object, VEHICLE.STATE.PATHING)
end

-- Credit to woe
function Pathfinding.updatePathfinding()
	local old_pathfind = server.pathfind --temporarily remember what the old function did
	local old_pathfindOcean = server.pathfindOcean
	function server.pathfind(matrix_start, matrix_end, required_tags, avoided_tags) --permanantly do this new function using the old name.
		local path = old_pathfind(matrix_start, matrix_end, required_tags, avoided_tags) --do the normal old function
		--d.print("(updatePathfinding) getting path y", true, 0)
		return p.getPathY(path) --add y to all of the paths.
	end
	function server.pathfindOcean(matrix_start, matrix_end)
		local path = old_pathfindOcean(matrix_start, matrix_end)
		return p.getPathY(path)
	end
end

local path_res = "%0.1f"

-- Credit to woe
function Pathfinding.getPathY(path)
	if not g_savedata.graph_nodes.init then --if it has never built the node's table
		p.createPathY() --build the table this one time
		g_savedata.graph_nodes.init = true --never build the table again unless you run traverse() manually
	end
	for each in pairs(path) do
		if g_savedata.graph_nodes.nodes[(path_res):format(path[each].x)] and g_savedata.graph_nodes.nodes[(path_res):format(path[each].x)][(path_res):format(path[each].z)] then --if y exists
			path[each].y = g_savedata.graph_nodes.nodes[(path_res):format(path[each].x)][(path_res):format(path[each].z)].y --add it to the table that already contains x and z
			--d.print("path["..each.."].y: "..tostring(path[each].y), true, 0)
		end
	end
	return path --return the path with the added, or not, y values.
end

-- Credit to woe
function Pathfinding.createPathY() --this looks through all env mods to see if there is a "zone" then makes a table of y values based on x and z as keys.

	local isGraphNode = function(tag)
		if tag == "land_path" or tag == "ocean_path" then
			return tag
		end
		return false
	end

	-- indexed by name, this is so we dont have to constantly call server.getTileTransform for the same tiles. 
	local tile_locations = {}

	local start_time = s.getTimeMillisec()
	d.print("Creating Path Y...", true, 0)
	local total_paths = 0
	local empty_matrix = matrix.translation(0, 0, 0)
	for addon_index = 0, s.getAddonCount() - 1 do
		local ADDON_DATA = s.getAddonData(addon_index)
		if ADDON_DATA.location_count and ADDON_DATA.location_count > 0 then
			for location_index = 0, ADDON_DATA.location_count - 1 do
				local LOCATION_DATA = s.getLocationData(addon_index, location_index)
				if LOCATION_DATA.env_mod and LOCATION_DATA.component_count > 0 then
					for component_index = 0, LOCATION_DATA.component_count - 1 do
						local COMPONENT_DATA = s.getLocationComponentData(
							addon_index, location_index, component_index
						)
						if COMPONENT_DATA.type == "zone" then
							local graph_node = isGraphNode(COMPONENT_DATA.tags[1])
							if graph_node then

								local transform_matrix = tile_locations[LOCATION_DATA.tile]
								if not transform_matrix then
									tile_locations[LOCATION_DATA.tile] = s.getTileTransform(
										empty_matrix,
										LOCATION_DATA.tile,
										100000
									)

									transform_matrix = tile_locations[LOCATION_DATA.tile]
								end

								if transform_matrix then
									local real_transform = matrix.multiplyXZ(COMPONENT_DATA.transform, transform_matrix)
									local x = (path_res):format(real_transform[13])
									local last_tag = COMPONENT_DATA.tags[#COMPONENT_DATA.tags]
									g_savedata.graph_nodes.nodes[x] = g_savedata.graph_nodes.nodes[x] or {}
									g_savedata.graph_nodes.nodes[x][(path_res):format(real_transform[15])] = { 
										y = real_transform[14],
										type = graph_node,
										NSO = last_tag == "NSO" and 1 or last_tag == "not_NSO" and 2 or 0
									}
									total_paths = total_paths + 1
								end
							end
						end
					end
				end
			end
		end
	end
	d.print("Got Y level of all paths\nNumber of nodes: "..total_paths.."\nTime taken: "..(millisecondsSince(start_time)/1000).."s", true, 0)
end
 -- functions for pathfinding -- functions relating to Players -- functions for script/world setup.
-- required libraries

-- library name
SpawningUtils = {}

-- shortened library name
su = SpawningUtils

-- spawn an individual object descriptor from a playlist location
function SpawningUtils.spawnObjectType(spawn_transform, location_index, object_descriptor, parent_vehicle_id)
	local component, is_success = s.spawnAddonComponent(spawn_transform, s.getAddonIndex(), location_index, object_descriptor.index, parent_vehicle_id)
	if is_success then
		return component.id
	else -- then it failed to spawn the addon component
		d.print("(Improved Missions and AI) Please send this debug info to the discord server:\ncomponent: "..component.."\naddon_index: "..s.getAddonIndex().."\nlocation index: "..location_index, false, 1)
		return nil
	end
end

function SpawningUtils.spawnObject(spawn_transform, location_index, object, parent_vehicle_id, spawned_objects, out_spawned_objects)
	-- spawn object

	local spawned_object_id = su.spawnObjectType(m.multiply(spawn_transform, object.transform), location_index, object, parent_vehicle_id)

	-- add object to spawned object tables

	if spawned_object_id ~= nil and spawned_object_id ~= 0 then

		local l_vehicle_type = VEHICLE.TYPE.HELI
		if Tags.has(object.tags, "vehicle_type=ai_plane") then
			l_vehicle_type = VEHICLE.TYPE.PLANE
		elseif Tags.has(object.tags, "vehicle_type=ai_boat") then
			l_vehicle_type = VEHICLE.TYPE.BOAT
		end
		if Tags.has(object.tags, "vehicle_type=ai_land") then
			l_vehicle_type = VEHICLE.TYPE.LAND
		end
		if Tags.has(object.tags, "vehicle_type=wep_turret") then
			l_vehicle_type = VEHICLE.TYPE.TURRET
		end
		if Tags.has(object.tags, "type=dlc_weapons_flag") then
			l_vehicle_type = "flag"
		end

		local l_size = "small"
		for tag_index, tag_object in pairs(object.tags) do
			if string.find(tag_object, "size=") ~= nil then
				l_size = string.sub(tag_object, 6)
			end
		end

		local object_data = { name = object.display_name, type = object.type, id = spawned_object_id, component_id = object.id, vehicle_type = l_vehicle_type, size = l_size }

		if spawned_objects ~= nil then
			table.insert(spawned_objects, object_data)
		end

		if out_spawned_objects ~= nil then
			table.insert(out_spawned_objects, object_data)
		end

		return object_data
	end

	return nil
end

function SpawningUtils.spawnObjects(spawn_transform, location_index, object_descriptors, out_spawned_objects)
	local spawned_objects = {}

	for _, object in pairs(object_descriptors) do
		-- find parent vehicle id if set

		local parent_vehicle_id = 0
		if object.vehicle_parent_component_id > 0 then
			for spawned_object_id, spawned_object in pairs(out_spawned_objects) do
				if spawned_object.type == "vehicle" and spawned_object.component_id == object.vehicle_parent_component_id then
					parent_vehicle_id = spawned_object.id
				end
			end
		end

		su.spawnObject(spawn_transform, location_index, object, parent_vehicle_id, spawned_objects, out_spawned_objects)
	end

	return spawned_objects
end
 -- functions used by the spawn vehicle function -- custom string functions -- custom table functions -- functions related to getting tags from components inside of mission and environment locations
-- library name
Ticks = {}

---@param start_ms number the time you want to see how long its been since (in ms)
---@return number ms_since how many ms its been since <start_ms>
function Ticks.millisecondsSince(start_ms)
	return s.getTimeMillisec() - start_ms
end
 -- functions related to ticks and time
-- required libraries

-- library name
Vehicle = {}

-- shortened library name
v = Vehicle

---@param vehicle_object vehicle_object the vehicle you want to get the speed of
---@param ignore_terrain_type boolean if false or nil, it will include the terrain type in speed, otherwise it will return the offroad speed (only applicable to land vehicles)
---@param ignore_aggressiveness boolean if false or nil, it will include the aggressiveness in speed, otherwise it will return the normal speed (only applicable to land vehicles)
---@param terrain_type_override string \"road" to override speed as always on road, "offroad" to override speed as always offroad, "bridge" to override the speed always on a bridge (only applicable to land vehicles)
---@param aggressiveness_override string \"normal" to override the speed as always normal, "aggressive" to override the speed as always aggressive (only applicable to land vehicles)
---@return number speed the speed of the vehicle, 0 if not found
---@return boolean got_speed if the speed was found
function Vehicle.getSpeed(vehicle_object, ignore_terrain_type, ignore_aggressiveness, terrain_type_override, aggressiveness_override, ignore_convoy_modifier)
	if not vehicle_object then
		d.print("(Vehicle.getSpeed) vehicle_object is nil!", true, 1)
		return 0, false
	end

	local squad_index, squad = Squad.getSquad(vehicle_object.id)

	if not squad then
		d.print("(Vehicle.getSpeed) squad is nil! vehicle_id: "..tostring(vehicle_object.id), true, 1)
		return 0, false
	end

	local speed = 0

	local ignore_me = false

	if squad.command == SQUAD.COMMAND.CARGO then
		-- return the slowest vehicle in the chain's speed
		for vehicle_index, _ in pairs(squad.vehicles) do
			if g_savedata.cargo_vehicles[vehicle_index] and g_savedata.cargo_vehicles[vehicle_index].route_status == 1 then
				speed = g_savedata.cargo_vehicles[vehicle_index].path_data.speed or 0
				if speed ~= 0 and not ignore_convoy_modifier then
					speed = speed + (vehicle_object.speed.convoy_modifier or 0)
					ignore_me = true
				end
			end
		end
	end

	if speed == 0 and not ignore_me then
		speed = vehicle_object.speed.speed

		if vehicle_object.vehicle_type == VEHICLE.TYPE.LAND then
			-- land vehicle
			local terrain_type = v.getTerrainType(vehicle_object.transform)
			local aggressive = agressiveness_override or not ignore_aggressiveness and vehicle_object.is_aggressive or false
			if aggressive then
				speed = speed * VEHICLE.SPEED.MULTIPLIERS.LAND.AGGRESSIVE
			else
				speed = speed * VEHICLE.SPEED.MULTIPLIERS.LAND.NORMAL
			end

			speed = speed * VEHICLE.SPEED.MULTIPLIERS.LAND[string.upper(terrain_type)]
		end
	end

	return speed, true
end

---@param transform SWMatrix the transform of where you want to check
---@return string terrain_type the terrain type the transform is on
---@return boolean found_terrain_type if the terrain type was found
function Vehicle.getTerrainType(transform)
	local found_terrain_type = false
	local terrain_type = "offroad"
	
	if transform then
		-- prefer returning bridge, then road, then offroad
		if s.isInZone(transform, "land_ai_bridge") then
			terrain_type = "bridge"
		elseif s.isInZone(transform, "land_ai_road") then
			terrain_type = "road"
		end
	else
		d.print("(Vehicle.getTerrainType) vehicle_object is nil!", true, 1)
	end

	return terrain_type, found_terrain_type
end

---@param vehicle_id integer the id of the vehicle
---@return prefab prefab the prefab of the vehicle if it was created
---@return boolean was_created if the prefab was created
function Vehicle.createPrefab(vehicle_id)
	if not vehicle_id then
		d.print("(Vehicle.createPrefab) vehicle_id is nil!", true, 1)
		return nil, false
	end

	local vehicle_data, got_vehicle_data = s.getVehicleData(vehicle_id)

	if not got_vehicle_data then
		d.print("(Vehicle.createPrefab) failed to get vehicle data! vehicle_id: "..tostring(vehicle_id), true, 1)
		return nil, false
	end

	local vehicle_object, squad, squad_index = Squad.getVehicle(vehicle_id)

	if not vehicle_object then
		d.print("(Vehicle.createPrefab) failed to get vehicle_object! vehicle_id: "..tostring(vehicle_id), true, 1)
		return nil, false
	end

	---@class prefab
	local prefab = {
		voxels = vehicle_data.voxels,
		mass = vehicle_data.mass,
		powertrain_types = v.getPowertrainTypes(vehicle_object),
		role = vehicle_object.role,
		vehicle_type = vehicle_object.vehicle_type,
		strategy = vehicle_object.strategy,
		fully_created = (vehicle_data.mass ~= 0) -- requires to be loaded
	}

	g_savedata.prefabs[string.removePrefix(vehicle_object.name)] = prefab

	return prefab, true
end

---@param vehicle_name string the name of the vehicle
---@return prefab prefab the prefab data of the vehicle
---@return got_prefab boolean if the prefab data was found
function Vehicle.getPrefab(vehicle_name)
	if not vehicle_name then
		d.print("(Vehicle.getPrefab) vehicle_name is nil!", true, 1)
		return nil, false
	end

	vehicle_name = string.removePrefix(vehicle_name)

	if not g_savedata.prefabs[vehicle_name] then
		return nil, false
	end

	return g_savedata.prefabs[vehicle_name], true
end

---@param vehicle_object vehicle_object the vehicle_object of the vehicle you want to get the powertrain type of
---@return powertrain_types powertrain_types the powertrain type(s) of the vehicle
---@return boolean got_powertrain_type if the powertrain type was found
function Vehicle.getPowertrainTypes(vehicle_object)

	if not vehicle_object then
		d.print("(Vehicle.getPowertrainType) vehicle_object is nil!", true, 1)
		return nil, false
	end

	local vehicle_data, got_vehicle_data = s.getVehicleData(vehicle_object.id)

	if not got_vehicle_data then
		d.print("(Vehicle.getPowertrainType) failed to get vehicle data! name: "..tostring(vehicle_object.name).."\nid: "..tostring(vehicle_object.id), true, 1)
		return nil, false
	end

	local _, is_jet = s.getVehicleTank(vehicle_object.id, "Jet 1")

	local _, is_diesel = s.getVehicleTank(vehicle_object.id, "Diesel 1")

	---@class powertrain_types
	local powertrain_types = {
		jet_fuel = is_jet,
		diesel = is_diesel,
		electric = (not is_jet and not is_diesel)
	}

	return powertrain_types, true	
end

--# decides where to spawn a vehicle
---@param vehicle_type string the type of the vehicle to spawn
--function Vehicle.decideVehicleSpawn(vehicle_type)
	


--# decides which vehicle to spawn
---@return string vehicle_type the vehicle type to spawn
--function Vehicle.typeToSpawn()
	

--# spawns an AI vehicle, set arguments to nil to be completely random.
---@param spawn_matrix ?SWMatrix the position you want the vehicle to spawn at
---@param vehicle_type ?string the vehicle type, eg: "boat"
---@param vehicle_name ?string the name of the vehicle
--function Vehicle.spawn(spawn_matrix, vehicle_type, vehicle_name)

---@param requested_prefab any vehicle name or vehicle role, such as scout, will try to spawn that vehicle or type
---@param vehicle_type string the vehicle type you want to spawn, such as boat, leave nil to ignore
---@param force_spawn boolean if you want to force it to spawn, it will spawn at the ai's main base
---@param specified_island island[] the island you want it to spawn at
---@param purchase_type integer 0 for dont buy, 1 for free (cost will be 0 no matter what), 2 for free but it has lower stats, 3 for spend as much as you can but the less spent will result in lower stats. 
---@return boolean spawned_vehicle if the vehicle successfully spawned or not
---@return vehicle_object vehicle_object the vehicle's data if the the vehicle successfully spawned, otherwise its returns the error code
function Vehicle.spawn(requested_prefab, vehicle_type, force_spawn, specified_island, purchase_type)
	local plane_count = 0
	local heli_count = 0
	local army_count = 0
	local land_count = 0
	local boat_count = 0

	if not g_savedata.settings.CARGO_MODE or not purchase_type then
		-- buy the vehicle for free
		purchase_type = 1
	end
	
	for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
		for vehicle_id, vehicle_object in pairs(squad.vehicles) do
			if vehicle_object.vehicle_type ~= VEHICLE.TYPE.TURRET then army_count = army_count + 1 end
			if vehicle_object.vehicle_type == VEHICLE.TYPE.PLANE then plane_count = plane_count + 1 end
			if vehicle_object.vehicle_type == VEHICLE.TYPE.HELI then heli_count = heli_count + 1 end
			if vehicle_object.vehicle_type == VEHICLE.TYPE.LAND then land_count = land_count + 1 end
			if vehicle_object.vehicle_type == VEHICLE.TYPE.BOAT then boat_count = boat_count + 1 end
		end
	end

	if vehicle_type == "helicopter" then
		vehicle_type = "heli"
	end
	
	local selected_prefab = nil

	local spawnbox_index = nil -- turrets

	if vehicle_type == "turret" and specified_island then

		-----
		--* turret spawning
		-----

		local island = specified_island

		-- make sure theres turret spawns on this island
		if (#island.zones.turrets < 1) then
			return false, "theres no turret zones on this island!\nisland: "..island.name 
		end

		local turret_count = 0
		local unoccupied_zones = {}

		-- count the amount of turrets this island has spawned
		for turret_zone_index = 1, #island.zones.turrets do
			if island.zones.turrets[turret_zone_index].is_spawned then 
				turret_count = turret_count + 1

				-- check if this island already hit the maximum for the amount of turrets
				if turret_count >= g_savedata.settings.MAX_TURRET_AMOUNT then 
					return false, "hit turret limit for this island" 
				end

				-- check if this island already has all of the turret spawns filled
				if turret_count >= #island.zones.turrets then
					return false, "the island already has all turret spawns occupied"
				end
			else
				-- add the zone to a list to be picked from for spawning the next turret
				table.insert(unoccupied_zones, turret_zone_index)
			end
		end

		-- d.print("turret count: "..turret_count, true, 0)

		-- pick a spawn point out of the list which is unoccupied
		spawnbox_index = unoccupied_zones[math.random(1, #unoccupied_zones)]

		-- make sure theres no players nearby this turret spawn
		local player_list = s.getPlayers()
		if not force_spawn and not pl.noneNearby(player_list, island.zones.turrets[spawnbox_index].transform, 2500, true) then -- makes sure players are not too close before spawning a turret
			return false, "players are too close to the turret spawn point!"
		end

		selected_prefab = sm.spawn(true, Tags.getValue(island.zones.turrets[spawnbox_index].tags, "turret_type", true), "turret")

		if not selected_prefab then
			return false, "was unable to get a turret prefab! turret_type of turret spawn zone: "..tostring(Tags.getValue(island.zones.turrets[spawnbox_index].tags, "turret_type", true))
		end

	elseif requested_prefab then
		-- *spawning specified vehicle
		selected_prefab = sm.spawn(true, requested_prefab, vehicle_type) 
	else
		-- *spawn random vehicle
		selected_prefab = sm.spawn(false, requested_prefab, vehicle_type)
	end

	if not selected_prefab then
		d.print("(Vehicle.spawn) Unable to spawn AI vehicle! (prefab not recieved)", true, 1)
		return false, "returned vehicle was nil, prefab "..(requested_prefab and "was" or "was not").." selected"
	end

	d.print("(Vehicle.spawn) selected vehicle: "..selected_prefab.location.data.name, true, 0)

	if not requested_prefab then
		if Tags.has(selected_prefab.vehicle.tags, "vehicle_type=wep_boat") and boat_count >= g_savedata.settings.MAX_BOAT_AMOUNT then
			return false, "boat limit reached"
		elseif Tags.has(selected_prefab.vehicle.tags, "vehicle_type=wep_land") and land_count >= g_savedata.settings.MAX_LAND_AMOUNT then
			return false, "land limit reached"
		elseif Tags.has(selected_prefab.vehicle.tags, "vehicle_type=wep_heli") and heli_count >= g_savedata.settings.MAX_HELI_AMOUNT then
			return false, "heli limit reached"
		elseif Tags.has(selected_prefab.vehicle.tags, "vehicle_type=wep_plane") and plane_count >= g_savedata.settings.MAX_PLANE_AMOUNT then
			return false, "plane limit reached"
		end
		if army_count > g_savedata.settings.MAX_BOAT_AMOUNT + g_savedata.settings.MAX_LAND_AMOUNT + g_savedata.settings.MAX_HELI_AMOUNT + g_savedata.settings.MAX_PLANE_AMOUNT then
			return false, "AI hit vehicle limit!"
		end
	end

	local player_list = s.getPlayers()

	local selected_spawn = 0
	local selected_spawn_transform = g_savedata.ai_base_island.transform

	-------
	-- get spawn location
	-------

	local min_player_dist = 2500

	d.print("(Vehicle.spawn) Getting island to spawn vehicle at...", true, 0)

	if not specified_island then
		-- if the vehicle we want to spawn is an attack vehicle, we want to spawn it as close to their objective as possible
		if Tags.getValue(selected_prefab.vehicle.tags, "role", true) == "attack" or Tags.getValue(selected_prefab.vehicle.tags, "role", true) == "scout" then
			target, ally = Objective.getIslandToAttack()
			if not target then
				sm.train(PUNISH, attack, 5) -- we can no longer spawn attack vehicles
				sm.train(PUNISH, attack, 5)
				v.spawn(nil, nil, nil, nil, purchase_type)
				return false, "no islands to attack! cancelling spawning of attack vehicle"
			end
			for island_index, island in pairs(g_savedata.islands) do
				if is.canSpawn(island, selected_prefab) and (selected_spawn_transform == nil or m.xzDistance(target.transform, island.transform) < m.xzDistance(target.transform, selected_spawn_transform)) then
					selected_spawn_transform = island.transform
					selected_spawn = island_index
				end
			end
		-- (A) if the vehicle we want to spawn is a defensive vehicle, we want to spawn it on the island that has the least amount of defence
		-- (B) if theres multiple, pick the island we saw the player closest to
		-- (C) if none, then spawn it at the island which is closest to the player's island
		elseif Tags.getValue(selected_prefab.vehicle.tags, "role", true) == "defend" then
			local lowest_defenders = nil
			local check_last_seen = false
			local islands_needing_checked = {}

			for island_index, island in pairs(g_savedata.islands) do
				if is.canSpawn(island, selected_prefab) then
					if not lowest_defenders or island.defenders < lowest_defenders then -- choose the island with the least amount of defence (A)
						lowest_defenders = island.defenders -- set the new lowest defender amount on an island
						selected_spawn_transform = island.transform
						selected_spawn = island_index
						check_last_seen = false -- say that we dont need to do a tie breaker
						islands_needing_checked = {}
					elseif lowest_defenders == island.defenders then -- if two islands have the same amount of defenders
						islands_needing_checked[selected_spawn] = selected_spawn_transform
						islands_needing_checked[island_index] = island.transform
						check_last_seen = true -- we need a tie breaker
					end
				end
			end

			if check_last_seen then -- do a tie breaker (B)
				local closest_player_pos = nil
				for player_steam_id, player_transform in pairs(g_savedata.ai_knowledge.last_seen_positions) do
					for island_index, island_transform in pairs(islands_needing_checked) do
						local player_to_island_dist = m.xzDistance(player_transform, island_transform)
						if not closest_player_pos or player_to_island_dist < closest_player_pos then
							closest_player_pos = player_to_island_dist
							selected_spawn_transform = island_transform
							selected_spawn = island_index
						end
					end
				end

				if not closest_player_pos then -- if no players were seen this game, spawn closest to the closest player island (C)
					for island_index, island_transform in pairs(islands_needing_checked) do
						for player_island_index, player_island in pairs(g_savedata.islands) do
							if player_island.faction == ISLAND.FACTION.PLAYER then
								if m.xzDistance(player_island.transform, selected_spawn_transform) > m.xzDistance(player_island.transform, island_transform) then
									selected_spawn_transform = island_transform
									selected_spawn = island_index
								end
							end
						end
					end
				end
			end
		-- spawn it at a random ai island
		else
			local valid_islands = {}
			local valid_island_index = {}
			for island_index, island in pairs(g_savedata.islands) do
				if is.canSpawn(island, selected_prefab) then
					table.insert(valid_islands, island)
					table.insert(valid_island_index, island_index)
				end
			end
			if #valid_islands > 0 then
				random_island = math.random(1, #valid_islands)
				selected_spawn_transform = valid_islands[random_island].transform
				selected_spawn = valid_island_index[random_island]
			end
		end
	else
		-- if they specified the island they want it to spawn at
		if not force_spawn then
			-- if they did not force the vehicle to spawn
			if is.canSpawn(specified_island, selected_prefab) then
				selected_spawn_transform = specified_island.transform
				selected_spawn = specified_island.index
			end
		else
			--d.print("forcing vehicle to spawn at "..specified_island.index, true, 0)
			-- if they forced the vehicle to spawn
			selected_spawn_transform = specified_island.transform
			selected_spawn = specified_island.index
		end
	end

	-- try spawning at the ai's main base if it was unable to find a valid spawn
	if not g_savedata.islands[selected_spawn] and g_savedata.ai_base_island.index ~= selected_spawn then
		if force_spawn or pl.noneNearby(player_list, g_savedata.ai_base_island.transform, min_player_dist, true) then -- makes sure no player is within min_player_dist
			-- if it can spawn at the ai's main base, or the vehicle is being forcibly spawned and its not a land vehicle
			if Tags.has(g_savedata.ai_base_island.tags, "can_spawn="..string.gsub(Tags.getValue(selected_prefab.vehicle.tags, "vehicle_type", true), "wep_", "")) or force_spawn and Tags.getValue(selected_prefab.vehicle.tags, "vehicle_type", true) ~= "wep_land" then
				selected_spawn_transform = g_savedata.ai_base_island.transform
				selected_spawn = g_savedata.ai_base_island.index
			end
		end
	end

	-- if it still was unable to find a island to spawn at
	if not g_savedata.islands[selected_spawn] and selected_spawn ~= g_savedata.ai_base_island.index then
		if Tags.getValue(selected_prefab.vehicle.tags, "role", true) == "scout" then -- make the scout spawn at the ai's main base
			selected_spawn_transform = g_savedata.ai_base_island.transform
			selected_spawn = g_savedata.ai_base_island.index
		else
			d.print("(Vehicle.spawn) was unable to find island to spawn at!\nIsland Index: "..selected_spawn.."\nVehicle Type: "..string.gsub(Tags.getValue(selected_prefab.vehicle.tags, "vehicle_type", true), "wep_", "").."\nVehicle Role: "..Tags.getValue(selected_prefab.vehicle.tags, "role", true), true, 1)
			return false, "was unable to find island to spawn at"
		end
	end

	local island = g_savedata.ai_base_island.index == selected_spawn and g_savedata.ai_base_island or g_savedata.islands[selected_spawn]

	if not island then
		d.print(("(Vehicle.spawn) no island found with the selected spawn of: %s. \nVehicle type: %s Vehicle role: %s"):format(tostring(selected_spawn), string.gsub(Tags.getValue(selected_prefab.vehicle.tags, "vehicle_type", true), "wep_", ""), Tags.getValue(selected_prefab.vehicle.tags, "role", true)), false, 1)
		return false, ("(Vehicle.spawn) no island found with the selected spawn of: %s. \nVehicle type: %s Vehicle role: %s"):format(tostring(selected_spawn), string.gsub(Tags.getValue(selected_prefab.vehicle.tags, "vehicle_type", true), "wep_", ""), Tags.getValue(selected_prefab.vehicle.tags, "role", true))
	end

	d.print("(Vehicle.spawn) island: "..island.name, true, 0)

	local spawn_transform = selected_spawn_transform
	if Tags.has(selected_prefab.vehicle.tags, "vehicle_type=wep_boat") then
		if not island then
			return false, "unable to find island to spawn sea vehicle at!"
		end
		if #island.zones.sea == 0 then
			d.print("(Vehicle.spawn) island has no sea spawn zones but says it can spawn sea vehicles! island_name: "..tostring(island.name), true, 1)
			return false, "island has no sea spawn zones"
		end

		spawn_transform = island.zones.sea[math.random(1, #island.zones.sea)].transform
	elseif Tags.has(selected_prefab.vehicle.tags, "vehicle_type=wep_land") then
		if #island.zones.land == 0 then
			d.print("(Vehicle.spawn) island has no land spawn zones but says it can spawn land vehicles! island_name: "..tostring(island.name), true, 1)
			return false, "island has no land spawn zones"
		end

		spawn_transform = island.zones.land[math.random(1, #island.zones.land)].transform
	elseif Tags.has(selected_prefab.vehicle.tags, "vehicle_type=wep_turret") then
		local turret_count = 0
		local unoccupied_zones = {}

		if #island.zones.turrets == 0 then
			d.print(("(v.spawn) Unable to spawn turret, Island %s has no turret spawn zones!"):format(island.name), true, 1)
			return false, ("Island %s has no turret spawn zones!"):format(island.name)
		end

		-- count the amount of turrets this island has spawned
		for turret_zone_index = 1, #island.zones.turrets do
			if island.zones.turrets[turret_zone_index].is_spawned then 
				turret_count = turret_count + 1

				-- check if this island already hit the maximum for the amount of turrets
				if turret_count >= g_savedata.settings.MAX_TURRET_AMOUNT then 
					return false, "hit turret limit for this island" 
				end

				-- check if this island already has all of the turret spawns filled
				if turret_count >= #island.zones.turrets then
					return false, "the island already has all turret spawns occupied"
				end
			elseif Tags.has(island.zones.turrets[turret_zone_index].tags, "turret_type="..Tags.getValue(selected_prefab.vehicle.tags, "role", true)) then
				-- add the zone to a list to be picked from for spawning the next turret
				table.insert(unoccupied_zones, turret_zone_index)
			end
		end

		if #unoccupied_zones == 0 then
			d.print(("(v.spawn) Unable to spawn turret, Island %s has no free turret spawn zones with the type of %s!"):format(island.name, Tags.getValue(selected_prefab.vehicle.tags, "role", true)), true, 1)
			return false, ("Island %s has no free turret spawn zones with the type of %s!"):format(island.name, Tags.getValue(selected_prefab.vehicle.tags, "role", true))
		end

		-- pick a spawn location out of the list which is unoccupied

		spawnbox_index = unoccupied_zones[math.random(1, #unoccupied_zones)]

		spawn_transform = island.zones.turrets[spawnbox_index].transform

	elseif Tags.has(selected_prefab.vehicle.tags, "vehicle_type=wep_plane") or Tags.has(selected_prefab.vehicle.tags, "vehicle_type=wep_heli") then
		spawn_transform = m.multiply(selected_spawn_transform, m.translation(math.random(-500, 500), CRUISE_HEIGHT + 400, math.random(-500, 500)))
	end

	-- check to make sure no vehicles are too close, as this could result in them spawning inside each other
	for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
		for vehicle_id, vehicle_object in pairs(squad.vehicles) do
			if m.distance(spawn_transform, vehicle_object.transform) < (Tags.getValue(selected_prefab.vehicle.tags, "spawning_distance") or DEFAULT_SPAWNING_DISTANCE + vehicle_object.spawning_transform.distance) then
				return false, "spawn location was too close to vehicle "..vehicle_id
			end
		end
	end

	d.print("(Vehicle.spawn) calculating cost of vehicle... (purchase type: "..tostring(purchase_type)..")", true, 0)
	-- check if we can afford the vehicle
	local cost, cost_existed, was_purchased, stats_multiplier = v.purchaseVehicle(string.removePrefix(selected_prefab.location.data.name), island.name, purchase_type, true)

	d.print("(Vehicle.spawn) cost: "..tostring(cost).." Purchase Type: "..purchase_type, true, 0)

	if not was_purchased then
		return false, "was unable to afford vehicle"
	end

	-- spawn objects
	local spawned_objects = {
		survivors = su.spawnObjects(spawn_transform, selected_prefab.location.location_index, selected_prefab.survivors, {}),
		fires = su.spawnObjects(spawn_transform, selected_prefab.location.location_index, selected_prefab.fires, {}),
		spawned_vehicle = su.spawnObject(spawn_transform, selected_prefab.location.location_index, selected_prefab.vehicle, 0, nil, {}),
	}

	d.print("(Vehicle.spawn) setting up enemy vehicle: "..selected_prefab.location.data.name, true, 0)

	if spawned_objects.spawned_vehicle ~= nil then
		local vehicle_survivors = {}
		for key, char in pairs(spawned_objects.survivors) do
			local c = s.getCharacterData(char.id)
			s.setCharacterData(char.id, c.hp, true, true)
			s.setAIState(char.id, 1)
			s.setAITargetVehicle(char.id, nil)
			table.insert(vehicle_survivors, char)
		end

		local home_x, home_y, home_z = m.position(spawn_transform)

		d.print("(Vehicle.spawn) setting vehicle data...", true, 0)
		--d.print("selected_spawn: "..selected_spawn, true, 0)

		---@class vehicle_object
		local vehicle_data = { 
			id = spawned_objects.spawned_vehicle.id,
			name = selected_prefab.location.data.name,
			home_island = g_savedata.islands[selected_spawn] or g_savedata.ai_base_island,
			survivors = vehicle_survivors, 
			path = { 
				[0] = {
					x = home_x, 
					y = home_y, 
					z = home_z
				} 
			},
			state = { 
				s = VEHICLE.STATE.HOLDING,
				timer = math.floor(math.fmod(spawned_objects.spawned_vehicle.id, 300 * stats_multiplier)),
				is_simulating = false,
				convoy = {
					status = CONVOY.MOVING,
					status_reason = "",
					time_changed = -1,
					ignore_wait = false,
					waiting_for = 0
				}
			},
			previous_squad = nil,
			ui_id = s.getMapID(),
			vehicle_type = spawned_objects.spawned_vehicle.vehicle_type,
			role = Tags.getValue(selected_prefab.vehicle.tags, "role", true) or "general",
			size = spawned_objects.spawned_vehicle.size or "small",
			main_body = Tags.getValue(selected_prefab.vehicle.tags, "main_body") or 0,
			holding_index = 1,
			holding_target = m.translation(home_x, home_y, home_z),
			spawnbox_index = spawnbox_index,
			costs = {
				buy_on_load = not cost_existed,
				purchase_type = purchase_type
			},
			vision = { 
				radius = Tags.getValue(selected_prefab.vehicle.tags, "visibility_range") or VISIBLE_DISTANCE,
				base_radius = Tags.getValue(selected_prefab.vehicle.tags, "visibility_range") or VISIBLE_DISTANCE,
				is_radar = Tags.has(selected_prefab.vehicle.tags, "radar"),
				is_sonar = Tags.has(selected_prefab.vehicle.tags, "sonar")
			},
			spawning_transform = {
				distance = Tags.getValue(selected_prefab.vehicle.tags, "spawning_distance") or DEFAULT_SPAWNING_DISTANCE
			},
			speed = {
				speed = Tags.getValue(selected_prefab.vehicle.tags, "speed") or 0 * stats_multiplier,
				convoy_modifier = 0
			},
			driving = { -- used for driving the vehicle itself, holds special data depending on the vehicle type
				ui_id = s.getMapID()
			},
			capabilities = {
				gps_target = Tags.has(selected_prefab.vehicle.tags, "GPS_TARGET_POSITION"), -- if it needs to have gps coords sent for where the player is
				gps_missile = Tags.has(selected_prefab.vehicle.tags, "GPS_MISSILE"), -- used to press a button to fire the missiles
				target_mass = Tags.has(selected_prefab.vehicle.tags, "TARGET_MASS") -- sends mass of targeted vehicle mass to the creation
			},
			cargo = {
				capacity = Tags.getValue(selected_prefab.vehicle.tags, "cargo_per_type") or 0,
				current = {
					oil = 0,
					diesel = 0,
					jet_fuel = 0
				}
			},
			is_aggressive = false,
			is_killed = false,
			just_strafed = true, -- used for fighter jet strafing
			strategy = Tags.getValue(selected_prefab.vehicle.tags, "strategy", true) or "general",
			can_offroad = Tags.has(selected_prefab.vehicle.tags, "can_offroad"),
			is_resupply_on_load = false,
			transform = spawn_transform,
			transform_history = {},
			target_vehicle_id = nil,
			target_player_id = nil,
			current_damage = 0,
			health = (Tags.getValue(selected_prefab.vehicle.tags, "health", false) or 1) * stats_multiplier,
			damage_dealt = {},
			fire_id = nil,
			object_type = "vehicle"
		}

		d.print("(Vehicle.spawn) set vehicle data", true, 0)

		if #spawned_objects.fires > 0 then
			vehicle_data.fire_id = spawned_objects.fires[1].id
		end

		local squad = addToSquadron(vehicle_data)
		if Tags.getValue(selected_prefab.vehicle.tags, "role", true) == "scout" then
			setSquadCommand(squad, SQUAD.COMMAND.SCOUT)
		elseif Tags.getValue(selected_prefab.vehicle.tags, "vehicle_type", true) == "wep_turret" then
			setSquadCommand(squad, SQUAD.COMMAND.TURRET)

			-- set the zone it spawned at to say that a turret was spawned there
			if g_savedata.islands[selected_spawn] then -- set at their island
				g_savedata.islands[selected_spawn].zones.turrets[spawnbox_index].is_spawned = true
			else -- they spawned at their main base
				g_savedata.ai_base_island.zones.turrets[spawnbox_index].is_spawned = true
			end

		elseif Tags.getValue(selected_prefab.vehicle.tags, "role", true) == "cargo" then
			setSquadCommand(squad, SQUAD.COMMAND.CARGO)
		end

		local prefab, got_prefab = v.getPrefab(selected_prefab.location.data.name)

		if not got_prefab then
			v.createPrefab(spawned_objects.spawned_vehicle.id)
		end

		if cost_existed then
			local cost, cost_existed, was_purchased = v.purchaseVehicle(string.removePrefix(selected_prefab.location.data.name), (g_savedata.islands[selected_spawn].name or g_savedata.ai_base_island.name), purchase_type)
			if not was_purchased then
				vehicle_data.costs.buy_on_load = true
			end
		end

		return true, vehicle_data
	end
	return false, "spawned_objects.spawned_vehicle was nil"
end

-- spawns a ai vehicle, if it fails then it tries again, the amount of times it retrys is how ever many was given
---@param requested_prefab any vehicle name or vehicle role, such as scout, will try to spawn that vehicle or type
---@param vehicle_type string the vehicle type you want to spawn, such as boat, leave nil to ignore
---@param force_spawn boolean if you want to force it to spawn, it will spawn at the ai's main base
---@param specified_island island[] the island you want it to spawn at
---@param purchase_type integer the way you want to purchase the vehicle 0 for dont buy, 1 for free (cost will be 0 no matter what), 2 for free but it has lower stats, 3 for spend as much as you can but the less spent will result in lower stats. 
---@param retry_count integer how many times to retry spawning the vehicle if it fails
---@return boolean spawned_vehicle if the vehicle successfully spawned or not
---@return vehicle_data[] vehicle_data the vehicle's data if the the vehicle successfully spawned, otherwise its nil
function Vehicle.spawnRetry(requested_prefab, vehicle_type, force_spawn, specified_island, purchase_type, retry_count)
	local spawned = nil
	local vehicle_data = nil
	d.print("(Vehicle.spawnRetry) attempting to spawn vehicle...", true, 0)
	for i = 1, retry_count do
		spawned, vehicle_data = v.spawn(requested_prefab, vehicle_type, force_spawn, specified_island, purchase_type)
		if spawned then
			return spawned, vehicle_data
		else
			d.print("(Vehicle.spawnRetry) Spawning failed, retrying ("..retry_count-i.." attempts remaining)\nError: "..vehicle_data, true, 1)
		end
	end
	return spawned, vehicle_data
end

-- teleports a vehicle and all of the characters attached to the vehicle to avoid the characters being left behind
---@param vehicle_id integer the id of the vehicle which to teleport
---@param transform SWMatrix where to teleport the vehicle and characters to
---@return boolean is_success if it successfully teleported all of the vehicles and characters
function Vehicle.teleport(vehicle_id, transform)

	-- make sure vehicle_id is not nil
	if not vehicle_id then
		d.print("(Vehicle.teleport) vehicle_id is nil!", true, 1)
		return false
	end

	-- make sure transform is not nil
	if not transform then
		d.print("(Vehicle.teleport) transform is nil!", true, 1)
		return false
	end

	local vehicle_object, squad_index, squad = Squad.getVehicle(vehicle_id)

	local none_failed = true

	-- set char pos
	for i, char in ipairs(vehicle_object.survivors) do
		local is_success = s.setObjectPos(char.id, transform)
		if not is_success then
			d.print("(Vehicle.teleport) failed to set character position! char.id: "..char.id, true, 1)
			none_failed = false
		end
	end

	-- set vehicle pos
	local is_success = s.setVehiclePos(vehicle_id, transform)

	if not is_success then
		d.print("(Vehicle.teleport) failed to set vehicle position! vehicle_id: "..vehicle_id, true, 1)
		none_failed = false
	end

	return none_failed
end
 -- functions related to vehicles, and parsing data on them

function onCreate(is_world_create)

	-- start the timer for when the world has started to be setup
	local world_setup_time = s.getTimeMillisec()

	-- setup settings
	if not g_savedata.settings then
		g_savedata.settings = {
			MAX_FAMILIES_PER_TOWN = property.slider("Maximum Families Per Town", 0, 20, 1, 7),
			MAX_OCCUPIED_HOUSES_PERCENTAGE = property.slider("Maximum percentage of houses with residents per town", 0, 100, 5, 75) * 0.01
		}
	end

	comp.verify() -- backwards compatibility check

	if just_migrated then
		comp.showSaveMessage()
		return
	end

	-- update player data
	g_savedata.players.online = {}

	if not is_world_create then
		for _, peer in pairs(s.getPlayers()) do
			Players.onJoin(tostring(peer.steam_id), peer.id)
		end
	end

	p.updatePathfinding()

	if is_world_create then
		d.print("setting up world...", true, 0)

		d.print("getting y level of all graph nodes...", true, 0)
		-- cause createPathY to execute, which will get the y level of all graph nodes
		-- otherwise the game would freeze for a bit after the player loaded in, looking like the game froze
		-- instead it looks like its taking a bit longer to create the world.

		local empty_matrix = m.identity()

		s.pathfind(empty_matrix, empty_matrix, "", "")

		--d.print("setting up reservable zones...", true, 0)
		
		--Zones.setup()
	end

	d.print("Loaded Script: "..s.getAddonData((s.getAddonIndex())).name..", Version: "..ADDON_VERSION, true, 0, -1)

	d.print(("World setup complete! took: %.3fs"):format(Ticks.millisecondsSince(world_setup_time)/1000), true, 0, -1)
end

function onPlayerJoin(steam_id, name, peer_id, is_admin, is_auth)
	Players.onJoin(tostring(steam_id), peer_id)
end

function onTick(game_ticks)

	g_savedata.tick_counter = g_savedata.tick_counter + 1
	--server.setGameSetting("npc_damage", true)
	--d.print("onTick", false, 0)
	Citizens.onTick(game_ticks)
end

--------------------------------------------------------------------------------
--
-- Other
--
--------------------------------------------------------------------------------

---@param id integer the tick you want to check that it is
---@param rate integer the total amount of ticks, for example, a rate of 60 means it returns true once every second* (if the tps is not low)
---@return boolean isTick if its the current tick that you requested
function isTickID(id, rate)
	return (g_savedata.tick_counter + id) % rate == 0
end

---@param start_ms number the time you want to see how long its been since (in ms)
---@return number ms_since how many ms its been since <start_ms>
function millisecondsSince(start_ms)
	return s.getTimeMillisec() - start_ms
end

