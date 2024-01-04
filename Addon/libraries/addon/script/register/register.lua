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

require("libraries.utils.string")

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[ 
	Register system, used to allow other scripts to register things inside of this addon,
	such as adding medical conditions, citizen traits, etc.
]]

-- contains the registers
registers = {}

Register = {}

---# Create a new register
---@param register_name string the register's name, cannot contain spaces
---@param call_on_set function the function to call when something tries to add a variable to the register.
---@return boolean is_success if the register was successfully created
function Register.create(register_name, call_on_set)

	--[[
		Error Checking
	]]

	local register_name_type = type(register_name)

	-- ensure register name is a string
	if register_name_type ~= "string" then
		d.print(("<line>: type of register_name provided is %s, expected string"):format(register_name_type), true, 1)
		return false
	end

	-- ensure register name contains no spaces
	if register_name:find(" ") then
		d.print(("<line>: invalid register_name provided as it contains spaces: \"%s\""):format(register_name), true, 1)
		return false
	end

	local call_on_set_type = type(call_on_set)

	-- ensure register name is a string
	if call_on_set_type ~= "function" then
		d.print(("<line>: type of call_on_set provided is %s, expected function"):format(call_on_set_type), true, 1)
		return false
	end

	-- ensure that this register has not already been created
	if registers[register_name] then
		d.print(("<line>: register \"%s\" has already been created."):format(register_name), true, 1)
		return false
	end

	--[[
		Creating the register
	]]

	registers[register_name] = call_on_set

	return true
end

