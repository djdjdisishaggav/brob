-- STEP 1 of docs/APPLY.md. Run in the Studio command bar of the LOBBY place
-- (edit mode) before anything is changed. Copies the current lobby - scripts,
-- UI, models, lighting - into ServerStorage.LobbyBackup_<UTC time>. Nothing is
-- moved or deleted, and scripts stored in ServerStorage do not run.

local LOBBY_PLACE_ID = 106448766989936

if game.PlaceId ~= LOBBY_PLACE_ID then
	error(`This is place {game.PlaceId}, not the Lobby place {LOBBY_PLACE_ID}. Nothing was changed.`)
end

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ServerStorage = game:GetService("ServerStorage")

local backup = Instance.new("Folder")
backup.Name = "LobbyBackup_" .. os.date("!%Y%m%d_%H%M%S")

local copied, skipped = 0, 0

local function copyChildren(source: Instance, name: string, skip: ((Instance) -> boolean)?)
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = backup
	for _, child in source:GetChildren() do
		if not (skip and skip(child)) then
			-- Clone returns nil for non-archivable instances.
			local ok, clone = pcall(function()
				return child:Clone()
			end)
			if ok and clone then
				clone.Parent = folder
				copied += 1
			else
				skipped += 1
			end
		end
	end
end

local StarterPlayer = game:GetService("StarterPlayer")

copyChildren(workspace, "Workspace", function(child)
	return child:IsA("Terrain") or child:IsA("Camera")
end)
copyChildren(game:GetService("ServerScriptService"), "ServerScriptService")
copyChildren(game:GetService("ReplicatedStorage"), "ReplicatedStorage")
copyChildren(game:GetService("ReplicatedFirst"), "ReplicatedFirst")
copyChildren(game:GetService("StarterGui"), "StarterGui")
copyChildren(game:GetService("StarterPack"), "StarterPack")
copyChildren(StarterPlayer.StarterPlayerScripts, "StarterPlayerScripts")
copyChildren(StarterPlayer.StarterCharacterScripts, "StarterCharacterScripts")
copyChildren(game:GetService("Lighting"), "Lighting")
copyChildren(game:GetService("SoundService"), "SoundService")
copyChildren(ServerStorage, "ServerStorage", function(child)
	return child.Name:match("^LobbyBackup_") ~= nil
end)

backup.Parent = ServerStorage
ChangeHistoryService:SetWaypoint("Mushroom Lobby backup")

print(`[MushroomLobby] backup written to ServerStorage.{backup.Name}: {copied} top-level items copied, {skipped} skipped`)
