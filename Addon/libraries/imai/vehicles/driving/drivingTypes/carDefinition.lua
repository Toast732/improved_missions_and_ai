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
require("libraries.utils.vector2")
require("libraries.addon.script.matrix")

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[ 
	Sets up the driving behaviour of cars.
]]

--[[


	Constants


]]

-- The distance to project the paths to.
CAR_PATH_MAX_PROJECTION_DISTANCE = 20

-- The distance to look ahead for upcoming turns.
CAR_PATH_LOOK_AHEAD_DISTANCE = 150

--[[


	Functions


]]

-- Define/Get the land driving type.
land_driving_type = DrivingVehicles.define(DRIVABLE_VEHICLE_TYPE.LAND)

-- Define the car driving style.
land_driving_style = land_driving_type:defineStyle("car")

-- Define the normal driving state
land_normal_driving_state = land_driving_style:defineState("normal")

-- Define the normal car driving condition (driving normally).
land_normal_driving_state:defineCondition(
	"normal",
	1,
	DrivableVehicle.hasNextNode,
	function(drivable_vehicle)
		-- Get an empty seat input identity.
		local seat_input = DrivableVehicle.getSeatInputIdentity()

		-- Set that the engine is on
		seat_input.button1 = true

		-- Get it's path.
		local path = Routing.getPathFromID(drivable_vehicle.route.stored_path_id)

		-- Cast that path cannot be nil, as if it was, DrivableVehicle.hasNextNode would've returned false.
		---@cast path -nil

		-- Alias variables creating previous_node and target_node
		local previous_node = path[drivable_vehicle.route.path_index]

		local target_node = path[drivable_vehicle.route.path_index + 1]

		-- Create vectors of the nodes.
		local previous_node_vec2 = Vector2.new(previous_node.x, previous_node.z)

		local target_node_vec2 = Vector2.new(target_node.x, target_node.z)

		-- Create a vector2 of the vehicle's position
		local vehicle_position_vec2 = Vector2.fromMatrix(drivable_vehicle.transform, true)

		-- Get the projected target pos
		local projected_position, projection_distance = Vector2.scalarProjection(
			vehicle_position_vec2,
			previous_node_vec2,
			target_node_vec2,
			CAR_PATH_MAX_PROJECTION_DISTANCE
		)

		server.removeMapLine(-1, 10000512)
		server.addMapLine(-1, 10000512, drivable_vehicle.transform, matrix.translation(projected_position.x, 0, projected_position.y), 1, 0, 0, 255, 255)

		-- If our projection distance is less than the consumption distance, go to the next node, for the next tick.
		if projection_distance < CAR_PATH_MAX_PROJECTION_DISTANCE / 2 then
			-- Increment the path index
			drivable_vehicle.route.path_index = drivable_vehicle.route.path_index + 1
		end

		-- Get the angle the vehicle is facing
		local _, yaw, _ = matrix.getMatrixRotation(drivable_vehicle.transform)

		-- Get the angle to the target
		local target_angle = Vector2.angleBetween(vehicle_position_vec2, projected_position)

		-- Set the a/d input.
		seat_input.axis_d = -math.wrap(yaw - target_angle, -math.pi, math.pi)

		-- Get the upcoming turn data
		local upcoming_turn_data = DrivableVehicle.getUpcomingTurnData(drivable_vehicle, CAR_PATH_LOOK_AHEAD_DISTANCE)

		-- If the upcoming turn data is nil, return the seat input.
		if not upcoming_turn_data then
			return seat_input
		end

		-- Store the vehicle's target speed to compare later
		local base_target_speed = drivable_vehicle.max_speed

		-- Set the vehicle's target speed
		local bent_target_speed = base_target_speed

		for i = 1, 20 do
			server.removeMapLabel(-1, 10000512)
		end

		--server.addMapLabel(-1, 10000512, 2, ("Angle: %0.2f\nx: %0.1f\nz: %0.1f"):format(yaw, vehicle_position_vec2.x, vehicle_position_vec2.y), vehicle_position_vec2.x, vehicle_position_vec2.y)

		-- For each bend in the upcoming turn data, reduce the target speed depending upon the bend's angle.
		for bend_index = 1, #upcoming_turn_data do

			-- Get the bend node data
			local bend_node_data = upcoming_turn_data[bend_index]

			-- Add to the map.
			server.addMapLabel(-1, 10000512, 2, ("Angle: %0.2f\nx: %0.1f\nz: %0.1f"):format(bend_node_data.angle, bend_node_data.position.x, bend_node_data.position.z), bend_node_data.position.x, bend_node_data.position.z)

			-- Get the distance ratio
			local bend_distance_ratio = 1 - math.clamp(bend_node_data.distance / CAR_PATH_LOOK_AHEAD_DISTANCE, 0, 1)

			-- Get the bend speed reduction
			local bend_speed_reduction = math.clamp(1 - math.abs(bend_node_data.angle * bend_distance_ratio) / math.half_pi, 0.2, 1)

			-- Reduce the target speed
			bent_target_speed = math.max(bent_target_speed * bend_speed_reduction, base_target_speed * 0.2)

			-- If the target speed is equal to 20% of the vehicle's base target speed, return.
			if bent_target_speed == base_target_speed * 0.2 then
				break
			end
		end

		-- Set the w/s input.
		seat_input.axis_w = bent_target_speed / drivable_vehicle.max_speed

		-- Get the vehicle's current speed.
		local current_speed = DrivableVehicle.getSpeed(drivable_vehicle)

		-- Get the difference as a ratio between the vehicle's target speed and it's current speed.
		local speed_difference_ratio = 1 - current_speed / bent_target_speed

		-- If the speed difference ratio says that the vehicle needs to increase in speed by at least 20%, increase the w/s input depending upon the difference.
		if speed_difference_ratio > 0.2 then
			seat_input.axis_w = math.min(seat_input.axis_w + speed_difference_ratio * 0.5, 1)
		
		-- If the speed difference ratio says that the vehicle needs to decrease in speed by at least 10%, decrease the w/s input depending upon the difference.
		elseif speed_difference_ratio < -0.1 then
			seat_input.axis_w = math.max(seat_input.axis_w + speed_difference_ratio * 0.5, 0)
		end

		-- If the speed difference ratio says that the vehicle needs to decrease in speed by at least 30%, set the up/down (brakes) input depending upon the difference.
		if speed_difference_ratio < -0.3 then
			seat_input.axis_up = math.min(speed_difference_ratio * -0.25, 1)
		end

		-- If the brakes have been applied at all, set the w/s input to 0.
		if seat_input.axis_up < 0 then
			seat_input.axis_w = 0
		end

		-- Get the generic vehicle
		local generic_vehicle = Vehicle.getGenericVehicle(drivable_vehicle.generic_vin)

		drivable_vehicle.temp_ui_id = drivable_vehicle.temp_ui_id or server.getMapID()

		--server.removePopup(-1, drivable_vehicle.temp_ui_id)
		server.setPopup(-1, drivable_vehicle.temp_ui_id, "eaw", true, ("Speed: %s\nTarget Speed: %s"):format(current_speed, bent_target_speed), 0, 0, 0, 2500, generic_vehicle.vehicle_ids[1], 0)
		
		-- Return the seat input
		return seat_input
	end
)

-- Define the stopped car driving condition (stopped)
land_normal_driving_state:defineCondition(
	"stopped_reached_end",
	0,
	true,
	function(vehicle)
		-- Return an empty seat input.
		return DrivableVehicle.getSeatInputIdentity()
	end
)