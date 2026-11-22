--!strict
-- Party and station state machine. Pure Luau: no Roblox services, no yields,
-- time injected. The server wraps this in PartyService; tests drive it
-- directly. Every method validates its caller, because callers are players.
--
-- Methods return (true, value?) or (false, code) where code is a key of
-- Net.Messages. State changes are reported as effects (see DrainEffects) that
-- the service turns into replication, notices and teleports.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("MushroomLobby")

local Config = require(Shared.Config)
local Net = require(Shared.Net)

export type User = { userId: number, name: string, displayName: string }

type Member = { userId: number, name: string, displayName: string, ready: boolean }

type Invite = {
	id: string,
	partyId: string,
	fromUserId: number,
	fromName: string,
	toUserId: number,
	toName: string,
	expiresAt: number,
}

type PartyError = { code: string, message: string, at: number }

export type Party = {
	id: string,
	stationId: string,
	leaderUserId: number,
	chapterId: string,
	difficultyId: string,
	peaceful: boolean,
	maxSize: number,
	-- Join order; the first remaining member inherits leadership.
	members: { Member },
	phase: string,
	countdownEndsAt: number?,
	teleportStartedAt: number?,
	error: PartyError?,
	revision: number,
}

export type CreateParams = {
	stationId: string,
	chapterId: string,
	difficultyId: string,
	peaceful: boolean,
	maxSize: number,
}

-- type is one of: "party" (partyId), "partyLeft" (userId), "station"
-- (stationId), "invite" (userId, invite), "inviteClosed" (userId, inviteId,
-- reason), "notice" (userId, level, text), "teleport" (partyId).
export type Effect = {
	type: string,
	partyId: string?,
	stationId: string?,
	userId: number?,
	invite: Net.IncomingInvite?,
	inviteId: string?,
	reason: string?,
	level: string?,
	text: string?,
}

export type Deps = {
	now: () -> number,
	isUnlocked: (userId: number, chapterId: string, difficultyId: string) -> boolean,
	acceptsInvites: ((userId: number) -> boolean)?,
}

local Phase = Net.Phase
local Status = Net.StationStatus
local Level = Net.NoticeLevel

local PartyLogic = {}
PartyLogic.__index = PartyLogic

export type PartyLogic = typeof(setmetatable(
	{} :: {
		_deps: Deps,
		_parties: { [string]: Party },
		_partyByUser: { [number]: string },
		_partyByStation: { [string]: string },
		_invites: { [string]: Invite },
		_inviteCooldown: { [string]: number },
		_disabledStations: { [string]: string },
		_matchmakingDisabled: string?,
		_effects: { Effect },
		_nextId: number,
	},
	PartyLogic
))

function PartyLogic.new(deps: Deps): PartyLogic
	return setmetatable({
		_deps = deps,
		_parties = {},
		_partyByUser = {},
		_partyByStation = {},
		_invites = {},
		_inviteCooldown = {},
		_disabledStations = {},
		_matchmakingDisabled = nil,
		_effects = {},
		_nextId = 0,
	}, PartyLogic)
end

local function isInteger(value: any): boolean
	return type(value) == "number" and value == value and value % 1 == 0
end

local function findMember(party: Party, userId: number): (Member?, number?)
	for index, member in party.members do
		if member.userId == userId then
			return member, index
		end
	end
	return nil, nil
end

function PartyLogic._emit(self: PartyLogic, effect: Effect)
	table.insert(self._effects, effect)
end

function PartyLogic._newId(self: PartyLogic, prefix: string): string
	self._nextId += 1
	return prefix .. tostring(self._nextId)
end

function PartyLogic._touch(self: PartyLogic, party: Party)
	party.revision += 1
	self:_emit({ type = "party", partyId = party.id })
	self:_emit({ type = "station", stationId = party.stationId })
end

function PartyLogic._notify(self: PartyLogic, party: Party, level: string, text: string, exceptUserId: number?)
	for _, member in party.members do
		if member.userId ~= exceptUserId then
			self:_emit({ type = "notice", userId = member.userId, level = level, text = text })
		end
	end
end

function PartyLogic._partyOf(self: PartyLogic, userId: number): Party?
	local partyId = self._partyByUser[userId]
	return if partyId then self._parties[partyId] else nil
end

function PartyLogic._stationReason(self: PartyLogic, stationId: string): string?
	return self._disabledStations[stationId] or self._matchmakingDisabled
end

function PartyLogic._pendingInvites(self: PartyLogic, partyId: string): { Invite }
	local list = {}
	for _, invite in self._invites do
		if invite.partyId == partyId then
			table.insert(list, invite)
		end
	end
	table.sort(list, function(a, b)
		return a.expiresAt < b.expiresAt or (a.expiresAt == b.expiresAt and a.id < b.id)
	end)
	return list
end

function PartyLogic._closeInvite(self: PartyLogic, invite: Invite, reason: string)
	self._invites[invite.id] = nil
	self:_emit({ type = "inviteClosed", userId = invite.toUserId, inviteId = invite.id, reason = reason })
end

-- Closes a party's pending invites. Returns true when any were open.
function PartyLogic._closePartyInvites(self: PartyLogic, partyId: string, reason: string): boolean
	local closedAny = false
	for _, invite in self:_pendingInvites(partyId) do
		self:_closeInvite(invite, reason)
		closedAny = true
	end
	return closedAny
end

-- Closes invites addressed to a player and refreshes the parties that sent them.
function PartyLogic._closeInvitesTo(self: PartyLogic, userId: number, reason: string)
	local touched: { [string]: boolean } = {}
	for _, invite in table.clone(self._invites) do
		if invite.toUserId == userId then
			self:_closeInvite(invite, reason)
			touched[invite.partyId] = true
		end
	end
	for partyId in touched do
		local party = self._parties[partyId]
		if party then
			self:_touch(party)
		end
	end
end

function PartyLogic._addMember(self: PartyLogic, party: Party, user: User, ready: boolean)
	table.insert(party.members, {
		userId = user.userId,
		name = user.name,
		displayName = user.displayName,
		ready = ready,
	})
	self._partyByUser[user.userId] = party.id
	self:_closeInvitesTo(user.userId, "joined")
	if #party.members >= party.maxSize then
		self:_closePartyInvites(party.id, "full")
	end
end

function PartyLogic._closeParty(self: PartyLogic, party: Party)
	for _, member in party.members do
		self._partyByUser[member.userId] = nil
		self:_emit({ type = "partyLeft", userId = member.userId })
	end
	party.members = {}
	self:_closePartyInvites(party.id, "closed")
	self._parties[party.id] = nil
	if self._partyByStation[party.stationId] == party.id then
		self._partyByStation[party.stationId] = nil
	end
	self:_emit({ type = "station", stationId = party.stationId })
end

function PartyLogic._cancelCountdown(_self: PartyLogic, party: Party)
	party.phase = Phase.Forming
	party.countdownEndsAt = nil
end

--------------------------------------------------------------------------------
-- Requests
--------------------------------------------------------------------------------

function PartyLogic.CreateParty(self: PartyLogic, user: User, params: CreateParams): (boolean, string)
	if type(params) ~= "table" then
		return false, "InvalidRequest"
	end
	if
		type(params.stationId) ~= "string"
		or type(params.chapterId) ~= "string"
		or type(params.difficultyId) ~= "string"
	then
		return false, "InvalidRequest"
	end
	local station = Config.getStation(params.stationId)
	local chapter = Config.getChapter(params.chapterId)
	local difficulty = Config.getDifficulty(params.difficultyId)
	if not station or not chapter or not difficulty then
		return false, "InvalidRequest"
	end
	if type(params.peaceful) ~= "boolean" or (params.peaceful and not Config.PeacefulMode.Enabled) then
		return false, "InvalidRequest"
	end
	local maxSize = params.maxSize
	if not isInteger(maxSize) or maxSize < Config.Party.MinSize or maxSize > Config.Party.MaxSize then
		return false, "InvalidRequest"
	end
	if self._partyByUser[user.userId] then
		return false, "AlreadyInParty"
	end
	if self:_stationReason(station.Id) then
		return false, "StationUnavailable"
	end
	if self._partyByStation[station.Id] then
		return false, "StationOccupied"
	end
	if not self._deps.isUnlocked(user.userId, chapter.Id, difficulty.Id) then
		return false, "Locked"
	end

	local party: Party = {
		id = self:_newId("party-"),
		stationId = station.Id,
		leaderUserId = user.userId,
		chapterId = chapter.Id,
		difficultyId = difficulty.Id,
		peaceful = params.peaceful,
		maxSize = maxSize,
		members = {},
		phase = Phase.Forming,
		countdownEndsAt = nil,
		teleportStartedAt = nil,
		error = nil,
		revision = 0,
	}
	self._parties[party.id] = party
	self._partyByStation[station.Id] = party.id
	self:_addMember(party, user, true)
	self:_touch(party)
	return true, party.id
end

function PartyLogic.JoinStationParty(self: PartyLogic, user: User, stationId: string): (boolean, string)
	if type(stationId) ~= "string" or not Config.getStation(stationId) then
		return false, "InvalidRequest"
	end
	if self._partyByUser[user.userId] then
		return false, "AlreadyInParty"
	end
	if self:_stationReason(stationId) then
		return false, "StationUnavailable"
	end
	local partyId = self._partyByStation[stationId]
	local party = partyId and self._parties[partyId]
	if not party then
		return false, "StationEmpty"
	end
	if party.phase ~= Phase.Forming then
		return false, "WrongPhase"
	end
	if #party.members >= party.maxSize then
		return false, "PartyFull"
	end
	self:_addMember(party, user, false)
	self:_notify(party, Level.Info, `{user.displayName} joined the party.`, user.userId)
	self:_touch(party)
	return true, party.id
end

-- Removes a player from their party. `disconnected` is true when the player
-- left the server (which is also how a successful teleport looks from here).
function PartyLogic.Leave(self: PartyLogic, userId: number, disconnected: boolean?): (boolean, string?)
	local party = self:_partyOf(userId)
	if not party then
		return false, "NotInParty"
	end
	if party.phase == Phase.Teleporting and not disconnected then
		return false, "WrongPhase"
	end
	local member, index = findMember(party, userId)
	if not member or not index then
		return false, "NotInParty"
	end

	table.remove(party.members, index)
	self._partyByUser[userId] = nil
	self:_emit({ type = "partyLeft", userId = userId })

	if #party.members == 0 then
		self:_closeParty(party)
		return true, nil
	end

	local quiet = party.phase == Phase.Teleporting
	if party.leaderUserId == userId then
		local heir = party.members[1]
		party.leaderUserId = heir.userId
		heir.ready = true
		if not quiet then
			self:_notify(party, Level.Info, `{member.displayName} left. {heir.displayName} is now the party leader.`)
		end
	elseif not quiet then
		self:_notify(party, Level.Info, `{member.displayName} left the party.`)
	end
	if party.phase == Phase.Countdown then
		self:_cancelCountdown(party)
		self:_notify(party, Level.Warning, `Countdown cancelled - {member.displayName} left the party.`)
	end
	self:_touch(party)
	return true, nil
end

-- A player left the server: drop them from their party and from every invite.
function PartyLogic.RemoveUser(self: PartyLogic, userId: number)
	self:_closeInvitesTo(userId, "offline")
	if self._partyByUser[userId] then
		self:Leave(userId, true)
	end
	for key in table.clone(self._inviteCooldown) do
		local from, to = key:match("^(%d+):(%d+)$")
		if tonumber(from) == userId or tonumber(to) == userId then
			self._inviteCooldown[key] = nil
		end
	end
end

function PartyLogic.SetReady(self: PartyLogic, userId: number, ready: boolean): (boolean, string?)
	if type(ready) ~= "boolean" then
		return false, "InvalidRequest"
	end
	local party = self:_partyOf(userId)
	if not party then
		return false, "NotInParty"
	end
	if party.phase ~= Phase.Forming then
		return false, "WrongPhase"
	end
	local member = findMember(party, userId)
	if not member then
		return false, "NotInParty"
	end
	-- The leader is always ready: pressing Start is their confirmation.
	if party.leaderUserId == userId then
		return true, nil
	end
	if member.ready ~= ready then
		member.ready = ready
		self:_touch(party)
	end
	return true, nil
end

function PartyLogic.Invite(self: PartyLogic, userId: number, target: User): (boolean, string?)
	local party = self:_partyOf(userId)
	if not party then
		return false, "NotInParty"
	end
	if Config.Party.LeaderOnlyInvites and party.leaderUserId ~= userId then
		return false, "NotLeader"
	end
	if party.phase ~= Phase.Forming then
		return false, "WrongPhase"
	end
	if #party.members >= party.maxSize then
		return false, "PartyFull"
	end
	if target.userId == userId or self._partyByUser[target.userId] then
		return false, "PlayerUnavailable"
	end
	local pending = self:_pendingInvites(party.id)
	for _, invite in pending do
		if invite.toUserId == target.userId then
			return false, "AlreadyInvited"
		end
	end
	if #pending >= Config.Party.MaxPendingInvites then
		return false, "InviteLimit"
	end
	local now = self._deps.now()
	local cooldownKey = `{userId}:{target.userId}`
	local allowedAt = self._inviteCooldown[cooldownKey]
	if allowedAt and now < allowedAt then
		return false, "InviteCooldown"
	end
	local acceptsInvites = self._deps.acceptsInvites
	if acceptsInvites and not acceptsInvites(target.userId) then
		return false, "InvitesBlocked"
	end

	local sender = findMember(party, userId) :: Member
	local invite: Invite = {
		id = self:_newId("invite-"),
		partyId = party.id,
		fromUserId = userId,
		fromName = sender.displayName,
		toUserId = target.userId,
		toName = target.displayName,
		expiresAt = now + Config.Party.InviteTtlSeconds,
	}
	self._invites[invite.id] = invite
	self._inviteCooldown[cooldownKey] = now + Config.Party.InviteCooldownSeconds
	self:_emit({ type = "invite", userId = target.userId, invite = self:_incoming(invite, party) })
	self:_touch(party)
	return true, nil
end

function PartyLogic.CancelInvite(self: PartyLogic, userId: number, targetUserId: number): (boolean, string?)
	local party = self:_partyOf(userId)
	if not party then
		return false, "NotInParty"
	end
	if Config.Party.LeaderOnlyInvites and party.leaderUserId ~= userId then
		return false, "NotLeader"
	end
	for _, invite in self:_pendingInvites(party.id) do
		if invite.toUserId == targetUserId then
			self:_closeInvite(invite, "cancelled")
			self:_touch(party)
			return true, nil
		end
	end
	return false, "InviteExpired"
end

function PartyLogic.RespondInvite(self: PartyLogic, user: User, inviteId: string, accept: boolean): (boolean, string?)
	if type(inviteId) ~= "string" or type(accept) ~= "boolean" then
		return false, "InvalidRequest"
	end
	local invite = self._invites[inviteId]
	if not invite or invite.toUserId ~= user.userId or self._deps.now() >= invite.expiresAt then
		return false, "InviteExpired"
	end
	local party = self._parties[invite.partyId]
	if not party then
		self:_closeInvite(invite, "closed")
		return false, "InviteExpired"
	end

	if not accept then
		self:_closeInvite(invite, "declined")
		self:_emit({
			type = "notice",
			userId = party.leaderUserId,
			level = Level.Info,
			text = `{user.displayName} declined the invite.`,
		})
		self:_touch(party)
		return true, nil
	end

	if self._partyByUser[user.userId] then
		return false, "AlreadyInParty"
	end
	if party.phase ~= Phase.Forming then
		return false, "WrongPhase"
	end
	if #party.members >= party.maxSize then
		self:_closeInvite(invite, "full")
		self:_touch(party)
		return false, "PartyFull"
	end
	self:_addMember(party, user, false)
	self:_notify(party, Level.Success, `{user.displayName} joined the party.`, user.userId)
	self:_touch(party)
	return true, party.id
end

function PartyLogic.Start(self: PartyLogic, userId: number): (boolean, string?)
	local party = self:_partyOf(userId)
	if not party then
		return false, "NotInParty"
	end
	if party.leaderUserId ~= userId then
		return false, "NotLeader"
	end
	if party.phase ~= Phase.Forming then
		return false, "WrongPhase"
	end
	if self:_stationReason(party.stationId) then
		return false, "StationUnavailable"
	end
	if Config.Party.RequireAllReady then
		for _, member in party.members do
			if not member.ready then
				return false, "NotReady"
			end
		end
	end
	party.phase = Phase.Countdown
	party.countdownEndsAt = self._deps.now() + Config.Party.CountdownSeconds
	party.error = nil
	self:_closePartyInvites(party.id, "starting")
	self:_touch(party)
	return true, nil
end

function PartyLogic.CancelCountdown(self: PartyLogic, userId: number): (boolean, string?)
	local party = self:_partyOf(userId)
	if not party then
		return false, "NotInParty"
	end
	if party.leaderUserId ~= userId then
		return false, "NotLeader"
	end
	if party.phase ~= Phase.Countdown then
		return false, "WrongPhase"
	end
	self:_cancelCountdown(party)
	self:_notify(party, Level.Info, "The leader cancelled the countdown.", userId)
	self:_touch(party)
	return true, nil
end

--------------------------------------------------------------------------------
-- Server-driven transitions
--------------------------------------------------------------------------------

-- Advances timers: invite expiry, countdown completion, teleport timeout and
-- error display. Call a few times per second.
function PartyLogic.Tick(self: PartyLogic)
	local now = self._deps.now()

	local expired: { [string]: boolean } = {}
	for _, invite in table.clone(self._invites) do
		if now >= invite.expiresAt then
			self:_closeInvite(invite, "expired")
			expired[invite.partyId] = true
		end
	end
	for partyId in expired do
		local party = self._parties[partyId]
		if party then
			self:_touch(party)
		end
	end

	for _, party in table.clone(self._parties) do
		if party.phase == Phase.Countdown and party.countdownEndsAt and now >= party.countdownEndsAt then
			party.phase = Phase.Teleporting
			party.countdownEndsAt = nil
			party.teleportStartedAt = now
			self:_touch(party)
			self:_emit({ type = "teleport", partyId = party.id })
		elseif
			party.phase == Phase.Teleporting
			and party.teleportStartedAt
			and now - party.teleportStartedAt >= Config.Party.TeleportTimeoutSeconds
		then
			self:TeleportFailed(party.id, "TeleportTimeout")
		elseif party.error and now - party.error.at >= Config.Party.ErrorDisplaySeconds then
			party.error = nil
			self:_touch(party)
		end
	end
end

-- The teleport did not happen: keep the party together and let it try again.
function PartyLogic.TeleportFailed(self: PartyLogic, partyId: string, code: string?): boolean
	local party = self._parties[partyId]
	if not party or party.phase ~= Phase.Teleporting then
		return false
	end
	local errorCode = if code and Net.Messages[code] then code else "TeleportFailed"
	party.phase = Phase.Forming
	party.teleportStartedAt = nil
	party.error = { code = errorCode, message = Net.Messages[errorCode], at = self._deps.now() }
	self:_notify(party, Level.Error, Net.Messages[errorCode])
	self:_touch(party)
	return true
end

-- Closes or reopens one station. A closed station keeps its party but cannot
-- start a run or accept a new party.
function PartyLogic.SetStationDisabled(self: PartyLogic, stationId: string, reason: string?)
	if not Config.getStation(stationId) then
		return
	end
	self._disabledStations[stationId] = reason :: any
	local partyId = self._partyByStation[stationId]
	local party = partyId and self._parties[partyId]
	if party and reason and party.phase == Phase.Countdown then
		self:_cancelCountdown(party)
		self:_notify(party, Level.Warning, "Countdown cancelled - this station was closed.")
		self:_touch(party)
	else
		self:_emit({ type = "station", stationId = stationId })
	end
end

-- Closes or reopens every station at once (nil reopens).
function PartyLogic.SetMatchmakingDisabled(self: PartyLogic, reason: string?)
	self._matchmakingDisabled = reason
	for _, station in Config.Stations do
		local partyId = self._partyByStation[station.Id]
		local party = partyId and self._parties[partyId]
		if party and reason and party.phase == Phase.Countdown then
			self:_cancelCountdown(party)
			self:_notify(party, Level.Warning, "Countdown cancelled - matchmaking was paused.")
			self:_touch(party)
		else
			self:_emit({ type = "station", stationId = station.Id })
		end
	end
end

function PartyLogic.DrainEffects(self: PartyLogic): { Effect }
	local effects = self._effects
	self._effects = {}
	return effects
end

--------------------------------------------------------------------------------
-- Queries
--------------------------------------------------------------------------------

function PartyLogic.GetPartyIdOf(self: PartyLogic, userId: number): string?
	return self._partyByUser[userId]
end

function PartyLogic.GetParty(self: PartyLogic, partyId: string): Party?
	return self._parties[partyId]
end

function PartyLogic.GetStationPartyId(self: PartyLogic, stationId: string): string?
	return self._partyByStation[stationId]
end

function PartyLogic.GetMemberIds(self: PartyLogic, partyId: string): { number }
	local ids = {}
	local party = self._parties[partyId]
	if party then
		for _, member in party.members do
			table.insert(ids, member.userId)
		end
	end
	return ids
end

function PartyLogic._incoming(_self: PartyLogic, invite: Invite, party: Party): Net.IncomingInvite
	local chapter = Config.getChapter(party.chapterId)
	local difficulty = Config.getDifficulty(party.difficultyId)
	return {
		id = invite.id,
		fromUserId = invite.fromUserId,
		fromName = invite.fromName,
		stationId = party.stationId,
		chapterName = if chapter then chapter.Name else party.chapterId,
		difficultyName = if difficulty then difficulty.Name else party.difficultyId,
		peaceful = party.peaceful,
		memberCount = #party.members,
		maxSize = party.maxSize,
		expiresAt = invite.expiresAt,
	}
end

-- Open invitations addressed to a player.
function PartyLogic.GetInvitesFor(self: PartyLogic, userId: number): { Net.IncomingInvite }
	local list = {}
	for _, invite in self._invites do
		local party = self._parties[invite.partyId]
		if invite.toUserId == userId and party then
			table.insert(list, self:_incoming(invite, party))
		end
	end
	table.sort(list, function(a, b)
		return a.expiresAt < b.expiresAt
	end)
	return list
end

function PartyLogic.PartySnapshot(self: PartyLogic, partyId: string): Net.PartySnapshot?
	local party = self._parties[partyId]
	if not party then
		return nil
	end
	local members = {}
	for _, member in party.members do
		table.insert(members, {
			userId = member.userId,
			name = member.name,
			displayName = member.displayName,
			ready = member.ready,
			isLeader = member.userId == party.leaderUserId,
		})
	end
	local invites = {}
	for _, invite in self:_pendingInvites(party.id) do
		table.insert(invites, {
			id = invite.id,
			userId = invite.toUserId,
			displayName = invite.toName,
			expiresAt = invite.expiresAt,
		})
	end
	return {
		id = party.id,
		stationId = party.stationId,
		leaderUserId = party.leaderUserId,
		chapterId = party.chapterId,
		difficultyId = party.difficultyId,
		peaceful = party.peaceful,
		maxSize = party.maxSize,
		members = members,
		invites = invites,
		phase = party.phase,
		countdownSeconds = if party.phase == Phase.Countdown then Config.Party.CountdownSeconds else nil,
		countdownEndsAt = party.countdownEndsAt,
		error = if party.error then { code = party.error.code, message = party.error.message } else nil,
		revision = party.revision,
	}
end

function PartyLogic.StationSnapshot(self: PartyLogic, stationId: string): Net.StationSnapshot?
	local station = Config.getStation(stationId)
	if not station then
		return nil
	end
	local partyId = self._partyByStation[stationId]
	local party = partyId and self._parties[partyId]
	local reason = self:_stationReason(stationId)

	local snapshot: Net.StationSnapshot = {
		id = stationId,
		status = Status.Available,
		message = nil,
		partyId = nil,
		leaderName = nil,
		memberNames = {},
		memberCount = 0,
		maxSize = station.DefaultSize,
		chapterName = nil,
		difficultyName = nil,
		peaceful = nil,
		countdownEndsAt = nil,
	}

	if party then
		local chapter = Config.getChapter(party.chapterId)
		local difficulty = Config.getDifficulty(party.difficultyId)
		snapshot.partyId = party.id
		snapshot.maxSize = party.maxSize
		snapshot.memberCount = #party.members
		snapshot.chapterName = if chapter then chapter.Name else nil
		snapshot.difficultyName = if difficulty then difficulty.Name else nil
		snapshot.peaceful = party.peaceful
		snapshot.countdownEndsAt = party.countdownEndsAt
		for _, member in party.members do
			table.insert(snapshot.memberNames, member.displayName)
			if member.userId == party.leaderUserId then
				snapshot.leaderName = member.displayName
			end
		end
	end

	if reason then
		snapshot.status = Status.Unavailable
		snapshot.message = reason
	elseif not party then
		snapshot.status = Status.Available
	elseif party.error then
		snapshot.status = Status.Error
		snapshot.message = "Teleport failed"
	elseif party.phase ~= Phase.Forming then
		snapshot.status = Status.Starting
	elseif #party.members >= party.maxSize then
		snapshot.status = Status.Full
	else
		snapshot.status = Status.Occupied
	end
	return snapshot
end

function PartyLogic.AllStationSnapshots(self: PartyLogic): { [string]: Net.StationSnapshot }
	local all = {}
	for _, station in Config.Stations do
		all[station.Id] = self:StationSnapshot(station.Id) :: Net.StationSnapshot
	end
	return all
end

return PartyLogic
