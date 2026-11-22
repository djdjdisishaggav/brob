--!strict
-- Original icon set drawn from rounded rectangles and rings on a 24-unit grid,
-- so icons stay crisp at any scale and need no uploaded image assets.
--
-- Each shape: { kind, x, y, w, h, ... } with x/y the top-left corner in grid
-- units. Optional: r (corner radius), rot (degrees about the shape centre),
-- th (ring thickness), role ("fg" default, "dim", "accent", "cut").

export type Shape = {
	kind: "rect" | "ring",
	x: number,
	y: number,
	w: number,
	h: number,
	r: number?,
	rot: number?,
	th: number?,
	role: string?,
}

export type Colors = {
	fg: Color3,
	-- Second colour for two-tone icons; defaults to fg.
	accent: Color3?,
	-- Colour of the surface behind the icon, used for cut-outs.
	cut: Color3?,
}

local GRID = 24

-- A bar of the given length and thickness centred on (cx, cy).
local function bar(cx: number, cy: number, length: number, thickness: number, rot: number, role: string?): Shape
	return {
		kind = "rect",
		x = cx - length / 2,
		y = cy - thickness / 2,
		w = length,
		h = thickness,
		r = thickness / 2,
		rot = rot,
		role = role,
	}
end

local function dot(cx: number, cy: number, diameter: number, role: string?): Shape
	return {
		kind = "rect",
		x = cx - diameter / 2,
		y = cy - diameter / 2,
		w = diameter,
		h = diameter,
		r = diameter / 2,
		role = role,
	}
end

local function gear(): { Shape }
	local shapes: { Shape } = { { kind = "ring", x = 5.5, y = 5.5, w = 13, h = 13, th = 3.2, r = 6.5 } }
	for step = 0, 7 do
		local angle = math.rad(step * 45)
		local cx, cy = 12 + math.cos(angle) * 9, 12 + math.sin(angle) * 9
		table.insert(shapes, { kind = "rect", x = cx - 2.1, y = cy - 2.1, w = 4.2, h = 4.2, r = 1, rot = step * 45 })
	end
	return shapes
end

local Icons: { [string]: { Shape } } = {
	Gear = gear(),
	Party = {
		dot(17.2, 8, 5.4, "dim"),
		{ kind = "rect", x = 13.2, y = 12.4, w = 8.2, h = 6.4, r = 3.2, role = "dim" },
		dot(9.2, 7.6, 7),
		{ kind = "rect", x = 3, y = 12.6, w = 12.4, h = 8.4, r = 4.2 },
	},
	User = {
		dot(12, 7.8, 7.6),
		{ kind = "rect", x = 5, y = 13.2, w = 14, h = 8.4, r = 4.2 },
	},
	UserPlus = {
		dot(9.4, 7.8, 7.2),
		{ kind = "rect", x = 2.8, y = 13.2, w = 13.2, h = 8.2, r = 4.1 },
		bar(19, 9, 7, 2.6, 0),
		bar(19, 9, 7, 2.6, 90),
	},
	Bell = {
		dot(12, 3.6, 3),
		{ kind = "rect", x = 6.2, y = 4.4, w = 11.6, h = 13, r = 5.8 },
		{ kind = "rect", x = 4, y = 14.6, w = 16, h = 3.6, r = 1.8 },
		dot(12, 20.4, 3.8),
	},
	Mushroom = {
		{ kind = "rect", x = 9, y = 11, w = 6, h = 10, r = 2.6, role = "fg" },
		{ kind = "rect", x = 2.6, y = 3.4, w = 18.8, h = 11, r = 5.5, role = "accent" },
		dot(8, 7.6, 3, "fg"),
		dot(13.4, 6.6, 2.4, "fg"),
		dot(17, 9.6, 2, "fg"),
	},
	Lock = {
		{ kind = "ring", x = 7.4, y = 3.2, w = 9.2, h = 12, th = 2.6, r = 4.6 },
		{ kind = "rect", x = 4.8, y = 10.2, w = 14.4, h = 10.8, r = 2.6 },
		dot(12, 15.2, 3, "cut"),
	},
	Check = {
		bar(8.4, 14.4, 7, 3.2, 45),
		bar(14.2, 11.6, 12.4, 3.2, -45),
	},
	ChevronLeft = {
		bar(11.2, 8.9, 9.4, 3.4, -45),
		bar(11.2, 15.1, 9.4, 3.4, 45),
	},
	ChevronRight = {
		bar(12.8, 8.9, 9.4, 3.4, 45),
		bar(12.8, 15.1, 9.4, 3.4, -45),
	},
	Plus = {
		bar(12, 12, 14, 3.4, 0),
		bar(12, 12, 14, 3.4, 90),
	},
	Close = {
		bar(12, 12, 15, 3.4, 45),
		bar(12, 12, 15, 3.4, -45),
	},
	Crown = {
		{ kind = "rect", x = 4.4, y = 16.6, w = 15.2, h = 3.4, r = 1.2 },
		{ kind = "rect", x = 5.4, y = 11, w = 13.2, h = 5.2, r = 0.8 },
		{ kind = "rect", x = 3.9, y = 7.5, w = 5.4, h = 5.4, r = 0.8, rot = 45 },
		{ kind = "rect", x = 9.1, y = 5, w = 5.8, h = 5.8, r = 0.8, rot = 45 },
		{ kind = "rect", x = 14.7, y = 7.5, w = 5.4, h = 5.4, r = 0.8, rot = 45 },
	},
	Sprout = {
		bar(12, 16.4, 9.6, 2.6, 90),
		{ kind = "rect", x = 3.2, y = 7.6, w = 9.6, h = 5.6, r = 2.8, rot = 28 },
		{ kind = "rect", x = 11.4, y = 4.6, w = 9.6, h = 5.6, r = 2.8, rot = -32 },
	},
	Diamond = {
		{ kind = "rect", x = 6.2, y = 6.2, w = 11.6, h = 11.6, r = 2, rot = 45 },
	},
	Coin = {
		dot(12, 12, 18, "accent"),
		{ kind = "ring", x = 6, y = 6, w = 12, h = 12, th = 1.8, r = 6, role = "fg" },
	},
	Paw = {
		{ kind = "rect", x = 6.6, y = 11.4, w = 10.8, h = 9, r = 4.5 },
		dot(5.2, 9.6, 3.8),
		dot(9.6, 5.6, 3.8),
		dot(14.4, 5.6, 3.8),
		dot(18.8, 9.6, 3.8),
	},
	Bag = {
		{ kind = "ring", x = 8, y = 2.6, w = 8, h = 9, th = 2.4, r = 4 },
		{ kind = "rect", x = 4, y = 8.4, w = 16, h = 12.6, r = 3 },
	},
	Chart = {
		{ kind = "rect", x = 4, y = 12.6, w = 4.4, h = 8.4, r = 1.4 },
		{ kind = "rect", x = 9.8, y = 4, w = 4.4, h = 17, r = 1.4 },
		{ kind = "rect", x = 15.6, y = 8.6, w = 4.4, h = 12.4, r = 1.4 },
	},
	Scroll = {
		{ kind = "rect", x = 5, y = 4, w = 14, h = 16, r = 2 },
		{ kind = "rect", x = 3, y = 2.6, w = 18, h = 4, r = 2 },
		{ kind = "rect", x = 3, y = 17.4, w = 18, h = 4, r = 2 },
		bar(12, 10, 8, 1.8, 0, "cut"),
		bar(12, 13.8, 8, 1.8, 0, "cut"),
	},
	Warning = {
		dot(12, 12, 19),
		bar(12, 9.8, 7.4, 2.8, 90, "cut"),
		dot(12, 16.6, 2.8, "cut"),
	},
	Info = {
		dot(12, 12, 19),
		dot(12, 7.6, 2.8, "cut"),
		bar(12, 14, 7.4, 2.8, 90, "cut"),
	},
	Clock = {
		{ kind = "ring", x = 3, y = 3, w = 18, h = 18, th = 2.6, r = 9 },
		bar(12, 9.4, 6, 2.4, 90),
		bar(14, 12.6, 5.4, 2.4, 0),
	},
	Exit = {
		{ kind = "rect", x = 3.4, y = 3.6, w = 3, h = 16.8, r = 1.5 },
		{ kind = "rect", x = 3.4, y = 3.6, w = 9, h = 3, r = 1.5 },
		{ kind = "rect", x = 3.4, y = 17.4, w = 9, h = 3, r = 1.5 },
		bar(14.6, 12, 10, 3, 0),
		bar(17.6, 9.6, 6.6, 3, 45),
		bar(17.6, 14.4, 6.6, 3, -45),
	},
	Spore = {
		dot(8.4, 14.6, 8.4),
		dot(16, 8.2, 6, "dim"),
		dot(17.4, 17, 3.6, "dim"),
	},
}

local IconKit = {}

IconKit.Names = (function()
	local names = {}
	for name in Icons do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end)()

function IconKit.has(name: string): boolean
	return Icons[name] ~= nil
end

-- Builds the icon as a transparent square Frame `size` pixels wide.
function IconKit.create(name: string, size: number, colors: Colors): Frame
	local shapes = Icons[name]
	if not shapes then
		error(`unknown icon "{name}"`, 2)
	end
	local unit = size / GRID

	local root = Instance.new("Frame")
	root.Name = name .. "Icon"
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.Size = UDim2.fromOffset(size, size)

	for index, shape in shapes do
		local role = shape.role or "fg"
		local color = colors.fg
		if role == "accent" then
			color = colors.accent or colors.fg
		elseif role == "cut" then
			color = colors.cut or Color3.new(0, 0, 0)
		end

		local frame = Instance.new("Frame")
		frame.Name = `{shape.kind}{index}`
		frame.BorderSizePixel = 0
		frame.Rotation = shape.rot or 0
		frame.ZIndex = index

		local inset = 0
		if shape.kind == "ring" then
			-- UIStroke draws outside the frame, so shrink the frame by the thickness.
			local thickness = (shape.th or 2) * unit
			inset = shape.th or 2
			frame.BackgroundTransparency = 1
			local stroke = Instance.new("UIStroke")
			stroke.Color = color
			stroke.Thickness = thickness
			stroke.Transparency = if role == "dim" then 0.5 else 0
			stroke.Parent = frame
		else
			frame.BackgroundColor3 = color
			frame.BackgroundTransparency = if role == "dim" then 0.5 else 0
		end

		frame.Position = UDim2.fromOffset((shape.x + inset) * unit, (shape.y + inset) * unit)
		frame.Size = UDim2.fromOffset((shape.w - inset * 2) * unit, (shape.h - inset * 2) * unit)

		local radius = math.max(0, (shape.r or 0) - inset)
		if radius > 0 then
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, radius * unit)
			corner.Parent = frame
		end
		frame.Parent = root
	end
	return root
end

return IconKit
