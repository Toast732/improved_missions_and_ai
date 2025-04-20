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

TickTesterCommand = {}

-- required libraries
require("libraries.addon.script.addonCommunication")

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[

	Registers a command to test if the addon has errored or not, by checking if the tick function is getting called.

]]

--[[


	Constants


]]

TICK_TEST_ADDON_COMMUNICATION_MESSAGE = "TICK_TEST_PING"

--[[


	Variables


]]

local is_tick_test_command_active = false
local tick_testers = {}

-- Tick Test command
Command.registerCommand(
	"tick_test",
	---@param full_message string the full message
	---@param peer_id integer the peer_id of the sender
	---@param arg table the arguments of the command.
	function(full_message, peer_id, arg)
		-- Set the tick test variable to true
		is_tick_test_command_active = true

		-- Add this user to the tick testers.
		table.insert(tick_testers, peer_id)

		AddonCommunication.executeOnReply(
			SHORT_ADDON_NAME,
			TICK_TEST_ADDON_COMMUNICATION_MESSAGE,
			0,
			function()
				-- If the tick test command is active, then print that the tick test has failed.
				if is_tick_test_command_active then
					for tick_tester_index = 1, #tick_testers do 
						d.print("Tick test failed!", false, 0, tick_testers[tick_tester_index])
					end
					
					-- Set the tick test variable to false.
					is_tick_test_command_active = false

					-- Clear the tick testers
					tick_testers = {}
				end
			end,
			1,
			5
		)

		-- Send the communication
		AddonCommunication.sendCommunication(TICK_TEST_ADDON_COMMUNICATION_MESSAGE, 0)
	end,
	"none",
	"Tests if the tick function is being called. Which is able to check if an error occured in the addon, useful for if an error occured, but was pushed up by a bunch of debug.",
	"Tests if the addon has errored.",
	{""}
)

-- OnTick for the tick test command, will print that the tick test has passed.
function TickTesterCommand.onTick()
	if is_tick_test_command_active then
		for tick_tester_index = 1, #tick_testers do 
			d.print("Tick test passed!", false, 0, tick_testers[tick_tester_index])
		end

		-- Set the tick test variable to false.
		is_tick_test_command_active = false

		-- Clear the tick testers
		tick_testers = {}
	end
end