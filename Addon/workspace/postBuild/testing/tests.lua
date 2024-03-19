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
	LIBRARY DESCRIPTION
]]

-- library name
LibraryName = {}

--[[


	Classes


]]

---@class Test
---@field name string the name of the test
---@field execute_function fun() the function to be ran.

--[[


	Constants


]]

--[[


	Variables


]]

-- Stores all of the tests to be ran
---@type table<integer, Test>
local stored_tests = {}

--[[


	Functions


]]

-- Called by _buildactions.lua, once the script has been built. Starts all of the tests.
function onBuild(script_path)
	-- Iterate through all of the tests
	for test_index = 1, #stored_tests do

		-- Define the matrix table.
		matrix = {}
		
		-- load the _ENV from the script
		dofile(script_path)
		-- Run the test
		success, result = pcall(stored_tests[test_index].execute_function)

		if success and result == true then
			print("Test " .. stored_tests[test_index].name .. " passed.")
		else
			print("Test " .. stored_tests[test_index].name .. " failed.")
		end
	end
end

--- Registers a test to be run.
---@param test_name string the name of the test
---@param test_function function the function to be run
function registerTest(test_name, test_function)
	-- Add the test
	table.insert(stored_tests, 
	{
			name = test_name,
			execute_function = test_function
		}
	)
end

require("workspace.postBuild.testing.vehicles.drivable.landTesting")