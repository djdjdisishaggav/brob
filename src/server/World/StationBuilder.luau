-- Builds one matchmaking station: a round pad with a status ring, a roofed
-- sign frame carrying the name sign, status board and four slot lanterns, a
-- prompt pedestal, and the station's signature giant mushrooms.
--
-- Station space: origin on the ground at the pad centre, +Z is the front
-- (towards the promenade), -Z the back (towards the wall).
--
-- All four stations share the same architecture. Identity comes from the
-- accent colour and from the mushroom count and species: one, two, three or
-- four caps above the sign.

local shared = game:GetService("ReplicatedStorage"):WaitForChild("MushroomLobby")
local Config = require(shared:WaitForChild("Config"))
local Theme = require(shared:WaitForChild("Theme"))

local Build = require(script.Parent.Build)
local Palette = require(script.Parent.Palette)
local Props = require(script.Parent.Props)
local StationView = require(script.Parent.StationView)

local StationBuilder = {}

StationBuilder.PadRadius = 9
StationBuilder.PlinthRadius = 11.5
StationBuilder.PadHeight = 1
-- Sign board centre and size in station space.
StationBuilder.SignCenter = Vector3.new(0, 17.1, -11.95)
StationBuilder.SignSize = Vector3.new(22.6, 8.5, 0.8)
StationBuilder.StatusCenter = Vector3.new(0, 10.25, -12)
StationBuilder.StatusSize = Vector3.new(16, 4.2, 0.6)
StationBuilder.FrameWidth = 24.4

local WOOD = Enum.Material.Wood
local PLANKS = Enum.Material.WoodPlanks
local PLASTIC = Enum.Material.SmoothPlastic
local NEON = Enum.Material.Neon
local STONE = Enum.Material.Cobblestone

local SIGN_Z = -12.5
local POST_X = 12.2
local SLOT_SPACING = 5.2

local SIGN_SCALE = 2.5

local function playersLine(count: number): string
	return if count == 1 then "1 PLAYER" else `{count} PLAYERS`
end

local function buildPlatform(model: Model, base: CFrame, station: Config.Station, accent: Color3)
	local platform = Build.model(nil, "Platform")
	local idle = Theme.Status.Available.Color

	Build.post(
		platform,
		"Plinth",
		StationBuilder.PlinthRadius * 2,
		0.5,
		base,
		Palette.Stone,
		STONE,
		{ collide = true }
	)
	-- Shows as a glowing band between the plinth and the pad.
	Build.post(platform, "Ring", StationBuilder.PadRadius * 2 + 1.5, 0.62, base, idle, NEON)
	local pad = Build.post(
		platform,
		"Pad",
		StationBuilder.PadRadius * 2,
		0.5,
		base * CFrame.new(0, 0.5, 0),
		Palette.Plank,
		PLANKS,
		{ collide = true }
	)
	pad:SetAttribute("ZoneRadius", StationBuilder.PadRadius)

	local inner = Build.post(platform, "RingInner", 11.8, 0.1, base * CFrame.new(0, 0.94, 0), idle, NEON)
	local glow = Build.light(inner, idle, 16, 0.7)
	glow.Name = "Glow"
	Build.post(platform, "PadCenter", 10.8, 0.1, base * CFrame.new(0, 0.98, 0), Palette.PlankLight, PLANKS)

	-- One dot per default party seat, in the station colour.
	local dots = station.DefaultSize
	for index = 1, dots do
		local x = (index - (dots + 1) / 2) * 2.3
		Build.post(platform, "SeatDot", 1.5, 0.08, base * CFrame.new(x, 1.04, 0), accent, NEON)
	end

	for _, side in { -1, 1 } do
		Props.glowBollard(platform, base * CFrame.new(side * 7.4, 0, 10.9), accent, 0.9)
	end

	platform.Parent = model
	return pad
end

local function buildPedestal(model: Model, base: CFrame, station: Config.Station, accent: Color3)
	local pedestal = Build.model(nil, "Pedestal")
	local foot = base * CFrame.new(0, StationBuilder.PadHeight, 7.3)
	local stump =
		Build.post(pedestal, "PromptAnchor", 1.7, 2.4, foot, Palette.Bark, WOOD, { collide = true, shadow = true })
	Build.post(pedestal, "Top", 2.2, 0.3, foot * CFrame.new(0, 2.4, 0), Palette.PlankLight, PLANKS)
	Build.post(pedestal, "ButtonStem", 0.45, 0.6, foot * CFrame.new(0, 2.7, 0), Palette.Stem, PLASTIC)
	local button = Build.ellipsoid(
		pedestal,
		"Button",
		Vector3.new(1.6, 0.9, 1.6),
		foot * CFrame.new(0, 3.45, 0),
		accent,
		NEON
	)
	Build.light(button, accent, 9, 0.8)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Prompt"
	prompt.ActionText = "Create Party"
	prompt.ObjectText = station.Name .. " Station"
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 10
	prompt.HoldDuration = 0
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.UIOffset = Vector2.new(0, 40)
	prompt.Parent = stump

	pedestal.Parent = model
end

local function buildSignGui(board: Part, station: Config.Station, accent: Color3)
	local gui = Build.surfaceGui(board, { name = "SignGui", pixelsPerStud = 50 })
	-- Roblox caps scaled text at 100 px. The layout is authored at 1/2.5 size
	-- and enlarged with a UIScale so the title can be over four studs tall.
	local root = Build.frame(gui, { name = "Root", size = UDim2.fromScale(1 / SIGN_SCALE, 1 / SIGN_SCALE) })
	local scale = Instance.new("UIScale")
	scale.Scale = SIGN_SCALE
	scale.Parent = root

	Build.frame(root, {
		name = "Panel",
		size = UDim2.new(1, -12, 1, -12),
		position = UDim2.fromOffset(6, 6),
		color = Palette.SignPanel,
		corner = UDim.new(0, 10),
		strokeColor = accent,
		strokeThickness = 2.5,
	})
	local badge = Build.frame(root, {
		name = "Badge",
		size = UDim2.fromOffset(108, 108),
		position = UDim2.new(0, 24, 0.5, 0),
		anchor = Vector2.new(0, 0.5),
		color = accent,
		corner = UDim.new(0.5, 0),
		strokeColor = Theme.darken(accent, 0.45),
		strokeThickness = 3,
		zIndex = 2,
	})
	Build.label(badge, {
		name = "Count",
		text = tostring(station.DefaultSize),
		font = Theme.Font.Display,
		color = Theme.Semantic.TextOnLight,
		size = UDim2.fromScale(0.7, 0.8),
		position = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		zIndex = 3,
	})
	Build.label(root, {
		name = "Title",
		text = string.upper(station.Name),
		font = Theme.Font.Display,
		color = Palette.SignText,
		size = UDim2.new(1, -172, 0, 90),
		position = UDim2.fromOffset(150, 12),
		alignX = Enum.TextXAlignment.Left,
	})
	Build.label(root, {
		name = "Players",
		text = playersLine(station.DefaultSize),
		font = Theme.Font.Display,
		color = accent,
		size = UDim2.new(1, -176, 0, 28),
		position = UDim2.fromOffset(154, 102),
		alignX = Enum.TextXAlignment.Left,
	})
	Build.label(root, {
		name = "Tagline",
		text = station.Tagline,
		font = Theme.Font.BodyBold,
		color = Palette.SignTextSoft,
		size = UDim2.new(1, -176, 0, 23),
		position = UDim2.fromOffset(154, 132),
		alignX = Enum.TextXAlignment.Left,
	})
end

local function buildSign(model: Model, base: CFrame, station: Config.Station, accent: Color3)
	local sign = Build.model(nil, "Sign")

	for _, side in { -1, 1 } do
		local foot = base * CFrame.new(side * POST_X, 0, SIGN_Z)
		Build.post(sign, "Footing", 3.6, 1.3, foot, Palette.Stone, STONE, { collide = true })
		Build.post(sign, "Post", 1.9, 23.4, foot, Palette.Bark, WOOD, { collide = true })
		-- Station pennant on the front of each post.
		Build.block(
			sign,
			"Pennant",
			Vector3.new(1.7, 5.6, 0.16),
			base * CFrame.new(side * POST_X, 17.4, SIGN_Z + 1.08),
			accent,
			Enum.Material.Fabric
		)
		Build.block(
			sign,
			"PennantRod",
			Vector3.new(2.3, 0.3, 0.4),
			base * CFrame.new(side * POST_X, 20.3, SIGN_Z + 1.08),
			Palette.BarkDark,
			WOOD
		)
		Props.capLantern(sign, base * CFrame.new(side * 14.3, 21.9, SIGN_Z), {
			name = "FrameLantern",
			scale = 1.15,
			range = 22,
			brightness = 1.3,
		})
	end

	local function point(x: number, y: number, z: number): Vector3
		return (base * CFrame.new(x, y, z)).Position
	end

	Build.rod(sign, "TopBeam", 1.2, point(-15.2, 22.5, SIGN_Z), point(15.2, 22.5, SIGN_Z), Palette.BarkDeep, WOOD)
	Build.rod(sign, "SlotBeam", 1, point(-POST_X, 7.65, SIGN_Z), point(POST_X, 7.65, SIGN_Z), Palette.BarkDeep, WOOD)
	Build.rod(sign, "NameRail", 0.45, point(-POST_X, 4.3, SIGN_Z), point(POST_X, 4.3, SIGN_Z), Palette.BarkDeep, WOOD)

	-- Gabled roof with a mossy front.
	local pitch = math.rad(32)
	local slab = Vector3.new(28, 0.6, 4.8)
	local rise = math.sin(pitch) * slab.Z / 2
	local run = math.cos(pitch) * slab.Z / 2
	local ridge = 26.1
	for _, side in { -1, 1 } do
		Build.block(
			sign,
			"Roof",
			slab,
			base * CFrame.new(0, ridge - rise, SIGN_Z + side * run) * CFrame.Angles(side * pitch, 0, 0),
			Palette.BarkDark,
			PLANKS
		)
	end
	Build.rod(sign, "Ridge", 0.95, point(-14.3, ridge + 0.1, SIGN_Z), point(14.3, ridge + 0.1, SIGN_Z), Palette.Bark, WOOD)
	local rng = Build.rng(station.Order * 17)
	for index = 1, 3 do
		local x = -9 + (index - 1) * 9 + rng.range(-2, 2)
		local length = rng.range(5, 8)
		Build.ellipsoid(
			sign,
			"RoofMoss",
			Vector3.new(length, 0.7, 3.2),
			base * CFrame.new(x, ridge - rise + 0.3, SIGN_Z + run) * CFrame.Angles(pitch, 0, 0),
			Build.shade(Palette.Moss, rng.range(-0.05, 0.1)),
			Enum.Material.Grass
		)
	end
	-- Accent caps sprouting from both ridge ends.
	for _, side in { -1, 1 } do
		Build.post(sign, "SproutStem", 0.7, 1.3, base * CFrame.new(side * 13.6, ridge + 0.3, SIGN_Z), Palette.Stem, PLASTIC)
		Build.ellipsoid(
			sign,
			"Sprout",
			Vector3.new(3.4, 1.9, 3.4),
			base * CFrame.new(side * 13.6, ridge + 1.9, SIGN_Z),
			accent,
			PLASTIC
		)
	end

	local board = Build.block(
		sign,
		"SignBoard",
		StationBuilder.SignSize,
		base * CFrame.new(StationBuilder.SignCenter),
		Palette.SignBoard,
		PLANKS,
		{ shadow = true }
	)
	local half = StationBuilder.SignSize.Y / 2
	for _, offset in { half + 0.25, -half - 0.25 } do
		Build.block(
			sign,
			"SignRail",
			Vector3.new(StationBuilder.SignSize.X, 0.5, 1.2),
			base * CFrame.new(StationBuilder.SignCenter + Vector3.new(0, offset, 0)),
			Palette.BarkLight,
			WOOD
		)
	end
	buildSignGui(board, station, accent)

	-- Low stone ledge that grounds the frame.
	Build.block(
		sign,
		"Ledge",
		Vector3.new(21.4, 1.5, 2.4),
		base * CFrame.new(0, 0.75, SIGN_Z - 0.3),
		Palette.StoneDeep,
		STONE,
		{ collide = true }
	)
	Build.ellipsoid(
		sign,
		"LedgeMoss",
		Vector3.new(19, 0.8, 2.6),
		base * CFrame.new(0, 1.5, SIGN_Z - 0.3),
		Palette.Moss,
		Enum.Material.Grass
	)

	sign.Parent = model
end

local function buildDisplay(model: Model, base: CFrame, accent: Color3)
	local display = Build.model(nil, "Display")

	local board = Build.block(
		display,
		"StatusBoard",
		StationBuilder.StatusSize,
		base * CFrame.new(StationBuilder.StatusCenter),
		Palette.SignBoard,
		PLANKS,
		{ shadow = true }
	)
	local gui = Build.surfaceGui(board, { name = "StatusGui", pixelsPerStud = 50 })
	local idle = Theme.Status.Available
	Build.frame(gui, {
		name = "Panel",
		size = UDim2.new(1, -12, 1, -12),
		position = UDim2.fromOffset(6, 6),
		color = Palette.SignPanel,
		corner = UDim.new(0, 16),
		strokeColor = Theme.Color.Bark500,
		strokeThickness = 4,
	})
	Build.frame(gui, {
		name = "Bar",
		size = UDim2.new(1, -56, 0, 8),
		position = UDim2.fromOffset(28, 16),
		color = idle.Color,
		corner = UDim.new(0.5, 0),
		zIndex = 2,
	})
	Build.label(gui, {
		name = "Status",
		text = idle.Label,
		font = Theme.Font.Display,
		color = idle.Color,
		size = UDim2.new(1, -48, 0, 76),
		position = UDim2.fromOffset(24, 28),
	})
	Build.label(gui, {
		name = "Detail",
		text = "",
		font = Theme.Font.BodyBold,
		color = Palette.SignText,
		size = UDim2.new(1, -48, 0, 86),
		position = UDim2.fromOffset(24, 106),
	})
	Build.label(gui, {
		name = "Info",
		text = "",
		font = Theme.Font.Body,
		color = Palette.SignTextSoft,
		size = UDim2.new(1, -48, 0, 34),
		position = UDim2.fromOffset(24, 164),
	})

	-- Four slot lanterns under the beam, each with a name plate below it.
	local slots = Build.model(nil, "Slots")
	for index = 1, StationView.SlotCount do
		local x = (index - (StationView.SlotCount + 1) / 2) * SLOT_SPACING
		local hook = base * CFrame.new(x, 7.2, SIGN_Z)
		local lantern = Props.capLantern(nil, hook, {
			name = "Slot" .. index,
			glow = accent,
			lightColor = accent,
			range = 13,
			brightness = 1.5,
			lit = false,
		})
		local slot = lantern.model
		slot:SetAttribute("Index", index)
		Build.block(
			slot,
			"Shutter",
			Vector3.new(1.42, 1.6, 1.42),
			hook * CFrame.new(0, -1.78, 0) * CFrame.Angles(0, math.rad(45), 0),
			Palette.BarkDark,
			PLANKS,
			{ transparency = 1 }
		)
		local plate = Build.block(
			slot,
			"Plate",
			Vector3.new(4.6, 1.15, 0.3),
			base * CFrame.new(x, 3.55, SIGN_Z + 0.3),
			Palette.SignBoard,
			PLANKS
		)
		local plateGui = Build.surfaceGui(plate, { name = "PlateGui", pixelsPerStud = 50 })
		Build.frame(plateGui, {
			name = "Panel",
			size = UDim2.new(1, -8, 1, -8),
			position = UDim2.fromOffset(4, 4),
			color = Palette.SignPanel,
			corner = UDim.new(0, 10),
			strokeColor = Theme.Color.Bark500,
			strokeThickness = 2,
		})
		Build.label(plateGui, {
			name = "Label",
			text = "",
			font = Theme.Font.Display,
			color = Palette.SignTextMuted,
			size = UDim2.new(1, -28, 1, -18),
			position = UDim2.fromOffset(14, 9),
		})
		slot.Parent = slots
	end
	slots.Parent = display

	display.Parent = model
end

type Species = {
	stem: number,
	radius: number,
	dome: number,
	tiers: { { number } }?,
	spots: number,
	spotSize: number?,
	spotGlow: boolean?,
	skirt: boolean?,
	drops: number?,
	finial: boolean?,
	-- x, z, height per mushroom.
	places: { { number } },
}

-- One, two, three and four caps: readable as a count from across the lobby.
local SPECIES: { [string]: Species } = {
	-- A single broad lantern-cap with a second dome and glowing drops.
	solo = {
		stem = 5.2,
		radius = 11.5,
		dome = 4.6,
		tiers = { { 8.2, 4.4, 3.1 } },
		spots = 7,
		spotSize = 0.2,
		drops = 8,
		places = { { 0, -19.5, 33 } },
	},
	-- Twin round glowcaps.
	duo = {
		stem = 3.7,
		radius = 8,
		dome = 6.6,
		spots = 9,
		spotSize = 0.24,
		spotGlow = true,
		places = { { -9.6, -20.6, 32.5 }, { 9.6, -21, 37.5 } },
	},
	-- Three tiered bell caps tipped with crystal.
	trio = {
		stem = 2.7,
		radius = 6.6,
		dome = 2,
		tiers = { { 4.9, 2.3, 2.3 }, { 3, 2.6, 4.9 } },
		spots = 0,
		finial = true,
		places = { { -12.6, -18.6, 29.5 }, { 0, -20.4, 35.5 }, { 12.6, -19, 31.5 } },
	},
	-- Four flat spotted parasols.
	squad = {
		stem = 2.2,
		radius = 5.7,
		dome = 2.4,
		spots = 7,
		spotSize = 0.3,
		skirt = true,
		places = { { -14.2, -18.4, 30 }, { -4.8, -20.4, 35 }, { 4.8, -19.8, 32.2 }, { 14.2, -18.6, 29.6 } },
	},
}

local function buildMushrooms(model: Model, base: CFrame, station: Config.Station, accent: Color3)
	local species = SPECIES[station.Id]
	if not species then
		return
	end
	local mushrooms = Build.model(nil, "Mushrooms")
	local rng = Build.rng(station.Order * 101)
	local gill = Build.mix(Palette.Gill, accent, 0.12)

	for index, place in species.places do
		local foot = base * CFrame.new(place[1], 0, place[2]) * CFrame.Angles(0, rng.range(0, math.pi), 0)
		local height = place[3]
		local mushroom = Props.mushroom(nil, foot, {
			name = "Mushroom" .. index,
			height = height,
			stemDiameter = species.stem,
			capRadius = species.radius,
			capHeight = species.dome,
			capColor = accent,
			gillColor = gill,
			spots = species.spots,
			spotSize = species.spotSize,
			spotGlow = species.spotGlow,
			spotColor = if species.spotGlow then Theme.lighten(accent, 0.55) else Palette.Spot,
			skirt = species.skirt,
			drops = species.drops,
			dropColor = Theme.lighten(accent, 0.3),
			lightColor = Theme.lighten(accent, 0.25),
			lightRange = species.radius * 2.6 + 6,
			lightBrightness = 1,
			collide = true,
			seed = station.Order * 53 + index,
		})

		local top = species.dome
		if species.tiers then
			for tierIndex, tier in species.tiers do
				Build.ellipsoid(
					mushroom,
					"CapTier",
					Vector3.new(tier[1] * 2, tier[2] * 2, tier[1] * 2),
					foot * CFrame.new(0, height + tier[3], 0),
					Theme.lighten(accent, 0.06 * tierIndex),
					PLASTIC
				)
				top = tier[3] + tier[2]
			end
		end
		if species.finial then
			Props.crystal(
				mushroom,
				foot * CFrame.new(0, height + top - 0.5, 0) * CFrame.Angles(0, math.rad(45), 0),
				3.4,
				0.9,
				Theme.lighten(accent, 0.35),
				true
			)
		end

		-- Two buttress roots reaching forward under the sign.
		for _, side in { -1, 1 } do
			local start = (foot * CFrame.new(0, species.stem * 0.9, 0)).Position
			local reach = species.stem * 1.5 + 2
			local angle = math.rad(90 + side * rng.range(35, 70))
			local finish = (base * CFrame.new(
				place[1] + math.cos(angle) * reach,
				0.1,
				place[2] + math.sin(angle) * reach
			)).Position
			local middle = (start + finish) / 2 + Vector3.new(0, species.stem * 0.55, 0)
			Props.root(mushroom, "Root", start, middle, finish, species.stem * 0.42, species.stem * 0.2, 3, Palette.StemShade)
		end
		mushroom.Parent = mushrooms
	end

	mushrooms.Parent = model
end

local function buildDressing(model: Model, base: CFrame, station: Config.Station, accent: Color3)
	local dressing = Build.model(nil, "Dressing")
	local soft = Build.mix(accent, Palette.CapCream, 0.35)
	for _, side in { -1, 1 } do
		Props.mushroomCluster(dressing, base * CFrame.new(side * 15.6, 0, SIGN_Z + 2.2), {
			count = 4,
			spread = 2.1,
			minHeight = 1.2,
			maxHeight = 3.6,
			colors = { soft, accent },
			seed = station.Order * 7 + (if side > 0 then 3 else 1),
		})
	end
	dressing.Parent = model
end

function StationBuilder.build(station: Config.Station, base: CFrame, parent: Instance?): Model
	local accent = Theme.Station[station.Id] or Theme.Color.Amber400
	local model = Build.model(nil, station.Id)
	model:SetAttribute("StationId", station.Id)
	model:SetAttribute("StationName", station.Name)
	model:SetAttribute("DefaultSize", station.DefaultSize)
	model.WorldPivot = base

	local pad = buildPlatform(model, base, station, accent)
	model.PrimaryPart = pad
	buildPedestal(model, base, station, accent)
	buildSign(model, base, station, accent)
	buildDisplay(model, base, accent)
	buildMushrooms(model, base, station, accent)
	buildDressing(model, base, station, accent)

	-- Start in the idle state so the station is correct before the first push.
	local view = StationView.new(model)
	view:Render({
		id = station.Id,
		status = "Available",
		memberNames = {},
		memberCount = 0,
		maxSize = station.DefaultSize,
	}, 0)
	view:Destroy()

	model.Parent = parent
	return model
end

return StationBuilder
