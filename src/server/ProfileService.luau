-- Per-player profile: unlock progress (read-only here, written by the
-- gameplay place) and lobby settings. Both fall back to safe defaults when
-- DataStores are unavailable, so the lobby stays usable.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("MushroomLobby")

local Config = require(Shared.Config)
local Unlocks = require(Shared.Unlocks)

type Profile = {
	progress: Unlocks.Progress,
	settings: { [string]: any },
	settingsDirty: boolean,
}

local ProfileService = {}

-- Called with the player once their stored profile has been read.
ProfileService.onLoaded = nil :: ((player: Player) -> ())?

local profiles: { [Player]: Profile } = {}
local started = false

local function defaults(): Profile
	return {
		progress = Unlocks.emptyProgress(),
		settings = table.clone(Config.Settings.Defaults),
		settingsDirty = false,
	}
end

local function isValidSetting(key: any, value: any): boolean
	if key == "uiScale" then
		return type(value) == "string" and table.find(Config.Settings.UiScaleOptions, value) ~= nil
	elseif key == "reduceMotion" or key == "allowInvites" or key == "ambientEffects" then
		return type(value) == "boolean"
	end
	return false
end

local function read(storeName: string, key: string): (boolean, any)
	return pcall(function()
		return DataStoreService:GetDataStore(storeName):GetAsync(key)
	end)
end

local function load(player: Player)
	local profile = defaults()
	profiles[player] = profile

	local okProgress, storedProgress = read(Config.Progression.DataStoreName, Config.Progression.KeyPrefix .. player.UserId)
	if okProgress then
		profile.progress = Unlocks.sanitize(storedProgress)
	end
	local okSettings, storedSettings = read(Config.Settings.DataStoreName, Config.Settings.KeyPrefix .. player.UserId)
	-- A setting changed while the read was in flight wins over the stored value.
	if okSettings and type(storedSettings) == "table" and not profile.settingsDirty then
		for key, value in storedSettings do
			if isValidSetting(key, value) then
				profile.settings[key] = value
			end
		end
	end

	if profiles[player] == profile and ProfileService.onLoaded then
		ProfileService.onLoaded(player)
	end
end

local function save(player: Player)
	local profile = profiles[player]
	if not profile or not profile.settingsDirty then
		return
	end
	profile.settingsDirty = false
	local settings = table.clone(profile.settings)
	local ok = pcall(function()
		DataStoreService:GetDataStore(Config.Settings.DataStoreName)
			:SetAsync(Config.Settings.KeyPrefix .. player.UserId, settings)
	end)
	if not ok then
		profile.settingsDirty = true
	end
end

function ProfileService.start()
	if started then
		return
	end
	started = true
	Players.PlayerAdded:Connect(function(player)
		load(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		save(player)
		profiles[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			save(player)
		end
	end)
end

local function get(player: Player): Profile
	return profiles[player] or defaults()
end

function ProfileService.isUnlocked(player: Player, chapterId: string, difficultyId: string): boolean
	return Unlocks.isUnlocked(get(player).progress, chapterId, difficultyId)
end

function ProfileService.acceptsInvites(player: Player): boolean
	return get(player).settings.allowInvites == true
end

-- Validates and stores one setting. Returns false when the key or value is not allowed.
function ProfileService.updateSetting(player: Player, key: any, value: any): boolean
	local profile = profiles[player]
	if not profile or not isValidSetting(key, value) then
		return false
	end
	if profile.settings[key] ~= value then
		profile.settings[key] = value
		profile.settingsDirty = true
	end
	return true
end

-- What the client is allowed to know about its own profile.
function ProfileService.snapshot(player: Player): { progress: Unlocks.Progress, settings: { [string]: any } }
	local profile = get(player)
	return { progress = profile.progress, settings = table.clone(profile.settings) }
end

return ProfileService
