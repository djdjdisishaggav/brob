-- Builds the lobby headlessly and renders preview screenshots of it.
--
--   lune run tools/world/render                 every shot
--   lune run tools/world/render -- 01 05        only shots whose name contains 01 or 05
--   lune run tools/world/render -- --no-shots   build, export and save the place only
--
-- Output: docs/renders/world/*.png, build/world/preview.html and
-- build/lobby-built.rbxl. Needs Node (for the three.js package) and Chrome.
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local Harness = require("../harness")
local Export = require("./export")

local OUT_DIR = "docs/renders/world"
local WORK_DIR = "build/world"
local MODULES = "tools/world/node_modules"
local CHROME = process.env.CHROME_PATH or "/usr/local/bin/google-chrome"
local WIDTH, HEIGHT = 1600, 900

local filters = {}
local noShots = false
for _, arg in process.args do
	if arg == "--no-shots" then
		noShots = true
	else
		table.insert(filters, arg)
	end
end

local function ensureDir(path: string)
	local current = ""
	for segment in string.gmatch(path, "[^/]+") do
		current = if current == "" then segment else current .. "/" .. segment
		if not fs.isDir(current) then
			fs.writeDir(current)
		end
	end
end

-- Build ----------------------------------------------------------------------

local harness = Harness.new()
local server = harness:context("server")
local world = harness:service("ServerScriptService"):FindFirstChild("MushroomLobby"):FindFirstChild("World")
assert(world, "ServerScriptService.MushroomLobby.World is missing from the built place")

local LobbyBuilder = server.require(world.LobbyBuilder)
local StationView = server.require(world.StationView)
local LightingSetup = server.require(world.LightingSetup)

local started = os.clock()
local lobby = LobbyBuilder.build({ parent = harness:service("Workspace") })
local buildSeconds = os.clock() - started
LightingSetup.apply(harness:service("Lighting"))

-- Four stations in four different states.
local now = 1000
local snapshots = {
	solo = { id = "solo", status = "Available", memberNames = {}, memberCount = 0, maxSize = 1 },
	duo = {
		id = "duo",
		status = "Occupied",
		partyId = "p1",
		leaderName = "Mossling",
		memberNames = { "Mossling" },
		memberCount = 1,
		maxSize = 2,
		chapterName = "Sporewood Hollow",
		difficultyName = "Normal",
	},
	trio = {
		id = "trio",
		status = "Full",
		partyId = "p2",
		leaderName = "Fernwick",
		memberNames = { "Fernwick", "CapKnight", "Lumi" },
		memberCount = 3,
		maxSize = 3,
		chapterName = "Glowcap Caverns",
		difficultyName = "Hard",
	},
	squad = {
		id = "squad",
		status = "Starting",
		partyId = "p3",
		leaderName = "Rootwarden",
		memberNames = { "Rootwarden", "Sporelle", "Bramble", "Tindercap" },
		memberCount = 4,
		maxSize = 4,
		chapterName = "Sporewood Hollow",
		difficultyName = "Normal",
		peaceful = true,
		countdownEndsAt = now + 3.4,
	},
}
local stations = lobby:FindFirstChild("Stations")
for id, snapshot in snapshots do
	StationView.new(stations:FindFirstChild(id)):Render(snapshot, now)
end

local scene, names = Export.scene(lobby)
print(`built {#scene.parts} parts, {#scene.lights} lights, {#scene.guis} signs in {string.format("%.2f", buildSeconds)}s`)

local groups = {}
for _, group in lobby:FindFirstChild("Environment"):GetChildren() do
	table.insert(groups, group)
end
table.insert(groups, stations)
local breakdown = {}
for _, group in groups do
	local count = 0
	for _, descendant in group:GetDescendants() do
		if descendant:IsA("BasePart") then
			count += 1
		end
	end
	table.insert(breakdown, `{group.Name} {count}`)
end
print("  " .. table.concat(breakdown, ", "))
local _ = names

ensureDir("build")
harness:savePlace("build/lobby-built.rbxl")

if noShots then
	return
end

-- Shots ----------------------------------------------------------------------

local layout = LobbyBuilder.Layout
local spawnEye = { layout.Spawn.X, layout.Spawn.Y + layout.EyeHeight, layout.Spawn.Z }
local shots = {
	{ name = "01-spawn-view", position = spawnEye, target = { 0, spawnEye[2], -60 }, fov = 70 },
	{ name = "02-plan", type = "ortho", target = { 0, 0, -4 }, halfHeight = 104 },
	{ name = "03-aerial", position = { 168, 128, 176 }, target = { 4, 0, -14 }, fov = 44 },
	{ name = "04-stations", position = { 0, 13, 38 }, target = { 0, 15, -60 }, fov = 58 },
	{ name = "06-plaza", position = { 22, 11, 33 }, target = { 0, 4, -2 }, fov = 50 },
	{ name = "07-gate", position = { 0, 9, 4 }, target = { 0, 10, 75 }, fov = 70 },
	{ name = "08-garden", position = { 14, 8, -10 }, target = { 78, 6, 16 }, fov = 62 },
}
for index, x in layout.StationX do
	local id = ({ "solo", "duo", "trio", "squad" })[index]
	table.insert(shots, {
		name = "05-station-" .. id,
		position = { x + 5, 6.5, layout.StationZ + 30 },
		target = { x, 15.5, layout.StationZ - 12 },
		fov = 66,
	})
end
table.sort(shots, function(a, b)
	return a.name < b.name
end)
scene.shots = shots
scene.width = WIDTH
scene.height = HEIGHT

-- Page -----------------------------------------------------------------------

if not fs.isFile(MODULES .. "/three/build/three.min.js") then
	print("installing preview dependencies (npm install)...")
	local install = process.exec("npm", { "install", "--prefix", "tools/world", "--no-audit", "--no-fund" })
	assert(install.ok, "npm install failed:\n" .. install.stderr)
end

local function base64(path: string): string
	local result = process.exec("base64", { "-w0", path })
	assert(result.ok, "base64 failed for " .. path)
	return (result.stdout:gsub("%s+$", ""))
end

local fonts = {
	{ "Fredoka One", 400, MODULES .. "/@fontsource/fredoka-one/files/fredoka-one-latin-400-normal.woff2" },
	{ "Nunito", 600, MODULES .. "/@fontsource/nunito/files/nunito-latin-600-normal.woff2" },
	{ "Nunito", 700, MODULES .. "/@fontsource/nunito/files/nunito-latin-700-normal.woff2" },
	{ "Nunito", 800, MODULES .. "/@fontsource/nunito/files/nunito-latin-800-normal.woff2" },
}
local fontCss = {}
for _, font in fonts do
	table.insert(
		fontCss,
		`@font-face\{font-family:"{font[1]}";font-weight:{font[2]};src:url(data:font/woff2;base64,{base64(font[3])}) format("woff2");}`
	)
end

local html = table.concat({
	'<!doctype html><html><head><meta charset="utf-8"><title>Mushroom Guardians lobby preview</title><style>',
	table.concat(fontCss, "\n"),
	"html,body{margin:0;overflow:hidden;background:#141018}canvas{display:block;position:fixed;left:0;top:0}",
	"</style></head><body><script>",
	fs.readFile(MODULES .. "/three/build/three.min.js"),
	"</script><script>window.SCENE=",
	serde.encode("json", scene),
	";</script><script>",
	fs.readFile("tools/world/viewer.js"),
	"</script></body></html>",
})
ensureDir(WORK_DIR)
ensureDir(OUT_DIR)
fs.writeFile(WORK_DIR .. "/preview.html", html)

local cwd = process.cwd:gsub("/$", "")
local rendered = 0
for _, shot in shots do
	local wanted = #filters == 0
	for _, filter in filters do
		if string.find(shot.name, filter, 1, true) then
			wanted = true
		end
	end
	if wanted then
		local output = `{cwd}/{OUT_DIR}/{shot.name}.png`
		if fs.isFile(output) then
			fs.removeFile(output)
		end
		local result = process.exec(CHROME, {
			"--headless=new",
			"--no-sandbox",
			"--disable-gpu-sandbox",
			"--use-angle=swiftshader",
			"--enable-unsafe-swiftshader",
			"--hide-scrollbars",
			`--window-size={WIDTH},{HEIGHT + 120}`,
			"--virtual-time-budget=8000",
			"--screenshot=" .. output,
			`file://{cwd}/{WORK_DIR}/preview.html#shot={shot.name}`,
		})
		if fs.isFile(output) then
			rendered += 1
			print(`  {shot.name}.png  {math.round(#fs.readFile(output) / 1024)} KB`)
		else
			print(`  {shot.name}: FAILED\n{result.stderr}`)
		end
	end
end
print(`rendered {rendered} shot(s) to {OUT_DIR}`)
