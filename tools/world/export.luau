-- Flattens a built lobby into plain data for the three.js preview:
-- every BasePart, every enabled PointLight, and a draw list per SurfaceGui.
local Export = {}

local function round(value: number, places: number?): number
	local factor = 10 ^ (places or 3)
	return math.round(value * factor) / factor
end

local function color(value): { number }
	return { math.round(value.R * 255), math.round(value.G * 255), math.round(value.B * 255) }
end

local function shapeOf(part): string
	if part.ClassName == "WedgePart" then
		return "wedge"
	end
	local mesh = part:FindFirstChildOfClass("SpecialMesh")
	if mesh and mesh.MeshType.Name == "Sphere" then
		return "ellipsoid"
	end
	if part.ClassName == "Part" or part.ClassName == "SpawnLocation" then
		local shape = part.Shape.Name
		if shape == "Ball" then
			return "ball"
		elseif shape == "Cylinder" then
			return "cylinder"
		elseif shape == "Wedge" then
			return "wedge"
		end
	end
	return "block"
end

local function fontOf(label): (string, number)
	local face = label.FontFace
	local family = if string.find(face.Family, "Fredoka") then "Fredoka One" else "Nunito"
	local weights = { Regular = 400, Medium = 500, SemiBold = 600, Bold = 700, ExtraBold = 800, Heavy = 900 }
	local weight = weights[face.Weight.Name] or 400
	return family, if family == "Fredoka One" then 400 else weight
end

-- Resolves UDim2 layout the way Roblox does for the subset the signs use:
-- scale + offset sizing, anchor points, nested frames, UIScale, UICorner and
-- UIStroke. No list or grid layouts.
local function layoutGui(gui, width: number, height: number)
	local ops = {}

	local function visit(parent, px: number, py: number, pw: number, ph: number, scale: number)
		local children = {}
		for _, child in parent:GetChildren() do
			if child:IsA("GuiObject") and child.Visible then
				table.insert(children, child)
			end
		end
		table.sort(children, function(a, b)
			return a.ZIndex < b.ZIndex
		end)
		for _, child in children do
			local uiScale = child:FindFirstChildOfClass("UIScale")
			local own = if uiScale then uiScale.Scale else 1
			local size, position, anchor = child.Size, child.Position, child.AnchorPoint
			local w = (pw * size.X.Scale + size.X.Offset * scale) * own
			local h = (ph * size.Y.Scale + size.Y.Offset * scale) * own
			local x = px + pw * position.X.Scale + position.X.Offset * scale - anchor.X * w
			local y = py + ph * position.Y.Scale + position.Y.Offset * scale - anchor.Y * h
			local total = scale * own

			if child.BackgroundTransparency < 1 then
				local corner = child:FindFirstChildOfClass("UICorner")
				local stroke = child:FindFirstChildOfClass("UIStroke")
				local radius = 0
				if corner then
					radius = corner.CornerRadius.Scale * math.min(w, h) + corner.CornerRadius.Offset * total
				end
				table.insert(ops, {
					k = "f",
					x = round(x, 1),
					y = round(y, 1),
					w = round(w, 1),
					h = round(h, 1),
					c = color(child.BackgroundColor3),
					a = round(1 - child.BackgroundTransparency, 2),
					r = round(radius, 1),
					sc = if stroke then color(stroke.Color) else nil,
					st = if stroke then round(stroke.Thickness * total, 1) else nil,
				})
			end
			if child.ClassName == "TextLabel" and child.Text ~= "" then
				local family, weight = fontOf(child)
				table.insert(ops, {
					k = "t",
					x = round(x, 1),
					y = round(y, 1),
					w = round(w, 1),
					h = round(h, 1),
					text = child.Text,
					c = color(child.TextColor3),
					font = family,
					weight = weight,
					-- Roblox caps scaled text at 100 px before any UIScale.
					max = 100 * total,
					ax = child.TextXAlignment.Name,
				})
			end
			visit(child, x, y, w, h, total)
		end
	end

	visit(gui, 0, 0, width, height, 1)
	return ops
end

local FACES = {
	Back = { "X", "Y", "Z", 1 },
	Front = { "X", "Y", "Z", -1 },
	Right = { "Z", "Y", "X", 1 },
	Left = { "Z", "Y", "X", -1 },
	Top = { "X", "Z", "Y", 1 },
	Bottom = { "X", "Z", "Y", -1 },
}

function Export.scene(root)
	local parts, lights, guis = {}, {}, {}
	local names = {}

	for _, instance in root:GetDescendants() do
		if instance:IsA("BasePart") then
			local size = instance.Size
			local components = { instance.CFrame:GetComponents() }
			for index, value in components do
				components[index] = round(value, 4)
			end
			names[instance.Name] = (names[instance.Name] or 0) + 1
			table.insert(parts, {
				n = instance.Name,
				s = shapeOf(instance),
				z = { round(size.X), round(size.Y), round(size.Z) },
				f = components,
				c = color(instance.Color),
				m = instance.Material.Name,
				t = round(instance.Transparency, 2),
				sh = instance.CastShadow,
				col = instance.CanCollide,
			})
		elseif instance.ClassName == "PointLight" and instance.Enabled then
			local holder = instance.Parent
			if holder and holder:IsA("BasePart") then
				local position = holder.CFrame.Position
				table.insert(lights, {
					p = { round(position.X, 2), round(position.Y, 2), round(position.Z, 2) },
					c = color(instance.Color),
					r = instance.Range,
					b = instance.Brightness,
				})
			end
		elseif instance.ClassName == "SurfaceGui" and instance.Enabled then
			local holder = instance.Parent
			local face = FACES[instance.Face.Name]
			if holder and holder:IsA("BasePart") and face then
				local size = holder.Size
				local widthStuds, heightStuds = size[face[1]], size[face[2]]
				local ppi = instance.PixelsPerStud
				local components = { holder.CFrame:GetComponents() }
				for index, value in components do
					components[index] = round(value, 4)
				end
				table.insert(guis, {
					n = instance.Name,
					f = components,
					face = instance.Face.Name,
					w = round(widthStuds, 3),
					h = round(heightStuds, 3),
					d = round(size[face[3]] / 2, 3),
					ppi = ppi,
					ops = layoutGui(instance, widthStuds * ppi, heightStuds * ppi),
				})
			end
		end
	end

	return { parts = parts, lights = lights, guis = guis }, names
end

return Export
