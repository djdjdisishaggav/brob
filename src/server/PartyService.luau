-- Server authority for parties. Owns the remotes, validates every client
-- request, applies it to PartyLogic and replicates the resulting state.
-- Clients never decide anything: they send intents and render snapshots.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("MushroomLobby")

local Config = require(Shared.Config)
local Net = require(Shared.Net)

local PartyLogic = require(script.Parent.PartyLogic)
local ProfileService = require(script.Parent.ProfileService)
local StationService = require(script.Parent.StationService)
local TeleportController = require(script.Parent.TeleportController)

local Action = Net.Action
local Topic = Net.Topic

local TICK_INTERVAL = 0.25

local PartyService = {}

local logic: PartyLogic.PartyLogic
local pushRemote: RemoteEvent
local buckets: { [Player]: { tokens: number, at: number } } = {}
local started = false

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function userOf(player: Player): PartyLogic.User
	return { userId = player.UserId, name = player.Name, displayName = player.DisplayName }
end

local function push(player: Player?, topic: string, payload: any)
	if player and player.Parent == Players then
		pushRemote:FireClient(player, topic, payload)
	end
end

local function result(ok: boolean, value: any): Net.Result
	if ok then
		return Net.ok(value)
	end
	return Net.fail(value)
end

local function runTeleport(partyId: string)
	local party = logic:GetParty(partyId)
	if not party then
		return
	end
	local players = {}
	local memberUserIds = {}
	for _, member in party.members do
		local player = Players:GetPlayerByUserId(member.userId)
		if player then
			table.insert(players, player)
			table.insert(memberUserIds, member.userId)
		end
	end
	local ok, code = TeleportController.teleport(players, {
		version = 1,
		partyId = party.id,
		stationId = party.stationId,
		leaderUserId = party.leaderUserId,
		memberUserIds = memberUserIds,
		chapterId = party.chapterId,
		difficultyId = party.difficultyId,
		peaceful = party.peaceful,
		maxSize = party.maxSize,
	})
	if not ok then
		logic:TeleportFailed(partyId, code)
		PartyService.flush()
	end
end

-- Turns the logic's queued effects into replication. Called after every
-- request and every tick.
function PartyService.flush()
	local effects = logic:DrainEffects()
	if #effects == 0 then
		return
	end

	local parties: { [string]: boolean } = {}
	local stations: { [string]: boolean } = {}
	local left: { [number]: boolean } = {}
	local teleports: { string } = {}

	for _, effect in effects do
		if effect.type == "party" and effect.partyId then
			parties[effect.partyId] = true
		elseif effect.type == "station" and effect.stationId then
			stations[effect.stationId] = true
		elseif effect.type == "partyLeft" and effect.userId then
			left[effect.userId] = true
		elseif effect.type == "teleport" and effect.partyId then
			table.insert(teleports, effect.partyId)
		elseif effect.type == "invite" and effect.userId then
			push(Players:GetPlayerByUserId(effect.userId), Topic.Invite, effect.invite)
		elseif effect.type == "inviteClosed" and effect.userId then
			push(
				Players:GetPlayerByUserId(effect.userId),
				Topic.InviteClosed,
				{ id = effect.inviteId, reason = effect.reason }
			)
		elseif effect.type == "notice" and effect.userId then
			push(Players:GetPlayerByUserId(effect.userId), Topic.Notice, { level = effect.level, text = effect.text })
		end
	end

	for userId in left do
		if not logic:GetPartyIdOf(userId) then
			push(Players:GetPlayerByUserId(userId), Topic.Party, nil)
		end
	end
	for partyId in parties do
		local snapshot = logic:PartySnapshot(partyId)
		if snapshot then
			for _, userId in logic:GetMemberIds(partyId) do
				push(Players:GetPlayerByUserId(userId), Topic.Party, snapshot)
			end
		end
	end

	local changedStations = {}
	local anyStation = false
	for stationId in stations do
		local snapshot = logic:StationSnapshot(stationId)
		if snapshot then
			changedStations[stationId] = snapshot
			anyStation = true
			StationService.render(snapshot)
		end
	end
	if anyStation then
		pushRemote:FireAllClients(Topic.Stations, changedStations)
	end

	for _, partyId in teleports do
		task.spawn(runTeleport, partyId)
	end
end

local function allow(player: Player): boolean
	local t = os.clock()
	local bucket = buckets[player]
	if not bucket then
		bucket = { tokens = Config.Party.RequestBurst, at = t }
		buckets[player] = bucket
	end
	bucket.tokens =
		math.min(Config.Party.RequestBurst, bucket.tokens + (t - bucket.at) * Config.Party.RequestsPerSecond)
	bucket.at = t
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

local function isUserId(value: any): boolean
	return type(value) == "number" and value == value and value % 1 == 0 and value > 0
end

local handlers: { [string]: (player: Player, payload: { [string]: any }) -> Net.Result } = {}

handlers[Action.GetState] = function(player)
	local partyId = logic:GetPartyIdOf(player.UserId)
	return Net.ok({
		profile = ProfileService.snapshot(player),
		stations = logic:AllStationSnapshots(),
		party = if partyId then logic:PartySnapshot(partyId) else nil,
		invites = logic:GetInvitesFor(player.UserId),
		presence = StationService.getPresence(player),
		serverTime = now(),
	})
end

handlers[Action.CreateParty] = function(player, payload)
	local stationId = payload.stationId
	if type(stationId) ~= "string" or not Config.getStation(stationId) then
		return Net.fail("InvalidRequest")
	end
	local inviteUserIds = payload.inviteUserIds
	if inviteUserIds ~= nil then
		if type(inviteUserIds) ~= "table" or #inviteUserIds > Config.Party.MaxSize - 1 then
			return Net.fail("InvalidRequest")
		end
		for _, userId in inviteUserIds do
			if not isUserId(userId) then
				return Net.fail("InvalidRequest")
			end
		end
	end
	if not StationService.isPlayerNear(player, stationId) then
		return Net.fail("TooFar")
	end

	local ok, value = logic:CreateParty(userOf(player), {
		stationId = stationId,
		chapterId = payload.chapterId,
		difficultyId = payload.difficultyId,
		peaceful = payload.peaceful,
		maxSize = payload.maxSize,
	})
	if not ok then
		return Net.fail(value)
	end
	-- Invites chosen before creating are sent now; one that fails is skipped
	-- and the leader can retry it from the party panel.
	for _, userId in inviteUserIds or {} do
		local target = Players:GetPlayerByUserId(userId)
		if target then
			logic:Invite(player.UserId, userOf(target))
		end
	end
	return Net.ok({ partyId = value })
end

handlers[Action.JoinStationParty] = function(player, payload)
	local stationId = payload.stationId
	if type(stationId) ~= "string" or not Config.getStation(stationId) then
		return Net.fail("InvalidRequest")
	end
	if not StationService.isPlayerNear(player, stationId) then
		return Net.fail("TooFar")
	end
	return result(logic:JoinStationParty(userOf(player), stationId))
end

handlers[Action.LeaveParty] = function(player)
	return result(logic:Leave(player.UserId, false))
end

handlers[Action.SetReady] = function(player, payload)
	return result(logic:SetReady(player.UserId, payload.ready))
end

handlers[Action.Invite] = function(player, payload)
	local target = isUserId(payload.userId) and Players:GetPlayerByUserId(payload.userId)
	if not target then
		return Net.fail(if isUserId(payload.userId) then "PlayerUnavailable" else "InvalidRequest")
	end
	return result(logic:Invite(player.UserId, userOf(target)))
end

handlers[Action.CancelInvite] = function(player, payload)
	if not isUserId(payload.userId) then
		return Net.fail("InvalidRequest")
	end
	return result(logic:CancelInvite(player.UserId, payload.userId))
end

handlers[Action.RespondInvite] = function(player, payload)
	return result(logic:RespondInvite(userOf(player), payload.inviteId, payload.accept))
end

handlers[Action.Start] = function(player)
	return result(logic:Start(player.UserId))
end

handlers[Action.CancelCountdown] = function(player)
	return result(logic:CancelCountdown(player.UserId))
end

handlers[Action.UpdateSetting] = function(player, payload)
	if not ProfileService.updateSetting(player, payload.key, payload.value) then
		return Net.fail("InvalidRequest")
	end
	push(player, Topic.Profile, ProfileService.snapshot(player))
	return Net.ok()
end

local function onRequest(player: Player, action: any, payload: any): Net.Result
	if not allow(player) then
		return Net.fail("RateLimited")
	end
	local handler = type(action) == "string" and handlers[action]
	if not handler or (payload ~= nil and type(payload) ~= "table") then
		return Net.fail("InvalidRequest")
	end
	local ok, response = xpcall(handler, function(err)
		return debug.traceback(tostring(err), 2)
	end, player, payload or {})
	if not ok then
		warn(`[MushroomLobby] request "{action}" from {player.Name} failed: {response}`)
		response = Net.fail("Internal")
	end
	PartyService.flush()
	return response
end

-- Closes one station (reason shown on its board) or reopens it (nil).
function PartyService.setStationDisabled(stationId: string, reason: string?)
	logic:SetStationDisabled(stationId, reason)
	PartyService.flush()
end

-- Pauses or resumes all matchmaking, e.g. while the gameplay place is being updated.
function PartyService.setMatchmakingDisabled(reason: string?)
	logic:SetMatchmakingDisabled(reason)
	PartyService.flush()
end

function PartyService.start()
	if started then
		return
	end
	started = true

	logic = PartyLogic.new({
		now = now,
		isUnlocked = function(userId, chapterId, difficultyId)
			local player = Players:GetPlayerByUserId(userId)
			return player ~= nil and ProfileService.isUnlocked(player, chapterId, difficultyId)
		end,
		acceptsInvites = function(userId)
			local player = Players:GetPlayerByUserId(userId)
			return player ~= nil and ProfileService.acceptsInvites(player)
		end,
	})

	local requestRemote
	requestRemote, pushRemote = Net.createServer(Shared)

	ProfileService.onLoaded = function(player)
		push(player, Topic.Profile, ProfileService.snapshot(player))
	end
	ProfileService.start()

	StationService.onPresenceChanged = function(player, stationId, viaPrompt)
		push(player, Topic.Presence, { stationId = stationId, viaPrompt = viaPrompt })
	end
	for _, stationId in StationService.start() do
		logic:SetStationDisabled(stationId, "Station is being rebuilt")
	end
	for _, station in Config.Stations do
		StationService.render(logic:StationSnapshot(station.Id) :: Net.StationSnapshot)
	end
	logic:DrainEffects()

	TeleportController.onPlayerFailed = function(player)
		local partyId = logic:GetPartyIdOf(player.UserId)
		if partyId and logic:TeleportFailed(partyId, "TeleportFailed") then
			PartyService.flush()
		end
	end
	TeleportController.start()

	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
		logic:RemoveUser(player.UserId)
		PartyService.flush()
	end)

	requestRemote.OnServerInvoke = onRequest

	task.spawn(function()
		while true do
			logic:Tick()
			PartyService.flush()
			task.wait(TICK_INTERVAL)
		end
	end)
end

return PartyService
