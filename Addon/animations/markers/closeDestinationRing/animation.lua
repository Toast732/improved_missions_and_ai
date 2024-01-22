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

-- Animation Version 0.0.2

--[[


	Animation Setup


]]

-- required libraries
require("libraries.addon.script.debugging")
require("libraries.animator.animator")
require("libraries.addon.components.spawning.componentSpawner")
require("libraries.imai.missions.objectives.objective")

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[ 
	Constructor for creating close destination rings.
]]

-- library name
Animations.markers.closeDestinationRing = {}

--[[


	Classes


]]

--[[


	Constants


]]

-- The close destination ring's length and width (in meters), assumed to be square.
CLOSE_DESTINATION_RING_LENGTH = 4

-- Speed when moving up (m/s)
CLOSE_DESTINATION_RING_MOVE_UP_TIME = 3

-- Speed when moving down (m/s)
CLOSE_DESTINATION_RING_MOVE_DOWN_TIME = 4

-- The scale of the height of the close destination ring, relative to the smallest of the length and width.
CLOSE_DESTINATION_RING_HEIGHT_SCALE = 0.5

--[[


	Variables


]]

INTERNAL_ANIMATION_NAME = "markers.closeDestinationRing"
ANIMATION_NAME = "Close Destination Ring"

--[[


	Functions


]]

--[[
	Creating the animation.
]]
---@param destination Destination the destination to spawn the ring at.
function Animations.markers.closeDestinationRing.create(destination)
	
	-- define the scale for this animation.
	local scale = {
		x = 1,
		y = CLOSE_DESTINATION_RING_HEIGHT_SCALE,
		z = 1
	}

	-- define the origin matrix
	local origin_matrix = matrix.identity()

	-- if this destination is a zone, scale by the zone dimensions.
	if destination.type == "zone" then
		scale.x = destination.zone.size.x/CLOSE_DESTINATION_RING_LENGTH -- set x scale to the zone's x size.
		scale.z = destination.zone.size.z/CLOSE_DESTINATION_RING_LENGTH -- set z scale to the zone's z size.
		scale.y = math.min(scale.x, scale.z)*CLOSE_DESTINATION_RING_HEIGHT_SCALE -- set the y scale to half the smallest dimension of the zone.

		-- set the origin matrix to the zone's matrix.
		origin_matrix = destination.zone.transform
	
	-- otherwise if this destination is a matrix, scale by the radius.
	elseif destination.type == "matrix" then
		scale.x = destination.radius/CLOSE_DESTINATION_RING_LENGTH -- set x scale to the radius.
		scale.z = destination.radius/CLOSE_DESTINATION_RING_LENGTH -- set z scale to the radius.
		scale.y = scale.x*CLOSE_DESTINATION_RING_HEIGHT_SCALE -- set the y scale to half the radius.

		origin_matrix = matrix.translation(
			destination.position.x,
			destination.position.y,
			destination.position.z
		)
	end

	-- set the height it should travel
	local travel_height = scale.y*CLOSE_DESTINATION_RING_LENGTH

	-- create the animation
	animation = Animator.createAnimation(
		{
			-- Keyframe 1: move up
			Animator.createKeyframe(
				{ -- move up
					Animator.createPositionKeyframeInstruction(
						0,
						travel_height, -- move up to desired height
						0,
						false
					):setQuadraticBezier(
						0,
						travel_height*1.2,
						0
					)
				},
				CLOSE_DESTINATION_RING_MOVE_UP_TIME -- set seconds to match our desired up movement speed
			),
			-- Keyframe 2: move down
			Animator.createKeyframe(
				{
					Animator.createPositionKeyframeInstruction(
						0,
						-travel_height, -- move down to the lower desired height
						0,
						false
					):setQuadraticBezier(
						0,
						travel_height*-1.2,
						0
					)
				},
				CLOSE_DESTINATION_RING_MOVE_DOWN_TIME -- set seconds to match our desired down movement speed
			)
		},
		true, -- remove collision
		-1 -- loop infinitely
	)

	--[[
		Find the close destination ring vehicle.
	]]

	-- Create the filter for the close destination ring vehicle.
	local close_destination_ring_vehicle_filter = ComponentSpawner.createFilter()

	-- Configure the filter to discard env mods
	close_destination_ring_vehicle_filter:setEnvModHandling(COMPONENT_FILTER_ENV_MOD_HANDLING.NOT_ALLOWED)

	-- Configure the filter to require the tag "imai"
	close_destination_ring_vehicle_filter:addTag("imai", false)

	-- Configure the filter to require the tag "animation_object"
	close_destination_ring_vehicle_filter:addTag("animation_object", false)

	-- Configure the filter to require the tag "close_destination_ring"
	close_destination_ring_vehicle_filter:addTag("close_destination_marker", false)

	-- Get the spawning data for the close destination ring vehicle, fallback to first.
	local close_destination_ring_vehicle_spawning_data, is_success = close_destination_ring_vehicle_filter:getSpawningData(SPAWNING_DATA_FALLBACK.FIRST)

	-- if the spawning data was not found, stop here to prevent an error.
	if not is_success then
		d.print(("Could not find close destination ring vehicle, please make sure it exists."), true, 1)
		return
	end

	-- set the scale of the origin matrix
	--TODO: Currently, will not work if the zone is rotated.
	origin_matrix[1] = scale.x
	origin_matrix[6] = scale.y
	origin_matrix[11] = scale.z

	-- Deploy the animation.
	local animator_id, deploy_success = Animator.deployAnimation(
		animation,
		close_destination_ring_vehicle_spawning_data,
		origin_matrix
	)

	return animator_id
end

--[[


	Definitions


]]

-- define the animation
Animator.define(
	INTERNAL_ANIMATION_NAME,
	ANIMATION_NAME,
	---@param peer_id integer the peer_id of the sender
	---@param arg table the arguments of the command.
	function(peer_id, arg)

		local radius = tonumber(arg[1]) or 5

		local player_pos = server.getPlayerPos(peer_id)

		Animations.markers.closeDestinationRing.create(
			Objective.destination.matrix(
				player_pos,
				radius
			)
		)
	end
)