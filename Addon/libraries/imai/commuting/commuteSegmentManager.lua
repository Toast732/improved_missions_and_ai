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
require("libraries.imai.commuting.communting")

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[
	This file handles the commute segments, making it easier and cleaner to manage the commutes, for example, this makes it easy to insert a new segment into
	the middle of a commute, or to remove a segment from the middle of a commute, which could be used in carpooling.
]]

-- library name
CommuteSegmentManager = {}

--[[


	Classes


]]

---@alias CommuteSegmentIndex integer the index of the current segment.

---@class CommuteSegment
---@field commute_type CommuteType the type of commute this segment is.
---@field option_data CommuteBaseOptionData the data for this segment.
---@field route Route the route for this segment.

---@alias CommuteSegments table<CommuteSegmentIndex, CommuteSegment>

---@class DirtyCommuteSegmentManager
---@field builder CommuteBuilder the builder for this commute.
---@field segments CommuteSegments the segments of this commute.
---@field start_connected boolean if the start of this commute is connected to the origin.
---@field end_connected boolean if the end of this commute is connected to the desination.
---@field cost CommuteCost the total cost of this commute.

---@class CommuteSegmentManager: DirtyCommuteSegmentManager
---@field insertSegment fun(self: CommuteSegmentManager, index: CommuteSegmentIndex, segment: CommuteSegment) the function to insert a segment into the commute.
---@field duplicate fun(self: CommuteSegmentManager): CommuteSegmentManager the function to duplicate the segment manager.
---@field getNextTargetPoints fun(self: CommuteSegmentManager): Vector3, Vector3, SEGMENT_CONNECTING_TO the function to get the next origin and destination points to connect.
---@field canInsert fun(self: CommuteSegmentManager, index: CommuteSegmentIndex, commute_type: CommuteType): boolean the function to check if a segment of a specific type can be inserted at the index.
---@field drawDebug fun(self: CommuteSegmentManager) draws map debug for each of the segments

--[[


	Constants


]]

-- The distance the start or end of a segment can be from the origin or destination to be considered connected.
SEGMENT_COMPLETE_DISTANCE = 10

---@enum SEGMENT_CONNECTING_TO
COMMUTE_CONNECTING_TO = {
	START = 1,
	END = 2
}

--[[


	Variables


]]

g_savedata.libraries.commuting = {
}

--[[


	Functions


]]

--- This function is used to create a new commute segment manager.
---@param builder CommuteBuilder
---@return CommuteSegmentManager the new commute segment manager.
function CommuteSegmentManager.new(builder)

	-- Create the segment manager.
	---@type DirtyCommuteSegmentManager
	local commute_segment_manager = {
		builder = builder,
		segments = {},
		start_connected = false,
		end_connected = false,
		cost = 0
	}

	-- Return the segment manager after setting up the OOP functions.
	return CommuteSegmentManager.setup(commute_segment_manager)
end

--- Function for cleaning a commute segment manager, where it will add the oop functions (used upon reload)
---@param commute_segment_manager DirtyCommuteSegmentManager|CommuteSegmentManager
---@return CommuteSegmentManager
function CommuteSegmentManager.setup(commute_segment_manager)
	---@cast commute_segment_manager CommuteSegmentManager

	--- Function for inserting a segment into the commute.
	---@param self CommuteSegmentManager the segment manager to insert the segment into.
	---@param index CommuteSegmentIndex the index to insert the segment at.
	---@param segment CommuteSegment the segment to insert.
	function commute_segment_manager.insertSegment(self, index, segment)
		-- Insert the segment.
		table.insert(self.segments, index, segment)

		d.print("<line>: (CommuteSegmentManager.insertSegment) Segment commute_type: "..segment.commute_type, true, 0)

		-- Update the cost.
		self.cost = self.cost + commute_types[segment.commute_type].getCost(segment.option_data, segment.route)

		-- If this is not an interim segment, skip the next checks.
		if not commute_types[segment.commute_type].interim then
			return
		end

		-- If the index for this segment is the start (1) check if the start is connected.
		if index == 1 then

			-- Check if we're within the complete distance
			self.start_connected = Vector3.euclideanDistance(
				Vector3.fromMatrix(
					segment.route.start_matrix,
					true
				),
				self.builder.origin
			) <= SEGMENT_COMPLETE_DISTANCE

			d.print(("<line>: (CommuteSegmentManager.insertSegment) Start connected: %s"):format(tostring(self.start_connected)), true, 0)
		end

		-- If the index for this segment is the last one, check if the end is connected.
		if index == #self.segments then

			-- Check if we're within the complete distance
			self.end_connected = Vector3.euclideanDistance(
				Vector3.fromMatrix(
					segment.route.end_matrix,
					true
				),
				self.builder.destination
			) <= SEGMENT_COMPLETE_DISTANCE

			d.print(("<line>: (CommuteSegmentManager.insertSegment) End connected: %s"):format(tostring(self.end_connected)), true, 0)
		end
	end

	--- Function for duplicating the segment manager.
	---@param self CommuteSegmentManager the segment manager to duplicate.
	---@return CommuteSegmentManager the duplicated segment manager.
	function commute_segment_manager.duplicate(self)
		-- Create a new segment manager.
		duplicated_segment_manager = CommuteSegmentManager.new(self.builder)

		-- For each of the segments in this segment manager, insert them into the duplicated segment manager.
		for segment_index, segment in pairs(commute_segment_manager.segments) do
			
			-- Insert the segment into the duplicated segment manager.
			duplicated_segment_manager:insertSegment(segment_index, segment)
		end

		-- Return the duplicated segment manager.
		return duplicated_segment_manager
	end

	--- Function to get the next origin and destination points to connect, if we've yet to connect to the end, then connect to the end, after, then focus on the start.
	---@param self CommuteSegmentManager the segment manager to get the next origin and destination points to connect.
	---@return Vector3 target_origin the next origin point to connect to.
	---@return Vector3 target_destination the next destination point to connect to.
	---@return SEGMENT_CONNECTING_TO segment_connecting_to the segment to connect to (start or end).
	function commute_segment_manager.getNextTargetPoints(self)

		-- If we've reached our destination, then focus on the start
		if self.end_connected then
			return 
				self.builder.origin,
				Vector3.fromMatrix(self.segments[1].route.start_matrix, true),
				COMMUTE_CONNECTING_TO.START

		-- Otherwise, focus on the end.
		else
			return 
				Vector3.fromMatrix(self.segments[#self.segments].route.end_matrix, true),
				self.builder.destination,
				COMMUTE_CONNECTING_TO.END
		end
	end

	--- Function to check if we can insert a segment of a specific type at the index.
	---@param self CommuteSegmentManager the segment manager to check if we can insert a segment of a specific type at the index.
	---@param index CommuteSegmentIndex the index to check if we can insert the segment at.
	---@param commute_type CommuteType the definition of the segment to check if we can insert.
	---@return boolean can_insert if we can insert the segment at the index.
	function commute_segment_manager.canInsert(self, index, commute_type)
		-- Get the index before us.
		local previous_index = index - 1

		-- Get the index after us (which will be this index after we're inserted, so check that one.)
		local next_index = index

		-- Get the previous segment.
		local previous_segment = self.segments[previous_index]

		-- Get the next segment.
		local next_segment = self.segments[next_index]

		-- If the previous segment exists, and it's the same type, we cannot insert.
		if previous_segment and previous_segment.commute_type == commute_type then
			return false
		end

		-- If the next segment exists, and it's the same type, we cannot insert.
		if next_segment and next_segment.commute_type == commute_type then
			return false
		end

		-- Otherwise, we can insert.
		return true
	end

	--- Draws debug on each of the segments.
	---@param self CommuteSegmentManager the segment manager to draw debug for.
	function commute_segment_manager.drawDebug(self)
		for segment_index = 1, #self.segments do

			-- Get the segment.
			local segment = self.segments[segment_index]

			-- Get the path for this route.
			local path = Routing.getPathFromID(segment.route.stored_path_id)

			-- If the path is nil, then skip.
			if not path then
				goto continue
			end

			-- Go through all of the nodes in this path.
			for node_index = 2, #path.path_list do
				-- Get this node.
				local node = path.path_list[node_index]

				-- Get the previous node.
				local previous_node = path.path_list[node_index - 1]

				-- Draw a line.
				server.addMapLine(
					0,
					1258901724,
					Vector3.toMatrix(
						Vector3.new(
							previous_node.x,
							previous_node.y,
							previous_node.z
						)
					),
					Vector3.toMatrix(
						Vector3.new(
							node.x,
							node.y,
							node.z
						)
					),
					1,
					segment.commute_type == "Walking" and 0 or 255,
					0,
					segment.commute_type == "Walking" and 255 or 0,
					125
				)
			end

			::continue::
		end
	end
		

	return commute_segment_manager
end

--[[

	Definitions

]]