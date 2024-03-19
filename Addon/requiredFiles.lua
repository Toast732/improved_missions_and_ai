--[[ 
	Just stores the files that main.lua requires, used to clean up main.lua
]]

--[[


	Required Files


]]

require("libraries.addon.utils.objects.object")

require("libraries.addon.commands.command.command") -- command handler, used to register commands.

require("libraries.imai.effects.effects")

require("libraries.imai.ai.citizens.citizens")

require("libraries.imai.missions.missions")

require("animations.animations")

require("missions.includedMissions")

require("libraries.imai.vehicles.driving.drivingVehicles")

require("libraries.imai.vehicles.vehicleUtilities.speedTracker")
require("libraries.imai.vehicles.routing.routing")
require("libraries.imai.vehicles.vehiclePrefab")

require("libraries.ai") -- functions relating to their AI
require("libraries.cache") -- functions relating to the cache
require("libraries.compatibility") -- functions used for making the mod backwards compatible
require("libraries.addon.script.debugging") -- functions for debugging
require("libraries.map") -- functions for drawing on the map
require("libraries.utils.math") -- custom math functions

require("libraries.utils.unitConversions")

require("libraries.utils.executionQueue")

require("libraries.addon.script.matrix") -- custom matrix functions
require("libraries.pathing.pathfinding") -- functions for pathfinding
require("libraries.addon.script.players") -- functions relating to Players
require("libraries.setup") -- functions for script/world setup.
require("libraries.spawningUtils") -- functions used by the spawn vehicle function
require("libraries.utils.string") -- custom string functions
require("libraries.utils.tables") -- custom table functions
require("libraries.addon.components.tags") -- functions related to getting tags from components inside of mission and environment locations
require("libraries.ticks") -- functions related to ticks and time
require("libraries.vehicle") -- functions related to vehicles, and parsing data on them
require("libraries.addon.script.addonCommunication")