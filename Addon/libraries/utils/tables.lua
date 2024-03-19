-- required libraries
require("libraries.addon.script.debugging")

--# check for if none of the inputted variables are nil
---@param print_error boolean if you want it to print an error if any are nil (if true, the second argument must be a name for debugging puposes)
---@param ... any variables to check
---@return boolean none_are_nil returns true of none of the variables are nil or false
function table.noneNil(print_error,...)
	local _ = table.pack(...)
	local none_nil = true
	for variable_index, variable in pairs(_) do
		if print_error and variable ~= _[1] or not print_error then
			if not none_nil then
				none_nil = false
				if print_error then
					d.print("(table.noneNil) a variable was nil! index: "..variable_index.." | from: ".._[1], true, 1)
				end
			end
		end
	end
	return none_nil
end

--# returns the number of elements in the table
---@param t table table to get the size of
---@return number count the size of the table
function table.length(t)
	if not t or type(t) ~= "table" then
		return 0 -- invalid input
	end

	local count = 0

	for _ in pairs(t) do -- goes through each element in the table
		count = count + 1 -- adds 1 to the count
	end

	return count -- returns number of elements
end

-- credit: woe | for this function
function table.tabulate(t,...)
	local _ = table.pack(...)
	t[_[1]] = t[_[1]] or {}
	if _.n>1 then
		table.tabulate(t[_[1]], table.unpack(_, 2))
	end
end

--# function that turns strings into a table (Warning: very picky)
--- @param S string a table in string form
--- @return table T the string turned into a.table
function table.fromString(S)
	local function stringToTable(string_as_table, start_index)
		local T = {}

		local variable = nil
		local str = ""

		local char_offset = 0

		start_index = start_index or 1

		for char_index = start_index, string_as_table:len() do
			char_index = char_index + char_offset

			-- if weve gone through the entire string, accounting for the offset
			if char_index > string_as_table:len() then
				return T, char_index - start_index
			end

			-- the current character to read
			local char = string_as_table:sub(char_index, char_index)

			-- if this is the opening of a table
			if char == "{" then
				local returned_table, chars_checked = stringToTable(string_as_table, char_index + 1)

				if not variable then
					table.insert(T, returned_table)
				else
					T[variable] = returned_table
				end

				char_offset = char_offset + (chars_checked or 0)

				variable = nil

			-- if this is the closing of a table, and a start of another
			elseif string_as_table:sub(char_index, char_index + 2) == "},{" then
				if variable then
					T[variable] = str
				end

				return T, char_index - start_index + 1

			-- if this is a closing of a table.
			elseif char == "}" then
				if variable then
					T[variable] = str
				elseif str ~= "" then
					table.insert(T, str)
				end

				return T, char_index - start_index

			-- if we're recording the value to set the variable to
			elseif char == "=" then
				variable = str
				str = ""

			-- save the value of the variable
			elseif char == "," then
				if variable then
					T[variable] = str
				elseif str ~= "" then
					table.insert(T, str)
				end

				str = ""
				variable = ""

			-- write this character if its not a quote
			elseif char ~= "\"" then
				str = str..char
			end
		end
	end

	return table.pack(stringToTable(S, 1))[1]
end

--- Returns the value at the path in _ENV
---@param path string the path we want to get the value at
---@return any value the value at the path, if it reached a nil value in the given path, it will return the value up to that point, and is_success will be false.
---@return boolean is_success if it successfully got the value at the path
function table.getValueAtPath(path)
	if type(path) ~= "string" then
		d.print(("path must be a string! given path: %s type: %s"):format(path, type(path)), true, 1)
		return nil, false
	end

	-- If path is _ENV, then set it to an empty string.
	if path == "_ENV" then
		path = ""
	end

	local cur_path
	-- if our environment is modified, we will have to make a deep copy under the non-modified environment.
	if _ENV_NORMAL then
		-- make sure _ENV_MODIFIED is removed from _ENV_NORMAL to prevent infinite recursion
		_ENV_NORMAL._ENV_MODIFIED = nil
		cur_path = _ENV_NORMAL.table.copy.deep(_ENV, _ENV_NORMAL)
	else
		cur_path = table.copy.deep(_ENV)
	end
	
	--cur_path = safe_copy_deep(_ENV)

	local cur_path_string = "_ENV"

	for index in string.gmatch(path, "([^%.]+)") do
		if not cur_path[index] then
			d.print(("%s does not contain a value indexed by %s, given path: %s"):format(cur_path_string, index, path), false, 1)
			return cur_path, false
		end

		cur_path = cur_path[index]
	end

	return cur_path, true
end


--- Sets the value at the path in _ENV
---@param path string the path we want to set the value at
---@param set_value any the value we want to set the value of what the path is
---@return boolean is_success if it successfully got the value at the path
function table.setValueAtPath(path, set_value)
	
	if type(path) ~= "string" then
		d.print(("(table.setValueAtPath) path must be a string! given path: %s type: %s"):format(path, type(path)), true, 1)
		return false
	end

	-- If path is _ENV, then set it to an empty string.
	if path == "_ENV" then
		path = ""
	end

	local cur_path = _ENV
	-- if our environment is modified, we will have to make a deep copy under the non-modified environment.
	--[[if _ENV_NORMAL then
		cur_path = _ENV_NORMAL.table.copy.deep(_ENV, _ENV_NORMAL)
	else
		cur_path = table.copy.deep(_ENV)
	end]]

	local cur_path_string = "_ENV"

	local index_count = 0

	local last_index, got_count = string.countCharInstances(path, "%.")

	last_index = last_index + 1

	if not got_count then
		d.print(("(table.setValueAtPath) failed to get count! path: %s"):format(path))
		return false
	end

	for index in string.gmatch(path, "([^%.]+)") do
		index_count = index_count + 1

		if not cur_path[index] then
			d.print(("(table.setValueAtPath) %s does not contain a value indexed by %s, given path: %s"):format(cur_path_string, index, path), false, 1)
			return false
		end

		if index_count == last_index then
			cur_path[index] = set_value

			return true
		end

		cur_path = cur_path[index]
	end

	d.print("(table.setValueAtPath) never reached end of path?", true, 1)
	return false
end

-- a table containing a bunch of functions for making a copy of tables, to best fit each scenario performance wise.
table.copy = {

	iShallow = function(t, __ENV)
		__ENV = __ENV or _ENV
		return {__ENV.table.unpack(t)}
	end,
	shallow = function(t, __ENV)
		__ENV = __ENV or _ENV

		local t_type = __ENV.type(t)

		local t_shallow

		if t_type == "table" then
			for key, value in __ENV.next, t, nil do
				t_shallow[key] = value
			end
		end

		return t_shallow or t
	end,
	deep = function(t, __ENV)

		__ENV = __ENV or _ENV

		-- Normal Version

		local function deepCopy(T)
			local copy = {}
			if __ENV.type(T) == "table" then
				for key, value in __ENV.next, T, nil do
					copy[deepCopy(key)] = deepCopy(value)
				end
			else
				copy = T
			end
			return copy
		end

		-- Debug Version (For fixing stack overflows)
		local function deepCopyDebug(T, p_key)
			local copy = {}
			debug.log("SW IMAI  Debug: | "..p_key)
			if __ENV.type(T) == "table" then
				for key, value in __ENV.next, T, nil do
					copy[deepCopyDebug(key, p_key.."."..tostring(key))] = deepCopyDebug(value, p_key.."."..tostring(key))
				end
			else
				copy = T
			end
			return copy
		end

		--return deepCopy(t)
	
		return deepCopy(t ,"")
		
	end
}

---# Returns whether or not two tables are equal. <br>
--- Variation of https://stackoverflow.com/a/32660766
---@param t1 any
---@param t2 any
---@return boolean equal
function table.equals(t1, t2)
	-- if the two variables are just directly equal.
	if t1 == t2 then
		return true
	end

	-- get the types of the tables
	local t1_type = type(t1)
	local t2_type = type(t2)

	-- if the types are not the same, then they cannot be the same.
	if t1_type ~= t2_type then
		return false
	end

	--[[
		if they're not tables, then we can skip checking them, as we cannot iterate through non tables.
		we only need to check one as they have to be the same variable type due to the previous check.
	]]
	if t1_type ~= "table" then
		return false
	end

	-- store the keys that exist in t1
	local t1_keys = {}

	-- iterate through t1
	for tk1, tv1 in pairs(t1) do
		-- get the value in t2 with the index of this variable in t1
		local tv2 = t2[tk1]

		-- if the index in t1 does not exist in t2, then the tables are not the same.
		if tv2 == nil then
			return false
		end

		-- check if the two values are the same, if the normal == returns false, then do a check via table.equals, as {} ~= {}.
		if tv1 ~= tv2 and table.equals(tv1, tv2) then
			return false
		end
		-- say that this key exists in tv1
		t1_keys[tk1] = true
	end

	-- iterate through t2
	for tk2, _ in pairs(t2) do
		-- if this key does not exist in t1, then the tables are not the same.
		if not t1_keys[tk2] then
			return false
		end
	end

	-- if we got to this point, that means that these two tables are the same.
	return true
end