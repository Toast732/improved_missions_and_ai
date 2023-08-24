lineNumbers = {}

--- returns the number of instances of that character in the string
---@param str string the string we are wanting to check
---@param char any the character(s) we are wanting to count for in str, note that this is as a lua pattern
---@return number count the number of instances of char, if there was an error, count will be 0, and is_success will be false
---@return boolean is_success if we successfully got the number of instances of the character
local function countCharInstances(str, char)

	if type(str) ~= "string" then
		--d.print(("(string.countCharInstances) str is not a string! type of str: %s str: %s"):format(type(str), str), true, 1)
		return 0, false
	end

	char = tostring(char)

	local _, count = string.gsub(str, char, "")

	return count, true
end

local function findLine(pos, text)
	local trimmed_text = text:sub(1, pos)

	return countCharInstances(trimmed_text, "\n") + 1
end

-- look for the following strings to replace with the line number that string is on.
local line_number_replace_strings = {
	"<line>"
}

function lineNumbers.onCompile(script_text, script_file_path)

	-- replace all "<line>" with the line number which its on.

	for replace_string_index = 1, #line_number_replace_strings do

		local pattern = line_number_replace_strings[replace_string_index]

		local pos = 0

		-- go through all instances of this string in the script
		for _ in script_text:gmatch(pattern) do

			-- find the position of this string
			pos, last_pos = script_text:find(pattern, pos)

			-- if we failed to find the position, then stop checking for more.
			if not pos then break end

			-- replace the string with the line's position
			script_text = ("%s%s%s"):format(
				script_text:sub(1, pos-1),
				findLine(pos, script_text),
				script_text:sub(last_pos+1, script_text:len())
			)

			-- make sure it doesn't constantly keep trying to edit the same string, if replacing the string fails for whatever reason
			pos = last_pos
		end
	end

	LifeBoatAPI.Tools.FileSystemUtils.writeAllText(script_file_path, script_text)

	return script_text
end