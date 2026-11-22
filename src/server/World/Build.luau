-- Low-level construction helpers for the procedural lobby.
--
-- Everything is positioned through CFrame only and built from primitive parts,
-- so the same code produces the same geometry in Studio and in the headless
-- test harness.

local Build = {}

export type Options = {
	-- Collides with characters. Decorative parts leave this off.
	collide: boolean?,
	shadow: boolean?,
	transparency: number?,
	reflectance: number?,
}

export type Rng = {
	next: () -> number,
	range: (number, number) -> number,
	int: (number, number) -> number,
	pick: <T>({ T }) -> T,
	sign: () -> number,
	chance: (number) -> boolean,
}

local SMOOTH = Enum.SurfaceType.Smooth
-- Rotates a cylinder so its axis (local X) points along +Y.
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))
local SMALL_DETAIL = 2.6

Build.UPRIGHT = UPRIGHT

-- Lehmer generator. Roblox's Random is not reproducible outside the engine,
-- and the layout must not change between the preview and the real place.
function Build.rng(seed: number): Rng
	local state = (math.floor(seed) * 7919 + 104729) % 2147483646 + 1
	local function nextValue(): number
		state = (state * 48271) % 2147483647
		return state / 2147483647
	end
	for _ = 1, 4 do
		nextValue()
	end
	local rng = {}
	rng.next = nextValue
	function rng.range(low: number, high: number): number
		return low + (high - low) * nextValue()
	end
	function rng.int(low: number, high: number): number
		return math.min(high, math.floor(low + (high - low + 1) * nextValue()))
	end
	function rng.pick(list)
		return list[rng.int(1, #list)]
	end
	function rng.sign(): number
		return if nextValue() < 0.5 then -1 else 1
	end
	function rng.chance(probability: number): boolean
		return nextValue() < probability
	end
	return rng :: any
end

-- amount > 0 lightens, amount < 0 darkens.
function Build.shade(color: Color3, amount: number): Color3
	if amount >= 0 then
		return color:Lerp(Color3.new(1, 1, 1), amount)
	end
	return color:Lerp(Color3.new(0, 0, 0), -amount)
end

function Build.mix(a: Color3, b: Color3, alpha: number): Color3
	return a:Lerp(b, alpha)
end

function Build.folder(parent: Instance?, name: string): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

function Build.model(parent: Instance?, name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

-- A CFrame at `position` whose local X axis points along `xAxis`.
function Build.alongX(position: Vector3, xAxis: Vector3): CFrame
	local x = xAxis.Unit
	local hint = if math.abs(x.Y) > 0.95 then Vector3.new(0, 0, 1) else Vector3.new(0, 1, 0)
	local z = x:Cross(hint).Unit
	local y = z:Cross(x)
	return CFrame.new(position.X, position.Y, position.Z, x.X, y.X, z.X, x.Y, y.Y, z.Y, x.Z, y.Z, z.Z)
end

-- A CFrame at `position` whose local Y axis points along `yAxis`.
function Build.alongY(position: Vector3, yAxis: Vector3): CFrame
	local y = yAxis.Unit
	local hint = if math.abs(y.X) > 0.95 then Vector3.new(0, 0, 1) else Vector3.new(1, 0, 0)
	local z = hint:Cross(y).Unit
	local x = y:Cross(z)
	return CFrame.new(position.X, position.Y, position.Z, x.X, y.X, z.X, x.Y, y.Y, z.Y, x.Z, y.Z, z.Z)
end

local function finish(
	part: BasePart,
	parent: Instance?,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	options: Options?
)
	part.Name = name
	part.Anchored = true
	part.TopSurface = SMOOTH
	part.BottomSurface = SMOOTH
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material

	local collide = options ~= nil and options.collide == true
	part.CanCollide = collide
	part.CanTouch = false
	part.CanQuery = collide

	local transparency = if options and options.transparency then options.transparency else 0
	if transparency > 0 then
		part.Transparency = transparency
	end
	if options and options.reflectance then
		part.Reflectance = options.reflectance
	end

	local shadow = true
	if options and options.shadow ~= nil then
		shadow = options.shadow
	elseif
		transparency > 0
		or material == Enum.Material.Neon
		or math.max(size.X, size.Y, size.Z) < SMALL_DETAIL
		or math.min(size.X, size.Y, size.Z) < 0.2
	then
		shadow = false
	end
	if not shadow then
		part.CastShadow = false
	end

	part.Parent = parent
end

function Build.block(
	parent: Instance?,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	options: Options?
): Part
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Block
	finish(part, parent, name, size, cframe, color, material, options)
	return part
end

-- The slope rises toward the part's back (+Z) face.
function Build.wedge(
	parent: Instance?,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	options: Options?
): WedgePart
	local part = Instance.new("WedgePart")
	finish(part, parent, name, size, cframe, color, material, options)
	return part
end

function Build.ball(
	parent: Instance?,
	name: string,
	diameter: number,
	position: Vector3,
	color: Color3,
	material: Enum.Material,
	options: Options?
): Part
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Ball
	finish(
		part,
		parent,
		name,
		Vector3.new(diameter, diameter, diameter),
		CFrame.new(position),
		color,
		material,
		options
	)
	return part
end

-- An ellipsoid filling `size`: a block part carrying a sphere mesh.
function Build.ellipsoid(
	parent: Instance?,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	options: Options?
): Part
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Block
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	finish(part, parent, name, size, cframe, color, material, options)
	return part
end

-- A cylinder whose axis is the local X axis of `cframe`.
function Build.cylinder(
	parent: Instance?,
	name: string,
	diameter: number,
	length: number,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	options: Options?
): Part
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Cylinder
	finish(part, parent, name, Vector3.new(length, diameter, diameter), cframe, color, material, options)
	return part
end

-- An upright cylinder standing on `base` (its local Y is the axis).
function Build.post(
	parent: Instance?,
	name: string,
	diameter: number,
	height: number,
	base: CFrame,
	color: Color3,
	material: Enum.Material,
	options: Options?
): Part
	return Build.cylinder(
		parent,
		name,
		diameter,
		height,
		base * CFrame.new(0, height / 2, 0) * UPRIGHT,
		color,
		material,
		options
	)
end

-- A cylinder between two points. `overlap` extends both ends so chained
-- segments close their joints.
function Build.rod(
	parent: Instance?,
	name: string,
	diameter: number,
	from: Vector3,
	to: Vector3,
	color: Color3,
	material: Enum.Material,
	options: Options?,
	overlap: number?
): Part
	local delta = to - from
	local length = delta.Magnitude + 2 * (overlap or 0)
	return Build.cylinder(
		parent,
		name,
		diameter,
		length,
		Build.alongX((from + to) / 2, delta),
		color,
		material,
		options
	)
end

-- A rectangular beam between two points (width across, thickness up).
function Build.beam(
	parent: Instance?,
	name: string,
	width: number,
	thickness: number,
	from: Vector3,
	to: Vector3,
	color: Color3,
	material: Enum.Material,
	options: Options?
): Part
	local delta = to - from
	return Build.block(
		parent,
		name,
		Vector3.new(delta.Magnitude, thickness, width),
		Build.alongX((from + to) / 2, delta),
		color,
		material,
		options
	)
end

function Build.light(parent: Instance, color: Color3, range: number, brightness: number, shadows: boolean?): PointLight
	local light = Instance.new("PointLight")
	light.Name = "Light"
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = shadows == true
	light.Parent = parent
	return light
end

-- Slow drifting motes. Uses the engine's built-in particle texture.
function Build.spores(parent: Instance, color: Color3, rate: number, spread: number?): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Spores"
	emitter.Rate = rate
	emitter.Lifetime = NumberRange.new(5, 9)
	emitter.Speed = NumberRange.new(0.4, 1.4)
	emitter.SpreadAngle = Vector2.new(spread or 55, spread or 55)
	emitter.Acceleration = Vector3.new(0, 0.25, 0)
	emitter.Drag = 0.4
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-25, 25)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.25, 0.45),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 0.9
	emitter.LightInfluence = 0
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Parent = parent
	return emitter
end

export type GuiOptions = {
	name: string?,
	face: Enum.NormalId?,
	pixelsPerStud: number?,
	lightInfluence: number?,
	brightness: number?,
}

function Build.surfaceGui(part: BasePart, options: GuiOptions?): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = if options and options.name then options.name else "Gui"
	gui.Face = if options and options.face then options.face else Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = if options and options.pixelsPerStud then options.pixelsPerStud else 50
	-- Signs stay readable in shadow and at dusk.
	gui.LightInfluence = if options and options.lightInfluence then options.lightInfluence else 0.15
	gui.Brightness = if options and options.brightness then options.brightness else 1
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.ResetOnSpawn = false
	gui.Parent = part
	return gui
end

export type FrameProps = {
	name: string?,
	size: UDim2?,
	position: UDim2?,
	anchor: Vector2?,
	color: Color3?,
	transparency: number?,
	corner: UDim?,
	strokeColor: Color3?,
	strokeThickness: number?,
	zIndex: number?,
}

function Build.frame(parent: Instance, props: FrameProps): Frame
	local frame = Instance.new("Frame")
	frame.Name = props.name or "Frame"
	frame.Size = props.size or UDim2.fromScale(1, 1)
	frame.Position = props.position or UDim2.new()
	frame.AnchorPoint = props.anchor or Vector2.new(0, 0)
	frame.BorderSizePixel = 0
	if props.color then
		frame.BackgroundColor3 = props.color
		frame.BackgroundTransparency = props.transparency or 0
	else
		frame.BackgroundTransparency = 1
	end
	frame.ZIndex = props.zIndex or 1
	if props.corner then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = props.corner
		corner.Parent = frame
	end
	if props.strokeColor then
		local stroke = Instance.new("UIStroke")
		stroke.Color = props.strokeColor
		stroke.Thickness = props.strokeThickness or 2
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = frame
	end
	frame.Parent = parent
	return frame
end

export type LabelProps = {
	name: string?,
	text: string,
	font: Font,
	color: Color3,
	size: UDim2?,
	position: UDim2?,
	anchor: Vector2?,
	alignX: Enum.TextXAlignment?,
	alignY: Enum.TextYAlignment?,
	zIndex: number?,
}

-- Scaled text that always fits its box.
function Build.label(parent: Instance, props: LabelProps): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = props.name or "Label"
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Size = props.size or UDim2.fromScale(1, 1)
	label.Position = props.position or UDim2.new()
	label.AnchorPoint = props.anchor or Vector2.new(0, 0)
	label.FontFace = props.font
	label.Text = props.text
	label.TextColor3 = props.color
	label.TextScaled = true
	label.TextWrapped = true
	label.TextXAlignment = props.alignX or Enum.TextXAlignment.Center
	label.TextYAlignment = props.alignY or Enum.TextYAlignment.Center
	label.ZIndex = props.zIndex or 2
	label.Parent = parent
	return label
end

function Build.countParts(root: Instance): number
	local count = 0
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") then
			count += 1
		end
	end
	return count
end

return Build
