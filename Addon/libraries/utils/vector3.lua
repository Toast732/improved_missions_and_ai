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

-- Library Version 0.0.2

--[[


	Library Setup


]]

-- required libraries

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[ 
	Contains some code for math on Vector 3s, as in, a 3D vector.
]]

-- library name
Vector3 = {}

--[[


	Classes


]]

---@class Vector3
---@field x number x axis
---@field y number y axis (up/down)
---@field z number z axis

--[[


	Variables


]]

--[[


	Functions


]]

--- Function for creating a new Vector3
---@param x number
---@param y number
---@param z number
---@return Vector3
function Vector3.new(x, y, z)
	-- create the vector
	local vector = {
		x = x,
		y = y,
		z = z
	}

	-- return the vector
	return vector
end

--- Function for getting the euclidean distance
---@param a Vector3
---@param b Vector3
---@return number euclidean_distance euclidean distance between the two 3D vectors.
function Vector3.euclideanDistance(a, b)
	-- get the relative x position
	local rx = a.x - b.x

	-- get the relative y position
	local ry = a.y - b.y

	-- get the relative z position
	local rz = a.z - b.z

	-- return the distance
	return math.sqrt(rx*rx+ry*ry+rz*rz)
end

--- Function for getting the manhattan distance
---@param a Vector3
---@param b Vector3
---@return number manhattan_distance manhattan distance between the two 3D vectors.
function Vector3.manhattanDistance(a, b)
	-- return the distance
	return (
		math.abs(a.x - b.x) + -- get manhattan distance on x axis
		math.abs(a.y - b.y) + -- get manhattan distance on y axis
		math.abs(a.z - b.z) -- get manhattan distance on z axis
	)
end

--- Function for turning a Matrix into a Vector3
---@param target_matrix SWMatrix
---@param raw_coordinates boolean? whether or not to return the raw coordinates of the matrix (true), or the transformed coordinates (false/nil).
---@return Vector3 vector the vector created from the matrix.
function Vector3.fromMatrix(target_matrix, raw_coordinates)
	-- if raw_coordinates is true
	if raw_coordinates then
		-- return the raw coordinates
		return {
			x = target_matrix[13],
			y = target_matrix[14],
			z = target_matrix[15]
		}
	end

	--* raw coordinates is false, return the transformed coordinates

	-- get transformed coordinates (I assume this function properly applies the rotations, scaling, etc to the matrix.)
	local x, y, z = matrix.position(target_matrix)

	-- return the transformed coordinates
	return {
		x = x,
		y = y,
		z = z
	}
end

--- Function for turning a Vector3 into a Matrix
---@param target_vector Vector3
---@return SWMatrix matrix the matrix created from the vector.
function Vector3.toMatrix(target_vector)
	-- create the matrix
	local matrix = matrix.translation(target_vector.x, target_vector.y, target_vector.z)

	-- return the matrix
	return matrix
end