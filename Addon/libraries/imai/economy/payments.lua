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
require("libraries.addon.script.players")

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field

--[[ 
	Simple library for paying the players. Put in it's own seperate library to make it easier to modify,
		that way it's easy to modify the addon to work with external economy addons.
]]

-- library name
Payments = {}

--[[


	Functions


]]

---@param player Player|nil the player to pay. If nil, then it will pay all players.
---@param money number the amount of money to pay the player.
---@param research_points number the amount of research points to pay the player.
function Payments.transact(player, money, research_points)

	--* NOTE: This is for the non modded currency system, pays all players as normal.

	-- get the amount of currency they currently have.
	local current_currency = server.getCurrency()

	-- get the number of research points they currently have.
	local current_research_points = server.getResearchPoints()

	-- complete the transaction.
	server.setCurrency(
		current_currency + money,
		current_research_points + research_points
	)
end