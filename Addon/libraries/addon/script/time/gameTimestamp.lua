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

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[ 
	Acts as a epoch timestamp for the game. Where the time is based on in game time and date, instead of real time.
]]

-- library name
GameTimestamp = {}

--[[


	Classes


]]

---@alias GameTimestamp number

--[[


	Constants


]]

--[[


	Variables


]]

--- Used to cache timestamps.
local cached_timestamps = {
	now = {
		value = 0,
		last_updated_tick = -1

	},
	today = {
		value = 0,
		last_updated_tick = -1
	}
}

--[[


	Functions


]]

--- Function for creating a game timestamp for the current day.
---@return GameTimestamp
function GameTimestamp.today()

	-- Check if the cached timestamp is still valid
	if cached_timestamps.today.last_updated_tick == g_savedata.tick_counter then
		return cached_timestamps.today.value
	end

	-- Otherwise, update the cached timestamp

	-- Get the current date
	local day, month, year = server.getDate()

	-- Deduct 2032 from the year, as the game starts in 2032.
	year = year - 2032

	-- Deduct 5 from the month, as the game starts in June.
	month = month - 5

	-- Calculate the timestamp
	cached_timestamps.today.value = year * 365 + month * 30 + day

	-- Update the last updated tick
	cached_timestamps.today.last_updated_tick = g_savedata.tick_counter

	-- Return the timestamp
	return cached_timestamps.today.value
end

--- Function for creating a game timestamp for the current time.
--- @return GameTimestamp
function GameTimestamp.now()

	-- Check if the cached timestamp is still valid
	if cached_timestamps.now.last_updated_tick == g_savedata.tick_counter then
		return cached_timestamps.now.value
	end

	-- Otherwise, update the cached timestamp

	-- Get today's timestamp
	local base_timestamp = GameTimestamp.today()

	-- Get the current time as a ratio of the day
	local day_ratio = server.getTime().percent

	-- Calculate the timestamp
	cached_timestamps.now.value = base_timestamp + day_ratio

	-- Update the last updated tick
	cached_timestamps.now.last_updated_tick = g_savedata.tick_counter

	-- Return the timestamp
	return cached_timestamps.now.value
end

--- Function for turning hours to a timestamp value, which you can use in conjunction with a timestamp for calculations.
---@param hours number the number of hours to convert to a timestamp.
---@return GameTimestamp game_timestamp the timestamp value for the hours.
function GameTimestamp.hoursToTimestamp(hours)
	return hours / 24
end

--- Function for turning minutes to a timestamp value, which you can use in conjunction with a timestamp for calculations.
---@param minutes number the number of minutes to convert to a timestamp.
---@return GameTimestamp game_timestamp the timestamp value for the minutes.
function GameTimestamp.minutesToTimestamp(minutes)
	return minutes / 1440
end

--- Function for turning seconds to a timestamp value, which you can use in conjunction with a timestamp for calculations.
---@param seconds number the number of seconds to convert to a timestamp.
---@return GameTimestamp game_timestamp the timestamp value for the seconds.
function GameTimestamp.secondsToTimestamp(seconds)
	return seconds / 86400
end