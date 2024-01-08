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
	Contains some code for math on Vector 2s, as in, a 2D vector.
]]

-- library name
Vector2 = {}

--[[


	Classes


]]

---@class Vector2
---@field x number
---@field y number Usually the z axis in disguise.

--[[


	Variables


]]

--[[


	Functions


]]

--- Function for getting the euclidean distance
---@param a Vector2
---@param b Vector2
---@return number euclidean_distance euclidean distance between the two 2D vectors.
function Vector2.euclideanDistance(a, b)
	-- get the relative x position
	local rx = a.x - b.x

	-- get the relative y position
	local ry = a.y - b.y

	-- return the distance
	return math.sqrt(rx*rx+ry*ry)
end

--- Function for getting the manhattan distance
---@param a Vector2
---@param b Vector2
---@return number manhattan_distance manhattan distance between the two 2D vectors.
function Vector2.manhattanDistance(a, b)
	-- return the distance
	return (
		math.abs(a.x - b.x) + -- get manhattan distance on x axis
		math.abs(a.y - b.y) -- get manhattan distance on y axis
	)
end