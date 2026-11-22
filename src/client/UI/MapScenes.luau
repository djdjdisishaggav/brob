--!strict
-- Small original dioramas for the chapter preview in the Create Party panel.
-- Each scene is built from plain parts (no uploaded assets) around the origin,
-- about 30 studs across, and is meant to be shown in a ViewportFrame.
--
-- Colours come from the UI theme so the previews match the rest of the lobby.
-- Parts are placed with CFrame only.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("MushroomLobby")

local Theme = require(Shared.Theme)

local Color = Theme.Color

export type Backdrop = {
	-- Gradient drawn behind the ViewportFrame.
	SkyTop: Color3,
	SkyBottom: Color3,
	-- ViewportFrame lighting.
	Ambient: Color3,
	LightColor: Color3,
	LightDirection: Vector3,
}

local MapScenes = {}

MapScenes.Default = "Grove"

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

--------------------------------------------------------------------------------
-- Part helpers
--------------------------------------------------------------------------------

local function finish(
	part: BasePart,
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material
)
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Parent = parent
end

local function block(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Block
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	finish(part, parent, name, size, cframe, color, material)
	return part
end

local function ball(
	parent: Instance,
	name: string,
	diameter: number,
	position: Vector3,
	color: Color3,
	material: Enum.Material
): Part
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Ball
	finish(part, parent, name, Vector3.new(diameter, diameter, diameter), CFrame.new(position), color, material)
	return part
end

-- An ellipsoid filling `size`: a block carrying a sphere mesh.
local function ellipsoid(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Block
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	finish(part, parent, name, size, cframe, color, material)
	return part
end

-- An upright cylinder whose bottom face is centred on `base`.
local function post(
	parent: Instance,
	name: string,
	diameter: number,
	height: number,
	base: Vector3,
	color: Color3,
	material: Enum.Material
): Part
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Cylinder
	local cframe = CFrame.new(base + Vector3.new(0, height / 2, 0)) * UPRIGHT
	finish(part, parent, name, Vector3.new(height, diameter, diameter), cframe, color, material)
	return part
end

-- A cylinder running from `from` to `to`. Not for exactly vertical runs (use post).
local function limb(
	parent: Instance,
	name: string,
	from: Vector3,
	to: Vector3,
	diameter: number,
	color: Color3,
	material: Enum.Material
): Part
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Cylinder
	local length = (to - from).Magnitude
	-- lookAt points -Z at the target; a quarter turn puts the cylinder's X axis there.
	local cframe = CFrame.lookAt(from:Lerp(to, 0.5), to) * CFrame.Angles(0, math.rad(90), 0)
	finish(part, parent, name, Vector3.new(length, diameter, diameter), cframe, color, material)
	return part
end

local function wedge(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material
): WedgePart
	local part = Instance.new("WedgePart")
	finish(part, parent, name, size, cframe, color, material)
	return part
end

local function glow(part: BasePart, color: Color3, range: number, brightness: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = part
end

-- Stem, gill disc, cap and spots. `spots` are unit-ish directions from the cap centre.
local function mushroom(
	parent: Instance,
	name: string,
	base: Vector3,
	stemDiameter: number,
	stemHeight: number,
	capSize: Vector3,
	capColor: Color3,
	capMaterial: Enum.Material,
	stemColor: Color3,
	spotColor: Color3?,
	spots: { Vector3 }?
)
	post(parent, name .. "Stem", stemDiameter, stemHeight, base, stemColor, Enum.Material.SmoothPlastic)
	local capCentre = base + Vector3.new(0, stemHeight + capSize.Y * 0.12, 0)
	post(
		parent,
		name .. "Gills",
		capSize.X * 0.8,
		capSize.Y * 0.1,
		capCentre - Vector3.new(0, capSize.Y * 0.2, 0),
		stemColor:Lerp(capColor, 0.25),
		Enum.Material.SmoothPlastic
	)
	ellipsoid(parent, name .. "Cap", capSize, CFrame.new(capCentre), capColor, capMaterial)
	if spots and spotColor then
		local spotSize = math.max(0.5, capSize.X * 0.16)
		for index, direction in spots do
			local unit = direction.Unit
			local offset = Vector3.new(unit.X * capSize.X, unit.Y * capSize.Y, unit.Z * capSize.Z) * 0.46
			ellipsoid(
				parent,
				`{name}Spot{index}`,
				Vector3.new(spotSize, spotSize * 0.7, spotSize),
				CFrame.new(capCentre + offset),
				spotColor,
				Enum.Material.SmoothPlastic
			)
		end
	end
end

local function spores(parent: Instance, color: Color3, positions: { Vector3 })
	for index, position in positions do
		ball(parent, `Spore{index}`, 0.3 + (index % 3) * 0.1, position, color, Enum.Material.Neon)
	end
end

local function ground(parent: Instance, color: Color3, material: Enum.Material)
	post(parent, "Ground", 38, 1, Vector3.new(0, -1, 0), color, material)
end

--------------------------------------------------------------------------------
-- Grove: a lantern-lit clearing with giant mushrooms
--------------------------------------------------------------------------------

local function buildGrove(model: Model)
	local grass, plastic, wood = Enum.Material.Grass, Enum.Material.SmoothPlastic, Enum.Material.Wood
	local stem = Color.Parchment200

	ground(model, Color.Moss700, grass)
	post(model, "Clearing", 21, 0.2, Vector3.new(-0.5, -0.05, 2), Color.Moss600, grass)

	local stones = {
		{ Vector3.new(3.2, 0, 13), 2.8 },
		{ Vector3.new(1.4, 0, 10), 2.4 },
		{ Vector3.new(-0.2, 0, 7.2), 2.6 },
		{ Vector3.new(-1.4, 0, 4.6), 2.2 },
	}
	for index, stone in stones do
		post(model, `PathStone{index}`, stone[2] :: number, 0.3, stone[1] :: Vector3, Color.Parchment400, Enum.Material.Slate)
	end

	-- Lantern post with a cap-shaped roof.
	local postBase = Vector3.new(-3.4, 0, 2)
	local lantern = postBase + Vector3.new(2.3, 0, 0)
	post(model, "PostFoot", 1.9, 0.6, postBase, Color.Stone500, Enum.Material.Slate)
	post(model, "Post", 0.7, 8, postBase + Vector3.new(0, 0.6, 0), Color.Bark500, wood)
	block(model, "PostArm", Vector3.new(3, 0.45, 0.45), CFrame.new(postBase + Vector3.new(1.15, 8.2, 0)), Color.Bark500, wood)
	block(
		model,
		"PostBrace",
		Vector3.new(1.7, 0.3, 0.3),
		CFrame.new(postBase + Vector3.new(0.65, 7.5, 0)) * CFrame.Angles(0, 0, math.rad(45)),
		Color.Bark600,
		wood
	)
	block(model, "LanternChain", Vector3.new(0.14, 0.9, 0.14), CFrame.new(lantern + Vector3.new(0, 7.6, 0)), Color.Bark900, plastic)
	ellipsoid(model, "LanternRoof", Vector3.new(1.9, 0.9, 1.9), CFrame.new(lantern + Vector3.new(0, 7.05, 0)), Color.Cap600, plastic)
	local flame = block(
		model,
		"LanternGlow",
		Vector3.new(1.05, 1.3, 1.05),
		CFrame.new(lantern + Vector3.new(0, 6.15, 0)),
		Color.Amber400,
		Enum.Material.Neon
	)
	glow(flame, Color.Amber300, 22, 2)
	block(model, "LanternFoot", Vector3.new(1.3, 0.2, 1.3), CFrame.new(lantern + Vector3.new(0, 5.4, 0)), Color.Bark700, wood)

	-- Giant mushrooms: a red hero cap, an amber one behind the lantern, small ones up front.
	mushroom(
		model,
		"Hero",
		Vector3.new(7, 0, -4),
		2.6,
		9,
		Vector3.new(13, 5.6, 13),
		Color.Cap500,
		plastic,
		stem,
		Color.Parchment100,
		{ Vector3.new(0.15, 0.62, 0.77), Vector3.new(-0.6, 0.5, 0.62), Vector3.new(0.72, 0.42, 0.55), Vector3.new(-0.15, 0.95, 0.2) }
	)
	mushroom(
		model,
		"Elder",
		Vector3.new(-9.5, 0, -6),
		1.9,
		6.4,
		Vector3.new(9, 4, 9),
		Color.Amber500,
		plastic,
		stem,
		Color.Amber300,
		{ Vector3.new(0.3, 0.6, 0.74), Vector3.new(-0.5, 0.55, 0.67), Vector3.new(0.05, 0.95, 0.3) }
	)
	mushroom(
		model,
		"Young",
		Vector3.new(11, 0, 6),
		1.1,
		2.8,
		Vector3.new(5, 2.3, 5),
		Color.Cap400,
		plastic,
		stem,
		Color.Parchment100,
		{ Vector3.new(0.3, 0.7, 0.65), Vector3.new(-0.5, 0.6, 0.62) }
	)
	mushroom(model, "SproutA", Vector3.new(-11, 0, 6.5), 0.6, 1.5, Vector3.new(2.4, 1.2, 2.4), Color.Cap500, plastic, stem)
	mushroom(model, "SproutB", Vector3.new(-9.4, 0, 8), 0.5, 1, Vector3.new(1.8, 0.9, 1.8), Color.Amber400, plastic, stem)

	-- Dark trees close the clearing at the back.
	local trees = {
		{ Vector3.new(-15, 0, -9), 2.4, Vector3.new(-15, 15.5, -9), 9.5, Vector3.new(-11.5, 13.5, -10.5), 7 },
		{ Vector3.new(-2.5, 0, -14.5), 2, Vector3.new(-2.5, 15, -14.5), 10, Vector3.new(1.5, 13, -15.5), 7 },
		{ Vector3.new(15, 0, -10), 2.6, Vector3.new(14.5, 16, -10), 9.5, Vector3.new(11.5, 14.5, -12), 6.5 },
	}
	for index, tree in trees do
		post(model, `Trunk{index}`, tree[2] :: number, 16, tree[1] :: Vector3, Color.Bark800, wood)
		ball(model, `Canopy{index}A`, tree[4] :: number, tree[3] :: Vector3, Color.Moss800, grass)
		ball(model, `Canopy{index}B`, tree[6] :: number, tree[5] :: Vector3, Color.Moss700, grass)
	end

	-- Small lanterns strung between the trees.
	local strung = { Vector3.new(-6.5, 10, -9), Vector3.new(2.6, 11, -11.5) }
	for index, position in strung do
		block(model, `String{index}`, Vector3.new(0.1, 2.4, 0.1), CFrame.new(position + Vector3.new(0, 1.6, 0)), Color.Bark900, plastic)
		ball(model, `Strung{index}`, 0.95, position, Color.Amber400, Enum.Material.Neon)
	end

	ball(model, "RockA", 2.3, Vector3.new(4.6, 0.5, 7.2), Color.Stone500, Enum.Material.Slate)
	ball(model, "RockB", 1.5, Vector3.new(5.9, 0.3, 8.2), Color.Stone400, Enum.Material.Slate)
	ball(model, "RockC", 2, Vector3.new(-13, 0.5, 1.5), Color.Stone500, Enum.Material.Slate)

	local tufts = {
		Vector3.new(-6, 0.5, 9.5),
		Vector3.new(7.5, 0.5, 10.5),
		Vector3.new(1.5, 0.5, 2.5),
		Vector3.new(-7.5, 0.5, 0.5),
		Vector3.new(12.5, 0.5, 0.5),
	}
	for index, position in tufts do
		wedge(
			model,
			`Tuft{index}`,
			Vector3.new(0.35, 1.1, 0.9),
			CFrame.new(position) * CFrame.Angles(0, index * 1.3, 0),
			Color.Moss400,
			grass
		)
	end

	spores(model, Color.Amber300, {
		Vector3.new(-5.5, 4, 5),
		Vector3.new(2.5, 6.5, 4),
		Vector3.new(5, 3, 9),
		Vector3.new(-9, 7.5, 1),
		Vector3.new(10.5, 8.5, 2),
		Vector3.new(-1.5, 9.5, -3),
		Vector3.new(0.5, 2.5, 8.5),
	})
end

--------------------------------------------------------------------------------
-- Cavern: dark rock, teal and violet crystals, glowing caps
--------------------------------------------------------------------------------

-- A cluster of leaning neon shards. Each entry: offset, height, thickness, lean in degrees.
local function crystals(parent: Instance, name: string, base: Vector3, color: Color3, shards: { { number } })
	for index, shard in shards do
		local height, thickness = shard[3], shard[4]
		local cframe = CFrame.new(base + Vector3.new(shard[1], 0, shard[2]))
			* CFrame.Angles(math.rad(shard[6] or 0), math.rad(45), math.rad(shard[5]))
			* CFrame.new(0, height / 2 - 0.3, 0)
		local part = block(
			parent,
			`{name}Shard{index}`,
			Vector3.new(thickness, height, thickness),
			cframe,
			color,
			Enum.Material.Neon
		)
		if index == 1 then
			glow(part, color, 18, 1.6)
		end
	end
end

local function buildCavern(model: Model)
	local slate, plastic = Enum.Material.Slate, Enum.Material.SmoothPlastic
	local rockDark = Color.Stone700:Lerp(Color.Crystal700, 0.18)
	local rockMid = Color.Stone600:Lerp(Color.Crystal700, 0.22)
	local rockLight = Color.Stone500:Lerp(Color.Crystal600, 0.2)

	ground(model, rockDark, slate)

	-- Still pool in the middle of the chamber.
	local pool = Vector3.new(-1, 0, 4)
	post(model, "PoolBed", 11.5, 0.16, pool - Vector3.new(0, 0.04, 0), Color.Spore700, plastic)
	post(model, "PoolGlow", 8.5, 0.1, pool + Vector3.new(0.4, 0.1, 0.2), Color.Spore500, Enum.Material.Neon)
	local rim = { { 5.6, 1, 1.9 }, { -5.9, 0.2, 2.2 }, { 3.4, -4.6, 1.6 }, { -3.2, 4.9, 1.7 }, { -4.8, -3.6, 1.4 } }
	for index, stone in rim do
		ball(model, `PoolStone{index}`, stone[3], pool + Vector3.new(stone[1], 0.3, stone[2]), rockLight, slate)
	end

	-- Chamber walls, a rock shelf and an overhang.
	local walls: { { any } } = {
		{ Vector3.new(12, 22, 6), CFrame.new(-12, 10, -12.5) * CFrame.Angles(0, math.rad(20), math.rad(4)), rockMid },
		{ Vector3.new(12, 24, 6), CFrame.new(-1.5, 11, -15.5) * CFrame.Angles(0, math.rad(-4), 0), rockDark },
		{ Vector3.new(12, 22, 6), CFrame.new(10, 10, -13) * CFrame.Angles(0, math.rad(-22), math.rad(-5)), rockMid },
		{ Vector3.new(6, 20, 12), CFrame.new(-18, 9, -3) * CFrame.Angles(0, math.rad(32), 0), rockDark },
		{ Vector3.new(6, 20, 12), CFrame.new(18, 9, -3) * CFrame.Angles(0, math.rad(-32), 0), rockDark },
		{ Vector3.new(9, 2.6, 5.5), CFrame.new(8.5, 1.3, -8) * CFrame.Angles(0, math.rad(-12), 0), rockLight },
		{ Vector3.new(34, 4, 12), CFrame.new(0, 20.5, -9) * CFrame.Angles(math.rad(10), 0, 0), rockDark },
	}
	for index, wall in walls do
		block(model, `Rock{index}`, wall[1], wall[2], wall[3], slate)
	end

	local stalactites = { { -10, 17.5, -7, 6 }, { -5, 18, -9, 4.5 }, { 1.5, 17.6, -6.5, 7 }, { 6.5, 18, -9, 4 }, { 11.5, 17.4, -6.5, 5.5 } }
	for index, spike in stalactites do
		ellipsoid(
			model,
			`Stalactite{index}`,
			Vector3.new(1.7, spike[4], 1.7),
			CFrame.new(spike[1], spike[2], spike[3]),
			rockMid,
			slate
		)
	end
	local stalagmites = { { -14, -1, 5 }, { -6.5, -9, 6.5 }, { 14.5, -6, 6 }, { 15, 5.5, 4 }, { 1.5, -10.5, 4.5 } }
	for index, spike in stalagmites do
		ellipsoid(
			model,
			`Stalagmite{index}`,
			Vector3.new(2.2, spike[3] * 2, 2.2),
			CFrame.new(spike[1], 0, spike[2]),
			rockLight,
			slate
		)
	end

	crystals(model, "Teal", Vector3.new(-9.5, 0, -2.5), Color.Spore400, {
		{ 0, 0, 6.5, 1.5, 8 },
		{ 1.4, 0.6, 4.4, 1.1, -22 },
		{ -1.3, 0.4, 3.4, 1, 26 },
		{ 0.3, 1.5, 2.4, 0.8, -8, 24 },
	})
	crystals(model, "Violet", Vector3.new(8.5, 2.6, -8), Color.Crystal400, {
		{ 0, 0, 6, 1.4, -6 },
		{ -1.5, 0.5, 4.2, 1.1, 24 },
		{ 1.6, 0.3, 3.6, 1, -28 },
		{ 0.2, 1.4, 2.4, 0.8, 10, 26 },
	})
	crystals(model, "Shard", Vector3.new(12.5, 0, 3.5), Color.Spore400, {
		{ 0, 0, 3.6, 1, -10 },
		{ 1, 0.6, 2.4, 0.8, 22 },
		{ -0.9, 0.5, 2, 0.7, -30 },
	})
	crystals(model, "Bloom", Vector3.new(-12.5, 0, 6), Color.Crystal400, {
		{ 0, 0, 3.2, 0.9, 12 },
		{ 0.9, 0.5, 2.2, 0.7, -24 },
	})

	local capStem = Color.Stone300
	mushroom(model, "GlowA", Vector3.new(4, 0, 0.5), 0.9, 3.3, Vector3.new(4.4, 1.9, 4.4), Color.Spore300, Enum.Material.Neon, capStem)
	mushroom(model, "GlowB", Vector3.new(6.2, 0, 2.4), 0.7, 2, Vector3.new(2.9, 1.3, 2.9), Color.Spore400, Enum.Material.Neon, capStem)
	mushroom(model, "GlowC", Vector3.new(-5, 0, -7), 1, 4.2, Vector3.new(5, 2.1, 5), Color.Crystal300, Enum.Material.Neon, capStem)
	mushroom(model, "GlowD", Vector3.new(-2.8, 0, -8.4), 0.7, 2.3, Vector3.new(2.8, 1.2, 2.8), Color.Spore300, Enum.Material.Neon, capStem)

	spores(model, Color.Spore300, {
		Vector3.new(-3, 5, 6),
		Vector3.new(2.5, 7.5, 2),
		Vector3.new(7.5, 5.5, 5),
		Vector3.new(-7.5, 9, 1.5),
		Vector3.new(0, 10.5, -3),
		Vector3.new(-12, 6.5, 2),
	})
end

--------------------------------------------------------------------------------
-- Sanctum: elder-tree roots around an amber heart-lantern
--------------------------------------------------------------------------------

local function buildSanctum(model: Model)
	local wood, plastic, neon = Enum.Material.Wood, Enum.Material.SmoothPlastic, Enum.Material.Neon

	ground(model, Color.Bark800, Enum.Material.Slate)
	local moss: { { any } } = {
		{ Vector3.new(9, 0.5, 6.5), Vector3.new(-7, 0, 5), Color.Moss700 },
		{ Vector3.new(7.5, 0.5, 5.5), Vector3.new(8.5, 0, 7), Color.Moss600 },
		{ Vector3.new(6, 0.5, 4.5), Vector3.new(-13, 0, -2), Color.Moss600 },
		{ Vector3.new(6.5, 0.5, 4.5), Vector3.new(13.5, 0, -1.5), Color.Moss700 },
	}
	for index, patch in moss do
		ellipsoid(model, `Moss{index}`, patch[1], CFrame.new(patch[2]), patch[3], Enum.Material.Grass)
	end

	-- The elder trunk fills the back of the frame; its hollow sits behind the lantern.
	post(model, "Trunk", 13, 26, Vector3.new(0, 0, -11), Color.Bark600, wood)
	post(model, "ButtressLeft", 5.5, 24, Vector3.new(-6.2, 0, -8.6), Color.Bark500, wood)
	post(model, "ButtressRight", 5, 24, Vector3.new(6.4, 0, -8.9), Color.Bark500, wood)
	ellipsoid(model, "Hollow", Vector3.new(6, 10.5, 1.6), CFrame.new(0, 5.6, -4.6), Color.Bark950, plastic)

	-- Roots pour out of the trunk and curl forward round the clearing.
	local roots: { { any } } = {
		{ Vector3.new(-4.5, 6.5, -5.5), Vector3.new(-9.5, 1.2, 0.5), Vector3.new(-7.5, 0.5, 9), 2.5 },
		{ Vector3.new(4.5, 7, -5.5), Vector3.new(10, 1.2, 1), Vector3.new(8, 0.5, 9.5), 2.5 },
		{ Vector3.new(-5.5, 4.5, -7), Vector3.new(-14, 0.9, -3), Vector3.new(-17, 0.3, 4), 2 },
		{ Vector3.new(5.5, 4.5, -7), Vector3.new(14, 0.9, -2.5), Vector3.new(17, 0.3, 4.5), 2 },
	}
	for index, root in roots do
		local diameter = root[4] :: number
		local color = if index <= 2 then Color.Bark500 else Color.Bark600
		limb(model, `Root{index}Upper`, root[1], root[2], diameter, color, wood)
		ball(model, `Root{index}Knee`, diameter * 1.08, root[2], color, wood)
		limb(model, `Root{index}Lower`, root[2], root[3], diameter * 0.78, color, wood)
	end

	-- Heart-lantern on a stone dais, held by three small roots and hung from the trunk.
	local dais = Vector3.new(0, 0, 2)
	local heart = dais + Vector3.new(0, 4.5, 0)
	post(model, "DaisLower", 6.2, 0.8, dais, Color.Stone500, Enum.Material.Slate)
	post(model, "DaisUpper", 4.4, 0.8, dais + Vector3.new(0, 0.8, 0), Color.Stone400, Enum.Material.Slate)
	limb(model, "ClawLeft", dais + Vector3.new(-1.5, 1.5, 0.3), heart + Vector3.new(-2.3, -0.4, 0.2), 0.6, Color.Bark500, wood)
	limb(model, "ClawRight", dais + Vector3.new(1.5, 1.5, 0.3), heart + Vector3.new(2.3, -0.4, 0.2), 0.6, Color.Bark500, wood)
	limb(model, "ClawBack", dais + Vector3.new(0, 1.5, -1.4), heart + Vector3.new(0.2, -0.2, -2.1), 0.6, Color.Bark600, wood)
	local lobe = ball(model, "HeartLobeLeft", 2.4, heart + Vector3.new(-0.86, 0.75, 0), Color.Amber400, neon)
	ball(model, "HeartLobeRight", 2.4, heart + Vector3.new(0.86, 0.75, 0), Color.Amber400, neon)
	block(
		model,
		"HeartPoint",
		Vector3.new(2.25, 2.25, 1.8),
		CFrame.new(heart + Vector3.new(0, -0.15, 0)) * CFrame.Angles(0, 0, math.rad(45)),
		Color.Amber400,
		neon
	)
	glow(lobe, Color.Amber300, 26, 2.4)
	limb(model, "HeartVine", heart + Vector3.new(0, 1.7, 0), Vector3.new(0.8, 13, -3.5), 0.45, Color.Bark700, wood)

	-- Thin roots hang from above, some still carrying a lantern bud.
	local hanging = { { -8.5, 3, 7, true }, { -4.5, 0, 4.5, false }, { 5.5, 1, 6, true }, { 10, 3.5, 4, false }, { 13, -1, 6.5, true } }
	for index, vine in hanging do
		local x, z, length = vine[1] :: number, vine[2] :: number, vine[3] :: number
		post(model, `Vine{index}`, 0.4, length, Vector3.new(x, 19 - length, z), Color.Bark700, wood)
		if vine[4] then
			ball(model, `Bud{index}`, 0.9, Vector3.new(x, 18.7 - length, z), Color.Amber400, neon)
		end
	end

	mushroom(model, "CapA", Vector3.new(-11.5, 0, 7), 0.6, 1.6, Vector3.new(2.6, 1.3, 2.6), Color.Amber500, plastic, Color.Parchment200)
	mushroom(model, "CapB", Vector3.new(12, 0, 6.5), 0.7, 2, Vector3.new(3, 1.4, 3), Color.Amber500, plastic, Color.Parchment200)
	mushroom(model, "CapC", Vector3.new(5, 0, 11), 0.5, 1.1, Vector3.new(2, 1, 2), Color.Amber400, plastic, Color.Parchment200)

	ball(model, "RockA", 2.2, Vector3.new(-4.5, 0.4, 8), Color.Stone600, Enum.Material.Slate)
	ball(model, "RockB", 1.5, Vector3.new(-3, 0.3, 9.2), Color.Stone500, Enum.Material.Slate)
	ball(model, "RockC", 1.9, Vector3.new(15, 0.4, 9), Color.Stone600, Enum.Material.Slate)

	spores(model, Color.Amber300, {
		Vector3.new(-3.5, 6.5, 5),
		Vector3.new(3, 8, 4.5),
		Vector3.new(-6.5, 3.5, 7.5),
		Vector3.new(6.5, 4, 8),
		Vector3.new(-1.5, 9.5, 1),
		Vector3.new(2, 2.6, 7.5),
		Vector3.new(-10, 9, 3),
	})
end

--------------------------------------------------------------------------------
-- Catalogue
--------------------------------------------------------------------------------

type Scene = {
	build: (model: Model) -> (),
	camera: CFrame,
	fieldOfView: number,
	backdrop: Backdrop,
}

-- Light travels away from the camera (which sits on +Z) and downwards.
local FRONT_LIGHT = Vector3.new(-0.5, -1, -0.75)

local SCENES: { [string]: Scene } = {
	Grove = {
		build = buildGrove,
		camera = CFrame.lookAt(Vector3.new(0, 9.5, 34), Vector3.new(0, 5.6, 0)),
		fieldOfView = 36,
		backdrop = {
			SkyTop = Color.Spore700:Lerp(Color.Bark900, 0.45),
			SkyBottom = Color.Amber600:Lerp(Color.Moss600, 0.45),
			Ambient = Color.Parchment400:Lerp(Color.Moss400, 0.3),
			LightColor = Color.Amber300,
			LightDirection = FRONT_LIGHT,
		},
	},
	Cavern = {
		build = buildCavern,
		camera = CFrame.lookAt(Vector3.new(0, 8, 33), Vector3.new(0, 6.6, 0)),
		fieldOfView = 38,
		backdrop = {
			SkyTop = Color.Bark950,
			SkyBottom = Color.Crystal700:Lerp(Color.Bark950, 0.5),
			Ambient = Color.Stone400:Lerp(Color.Crystal500, 0.35),
			LightColor = Color.Spore300,
			LightDirection = FRONT_LIGHT,
		},
	},
	Sanctum = {
		build = buildSanctum,
		camera = CFrame.lookAt(Vector3.new(0, 8.5, 32), Vector3.new(0, 6.2, 0)),
		fieldOfView = 38,
		backdrop = {
			SkyTop = Color.Bark900,
			SkyBottom = Color.Amber700:Lerp(Color.Bark800, 0.4),
			Ambient = Color.Parchment400:Lerp(Color.Amber500, 0.2),
			LightColor = Color.Amber300,
			LightDirection = FRONT_LIGHT,
		},
	},
}

MapScenes.Names = { "Grove", "Cavern", "Sanctum" }

local function resolve(sceneName: string): (Scene, string)
	local scene = SCENES[sceneName]
	if scene then
		return scene, sceneName
	end
	return SCENES[MapScenes.Default], MapScenes.Default
end

-- Builds a fresh, unparented copy of the diorama and returns it with the camera
-- CFrame to view it from and the field of view. Unknown names give the Grove.
-- The scene is centred on the world Y axis, so the camera can orbit that axis.
function MapScenes.build(sceneName: string): (Model, CFrame, number)
	local scene, resolvedName = resolve(sceneName)
	local model = Instance.new("Model")
	model.Name = resolvedName .. "Scene"
	scene.build(model)
	return model, scene.camera, scene.fieldOfView
end

-- Sky gradient and ViewportFrame lighting that suit the scene.
function MapScenes.backdrop(sceneName: string): Backdrop
	local scene = resolve(sceneName)
	return scene.backdrop
end

return MapScenes
