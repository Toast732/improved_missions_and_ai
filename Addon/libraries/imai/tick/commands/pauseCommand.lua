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
require("libraries.addon.commands.command.command")
require("libraries.addon.script.debugging")

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[

	Registers the pause command.

]]

g_savedata.paused = false

-- Pause command
Command.registerCommand(
	"pause",
	---@param full_message string the full message
	---@param peer_id integer the peer_id of the sender
	---@param arg table the arguments of the command.
	function(full_message, peer_id, arg)
		-- Invert the paused state
		g_savedata.paused = not g_savedata.paused

		-- Print the new state
		d.print(("%saused %s"):format(g_savedata.paused and "P" or "Unp", SHORT_ADDON_NAME), false, 0, peer_id)
	end,
	"admin",
	"Prevents the addon's onTick function from executing anything, some important tickers may bypass (eg: prefab setup).",
	"Pauses the script's ticker.",
	{""}
)