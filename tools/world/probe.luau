-- Temporary capability probe (deleted before hand-off).
local Harness = require("../harness")
local h = Harness.new()
local ctx = h:context("server")

local source = [[
local out = {}
local function try(label, fn)
	local ok, err = pcall(fn)
	table.insert(out, (ok and "ok   " or "FAIL ") .. label .. (ok and "" or (" -> " .. tostring(err))))
end

try("CFrame.fromMatrix", function() return CFrame.fromMatrix(Vector3.new(), Vector3.new(1,0,0), Vector3.new(0,1,0), Vector3.new(0,0,1)) end)
try("CFrame.lookAt", function() return CFrame.lookAt(Vector3.new(), Vector3.new(0,0,-1)) end)
try("CFrame 12", function() return CFrame.new(1,2,3, 1,0,0, 0,1,0, 0,0,1) end)
try("CFrame components", function() local a = { CFrame.new(1,2,3):GetComponents() } assert(#a == 12) end)
try("CFrame Angles mul", function() local c = CFrame.new(1,2,3) * CFrame.Angles(0, 0, math.rad(90)); assert(math.abs(c.XVector.Y - 1) < 1e-4, tostring(c.XVector)) end)
try("CFrame vec props", function() local c = CFrame.new(1,2,3); return c.XVector, c.YVector, c.ZVector, c.LookVector, c.RightVector, c.UpVector, c.Position, c.Rotation end)
try("CFrame inverse/pointToObjectSpace", function() local c = CFrame.new(1,2,3); return c:Inverse(), c:PointToObjectSpace(Vector3.new()), c:PointToWorldSpace(Vector3.new()), c:VectorToWorldSpace(Vector3.new()), c:ToWorldSpace(c) end)
try("Vector3 ops", function() local v = Vector3.new(1,2,3); return v.Unit, v.Magnitude, v:Cross(v), v:Dot(v), v:Lerp(v, 0.5), v * 2, v * v, -v end)
try("Color3 ops", function() local c = Color3.fromRGB(1,2,3); return c:Lerp(c, 0.5), c:ToHSV(), Color3.fromHSV(0.1,0.2,0.3), c.R, c:ToHex() end)
try("bit32", function() return bit32.bxor(1, 2), bit32.rshift(8, 1) end)
try("math.round/clamp/sign/noise", function() return math.round(1.5), math.clamp(1, 0, 2), math.sign(-1), math.noise(0.5, 0.5) end)
try("string.format", function() return string.format("%d %s", 1, "a"), `x{1}` end)
try("table lib", function() return table.create(4), table.clone({}), table.find({1}, 1), table.freeze({}) end)

try("Part props", function()
	local p = Instance.new("Part")
	p.Name = "P"
	p.Anchored = true
	p.Size = Vector3.new(1, 2, 3)
	p.CFrame = CFrame.new(1, 2, 3)
	p.Color = Color3.fromRGB(10, 20, 30)
	p.Material = Enum.Material.WoodPlanks
	p.Shape = Enum.PartType.Cylinder
	p.Transparency = 0.5
	p.Reflectance = 0.1
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Massless = true
	p.Locked = true
	p:SetAttribute("ZoneRadius", 9)
	assert(p:GetAttribute("ZoneRadius") == 9)
	assert(p:IsA("BasePart"))
	assert(p.Color.R > 0)
	assert(p.Shape == Enum.PartType.Cylinder)
	assert(p.Material == Enum.Material.WoodPlanks)
	assert(p.Size.Z == 3)
end)
try("Part shapes", function()
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Shape = Enum.PartType.Block
	p.Shape = Enum.PartType.Wedge
	p.Shape = Enum.PartType.CornerWedge
end)
for _, m in { "Wood", "WoodPlanks", "Grass", "LeafyGrass", "Ground", "Mud", "Slate", "Rock", "Cobblestone", "Basalt", "Sandstone", "Limestone", "Pebble", "Marble", "Glass", "Neon", "SmoothPlastic", "Fabric", "Ice", "Foil", "Brick", "Metal", "Sand", "Granite", "Concrete", "Pavement", "CrackedLava", "Plaster", "Cardboard", "Leather", "Carpet", "RoofShingles", "ClayRoofTiles", "DiamondPlate", "CorrodedMetal", "Salt", "Snow", "Glacier", "Asphalt" } do
	try("Material." .. m, function() local p = Instance.new("Part"); p.Material = Enum.Material[m] end)
end
try("WedgePart", function() local p = Instance.new("WedgePart"); p.Size = Vector3.new(1,2,3); p.Anchored = true end)
try("CornerWedgePart", function() local p = Instance.new("CornerWedgePart"); p.Size = Vector3.new(1,2,3) end)
try("TrussPart", function() local p = Instance.new("TrussPart"); p.Size = Vector3.new(2,6,2) end)
try("SpecialMesh", function()
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.Sphere
	m.Scale = Vector3.new(1, 0.5, 1)
	m.Offset = Vector3.new(0, 1, 0)
	assert(m.MeshType == Enum.MeshType.Sphere)
end)
try("SurfaceGui", function()
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Back
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 40
	g.LightInfluence = 0.2
	g.Brightness = 1.5
	g.AlwaysOnTop = false
	g.ResetOnSpawn = false
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	g.MaxDistance = 200
	g.ClipsDescendants = true
	g.Enabled = true
	g.Active = false
end)
try("SurfaceGui.CanvasSize", function() local g = Instance.new("SurfaceGui"); g.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize; g.CanvasSize = Vector2.new(800, 300) end)
try("SurfaceGui.Adornee", function() local g = Instance.new("SurfaceGui"); g.Adornee = Instance.new("Part") end)
try("BillboardGui", function()
	local g = Instance.new("BillboardGui")
	g.Size = UDim2.fromScale(4, 1)
	g.StudsOffset = Vector3.new(0, 2, 0)
	g.StudsOffsetWorldSpace = Vector3.new(0, 2, 0)
	g.AlwaysOnTop = false
	g.MaxDistance = 60
	g.LightInfluence = 0
	g.Brightness = 1
	g.ExtentsOffsetWorldSpace = Vector3.new()
end)
try("TextLabel", function()
	local t = Instance.new("TextLabel")
	t.Text = "SOLO"
	t.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextScaled = true
	t.TextSize = 40
	t.TextWrapped = true
	t.RichText = false
	t.BackgroundTransparency = 1
	t.BackgroundColor3 = Color3.new()
	t.BorderSizePixel = 0
	t.Size = UDim2.fromScale(1, 0.5)
	t.Position = UDim2.new(0.5, 0, 0, 4)
	t.AnchorPoint = Vector2.new(0.5, 0)
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextYAlignment = Enum.TextYAlignment.Center
	t.TextTransparency = 0
	t.TextStrokeTransparency = 1
	t.TextTruncate = Enum.TextTruncate.AtEnd
	t.ZIndex = 2
	t.LayoutOrder = 1
	t.Visible = true
	t.TextStrokeColor3 = Color3.new()
	t.LineHeight = 1
	t.MaxVisibleGraphemes = -1
	assert(t.Text == "SOLO")
end)
try("UI extras", function()
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8)
	local s = Instance.new("UIStroke"); s.Color = Color3.new(); s.Thickness = 2; s.Transparency = 0.2; s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local g = Instance.new("UIGradient"); g.Rotation = 90; g.Color = ColorSequence.new(Color3.new(), Color3.new(1,1,1)); g.Transparency = NumberSequence.new(0, 1)
	local p = Instance.new("UIPadding"); p.PaddingLeft = UDim.new(0, 4)
	local l = Instance.new("UIListLayout"); l.FillDirection = Enum.FillDirection.Horizontal; l.Padding = UDim.new(0, 4); l.HorizontalAlignment = Enum.HorizontalAlignment.Center; l.VerticalAlignment = Enum.VerticalAlignment.Center; l.SortOrder = Enum.SortOrder.LayoutOrder
	local t = Instance.new("UITextSizeConstraint"); t.MaxTextSize = 40; t.MinTextSize = 8
	local a = Instance.new("UIAspectRatioConstraint"); a.AspectRatio = 1
	local f = Instance.new("Frame"); f.BackgroundColor3 = Color3.new(); f.BackgroundTransparency = 0.5; f.BorderSizePixel = 0; f.Rotation = 45
end)
try("ProximityPrompt", function()
	local p = Instance.new("ProximityPrompt")
	p.ActionText = "Create Party"; p.ObjectText = "Solo Station"; p.RequiresLineOfSight = false; p.MaxActivationDistance = 10; p.HoldDuration = 0
	p.KeyboardKeyCode = Enum.KeyCode.E; p.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton; p.UIOffset = Vector2.new(0, 0); p.Enabled = true; p.Style = Enum.ProximityPromptStyle.Default
	p.GamepadKeyCode = Enum.KeyCode.ButtonX; p.ClickablePrompt = true
end)
try("SpawnLocation", function()
	local s = Instance.new("SpawnLocation")
	s.Neutral = true; s.Duration = 0; s.AllowTeamChangeOnTouch = false; s.Enabled = true; s.Anchored = true; s.Transparency = 1
	s.Shape = Enum.PartType.Cylinder
	assert(s:IsA("BasePart"))
end)
try("Lights", function()
	local p = Instance.new("PointLight"); p.Brightness = 1; p.Range = 16; p.Color = Color3.new(1, 1, 1); p.Shadows = false; p.Enabled = true
	local s = Instance.new("SpotLight"); s.Angle = 90; s.Face = Enum.NormalId.Bottom; s.Range = 20; s.Brightness = 2
	local f = Instance.new("SurfaceLight"); f.Angle = 90; f.Face = Enum.NormalId.Top; f.Range = 20
end)
try("ParticleEmitter", function()
	local e = Instance.new("ParticleEmitter")
	e.Rate = 4; e.Lifetime = NumberRange.new(4, 7); e.Speed = NumberRange.new(0.5, 1.5)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.4), NumberSequenceKeypoint.new(1, 0) })
	e.Color = ColorSequence.new(Color3.new(1, 1, 1))
	e.Transparency = NumberSequence.new(0.2, 1)
	e.LightEmission = 0.8; e.LightInfluence = 0; e.SpreadAngle = Vector2.new(40, 40); e.Acceleration = Vector3.new(0, 0.3, 0)
	e.Drag = 0.5; e.Rotation = NumberRange.new(0, 360); e.RotSpeed = NumberRange.new(-20, 20); e.EmissionDirection = Enum.NormalId.Top
	e.Enabled = true; e.LockedToPart = false; e.Brightness = 2; e.Shape = Enum.ParticleEmitterShape.Sphere; e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
end)
try("Attachment", function() local a = Instance.new("Attachment"); a.CFrame = CFrame.new(0, 1, 0); a.Name = "A" end)
try("Lighting props", function()
	local L = game:GetService("Lighting")
	L.ClockTime = 17.7; L.GeographicLatitude = 30; L.Brightness = 2.4; L.Ambient = Color3.fromRGB(90, 84, 104); L.OutdoorAmbient = Color3.fromRGB(140, 130, 150)
	L.ColorShift_Top = Color3.fromRGB(255, 200, 150); L.ColorShift_Bottom = Color3.fromRGB(90, 110, 140); L.EnvironmentDiffuseScale = 0.6; L.EnvironmentSpecularScale = 0.4
	L.ExposureCompensation = 0.2; L.GlobalShadows = true; L.ShadowSoftness = 0.4; L.FogColor = Color3.new(); L.FogEnd = 100000; L.FogStart = 0
	assert(math.abs(L.ClockTime - 17.7) < 1e-3)
end)
try("Lighting.TimeOfDay read", function() return game:GetService("Lighting").TimeOfDay end)
try("Post effects", function()
	local a = Instance.new("Atmosphere"); a.Density = 0.3; a.Offset = 0.1; a.Color = Color3.new(); a.Decay = Color3.new(); a.Glare = 0.2; a.Haze = 1.5
	local b = Instance.new("BloomEffect"); b.Intensity = 0.5; b.Size = 24; b.Threshold = 1; b.Enabled = true
	local c = Instance.new("ColorCorrectionEffect"); c.Brightness = 0; c.Contrast = 0.1; c.Saturation = 0.1; c.TintColor = Color3.new(1, 1, 1)
	local s = Instance.new("SunRaysEffect"); s.Intensity = 0.05; s.Spread = 0.6
	local d = Instance.new("DepthOfFieldEffect")
	local sky = Instance.new("Sky"); sky.StarCount = 1500; sky.CelestialBodiesShown = true; sky.SunAngularSize = 14; sky.MoonAngularSize = 9
end)
try("Model/Folder", function()
	local m = Instance.new("Model"); m.Name = "M"; local p = Instance.new("Part"); p.Parent = m; m.PrimaryPart = p
	m:SetAttribute("StationId", "solo")
	local f = Instance.new("Folder"); f.Name = "F"; m.Parent = f
	assert(#f:GetDescendants() == 2)
	assert(f:FindFirstChild("P", true) == nil or true)
	m.Parent = workspace
	assert(workspace:FindFirstChild("M") == m)
	m:Destroy()
end)
try("Model.WorldPivot write", function() local m = Instance.new("Model"); m.WorldPivot = CFrame.new(1, 2, 3) end)
try("typeof", function() assert(typeof(Instance.new("Part")) == "Instance"); assert(typeof(Vector3.new()) == "Vector3"); assert(typeof(CFrame.new()) == "CFrame") end)
try("ModelStreamingMode", function() local m = Instance.new("Model"); m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent end)
try("FindFirstChildWhichIsA", function() return workspace:FindFirstChildWhichIsA("Camera"), workspace:FindFirstChildOfClass("Camera") end)
try("GetAttributes", function() local p = Instance.new("Part"); p:SetAttribute("A", "x"); local t = p:GetAttributes(); assert(t.A == "x") end)
try("CollectionService tags", function() local p = Instance.new("Part"); p:AddTag("X"); assert(p:HasTag("X")) end)
try("ReplicatedStorage require", function()
	local shared = game:GetService("ReplicatedStorage"):WaitForChild("MushroomLobby")
	local Theme = require(shared:WaitForChild("Theme"))
	assert(Theme.Station.solo)
end)
try("TextLabel.Font read", function() return Instance.new("TextLabel").Font end)
try("os.clock", function() return os.clock(), os.time() end)
return out
]]

for _, line in ctx.eval(source) do
	print(line)
end
