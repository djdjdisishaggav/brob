-- Layout maths of the headless UI renderer (tools/ui_render).
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local Render = require("../tools/ui_render")

local Instance, Enum = roblox.Instance, roblox.Enum
local UDim, UDim2, Vector2, Color3 = roblox.UDim, roblox.UDim2, roblox.Vector2, roblox.Color3

local NUNITO = roblox.Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
local FREDOKA =
	roblox.Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
local NO_INSET = { topInset = 0 }

local passed, failures = 0, {}
local function check(condition, name)
	if condition then
		passed += 1
	else
		table.insert(failures, name)
	end
end
local function near(actual, expected, name)
	check(
		type(actual) == "number" and math.abs(actual - expected) < 0.05,
		`{name}: expected {expected}, got {actual}`
	)
end
local function rect(node, x, y, w, h, name)
	near(node.x, x, name .. " x")
	near(node.y, y, name .. " y")
	near(node.w, w, name .. " width")
	near(node.h, h, name .. " height")
end

local function make(class, props, children)
	local instance = Instance.new(class)
	for key, value in props or {} do
		instance[key] = value
	end
	for _, child in children or {} do
		child.Parent = instance
	end
	return instance
end
local function frame(w, h, props, children)
	local instance = make("Frame", { Size = UDim2.fromOffset(w, h) }, children)
	for key, value in props or {} do
		instance[key] = value
	end
	return instance
end
local function gui(children, props)
	local screen = make("ScreenGui", { IgnoreGuiInset = true }, children)
	for key, value in props or {} do
		screen[key] = value
	end
	return screen
end
local function list(direction, gap, props)
	local layout = make("UIListLayout", {
		FillDirection = Enum.FillDirection[direction],
		Padding = UDim.new(0, gap),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	for key, value in props or {} do
		layout[key] = value
	end
	return layout
end
local function label(text, size, props, children)
	local instance = make("TextLabel", { Text = text, TextSize = size, FontFace = NUNITO }, children)
	for key, value in props or {} do
		instance[key] = value
	end
	return instance
end
local VIEW = Vector2.new(1000, 600)

-- Scale + offset sizes, anchor points, written-back properties.
do
	local box = frame(0, 0, {
		Size = UDim2.new(0.5, 20, 0.25, -10),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
	})
	local layout = Render.layout(gui({ box }), VIEW, NO_INSET)
	rect(layout[box], 240, 450, 520, 140, "anchored frame")
	near(box.AbsoluteSize.X, 520, "AbsoluteSize written")
	near(box.AbsolutePosition.Y, 450, "AbsolutePosition written")
end

-- Top bar inset: IgnoreGuiInset off moves content down, positions stay inset-relative.
do
	local inside, ignoring = frame(10, 10), frame(10, 10)
	local screen = make("ScreenGui", {}, { inside })
	local layout = Render.layout({ screen, gui({ ignoring }) }, VIEW)
	near(layout[inside].y, 58, "inset pushes content down")
	near(inside.AbsolutePosition.Y, 0, "AbsolutePosition is inset-relative")
	near(ignoring.AbsolutePosition.Y, -58, "IgnoreGuiInset reports negative Y")
	near(screen.AbsoluteSize.Y, 542, "ScreenGui height excludes the inset")
end

-- UIPadding with scale and offset on all four sides.
do
	local fill = frame(0, 0, { Size = UDim2.fromScale(1, 1) })
	local cornered = frame(20, 20, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(1, 1) })
	local parent = frame(400, 300, { Position = UDim2.fromOffset(100, 50) }, {
		make("UIPadding", {
			PaddingLeft = UDim.new(0, 10),
			PaddingTop = UDim.new(0.1, 0),
			PaddingRight = UDim.new(0, 30),
			PaddingBottom = UDim.new(0, 40),
		}),
		fill,
		cornered,
	})
	local layout = Render.layout(gui({ parent }), VIEW, NO_INSET)
	rect(layout[fill], 110, 80, 360, 230, "padded fill child")
	rect(layout[cornered], 450, 290, 20, 20, "padded anchored child")
end

-- UIListLayout: order, padding, alignment, content size, hidden children.
do
	local a = frame(50, 20, { LayoutOrder = 2 })
	local b = frame(70, 40, { LayoutOrder = 1 })
	local c = frame(30, 30, { LayoutOrder = 3 })
	local hidden = frame(500, 500, { LayoutOrder = 0, Visible = false })
	local layoutInstance = list("Horizontal", 10, {
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
	})
	local parent = frame(400, 100, nil, { layoutInstance, a, b, c, hidden })
	local layout = Render.layout(gui({ parent }), VIEW, NO_INSET)
	rect(layout[b], 115, 60, 70, 40, "list first by LayoutOrder")
	rect(layout[a], 195, 80, 50, 20, "list second")
	rect(layout[c], 255, 70, 30, 30, "list third")
	near(layoutInstance.AbsoluteContentSize.X, 170, "list content width")
	near(layoutInstance.AbsoluteContentSize.Y, 40, "list content height")

	local first, second = frame(10, 20, { Name = "B" }), frame(10, 30, { Name = "A" })
	local vertical = frame(100, 200, nil, {
		make("UIListLayout", { Padding = UDim.new(0.1, 0), SortOrder = Enum.SortOrder.Name }),
		first,
		second,
	})
	layout = Render.layout(gui({ vertical }), VIEW, NO_INSET)
	near(layout[second].y, 0, "vertical list sorts by name")
	near(layout[first].y, 50, "vertical list scale padding")
end

-- Flex: layout-wide Fill, UIFlexItem Fill and custom grow ratios, cross-axis Fill.
do
	local a, b, c = frame(50, 20), frame(70, 20), frame(30, 20)
	local parent = frame(400, 100, nil, { list("Horizontal", 10, { HorizontalFlex = Enum.UIFlexAlignment.Fill }), a, b, c })
	local layout = Render.layout(gui({ parent }), VIEW, NO_INSET)
	near(layout[a].w, 126.67, "flex fill grows evenly")
	near(layout[c].x + layout[c].w, 400, "flex fill reaches the far edge")

	local fixed = frame(100, 20)
	local grower = frame(0, 20, nil, { make("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }) })
	layout = Render.layout(gui({ frame(400, 100, nil, { list("Horizontal", 10), fixed, grower }) }), VIEW, NO_INSET)
	rect(layout[grower], 110, 0, 290, 20, "flex item fills the remainder")

	local function ratio(value)
		return make("UIFlexItem", { FlexMode = Enum.UIFlexMode.Custom, GrowRatio = value })
	end
	local one, three = frame(0, 20, nil, { ratio(1) }), frame(0, 20, nil, { ratio(3) })
	layout = Render.layout(gui({ frame(400, 100, nil, { list("Horizontal", 0), one, three }) }), VIEW, NO_INSET)
	near(layout[one].w, 100, "grow ratio 1 of 4")
	near(layout[three].w, 300, "grow ratio 3 of 4")

	local stretched = frame(10, 20)
	local column = frame(200, 100, nil, { list("Vertical", 0, { HorizontalFlex = Enum.UIFlexAlignment.Fill }), stretched })
	layout = Render.layout(gui({ column }), VIEW, NO_INSET)
	rect(layout[stretched], 0, 0, 200, 20, "cross-axis fill")
end

-- Wrapping list.
do
	local items = {}
	for index = 1, 5 do
		items[index] = frame(100, 30, { LayoutOrder = index })
	end
	local children = { list("Horizontal", 10, { Wraps = true }) }
	for _, item in items do
		table.insert(children, item)
	end
	local layout = Render.layout(gui({ frame(320, 200, nil, children) }), VIEW, NO_INSET)
	rect(layout[items[3]], 220, 0, 100, 30, "third item ends the first line")
	rect(layout[items[4]], 0, 40, 100, 30, "fourth item wraps")
end

-- UIGridLayout: cells, wrapping, max cells, alignment of a short last line.
do
	local function grid(props)
		local layoutInstance = make("UIGridLayout", {
			CellSize = UDim2.fromOffset(60, 40),
			CellPadding = UDim2.fromOffset(10, 5),
			SortOrder = Enum.SortOrder.LayoutOrder,
		})
		for key, value in props or {} do
			layoutInstance[key] = value
		end
		local cells, children = {}, { layoutInstance }
		for index = 1, 5 do
			cells[index] = frame(5, 5, { LayoutOrder = index })
			table.insert(children, cells[index])
		end
		local layout = Render.layout(gui({ frame(200, 200, nil, children) }), VIEW, NO_INSET)
		return layout, cells, layoutInstance
	end
	local layout, cells, layoutInstance = grid()
	rect(layout[cells[3]], 140, 0, 60, 40, "grid third cell")
	rect(layout[cells[4]], 0, 45, 60, 40, "grid wraps to second row")
	near(layoutInstance.AbsoluteContentSize.Y, 85, "grid content height")
	layout, cells = grid({ FillDirectionMaxCells = 2 })
	rect(layout[cells[3]], 0, 45, 60, 40, "grid max cells")
	layout, cells = grid({ HorizontalAlignment = Enum.HorizontalAlignment.Center })
	near(layout[cells[1]].x, 0, "full grid row centred")
	near(layout[cells[4]].x, 35, "short grid row centred on its own")
end

-- UIAspectRatioConstraint and UISizeConstraint.
do
	local function aspect(props)
		return make("UIAspectRatioConstraint", props)
	end
	local square = frame(200, 100, nil, { aspect({ AspectRatio = 1 }) })
	local wide = frame(200, 100, nil, { aspect({ AspectRatio = 4 }) })
	local scaled = frame(10, 10, nil, {
		aspect({ AspectRatio = 2, AspectType = Enum.AspectType.ScaleWithParentSize }),
	})
	local capped = frame(500, 5, nil, {
		make("UISizeConstraint", { MinSize = Vector2.new(0, 20), MaxSize = Vector2.new(120, 1000) }),
	})
	local layout = Render.layout(gui({ frame(300, 200, nil, { square, wide, scaled, capped }) }), VIEW, NO_INSET)
	rect(layout[square], 0, 0, 100, 100, "aspect 1 fits the height")
	rect(layout[wide], 0, 0, 200, 50, "aspect 4 fits the width")
	rect(layout[scaled], 0, 0, 300, 150, "aspect scales with parent width")
	rect(layout[capped], 0, 0, 120, 20, "size constraint clamps")
end

-- UIScale: scales its parent's size and accumulates for offsets below it.
do
	local deep = frame(100, 100, nil, { make("UIScale", { Scale = 0.5 }) })
	local child = frame(0, 0, { Size = UDim2.new(0.5, 10, 0, 20), Position = UDim2.fromOffset(5, 5) }, { deep })
	local outer = frame(200, 100, { Position = UDim2.fromOffset(100, 100) }, { make("UIScale", { Scale = 2 }), child })
	local layout = Render.layout(gui({ outer }), VIEW, NO_INSET)
	rect(layout[outer], 100, 100, 400, 200, "scaled frame")
	rect(layout[child], 110, 110, 220, 40, "child of scaled frame")
	rect(layout[deep], 110, 110, 100, 100, "nested scale 2 x 0.5")
	near(layout[deep].scale, 1, "accumulated scale")
end

-- AutomaticSize: containers with and without a layout, minimum size, nesting.
do
	local inner = frame(0, 0, { AutomaticSize = Enum.AutomaticSize.XY }, {
		list("Horizontal", 5),
		frame(40, 10),
		frame(40, 30),
	})
	local stacked = frame(0, 0, { AutomaticSize = Enum.AutomaticSize.XY }, {
		make("UIPadding", {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
		}),
		list("Vertical", 4),
		frame(100, 20),
		inner,
	})
	local free = frame(200, 0, { AutomaticSize = Enum.AutomaticSize.XY, Position = UDim2.fromOffset(0, 300) }, {
		frame(50, 50, { Position = UDim2.fromOffset(10, 10) }),
	})
	local layout = Render.layout(gui({ stacked, free }), VIEW, NO_INSET)
	rect(layout[inner], 8, 32, 85, 30, "nested automatic size")
	rect(layout[stacked], 0, 0, 116, 70, "automatic size with list and padding")
	rect(layout[free], 0, 300, 200, 60, "automatic size keeps Size as minimum")
end

-- Text: measurement, wrapping, automatic size, truncation, scaling, rich text.
do
	local wordWidth = Render.measureText("mmmm", 16, NUNITO)
	local pairWidth, lineHeight = Render.measureText("mmmm mmmm", 16, NUNITO)
	check(wordWidth > 20 and wordWidth < 60, "word width is plausible: " .. wordWidth)
	near(lineHeight, 16, "one line is TextSize tall")
	local _, wrappedHeight = Render.measureText("mmmm mmmm mmmm mmmm mmmm", 16, NUNITO, pairWidth + 1)
	near(wrappedHeight, 48, "measureText wraps to three lines")

	local wrapped = label("mmmm mmmm mmmm mmmm mmmm", 16, {
		Size = UDim2.fromOffset(pairWidth + 1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
	})
	local growing = label("mmmm mmmm", 16, { AutomaticSize = Enum.AutomaticSize.XY })
	local broken = label("mmmmmmmmmmmm", 16, { Size = UDim2.fromOffset(wordWidth, 100), TextWrapped = true })
	local cut = label("mmmm mmmm mmmm", 16, {
		Size = UDim2.fromOffset(pairWidth, 16),
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local scaled = label("3", 8, { Size = UDim2.fromOffset(100, 40), TextScaled = true, FontFace = FREDOKA })
	local limited = label("3", 8, { Size = UDim2.fromOffset(100, 40), TextScaled = true }, {
		make("UITextSizeConstraint", { MaxTextSize = 24 }),
	})
	local rich = label('<b>Bold</b> plain<br/><font color="#ff0000" size="20">red</font><x>!</x>', 16, {
		Size = UDim2.fromOffset(300, 60),
		RichText = true,
	})
	local tall = label("one\ntwo", 20, { Size = UDim2.fromOffset(100, 100), LineHeight = 1.5 })
	local layout = Render.layout(gui({ wrapped, growing, broken, cut, scaled, limited, rich, tall }), VIEW, NO_INSET)

	near(#layout[wrapped].text.block.lines, 3, "wrapped line count")
	near(layout[wrapped].h, 48, "automatic height follows the lines")
	near(wrapped.TextBounds.Y, 48, "TextBounds written")
	check(math.abs(layout[growing].w - pairWidth) <= 1, "automatic width follows the text")
	near(#layout[broken].text.block.lines, 3, "a long word breaks across lines")
	local cutLine = layout[cut].text.block.lines[1]
	check(cutLine.pieces[#cutLine.pieces].text:sub(-3) == "…", "truncated text ends with an ellipsis")
	check(cutLine.width <= pairWidth + 0.05, "truncated text fits")
	check(cut.TextFits == false and wrapped.TextFits == true, "TextFits written")
	near(layout[scaled].text.spec.size, 40, "TextScaled fills the height")
	near(layout[limited].text.spec.size, 24, "UITextSizeConstraint caps TextScaled")
	local richLines = layout[rich].text.block.lines
	near(#richLines, 2, "rich text <br/>")
	check(richLines[1].pieces[1].style.bold == true and richLines[1].pieces[1].text == "Bold", "rich text <b>")
	check(richLines[2].pieces[1].style.color == "#ff0000", "rich text font colour")
	near(richLines[2].height, 20, "rich text font size sets the line height")
	check(richLines[2].pieces[2].text == "!", "unknown tags are stripped")
	near(tall.TextBounds.Y, 60, "LineHeight multiplies the line box")
end

-- SVG: stroke outset, corners, gradients, clipping, z-order, rotation, visibility.
do
	local stroked = frame(100, 40, { Name = "Stroked", Position = UDim2.fromOffset(10, 10) }, {
		make("UICorner", { CornerRadius = UDim.new(0, 8) }),
		make("UIStroke", { Thickness = 2, Color = Color3.fromHex("#112233") }),
		make("UIGradient", {
			Rotation = 90,
			Color = roblox.ColorSequence.new({
				roblox.ColorSequenceKeypoint.new(0, Color3.new(1, 0, 0)),
				roblox.ColorSequenceKeypoint.new(0.5, Color3.new(0, 1, 0)),
				roblox.ColorSequenceKeypoint.new(1, Color3.new(0, 0, 1)),
			}),
		}),
	})
	local svg = Render.toSvg(gui({ stroked }), { viewport = VIEW, topInset = 0 })
	check(
		svg:find('<rect x="9" y="9" width="102" height="42" rx="9" fill="none" stroke="#112233" stroke-width="2"', 1, true)
			~= nil,
		"2px stroke is centred 1px outside the edge"
	)
	check(svg:find('x1="60" y1="10" x2="60" y2="50"', 1, true) ~= nil, "gradient runs top to bottom")
	check(select(2, svg:gsub("<stop ", "")) >= 3 + 3, "gradient keeps every keypoint")
	check(svg:find('id="Stroked" data-name="Stroked" data-class="Frame"', 1, true) ~= nil, "groups carry names")

	local clipFrame = frame(50, 50, { Name = "Clip", ClipsDescendants = true }, {
		make("UICorner", { CornerRadius = UDim.new(0, 10) }),
	})
	local clipGroup = make("CanvasGroup", { Name = "Group", Size = UDim2.fromOffset(50, 50), GroupTransparency = 0.5 }, {
		make("UICorner", { CornerRadius = UDim.new(0, 10) }),
	})
	svg = Render.toSvg(gui({ clipFrame, clipGroup }), { viewport = VIEW })
	check(svg:find('<clipPath id="clip"><rect x="0" y="0" width="50" height="50"/>', 1, true) ~= nil, "frames clip square")
	check(svg:find('width="50" height="50" rx="10"/></clipPath>', 1, true) ~= nil, "canvas groups clip rounded")
	check(svg:find('data-class="CanvasGroup" opacity="0.5"', 1, true) ~= nil, "group transparency")
	svg = Render.toSvg(gui({ clipFrame }), { viewport = VIEW, roundedClip = true })
	check(svg:find('<clipPath id="clip"><rect x="0" y="0" width="50" height="50" rx="10"/>', 1, true) ~= nil, "roundedClip")

	local above = frame(10, 10, { Name = "Above", ZIndex = 2 })
	local below = frame(10, 10, { Name = "Below", Rotation = 30 })
	local gone = frame(10, 10, { Name = "Gone", Visible = false })
	local back = gui({ frame(10, 10, { Name = "Back" }) }, { DisplayOrder = -1 })
	local off = gui({ frame(10, 10, { Name = "Off" }) }, { Enabled = false })
	svg = Render.toSvg({ gui({ above, below, gone }), back, off }, { viewport = VIEW })
	local backAt, belowAt, aboveAt = svg:find('id="Back"', 1, true), svg:find('id="Below"', 1, true), svg:find('id="Above"', 1, true)
	check(backAt and belowAt and aboveAt and backAt < belowAt and belowAt < aboveAt, "DisplayOrder then ZIndex")
	check(svg:find('transform="rotate(30 5 5)"', 1, true) ~= nil, "rotation about the centre")
	check(not svg:find('id="Gone"', 1, true) and not svg:find('id="Off"', 1, true), "hidden objects are skipped")
end

if #failures > 0 then
	for _, failure in failures do
		print("FAIL " .. failure)
	end
	print(`ui_render spec: {#failures} of {passed + #failures} assertions failed`)
	process.exit(1)
end
print(`ui_render spec: {passed} assertions ok`)
