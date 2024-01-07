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
require("libraries.addon.script.debugging")

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[ 
	Has some functions to find tags on an object. And some to get their value.
]]

-- library name
Tags = {}

--[[


	Classes


]]

---@alias Tags table<integer, string>

--[[


	Variables


]]

--[[


	Functions


]]

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