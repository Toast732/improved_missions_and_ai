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

	Registers the register commands.

]]

-- Info command
Command.registerCommand(
	"add",
	---@param full_message string the full message
	---@param peer_id integer the peer_id of the sender
	---@param arg table the arguments of the command.
	function(full_message, peer_id, arg)

		--[[
			Ensure that its talking to us and not giving bad data
		]]

		local target_script = arg[1]

		-- check if this command is meant for us
		if target_script ~= SHORT_ADDON_NAME or target_script ~= server.getAddonIndex() then
			return
		end

		local calling_script = arg[2]
		-- ensure the calling script is set
		if not calling_script then
			d.print("<line>: failed to add register as script did not identify itself.", true, 1)
			return
		end

		local register_name = arg[3]

		-- ensure the register name is set
		if not registers[register_name] then
			d.print(("<line>: Addon \"%s\" attempted to add to the register \"%s\", however it does not exist."):format(calling_script, register_name), true, 1)
			return
		end

		--[[
			remove args for calling target register
		]]
		
		-- remove target_script arg
		table.remove(arg, 1)
		-- remove register_name arg
		table.remove(arg, 2)
		-- adjust .n
		arg.n = arg.n - 2
		
		--[[
			call target register
		]]

		registers[register_name](arg)
	end,
	"admin_script",
	"Prints some info about the addon, such as it's version",
	"Prints some general addon info.",
	{""},
	"register"
)