-- STEP 4 of docs/APPLY.md. Run in the Studio command bar of the LOBBY place
-- (edit mode) after the MushroomLobby code has been synced in. Moves the old
-- lobby geometry and old lobby ScreenGuis into the newest backup folder (they
-- are moved, not deleted), then bakes the new lobby and lighting into the
-- place. One undo step reverts it.
--
-- Edit KEEP_IN_WORKSPACE and KEEP_IN_STARTER_GUI first, using the output of
-- 2_inspect.luau: anything listed there stays where it is.

local LOBBY_PLACE_ID = 106448766989936

local KEEP_IN_WORKSPACE: { string } = {
	-- e.g. "Leaderboards"
}
local KEEP_IN_STARTER_GUI: { string } = {
	-- e.g. "ShopGui", "PetsGui" (then list them in Config.Hud.ExternalFeatures)
}

if game.PlaceId ~= LOBBY_PLACE_ID then
	error(`This is place {game.PlaceId}, not the Lobby place {LOBBY_PLACE_ID}. Nothing was changed.`)
end

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Lighting = game:GetService("Lighting")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local StarterGui = game:GetService("StarterGui")

local package = ServerScriptService:FindFirstChild("MushroomLobby")
if not package then
	error("ServerScriptService.MushroomLobby is missing. Sync the code first (step 3).")
end

local backup: Instance? = nil
for _, child in ServerStorage:GetChildren() do
	if child.Name:match("^LobbyBackup_") and (not backup or child.Name > backup.Name) then
		backup = child
	end
end
if not backup then
	error("No ServerStorage.LobbyBackup_* folder found. Run 1_backup.luau first (step 1).")
end

local recording = ChangeHistoryService:TryBeginRecording("Bake Mushroom Lobby")

local replaced = Instance.new("Folder")
replaced.Name = "Replaced"
replaced.Parent = backup

local function archive(source: Instance, name: string, keep: { string }, eligible: (Instance) -> boolean)
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = replaced
	local moved = 0
	for _, child in source:GetChildren() do
		if eligible(child) and not table.find(keep, child.Name) then
			child.Parent = folder
			moved += 1
		end
	end
	return moved
end

local movedWorld = archive(workspace, "Workspace", KEEP_IN_WORKSPACE, function(child)
	return not child:IsA("Terrain") and not child:IsA("Camera") and child.Name ~= "MushroomLobby"
end)
local movedGui = archive(StarterGui, "StarterGui", KEEP_IN_STARTER_GUI, function(child)
	return child:IsA("ScreenGui")
end)

local world = package:FindFirstChild("World") :: Instance
local LobbyBuilder = (require :: any)(world:FindFirstChild("LobbyBuilder"))
local LightingSetup = (require :: any)(world:FindFirstChild("LightingSetup"))

local existing = workspace:FindFirstChild("MushroomLobby")
if existing then
	existing.Parent = replaced
end
local lobby = LobbyBuilder.build({ parent = workspace })
LightingSetup.apply(Lighting)

if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end

local parts = 0
for _, item in lobby:GetDescendants() do
	if item:IsA("BasePart") then
		parts += 1
	end
end
print(
	`[MushroomLobby] baked {lobby:GetFullName()} ({parts} parts). Archived {movedWorld} Workspace items and {movedGui} ScreenGuis into ServerStorage.{backup.Name}.Replaced`
)
