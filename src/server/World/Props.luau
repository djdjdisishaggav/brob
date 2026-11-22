-- Reusable scenery kit: mushrooms, lanterns, crystals, roots, fences, benches,
-- boulders and trees. Every prop is built relative to a base CFrame whose
-- origin sits on the ground and whose Y axis points up.

local Build = require(script.Parent.Build)
local Palette = require(script.Parent.Palette)

local Props = {}

local PLASTIC = Enum.Material.SmoothPlastic
local WOOD = Enum.Material.Wood
local NEON = Enum.Material.Neon
local GOLDEN_ANGLE = 2.399963

local function point(base: CFrame, x: number, y: number, z: number): Vector3
	return (base * CFrame.new(x, y, z)).Position
end

-- Mushrooms ------------------------------------------------------------------

export type Brim = { radius: number, half: number, drop: number }

export type MushroomSpec = {
	name: string?,
	-- Ground to the widest line of the cap.
	height: number,
	stemDiameter: number,
	capRadius: number,
	-- Dome height above the widest line.
	capHeight: number,
	capColor: Color3,
	capMaterial: Enum.Material?,
	gillColor: Color3?,
	stemColor: Color3?,
	-- Optional flared rim below the dome, as fractions of the cap.
	brim: Brim?,
	spots: number?,
	spotColor: Color3?,
	spotSize: number?,
	spotGlow: boolean?,
	-- Elevation band for the spots, in degrees above the widest line.
	spotLow: number?,
	spotHigh: number?,
	skirt: boolean?,
	-- Hanging glow drops under the rim.
	drops: number?,
	dropColor: Color3?,
	finialColor: Color3?,
	lightColor: Color3?,
	lightRange: number?,
	lightBrightness: number?,
	collide: boolean?,
	seed: number?,
}

function Props.mushroom(parent: Instance?, base: CFrame, spec: MushroomSpec): Model
	local model = Build.model(nil, spec.name or "Mushroom")
	local rng = Build.rng(spec.seed or 1)
	local height = spec.height
	local radius = spec.capRadius
	local dome = spec.capHeight
	local stem = spec.stemDiameter
	local stemColor = spec.stemColor or Palette.Stem
	local gillColor = spec.gillColor or Palette.Gill
	local capMaterial = spec.capMaterial or PLASTIC
	local solid = { collide = spec.collide == true }

	-- The pale underside is a second, lower ellipsoid that swallows the bottom
	-- half of the cap, so the cap reads two-tone from below.
	local gillRadius = radius * 0.9
	local gillHalf = dome * 0.6
	local gillDrop = dome * 0.5
	if spec.brim then
		gillRadius = spec.brim.radius * 0.92
		gillDrop = spec.brim.drop
		gillHalf = math.max(dome - gillDrop + dome * 0.08, spec.brim.half * 1.6)
	end
	local stemTop = height - gillDrop

	if height > 7 then
		-- A swollen foot and a soft collar hide the cylinder's hard ends.
		Build.post(model, "Stem", stem, stemTop, base, stemColor, PLASTIC, solid)
		Build.ellipsoid(
			model,
			"Foot",
			Vector3.new(stem * 1.9, stem * 1.5, stem * 1.9),
			base * CFrame.new(0, stem * 0.3, 0),
			Build.shade(stemColor, -0.1),
			PLASTIC
		)
		Build.ellipsoid(
			model,
			"Collar",
			Vector3.new(stem * 1.5, stem * 0.9, stem * 1.5),
			base * CFrame.new(0, stemTop - gillHalf * 0.75, 0),
			Build.shade(stemColor, -0.05),
			PLASTIC
		)
	else
		Build.post(model, "Stem", stem, stemTop, base, stemColor, PLASTIC, solid)
	end

	local capCenter = base * CFrame.new(0, height, 0)
	local gill = Build.ellipsoid(
		model,
		"Gill",
		Vector3.new(gillRadius * 2, gillHalf * 2, gillRadius * 2),
		capCenter * CFrame.new(0, -gillDrop, 0),
		gillColor,
		PLASTIC
	)
	Build.ellipsoid(
		model,
		"Cap",
		Vector3.new(radius * 2, dome * 2, radius * 2),
		capCenter,
		spec.capColor,
		capMaterial
	)
	if spec.brim then
		Build.ellipsoid(
			model,
			"Brim",
			Vector3.new(spec.brim.radius * 2, spec.brim.half * 2, spec.brim.radius * 2),
			capCenter * CFrame.new(0, -spec.brim.drop, 0),
			Build.shade(spec.capColor, -0.08),
			capMaterial
		)
	end

	if spec.skirt then
		Build.ellipsoid(
			model,
			"Skirt",
			Vector3.new(stem * 2.1, stem * 0.36, stem * 2.1),
			base * CFrame.new(0, stemTop * 0.74, 0),
			Build.shade(stemColor, -0.04),
			PLASTIC
		)
	end

	local spots = spec.spots or 0
	if spots > 0 then
		local spotColor = spec.spotColor or Palette.Spot
		local spotMaterial = if spec.spotGlow then NEON else PLASTIC
		local turn = rng.range(0, math.pi * 2)
		local spotLow, spotHigh = spec.spotLow or 36, spec.spotHigh or 82
		for index = 1, spots do
			local alpha = (index - 0.5) / spots
			local elevation = math.rad(spotLow + (spotHigh - spotLow) * alpha)
			local azimuth = turn + index * GOLDEN_ANGLE
			local cosE, sinE = math.cos(elevation), math.sin(elevation)
			local local0 = Vector3.new(radius * cosE * math.cos(azimuth), dome * sinE, radius * cosE * math.sin(azimuth))
			local normal = Vector3.new(local0.X / (radius * radius), local0.Y / (dome * dome), local0.Z / (radius * radius)).Unit
			local size = radius * (spec.spotSize or 0.26) * rng.range(0.72, 1.18) * (1.1 - 0.35 * alpha)
			-- Sunk into the cap so only a shallow lens shows and the outline stays clean.
			Build.ellipsoid(
				model,
				"Spot",
				Vector3.new(size, size * 0.3, size),
				capCenter * Build.alongY(local0 - normal * size * 0.07, normal),
				spotColor,
				spotMaterial,
				{ shadow = false }
			)
		end
	end

	local drops = spec.drops or 0
	if drops > 0 then
		local dropColor = spec.dropColor or Palette.LanternGlow
		local ringRadius = gillRadius * 0.78
		local rimY = -gillDrop - gillHalf * 0.62
		local turn = rng.range(0, math.pi * 2)
		for index = 1, drops do
			local angle = turn + index / drops * math.pi * 2
			local length = radius * rng.range(0.16, 0.34)
			local x, z = math.cos(angle) * ringRadius, math.sin(angle) * ringRadius
			local size = math.max(0.5, radius * 0.085)
			Build.rod(
				model,
				"DropThread",
				math.max(0.1, size * 0.14),
				(capCenter * CFrame.new(x, rimY + size, z)).Position,
				(capCenter * CFrame.new(x, rimY - length, z)).Position,
				Palette.BarkDeep,
				WOOD
			)
			Build.ellipsoid(
				model,
				"Drop",
				Vector3.new(size, size * 1.45, size),
				capCenter * CFrame.new(x, rimY - length - size * 0.6, z),
				dropColor,
				NEON
			)
		end
	end

	if spec.finialColor then
		local size = radius * 0.2
		Build.block(
			model,
			"Finial",
			Vector3.new(size, size * 2.6, size),
			capCenter * CFrame.new(0, dome + size * 0.9, 0) * CFrame.Angles(0, math.rad(45), 0),
			spec.finialColor,
			NEON
		)
	end

	if spec.lightColor then
		Build.light(gill, spec.lightColor, spec.lightRange or radius * 2.4, spec.lightBrightness or 1.2)
	end

	model.Parent = parent
	return model
end

export type ClusterSpec = {
	name: string?,
	count: number,
	spread: number,
	minHeight: number,
	maxHeight: number,
	colors: { Color3 },
	seed: number,
	glow: boolean?,
	spots: boolean?,
}

-- A tidy clump of small mushrooms: the tallest in the middle, smaller ones
-- leaning outwards around it.
function Props.mushroomCluster(parent: Instance?, base: CFrame, spec: ClusterSpec): Model
	local model = Build.model(nil, spec.name or "MushroomCluster")
	local rng = Build.rng(spec.seed)
	local turn = rng.range(0, math.pi * 2)
	for index = 1, spec.count do
		local alpha = if spec.count > 1 then (index - 1) / (spec.count - 1) else 0
		local distance = if index == 1 then 0 else spec.spread * (0.45 + 0.55 * math.sqrt(alpha))
		local angle = turn + index * GOLDEN_ANGLE
		local height = spec.maxHeight - (spec.maxHeight - spec.minHeight) * alpha * rng.range(0.8, 1)
		local lean = if index == 1 then 0 else math.rad(rng.range(4, 13))
		local capRadius = height * rng.range(0.34, 0.46) + 0.25
		local color = spec.colors[(index - 1) % #spec.colors + 1]
		local child = base
			* CFrame.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
			* CFrame.Angles(0, -angle, 0)
			* CFrame.Angles(0, 0, -lean)
		Props.mushroom(model, child, {
			name = "Mushroom" .. index,
			height = height,
			stemDiameter = math.max(0.3, height * 0.17),
			capRadius = capRadius,
			capHeight = capRadius * rng.range(0.5, 0.72),
			capColor = Build.shade(color, rng.range(-0.06, 0.08)),
			capMaterial = if spec.glow then NEON else PLASTIC,
			spots = if spec.spots and index <= 2 then 3 else 0,
			spotSize = 0.34,
			seed = spec.seed * 31 + index,
		})
	end
	model.Parent = parent
	return model
end

-- Lanterns -------------------------------------------------------------------

export type LanternSpec = {
	name: string?,
	scale: number?,
	glow: Color3?,
	lightColor: Color3?,
	range: number?,
	brightness: number?,
	capColor: Color3?,
	lit: boolean?,
}

export type Lantern = {
	model: Model,
	core: Part,
	cap: Part,
	light: PointLight,
	-- Distance from the hook to the lowest point.
	drop: number,
}

-- The shared lantern of the grove: a glowing bulb under a small mushroom cap,
-- hanging from `hook` along its -Y axis.
function Props.capLantern(parent: Instance?, hook: CFrame, spec: LanternSpec?): Lantern
	local scale = if spec and spec.scale then spec.scale else 1
	local glow = if spec and spec.glow then spec.glow else Palette.LanternGlow
	local capColor = if spec and spec.capColor then spec.capColor else Palette.LanternCap
	local model = Build.model(nil, if spec and spec.name then spec.name else "Lantern")

	Build.rod(
		model,
		"Hanger",
		math.max(0.1, 0.12 * scale),
		hook.Position,
		point(hook, 0, -0.7 * scale, 0),
		Palette.Iron,
		Enum.Material.Metal
	)
	local core = Build.ellipsoid(
		model,
		"Core",
		Vector3.new(1.25 * scale, 1.5 * scale, 1.25 * scale),
		hook * CFrame.new(0, -1.75 * scale, 0),
		glow,
		NEON
	)
	local cap = Build.ellipsoid(
		model,
		"Cap",
		Vector3.new(1.95 * scale, 0.95 * scale, 1.95 * scale),
		hook * CFrame.new(0, -0.95 * scale, 0),
		capColor,
		PLASTIC
	)
	Build.post(
		model,
		"Base",
		0.8 * scale,
		0.18 * scale,
		hook * CFrame.new(0, -2.58 * scale, 0),
		Palette.Iron,
		Enum.Material.Metal
	)
	local light = Build.light(
		core,
		if spec and spec.lightColor then spec.lightColor else Palette.LanternLight,
		if spec and spec.range then spec.range else 18,
		if spec and spec.brightness then spec.brightness else 1.1
	)
	if spec and spec.lit == false then
		light.Enabled = false
	end

	model.Parent = parent
	return { model = model, core = core, cap = cap, light = light, drop = 2.58 * scale }
end

export type PostSpec = {
	name: string?,
	height: number?,
	scale: number?,
	glow: Color3?,
	lightColor: Color3?,
	range: number?,
	brightness: number?,
}

-- A path lantern: a timber post with a crook arm along the base's +X axis.
function Props.lanternPost(parent: Instance?, base: CFrame, spec: PostSpec?): Model
	local height = if spec and spec.height then spec.height else 7.6
	local scale = if spec and spec.scale then spec.scale else 0.9
	local model = Build.model(nil, if spec and spec.name then spec.name else "LanternPost")

	Build.post(model, "Foot", 1.7, 0.55, base, Palette.Stone, Enum.Material.Slate)
	Build.post(model, "Post", 0.62, height, base, Palette.BarkDeep, WOOD)
	Build.ball(model, "Knob", 0.95, point(base, 0, height + 0.2, 0), Palette.Bark, WOOD)
	Build.rod(
		model,
		"Arm",
		0.34,
		point(base, 0, height - 0.75, 0),
		point(base, 1.55, height - 0.2, 0),
		Palette.BarkDeep,
		WOOD,
		nil,
		0.1
	)
	Props.capLantern(model, base * CFrame.new(1.55, height - 0.3, 0), {
		scale = scale,
		glow = spec and spec.glow or nil,
		lightColor = spec and spec.lightColor or nil,
		range = spec and spec.range or 20,
		brightness = spec and spec.brightness or 1.2,
	})

	model.Parent = parent
	return model
end

-- A knee-high glowing mushroom lamp for plaza and pad edges.
function Props.glowBollard(parent: Instance?, base: CFrame, glow: Color3?, scale: number?): Model
	local s = scale or 1
	local model = Build.model(nil, "GlowBollard")
	Build.post(model, "Stem", 0.75 * s, 2.1 * s, base, Palette.StemShade, PLASTIC)
	local core = Build.ellipsoid(
		model,
		"Core",
		Vector3.new(1.3 * s, 1.3 * s, 1.3 * s),
		base * CFrame.new(0, 2.45 * s, 0),
		glow or Palette.LanternGlow,
		NEON
	)
	Build.ellipsoid(
		model,
		"Cap",
		Vector3.new(2.4 * s, 1.1 * s, 2.4 * s),
		base * CFrame.new(0, 3.1 * s, 0),
		Palette.LanternCap,
		PLASTIC
	)
	Build.light(core, glow or Palette.LanternLight, 12, 0.9)
	model.Parent = parent
	return model
end

-- Crystals -------------------------------------------------------------------

-- One shard: a square prism with a slanted cut top, standing on `base`.
function Props.crystal(
	parent: Instance?,
	base: CFrame,
	height: number,
	width: number,
	color: Color3,
	glow: boolean?
): Part
	local material = if glow then NEON else Enum.Material.Glass
	local options = if glow then nil else { transparency = 0.12, reflectance = 0.12 }
	local tip = width * 0.9
	local body = Build.block(
		parent,
		"Crystal",
		Vector3.new(width, height - tip, width),
		base * CFrame.new(0, (height - tip) / 2, 0),
		color,
		material,
		options
	)
	Build.wedge(
		parent,
		"CrystalTip",
		Vector3.new(width, tip, width),
		base * CFrame.new(0, height - tip / 2, 0),
		color,
		material,
		options
	)
	return body
end

export type CrystalSpec = {
	name: string?,
	count: number,
	height: number,
	color: Color3,
	lightColor: Color3?,
	seed: number,
	rock: boolean?,
}

function Props.crystalCluster(parent: Instance?, base: CFrame, spec: CrystalSpec): Model
	local model = Build.model(nil, spec.name or "CrystalCluster")
	local rng = Build.rng(spec.seed)
	local height = spec.height
	if spec.rock ~= false then
		Build.ellipsoid(
			model,
			"Rock",
			Vector3.new(height * 0.95, height * 0.36, height * 0.8),
			base * CFrame.new(0, height * 0.06, 0) * CFrame.Angles(0, rng.range(0, 3), 0),
			Palette.StoneDeep,
			Enum.Material.Slate
		)
	end
	local turn = rng.range(0, math.pi * 2)
	local core: Part? = nil
	for index = 1, spec.count do
		local centre = index == 1
		local angle = turn + index * GOLDEN_ANGLE
		local distance = if centre then 0 else height * rng.range(0.16, 0.3)
		local tilt = if centre then math.rad(rng.range(-5, 5)) else math.rad(rng.range(14, 34))
		local shardHeight = if centre then height else height * rng.range(0.38, 0.72)
		local width = shardHeight * rng.range(0.2, 0.27) + 0.12
		local shardBase = base
			* CFrame.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
			* CFrame.Angles(0, -angle + math.rad(rng.range(-25, 25)), 0)
			* CFrame.Angles(0, 0, -tilt)
			* CFrame.Angles(0, math.rad(45), 0)
		local shard = Props.crystal(
			model,
			shardBase,
			shardHeight,
			width,
			Build.shade(spec.color, rng.range(-0.05, 0.2)),
			index % 3 == 1
		)
		if centre then
			core = shard
		end
	end
	if core and spec.lightColor then
		Build.light(core, spec.lightColor, height * 3.2 + 6, 1.1)
	end
	model.Parent = parent
	return model
end

-- Roots and timber -----------------------------------------------------------

-- A root following a quadratic curve through three control points (world
-- space), tapering from `startDiameter` to `endDiameter`.
function Props.root(
	parent: Instance?,
	name: string,
	p0: Vector3,
	p1: Vector3,
	p2: Vector3,
	startDiameter: number,
	endDiameter: number,
	segments: number,
	color: Color3?,
	collide: boolean?
)
	local previous = p0
	for index = 1, segments do
		local t = index / segments
		local position = p0 * ((1 - t) * (1 - t)) + p1 * (2 * (1 - t) * t) + p2 * (t * t)
		local diameter = startDiameter + (endDiameter - startDiameter) * ((index - 0.5) / segments)
		Build.rod(
			parent,
			name,
			diameter,
			previous,
			position,
			color or Palette.Bark,
			WOOD,
			{ collide = collide == true },
			diameter * 0.28
		)
		previous = position
	end
end

export type FenceSpec = { name: string?, height: number?, spacing: number?, collide: boolean? }

-- A low two-rail log fence between two points given in `frame` space.
function Props.fence(parent: Instance?, frame: CFrame, from: Vector3, to: Vector3, spec: FenceSpec?): Model
	local model = Build.model(nil, if spec and spec.name then spec.name else "Fence")
	local height = if spec and spec.height then spec.height else 2.3
	local length = (to - from).Magnitude
	local bays = math.max(1, math.round(length / (if spec and spec.spacing then spec.spacing else 5)))
	local up = Vector3.new(0, 1, 0)
	for index = 0, bays do
		local position = from:Lerp(to, index / bays)
		Build.post(model, "Post", 0.7, height, frame * CFrame.new(position), Palette.Bark, WOOD)
		Build.ellipsoid(
			model,
			"PostCap",
			Vector3.new(1.05, 0.5, 1.05),
			frame * CFrame.new(position + up * height),
			Palette.LanternCap,
			PLASTIC
		)
	end
	for _, fraction in { 0.42, 0.8 } do
		Build.rod(
			model,
			"Rail",
			0.36,
			(frame * CFrame.new(from + up * height * fraction)).Position,
			(frame * CFrame.new(to + up * height * fraction)).Position,
			Palette.BarkLight,
			WOOD
		)
	end
	if not spec or spec.collide ~= false then
		local delta = to - from
		Build.block(
			model,
			"Collider",
			Vector3.new(length + 0.7, height, 0.7),
			frame * Build.alongX((from + to) / 2 + up * height / 2, delta),
			Palette.Bark,
			WOOD,
			{ collide = true, transparency = 1 }
		)
	end
	model.Parent = parent
	return model
end

-- A log bench facing the base's +Z axis.
function Props.bench(parent: Instance?, base: CFrame, length: number?): Model
	local model = Build.model(nil, "Bench")
	local span = length or 7
	for _, side in { -1, 1 } do
		Build.post(
			model,
			"Leg",
			1.5,
			1.25,
			base * CFrame.new(side * (span / 2 - 1.1), 0, 0),
			Palette.BarkDeep,
			WOOD,
			{ collide = true }
		)
		Build.post(
			model,
			"BackPost",
			0.5,
			3.3,
			base * CFrame.new(side * (span / 2 - 0.7), 0, -1.15) * CFrame.Angles(math.rad(-9), 0, 0),
			Palette.BarkDeep,
			WOOD
		)
	end
	Build.block(
		model,
		"Seat",
		Vector3.new(span, 0.5, 2.4),
		base * CFrame.new(0, 1.5, 0),
		Palette.PlankLight,
		Enum.Material.WoodPlanks,
		{ collide = true }
	)
	Build.rod(
		model,
		"BackRail",
		0.7,
		point(base, -span / 2 + 0.2, 3.05, -1.62),
		point(base, span / 2 - 0.2, 3.05, -1.62),
		Palette.Plank,
		WOOD
	)
	Build.rod(
		model,
		"BackRail",
		0.5,
		point(base, -span / 2 + 0.4, 2.3, -1.5),
		point(base, span / 2 - 0.4, 2.3, -1.5),
		Palette.Plank,
		WOOD
	)
	model.Parent = parent
	return model
end

-- Rocks and trees ------------------------------------------------------------

function Props.boulder(parent: Instance?, base: CFrame, size: number, seed: number, mossy: boolean?): Model
	local model = Build.model(nil, "Boulder")
	local rng = Build.rng(seed)
	local count = if size > 3 then 3 else 2
	for index = 1, count do
		local scale = if index == 1 then 1 else rng.range(0.42, 0.66)
		local angle = rng.range(0, math.pi * 2)
		local distance = if index == 1 then 0 else size * rng.range(0.42, 0.6)
		local dimensions =
			Vector3.new(size * scale * rng.range(0.95, 1.25), size * scale * rng.range(0.6, 0.8), size * scale)
		Build.ellipsoid(
			model,
			"Rock",
			dimensions,
			base
				* CFrame.new(math.cos(angle) * distance, dimensions.Y * 0.28, math.sin(angle) * distance)
				* CFrame.Angles(math.rad(rng.range(-10, 10)), rng.range(0, math.pi), math.rad(rng.range(-10, 10))),
			Build.shade(Palette.Stone, rng.range(-0.14, 0.08)),
			Enum.Material.Slate,
			{ collide = index == 1 and size >= 3 }
		)
		if mossy ~= false and index == 1 then
			Build.ellipsoid(
				model,
				"Moss",
				Vector3.new(dimensions.X * 0.78, dimensions.Y * 0.5, dimensions.Z * 0.78),
				base * CFrame.new(0, dimensions.Y * 0.58, 0) * CFrame.Angles(0, rng.range(0, math.pi), 0),
				Build.shade(Palette.Moss, rng.range(-0.05, 0.1)),
				Enum.Material.Grass
			)
		end
	end
	model.Parent = parent
	return model
end

export type TreeSpec = { name: string?, height: number, trunk: number, canopy: number, seed: number, color: Color3? }

-- A round-crowned backdrop tree.
function Props.tree(parent: Instance?, base: CFrame, spec: TreeSpec): Model
	local model = Build.model(nil, spec.name or "Tree")
	local rng = Build.rng(spec.seed)
	local trunkTop = spec.height * 0.62
	Build.post(model, "TrunkBase", spec.trunk * 1.3, trunkTop * 0.45, base, Palette.BarkDeep, WOOD)
	Build.post(model, "Trunk", spec.trunk, trunkTop, base, Palette.BarkDeep, WOOD)
	local color = spec.color or Palette.Canopy
	local crowns = 4
	for index = 1, crowns do
		local centre = index == 1
		local angle = rng.range(0, math.pi * 2) + index * GOLDEN_ANGLE
		local distance = if centre then 0 else spec.canopy * rng.range(0.42, 0.62)
		local size = spec.canopy * (if centre then 1.5 else rng.range(0.9, 1.2))
		Build.ellipsoid(
			model,
			"Crown",
			Vector3.new(size, size * rng.range(0.66, 0.8), size),
			base
				* CFrame.new(
					math.cos(angle) * distance,
					trunkTop + (if centre then spec.canopy * 0.3 else rng.range(-0.12, 0.18) * spec.canopy),
					math.sin(angle) * distance
				),
			Build.shade(color, rng.range(-0.1, 0.1)),
			Enum.Material.Grass
		)
	end
	model.Parent = parent
	return model
end

-- A few glowing buds on thin stalks for lawn edges.
function Props.sporeBuds(parent: Instance?, base: CFrame, count: number, color: Color3, seed: number): Model
	local model = Build.model(nil, "SporeBuds")
	local rng = Build.rng(seed)
	for index = 1, count do
		local angle = rng.range(0, math.pi * 2)
		local distance = rng.range(0.2, 1.6) * math.sqrt(index)
		local height = rng.range(0.9, 2.1)
		local foot = base * CFrame.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
		Build.post(model, "Stalk", 0.16, height, foot, Palette.MossDeep, PLASTIC)
		Build.ball(model, "Bud", rng.range(0.38, 0.62), point(foot, 0, height + 0.15, 0), color, NEON)
	end
	model.Parent = parent
	return model
end

return Props
