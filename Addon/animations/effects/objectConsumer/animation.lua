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

-- Animation Version 0.0.1

--[[


	Animation Setup


]]

-- required libraries
require("libraries.addon.script.debugging")
require("libraries.addon.callbacks.binder.binder")
require("libraries.animator.animator")
require("libraries.addon.components.spawning.componentSpawner")
require("libraries.imai.missions.objectives.objective")

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[ 
	Constructor for creating object consumers.
]]

-- library name
Animations.effects.objectConsumer = {}

--[[


	Classes


]]

--[[


	Constants


]]

-- The object consumer's length and width (in meters), assumed to be square.
OBJECT_CONSUMER_LENGTH = 1.5

-- The time it just waits at the top.
OBJECT_CONSUMER_UP_WAIT_TIME = 0.1

-- The time it takes to move down fully
OBJECT_CONSUMER_MOVE_DOWN_TIME = 0.5

-- The time it waits at the bottom.
OBJECT_CONSUMER_DOWN_WAIT_TIME = 2

-- The height of the object consumer (m)
OBJECT_CONSUMER_HEIGHT = 6

--[[


	Variables


]]

g_savedata.included_animations.effects.objectConsumer = {
	---@type table<integer, integer> the vehicle_ids of the animators we are waiting for to spawn.
	awaiting_animator_vehicle_ids = {}
}

INTERNAL_ANIMATION_NAME = "effects.objectConsumer"
ANIMATION_NAME = "Object Consumer"

--[[


	Functions


]]

--[[
	Creating the animation.
]]
---@param object_id integer the object to consume.
function Animations.effects.objectConsumer.create(object_id)

	-- get the object radius (right now, just assumed to be 1, will need to put in a proper system for this later.)
	local object_radius = 1

	local animation_xz_scale = object_radius/OBJECT_CONSUMER_LENGTH * 1.25
	
	-- define the scale for this animation.
	local scale = {
		x = animation_xz_scale,
		y = 1,
		z = animation_xz_scale
	}

	-- get the object's position
	local object_matrix = server.getObjectPos(object_id)

	-- define the origin matrix
	local origin_matrix = matrix.translation(
		object_matrix[13],
		object_matrix[14],
		object_matrix[15]
	)

	-- get the wait height
	local wait_height = object_radius + origin_matrix[14] - OBJECT_CONSUMER_HEIGHT * 0.5

	-- set the origin matrix y to the wait height
	origin_matrix[14] = wait_height

	-- create the animation
	animation = Animator.createAnimation(
		{
			-- Keyframe 1: wait at the top
			Animator.createKeyframe(
				{ -- move up
					Animator.createPositionKeyframeInstruction(
						0,
						0, -- stay at wait height.
						0,
						false
					)
				},
				OBJECT_CONSUMER_UP_WAIT_TIME -- wait for the desired time
			),
			-- Keyframe 2: Move Down
			Animator.createKeyframe(
				{
					Animator.createPositionKeyframeInstruction(
						0,
						OBJECT_CONSUMER_HEIGHT*-0.5, -- move down to the lower desired height
						0,
						false
					):setQuadraticBezier(
						0,
						0,
						0
					)
				},
				OBJECT_CONSUMER_MOVE_DOWN_TIME -- set seconds to match our desired down movement speed
			),
			-- Keyframe 3: Wait at the bottom
			Animator.createKeyframe(
				{
					Animator.createPositionKeyframeInstruction(
						0,
						-OBJECT_CONSUMER_HEIGHT, -- stay at the lower desired height
						0,
						false
					)
				},
				OBJECT_CONSUMER_DOWN_WAIT_TIME -- wait for the desired time
			)
		},
		true, -- remove collision
		1 -- only run once.
	)

	--[[
		Find the close destination ring vehicle.
	]]

	-- Create the filter for the close destination ring vehicle.
	local object_consumer_vehicle_filter = ComponentSpawner.createFilter()

	-- Configure the filter to discard env mods
	object_consumer_vehicle_filter:setEnvModHandling(COMPONENT_FILTER_ENV_MOD_HANDLING.NOT_ALLOWED)

	-- Configure the filter to require the tag "imai"
	object_consumer_vehicle_filter:addTag("imai", false)

	-- Configure the filter to require the tag "animation_object"
	object_consumer_vehicle_filter:addTag("animation_object", false)

	-- Configure the filter to require the tag "object_consumer"
	object_consumer_vehicle_filter:addTag("object_consumer", false)

	-- Get the spawning data for the object consumer vehicle, fallback to first.
	local object_consumer_vehicle_spawning_data, is_success = object_consumer_vehicle_filter:getSpawningData(SPAWNING_DATA_FALLBACK.FIRST)

	-- if the spawning data was not found, stop here to prevent an error.
	if not is_success then
		d.print(("Could not find object consumer vehicle, please make sure it exists."), true, 1)
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
		object_consumer_vehicle_spawning_data,
		origin_matrix
	)

	-- Get the animator
	local animator = Animator.getAnimator(animator_id)

	-- Check if we got the animator
	if animator then

		-- Get the list of vehicle_ids for this group_id
		local vehicle_ids = server.getVehicleGroup(animator.group_id)

		-- add each of the vehicle_ids to the list of vehicle_ids we are waiting for to spawn.
		for vehicle_index = 1, #vehicle_ids do
			local vehicle_id = vehicle_ids[vehicle_index]
			-- Add it to the list of vehicle_ids we are waiting for to spawn.
			g_savedata.included_animations.effects.objectConsumer.awaiting_animator_vehicle_ids[vehicle_id] = object_id
		end
	else
		-- Otherwise, print an error
		d.print(("(objectConsumer) Failed to get animator for object consumer animation."),  true, 1)

		-- Just remove the object now.
		server.despawnObject(object_id, true)
	end

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

		local object_type = tonumber(arg[1]) or 2

		local player_pos = server.getPlayerPos(peer_id)

		local object_id = server.spawnObject(player_pos, object_type)

		Animations.effects.objectConsumer.create(
			object_id
		)
	end
)

-- define the callback to delete the objects
Binder.bind.onVehicleLoad(
	---@param vehicle_id integer the vehicle_id of the spawned vehicle.
	function(vehicle_id)

		d.print(("(objectConsumer) on group spawn called for vehicle_id %d."):format(vehicle_id), true, 0)

		d.print(string.fromTable(g_savedata.included_animations.effects.objectConsumer.awaiting_animator_vehicle_ids), true, 0)
		-- get the object_id we are waiting for.
		local object_id = g_savedata.included_animations.effects.objectConsumer.awaiting_animator_vehicle_ids[vehicle_id]

		-- remove the vehicle_id from the list of vehicle_ids we are waiting for to spawn.
		g_savedata.included_animations.effects.objectConsumer.awaiting_animator_vehicle_ids[vehicle_id] = nil

		-- if the object_id is nil, stop here.
		if not object_id then
			return
		end

		-- despawn the object.
		server.despawnObject(object_id, true)
	end
)