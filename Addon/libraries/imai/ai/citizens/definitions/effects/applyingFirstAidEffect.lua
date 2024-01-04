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
require("libraries.imai.effects.effects")

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[ 
	Defines the applying first aid effect, which is used to discharge the first aid healing, and cools down the player's ability to heal
	the citizen, to simulate the player actively applying bandages or tourniquets on them.
]]

--[[Classes]]

--[[Variables]]

--[[


	Functions


]]

Effects.define(
	"applying_first_aid",
	{
		"citizen"
	},
	function(citizen)
		-- add applying_first_aid status.
		Citizens.Status.add(citizen, "applying_first_aid", "Applying First Aid...", 10000)
	end,
	function(citizen)
		-- remove applying_first_aid status.
		Citizens.Status.remove(citizen, "applying_first_aid")
	end,
	nil
)