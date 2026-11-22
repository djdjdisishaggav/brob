-- Client-side mirror of what the server has told this player. Nothing here is
-- authoritative: views render it, and every action goes through `request`,
-- which asks the server and returns its verdict.

local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("MushroomLobby")

local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Signal = require(Shared.Signal)
local Unlocks = require(Shared.Unlocks)

export type Notification = { id: number, level: string, text: string, at: number, read: boolean }

local Store = {}

Store.state = {
	loaded = false,
	progress = Unlocks.emptyProgress(),
	settings = table.clone(Config.Settings.Defaults) :: { [string]: any },
	party = nil :: Net.PartySnapshot?,
	stations = {} :: { [string]: Net.StationSnapshot },
	invites = {} :: { Net.IncomingInvite },
	-- Station pad the player is standing on.
	presence = nil :: string?,
	notifications = {} :: { Notification },
	unread = 0,
}

-- Fired with the name of the state field that changed.
Store.changed = Signal.new()
-- Fired with (stationId: string?, viaPrompt: boolean) when the player enters or
-- leaves a station pad or uses its prompt.
Store.presenceChanged = Signal.new()
-- Fired with a Net.Notice for transient feedback (toasts).
Store.noticed = Signal.new()
-- Fired with (Net.IncomingInvite) when a new invitation arrives.
Store.invited = Signal.new()

local requestRemote: RemoteFunction? = nil
local nextNotificationId = 0

function Store.serverNow(): number
	return Workspace:GetServerTimeNow()
end

-- Records a notice in the notification list and announces it.
function Store.notify(level: string, text: string)
	local state = Store.state
	nextNotificationId += 1
	table.insert(state.notifications, 1, {
		id = nextNotificationId,
		level = level,
		text = text,
		at = Store.serverNow(),
		read = false,
	})
	while #state.notifications > Config.Hud.MaxNotifications do
		table.remove(state.notifications)
	end
	state.unread += 1
	Store.changed:Fire("notifications")
	Store.noticed:Fire({ level = level, text = text })
end

function Store.markNotificationsRead()
	local state = Store.state
	if state.unread == 0 then
		return
	end
	for _, notification in state.notifications do
		notification.read = true
	end
	state.unread = 0
	Store.changed:Fire("notifications")
end

-- Sends an intent to the server and returns its Net.Result. Yields. A failed
-- remote call is reported as an ordinary failure so callers have one path.
function Store.request(action: string, payload: { [string]: any }?): Net.Result
	if not requestRemote then
		return Net.fail("Internal")
	end
	local ok, response = pcall(function()
		return (requestRemote :: RemoteFunction):InvokeServer(action, payload)
	end)
	if not ok or type(response) ~= "table" then
		return Net.fail("Internal")
	end
	return response
end

local function removeInvite(inviteId: string): boolean
	for index, invite in Store.state.invites do
		if invite.id == inviteId then
			table.remove(Store.state.invites, index)
			return true
		end
	end
	return false
end

local function applyProfile(profile: any)
	if type(profile) ~= "table" then
		return
	end
	Store.state.progress = Unlocks.sanitize(profile.progress)
	if type(profile.settings) == "table" then
		for key, value in profile.settings do
			Store.state.settings[key] = value
		end
	end
	Store.changed:Fire("progress")
	Store.changed:Fire("settings")
end

local handlers: { [string]: (payload: any) -> () } = {}

handlers[Net.Topic.Party] = function(payload)
	Store.state.party = payload
	Store.changed:Fire("party")
end

handlers[Net.Topic.Stations] = function(payload)
	if type(payload) ~= "table" then
		return
	end
	for stationId, snapshot in payload do
		Store.state.stations[stationId] = snapshot
	end
	Store.changed:Fire("stations")
end

handlers[Net.Topic.Invite] = function(payload)
	if type(payload) ~= "table" or type(payload.id) ~= "string" then
		return
	end
	removeInvite(payload.id)
	table.insert(Store.state.invites, payload)
	Store.changed:Fire("invites")
	Store.invited:Fire(payload)
end

handlers[Net.Topic.InviteClosed] = function(payload)
	if type(payload) == "table" and removeInvite(payload.id) then
		Store.changed:Fire("invites")
	end
end

handlers[Net.Topic.Notice] = function(payload)
	if type(payload) == "table" and type(payload.text) == "string" then
		Store.notify(payload.level or Net.NoticeLevel.Info, payload.text)
	end
end

handlers[Net.Topic.Presence] = function(payload)
	local stationId = if type(payload) == "table" then payload.stationId else nil
	Store.state.presence = stationId
	Store.changed:Fire("presence")
	Store.presenceChanged:Fire(stationId, type(payload) == "table" and payload.viaPrompt == true)
end

handlers[Net.Topic.Profile] = applyProfile

-- Connects to the server and loads the initial state. Yields until loaded.
function Store.start()
	local request, push = Net.waitClient(Shared)
	requestRemote = request
	push.OnClientEvent:Connect(function(topic, payload)
		local handler = handlers[topic]
		if handler then
			handler(payload)
		end
	end)

	local response = Store.request(Net.Action.GetState)
	if response.ok and type(response.data) == "table" then
		local data = response.data
		applyProfile(data.profile)
		handlers[Net.Topic.Stations](data.stations)
		Store.state.party = data.party
		Store.state.invites = if type(data.invites) == "table" then data.invites else {}
		Store.state.presence = data.presence
		Store.changed:Fire("party")
		Store.changed:Fire("invites")
	end
	Store.state.loaded = true
	Store.changed:Fire("loaded")
end

return Store
