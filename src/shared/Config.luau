--!strict
-- Single source of lobby rules and content. Server and client both read this;
-- only the server's copy is trusted.
--
-- Chapters, difficulties and Peaceful Mode are forwarded to the gameplay place
-- as teleport data (see TeleportController). They must match what the gameplay
-- place actually supports: edit this file when that content changes.

export type UnlockRule = { Chapter: string, Difficulty: string }

export type Chapter = {
	Id: string,
	Order: number,
	Name: string,
	Label: string,
	Description: string,
	Scene: string,
	Unlock: UnlockRule?,
}

export type Difficulty = {
	Id: string,
	Order: number,
	Name: string,
	Summary: string,
	Pips: number,
	-- Id of the difficulty that must be cleared on the same chapter first.
	UnlockAfter: string?,
}

export type Station = {
	Id: string,
	Order: number,
	Name: string,
	Tagline: string,
	DefaultSize: number,
	Accent: string,
}

local Config = {}

Config.Places = {
	Lobby = 106448766989936,
	Gameplay = 129614341268000,
}

Config.Party = {
	MinSize = 1,
	MaxSize = 4,
	-- Seconds between the leader pressing Start and the teleport. Keep within 3-5.
	CountdownSeconds = 5,
	RequireAllReady = true,
	LeaderOnlyInvites = true,
	InviteTtlSeconds = 30,
	InviteCooldownSeconds = 8,
	MaxPendingInvites = 6,
	-- A teleport that has not removed the party from this server after this long is treated as failed.
	TeleportTimeoutSeconds = 20,
	TeleportMaxAttempts = 2,
	TeleportRetryDelaySeconds = 2,
	-- How long a failed teleport keeps the station in its error state.
	ErrorDisplaySeconds = 6,
	-- Horizontal distance from a station pad within which create and join requests are accepted.
	StationRange = 16,
	-- Token bucket for the request remote, per player.
	RequestBurst = 8,
	RequestsPerSecond = 4,
}

Config.Stations = {
	{
		Id = "solo",
		Order = 1,
		Name = "Solo",
		Tagline = "Guard the grove alone",
		DefaultSize = 1,
		Accent = "Amber",
	},
	{
		Id = "duo",
		Order = 2,
		Name = "Duo",
		Tagline = "Two caps, one path",
		DefaultSize = 2,
		Accent = "Spore",
	},
	{
		Id = "trio",
		Order = 3,
		Name = "Trio",
		Tagline = "Three hold the ring",
		DefaultSize = 3,
		Accent = "Crystal",
	},
	{
		Id = "squad",
		Order = 4,
		Name = "Squad",
		Tagline = "The full circle",
		DefaultSize = 4,
		Accent = "Cap",
	},
} :: { Station }

Config.Chapters = {
	{
		Id = "sporewood_hollow",
		Order = 1,
		Name = "Sporewood Hollow",
		Label = "Chapter 1",
		Description = "Hold the lantern grove while the blight creeps in from the old roots.",
		Scene = "Grove",
	},
	{
		Id = "glowcap_caverns",
		Order = 2,
		Name = "Glowcap Caverns",
		Label = "Chapter 2",
		Description = "Descend into crystal-lit tunnels where the spores never sleep.",
		Scene = "Cavern",
		Unlock = { Chapter = "sporewood_hollow", Difficulty = "normal" },
	},
	{
		Id = "rootdeep_sanctum",
		Order = 3,
		Name = "Rootdeep Sanctum",
		Label = "Chapter 3",
		Description = "Reach the heart of the elder tree before its last lantern fades.",
		Scene = "Sanctum",
		Unlock = { Chapter = "glowcap_caverns", Difficulty = "normal" },
	},
} :: { Chapter }

Config.Difficulties = {
	{
		Id = "normal",
		Order = 1,
		Name = "Normal",
		Summary = "The standard watch.",
		Pips = 1,
	},
	{
		Id = "hard",
		Order = 2,
		Name = "Hard",
		Summary = "Tougher blight, better spoils.",
		Pips = 2,
		UnlockAfter = "normal",
	},
	{
		Id = "nightmare",
		Order = 3,
		Name = "Nightmare",
		Summary = "No mercy after dusk.",
		Pips = 3,
		UnlockAfter = "hard",
	},
} :: { Difficulty }

Config.PeacefulMode = {
	-- Set false if the gameplay place does not honour the `peaceful` teleport flag;
	-- the toggle is then removed from the Create Party panel.
	Enabled = true,
	Name = "Peaceful Mode",
	Description = "No blight attacks. Explore and build at your own pace.",
}

-- Progress is written by the gameplay place and only read here.
Config.Progression = {
	DataStoreName = "MG_Progress_v1",
	KeyPrefix = "player_",
}

Config.Settings = {
	DataStoreName = "MG_LobbySettings_v1",
	KeyPrefix = "player_",
	Defaults = {
		uiScale = "normal",
		reduceMotion = false,
		allowInvites = true,
		ambientEffects = true,
	},
	UiScaleOptions = { "small", "normal", "large" },
	UiScaleFactors = { small = 0.88, normal = 1, large = 1.14 },
}

-- HUD entries for systems this lobby package does not own. Each stays hidden
-- until its target exists at runtime, so no button is ever shown without a
-- working destination. `Gui` is the name of a ScreenGui in PlayerGui that the
-- button toggles.
Config.Hud = {
	ExternalFeatures = {
		{ Id = "pets", Name = "Pets", Icon = "Paw", Gui = "PetsGui" },
		{ Id = "shop", Name = "Shop", Icon = "Bag", Gui = "ShopGui" },
		{ Id = "stats", Name = "Stats", Icon = "Chart", Gui = "StatsGui" },
		{ Id = "news", Name = "News", Icon = "Scroll", Gui = "NewsGui" },
	},
	-- leaderstats values shown as currency pills, in this order, when present.
	CurrencyStats = { "Spores", "Coins", "Gems" },
	MaxCurrencyPills = 2,
	MaxNotifications = 20,
}

Config.World = {
	ModelName = "MushroomLobby",
	StationsFolder = "Stations",
}

function Config.getStation(id: string): Station?
	for _, station in Config.Stations do
		if station.Id == id then
			return station
		end
	end
	return nil
end

function Config.getChapter(id: string): Chapter?
	for _, chapter in Config.Chapters do
		if chapter.Id == id then
			return chapter
		end
	end
	return nil
end

function Config.getDifficulty(id: string): Difficulty?
	for _, difficulty in Config.Difficulties do
		if difficulty.Id == id then
			return difficulty
		end
	end
	return nil
end

return Config
