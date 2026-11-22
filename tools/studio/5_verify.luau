-- STEP 5 of docs/APPLY.md. Run in the Studio command bar of the LOBBY place
-- (edit mode) after baking. Prints a pass/fail checklist of what the lobby
-- code expects to find. It changes nothing.

local LOBBY_PLACE_ID = 106448766989936
local STATIONS = { "solo", "duo", "trio", "squad" }

local failures = 0
local function check(condition: any, label: string)
	if condition then
		print("  ok    " .. label)
	else
		failures += 1
		warn("  FAIL  " .. label)
	end
end

print("[MushroomLobby] verification")
check(game.PlaceId == LOBBY_PLACE_ID, "this is the Lobby place")

local shared = game:GetService("ReplicatedStorage"):FindFirstChild("MushroomLobby")
local server = game:GetService("ServerScriptService"):FindFirstChild("MushroomLobby")
local client = game:GetService("StarterPlayer").StarterPlayerScripts:FindFirstChild("MushroomLobby")
check(shared and shared:FindFirstChild("Config"), "ReplicatedStorage.MushroomLobby.Config")
check(server and server:FindFirstChild("Main"), "ServerScriptService.MushroomLobby.Main")
check(server and server:FindFirstChild("PartyService"), "ServerScriptService.MushroomLobby.PartyService")
check(client and client:FindFirstChild("Main"), "StarterPlayerScripts.MushroomLobby.Main")
check(client and client:FindFirstChild("UI"), "StarterPlayerScripts.MushroomLobby.UI")

local lobby = workspace:FindFirstChild("MushroomLobby")
check(lobby, "Workspace.MushroomLobby is baked")
local stations = lobby and lobby:FindFirstChild("Stations")
for _, id in STATIONS do
	local station = stations and stations:FindFirstChild(id)
	local pad = station and station:FindFirstChild("Pad", true)
	local prompt = station and station:FindFirstChild("Prompt", true)
	check(station and station:GetAttribute("StationId") == id, `station "{id}" exists`)
	check(pad and pad:IsA("BasePart") and type(pad:GetAttribute("ZoneRadius")) == "number", `station "{id}" has a Pad with ZoneRadius`)
	check(prompt and prompt:IsA("ProximityPrompt"), `station "{id}" has its Prompt`)
end

local spawns, foreign = 0, 0
for _, item in workspace:GetDescendants() do
	if item:IsA("SpawnLocation") then
		spawns += 1
		if not (lobby and item:IsDescendantOf(lobby)) then
			foreign += 1
		end
	end
end
check(spawns >= 1, "a SpawnLocation exists")
check(foreign == 0, "no SpawnLocation outside the new lobby (players would spawn in the old one)")

local unanchored = 0
if lobby then
	for _, item in lobby:GetDescendants() do
		if item:IsA("BasePart") and not item.Anchored then
			unanchored += 1
		end
	end
end
check(unanchored == 0, "every lobby part is anchored")

if failures == 0 then
	print("[MushroomLobby] all checks passed. Next: press Play and follow the play-test list in docs/APPLY.md.")
else
	warn(`[MushroomLobby] {failures} check(s) failed.`)
end
