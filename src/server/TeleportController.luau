-- Sends a party to the gameplay place on its own reserved server.
-- The run configuration travels as teleport data set by the server, which the
-- gameplay place reads with Player:GetJoinData().TeleportData.

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("MushroomLobby")

local Config = require(Shared.Config)

export type RunData = {
	version: number,
	partyId: string,
	stationId: string,
	leaderUserId: number,
	memberUserIds: { number },
	chapterId: string,
	difficultyId: string,
	peaceful: boolean,
	maxSize: number,
}

local TeleportController = {}

-- Called when Roblox reports that a player's teleport could not start.
TeleportController.onPlayerFailed = nil :: ((player: Player, message: string) -> ())?

local started = false

function TeleportController.start()
	if started then
		return
	end
	started = true
	TeleportService.TeleportInitFailed:Connect(function(player, _, message)
		if TeleportController.onPlayerFailed then
			TeleportController.onPlayerFailed(player, message or "")
		end
	end)
end

local function stillHere(players: { Player }): { Player }
	local present = {}
	for _, player in players do
		if player.Parent == Players then
			table.insert(present, player)
		end
	end
	return present
end

-- Yields. Returns true once Roblox accepted the teleport request for the
-- players still in the server, or false with a Net.Messages code.
function TeleportController.teleport(players: { Player }, data: RunData): (boolean, string?)
	local placeId = Config.Places.Gameplay
	local attempts = math.max(1, Config.Party.TeleportMaxAttempts)

	-- One reserved server for every attempt, so a retry lands the party together.
	local accessCode: string? = nil
	for attempt = 1, attempts do
		local present = stillHere(players)
		if #present == 0 then
			return false, "TeleportFailed"
		end
		local ok, err = pcall(function()
			if not accessCode then
				accessCode = TeleportService:ReserveServer(placeId)
			end
			local options = Instance.new("TeleportOptions")
			options.ReservedServerAccessCode = accessCode :: string
			options:SetTeleportData(data)
			TeleportService:TeleportAsync(placeId, present, options)
		end)
		if ok then
			return true, nil
		end
		warn(`[MushroomLobby] teleport attempt {attempt}/{attempts} failed: {err}`)
		if attempt < attempts then
			task.wait(Config.Party.TeleportRetryDelaySeconds)
		end
	end
	return false, "TeleportFailed"
end

return TeleportController
