-- Party state machine: every rule the server enforces, driven with a fake clock.
local Harness = require("../tools/harness")

local h = Harness.new()
local ctx = h:context("server")
local shared = h:service("ReplicatedStorage").MushroomLobby
local server = h:service("ServerScriptService").MushroomLobby

local Config = ctx.require(shared.Config)
local Net = ctx.require(shared.Net)
local PartyLogic = ctx.require(server.PartyLogic)

local count = 0
local function check(condition, label)
	count += 1
	if not condition then
		error("FAILED: " .. label, 2)
	end
end

local function expectFail(ok, code, expected, label)
	check(ok == false and code == expected, `{label} (expected {expected}, got {tostring(ok)} / {tostring(code)})`)
end

local function user(id, name)
	return { userId = id, name = name, displayName = name }
end

local ANN, BEN, CAT, DOT, EVE = user(1, "Ann"), user(2, "Ben"), user(3, "Cat"), user(4, "Dot"), user(5, "Eve")

local function newLogic(overrides)
	overrides = overrides or {}
	local env = { now = 100, unlocked = { ["sporewood_hollow/normal"] = true }, blockInvites = {} }
	local logic = PartyLogic.new({
		now = function()
			return env.now
		end,
		isUnlocked = overrides.isUnlocked or function(_, chapterId, difficultyId)
			return env.unlocked[chapterId .. "/" .. difficultyId] == true
		end,
		acceptsInvites = function(userId)
			return not env.blockInvites[userId]
		end,
	})
	return logic, env
end

local function params(overrides)
	local base = {
		stationId = "squad",
		chapterId = "sporewood_hollow",
		difficultyId = "normal",
		peaceful = false,
		maxSize = 4,
	}
	for key, value in overrides or {} do
		base[key] = value
	end
	return base
end

local function effectsOf(logic, kind)
	local list = {}
	for _, effect in logic:DrainEffects() do
		if kind == nil or effect.type == kind then
			table.insert(list, effect)
		end
	end
	return list
end

-- Creation ------------------------------------------------------------------
do
	local logic = newLogic()
	local ok, partyId = logic:CreateParty(ANN, params())
	check(ok and type(partyId) == "string", "create succeeds")
	local snapshot = logic:PartySnapshot(partyId)
	check(snapshot.leaderUserId == 1 and #snapshot.members == 1, "creator is leader and only member")
	check(snapshot.members[1].isLeader and snapshot.members[1].ready, "leader is flagged and ready")
	check(snapshot.phase == Net.Phase.Forming and snapshot.maxSize == 4, "starts forming with requested size")
	check(logic:GetPartyIdOf(1) == partyId and logic:GetStationPartyId("squad") == partyId, "indexes updated")
	local station = logic:StationSnapshot("squad")
	check(station.status == "Occupied" and station.leaderName == "Ann" and station.memberCount == 1, "station occupied")
	check(logic:StationSnapshot("solo").status == "Available", "other stations stay available")
	check(logic:StationSnapshot("solo").maxSize == 1 and logic:StationSnapshot("trio").maxSize == 3, "default sizes")

	local ok2, code2 = logic:CreateParty(ANN, params({ stationId = "duo" }))
	expectFail(ok2, code2, "AlreadyInParty", "creator cannot create a second party")
	local ok3, code3 = logic:CreateParty(BEN, params())
	expectFail(ok3, code3, "StationOccupied", "station hosts one party")
end

do
	local logic = newLogic()
	local cases = {
		{ params({ stationId = "nope" }), "InvalidRequest", "unknown station" },
		{ params({ chapterId = "nope" }), "InvalidRequest", "unknown chapter" },
		{ params({ difficultyId = 7 }), "InvalidRequest", "difficulty wrong type" },
		{ params({ maxSize = 0 }), "InvalidRequest", "size below range" },
		{ params({ maxSize = 5 }), "InvalidRequest", "size above range" },
		{ params({ maxSize = 2.5 }), "InvalidRequest", "fractional size" },
		{ params({ maxSize = "4" }), "InvalidRequest", "size wrong type" },
		{ params({ maxSize = 0 / 0 }), "InvalidRequest", "NaN size" },
		{ params({ peaceful = "yes" }), "InvalidRequest", "peaceful wrong type" },
		{ params({ difficultyId = "hard" }), "Locked", "locked difficulty" },
		{ params({ chapterId = "glowcap_caverns" }), "Locked", "locked chapter" },
	}
	for _, case in cases do
		local ok, code = logic:CreateParty(ANN, case[1])
		expectFail(ok, code, case[2], case[3])
	end
	local ok, code = logic:CreateParty(ANN, "not a table")
	expectFail(ok, code, "InvalidRequest", "params must be a table")
	check(logic:GetPartyIdOf(1) == nil, "failed creates leave no party behind")
	for size = 1, 4 do
		local sized = newLogic()
		check(sized:CreateParty(ANN, params({ maxSize = size })), `size {size} accepted`)
	end
	local peaceful = newLogic()
	local okP, idP = peaceful:CreateParty(ANN, params({ peaceful = true }))
	check(okP and peaceful:PartySnapshot(idP).peaceful == true, "peaceful flag stored")
end

-- Joining, full parties -------------------------------------------------------
do
	local logic = newLogic()
	local _, partyId = logic:CreateParty(ANN, params({ stationId = "duo", maxSize = 2 }))
	local ok, code = logic:JoinStationParty(BEN, "solo")
	expectFail(ok, code, "StationEmpty", "cannot join an empty station")
	ok, code = logic:JoinStationParty(BEN, "nope")
	expectFail(ok, code, "InvalidRequest", "cannot join unknown station")
	check(logic:JoinStationParty(BEN, "duo"), "second player joins")
	local snapshot = logic:PartySnapshot(partyId)
	check(#snapshot.members == 2 and snapshot.members[2].ready == false, "joiner starts not ready")
	check(logic:StationSnapshot("duo").status == "Full", "station reports full")
	ok, code = logic:JoinStationParty(CAT, "duo")
	expectFail(ok, code, "PartyFull", "full party rejects joiners")
	ok, code = logic:JoinStationParty(BEN, "duo")
	expectFail(ok, code, "AlreadyInParty", "member cannot join twice")
	ok, code = logic:CreateParty(BEN, params({ stationId = "solo", maxSize = 1 }))
	expectFail(ok, code, "AlreadyInParty", "member cannot create another party")
end

-- Ready and start ---------------------------------------------------------------
do
	local logic, env = newLogic()
	local _, partyId = logic:CreateParty(ANN, params({ stationId = "trio", maxSize = 3 }))
	logic:JoinStationParty(BEN, "trio")
	local ok, code = logic:Start(2)
	expectFail(ok, code, "NotLeader", "only leader starts")
	ok, code = logic:Start(1)
	expectFail(ok, code, "NotReady", "start needs everyone ready")
	ok, code = logic:SetReady(9, true)
	expectFail(ok, code, "NotInParty", "ready needs a party")
	ok, code = logic:SetReady(2, "yes")
	expectFail(ok, code, "InvalidRequest", "ready must be boolean")
	check(logic:SetReady(2, true), "member readies up")
	check(logic:PartySnapshot(partyId).members[2].ready == true, "ready stored")
	check(logic:SetReady(1, false) and logic:PartySnapshot(partyId).members[1].ready, "leader stays ready")

	logic:DrainEffects()
	check(logic:Start(1), "leader starts with a part-filled party")
	local snapshot = logic:PartySnapshot(partyId)
	check(snapshot.phase == Net.Phase.Countdown, "countdown phase")
	check(snapshot.countdownEndsAt == env.now + Config.Party.CountdownSeconds, "countdown end time")
	check(Config.Party.CountdownSeconds >= 3 and Config.Party.CountdownSeconds <= 5, "countdown is 3-5 seconds")
	check(logic:StationSnapshot("trio").status == "Starting", "station shows starting")
	ok, code = logic:JoinStationParty(CAT, "trio")
	expectFail(ok, code, "WrongPhase", "no joining during countdown")
	ok, code = logic:SetReady(2, false)
	expectFail(ok, code, "WrongPhase", "no unready during countdown")
	ok, code = logic:Start(1)
	expectFail(ok, code, "WrongPhase", "cannot start twice")

	ok, code = logic:CancelCountdown(2)
	expectFail(ok, code, "NotLeader", "only leader cancels")
	check(logic:CancelCountdown(1), "leader cancels countdown")
	snapshot = logic:PartySnapshot(partyId)
	check(snapshot.phase == Net.Phase.Forming and snapshot.countdownEndsAt == nil, "back to forming")
	ok, code = logic:CancelCountdown(1)
	expectFail(ok, code, "WrongPhase", "nothing to cancel")
	check(logic:PartySnapshot(partyId).members[2].ready, "ready states survive a cancel")

	-- Countdown runs out.
	check(logic:Start(1), "restart")
	logic:DrainEffects()
	env.now += Config.Party.CountdownSeconds - 0.1
	logic:Tick()
	check(#effectsOf(logic, "teleport") == 0, "no teleport before the countdown ends")
	env.now += 0.2
	logic:Tick()
	local teleports = effectsOf(logic, "teleport")
	check(#teleports == 1 and teleports[1].partyId == partyId, "teleport effect fires once")
	check(logic:PartySnapshot(partyId).phase == Net.Phase.Teleporting, "teleporting phase")
	logic:Tick()
	check(#effectsOf(logic, "teleport") == 0, "teleport effect is not repeated")
	ok, code = logic:Leave(2)
	expectFail(ok, code, "WrongPhase", "cannot leave mid-teleport by request")
	ok, code = logic:CancelCountdown(1)
	expectFail(ok, code, "WrongPhase", "cannot cancel once teleporting")

	-- Members arriving in the gameplay place look like disconnects here.
	logic:RemoveUser(2)
	check(#logic:PartySnapshot(partyId).members == 1, "teleported member removed")
	logic:RemoveUser(1)
	check(logic:GetParty(partyId) == nil, "party closes when everyone has left")
	check(logic:StationSnapshot("trio").status == "Available", "station is free again")
end

-- Teleport failure and timeout ------------------------------------------------
do
	local logic, env = newLogic()
	local _, partyId = logic:CreateParty(ANN, params({ stationId = "solo", maxSize = 1 }))
	logic:Start(1)
	env.now += Config.Party.CountdownSeconds
	logic:Tick()
	logic:DrainEffects()
	check(logic:TeleportFailed(partyId, "TeleportFailed"), "failure accepted while teleporting")
	local snapshot = logic:PartySnapshot(partyId)
	check(snapshot.phase == Net.Phase.Forming, "party survives a failed teleport")
	check(snapshot.error and snapshot.error.code == "TeleportFailed", "error recorded")
	check(snapshot.error.message == Net.Messages.TeleportFailed, "error message is readable")
	check(logic:StationSnapshot("solo").status == "Error", "station shows error")
	local notices = effectsOf(logic, "notice")
	check(#notices == 1 and notices[1].level == "error" and notices[1].userId == 1, "members are told")
	check(not logic:TeleportFailed(partyId, "TeleportFailed"), "failure ignored outside teleporting")

	env.now += Config.Party.ErrorDisplaySeconds
	logic:Tick()
	check(logic:PartySnapshot(partyId).error == nil, "error clears after its display time")
	check(logic:StationSnapshot("solo").status == "Full", "solo station returns to full")

	-- Retry, then time out.
	check(logic:Start(1), "retry after failure")
	env.now += Config.Party.CountdownSeconds
	logic:Tick()
	env.now += Config.Party.TeleportTimeoutSeconds
	logic:Tick()
	snapshot = logic:PartySnapshot(partyId)
	check(snapshot.phase == Net.Phase.Forming and snapshot.error.code == "TeleportTimeout", "timeout becomes an error")
	check(logic:Start(1) and logic:PartySnapshot(partyId).error == nil, "starting again clears the error")
end

-- Leaving, leadership, disconnects --------------------------------------------
do
	local logic = newLogic()
	local _, partyId = logic:CreateParty(ANN, params())
	logic:JoinStationParty(BEN, "squad")
	logic:JoinStationParty(CAT, "squad")
	logic:SetReady(2, true)
	logic:SetReady(3, true)
	local ok, code = logic:Leave(9)
	expectFail(ok, code, "NotInParty", "leave needs a party")

	logic:Start(1)
	logic:DrainEffects()
	check(logic:Leave(3), "member leaves during countdown")
	local snapshot = logic:PartySnapshot(partyId)
	check(snapshot.phase == Net.Phase.Forming, "leaving cancels the countdown")
	check(#snapshot.members == 2 and logic:GetPartyIdOf(3) == nil, "leaver removed")
	local left = effectsOf(logic, "partyLeft")
	check(#left == 1 and left[1].userId == 3, "leaver is told they are out")

	logic:RemoveUser(1)
	snapshot = logic:PartySnapshot(partyId)
	check(snapshot.leaderUserId == 2 and snapshot.members[1].isLeader, "next member becomes leader")
	check(snapshot.members[1].ready, "new leader is ready")
	check(logic:Start(2), "new leader can start")
	logic:RemoveUser(2)
	check(logic:GetParty(partyId) == nil and logic:GetStationPartyId("squad") == nil, "empty party is closed")
	check(logic:CreateParty(ANN, params()), "former leader can create again")
end

-- Invites -----------------------------------------------------------------------
do
	local logic, env = newLogic()
	local _, partyId = logic:CreateParty(ANN, params({ stationId = "trio", maxSize = 3 }))
	logic:DrainEffects()

	local ok, code = logic:Invite(2, CAT)
	expectFail(ok, code, "NotInParty", "outsiders cannot invite")
	ok, code = logic:Invite(1, ANN)
	expectFail(ok, code, "PlayerUnavailable", "cannot invite yourself")
	check(logic:Invite(1, BEN), "leader invites")
	local sent = effectsOf(logic, "invite")
	check(#sent == 1 and sent[1].userId == 2, "invite delivered to target")
	local invite = sent[1].invite
	check(invite.fromName == "Ann" and invite.chapterName == "Sporewood Hollow", "invite describes the party")
	check(invite.maxSize == 3 and invite.memberCount == 1 and invite.stationId == "trio", "invite counts")
	check(invite.expiresAt == env.now + Config.Party.InviteTtlSeconds, "invite expiry")
	check(#logic:PartySnapshot(partyId).invites == 1, "pending invite listed for the party")
	check(#logic:GetInvitesFor(2) == 1, "pending invite listed for the target")

	ok, code = logic:Invite(1, BEN)
	expectFail(ok, code, "AlreadyInvited", "no duplicate invites")
	ok, code = logic:RespondInvite(CAT, invite.id, true)
	expectFail(ok, code, "InviteExpired", "only the invitee can answer")
	ok, code = logic:RespondInvite(BEN, "invite-999", true)
	expectFail(ok, code, "InviteExpired", "unknown invite")
	ok, code = logic:RespondInvite(BEN, invite.id, "yes")
	expectFail(ok, code, "InvalidRequest", "accept must be boolean")

	check(logic:RespondInvite(BEN, invite.id, true), "invitee accepts")
	local snapshot = logic:PartySnapshot(partyId)
	check(#snapshot.members == 2 and #snapshot.invites == 0, "accepted invite becomes a member")
	ok, code = logic:RespondInvite(BEN, invite.id, true)
	expectFail(ok, code, "InviteExpired", "invite cannot be reused")
	ok, code = logic:Invite(2, CAT)
	expectFail(ok, code, "NotLeader", "members cannot invite")
	ok, code = logic:Invite(1, BEN)
	expectFail(ok, code, "PlayerUnavailable", "cannot invite someone already in a party")

	-- Decline, cooldown, expiry.
	logic:Invite(1, CAT)
	local catInvite = logic:GetInvitesFor(3)[1]
	logic:DrainEffects()
	check(logic:RespondInvite(CAT, catInvite.id, false), "invitee declines")
	check(#logic:PartySnapshot(partyId).invites == 0, "declined invite removed")
	local declined = effectsOf(logic, "notice")
	check(#declined == 1 and declined[1].userId == 1, "leader hears about the decline")
	ok, code = logic:Invite(1, CAT)
	expectFail(ok, code, "InviteCooldown", "cooldown after inviting the same player")
	env.now += Config.Party.InviteCooldownSeconds
	check(logic:Invite(1, CAT), "invite again after the cooldown")
	logic:DrainEffects()
	env.now += Config.Party.InviteTtlSeconds
	logic:Tick()
	local closed = effectsOf(logic, "inviteClosed")
	check(#closed == 1 and closed[1].reason == "expired" and closed[1].userId == 3, "invite expires")
	check(#logic:GetInvitesFor(3) == 0, "expired invite is gone")

	-- Blocked invites and cancelling.
	env.blockInvites[4] = true
	ok, code = logic:Invite(1, DOT)
	expectFail(ok, code, "InvitesBlocked", "target refuses invites")
	env.blockInvites[4] = nil
	check(logic:Invite(1, DOT), "invite once allowed")
	ok, code = logic:CancelInvite(2, 4)
	expectFail(ok, code, "NotLeader", "members cannot cancel invites")
	check(logic:CancelInvite(1, 4), "leader cancels invite")
	ok, code = logic:CancelInvite(1, 4)
	expectFail(ok, code, "InviteExpired", "nothing left to cancel")

	-- Filling the party closes the remaining invites.
	env.now += Config.Party.InviteCooldownSeconds
	logic:Invite(1, CAT)
	logic:Invite(1, DOT)
	local dotInvite = logic:GetInvitesFor(4)[1]
	check(logic:RespondInvite(CAT, logic:GetInvitesFor(3)[1].id, true), "third member joins by invite")
	check(#logic:GetInvitesFor(4) == 0, "full party withdraws other invites")
	ok, code = logic:RespondInvite(DOT, dotInvite.id, true)
	expectFail(ok, code, "InviteExpired", "withdrawn invite cannot be accepted")
	ok, code = logic:Invite(1, EVE)
	expectFail(ok, code, "PartyFull", "full party cannot invite")
end

do
	-- Invites die with the countdown, the party, and the invitee.
	local logic = newLogic()
	logic:CreateParty(ANN, params())
	logic:Invite(1, BEN)
	logic:Invite(1, CAT)
	logic:Start(1)
	check(#logic:GetInvitesFor(2) == 0, "starting withdraws invites")
	logic:CancelCountdown(1)
	local ok, code = logic:Invite(1, BEN)
	expectFail(ok, code, "InviteCooldown", "cooldown still applies after a withdrawn invite")

	local other, otherEnv = newLogic()
	local _, otherId = other:CreateParty(ANN, params())
	other:Invite(1, BEN)
	other:Invite(1, CAT)
	other:RemoveUser(2)
	check(#other:PartySnapshot(otherId).invites == 1, "invite to a player who left is dropped")
	check(other:CreateParty(CAT, params({ stationId = "solo", maxSize = 1 })), "invitee creates their own party")
	check(#other:PartySnapshot(otherId).invites == 0, "joining elsewhere closes invites")
	other:Invite(1, DOT)
	other:RemoveUser(1)
	check(#other:GetInvitesFor(4) == 0, "closing the party withdraws invites")
	check(otherEnv.now == 100, "clock untouched")

	-- Solo parties are full from the start; pending invite cap.
	local solo = newLogic()
	solo:CreateParty(ANN, params({ stationId = "solo", maxSize = 1 }))
	ok, code = solo:Invite(1, BEN)
	expectFail(ok, code, "PartyFull", "solo party cannot invite")
	check(solo:StationSnapshot("solo").status == "Full", "solo party is full")

	local capped = newLogic()
	capped:CreateParty(ANN, params())
	for index = 1, Config.Party.MaxPendingInvites do
		check(capped:Invite(1, user(100 + index, "P" .. index)), `pending invite {index}`)
	end
	ok, code = capped:Invite(1, user(200, "Overflow"))
	expectFail(ok, code, "InviteLimit", "pending invites are capped")
end

-- Station availability --------------------------------------------------------
do
	local logic = newLogic()
	logic:SetStationDisabled("duo", "Under repair")
	local station = logic:StationSnapshot("duo")
	check(station.status == "Unavailable" and station.message == "Under repair", "disabled station")
	local ok, code = logic:CreateParty(ANN, params({ stationId = "duo", maxSize = 2 }))
	expectFail(ok, code, "StationUnavailable", "cannot create at a closed station")
	logic:SetStationDisabled("duo", nil)
	check(logic:StationSnapshot("duo").status == "Available", "station reopens")

	local _, partyId = logic:CreateParty(ANN, params({ stationId = "duo", maxSize = 2 }))
	logic:Start(1)
	logic:SetStationDisabled("duo", "Under repair")
	check(logic:PartySnapshot(partyId).phase == Net.Phase.Forming, "closing a station cancels its countdown")
	ok, code = logic:Start(1)
	expectFail(ok, code, "StationUnavailable", "closed station cannot start")
	ok, code = logic:JoinStationParty(BEN, "duo")
	expectFail(ok, code, "StationUnavailable", "closed station cannot be joined")
	logic:SetStationDisabled("duo", nil)

	logic:SetMatchmakingDisabled("Teleports are paused")
	for _, config in Config.Stations do
		check(logic:StationSnapshot(config.Id).status == "Unavailable", `{config.Id} paused`)
	end
	ok, code = logic:CreateParty(BEN, params({ stationId = "solo", maxSize = 1 }))
	expectFail(ok, code, "StationUnavailable", "paused matchmaking blocks creation")
	logic:SetMatchmakingDisabled(nil)
	check(logic:StationSnapshot("solo").status == "Available", "matchmaking resumes")
end

-- Effects and snapshots are safe to send -------------------------------------
do
	local logic = newLogic()
	local _, partyId = logic:CreateParty(ANN, params())
	local kinds = {}
	for _, effect in logic:DrainEffects() do
		kinds[effect.type] = true
	end
	check(kinds.party and kinds.station, "create reports party and station changes")
	check(#logic:DrainEffects() == 0, "effects drain once")
	Harness.netCopy(logic:PartySnapshot(partyId))
	Harness.netCopy(logic:AllStationSnapshots())
	check(logic:PartySnapshot("party-404") == nil and logic:StationSnapshot("nope") == nil, "unknown ids give nil")
	local before = logic:PartySnapshot(partyId).revision
	logic:JoinStationParty(BEN, "squad")
	check(logic:PartySnapshot(partyId).revision > before, "revision increases on change")
end

print(`party logic spec: {count} assertions ok`)
