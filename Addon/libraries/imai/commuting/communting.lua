--[[
	
Copyright 2025 Liam Matthews

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
require("libraries.imai.commuting.commuteSegmentManager")

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[
	The commuting system, this is what's interacted with by things such as the citizen schedule system after the base schedule has been generated.
]]

--[[
	Rules:
		1. The first and final commute types must be an interim commute type (eg: walking)
			Reasoning:
				This is to avoid situations where, for example, a citizen could try driving into their work, and prevents cases of teleporting.
		2. The same commute type cannot be used twice in a row¹.
			Reasoning:
				This is to avoid wasting resources, as walking straight to work will aways be better than first walking to the bus station, 
				and then walking to work from said bus station. So this will prevent such from being calculated.
			¹ This rule does not always apply, as if somebody carpools with a driver, the driver would then be allowed to have two driving commutes in a row,
				However, this will be added after the fact, so during the generation of the schedule, we can still enforce this rule. As carpooling would inject the
				split from the end of the citizen who's getting the ride. The driver still gets to make the decision however.
]]

-- library name
Commuting = {}

--[[


	Classes


]]

---@alias CommuteCost number

--- Base class to be extended from, so each commute option can specify the custom data they require.
---@class CommuteBaseOptionData
---@field cost CommuteCost|nil the cost of this commute option.
---@field citizen_id CitizenID the citizen this commute is for.

---@alias CommuteType string

---@class CommuteTypeDefinition
---@field name CommuteType the name of the commute type, eg "walking"
---@field interim boolean if this commute can be used as an interim commute (eg: walking from house to the car)
---@field getOptions fun(citizen_id: CitizenID, origin: Vector3, destination: Vector3): table<integer, CommuteBaseOptionData> the options for this commute type.
---@field isAvailable fun(options_data: table<integer, CommuteBaseOptionData>): boolean if this commute type is available for this citizen.
---@field calculateRoute fun(option_data: CommuteBaseOptionData, origin: Vector3, destination: Vector3): Route the route for this commute type.
---@field getCommuteTime fun(option_data: CommuteBaseOptionData, route: Route): GameTimestamp the time it takes for this citizen to commute using this commute type.
---@field getCost fun(option_data: CommuteBaseOptionData, route: Route): CommuteCost the cost of this commute type.
---@field checkCompletion fun(option_data: CommuteBaseOptionData, route: Route): boolean if this commute is completed.
---@field tick fun(option_data: CommuteBaseOptionData, route: Route, game_ticks: integer)? Ticks the commute, null if not required.
---@field startActions fun(option_data: CommuteBaseOptionData, route: Route)? The actions to call when this commute type starts.
---@field endActions fun(option_data: CommuteBaseOptionData)? The actions to call when this commute type ends.

---@class CommuteBuilder
---@field citizen_id CitizenID the citizen this commute is for.
---@field origin Vector3 the origin of the commute.
---@field destination Vector3 the destination of the commute.

---@alias ActiveCommuteID integer

---@class ActiveCommute
---@field id ActiveCommuteID the id of this active commute.
---@field commute_builder CommuteBuilder the builder for this commute.
---@field commute_segments CommuteSegments the commute segments for this commute.
---@field current_segment_index CommuteSegmentIndex the index of the current segment.

--[[


	Constants


]]

-- The number of commutes to get for each segment addition. this number essentially multiplies by itself for each check.
MAX_COMMUTES_PER_SEGMENT_CHECK = 3

-- The absolute maximum number of segments before it just auto-fails, to prevent infinite recursion.
MAX_SEGMENTS = 3

--[[


	Variables


]]

g_savedata.libraries.commuting = {
	---@type table<ActiveCommuteID, ActiveCommute>
	active_commutes = {},

	---@type ActiveCommuteID
	next_active_commute_id = 1
}

--- The types of commutes that are registered. Interim commutes are also included in this list.
---@type table<CommuteType, CommuteTypeDefinition>
commute_types = {}

--- The interim commutes that are registered.
---@type table<integer, CommuteTypeDefinition>
interim_commute_types = {}

--[[


	Functions


]]

--- Function for registering a new commute type.
---@param name string the name of the commute type, eg "walking"
---@param interim boolean if this commute can be used as an interim commute (eg: walking from house to the car)
---@param getOptions fun(citizen_id: CitizenID, origin: Vector3, destination: Vector3): table<integer, CommuteBaseOptionData> the options for this commute type.
---@param isAvailable fun(options_data: table<integer, CommuteBaseOptionData>): boolean if this commute type is available for this citizen.
---@param calculateRoute fun(option_data: CommuteBaseOptionData, origin: Vector3, destination: Vector3): Route the route for this commute type.
---@param getCommuteTime fun(option_data: CommuteBaseOptionData, route: Route): GameTimestamp the time it takes for this citizen to commute using this commute type.
---@param getCost fun(option_data: CommuteBaseOptionData, route: Route): CommuteCost the cost of this commute type.
---@param checkCompletion fun(option_data: CommuteBaseOptionData, route: Route): boolean if this commute is completed.
---@param tick fun(option_data: CommuteBaseOptionData, route: Route, game_ticks: integer)? Ticks the commute, null if not required.
---@param startActions fun(option_data: CommuteBaseOptionData, route: Route)? The actions to call when this commute type starts.
---@param endActions fun(option_data: CommuteBaseOptionData)? The actions to call when this commute type ends.
function Commuting.registerCommuteType(name, interim, getOptions, isAvailable, calculateRoute, getCommuteTime, getCost, checkCompletion, tick, startActions, endActions)
	
	-- check if this commute type is already registered
	for _, commute_type in ipairs(commute_types) do
		if commute_type.name == name then
			d.print(("Commute type %s is already registered."):format(name), true, 1)
			return
		end
	end

	-- create the commute type definition
	---@type CommuteTypeDefinition
	local commute_type_definition = {
		name = name,
		interim = interim,
		getOptions = getOptions,
		isAvailable = isAvailable,
		calculateRoute = calculateRoute,
		getCommuteTime = getCommuteTime,
		getCost = getCost,
		checkCompletion = checkCompletion,
		tick = tick,
		startActions = startActions,
		endActions = endActions
	}

	-- create it as a commute type
	commute_types[name] = commute_type_definition

	-- If it's an interim commute, add it to the interim commutes.
	if interim then
		table.insert(interim_commute_types, commute_types[name])
	end
end

--- Function used to find the commute the citizen should take.
---@param builder CommuteBuilder the builder for the commute.
---@return ActiveCommuteID? active_commute_id the id of the active commute.
function Commuting.commute(builder)

	--- This function is used to get the next segment for the commute.
	---@param commute_segment_manager CommuteSegmentManager the commute segment manager to go off of.
	---@param max_commutes integer the maximum number of commutes to get, will get the top x commutes.
	---@return table<integer, CommuteSegmentManager> commutes the options for the commute.
	local function getNextCommuteSegments(commute_segment_manager, max_commutes)

		-- Get the points we're connecting to
		local target_origin, target_destination, connecting_to = commute_segment_manager:getNextTargetPoints()

		-- Store a list of all available commutes.
		---@type table<integer, CommuteSegmentManager>
		local available_commutes = {}

		-- Go through each commute type.
		for _, commute_type_definition in pairs(commute_types) do
			-- Get the options for this commute type.
			local options = commute_type_definition.getOptions(
				builder.citizen_id,
				target_origin,
				target_destination
			)

			-- If this commute type is available, add the options to the available options.
			if commute_type_definition.isAvailable(options) then

				-- Get the index to insert the segment at.
				local insertion_index = connecting_to == COMMUTE_CONNECTING_TO.START and 1 or #commute_segment_manager.segments + 1

				-- Check if we can even insert here.
				if not commute_segment_manager:canInsert(insertion_index, commute_type_definition.name) then
					d.print(("<line>: (Commuting.commute) Cannot insert segment of type %s at index %s."):format(commute_type_definition.name, insertion_index), true, 0)

					-- Print the segments in the segment manager.
					for segment_index, segment in pairs(commute_segment_manager.segments) do
						d.print(("<line>: (Commuting.commute) Segment %s: %s"):format(segment_index, segment.commute_type), true, 0)
					end

					goto continue_commute_type
				end

				for option_index = 1, #options do

					-- Get the option.
					local option = options[option_index]

					-- Create a new commute segment manager commute for this option.
					local option_commute_segment_manager = commute_segment_manager:duplicate()

					-- Insert the segment.
					option_commute_segment_manager:insertSegment(
						insertion_index,
						---@type CommuteSegment
						{
							commute_type = commute_type_definition.name,
							option_data = option,
							route = commute_type_definition.calculateRoute(option, target_origin, target_destination)
						}
					)

					-- If this commute is not an interim commute, do the interim route for this as well.
					if not commute_type_definition.interim then
						for _, interim_commute_type_definition in pairs(interim_commute_types) do

							-- Get the interim target origin
							local interim_target_origin = Vector3.fromMatrix(
								connecting_to == COMMUTE_CONNECTING_TO.START and
								option_commute_segment_manager.segments[insertion_index].route.end_matrix or
								option_commute_segment_manager.segments[insertion_index - 1].route.end_matrix
							)

							-- Get the interim target destination
							local interim_target_destination = Vector3.fromMatrix(
								connecting_to == COMMUTE_CONNECTING_TO.START and
								option_commute_segment_manager.segments[insertion_index + 1].route.start_matrix or
								option_commute_segment_manager.segments[insertion_index].route.start_matrix
							)

							-- Get the interim options.
							local interim_options = interim_commute_type_definition.getOptions(
								builder.citizen_id,
								interim_target_origin,
								interim_target_destination
							)

							-- If this commute type is available, add the options to the available options.
							if interim_commute_type_definition.isAvailable(interim_options) then

								-- Get the index to insert the segment at.
								local interim_insertion_index = connecting_to == COMMUTE_CONNECTING_TO.START and 2 or #option_commute_segment_manager.segments

								-- Check if we can even insert here.
								if not option_commute_segment_manager:canInsert(insertion_index, interim_commute_type_definition.name) then
									goto continue_interim_commute_type
								end

								for interim_option_index = 1, #interim_options do

									-- Get the option.
									local interim_option = interim_options[interim_option_index]

									-- Create a new commute segment manager commute for this interim option.
									local interim_option_commute_segment_manager = option_commute_segment_manager:duplicate()

									-- Insert the segment.
									interim_option_commute_segment_manager:insertSegment(
										interim_insertion_index,
										---@type CommuteSegment
										{
											commute_type = interim_commute_type_definition.name,
											option_data = interim_option,
											route = interim_commute_type_definition.calculateRoute(
												interim_option,
												interim_target_origin,
												interim_target_destination
											)
										}
									)

									-- Add this to the available commutes.
									table.insert(available_commutes, interim_option_commute_segment_manager)
								end

								::continue_interim_commute_type::
							end
						end

					else
						-- Otherwise, if this is the interim commute, then we can just insert it.
						table.insert(available_commutes, option_commute_segment_manager)
					end
				end

				::continue_commute_type::
			end
		end

		-- Sort the available commutes by cost, lowest tp highest
		table.sort(
			available_commutes,
			function(a, b)
				return a.cost < b.cost
			end
		)

		-- Create a list of the top x commutes
		---@type table<integer, CommuteSegmentManager>
		local top_commutes = {}

		-- Add the top commutes until we reach the max commutes, or we run out of commutes.
		for top_commute_index = 1, math.min(#available_commutes, max_commutes) do
			table.insert(top_commutes, available_commutes[top_commute_index])
		end

		-- Return the top commutes
		return top_commutes
	end

	-- The current stored commutes, each time we go further in check, this is cleared again with our new results. Each time one finishes or fails, it's removed.
	---@type table<integer, CommuteSegmentManager>
	local stored_commutes = {}

	-- Go through each of the commute types.
	for _, commute_type_definition in pairs(commute_types) do
		-- Get the options for this commute type.
		local options = commute_type_definition.getOptions(
			builder.citizen_id,
			builder.origin,
			builder.destination
		)

		-- If this commute type is available, add the options to the initial options.
		if commute_type_definition.isAvailable(options) then
			for option_index = 1, #options do

				-- Get the option.
				local option = options[option_index]

				-- Get the route for this option.
				local route = commute_type_definition.calculateRoute(option, builder.origin, builder.destination)

				-- Create the segment manager.
				local commute_segment_manager = CommuteSegmentManager.new(builder)

				-- Insert the segment.
				commute_segment_manager:insertSegment(
					1,
					---@type CommuteSegment
					{
						commute_type = commute_type_definition.name,
						option_data = option,
						route = route
					}
				)

				-- Add this to the potential segment paths.
				table.insert(stored_commutes, commute_segment_manager)
			end
		end
	end

	-- Store our best finished commute.
	---@type CommuteSegmentManager?
	local best_commute = nil

	-- Continue until there's no more stored commutes.
	while #stored_commutes > 0 do

		-- Cache the stored commutes.
		local current_commutes = stored_commutes

		-- Clear the stored commutes.
		stored_commutes = {}

		-- Go through each of the current commutes.
		for current_commute_index = 1, #current_commutes do

			-- Get the current commute.
			local current_commute = current_commutes[current_commute_index]

			-- If the commute is already complete, then do a best comparison
			if current_commute.end_connected and current_commute.start_connected then
				if not best_commute or best_commute.cost > current_commute.cost then

					current_commute:drawDebug()

					d.print(("<line>: (Commuting.commute) Found a best direct route. Segment Count: %s"):format(#current_commute.segments), true, 0)

					-- Set it as the best
					best_commute = current_commute

					-- Go to the next commute
					goto continue_next_commute
				end
			end

			-- Get the best options for this commute
			local next_commutes = getNextCommuteSegments(
				current_commutes[current_commute_index],
				MAX_COMMUTES_PER_SEGMENT_CHECK
			)

			-- Go through each of the next commutes, and add them.
			for next_commute_index = 1, #next_commutes do

				-- Get the next commute
				local next_commute = next_commutes[next_commute_index]

				next_commute:drawDebug()

				-- If we've hit over our maximum number of segments, then we just skip this one.
				if #next_commute.segments > MAX_SEGMENTS then
					d.print("<line>: (Commuting.commute) Hit maximum number of segments, skipping.", true, 0)
					goto continue_next_best_commute
				end

				-- If we have a best segment, check if this one is worse (if it's worse, then it can never be better)
				if best_commute and best_commute.cost <= next_commute.cost then
					d.print("<line>: (Commuting.commute) Commute costs more than the current best, skipping.", true, 0)
					goto continue_next_best_commute
				end

				-- If this commute has both connections (the previous check already checked for if the current best is better too), then set it as the best
				-- Otherwise, add it to the stored commutes for the next checks.
				if next_commute.start_connected and next_commute.end_connected then
					best_commute = next_commute
					d.print(("<line>: (Commuting.commute) Found a best route. Segment Count: %s"):format(#next_commute.segments), true, 0)

					-- Print each of the segments in this route.
					for segment_index = 1, #next_commute.segments do
						d.print(("<line>: (Commuting.commute) Segment %s: %s"):format(segment_index, next_commute.segments[segment_index].commute_type), true, 0)
					end
				else
					table.insert(stored_commutes, next_commute)
				end

				::continue_next_best_commute::
			end

			::continue_next_commute::
		end
	end

	-- If the best commute is nil, then return nil.
	if not best_commute then
		d.print(("<line>: (Commuting.commute) No best commute found. Citizen: %s"):format(builder.citizen_id), true, 1)
		return
	end

	-- Create the active commute for the best commute.
	local active_commute = {
		id = g_savedata.libraries.commuting.next_active_commute_id,
		commute_builder = builder,
		commute_segments = best_commute.segments,
		current_segment_index = 1
	}

	-- Ensure there is no active commutes for this citizen already, if there is, remove it
	-- Remember kids, don't walk and drive...
	for existing_active_commute_index, existing_active_commute in pairs(g_savedata.libraries.commuting.active_commutes) do
		-- Check if the citizen id is the same
		if existing_active_commute.commute_builder.citizen_id == builder.citizen_id then
			-- Remove this existing commute.
			g_savedata.libraries.commuting.active_commutes[existing_active_commute_index] = nil
		end
	end

	-- Increment the next active commute id.
	g_savedata.libraries.commuting.next_active_commute_id = g_savedata.libraries.commuting.next_active_commute_id + 1

	-- Store the active commute.
	g_savedata.libraries.commuting.active_commutes[active_commute.id] = active_commute

	-- Return the active commute id.
	return active_commute.id
end

function Commuting.onTick(game_ticks)
	-- Go through each active commute.
	for _, active_commute in pairs(g_savedata.libraries.commuting.active_commutes) do
		-- Get the current segment.
		local current_segment = active_commute.commute_segments[active_commute.current_segment_index]

		-- Get the citizen.
		local citizen = Citizens.getData(active_commute.commute_builder.citizen_id)

		-- If the citizen is nil, then continue.
		if not citizen then
			d.print(("<line>: (Commuting.onTick) Citizen is nil for active commute %s. Index: %s"):format(active_commute.id, active_commute.current_segment_index), true, 1)
			goto continue
		end

		-- If their schedule's oop is not setup, skip.
		if type(citizen.schedule.tick) ~= "function" then
			goto continue
		end

		-- If the current segment is nil, then continue.
		if not current_segment then
			-- Tick their schedule, to clear it.
			citizen.schedule:tick()

			-- Skip to the next active commute.
			goto continue
		end

		-- Get the definition for this commute type.
		local commute_type_definition = commute_types[current_segment.commute_type]

		-- If this commute type has a tick function, then tick it.
		if commute_type_definition.tick then
			commute_type_definition.tick(
				current_segment.option_data,
				current_segment.route,
				game_ticks
			)
		end

		local debug_string = ""

		debug_string = ("%sSegment Type: %s\n"):format(debug_string, current_segment.commute_type)

		server.removeMapObject(-1, citizen.object_id + 14784)

		server.addMapObject(
			-1,
			citizen.object_id + 14784,
			0,
			1,
			citizen.transform[13],
			citizen.transform[15],
			0,
			0,
			0,
			0,
			citizen.name.full,
			10,
			debug_string,
			255,
			255,
			255,
			255
		)

		-- If the current segment is completed, then move to the next segment.
		if commute_type_definition.checkCompletion(current_segment.option_data, current_segment.route) then

			-- Call the end actions of the current segment, if it exists.
			if commute_type_definition.endActions then
				commute_type_definition.endActions(current_segment.option_data)
			end

			active_commute.current_segment_index = active_commute.current_segment_index + 1

			-- Call the start actions of the new segment, if it exists.
			local new_segment = active_commute.commute_segments[active_commute.current_segment_index]

			-- Ensure we got the next segment.
			if not new_segment then
				goto continue
			end

			local new_commute_type_definition = commute_types[new_segment.commute_type]

			-- Ensure we got the next commute type definition.
			if not new_commute_type_definition then
				d.print(("<line>: (Commuting.onTick) Commute type definition not found for %s"):format(new_segment.commute_type), true, 1)
				goto continue
			end

			if new_commute_type_definition.startActions then
				new_commute_type_definition.startActions(new_segment.option_data, new_segment.route)
			end
		end

		::continue::
	end
end

--[[

	Definitions

]]

require("libraries.imai.commuting.types.walkingCommute")
require("libraries.imai.commuting.types.drivingCommute")