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