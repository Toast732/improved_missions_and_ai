-- library name
Ticks = {}

---@param start_ms number the time you want to see how long its been since (in ms)
---@return number ms_since how many ms its been since <start_ms>
function Ticks.millisecondsSince(start_ms)
	return s.getTimeMillisec() - start_ms
end