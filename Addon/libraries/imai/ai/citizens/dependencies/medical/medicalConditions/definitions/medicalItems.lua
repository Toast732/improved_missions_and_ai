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

--[[

	Registers the medical items to the registers.

]]

-- required libraries
require("libraries.addon.utils.objects.characters.inventory.item")

Item.createPrefab(
	"bandage",
	nil,
	{
		applied_time = 0
	}
)

Item.createPrefab(
	"tourniquet",
	nil,
	{
		applied_time = 0,
		tightened = false
	}
)