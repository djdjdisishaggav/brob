-- Lobby client entry point.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("MushroomLobby")

local Config = require(Shared.Config)

-- This package belongs to the Lobby place only.
if game.PlaceId == Config.Places.Gameplay then
	return
end

require(script.Parent.App).start()
