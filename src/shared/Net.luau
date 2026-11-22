--!strict
-- Remote contract between the lobby server and its clients.
--
-- One RemoteFunction carries every client request and returns a Result, so a
-- button can show loading and then success or a readable error. One
-- RemoteEvent carries server pushes, tagged by topic. Clients only ever send
-- intents; all party and station state lives on the server.

export type Result = { ok: boolean, code: string?, message: string?, data: any? }

export type MemberSnapshot = {
	userId: number,
	name: string,
	displayName: string,
	ready: boolean,
	isLeader: boolean,
}

export type InviteSnapshot = {
	id: string,
	userId: number,
	displayName: string,
	expiresAt: number,
}

export type PartyError = { code: string, message: string }

-- Sent to every member whenever their party changes. Times are in
-- Workspace:GetServerTimeNow() seconds.
export type PartySnapshot = {
	id: string,
	stationId: string,
	leaderUserId: number,
	chapterId: string,
	difficultyId: string,
	peaceful: boolean,
	maxSize: number,
	members: { MemberSnapshot },
	invites: { InviteSnapshot },
	phase: string,
	countdownSeconds: number?,
	countdownEndsAt: number?,
	error: PartyError?,
	revision: number,
}

export type StationSnapshot = {
	id: string,
	status: string,
	message: string?,
	partyId: string?,
	leaderName: string?,
	memberNames: { string },
	memberCount: number,
	maxSize: number,
	chapterName: string?,
	difficultyName: string?,
	peaceful: boolean?,
	countdownEndsAt: number?,
}

-- An invitation addressed to the receiving player.
export type IncomingInvite = {
	id: string,
	fromUserId: number,
	fromName: string,
	stationId: string,
	chapterName: string,
	difficultyName: string,
	peaceful: boolean,
	memberCount: number,
	maxSize: number,
	expiresAt: number,
}

export type Notice = { level: string, text: string }

local Net = {}

Net.FolderName = "Remotes"
Net.RequestName = "Request"
Net.PushName = "Push"

Net.Action = {
	GetState = "GetState",
	CreateParty = "CreateParty",
	JoinStationParty = "JoinStationParty",
	LeaveParty = "LeaveParty",
	SetReady = "SetReady",
	Invite = "Invite",
	CancelInvite = "CancelInvite",
	RespondInvite = "RespondInvite",
	Start = "Start",
	CancelCountdown = "CancelCountdown",
	UpdateSetting = "UpdateSetting",
}

Net.Topic = {
	-- PartySnapshot, or nil when the player is no longer in a party.
	Party = "party",
	-- { [stationId]: StationSnapshot }, full or partial.
	Stations = "stations",
	-- IncomingInvite
	Invite = "invite",
	-- { id: string, reason: string }
	InviteClosed = "inviteClosed",
	-- Notice
	Notice = "notice",
	-- { stationId: string?, open: boolean? } - the station zone the player is standing in.
	Presence = "presence",
	-- { progress: Unlocks.Progress, settings: {[string]: any} }
	Profile = "profile",
}

Net.Phase = {
	Forming = "Forming",
	Countdown = "Countdown",
	Teleporting = "Teleporting",
}

Net.StationStatus = {
	Available = "Available",
	Occupied = "Occupied",
	Full = "Full",
	Starting = "Starting",
	Unavailable = "Unavailable",
	Error = "Error",
}

Net.NoticeLevel = {
	Info = "info",
	Success = "success",
	Warning = "warning",
	Error = "error",
}

-- Failure codes with the sentence shown to the player.
Net.Messages = {
	RateLimited = "Slow down a moment and try again.",
	InvalidRequest = "That request was not valid.",
	NotInParty = "You are not in a party.",
	AlreadyInParty = "You are already in a party. Leave it first.",
	NotLeader = "Only the party leader can do that.",
	StationUnavailable = "This station is unavailable right now.",
	StationOccupied = "Another party is already forming at this station.",
	StationEmpty = "There is no party at this station to join.",
	TooFar = "Step onto the station pad first.",
	PartyFull = "This party is full.",
	Locked = "You have not unlocked that yet.",
	NotReady = "Everyone must be ready before the run can start.",
	WrongPhase = "The party cannot do that right now.",
	PlayerUnavailable = "That player cannot be invited right now.",
	AlreadyInvited = "That player already has an invite from your party.",
	InviteCooldown = "Wait a few seconds before inviting that player again.",
	InviteLimit = "Too many invites are pending. Wait for a reply first.",
	InvitesBlocked = "That player is not accepting invites.",
	InviteExpired = "That invite is no longer valid.",
	TeleportFailed = "The teleport failed. Your party is still together - try again.",
	TeleportTimeout = "The teleport took too long. Your party is still together - try again.",
	Internal = "Something went wrong. Please try again.",
}

function Net.ok(data: any?): Result
	return { ok = true, data = data }
end

function Net.fail(code: string, message: string?): Result
	return { ok = false, code = code, message = message or Net.Messages[code] or Net.Messages.Internal }
end

-- Server: creates the remotes under `parent` (the shared MushroomLobby folder).
function Net.createServer(parent: Instance): (RemoteFunction, RemoteEvent)
	local folder = Instance.new("Folder")
	folder.Name = Net.FolderName
	local request = Instance.new("RemoteFunction")
	request.Name = Net.RequestName
	request.Parent = folder
	local push = Instance.new("RemoteEvent")
	push.Name = Net.PushName
	push.Parent = folder
	folder.Parent = parent
	return request, push
end

-- Client: waits for the remotes created by the server.
function Net.waitClient(parent: Instance): (RemoteFunction, RemoteEvent)
	local folder = parent:WaitForChild(Net.FolderName)
	local request = folder:WaitForChild(Net.RequestName) :: RemoteFunction
	local push = folder:WaitForChild(Net.PushName) :: RemoteEvent
	return request, push
end

return Net
