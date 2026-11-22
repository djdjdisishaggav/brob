-- Lobby server entry point.

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("MushroomLobby")

local Config = require(Shared.Config)

-- This package belongs to the Lobby place only.
if game.PlaceId == Config.Places.Gameplay then
	return
end

local World = script.Parent.World
local LightingSetup = require(World.LightingSetup)
local LobbyBuilder = require(World.LobbyBuilder)
local PartyService = require(script.Parent.PartyService)

-- The lobby is normally baked into the place file (see docs/APPLY.md). Building
-- here keeps a place that has not been baked yet fully playable.
if not Workspace:FindFirstChild(Config.World.ModelName) then
	LobbyBuilder.build({ parent = Workspace })
end
LightingSetup.apply(Lighting)

PartyService.start()
