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

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[ 
	A system to be able to get the data on something without needing to store an exact copy of its data, to avoid issues with the two not syncing,
	and to provide an easy way to grab the data without hardcoding it to grab that data for only that data type.
]]

-- library name
References = {}

--[[


	Classes


]]

---@class referenceDefinition
---@field object_type string the object's type which this definition is for.
---@field getIndexingData function the function called whenever it tries to create the table which is store the indexing data, param1 is the object's data.
---@field getData function the function called whenever the data is tried to be gotten, param 1 is index_data (the data you return in the getIndexingData function)

--[[


	Variables


]]

---@type table<string, referenceDefinition>
reference_definitions = {}

--[[


	Functions


]]

---# Define this object type for references
---@param object_type string the type of this object.
---@param getIndexingData function the function called whenever it tries to create the table which is used to store the indexing data, param1 is the object's data.
---@param getData function the function called whenever the data is tried to be gotten, param 1 is index_data (the data you return in the getIndexingData function)
function References.define(object_type, getIndexingData, getData)
	reference_definitions[object_type] = {
		object_type = object_type,
		getIndexingData = getIndexingData,
		getData = getData
	}
end

---# Gets the indexing data, to store in the other tables to allow for easy indexing of this object.
---@param object table the object's data which to get the indexing data from
---@return table indexing_data the indexing data for this object, returns an empty table on failure.
---@return boolean is_success if it was able to get the indexing table successfully, failures could be due to:<br>1. The object doesn't have the object_type variable stored in it.<br>2. The object does not have an associated reference definition.
function References.getIndexingData(object)

	-- if the object does not store the object type. (error 1)
	if not object.object_type then
		d.print(("<line>: attempted to get the indexing data of an object, however it does not have the object_type stored within it! object_data:\n\"%s\""):format(string.fromTable(object)), true, 1)
		return {}, false
	end

	-- get the reference definition
	local reference_definition = reference_definitions[object.object_type]

	-- if the object does not have an associated definition. (error 2)
	if not reference_definition then
		d.print(("<line>: Attempted to get the reference definition of the object type \"%s\", however it does not have a proper definition, could be possibly due to the code being executed before the reference could be defined, or was never defined in the first place."):format(object.object_type), true, 1)
		return {}, false
	end

	-- get the indexing data
	local indexing_data = reference_definition.getIndexingData(object)

	-- add the object type parameter
	indexing_data.object_type = object.object_type

	-- return the data
	return indexing_data, true
end

---# Gets the data from an object based on just a few variables set to be stored when defined via the getIndexingData function.
---@param indexing_data table the indexing table, follows the returned table format defined in the getIndexingData function, also should have the object_type param unless there was an error in the References.getIndexingData function.
---@return table object_data the object data from the indexing_data table. returns an empty table on failure.
---@return boolean is_success if it successfully got the object_data failures could be due to:<br>1. The indexing_data does not contain the object_type<br>2. There is no defined way to get the object_data with the specified object_type
function References.getData(indexing_data)
	-- if the object does not store the object type. (error 1)
	if not indexing_data.object_type then
		d.print(("<line>: attempted to get the getData function for an object, however the given indexing_data table does not have the object_type stored within it! indexing_data:\n\"%s\""):format(string.fromTable(indexing_data)), true, 1)
		return {}, false
	end

	-- get the reference definition
	local reference_definition = reference_definitions[indexing_data.object_type]

	-- if the object does not have an associated definition. (error 2)
	if not reference_definition then
		d.print(("<line>: Attempted to get the reference definition of the object type \"%s\", however it does not have a proper definition, could be possibly due to the code being executed before the reference could be defined, or was never defined in the first place."):format(indexing_data.object_type), true, 1)
		return {}, false
	end

	local referencing_data = reference_definition.getData(indexing_data)

	-- get & return the object data, set referencing data to {} if its nil, as this should always return a table to try to prevent errors.
	return referencing_data or {}, referencing_data ~= nil
end