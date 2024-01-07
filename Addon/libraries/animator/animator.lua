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
require("libraries.addon.commands.flags")
require("libraries.utils.math")
require("libraries.addon.script.matrix")
require("libraries.addon.components.spawning.componentSpawner")

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[ 
	Animates vehicles.
]]

-- library name
Animator = {}

--[[


	Classes


]]

---@class KeyframeInstructionData

---@class KeyframeInstruction
---@field data KeyframeInstructionData the custom data for the keyframe instruction.

---@class KeyframeInstruction
---@field instruction_type string the type of keyframe instruction eg: "position", "rotation", "matrix", etc.
---@field data KeyframeInstructionData the custom data for the keyframe instruction.

---@class PositionalKeyframeInstructionData: KeyframeInstructionData
---@field x number the x position of the keyframe
---@field y number the y position of the keyframe
---@field z number the z position of the keyframe
---@field is_global boolean if the coordinates are global, if false, they are local to the origin.
---@field interpolation_type "linear"|"quadratic_bezier" the type of interpolation to use.
---@field p table<integer, table<string, number>> the points to use for more complex interpolations.

---@class PositionalKeyframeInstruction: KeyframeInstruction
---@field instruction_type "position" the type of keyframe instruction eg: "position", "rotation", "matrix", etc.
---@field data PositionalKeyframeInstructionData the custom data for the keyframe instruction.
---@field setQuadraticBezier fun(self: PositionalKeyframeInstruction, x: number, y: number, z: number) sets the quadratic bezier curve for the position.

---@alias KeyframeInstructionsPrefab table<integer, KeyframeInstruction>

---@alias KeyframeInstructions table<string, KeyframeInstruction> indexed by instruction type.

---@class Keyframe
---@field instructions KeyframeInstructions the instructions for the keyframe.
---@field time_milliseconds number how long this keyframe will be active for, keyframe will end after this many milliseconds after the previous one ended.

---@alias Keyframes table<integer, Keyframe>

---@class Animation
---@field keyframes Keyframes the keyframes for the animation.
---@field remove_collision boolean if you want to have collision removed on the animation. NOTE: ONLY WORKS FOR HOST IN MULTIPLAYER.
---@field animation_id AnimationID the id of the animation. (primary key for the registered_animations table)

---@alias AnimationID integer the id of the animation. (primary key for the registered_animations table)
---@alias AnimatorID integer the id of the animator. (primary key for the animator_ids table)
---@alias AnimatorIndex integer the index of the animator. (primary key for the active_animators table) NOTE: Volatile.

---@class ActiveAnimator
---@field animator_id AnimatorID the id of the animator. (primary key for the animator_ids table)
---@field spawning_data SpawningData the spawning data used when the animation was deployed. Used to respawn the animation if the vehicle is re-loaded.
---@field origin SWMatrix the animator's origin point.
---@field group_id integer the group id of the component.
---@field animation_id AnimationID the id of the animation to use. (primary key for the registered_animations table)
---@field keyframe_start_time number the time the last keyframe of the animation ended.
---@field keyframe_index integer the index of the current keyframe.
---@field last_matrix SWMatrix the matrix the time the last keyframe ended.

---@class DefinedAnimation
---@field internal_name string the internal name of the animation.
---@field name string the name of the animation.
---@field startAnimation fun(...) the function to call to start the animation.

---@alias DefinedAnimations table<string, DefinedAnimation> indexed by the internal name of the animation.

--[[


	Variables


]]

--- Stores the defined animations, can be used later to easily create the animation via command.
---@type DefinedAnimations
defined_animations = {}

g_savedata.animator = {

	---@type table<AnimatorID, AnimatorIndex>
	animator_ids = {}, -- Maps the animation id to the animation index.

	---@type table<AnimatorIndex, ActiveAnimator>
	active_animators = {}, -- Stores the active animators.

	---@type table<AnimationID, Animation>
	registered_animations = {}, -- Stores the registered animations, can be used later to get the animation, so it doesn't have to be re-created.

	---@type AnimationID
	next_animation_id = 1, -- The next animation id to use.

	---@type AnimatorID
	next_animator_id = 1 -- The next animator id to use.

}

--[[


	Functions


]]

--- Define an animation, should be used by the included animations.
---@param internal_name string the internal name of the animation.
---@param name string the name of the animation.
---@param startAnimation fun(...) the function to call to start the animation.
function Animator.define(internal_name, name, startAnimation)
	-- Create the defined mission
	---@type DefinedAnimation
	local defined_animation = {
		internal_name = internal_name,
		name = name,
		startAnimation = startAnimation
	}

	-- add it to the defined missions list
	defined_animations[internal_name] = defined_animation
end

---@param animation Animation the animation to use.
---@param spawning_data SpawningData the spawning data to use.
---@param origin SWMatrix the matrix to use as the origin.
---@return AnimatorID animator_id Returns 0 when is_success is false.
---@return boolean is_success
function Animator.deployAnimation(animation, spawning_data, origin)

	-- if the animation is set to make sure it has no collision
	if animation.remove_collision then
		-- ensure no scales are exactly 1.
		--TODO: Does not work if the zone is rotated.
		
		-- ensure x scale is not 1
		if origin[1] == 1 then
			origin[1] = 1.05
		end

		-- ensure y scale is not 1
		if origin[6] == 1 then
			origin[6] = 1.05
		end

		-- ensure z scale is not 1
		if origin[11] == 1 then
			origin[11] = 1.05
		end
	end

	-- spawn the component
	local component_data, is_success = ComponentSpawner.spawn(
		spawning_data,
		origin
	)

	-- if it failed to spawn the component
	if not is_success then
		d.print(("Failed to spawn component"), true, 1)
		return 0, false
	end

	-- get the animator id
	local animator_id = g_savedata.animator.next_animator_id
	-- increment the next animator id
	g_savedata.animator.next_animator_id = g_savedata.animator.next_animator_id + 1

	-- create and store the animator data
	table.insert(g_savedata.animator.active_animators,
		---@type ActiveAnimator
		{
			animator_id = animator_id,
			spawning_data = spawning_data,
			origin = origin,
			---@diagnostic disable-next-line: undefined-field
			group_id = component_data.group_id,
			animation_id = animation.animation_id,
			keyframe_start_time = server.getTimeMillisec(),
			keyframe_index = 1,
			last_matrix = origin
		}
	)

	-- get it's animation_index
	local animation_index = #g_savedata.animator.active_animators

	-- store that in the animator_ids table.
	g_savedata.animator.animator_ids[animator_id] = animation_index

	return animator_id, true
end

--- Function for creating an animation from a set of keyframes.
---@param keyframes Keyframes the keyframes for the animation.
---@param remove_collision boolean if you want to have collision removed on the animation. NOTE: ONLY WORKS FOR HOST IN MULTIPLAYER.
---@return Animation animation
function Animator.createAnimation(keyframes, remove_collision)

	-- if animator_debug is enabled, print the keyframes.
	if g_savedata.flags.animator_debug then
		d.print(("(Animator.createAnimation) Keyframes: %s"):format(string.fromTable(keyframes)), false, 0)
	end

	-- get the animation id
	local animation_id = g_savedata.animator.next_animation_id
	-- increment the next animation id
	g_savedata.animator.next_animation_id = g_savedata.animator.next_animation_id + 1

	-- store the animation
	g_savedata.animator.registered_animations[animation_id] = {
		keyframes = keyframes,
		remove_collision = remove_collision,
		animation_id = animation_id
	}
	
	-- return the animation
	return g_savedata.animator.registered_animations[animation_id]
end

--- Function for creating a keyframe from a set of instructions.
---@param keyframe_instructions KeyframeInstructionsPrefab the instructions for the keyframe.
---@param time number how long this keyframe will be active for, keyframe will end after this many seconds after the previous one ended.
---@return Keyframe keyframe
function Animator.createKeyframe(keyframe_instructions, time)

	-- if animator_debug is enabled, print the keyframe instructions.
	if g_savedata.flags.animator_debug then
		d.print("Keyframe Instructions:\n"..string.fromTable(keyframe_instructions), false, 0)
	end

	-- convert the time to ms
	local time_milliseconds = time*1000

	-- create the built keyframe instructions
	---@type KeyframeInstructions
	local built_keyframe_instructions = {}

	-- iterate through the keyframe instructions
	for keyframe_instruction_index = 1, #keyframe_instructions do
		keyframe_instruction = keyframe_instructions[keyframe_instruction_index]

		-- check if it's already added.
		if built_keyframe_instructions[keyframe_instruction.instruction_type] then
			
			-- print an error, two of the same type cannot be in the same keyframe.
			d.print(("Keyframe instruction type \"%s\" already exists in this keyframe! You can only have up-to one of each instruction type in a keyframe!"):format(keyframe_instruction.instruction_type), true, 1)
			
			-- return data early.
			return {
				instructions = built_keyframe_instructions,
				time_milliseconds = time_milliseconds
			}
		end

		-- add this instruction to the built keyframe instructions.
		built_keyframe_instructions[keyframe_instruction.instruction_type] = keyframe_instruction
	end

	-- if animator_debug is enabled, print the built keyframe instructions.
	if g_savedata.flags.animator_debug then
		d.print("Built Keyframe Instructions:\n"..string.fromTable(built_keyframe_instructions), false, 0)
	end

	-- return the keyframe
	return {
		instructions = built_keyframe_instructions,
		time_milliseconds = time_milliseconds
	}
end

--- Function for creating a position keyframe instruction, keyframes are made up with a table of instructions.
---@param x number the x position of the keyframe
---@param y number the y position of the keyframe
---@param z number the z position of the keyframe
---@param is_global boolean? if the coordinates are global, if false, they are local to the origin.
---@return PositionalKeyframeInstruction keyframe_instruction
function Animator.createPositionKeyframeInstruction(x, y, z, is_global)

	local positional_keyframe_instruction = {
		instruction_type = "position",
		data = {
			x = x,
			y = y,
			z = z,
			is_global = is_global or false,
			interpolation_type = "linear"
		}
	}

	--- Function for setting this positional keyframe to use quadratic bezier interpolation.
	---@param p1x number the x positon of p1 for keyframe
	---@param p1y number the y positon of p1 for keyframe
	---@param p1z number the z positon of p1 for keyframe
	---@return PositionalKeyframeInstruction keyframe_instruction
	function positional_keyframe_instruction:setQuadraticBezier(p1x, p1y, p1z)

		-- set the interpolation type
		self.data.interpolation_type = "quadratic_bezier"

		-- set the bezier points
		self.data.p = {
			{
				x = p1x,
				y = p1y,
				z = p1z
			}
		}

		return self
	end

	-- return the positional keyframe instructions.
	return positional_keyframe_instruction
end

--- Remove a animator from it's ID.
---@param animator_id AnimatorID the id of the animator to remove.
---@return boolean is_success
function Animator.removeAnimator(animator_id)
	-- Check if the animator exists
	if g_savedata.animator.animator_ids[animator_id] == nil then
		d.print(("Animator %s is not defined."):format(animator_id), true, 1)
		return false
	end

	-- get the animator index
	local animator_index = g_savedata.animator.animator_ids[animator_id]

	-- go through all vehicle ids in the group and despawn in
	local vehicle_ids = server.getVehicleGroup(g_savedata.animator.active_animators[animator_index].group_id)

	-- iterate through the vehicle ids
	for vehicle_index = 1, #vehicle_ids do
		-- despawn the vehicle
		server.despawnVehicle(vehicle_ids[vehicle_index], true)
	end

	-- remove the animator
	table.remove(g_savedata.animator.active_animators, animator_index)

	-- shift the animator indexes in animator_ids which were above this one.
	for _, iter_animator_index in pairs(g_savedata.animator.animator_ids) do
		if iter_animator_index > animator_index then
			g_savedata.animator.animator_ids[iter_animator_index] = animator_index - 1
		end
	end

	return true
end

--[[


	Internal Functions


]]

--[[


	Callbacks


]]

-- Update animations
function Animator.onTick(game_ticks)
	-- get the number of active animators
	local active_animator_count = #g_savedata.animator.active_animators

	-- if the number of active animators is 0, return early.
	if active_animator_count == 0 then
		return
	end

	-- get the current time (ms)
	local current_time_milliseconds = server.getTimeMillisec()

	-- iterate through the active animators
	for active_animator_index = active_animator_count, 1, -1 do

		-- get the active animator
		local active_animator = g_savedata.animator.active_animators[active_animator_index]

		-- get the animation
		local animation = g_savedata.animator.registered_animations[active_animator.animation_id]

		-- get the current keyframe
		local keyframe = animation.keyframes[active_animator.keyframe_index]

		-- get the new animation progress
		local keyframe_progress = math.min((current_time_milliseconds - active_animator.keyframe_start_time)/keyframe.time_milliseconds, 1)

		-- get the inverse animation progress (used to interpolate away from the last keyframe.)
		local inverse_keyframe_progress = 1 - keyframe_progress

		local new_target_matrix = matrix.clone(active_animator.origin)

		-- check if this keyframe has a position instruction
		if keyframe.instructions.position then
			-- if this is local to the origin
			---@type PositionalKeyframeInstruction
			local position_instructions = keyframe.instructions.position --[[@as PositionalKeyframeInstruction]]
			if not position_instructions.data.is_global then
				-- get the previous target position local to the matrix.
				local last_local_target = {
					x = active_animator.last_matrix[13] - active_animator.origin[13],
					y = active_animator.last_matrix[14] - active_animator.origin[14],
					z = active_animator.last_matrix[15] - active_animator.origin[15]
				}

				-- if interpolation type is linear
				if position_instructions.data.interpolation_type == "linear" then
					-- set the new position to set the vehicle to, interpolate with progress
					new_target_matrix[13] = active_animator.origin[13] + position_instructions.data.x*keyframe_progress + last_local_target.x*inverse_keyframe_progress
					new_target_matrix[14] = active_animator.origin[14] + position_instructions.data.y*keyframe_progress + last_local_target.y*inverse_keyframe_progress
					new_target_matrix[15] = active_animator.origin[15] + position_instructions.data.z*keyframe_progress + last_local_target.z*inverse_keyframe_progress
				-- if interpolation type is quadratic_bezier
				elseif position_instructions.data.interpolation_type == "quadratic_bezier" then
					-- x
					new_target_matrix[13] = math.quadraticBezier(
						last_local_target.x, -- the previous point
						position_instructions.data.x, -- the new point
						position_instructions.data.p[1].x, -- the control point
						keyframe_progress -- the keyframe progress
					) + active_animator.origin[13] -- add the origin

					-- y
					new_target_matrix[14] = math.quadraticBezier(
						last_local_target.y, -- the previous point
						position_instructions.data.y, -- the new point
						position_instructions.data.p[1].y, -- the control point
						keyframe_progress -- the keyframe progress
					) + active_animator.origin[14] -- add the origin

					-- z
					new_target_matrix[15] = math.quadraticBezier(
						last_local_target.z, -- the previous point
						position_instructions.data.z, -- the new point
						position_instructions.data.p[1].z, -- the control point
						keyframe_progress -- the keyframe progress
					) + active_animator.origin[15] -- add the origin
				end
			end
		end

		-- move the group's matrix.
		server.moveGroup(
			active_animator.group_id,
			new_target_matrix
		)

		-- if the progress is 1, then move to the next keyframe.
		if keyframe_progress == 1 then
			-- increment the keyframe index
			active_animator.keyframe_index = active_animator.keyframe_index + 1

			-- if the keyframe index is greater than the number of keyframes, return to the start
			if active_animator.keyframe_index > #animation.keyframes then
				-- return to the start
				active_animator.keyframe_index = 1
			end

			-- set the keyframe start time to the current time.
			active_animator.keyframe_start_time = current_time_milliseconds

			-- set the last matrix to the current matrix.
			active_animator.last_matrix = new_target_matrix
		end
	end
end

--[[


	Definitions


]]

-- Define a command to start an animation
Command.registerCommand(
	"start_animation",
	---@param full_message string the full message
	---@param peer_id integer the peer_id of the sender
	---@param arg table the arguments of the command.
	function(full_message, peer_id, arg)

		-- get the specified internal animation name
		local internal_animation_name = arg[1]

		-- Check if the animation is defined
		if defined_animations[internal_animation_name] == nil then
			d.print(("Animation %s is not defined."):format(internal_animation_name), false, 1, peer_id)
			return
		end

		-- remove the animation name from the arguments
		table.remove(arg, 1)

		d.print(("Starting Animation %s"):format(internal_animation_name), false, 0, peer_id)

		-- Call the mission start function
		defined_animations[internal_animation_name].startAnimation(peer_id, arg)
	end,
	"admin",
	"Starts the specified animation.",
	"Starts the specified animation, specified animation name must be it's internal name.",
	{"start_animation <internal_animation_name> [animation_args...]"}
)

-- Define a command to delete an active animator
Command.registerCommand(
	"delete_animator",
	---@param full_message string the full message
	---@param peer_id integer the peer_id of the sender
	---@param arg table the arguments of the command.
	function(full_message, peer_id, arg)

		-- get the specified animator id
		local animator_id = tonumber(arg[1])

		if not animator_id then
			d.print("Invalid animator id.", false, 1, peer_id)
			return
		end

		-- if the animator id is -1, delete all animators.
		if animator_id == -1 then

			-- iterate through all animators
			for animator_index = #g_savedata.animator.active_animators, 1, -1 do
				-- remove the animator
				Animator.removeAnimator(g_savedata.animator.active_animators[animator_index].animator_id)
			end

			d.print("Deleted all animators.", false, 0, peer_id)
		else
			local is_success = Animator.removeAnimator(animator_id)
			
			if is_success then
				d.print(("Deleted animator with id %s"):format(animator_id), false, 0, peer_id)
			end
		end
	end,
	"admin_script",
	"Starts the specified animation.",
	"Starts the specified animation, specified animation name must be it's internal name.",
	{"start_animation <internal_animation_name> [animation_args...]"}
)

-- Flag for detailed debug output.
Flag.registerBooleanFlag(
	"animator_debug",
	false,
	{
		"animations",
		"debug"
	},
	"admin",
	"admin",
	nil,
	"Enables detailed debug output for the animator library."
)