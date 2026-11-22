-- PartyService end to end on mocked services: remotes, validation, proximity,
-- replication, countdown, teleport success and failure, disconnects.
local process = require("@lune/process")
local task = require("@lune/task")

local Harness = require("../tools/harness")
local roblox = Harness.roblox

local count = 0
local function check(condition, label)
	count += 1
	if not condition then
		error("FAILED: " .. label, 2)
	end
end

local PAD_Z = -46
local PAD_X = { solo = -72, duo = -24, trio = 24, squad = 72 }

local function padPosition(stationId)
	return roblox.Vector3.new(PAD_X[stationId], 3, PAD_Z)
end

-- A minimal stand-in for the built lobby: just what StationService reads.
local function buildStations(h, ids)
	local lobby = roblox.Instance.new("Model")
	lobby.Name = "MushroomLobby"
	local folder = roblox.Instance.new("Folder")
	folder.Name = "Stations"
	folder.Parent = lobby
	local prompts = {}
	for _, id in ids do
		local model = roblox.Instance.new("Model")
		model.Name = id
		model:SetAttribute("StationId", id)
		local pad = roblox.Instance.new("Part")
		pad.Name = "Pad"
		pad.Anchored = true
		pad.CFrame = roblox.CFrame.new(PAD_X[id], 0.5, PAD_Z)
		pad:SetAttribute("ZoneRadius", 9)
		pad.Parent = model
		local prompt = roblox.Instance.new("ProximityPrompt")
		prompt.Name = "Prompt"
		prompt.Parent = pad
		prompts[id] = prompt
		model.Parent = folder
	end
	lobby.Parent = h:service("Workspace")
	return prompts
end

local function start(ids, configure)
	local h = Harness.new()
	local ctx = h:context("server")
	local shared = h:service("ReplicatedStorage").MushroomLobby
	local server = h:service("ServerScriptService").MushroomLobby
	local Config = ctx.require(shared.Config)
	local Net = ctx.require(shared.Net)

	Config.Party.CountdownSeconds = 0.6
	Config.Party.TeleportRetryDelaySeconds = 0.05
	Config.Party.TeleportTimeoutSeconds = 1.2
	Config.Party.ErrorDisplaySeconds = 0.6
	Config.Party.InviteCooldownSeconds = 0
	Config.Party.RequestBurst = 1000
	Config.Party.RequestsPerSecond = 1000
	if configure then
		configure(Config, h)
	end

	local prompts = buildStations(h, ids)
	local rendered = {}
	local StationService = ctx.require(server.StationService)
	StationService.start({
		viewFactory = function(model)
			local id = model:GetAttribute("StationId")
			return {
				Render = function(_, snapshot)
					rendered[id] = snapshot
				end,
				Destroy = function() end,
			}
		end,
	})
	local PartyService = ctx.require(server.PartyService)
	PartyService.start()

	local remotes = shared:FindFirstChild("Remotes")
	local env = {
		h = h,
		Config = Config,
		Net = Net,
		PartyService = PartyService,
		request = remotes.Request,
		rendered = rendered,
		prompts = prompts,
	}
	function env.call(player, action, payload)
		return h:invokeAs(player, remotes.Request, action, payload)
	end
	-- Latest payload pushed to a player on a topic.
	function env.last(player, topic)
		local found = nil
		for _, entry in h:sentTo(player, "Push") do
			if entry.args[1] == topic then
				found = entry
			end
		end
		return found and found.args[2], found ~= nil
	end
	function env.countTopic(player, topic)
		local n = 0
		for _, entry in h:sentTo(player, "Push") do
			if entry.args[1] == topic then
				n += 1
			end
		end
		return n
	end
	return env
end

local function createPayload(stationId, overrides)
	local payload = {
		stationId = stationId,
		chapterId = "sporewood_hollow",
		difficultyId = "normal",
		peaceful = false,
		maxSize = 4,
	}
	for key, value in overrides or {} do
		payload[key] = value
	end
	return payload
end

--------------------------------------------------------------------------------
-- Scenario 1: full flow
--------------------------------------------------------------------------------
do
	local env = start({ "solo", "duo", "trio", "squad" }, function(Config, h)
		-- Ann has cleared chapter 1 on Normal; Dot refuses invites.
		Harness.state.datastore.stores[Config.Progression.DataStoreName] = {
			player_1 = { cleared = { sporewood_hollow = { normal = true } } },
		}
		Harness.state.datastore.stores[Config.Settings.DataStoreName] = {
			player_4 = { allowInvites = false, uiScale = "large", bogus = 1 },
		}
		check(h ~= nil, "harness available to configure")
	end)
	local h, Net, call = env.h, env.Net, env.call

	local ann = h:addPlayer({ userId = 1, name = "Ann", position = roblox.Vector3.new(0, 3, 56) })
	local ben = h:addPlayer({ userId = 2, name = "Ben", position = roblox.Vector3.new(4, 3, 56) })
	local cat = h:addPlayer({ userId = 3, name = "Cat", position = roblox.Vector3.new(8, 3, 56) })
	local dot = h:addPlayer({ userId = 4, name = "Dot", position = roblox.Vector3.new(12, 3, 56) })
	h:setLocalPlayer(ann)
	task.wait(0.1)

	-- Initial state.
	local state = call(ann, Net.Action.GetState)
	check(state.ok and state.data.party == nil, "initial state has no party")
	local stationCount = 0
	for _, station in state.data.stations do
		stationCount += 1
		check(station.status == "Available", `station {station.id} starts available`)
	end
	check(stationCount == 4, "four stations reported")
	check(state.data.profile.progress.cleared.sporewood_hollow.normal == true, "progress loaded from the data store")
	check(type(state.data.serverTime) == "number", "server time included")
	local dotState = call(dot, Net.Action.GetState)
	check(dotState.data.profile.settings.allowInvites == false, "stored settings loaded")
	check(dotState.data.profile.settings.uiScale == "large", "stored ui scale loaded")
	check(dotState.data.profile.settings.bogus == nil, "unknown stored settings ignored")
	check(env.rendered.solo and env.rendered.solo.status == "Available", "station displays rendered at start")

	-- The remote itself works through the client loopback.
	local viaRemote = env.request:InvokeServer(Net.Action.GetState)
	check(viaRemote.ok == true, "RemoteFunction answers the local client")

	-- Bad requests.
	check(call(ann, "Nope").code == "InvalidRequest", "unknown action rejected")
	check(call(ann, 42).code == "InvalidRequest", "non-string action rejected")
	check(call(ann, Net.Action.CreateParty, "x").code == "InvalidRequest", "non-table payload rejected")
	check(call(ann, Net.Action.CreateParty, {}).code == "InvalidRequest", "empty payload rejected")
	check(call(ann, Net.Action.Start).code == "NotInParty", "start without a party")
	check(call(ann, Net.Action.LeaveParty).code == "NotInParty", "leave without a party")
	check(
		call(ann, Net.Action.CreateParty, createPayload("squad", { inviteUserIds = { 1, 2, 3, 4 } })).code
			== "InvalidRequest",
		"too many queued invites rejected"
	)
	check(
		call(ann, Net.Action.CreateParty, createPayload("squad", { inviteUserIds = { "2" } })).code == "InvalidRequest",
		"queued invite ids must be numbers"
	)

	-- Proximity is enforced on the server.
	local far = call(ann, Net.Action.CreateParty, createPayload("squad"))
	check(far.ok == false and far.code == "TooFar", "cannot create from across the lobby")
	check(far.message == Net.Messages.TooFar, "failures carry a readable message")

	h:movePlayer(ann, padPosition("squad"))
	task.wait(0.35)
	local presence = env.last(ann, Net.Topic.Presence)
	check(presence and presence.stationId == "squad" and presence.viaPrompt == false, "entering the pad is pushed")
	check(call(ann, Net.Action.GetState).data.presence == "squad", "presence included in state")

	-- Locked content is refused by the server whatever the client sends.
	h:movePlayer(ben, padPosition("duo"))
	task.wait(0.35)
	check(
		call(ben, Net.Action.CreateParty, createPayload("duo", { difficultyId = "hard" })).code == "Locked",
		"locked difficulty refused"
	)
	check(
		call(ben, Net.Action.CreateParty, createPayload("duo", { chapterId = "glowcap_caverns" })).code == "Locked",
		"locked chapter refused"
	)

	-- Create, with a queued invite.
	h:clearSent()
	local created = call(
		ann,
		Net.Action.CreateParty,
		createPayload("squad", { difficultyId = "hard", peaceful = true, maxSize = 3, inviteUserIds = { 3 } })
	)
	check(created.ok and type(created.data.partyId) == "string", "party created (unlocked hard, peaceful)")
	local party = env.last(ann, Net.Topic.Party)
	check(party and party.leaderUserId == 1 and party.maxSize == 3, "leader receives the party snapshot")
	check(party.difficultyId == "hard" and party.peaceful == true, "run settings stored on the server")
	check(#party.invites == 1 and party.invites[1].userId == 3, "queued invite is pending")
	local invite = env.last(cat, Net.Topic.Invite)
	check(invite and invite.fromName == "Ann" and invite.maxSize == 3, "invitee receives the invite")
	local stations = env.last(ben, Net.Topic.Stations)
	check(stations and stations.squad and stations.squad.status == "Occupied", "everyone sees the station change")
	check(env.rendered.squad.status == "Occupied" and env.rendered.squad.leaderName == "Ann", "station display updated")
	check(env.last(ben, Net.Topic.Party) == nil, "non-members get no party snapshot")

	-- Invites over the remote.
	check(call(ann, Net.Action.Invite, { userId = 999 }).code == "PlayerUnavailable", "cannot invite an absent player")
	check(call(ann, Net.Action.Invite, { userId = "3" }).code == "InvalidRequest", "invite id must be a number")
	check(call(ann, Net.Action.Invite, { userId = 4 }).code == "InvitesBlocked", "blocked invites are respected")
	check(call(ben, Net.Action.Invite, { userId = 3 }).code == "NotInParty", "outsiders cannot invite")
	check(call(cat, Net.Action.RespondInvite, { inviteId = invite.id, accept = true }).ok, "invite accepted")
	party = env.last(cat, Net.Topic.Party)
	check(party and #party.members == 2 and #party.invites == 0, "invitee is now a member")
	local notice = env.last(ann, Net.Topic.Notice)
	check(notice and notice.level == "success" and notice.text:find("Cat"), "leader is notified of the join")

	-- Joining at the station.
	check(call(ben, Net.Action.JoinStationParty, { stationId = "squad" }).code == "TooFar", "join needs proximity")
	h:movePlayer(ben, padPosition("squad"))
	task.wait(0.35)
	check(call(ben, Net.Action.JoinStationParty, { stationId = "squad" }).ok, "third player joins at the station")
	check(env.rendered.squad.status == "Full" and env.rendered.squad.memberCount == 3, "station full")
	h:movePlayer(dot, padPosition("squad"))
	task.wait(0.35)
	check(call(dot, Net.Action.JoinStationParty, { stationId = "squad" }).code == "PartyFull", "full party refuses")
	check(call(ben, Net.Action.Start).code == "NotLeader", "member cannot start")
	check(call(ann, Net.Action.Start).code == "NotReady", "start blocked until ready")
	check(call(ben, Net.Action.SetReady, { ready = true }).ok, "Ben ready")
	check(call(cat, Net.Action.SetReady, { ready = true }).ok, "Cat ready")
	check(call(cat, Net.Action.SetReady, {}).code == "InvalidRequest", "ready needs a boolean")

	-- Countdown, then cancel.
	local teleport = Harness.state.teleport
	check(call(ann, Net.Action.Start).ok, "leader starts")
	party = env.last(ben, Net.Topic.Party)
	check(party.phase == "Countdown" and type(party.countdownEndsAt) == "number", "members see the countdown")
	check(env.rendered.squad.status == "Starting", "station shows starting")
	check(call(ben, Net.Action.CancelCountdown).code == "NotLeader", "member cannot cancel")
	check(call(ann, Net.Action.CancelCountdown).ok, "leader cancels")
	task.wait(0.9)
	check(#teleport.calls == 0, "cancelled countdown does not teleport")
	check(env.last(ben, Net.Topic.Party).phase == "Forming", "party is forming again")

	-- Teleport failure: every attempt throws.
	teleport.mode = "throw"
	check(call(ann, Net.Action.Start).ok, "start again")
	task.wait(1.2)
	check(#teleport.calls == env.Config.Party.TeleportMaxAttempts, "teleport retried the configured number of times")
	party = env.last(cat, Net.Topic.Party)
	check(
		party.phase == "Forming" and party.error and party.error.code == "TeleportFailed",
		"failure returns the party"
	)
	check(#party.members == 3, "nobody is dropped by a failed teleport")
	check(env.rendered.squad.status == "Error", "station shows the error")
	notice = env.last(ben, Net.Topic.Notice)
	check(notice and notice.level == "error", "members are told about the failure")
	task.wait(0.9)
	check(env.last(cat, Net.Topic.Party).error == nil, "error clears")
	check(env.rendered.squad.status == "Full", "station recovers")

	-- Teleport accepted but one player's teleport fails to initialise.
	teleport.mode = "initFail"
	teleport.calls = {}
	check(call(ann, Net.Action.Start).ok, "start for init failure")
	task.wait(1)
	party = env.last(ann, Net.Topic.Party)
	check(party.phase == "Forming" and party.error ~= nil, "init failure also returns the party")
	task.wait(0.9)

	-- Successful teleport.
	teleport.mode = "ok"
	teleport.calls = {}
	check(call(ann, Net.Action.Start).ok, "start for success")
	task.wait(0.9)
	check(#teleport.calls == 1, "one teleport request on success")
	local sent = teleport.calls[1]
	check(sent.placeId == 129614341268000, "teleports to the gameplay place")
	check(#sent.players == 3, "the whole party is teleported together")
	check(sent.options.ReservedServerAccessCode == "harness-access-code", "party gets its own reserved server")
	local data = sent.data
	check(data.chapterId == "sporewood_hollow" and data.difficultyId == "hard", "teleport data carries the run")
	check(data.peaceful == true and data.maxSize == 3 and data.leaderUserId == 1, "teleport data carries the settings")
	check(#data.memberUserIds == 3 and data.version == 1, "teleport data lists the members")
	check(env.last(ann, Net.Topic.Party).phase == "Teleporting", "clients are told the teleport is under way")
	check(call(ann, Net.Action.LeaveParty).code == "WrongPhase", "cannot leave mid-teleport")
	h:removePlayer(ann)
	h:removePlayer(ben)
	h:removePlayer(cat)
	task.wait(0.1)
	check(env.rendered.squad.status == "Available" and env.rendered.squad.memberCount == 0, "station frees up")

	-- Settings.
	check(
		call(dot, Net.Action.UpdateSetting, { key = "hack", value = true }).code == "InvalidRequest",
		"unknown setting"
	)
	check(
		call(dot, Net.Action.UpdateSetting, { key = "uiScale", value = "huge" }).code == "InvalidRequest",
		"bad setting value"
	)
	check(call(dot, Net.Action.UpdateSetting, { key = "reduceMotion", value = true }).ok, "setting accepted")
	local profile = env.last(dot, Net.Topic.Profile)
	check(profile and profile.settings.reduceMotion == true, "profile pushed after a change")
	h:removePlayer(dot)
	task.wait(0.1)
	local stored = Harness.state.datastore.stores[env.Config.Settings.DataStoreName].player_4
	check(stored and stored.reduceMotion == true and stored.allowInvites == false, "settings saved on leave")
end

--------------------------------------------------------------------------------
-- Scenario 2: disconnects, prompt, rate limit, missing station, data store down
--------------------------------------------------------------------------------
do
	local env = start({ "solo", "duo", "trio" }, function(Config)
		Config.Party.RequestBurst = 5
		Config.Party.RequestsPerSecond = 0.001
		Harness.state.datastore.fail = true
	end)
	local h, Net, call = env.h, env.Net, env.call

	local ann = h:addPlayer({ userId = 11, name = "Ann", position = padPosition("duo") })
	local ben = h:addPlayer({ userId = 12, name = "Ben", position = padPosition("duo") })
	local spammer = h:addPlayer({ userId = 13, name = "Spam", position = padPosition("solo") })
	task.wait(0.35)

	local state = call(ann, Net.Action.GetState)
	check(state.ok and next(state.data.profile.progress.cleared) == nil, "data store outage falls back to defaults")
	check(state.data.stations.squad.status == "Unavailable", "a station missing from the world is closed")
	check(type(state.data.stations.squad.message) == "string", "closed station explains itself")
	check(call(ann, Net.Action.CreateParty, createPayload("squad")).code == "TooFar", "missing station cannot be used")

	-- Prompt re-opens the flow for a player already on the pad.
	h:clearSent()
	Harness.fire(env.prompts.duo, "Triggered", ann)
	task.wait(0.05)
	local presence = env.last(ann, Net.Topic.Presence)
	check(presence and presence.stationId == "duo" and presence.viaPrompt == true, "prompt pushes presence")

	check(call(ann, Net.Action.CreateParty, createPayload("duo", { maxSize = 2 })).ok, "create at duo")
	check(call(ben, Net.Action.JoinStationParty, { stationId = "duo" }).ok, "join at duo")
	check(call(ben, Net.Action.SetReady, { ready = true }).ok, "ready")
	check(call(ann, Net.Action.Start).ok, "start")

	-- Leader disconnects during the countdown.
	h:removePlayer(ann)
	task.wait(0.1)
	local party = env.last(ben, Net.Topic.Party)
	check(party.phase == "Forming" and party.leaderUserId == 12, "disconnect cancels and passes leadership")
	task.wait(0.9)
	check(#Harness.state.teleport.calls == 0, "no teleport after the leader disconnected")
	check(call(ben, Net.Action.LeaveParty).ok, "last member leaves")
	local _, wasSent = env.last(ben, Net.Topic.Party)
	check(wasSent and env.last(ben, Net.Topic.Party) == nil, "leaver is told the party is gone")
	check(env.rendered.duo.status == "Available", "station free after everyone left")

	-- Rate limit.
	local limited = false
	for _ = 1, 12 do
		if call(spammer, Net.Action.GetState).code == "RateLimited" then
			limited = true
		end
	end
	check(limited, "request spam is rate limited")

	-- Admin switches.
	env.PartyService.setMatchmakingDisabled("Teleports are paused")
	check(
		env.rendered.solo.status == "Unavailable" and env.rendered.solo.message == "Teleports are paused",
		"pause shown"
	)
	env.PartyService.setMatchmakingDisabled(nil)
	check(env.rendered.solo.status == "Available", "resume shown")
end

print(`party service spec: {count} assertions ok`)
process.exit(0)
