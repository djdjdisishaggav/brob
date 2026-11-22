-- STEP 2 of docs/APPLY.md. Run in the Studio command bar of the LOBBY place
-- (edit mode) and read the output before replacing anything. It lists what is
-- in the place today so existing systems can be kept: scripts, ScreenGuis,
-- remotes, spawn points, teleport usage and candidate HUD features.

local LOBBY_PLACE_ID = 106448766989936

if game.PlaceId ~= LOBBY_PLACE_ID then
	error(`This is place {game.PlaceId}, not the Lobby place {LOBBY_PLACE_ID}.`)
end

local lines = {}
local function out(text: string)
	table.insert(lines, text)
end

local function scripts(service: Instance)
	out(`\n== scripts in {service.Name}`)
	for _, item in service:GetDescendants() do
		if item:IsA("LuaSourceContainer") then
			local source = (item :: any).Source :: string
			local flags = {}
			if source:find("TeleportService") then
				table.insert(flags, "teleport")
			end
			if source:find("DataStoreService") then
				table.insert(flags, "datastore")
			end
			if source:find("leaderstats") then
				table.insert(flags, "leaderstats")
			end
			if source:find("MarketplaceService") then
				table.insert(flags, "purchases")
			end
			local _, lineCount = source:gsub("\n", "\n")
			out(`  {item.ClassName} {item:GetFullName()} ({lineCount + 1} lines) {table.concat(flags, ",")}`)
		end
	end
end

for _, name in
	{
		"ServerScriptService",
		"ReplicatedStorage",
		"ReplicatedFirst",
		"StarterGui",
		"StarterPlayer",
		"StarterPack",
		"ServerStorage",
		"Workspace",
	}
do
	scripts(game:GetService(name))
end

out("\n== ScreenGuis in StarterGui (candidates for Config.Hud.ExternalFeatures or for archiving)")
for _, gui in game:GetService("StarterGui"):GetChildren() do
	if gui:IsA("ScreenGui") then
		out(`  {gui.Name}  enabled={gui.Enabled}  descendants={#gui:GetDescendants()}`)
	end
end

out("\n== remotes")
for _, service in { game:GetService("ReplicatedStorage"), workspace } do
	for _, item in service:GetDescendants() do
		if item:IsA("RemoteEvent") or item:IsA("RemoteFunction") or item:IsA("BindableEvent") then
			out(`  {item.ClassName} {item:GetFullName()}`)
		end
	end
end

out("\n== top-level Workspace content")
for _, child in workspace:GetChildren() do
	local parts = 0
	for _, item in child:GetDescendants() do
		if item:IsA("BasePart") then
			parts += 1
		end
	end
	out(`  {child.ClassName} {child.Name}  parts={parts}`)
end

out("\n== spawn locations")
for _, item in workspace:GetDescendants() do
	if item:IsA("SpawnLocation") then
		out(`  {item:GetFullName()} at {item.Position}`)
	end
end

print(table.concat(lines, "\n"))
