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

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[ 
	LIBRARY DESCRIPTION
]]

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

registerTest("timeFormattingTest1", function()

	-- Test if 3456 seconds properly gets formatted as 57 minutes and 36 seconds.
	local seconds = 3456

	-- The desired output we want.
	local desired_output = "57 minutes, and 36 seconds"

	-- Format the time.
	local formatted_time = string.formatTime(time_formats.yMwdhmsMS, seconds)

	return isEqual(formatted_time, desired_output)
end)

registerTest("timeFormattingTest2", function()

	-- Test if 1 second properly gets formatted as 1 second.
	local seconds = 1

	-- The desired output we want.
	local desired_output = "1 second"

	-- Format the time.
	local formatted_time = string.formatTime(time_formats.yMwdhmsMS, seconds)

	return isEqual(formatted_time, desired_output)
end)

registerTest("timeFormattingTest3", function()

	-- Test if 0.5 seconds properly gets formatted as 500 milliseconds.
	local seconds = 0.5

	-- The desired output we want.
	local desired_output = "500 milliseconds"

	-- Format the time.
	local formatted_time = string.formatTime(time_formats.yMwdhmsMS, seconds)

	return isEqual(formatted_time, desired_output)
end)

registerTest("timeFormattingTest4", function()

	-- Test if 60 seconds properly gets formatted as 1 minute.
	local seconds = 60

	-- The desired output we want.
	local desired_output = "1 minute"

	-- Format the time.
	local formatted_time = string.formatTime(time_formats.yMwdhmsMS, seconds)

	return isEqual(formatted_time, desired_output)
end)


registerTest("timeFormattingTest5", function()

	-- Test if 120 seconds properly gets formatted as 2 minutes.
	local seconds = 120

	-- The desired output we want.
	local desired_output = "2 minutes"

	-- Format the time.
	local formatted_time = string.formatTime(time_formats.yMwdhmsMS, seconds)

	return isEqual(formatted_time, desired_output)
end)

registerTest("timeFormattingTest6", function()

	-- Test if 150 seconds properly gets formatted as 2 minutes and 30 seconds.
	local seconds = 150

	-- The desired output we want.
	local desired_output = "2 minutes, and 30 seconds"

	-- Format the time.
	local formatted_time = string.formatTime(time_formats.yMwdhmsMS, seconds)

	return isEqual(formatted_time, desired_output)
end)

registerTest("timeFormattingTest7", function()

	-- Test if 3600 seconds properly gets formatted as 1 hour.
	local seconds = 3600

	-- The desired output we want.
	local desired_output = "1 hour"

	-- Format the time.
	local formatted_time = string.formatTime(time_formats.yMwdhmsMS, seconds)

	return isEqual(formatted_time, desired_output)
end)