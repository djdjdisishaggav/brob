-- Shared setup for headless UI scenes: a harness with one local player, the
-- client modules loaded, and a capture helper that renders PlayerGui.
local Harness = require("../harness")
local Render = require("../ui_render")

local roblox = Harness.roblox

local Scenes = {}

Scenes.Viewports = {
	{ 1280, 720 },
	{ 1920, 1080 },
	{ 1366, 768 },
	{ 1024, 768 },
	{ 844, 390 },
}

-- Stand-in for the 3D lobby behind the UI, so contrast is judged fairly.
Scenes.Background = {
	stops = { { 0, "#3b4a63" }, { 0.45, "#4a5a52" }, { 1, "#2c3a2a" } },
}

function Scenes.setup(options)
	options = options or {}
	local h = Harness.new()
	local player = h:addPlayer({ userId = 1001, name = "Z1raelRam", displayName = "Z1rael" })
	h:setLocalPlayer(player)
	Harness.state.mode = "client"

	local ctx = h:context("client")
	local client = h:service("StarterPlayer").StarterPlayerScripts.MushroomLobby
	local shared = h:service("ReplicatedStorage").MushroomLobby

	local env = {
		h = h,
		ctx = ctx,
		client = client,
		shared = shared,
		player = player,
		playerGui = player:FindFirstChildOfClass("PlayerGui"),
		roblox = roblox,
		Harness = Harness,
	}
	env.Kit = ctx.require(client.UI.Kit)
	env.Theme = ctx.require(shared.Theme)
	env.Config = ctx.require(shared.Config)
	env.Net = ctx.require(shared.Net)
	env.Unlocks = ctx.require(shared.Unlocks)

	function env.require(path)
		local node = client
		for part in path:gmatch("[^/%.]+") do
			node = node[part]
		end
		return ctx.require(node)
	end

	-- Sets the viewport, lets auto-scaling react, and renders PlayerGui.
	function env.capture(name, width, height, captureOptions)
		captureOptions = captureOptions or {}
		h:setViewport(width, height)
		env.Kit.refreshScale()
		local result = Render.capture(captureOptions.roots or env.playerGui, {
			viewport = roblox.Vector2.new(width, height),
			path = `{captureOptions.dir or "docs/renders/ui"}/{name}-{width}x{height}.png`,
			background = captureOptions.background or Scenes.Background,
		})
		print(`rendered {result.png}`)
		return result
	end

	return env
end

return Scenes
