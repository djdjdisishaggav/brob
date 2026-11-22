-- Links the physical stations in the world to the party system: detects which
-- station pad each player is standing on, relays the station prompts, and
-- keeps the station displays in step with the server's snapshots.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("MushroomLobby")

local Config = require(Shared.Config)
local Net = require(Shared.Net)

type View = { Render: (self: any, snapshot: Net.StationSnapshot, serverNow: number) -> (), Destroy: (self: any) -> () }

type StationEntry = {
	model: Model,
	pad: BasePart,
	radius: number,
	view: View?,
	snapshot: Net.StationSnapshot?,
}

local PRESENCE_INTERVAL = 0.2
local COUNTDOWN_REFRESH = 0.25
-- Vertical slack around the pad so jumping does not drop a player out of the zone.
local ZONE_HEIGHT = 14

local StationService = {}

-- Called when a player enters or leaves a station pad, or uses its prompt.
StationService.onPresenceChanged = nil :: ((player: Player, stationId: string?, viaPrompt: boolean) -> ())?

local stations: { [string]: StationEntry } = {}
local presence: { [Player]: string } = {}
local started = false

local function rootPosition(player: Player): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.CFrame.Position
	end
	return nil
end

local function horizontalDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function stationAt(position: Vector3): string?
	for id, entry in stations do
		local center = entry.pad.CFrame.Position
		if horizontalDistance(position, center) <= entry.radius and math.abs(position.Y - center.Y) <= ZONE_HEIGHT then
			return id
		end
	end
	return nil
end

local function setPresence(player: Player, stationId: string?, viaPrompt: boolean)
	if presence[player] == stationId and not viaPrompt then
		return
	end
	presence[player] = stationId :: any
	if StationService.onPresenceChanged then
		StationService.onPresenceChanged(player, stationId, viaPrompt)
	end
end

local function register(model: Model, viewFactory: (Model) -> View)
	local id = model:GetAttribute("StationId")
	if type(id) ~= "string" or not Config.getStation(id) then
		return
	end
	local pad = model:FindFirstChild("Pad", true)
	if not pad or not pad:IsA("BasePart") then
		warn(`[MushroomLobby] station "{id}" has no Pad part and stays closed`)
		return
	end
	local radius = pad:GetAttribute("ZoneRadius")
	local entry: StationEntry = {
		model = model,
		pad = pad,
		radius = if type(radius) == "number" then radius else 9,
		view = nil,
		snapshot = nil,
	}
	local ok, view = pcall(viewFactory, model)
	if ok then
		entry.view = view
	else
		warn(`[MushroomLobby] station "{id}" display failed to initialise: {view}`)
	end
	stations[id] = entry

	local prompt = model:FindFirstChild("Prompt", true)
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Triggered:Connect(function(player)
			setPresence(player, id, true)
		end)
	end
end

local function missingStations(): { string }
	local missing = {}
	for _, station in Config.Stations do
		if not stations[station.Id] then
			table.insert(missing, station.Id)
		end
	end
	return missing
end

-- Finds the built stations and starts tracking players. Returns the ids of
-- configured stations that are missing from the world.
function StationService.start(options: { viewFactory: ((Model) -> View)? }?): { string }
	if started then
		return missingStations()
	end
	started = true

	local viewFactory = options and options.viewFactory
	if not viewFactory then
		local StationView = require(script.Parent.World.StationView) :: any
		viewFactory = function(model)
			return StationView.new(model)
		end
	end

	local lobby = Workspace:FindFirstChild(Config.World.ModelName)
	local folder = lobby and lobby:FindFirstChild(Config.World.StationsFolder)
	if folder then
		for _, child in folder:GetChildren() do
			if child:IsA("Model") then
				register(child, viewFactory :: (Model) -> View)
			end
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		presence[player] = nil
	end)

	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				local position = rootPosition(player)
				setPresence(player, if position then stationAt(position) else nil, false)
			end
			task.wait(PRESENCE_INTERVAL)
		end
	end)

	-- Stations that are counting down need their display refreshed between snapshots.
	task.spawn(function()
		while true do
			local now = Workspace:GetServerTimeNow()
			for _, entry in stations do
				local snapshot = entry.snapshot
				if entry.view and snapshot and snapshot.status == Net.StationStatus.Starting then
					entry.view:Render(snapshot, now)
				end
			end
			task.wait(COUNTDOWN_REFRESH)
		end
	end)

	return missingStations()
end

-- The station whose pad the player is standing on, if any.
function StationService.getPresence(player: Player): string?
	return presence[player]
end

-- Server-side proximity check for create and join requests.
function StationService.isPlayerNear(player: Player, stationId: string): boolean
	local entry = stations[stationId]
	local position = rootPosition(player)
	if not entry or not position then
		return false
	end
	local center = entry.pad.CFrame.Position
	return horizontalDistance(position, center) <= Config.Party.StationRange
		and math.abs(position.Y - center.Y) <= ZONE_HEIGHT
end

function StationService.render(snapshot: Net.StationSnapshot)
	local entry = stations[snapshot.id]
	if not entry then
		return
	end
	entry.snapshot = snapshot
	if entry.view then
		entry.view:Render(snapshot, Workspace:GetServerTimeNow())
	end
end

return StationService
