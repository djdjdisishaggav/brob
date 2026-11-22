-- Procedural Mushroom Guardians lobby: a walled grove-courtyard at dusk.
--
-- Lobby space: origin at the centre of the floor, +X east, -Z north. Players
-- spawn on the south terrace facing north along the main avenue; the four
-- matchmaking stations line the north side behind the cross promenade.
--
-- Rules the layout follows:
--   * the walkable interior is a Bounds.Width x Bounds.Depth rectangle;
--   * nothing tall stands between the spawn and the station signs;
--   * tall scenery sits against the walls, the middle stays open.

local shared = game:GetService("ReplicatedStorage"):WaitForChild("MushroomLobby")
local Config = require(shared:WaitForChild("Config"))
local Theme = require(shared:WaitForChild("Theme"))

local Build = require(script.Parent.Build)
local Palette = require(script.Parent.Palette)
local Props = require(script.Parent.Props)
local StationBuilder = require(script.Parent.StationBuilder)

local LobbyBuilder = {}

LobbyBuilder.Bounds = { Width = 220, Depth = 150 }

-- Key coordinates in lobby space, shared with tests and documentation.
LobbyBuilder.Layout = {
	StationX = { -72, -24, 24, 72 },
	StationZ = -49,
	AvenueHalfWidth = 10,
	PromenadeNorth = -33,
	PromenadeSouth = -17,
	SpurHalfWidth = 5,
	LoopX = 88,
	LoopHalfWidth = 4,
	SouthPathZ = 36,
	SouthPathHalfWidth = 3,
	PlazaRadius = 21,
	TerraceHalfWidth = 16,
	TerraceNorth = 47,
	TerraceHeight = 2,
	StepsNorth = 41,
	StepsHalfWidth = 12,
	Spawn = Vector3.new(0, 2, 56),
	EyeHeight = 5.5,
	WallHeight = 22,
	GateHalfWidth = 18,
}

local LAYOUT = LobbyBuilder.Layout
local HALF_W = LobbyBuilder.Bounds.Width / 2
local HALF_D = LobbyBuilder.Bounds.Depth / 2

local WOOD = Enum.Material.Wood
local PLANKS = Enum.Material.WoodPlanks
local PLASTIC = Enum.Material.SmoothPlastic
local NEON = Enum.Material.Neon
local COBBLE = Enum.Material.Cobblestone
local SLATE = Enum.Material.Slate
local GRASS = Enum.Material.Grass

local SOLID = { collide = true }

type Context = {
	origin: CFrame,
	at: (x: number, y: number, z: number) -> CFrame,
	point: (x: number, y: number, z: number) -> Vector3,
}

-- Yaw that turns a base's +X axis towards the horizontal direction (dx, dz).
local function yawTowards(dx: number, dz: number): CFrame
	return CFrame.Angles(0, math.atan2(-dz, dx), 0)
end

-- Yaw that turns a base's +Z axis (the front of benches) towards (dx, dz).
local function facing(dx: number, dz: number): CFrame
	return CFrame.Angles(0, math.atan2(dx, dz), 0)
end

-- Ground and paths -----------------------------------------------------------

local function buildGround(ctx: Context, environment: Instance)
	local ground = Build.model(nil, "Ground")
	Build.block(
		ground,
		"Lawn",
		Vector3.new(LobbyBuilder.Bounds.Width + 20, 6, LobbyBuilder.Bounds.Depth + 20),
		ctx.at(0, -3, 0),
		Palette.Grass,
		GRASS,
		SOLID
	)
	Build.block(ground, "Outskirts", Vector3.new(900, 6, 820), ctx.at(0, -3.4, -40), Palette.OuterGrass, GRASS)

	-- Soft tonal patches so the lawns are not one flat colour.
	local rng = Build.rng(11)
	local patches = {
		{ 40, 6, 17 },
		{ 58, 22, 12 },
		{ 30, -6, 11 },
		{ 66, -8, 13 },
		{ 46, 56, 16 },
		{ 76, 60, 12 },
		{ 100, 10, 9 },
		{ 100, -52, 10 },
		{ 48, -52, 9 },
	}
	for _, side in { -1, 1 } do
		for index, patch in patches do
			local light = (index + (if side > 0 then 1 else 0)) % 2 == 0
			Build.post(
				ground,
				"LawnPatch",
				patch[3] * 2 * rng.range(0.9, 1.1),
				0.06,
				ctx.at(side * patch[1] + rng.range(-2, 2), 0, patch[2] + rng.range(-2, 2)),
				if light then Palette.GrassLight else Palette.GrassDeep,
				Enum.Material.LeafyGrass,
				{ shadow = false }
			)
		end
	end
	ground.Parent = environment
end

local function buildPaths(ctx: Context, environment: Instance)
	local paths = Build.model(nil, "Paths")
	local rng = Build.rng(23)

	-- Tops differ by a hair so overlapping slabs never z-fight.
	local function slab(name: string, x0: number, x1: number, z0: number, z1: number, top: number, color: Color3?)
		return Build.block(
			paths,
			name,
			Vector3.new(math.abs(x1 - x0), 0.5, math.abs(z1 - z0)),
			ctx.at((x0 + x1) / 2, top - 0.25, (z0 + z1) / 2),
			color or Palette.Path,
			COBBLE,
			SOLID
		)
	end
	local function kerb(x0: number, z0: number, x1: number, z1: number)
		local length = math.max(math.abs(x1 - x0), math.abs(z1 - z0)) + 0.9
		local alongX = math.abs(x1 - x0) > math.abs(z1 - z0)
		Build.block(
			paths,
			"Kerb",
			if alongX then Vector3.new(length, 0.6, 0.9) else Vector3.new(0.9, 0.6, length),
			ctx.at((x0 + x1) / 2, 0.14, (z0 + z1) / 2),
			Build.shade(Palette.Kerb, rng.range(-0.05, 0.05)),
			SLATE,
			{ shadow = false }
		)
	end

	local avenue = LAYOUT.AvenueHalfWidth
	local north, south = LAYOUT.PromenadeNorth, LAYOUT.PromenadeSouth
	local loopInner = LAYOUT.LoopX - LAYOUT.LoopHalfWidth
	local loopOuter = LAYOUT.LoopX + LAYOUT.LoopHalfWidth
	local southNear = LAYOUT.SouthPathZ - LAYOUT.SouthPathHalfWidth
	local southFar = LAYOUT.SouthPathZ + LAYOUT.SouthPathHalfWidth
	local spur = LAYOUT.SpurHalfWidth

	slab("Promenade", -loopOuter, loopOuter, north, south, 0.16)
	slab("Avenue", -avenue, avenue, south, LAYOUT.StepsNorth, 0.15)
	slab("SouthPath", -loopInner, loopInner, southNear, southFar, 0.14)
	for _, side in { -1, 1 } do
		slab("Loop", side * loopInner, side * loopOuter, south, southFar, 0.14)
	end
	for _, x in LAYOUT.StationX do
		slab("Spur", x - spur, x + spur, north - 5.6, north, 0.15)
	end

	-- Edging.
	local edges = { -loopOuter }
	for _, x in LAYOUT.StationX do
		table.insert(edges, x - spur)
		table.insert(edges, x + spur)
	end
	table.insert(edges, loopOuter)
	for index = 1, #edges, 2 do
		kerb(edges[index], north, edges[index + 1], north)
	end
	for _, x in LAYOUT.StationX do
		kerb(x - spur, north - 5.2, x - spur, north)
		kerb(x + spur, north - 5.2, x + spur, north)
	end
	local plazaCut = math.sqrt(LAYOUT.PlazaRadius ^ 2 - south ^ 2) + 1.2
	local plazaSide = math.sqrt(LAYOUT.PlazaRadius ^ 2 - avenue ^ 2) + 1
	for _, side in { -1, 1 } do
		kerb(side * plazaCut, south, side * loopInner, south)
		kerb(side * loopOuter, north, side * loopOuter, southFar)
		kerb(side * loopInner, south, side * loopInner, southNear)
		kerb(side * avenue, southNear, side * loopInner, southNear)
		kerb(side * avenue, southFar, side * loopOuter, southFar)
		kerb(side * avenue, plazaSide, side * avenue, southNear)
		kerb(side * avenue, southFar, side * avenue, LAYOUT.StepsNorth)
	end

	-- Flagstones break up the long slabs.
	local function flagstones(count: number, x0: number, x1: number, z0: number, z1: number, top: number)
		for _ = 1, count do
			local width, depth = rng.range(2.2, 4.4), rng.range(2.2, 4.4)
			local x = rng.range(x0 + width / 2 + 1, x1 - width / 2 - 1)
			local z = rng.range(z0 + depth / 2 + 1, z1 - depth / 2 - 1)
			Build.block(
				paths,
				"Flagstone",
				Vector3.new(width, 0.08, depth),
				ctx.at(x, top, z),
				if rng.chance(0.5) then Palette.PathLight else Palette.PathDeep,
				SLATE,
				{ shadow = false }
			)
		end
	end
	flagstones(26, -loopOuter, loopOuter, north, south, 0.16)
	flagstones(9, -avenue, avenue, 22, LAYOUT.StepsNorth, 0.15)
	flagstones(14, -loopInner, loopInner, southNear, southFar, 0.14)
	for _, side in { -1, 1 } do
		local x0, x1 = side * loopInner, side * loopOuter
		flagstones(7, math.min(x0, x1), math.max(x0, x1), south, southNear, 0.14)
	end

	paths.Parent = environment
end

-- Perimeter ------------------------------------------------------------------

type WallSpec = {
	name: string,
	from: Vector3,
	to: Vector3,
	inward: Vector3,
	buttresses: { number },
	gap: number?,
	seed: number,
}

local function buildWall(ctx: Context, parent: Instance, spec: WallSpec)
	local wall = Build.model(nil, spec.name)
	local rng = Build.rng(spec.seed)
	local delta = spec.to - spec.from
	local length = delta.Magnitude
	local direction = delta.Unit
	local outward = -spec.inward
	local middle = (spec.from + spec.to) / 2

	local function frame(distance: number, out: number, y: number): CFrame
		return ctx.origin * Build.alongX(spec.from + direction * distance + outward * out + Vector3.new(0, y, 0), direction)
	end
	local function inGap(distance: number, margin: number): boolean
		return spec.gap ~= nil and math.abs(distance - length / 2) < spec.gap + margin
	end

	-- Invisible barrier: the only thing that needs to stop players.
	Build.block(
		wall,
		"Barrier",
		Vector3.new(length + 12, 60, 4),
		ctx.origin * Build.alongX(middle + outward * 2 + Vector3.new(0, 30, 0), direction),
		Palette.Stone,
		PLASTIC,
		{ collide = true, transparency = 1 }
	)

	-- Mossy stone base.
	local segments = math.round(length / 11)
	local segmentLength = length / segments
	for index = 1, segments do
		local distance = (index - 0.5) * segmentLength
		if not inGap(distance, -segmentLength / 2) then
			local height = rng.range(5, 6.6)
			local depth = rng.range(5.6, 6.4)
			Build.block(
				wall,
				"Stone",
				Vector3.new(segmentLength + 0.05, height, depth),
				frame(distance, depth / 2, height / 2),
				Build.shade(Palette.Stone, rng.range(-0.12, 0.08)),
				COBBLE
			)
			if rng.chance(0.62) then
				Build.ellipsoid(
					wall,
					"Moss",
					Vector3.new(segmentLength * rng.range(0.55, 0.9), 1.1, 3.4),
					frame(distance + rng.range(-1.5, 1.5), 1.5, height),
					Build.shade(Palette.Moss, rng.range(-0.08, 0.12)),
					GRASS
				)
			end
		end
	end

	-- Palisade of uneven logs.
	local logs = math.floor(length / 3.1)
	local spacing = length / logs
	local phase = rng.range(0, 6)
	for index = 1, logs do
		local distance = (index - 0.5) * spacing
		if not inGap(distance, 0) then
			local top = LAYOUT.WallHeight - 2.2 + 2.3 * math.sin(index * 0.47 + phase) + rng.range(-1.2, 1.2)
			Build.post(
				wall,
				"Log",
				3.4,
				top - 2,
				frame(distance, 3.3, 2),
				Build.shade(Palette.Bark, rng.range(-0.16, 0.1)),
				WOOD
			)
		end
	end

	-- Binding rails on the courtyard side.
	local function rails(fromDistance: number, toDistance: number)
		for _, y in { 11.2, 16.4 } do
			Build.block(
				wall,
				"Rail",
				Vector3.new(toDistance - fromDistance, 0.9, 0.8),
				frame((fromDistance + toDistance) / 2, 1.45, y),
				Palette.BarkDark,
				WOOD
			)
		end
	end
	if spec.gap then
		rails(0, length / 2 - spec.gap)
		rails(length / 2 + spec.gap, length)
	else
		rails(0, length)
	end

	-- Buttress posts carry the wall lanterns.
	for index, distance in spec.buttresses do
		local height = LAYOUT.WallHeight + rng.range(3.4, 5)
		Build.post(wall, "Buttress", 4.2, height, frame(distance, 0.9, 0), Palette.BarkDeep, WOOD, SOLID)
		Build.ellipsoid(
			wall,
			"ButtressCap",
			Vector3.new(7, 3.4, 7),
			frame(distance, 0.9, height + 0.4),
			Palette.CapRoof,
			PLASTIC
		)
		Build.post(wall, "ButtressFoot", 5.4, 1.4, frame(distance, 0.9, 0), Palette.StoneDeep, COBBLE)
		local armFrom = frame(distance, -1, 13.4).Position
		local armTo = frame(distance, -4.5, 14.2).Position
		Build.rod(wall, "LanternArm", 0.5, armFrom, armTo, Palette.BarkDark, WOOD, nil, 0.15)
		Props.capLantern(wall, frame(distance, -4.3, 14.05), {
			name = "WallLantern" .. index,
			scale = 1.2,
			range = 24,
			brightness = 1.25,
		})
	end

	wall.Parent = parent
end

local function buildTower(ctx: Context, parent: Instance, name: string, x: number, z: number, seed: number)
	local tower = Build.model(nil, name)
	local base = ctx.at(x, 0, z)
	local rng = Build.rng(seed)

	Build.post(tower, "Foot", 23, 3, base, Palette.StoneDeep, COBBLE, SOLID)
	Build.post(tower, "Shaft", 20, 27, base, Palette.Stone, COBBLE, SOLID)
	Build.post(tower, "Band", 20.9, 1.3, base * CFrame.new(0, 12.5, 0), Palette.BarkDeep, WOOD)
	Build.post(tower, "Gallery", 23.6, 1.3, base * CFrame.new(0, 26.4, 0), Palette.Bark, PLANKS)

	-- Lit windows facing the courtyard.
	local toCentre = math.atan2(-z, -x)
	for _, offset in { -0.55, 0.55 } do
		local angle = toCentre + offset
		local window = Build.block(
			tower,
			"Window",
			Vector3.new(0.5, 3.4, 2),
			base * CFrame.new(math.cos(angle) * 9.9, 19.5, math.sin(angle) * 9.9) * CFrame.Angles(0, -angle, 0),
			Palette.WindowGlow,
			NEON
		)
		Build.block(
			tower,
			"WindowSill",
			Vector3.new(0.9, 0.5, 2.8),
			window.CFrame * CFrame.new(0, -2, 0),
			Palette.BarkDark,
			WOOD
		)
	end
	local glow = Build.block(
		tower,
		"WindowGlow",
		Vector3.new(1, 1, 1),
		base * CFrame.new(math.cos(toCentre) * 11, 19.5, math.sin(toCentre) * 11),
		Palette.WindowGlow,
		PLASTIC,
		{ transparency = 1 }
	)
	Build.light(glow, Palette.LanternLight, 26, 1)

	Props.mushroom(tower, base * CFrame.new(0, 26.5, 0) * CFrame.Angles(0, rng.range(0, 3), 0), {
		name = "Roof",
		height = 10.5,
		stemDiameter = 9,
		capRadius = 16.5,
		capHeight = 7.4,
		capColor = Palette.CapRoof,
		spots = 9,
		spotSize = 0.22,
		seed = seed,
	})

	tower.Parent = parent
end

local function buildGate(ctx: Context, parent: Instance)
	local gate = Build.model(nil, "Gate")
	local face = HALF_D
	local half = LAYOUT.GateHalfWidth

	for _, side in { -1, 1 } do
		Build.block(
			gate,
			"Pier",
			Vector3.new(7, 26, 7),
			ctx.at(side * (half - 3.5), 13, face + 3.5),
			Palette.Stone,
			COBBLE,
			SOLID
		)
		Build.block(
			gate,
			"PierBase",
			Vector3.new(8.4, 4, 8.4),
			ctx.at(side * (half - 3.5), 2, face + 3.5),
			Palette.StoneDeep,
			COBBLE
		)
		Build.block(
			gate,
			"Door",
			Vector3.new(half - 7, 20, 1.2),
			ctx.at(side * (half - 7) / 2, 12, face + 1.4),
			Palette.Bark,
			PLANKS
		)
		for _, y in { 5, 12, 19 } do
			Build.block(
				gate,
				"DoorBand",
				Vector3.new(half - 7.6, 0.8, 0.3),
				ctx.at(side * (half - 7) / 2, y, face + 0.7),
				Palette.Iron,
				Enum.Material.Metal
			)
		end
		Props.capLantern(gate, ctx.at(side * (half - 3.5), 15.5, face - 1.6), {
			name = "GateLantern",
			scale = 1.3,
			range = 26,
			brightness = 1.3,
		})
		Build.rod(
			gate,
			"LanternArm",
			0.5,
			ctx.point(side * (half - 3.5), 15, face + 0.2),
			ctx.point(side * (half - 3.5), 15.7, face - 1.8),
			Palette.BarkDark,
			WOOD
		)
	end

	Build.block(gate, "Lintel", Vector3.new(half * 2 - 12, 4, 5), ctx.at(0, 24, face + 3), Palette.BarkDeep, WOOD)
	Build.block(gate, "LockBar", Vector3.new(half * 2 - 16, 1.5, 0.9), ctx.at(0, 8.4, face + 0.5), Palette.BarkLight, WOOD)
	-- Bronze boss across the seam.
	local turned = CFrame.Angles(0, math.rad(90), 0)
	Build.cylinder(gate, "Boss", 6.6, 0.5, ctx.at(0, 14.6, face + 0.7) * turned, Theme.Color.Amber700, Enum.Material.Metal)
	Build.cylinder(gate, "BossInner", 5, 0.5, ctx.at(0, 14.6, face + 0.55) * turned, Palette.BarkDark, WOOD)
	Build.cylinder(gate, "BossCore", 1.8, 0.5, ctx.at(0, 14.6, face + 0.4) * turned, Theme.Color.Amber500, NEON)

	Props.mushroom(gate, ctx.at(0, 26, face + 3.5), {
		name = "Roof",
		height = 6.5,
		stemDiameter = 8,
		capRadius = 19,
		capHeight = 6,
		capColor = Palette.CapRoof,
		spots = 9,
		spotSize = 0.2,
		seed = 77,
	})

	gate.Parent = parent
end

local function buildPerimeter(ctx: Context, environment: Instance)
	local walls = Build.model(nil, "Walls")
	local w, d = HALF_W, HALF_D

	buildWall(ctx, walls, {
		name = "North",
		from = Vector3.new(-w, 0, -d),
		to = Vector3.new(w, 0, -d),
		inward = Vector3.new(0, 0, 1),
		buttresses = { w - 96, w - 48, w + 48, w + 96 },
		seed = 301,
	})
	buildWall(ctx, walls, {
		name = "South",
		from = Vector3.new(w, 0, d),
		to = Vector3.new(-w, 0, d),
		inward = Vector3.new(0, 0, -1),
		buttresses = { w - 96, w - 72, w - 48, w - 28, w + 28, w + 48, w + 72, w + 96 },
		gap = LAYOUT.GateHalfWidth,
		seed = 302,
	})
	buildWall(ctx, walls, {
		name = "West",
		from = Vector3.new(-w, 0, d),
		to = Vector3.new(-w, 0, -d),
		inward = Vector3.new(1, 0, 0),
		buttresses = { d - 50, d - 25, d, d + 25, d + 50 },
		seed = 303,
	})
	buildWall(ctx, walls, {
		name = "East",
		from = Vector3.new(w, 0, -d),
		to = Vector3.new(w, 0, d),
		inward = Vector3.new(-1, 0, 0),
		buttresses = { d - 50, d - 25, d, d + 25, d + 50 },
		seed = 304,
	})

	local index = 0
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			index += 1
			buildTower(ctx, walls, "Tower" .. index, sx * (w + 4), sz * (d + 4), 400 + index)
		end
	end
	buildGate(ctx, walls)
	walls.Parent = environment
end

-- Spawn terrace --------------------------------------------------------------

local function buildTerrace(ctx: Context, environment: Instance, root: Model)
	local terrace = Build.model(nil, "SpawnTerrace")
	local half = LAYOUT.TerraceHalfWidth
	local north = LAYOUT.TerraceNorth
	local height = LAYOUT.TerraceHeight
	local depth = HALF_D - north

	Build.block(
		terrace,
		"Deck",
		Vector3.new(half * 2, height, depth),
		ctx.at(0, height / 2, north + depth / 2),
		Palette.StoneLight,
		COBBLE,
		SOLID
	)
	Build.block(
		terrace,
		"DeckTrim",
		Vector3.new(half * 2 + 0.8, 0.5, depth + 0.4),
		ctx.at(0, height - 0.45, north + depth / 2 - 0.2),
		Palette.StoneDeep,
		SLATE
	)
	Build.block(
		terrace,
		"Boards",
		Vector3.new(20, 0.1, 17),
		ctx.at(0, height + 0.05, LAYOUT.Spawn.Z + 1),
		Palette.PlankLight,
		PLANKS,
		{ shadow = false }
	)
	-- Arrival circle.
	Build.post(terrace, "ArrivalRing", 11.4, 0.08, ctx.at(0, height + 0.08, LAYOUT.Spawn.Z), Theme.Color.Amber400, NEON)
	Build.post(terrace, "ArrivalDisc", 10.4, 0.1, ctx.at(0, height + 0.1, LAYOUT.Spawn.Z), Palette.Plank, PLANKS)
	Build.post(terrace, "ArrivalCore", 2.2, 0.06, ctx.at(0, height + 0.2, LAYOUT.Spawn.Z), Theme.Color.Amber300, NEON)

	-- Three broad steps down to the avenue.
	local steps = 3
	local run = (north - LAYOUT.StepsNorth) / steps
	for index = 1, steps do
		local top = height - index * height / (steps + 1)
		Build.block(
			terrace,
			"Step",
			Vector3.new(LAYOUT.StepsHalfWidth * 2, top, run),
			ctx.at(0, top / 2, north - (index - 0.5) * run),
			if index % 2 == 0 then Palette.StoneLight else Palette.Stone,
			COBBLE,
			SOLID
		)
	end

	for _, side in { -1, 1 } do
		-- Stepped cheek wall and corner pier.
		Build.block(
			terrace,
			"Cheek",
			Vector3.new(2.6, 1.7, north - LAYOUT.StepsNorth),
			ctx.at(side * (LAYOUT.StepsHalfWidth + 1.3), 0.85, (north + LAYOUT.StepsNorth) / 2),
			Palette.Stone,
			COBBLE,
			SOLID
		)
		Build.block(
			terrace,
			"Pier",
			Vector3.new(3.4, 4.4, 3.4),
			ctx.at(side * (half - 1.7), 2.2, north + 1.7),
			Palette.Stone,
			COBBLE,
			SOLID
		)
		Build.block(
			terrace,
			"PierCap",
			Vector3.new(4, 0.5, 4),
			ctx.at(side * (half - 1.7), 4.6, north + 1.7),
			Palette.StoneDeep,
			SLATE
		)
		Props.glowBollard(terrace, ctx.at(side * (half - 1.7), 4.85, north + 1.7), nil, 1.15)
		Build.block(
			terrace,
			"Parapet",
			Vector3.new(1.5, 1.4, depth - 3.4),
			ctx.at(side * (half - 0.75), height + 0.7, north + 3.4 + (depth - 3.4) / 2),
			Palette.Stone,
			COBBLE,
			SOLID
		)
		Build.ellipsoid(
			terrace,
			"ParapetMoss",
			Vector3.new(1.9, 0.7, 9),
			ctx.at(side * (half - 0.75), height + 1.4, north + 14 + side * 3),
			Palette.Moss,
			GRASS
		)
		-- Planter behind the arrival circle.
		Props.mushroomCluster(terrace, ctx.at(side * (half - 4.4), height, HALF_D - 4.5), {
			count = 5,
			spread = 2.6,
			minHeight = 2,
			maxHeight = 6.5,
			colors = { Palette.CapCream, Palette.CapRusset },
			spots = true,
			seed = 500 + side,
		})
	end
	terrace.Parent = environment

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	-- Identity rotation in lobby space: characters face -Z, towards the stations.
	spawn.CFrame = ctx.at(LAYOUT.Spawn.X, LAYOUT.Spawn.Y + 0.5, LAYOUT.Spawn.Z)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CanTouch = false
	spawn.CanQuery = false
	spawn.CastShadow = false
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.BottomSurface = Enum.SurfaceType.Smooth
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.AllowTeamChangeOnTouch = false
	spawn.Parent = root
end

-- Plaza ----------------------------------------------------------------------

local function buildPlaza(ctx: Context, environment: Instance)
	local plaza = Build.model(nil, "Plaza")
	local radius = LAYOUT.PlazaRadius

	Build.post(plaza, "Kerb", radius * 2 + 1.8, 0.5, ctx.at(0, -0.28, 0), Palette.Kerb, SLATE)
	Build.post(plaza, "Paving", radius * 2, 0.5, ctx.at(0, -0.24, 0), Palette.Path, COBBLE, SOLID)
	Build.post(plaza, "Band", 30.4, 0.5, ctx.at(0, -0.22, 0), Palette.PathDeep, SLATE)
	Build.post(plaza, "Inner", 28.6, 0.5, ctx.at(0, -0.2, 0), Palette.PathLight, COBBLE)

	-- Spore well: a low stone curb around a glowing pool.
	Build.post(plaza, "WellStep", 17.6, 0.5, ctx.at(0, 0.3, 0), Palette.StoneDeep, SLATE, SOLID)
	Build.post(plaza, "WellBarrier", 14.4, 1.9, ctx.at(0, 0.8, 0), Palette.Stone, PLASTIC, { collide = true, transparency = 1 })
	local stones = 14
	for index = 1, stones do
		local angle = index / stones * math.pi * 2
		Build.block(
			plaza,
			"WellStone",
			Vector3.new(1.7, if index % 2 == 0 then 1.75 else 1.95, 3.05),
			ctx.at(math.cos(angle) * 6.4, 1.7, math.sin(angle) * 6.4) * CFrame.Angles(0, -angle, 0),
			if index % 2 == 0 then Palette.Stone else Palette.StoneLight,
			COBBLE
		)
	end
	local pool = Build.post(plaza, "SporePool", 11.6, 1, ctx.at(0, 0.8, 0), Theme.Color.Spore500, NEON)
	Build.post(plaza, "SporePoolCore", 6, 0.06, ctx.at(0, 1.8, 0), Palette.SporeLight, NEON)
	Build.light(pool, Palette.SporeGlow, 30, 1.2)
	Build.spores(pool, Palette.SporeLight, 6)

	-- Floating heart crystal with one shard per station colour.
	local tilt = CFrame.Angles(math.rad(-35.264), 0, math.rad(45))
	Build.block(
		plaza,
		"HeartCrystal",
		Vector3.new(2.5, 2.5, 2.5),
		ctx.at(0, 5.5, 0) * tilt,
		Palette.SporeLight,
		Enum.Material.Glass,
		{ transparency = 0.25, reflectance = 0.15 }
	)
	local heart = Build.block(plaza, "HeartCore", Vector3.new(1.5, 1.5, 1.5), ctx.at(0, 5.5, 0) * tilt, Palette.Spot, NEON)
	Build.light(heart, Palette.SporeLight, 22, 1.1)
	for index, station in Config.Stations do
		local angle = math.rad(-135 + (index - 1) * 30)
		Build.block(
			plaza,
			"Shard",
			Vector3.new(0.85, 0.85, 0.85),
			ctx.at(math.cos(angle) * 3.5, 4.4 + (index % 2) * 1.5, math.sin(angle) * 3.5) * tilt,
			Theme.Station[station.Id],
			NEON
		)
	end

	-- Ring of low lamps, kept clear of the avenue and the cross axis.
	for index = 1, 8 do
		local angle = math.rad(22.5 + (index - 1) * 45)
		Props.glowBollard(plaza, ctx.at(math.cos(angle) * 12.2, 0.3, math.sin(angle) * 12.2), nil, 1)
	end

	plaza.Parent = environment
end

-- Lanterns along the paths ---------------------------------------------------

local function buildLanterns(ctx: Context, environment: Instance)
	local lanterns = Build.model(nil, "Lanterns")
	local north = LAYOUT.PromenadeNorth - 1.6
	local south = LAYOUT.PromenadeSouth + 1.6
	local loopOuter = LAYOUT.LoopX + LAYOUT.LoopHalfWidth + 1.6
	local southFar = LAYOUT.SouthPathZ + LAYOUT.SouthPathHalfWidth + 1.6
	-- x, z and the direction the arm points.
	local posts = {
		{ 0, north, 0, 1 },
		{ -48, north, 0, 1 },
		{ 48, north, 0, 1 },
		{ -36, south, 0, -1 },
		{ 36, south, 0, -1 },
		{ -66, south, 0, -1 },
		{ 66, south, 0, -1 },
		{ -(LAYOUT.AvenueHalfWidth + 1.6), 27, 1, 0 },
		{ LAYOUT.AvenueHalfWidth + 1.6, 27, -1, 0 },
		{ -34, southFar, 0, -1 },
		{ 34, southFar, 0, -1 },
		{ -64, southFar, 0, -1 },
		{ 64, southFar, 0, -1 },
		{ -loopOuter, 8, 1, 0 },
		{ loopOuter, 8, -1, 0 },
	}
	for _, post in posts do
		Props.lanternPost(lanterns, ctx.at(post[1], 0, post[2]) * yawTowards(post[3], post[4]), { height = 7.6 })
	end
	lanterns.Parent = environment
end

-- Gardens --------------------------------------------------------------------

local function buildShadeMushroom(ctx: Context, parent: Instance, x: number, z: number, seed: number)
	local group = Build.model(nil, "ShadeMushroom")
	local base = ctx.at(x, 0, z)
	Build.post(group, "Bed", 17, 0.1, base, Palette.Soil, Enum.Material.Ground, { shadow = false })
	Props.mushroom(group, base * CFrame.Angles(0, seed, 0), {
		name = "Mushroom",
		height = 19,
		stemDiameter = 3.6,
		capRadius = 12.5,
		capHeight = 4.8,
		capColor = Palette.CapBrown,
		spots = 9,
		spotSize = 0.2,
		collide = true,
		lightColor = Palette.LanternLight,
		lightRange = 30,
		lightBrightness = 0.8,
		seed = seed,
	})
	for index = 1, 3 do
		local angle = math.rad(90 + index * 120 + seed * 17)
		Props.capLantern(group, base * CFrame.new(math.cos(angle) * 8.6, 15.4, math.sin(angle) * 8.6), {
			scale = 1.1,
			range = 20,
			brightness = 1.1,
		})
	end
	-- Hexagonal ring bench around the stem.
	for index = 1, 6 do
		local angle = index / 6 * math.pi * 2
		local seat = base * CFrame.new(math.cos(angle) * 4.5, 0, math.sin(angle) * 4.5) * CFrame.Angles(0, -angle, 0)
		Build.block(
			group,
			"Seat",
			Vector3.new(1.9, 0.5, 5.3),
			seat * CFrame.new(0, 1.5, 0),
			Palette.PlankLight,
			PLANKS,
			SOLID
		)
		local corner = angle + math.pi / 6
		Build.post(
			group,
			"Leg",
			1.3,
			1.25,
			base * CFrame.new(math.cos(corner) * 5.1, 0, math.sin(corner) * 5.1),
			Palette.BarkDeep,
			WOOD
		)
	end
	group.Parent = parent
end

local function buildFairyRing(ctx: Context, parent: Instance, x: number, z: number, seed: number)
	local group = Build.model(nil, "FairyRing")
	local rng = Build.rng(seed)
	local base = ctx.at(x, 0, z)
	Props.boulder(group, base, 3.4, seed)
	Props.crystalCluster(group, base * CFrame.new(0.4, 1.3, 0.2), {
		count = 4,
		height = 3.2,
		color = Palette.SporeGlow,
		lightColor = Palette.SporeLight,
		seed = seed + 1,
		rock = false,
	})
	local count = 8
	local turn = rng.range(0, 1)
	for index = 1, count do
		local angle = (index + turn) / count * math.pi * 2
		local height = rng.range(1.3, 2.7)
		local capRadius = height * 0.42 + 0.3
		Props.mushroom(
			group,
			base * CFrame.new(math.cos(angle) * 5.4, 0, math.sin(angle) * 5.4) * CFrame.Angles(0, -angle, math.rad(-7)),
			{
				height = height,
				stemDiameter = height * 0.2 + 0.1,
				capRadius = capRadius,
				capHeight = capRadius * 0.62,
				capColor = if index % 2 == 0 then Palette.CapCream else Palette.CapRusset,
				seed = seed + index,
			}
		)
	end
	group.Parent = parent
end

local function buildGarden(ctx: Context, parent: Instance, side: number)
	local garden = Build.model(nil, if side < 0 then "WestGarden" else "EastGarden")
	local seed = if side < 0 then 610 else 640
	local loopInner = LAYOUT.LoopX - LAYOUT.LoopHalfWidth
	local loopOuter = LAYOUT.LoopX + LAYOUT.LoopHalfWidth

	buildShadeMushroom(ctx, garden, side * 60, 9, seed)
	buildFairyRing(ctx, garden, side * 33, 16, seed + 10)

	-- Crystal outcrop between the avenue lawn and the promenade.
	Props.crystalCluster(garden, ctx.at(side * 45, 0, -6), {
		count = 6,
		height = 5.6,
		color = Palette.CrystalGlow,
		lightColor = Palette.CrystalLight,
		seed = seed + 20,
	})
	Props.boulder(garden, ctx.at(side * 48.5, 0, -3.5), 2.6, seed + 21)
	Props.sporeBuds(garden, ctx.at(side * 41.5, 0, -3), 5, Palette.CrystalLight, seed + 22)

	-- Seating along the paths.
	local promenadeEdge = LAYOUT.PromenadeSouth + 3.4
	Props.bench(garden, ctx.at(side * 26, 0, promenadeEdge) * facing(0, -1))
	Props.bench(garden, ctx.at(side * 56, 0, promenadeEdge) * facing(0, -1))
	Props.bench(garden, ctx.at(side * (loopInner - 3.4), 0, 24) * facing(-side, 0))
	Props.bench(garden, ctx.at(side * 46, 0, LAYOUT.SouthPathZ - 6.6) * facing(0, -1))

	-- Border planting between the loop path and the wall, fenced off.
	local fenceX = side * (loopOuter + 2.6)
	local origin = ctx.origin
	Props.fence(garden, origin, Vector3.new(fenceX, 0, -13), Vector3.new(fenceX, 0, 3))
	Props.fence(garden, origin, Vector3.new(fenceX, 0, 13), Vector3.new(fenceX, 0, 33))
	Props.mushroomCluster(garden, ctx.at(side * 102, 0, -5), {
		count = 5,
		spread = 3.4,
		minHeight = 3,
		maxHeight = 9.5,
		colors = { Palette.CapCream, Palette.CapBrown },
		spots = true,
		seed = seed + 30,
	})
	Props.mushroomCluster(garden, ctx.at(side * 102.5, 0, 23), {
		count = 6,
		spread = 3.8,
		minHeight = 3,
		maxHeight = 11.5,
		colors = { Palette.CapRusset, Palette.CapCream },
		spots = true,
		seed = seed + 31,
	})
	Props.boulder(garden, ctx.at(side * 101, 0, 8.5), 4, seed + 32)
	Props.crystalCluster(garden, ctx.at(side * 104, 0, 10.5), {
		count = 4,
		height = 4.4,
		color = Palette.SporeGlow,
		lightColor = Palette.SporeLight,
		seed = seed + 33,
		rock = false,
	})
	Props.mushroomCluster(garden, ctx.at(side * 100, 0, 39), {
		count = 4,
		spread = 2.6,
		minHeight = 1.4,
		maxHeight = 4.2,
		colors = { Palette.SporeGlow },
		glow = true,
		seed = seed + 34,
	})

	-- South lawn: a pair of tall mushrooms against the wall, out of the sightline.
	Props.mushroom(garden, ctx.at(side * 60, 0, 63) * CFrame.Angles(0, 1, math.rad(side * 3)), {
		name = "LawnMushroom",
		height = 18,
		stemDiameter = 3.2,
		capRadius = 9.5,
		capHeight = 4.2,
		capColor = Palette.CapRusset,
		spots = 8,
		collide = true,
		lightColor = Palette.LanternLight,
		lightRange = 24,
		lightBrightness = 0.7,
		seed = seed + 40,
	})
	Props.mushroom(garden, ctx.at(side * 71, 0, 58) * CFrame.Angles(0, 2, math.rad(-side * 4)), {
		name = "LawnMushroom",
		height = 11.5,
		stemDiameter = 2.4,
		capRadius = 6.4,
		capHeight = 3,
		capColor = Palette.CapCream,
		spots = 6,
		collide = true,
		seed = seed + 41,
	})
	Props.boulder(garden, ctx.at(side * 51, 0, 67), 3.6, seed + 42)
	Props.mushroomCluster(garden, ctx.at(side * 86, 0, 66), {
		count = 5,
		spread = 3,
		minHeight = 2,
		maxHeight = 7,
		colors = { Palette.CapBrown, Palette.CapCream },
		spots = true,
		seed = seed + 43,
	})
	Props.crystalCluster(garden, ctx.at(side * 30, 0, 68), {
		count = 5,
		height = 5,
		color = Palette.CrystalGlow,
		lightColor = Palette.CrystalLight,
		seed = seed + 44,
	})
	Props.sporeBuds(garden, ctx.at(side * 22, 0, 44), 4, Palette.SporeLight, seed + 45)
	Props.sporeBuds(garden, ctx.at(side * 78, 0, 30), 5, Palette.LanternGlow, seed + 46)
	Props.sporeBuds(garden, ctx.at(side * 18, 0, -11), 4, Palette.SporeLight, seed + 47)

	garden.Parent = parent
end

-- Planting between the stations, against the north wall.
local function buildNorthBorder(ctx: Context, parent: Instance)
	local border = Build.model(nil, "NorthBorder")
	local stationZ = LAYOUT.StationZ

	for _, side in { -1, 1 } do
		local seed = if side < 0 then 700 else 720
		-- Pocket between the outer and inner station.
		Props.mushroom(border, ctx.at(side * 48, 0, stationZ - 17) * CFrame.Angles(0, seed, math.rad(side * 3)), {
			name = "PocketMushroom",
			height = 12,
			stemDiameter = 2.3,
			capRadius = 6,
			capHeight = 3,
			capColor = Palette.CapCream,
			spots = 6,
			collide = true,
			seed = seed,
		})
		Props.mushroomCluster(border, ctx.at(side * 52.5, 0, stationZ - 12), {
			count = 4,
			spread = 2.2,
			minHeight = 1.6,
			maxHeight = 5,
			colors = { Palette.CapBrown, Palette.CapCream },
			seed = seed + 1,
		})
		Props.boulder(border, ctx.at(side * 44, 0, stationZ - 11.5), 3.2, seed + 2)
		Props.crystalCluster(border, ctx.at(side * 46.5, 0, stationZ - 8.5), {
			count = 4,
			height = 3.6,
			color = Palette.SporeGlow,
			lightColor = Palette.SporeLight,
			seed = seed + 3,
			rock = false,
		})
		-- Corner beyond the outer station.
		Props.mushroom(border, ctx.at(side * 98, 0, stationZ - 9) * CFrame.Angles(0, seed, math.rad(-side * 4)), {
			name = "CornerMushroom",
			height = 15,
			stemDiameter = 2.8,
			capRadius = 7.4,
			capHeight = 3.6,
			capColor = Palette.CapBrown,
			spots = 7,
			collide = true,
			lightColor = Palette.LanternLight,
			lightRange = 22,
			lightBrightness = 0.7,
			seed = seed + 4,
		})
		Props.mushroomCluster(border, ctx.at(side * 93.5, 0, stationZ - 3), {
			count = 4,
			spread = 2.4,
			minHeight = 1.6,
			maxHeight = 5.4,
			colors = { Palette.CapRusset, Palette.CapCream },
			spots = true,
			seed = seed + 5,
		})
		Props.boulder(border, ctx.at(side * 101.5, 0, stationZ + 1), 3, seed + 6)
	end

	-- Heartroot: the Elder Mushroom's roots spill over the wall and cradle a
	-- crystal on the lobby's centre line.
	local heart = Build.model(nil, "Heartroot")
	local z = stationZ - 15
	Props.boulder(heart, ctx.at(0, 0, z), 6, 760)
	Props.crystalCluster(heart, ctx.at(0, 1.4, z), {
		count = 7,
		height = 9,
		color = Palette.SporeGlow,
		lightColor = Palette.SporeLight,
		seed = 761,
		rock = false,
	})
	local wallTop = LAYOUT.WallHeight
	for _, side in { -1, 1 } do
		Props.root(
			heart,
			"Root",
			ctx.point(side * 9, wallTop + 1, -HALF_D - 5),
			ctx.point(side * 10, wallTop - 4, z - 3),
			ctx.point(side * 6.5, 0.2, z + 4.5),
			3.4,
			1.2,
			6
		)
		Props.root(
			heart,
			"Root",
			ctx.point(side * 3.5, wallTop + 2, -HALF_D - 5),
			ctx.point(side * 4, wallTop - 8, z - 4),
			ctx.point(side * 2.6, 0.6, z - 1.5),
			2.4,
			0.9,
			5
		)
	end
	heart.Parent = border
	border.Parent = parent
end

-- Backdrop -------------------------------------------------------------------

local function buildBackdrop(ctx: Context, environment: Instance)
	local backdrop = Build.model(nil, "Backdrop")

	-- The Elder Mushroom frames the stations from behind the north wall.
	local elderBase = ctx.at(0, -1, -HALF_D - 42)
	local elder = Props.mushroom(nil, elderBase, {
		name = "ElderMushroom",
		height = 64,
		stemDiameter = 19,
		capRadius = 47,
		capHeight = 14,
		capColor = Palette.CapDusk,
		gillColor = Palette.GillDusk,
		stemColor = Palette.StemDusk,
		spots = 11,
		spotColor = Palette.CapDuskLight,
		spotSize = 0.2,
		drops = 12,
		dropColor = Palette.LanternGlow,
		seed = 901,
	})
	Build.ellipsoid(
		elder,
		"CapTier",
		Vector3.new(62, 26, 62),
		elderBase * CFrame.new(0, 64 + 9, 0),
		Build.shade(Palette.CapDusk, 0.06),
		PLASTIC
	)
	elder.Parent = backdrop

	-- Giants beyond the walls give the skyline its silhouette.
	local giants = {
		-- x, z, height, stem, cap radius, dome, teal?
		{ -100, -HALF_D - 36, 44, 9, 23, 8.5, 1 },
		{ 100, -HALF_D - 36, 47, 9.5, 24, 9, 1 },
		{ -HALF_W - 40, -28, 50, 9, 22, 8, 0 },
		{ HALF_W + 42, -34, 46, 8.5, 21, 8, 0 },
		{ -HALF_W - 34, 40, 36, 7, 17, 6.5, 1 },
		{ HALF_W + 36, 34, 40, 7.5, 18, 7, 1 },
		{ -62, HALF_D + 40, 42, 8, 20, 7.5, 0 },
		{ 70, HALF_D + 38, 38, 7.5, 18, 7, 0 },
	}
	for index, giant in giants do
		local teal = giant[7] == 1
		Props.mushroom(backdrop, ctx.at(giant[1], -1, giant[2]) * CFrame.Angles(0, index, 0), {
			name = "Giant" .. index,
			height = giant[3],
			stemDiameter = giant[4],
			capRadius = giant[5],
			capHeight = giant[6],
			capColor = if teal then Palette.CapDuskTeal else Palette.CapDusk,
			gillColor = Palette.GillDusk,
			stemColor = Palette.StemDusk,
			spots = 7,
			spotColor = if teal then Palette.SporeLight else Palette.CapDuskLight,
			spotSize = 0.2,
			seed = 910 + index,
		})
	end

	local trees = {
		{ -HALF_W - 22, -HALF_D - 16, 44 },
		{ HALF_W + 24, -HALF_D - 14, 48 },
		{ -HALF_W - 26, HALF_D + 18, 46 },
		{ HALF_W + 22, HALF_D + 20, 42 },
		{ -HALF_W - 22, 4, 40 },
		{ HALF_W + 24, -2, 44 },
		{ -24, HALF_D + 30, 44 },
		{ 30, HALF_D + 34, 48 },
		{ -52, -HALF_D - 24, 40 },
		{ 52, -HALF_D - 26, 42 },
	}
	for index, tree in trees do
		Props.tree(backdrop, ctx.at(tree[1], -1, tree[2]), {
			name = "Tree" .. index,
			height = tree[3],
			trunk = tree[3] * 0.12,
			canopy = tree[3] * 0.42,
			seed = 950 + index,
			color = if index % 2 == 0 then Palette.Canopy else Palette.CanopyDeep,
		})
	end

	backdrop.Parent = environment
end

-- Entry point ----------------------------------------------------------------

export type Options = { parent: Instance?, origin: CFrame? }

function LobbyBuilder.build(options: Options?): Model
	local parent: Instance = if options and options.parent then options.parent else workspace
	local existing = parent:FindFirstChild(Config.World.ModelName)
	if existing and existing:IsA("Model") then
		return existing
	end

	local origin = if options and options.origin then options.origin else CFrame.new()
	local ctx: Context = {
		origin = origin,
		at = function(x, y, z)
			return origin * CFrame.new(x, y, z)
		end,
		point = function(x, y, z)
			return (origin * CFrame.new(x, y, z)).Position
		end,
	}

	local root = Build.model(nil, Config.World.ModelName)
	root.WorldPivot = origin
	root:SetAttribute("Width", LobbyBuilder.Bounds.Width)
	root:SetAttribute("Depth", LobbyBuilder.Bounds.Depth)

	local environment = Build.folder(root, "Environment")
	buildGround(ctx, environment)
	buildPaths(ctx, environment)
	buildPerimeter(ctx, environment)
	buildTerrace(ctx, environment, root)
	buildPlaza(ctx, environment)
	buildLanterns(ctx, environment)

	local gardens = Build.model(nil, "Gardens")
	buildGarden(ctx, gardens, -1)
	buildGarden(ctx, gardens, 1)
	buildNorthBorder(ctx, gardens)
	gardens.Parent = environment
	buildBackdrop(ctx, environment)

	local stations = Build.folder(root, Config.World.StationsFolder)
	for index, station in Config.Stations do
		local x = LAYOUT.StationX[index]
		StationBuilder.build(station, ctx.at(x, 0, LAYOUT.StationZ), stations)
	end

	root.Parent = parent
	return root
end

return LobbyBuilder
