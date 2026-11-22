-- Headless Roblox runtime shim for Lune.
--
-- Loads the Rojo-built place file and runs its ModuleScripts against mocked
-- services, so party logic, world building and UI construction can be
-- exercised without Roblox Studio. Property names and value types are still
-- validated by Lune's reflection database, which catches most API typos.
--
-- Limits: events only fire when a test fires them, tweens jump to their goal,
-- and computed properties (AbsoluteSize, ViewportSize, Position) hold whatever
-- the harness last wrote. Never read BasePart.Position in game code under
-- test; use CFrame.Position.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local task = require("@lune/task")

local Signal = require("./signal")

local Harness = {}
Harness.__index = Harness
Harness.Signal = Signal
Harness.roblox = roblox

local Instance = roblox.Instance
local Enum = roblox.Enum

-- Shared mutable state read by the mocks. One harness per process.
local state = {
	localPlayer = nil,
	mode = "both",
	clockOffset = 0,
	viewport = roblox.Vector2.new(1280, 720),
	teleport = { mode = "ok", calls = {}, message = "Teleport failed in harness" },
	datastore = { fail = false, stores = {} },
	sent = {},
	invokeHandlers = {},
	teleportData = {},
	closeHandlers = {},
}
Harness.state = state

local signals = {}

local function signalOf(instance, name)
	local bucket = signals[instance]
	if not bucket then
		bucket = {}
		signals[instance] = bucket
	end
	local signal = bucket[name]
	if not signal then
		signal = Signal.new()
		bucket[name] = signal
	end
	return signal
end
Harness.signalOf = signalOf

-- Fires a mocked event, e.g. Harness.fire(button, "MouseButton1Click").
function Harness.fire(instance, name, ...)
	signalOf(instance, name):Fire(...)
end

function Harness.firePropertyChanged(instance, property)
	signalOf(instance, "prop:" .. property):Fire()
end

-- Remote arguments are copied the way the network would copy them, so tests
-- catch aliasing and non-serialisable payloads.
local function netCopy(value, depth)
	depth = depth or 0
	if depth > 32 then
		error("remote payload too deep or cyclic")
	end
	local kind = type(value)
	if kind == "function" or kind == "thread" then
		error("remote payload contains a " .. kind)
	end
	if kind ~= "table" then
		return value
	end
	if getmetatable(value) ~= nil then
		error("remote payload contains a table with a metatable")
	end
	local copy = {}
	for key, item in value do
		copy[netCopy(key, depth + 1)] = netCopy(item, depth + 1)
	end
	return copy
end
Harness.netCopy = netCopy

local function netCopyArgs(...)
	local packed = table.pack(...)
	for index = 1, packed.n do
		packed[index] = netCopy(packed[index])
	end
	return table.unpack(packed, 1, packed.n)
end

local EVENTS = {
	Instance = {
		"Changed",
		"ChildAdded",
		"ChildRemoved",
		"DescendantAdded",
		"DescendantRemoving",
		"AncestryChanged",
		"Destroying",
		"AttributeChanged",
	},
	GuiObject = {
		"MouseEnter",
		"MouseLeave",
		"MouseMoved",
		"InputBegan",
		"InputEnded",
		"InputChanged",
		"SelectionGained",
		"SelectionLost",
		"TouchTap",
	},
	GuiButton = { "MouseButton1Click", "MouseButton1Down", "MouseButton1Up", "MouseButton2Click", "Activated" },
	TextBox = { "FocusLost", "Focused" },
	BasePart = { "Touched", "TouchEnded" },
	Players = { "PlayerAdded", "PlayerRemoving" },
	Player = { "CharacterAdded", "CharacterRemoving", "CharacterAppearanceLoaded", "OnTeleport" },
	Humanoid = { "Died", "HealthChanged", "StateChanged" },
	RunService = { "Heartbeat", "RenderStepped", "Stepped", "PreRender", "PreSimulation", "PostSimulation" },
	UserInputService = {
		"InputBegan",
		"InputEnded",
		"InputChanged",
		"LastInputTypeChanged",
		"TouchTap",
		"WindowFocused",
		"WindowFocusReleased",
	},
	RemoteEvent = { "OnServerEvent", "OnClientEvent" },
	BindableEvent = { "Event" },
	ProximityPrompt = { "Triggered", "TriggerEnded", "PromptShown", "PromptHidden" },
	ProximityPromptService = { "PromptTriggered", "PromptShown", "PromptHidden" },
	TeleportService = { "TeleportInitFailed", "LocalPlayerArrivedFromTeleport" },
	DataModel = { "Loaded", "Close" },
	GuiService = { "MenuOpened", "MenuClosed" },
	Sound = { "Ended", "Played" },
}

local installed = false

local function makeTween(instance, goals)
	local tween = { PlaybackState = Enum.PlaybackState.Begin, Instance = instance, Completed = Signal.new() }
	function tween:Play()
		for property, value in goals do
			instance[property] = value
		end
		tween.PlaybackState = Enum.PlaybackState.Completed
		task.defer(function()
			tween.Completed:Fire(Enum.PlaybackState.Completed)
		end)
	end
	function tween:Cancel()
		tween.PlaybackState = Enum.PlaybackState.Cancelled
	end
	function tween:Pause()
		tween.PlaybackState = Enum.PlaybackState.Paused
	end
	function tween:Destroy() end
	return tween
end

local function installMocks()
	if installed then
		return
	end
	installed = true

	for className, names in EVENTS do
		for _, name in names do
			roblox.implementProperty(className, name, function(self)
				return signalOf(self, name)
			end)
		end
	end

	local method = roblox.implementMethod

	method("Instance", "WaitForChild", function(self, name, timeout)
		local child = self:FindFirstChild(name)
		if child then
			return child
		end
		-- Give other threads a few scheduler turns to create it, then fail loudly.
		local deadline = os.clock() + (timeout or 2)
		while os.clock() < deadline do
			task.wait()
			child = self:FindFirstChild(name)
			if child then
				return child
			end
		end
		if timeout then
			return nil
		end
		error(`WaitForChild("{name}") never resolved under {self:GetFullName()}`)
	end)
	method("Instance", "GetPropertyChangedSignal", function(self, property)
		return signalOf(self, "prop:" .. property)
	end)
	method("Instance", "GetAttributeChangedSignal", function(self, attribute)
		return signalOf(self, "attr:" .. attribute)
	end)

	method("DataModel", "IsLoaded", function()
		return true
	end)
	method("DataModel", "BindToClose", function(_, fn)
		table.insert(state.closeHandlers, fn)
	end)

	method("RunService", "IsServer", function()
		return state.mode ~= "client"
	end)
	method("RunService", "IsClient", function()
		return state.mode ~= "server"
	end)
	method("RunService", "IsStudio", function()
		return false
	end)
	method("RunService", "IsRunning", function()
		return true
	end)

	method("Workspace", "GetServerTimeNow", function()
		return os.clock() + state.clockOffset
	end)

	method("Players", "GetPlayers", function(self)
		local list = {}
		for _, child in self:GetChildren() do
			if child.ClassName == "Player" then
				table.insert(list, child)
			end
		end
		return list
	end)
	method("Players", "GetPlayerByUserId", function(self, userId)
		for _, child in self:GetChildren() do
			if child.ClassName == "Player" and child.UserId == userId then
				return child
			end
		end
		return nil
	end)
	method("Players", "GetPlayerFromCharacter", function(self, character)
		for _, child in self:GetChildren() do
			if child.ClassName == "Player" and child.Character == character then
				return child
			end
		end
		return nil
	end)
	method("Players", "GetUserThumbnailAsync", function(_, userId)
		return `rbxthumb://type=AvatarHeadShot&id={userId}&w=150&h=150`, true
	end)
	method("Player", "Kick", function() end)
	method("Player", "GetJoinData", function()
		return { TeleportData = nil }
	end)

	-- Remotes loop back inside the process: the single simulated client is
	-- state.localPlayer, other players are driven through Harness:invokeAs.
	method("RemoteEvent", "FireServer", function(self, ...)
		signalOf(self, "OnServerEvent"):Fire(state.localPlayer, netCopyArgs(...))
	end)
	method("RemoteEvent", "FireClient", function(self, player, ...)
		local log = state.sent[player]
		if not log then
			log = {}
			state.sent[player] = log
		end
		table.insert(log, { remote = self.Name, args = table.pack(netCopyArgs(...)) })
		if player == state.localPlayer then
			signalOf(self, "OnClientEvent"):Fire(netCopyArgs(...))
		end
	end)
	method("RemoteEvent", "FireAllClients", function(self, ...)
		for _, player in self:FindFirstAncestorOfClass("DataModel"):GetService("Players"):GetPlayers() do
			self:FireClient(player, ...)
		end
	end)
	roblox.implementProperty("RemoteFunction", "OnServerInvoke", function(self)
		return state.invokeHandlers[self]
	end, function(self, handler)
		state.invokeHandlers[self] = handler
	end)
	method("RemoteFunction", "InvokeServer", function(self, ...)
		local handler = state.invokeHandlers[self]
		if not handler then
			error(`{self.Name}.OnServerInvoke is not set`)
		end
		return netCopyArgs(handler(state.localPlayer, netCopyArgs(...)))
	end)

	method("TweenService", "Create", function(_, instance, _, goals)
		return makeTween(instance, goals)
	end)
	method("TweenService", "GetValue", function(_, alpha)
		return alpha
	end)

	method("TextService", "GetTextSize", function(_, text, size)
		return roblox.Vector2.new(math.ceil(#text * size * 0.52), size)
	end)

	method("UserInputService", "GetMouseLocation", function()
		return roblox.Vector2.new(0, 0)
	end)
	method("UserInputService", "GetLastInputType", function()
		return Enum.UserInputType.MouseMovement
	end)
	method("UserInputService", "IsKeyDown", function()
		return false
	end)
	method("GuiService", "GetGuiInset", function()
		return roblox.Vector2.new(0, 0), roblox.Vector2.new(0, 0)
	end)
	method("StarterGui", "SetCore", function() end)
	method("StarterGui", "GetCore", function()
		return nil
	end)
	method("StarterGui", "SetCoreGuiEnabled", function() end)
	method("ContextActionService", "BindAction", function() end)
	method("ContextActionService", "UnbindAction", function() end)
	method("ContentProvider", "PreloadAsync", function() end)
	method("Debris", "AddItem", function() end)
	method("Sound", "Play", function() end)
	method("Sound", "Stop", function() end)

	method("DataStoreService", "GetDataStore", function(_, name)
		local data = state.datastore.stores[name]
		if not data then
			data = {}
			state.datastore.stores[name] = data
		end
		local function guard()
			if state.datastore.fail then
				error("DataStore request failed in harness")
			end
		end
		local store = {}
		function store:GetAsync(key)
			guard()
			return netCopy(data[key])
		end
		function store:SetAsync(key, value)
			guard()
			data[key] = netCopy(value)
		end
		function store:UpdateAsync(key, transform)
			guard()
			local result = transform(netCopy(data[key]))
			if result ~= nil then
				data[key] = netCopy(result)
			end
			return result
		end
		function store:RemoveAsync(key)
			guard()
			data[key] = nil
		end
		return store
	end)

	method("TeleportOptions", "SetTeleportData", function(self, data)
		state.teleportData[self] = netCopy(data)
	end)
	method("TeleportOptions", "GetTeleportData", function(self)
		return state.teleportData[self]
	end)
	method("TeleportService", "ReserveServer", function()
		return "harness-access-code", "harness-private-server"
	end)
	method("TeleportService", "SetTeleportGui", function() end)
	method("TeleportService", "TeleportAsync", function(self, placeId, players, options)
		local teleport = state.teleport
		table.insert(teleport.calls, {
			placeId = placeId,
			players = table.clone(players),
			options = options,
			data = options and state.teleportData[options] or nil,
		})
		if teleport.mode == "throw" then
			error(teleport.message)
		elseif teleport.mode == "initFail" then
			task.defer(function()
				for _, player in players do
					signalOf(self, "TeleportInitFailed"):Fire(
						player,
						Enum.TeleportResult.Failure,
						teleport.message,
						placeId,
						options
					)
				end
			end)
		end
		return { PrivateServerId = "harness-private-server", ReservedServerAccessCode = "harness-access-code" }
	end)
end

local function mockTweenInfo()
	local TweenInfo = {}
	function TweenInfo.new(time, style, direction, repeatCount, reverses, delayTime)
		return {
			Time = time or 1,
			EasingStyle = style or Enum.EasingStyle.Quad,
			EasingDirection = direction or Enum.EasingDirection.Out,
			RepeatCount = repeatCount or 0,
			Reverses = reverses or false,
			DelayTime = delayTime or 0,
		}
	end
	return TweenInfo
end

-- Deterministic stand-in for Roblox's Random. The sequence differs from the
-- engine's, so game code that needs identical output in Studio and here must
-- carry its own generator.
local function mockRandom()
	local Random = {}
	Random.__index = Random
	function Random.new(seed)
		return setmetatable({ s = (seed or 1) % 2147483647 }, Random)
	end
	function Random:_next()
		self.s = (self.s * 48271) % 2147483647
		return self.s / 2147483647
	end
	function Random:NextNumber(min, max)
		local value = self:_next()
		if min == nil then
			return value
		end
		return min + (max - min) * value
	end
	function Random:NextInteger(min, max)
		return math.floor(min + (max - min + 1) * self:_next())
	end
	function Random:Clone()
		return setmetatable({ s = self.s }, Random)
	end
	return Random
end

local function mockParams()
	return {
		new = function()
			return { FilterDescendantsInstances = {}, FilterType = Enum.RaycastFilterType.Exclude }
		end,
	}
end

-- Creates a harness around a place file. With no path, `rojo build` is run on
-- the project in the current directory first.
function Harness.new(options)
	options = options or {}
	installMocks()

	local placePath = options.placePath
	if not placePath then
		placePath = "build/lobby.rbxl"
		if not fs.isDir("build") then
			fs.writeDir("build")
		end
		local result = process.exec("rojo", { "build", "default.project.json", "-o", placePath })
		if not result.ok then
			error("rojo build failed:\n" .. result.stderr .. result.stdout)
		end
	end

	local self = setmetatable({}, Harness)
	self.game = roblox.deserializePlace(fs.readFile(placePath))
	self.placePath = placePath

	local game = self.game
	local workspace = game:GetService("Workspace")
	local camera = Instance.new("Camera")
	camera.Name = "Camera"
	camera.ViewportSize = state.viewport
	camera.Parent = workspace
	workspace.CurrentCamera = camera
	self.camera = camera

	local input = game:GetService("UserInputService")
	input.TouchEnabled = false
	input.KeyboardEnabled = true
	input.MouseEnabled = true
	input.GamepadEnabled = false

	-- Reset per-harness state so several harnesses can run in one process.
	state.localPlayer = nil
	state.mode = "both"
	state.sent = {}
	state.teleport.calls = {}
	state.teleport.mode = "ok"
	state.datastore.fail = false
	state.datastore.stores = {}

	return self
end

function Harness:service(name)
	return self.game:GetService(name)
end

function Harness:setViewport(width, height)
	state.viewport = roblox.Vector2.new(width, height)
	self.camera.ViewportSize = state.viewport
	Harness.firePropertyChanged(self.camera, "ViewportSize")
end

-- Adds a mock player with PlayerGui and a character standing at `position`.
function Harness:addPlayer(info)
	local players = self.game:GetService("Players")
	local player = Instance.new("Player")
	player.Name = info.name
	player.DisplayName = info.displayName or info.name
	player.UserId = info.userId
	local playerGui = Instance.new("PlayerGui")
	playerGui.Name = "PlayerGui"
	playerGui.Parent = player

	local character = Instance.new("Model")
	character.Name = info.name
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Anchored = true
	root.CFrame = roblox.CFrame.new(info.position or roblox.Vector3.new(0, 5, 0))
	root.Parent = character
	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = character
	character.PrimaryPart = root
	character.Parent = self.game:GetService("Workspace")
	player.Character = character

	player.Parent = players
	signalOf(players, "PlayerAdded"):Fire(player)
	return player
end

function Harness:removePlayer(player)
	local players = self.game:GetService("Players")
	signalOf(players, "PlayerRemoving"):Fire(player)
	task.wait()
	if player.Character then
		player.Character:Destroy()
	end
	player:Destroy()
end

function Harness:movePlayer(player, position)
	player.Character.PrimaryPart.CFrame = roblox.CFrame.new(position)
end

function Harness:setLocalPlayer(player)
	state.localPlayer = player
	self.game:GetService("Players").LocalPlayer = player
end

-- Calls a RemoteFunction's server handler as if `player` had invoked it.
function Harness:invokeAs(player, remoteFunction, ...)
	local handler = state.invokeHandlers[remoteFunction]
	if not handler then
		error(`{remoteFunction.Name}.OnServerInvoke is not set`)
	end
	return handler(player, netCopyArgs(...))
end

-- Messages the server sent to `player`, optionally filtered by remote name.
function Harness:sentTo(player, remoteName)
	local list = {}
	for _, entry in state.sent[player] or {} do
		if remoteName == nil or entry.remote == remoteName then
			table.insert(list, entry)
		end
	end
	return list
end

function Harness:clearSent()
	state.sent = {}
end

-- Fires the frame events once, as RunService would.
function Harness:step(dt)
	dt = dt or 1 / 60
	local runService = self.game:GetService("RunService")
	signalOf(runService, "PreSimulation"):Fire(dt)
	signalOf(runService, "Stepped"):Fire(os.clock(), dt)
	signalOf(runService, "Heartbeat"):Fire(dt)
	signalOf(runService, "PostSimulation"):Fire(dt)
	signalOf(runService, "PreRender"):Fire(dt)
	signalOf(runService, "RenderStepped"):Fire(dt)
end

-- A context is one script environment: its own module cache, like the
-- separate server and client Lua states in Roblox.
function Harness:context(name)
	local harness = self
	local context = { name = name, cache = {} }

	local globals = {
		game = self.game,
		workspace = self.game:GetService("Workspace"),
		Instance = Instance,
		Enum = Enum,
		task = task,
		warn = function(...)
			print("[warn]", ...)
		end,
		tick = os.clock,
		time = os.clock,
		TweenInfo = mockTweenInfo(),
		Random = mockRandom(),
		RaycastParams = mockParams(),
		OverlapParams = mockParams(),
		shared = {},
	}
	for _, datatype in
		{
			"Axes",
			"BrickColor",
			"CFrame",
			"Color3",
			"ColorSequence",
			"ColorSequenceKeypoint",
			"Faces",
			"Font",
			"NumberRange",
			"NumberSequence",
			"NumberSequenceKeypoint",
			"PhysicalProperties",
			"Ray",
			"Rect",
			"Region3",
			"UDim",
			"UDim2",
			"Vector2",
			"Vector2int16",
			"Vector3",
			"Vector3int16",
		}
	do
		globals[datatype] = roblox[datatype]
	end
	if options and options.globals then
		for key, value in options.globals do
			globals[key] = value
		end
	end
	context.globals = globals

	local function environmentFor(scriptInstance)
		local env = table.clone(globals)
		env.script = scriptInstance
		env.require = function(module)
			return context.require(module)
		end
		return env
	end

	function context.require(module)
		if typeof(module) ~= "Instance" or module.ClassName ~= "ModuleScript" then
			error("harness require expects a ModuleScript, got " .. tostring(module), 2)
		end
		local entry = context.cache[module]
		if entry then
			if entry.loading then
				error("circular require of " .. module:GetFullName(), 2)
			end
			return entry.value
		end
		entry = { loading = true }
		context.cache[module] = entry
		local chunk = luau.load(module.Source, {
			debugName = module:GetFullName(),
			environment = environmentFor(module),
		})
		local value = chunk()
		entry.loading = false
		entry.value = value
		return value
	end

	-- Runs a Script or LocalScript body on its own thread.
	function context.run(scriptInstance)
		local chunk = luau.load(scriptInstance.Source, {
			debugName = scriptInstance:GetFullName(),
			environment = environmentFor(scriptInstance),
		})
		return task.spawn(chunk)
	end

	-- Evaluates a snippet inside this context, with `script` set to `anchor`.
	function context.eval(source, anchor)
		local chunk = luau.load(source, {
			debugName = "eval:" .. name,
			environment = environmentFor(anchor or harness.game),
		})
		return chunk()
	end

	return context
end

-- Writes the current DataModel back out, e.g. after a world build.
function Harness:savePlace(path)
	fs.writeFile(path, roblox.serializePlace(self.game))
end

return Harness
