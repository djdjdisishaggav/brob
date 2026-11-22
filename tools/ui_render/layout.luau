-- Computes Roblox-style rectangles for a GUI tree. Sizes are resolved top-down
-- with child positions relative to their parent, then made absolute in one walk.
local roblox = require("@lune/roblox")

local Fonts = require("./fonts")
local Text = require("./text")

local Layout = {}

local EPS = 0.01
local TEXT_CLASSES = { TextLabel = true, TextButton = true, TextBox = true }
local ALIGN = { Left = 0, Top = 0, Center = 0.5, Right = 1, Bottom = 1 }
Layout.ALIGN = ALIGN

-- Lune throws for properties without a reflection default (CornerRadius, Image,
-- IgnoreGuiInset, ...) until they are written, so every optional read has a fallback.
local function get(instance, property, default)
	local ok, value = pcall(function()
		return instance[property]
	end)
	if ok and value ~= nil then
		return value
	end
	return default
end
Layout.get = get

local function set(instance, property, value)
	pcall(function()
		instance[property] = value
	end)
end

local function udim(value, basis, scale)
	return value.Scale * basis + value.Offset * scale
end

local function scan(nodes, instance, parent)
	local isObject = instance:IsA("GuiObject")
	local info = {
		instance = instance,
		class = instance.ClassName,
		name = instance.Name,
		parent = parent,
		children = {},
		mods = {},
		rx = 0,
		ry = 0,
		w = 0,
		h = 0,
		scale = 1,
		padding = { 0, 0, 0, 0 },
		visible = get(instance, isObject and "Visible" or "Enabled", true),
		zIndex = isObject and get(instance, "ZIndex", 1) or 1,
		rotation = isObject and get(instance, "Rotation", 0) or 0,
	}
	if isObject then
		info.size, info.position = instance.Size, instance.Position
		info.anchor = get(instance, "AnchorPoint", roblox.Vector2.new(0, 0))
		info.auto = get(instance, "AutomaticSize", { Name = "None" }).Name
		info.order = get(instance, "LayoutOrder", 0)
	end
	nodes[instance] = info
	for _, child in instance:GetChildren() do
		local class = child.ClassName
		if child:IsA("GuiObject") then
			table.insert(info.children, scan(nodes, child, info))
		elseif class:sub(1, 2) == "UI" and not info.mods[class] then
			local switchable = class == "UIStroke" or class == "UIGradient"
			if not switchable or get(child, "Enabled", true) then
				info.mods[class] = child
			end
			if class == "UIStroke" then
				local gradient = child:FindFirstChildOfClass("UIGradient")
				info.strokeGradient = gradient and get(gradient, "Enabled", true) and gradient or nil
			end
		end
	end
	return info
end

local function padding(info, w, h)
	local pad, scale = info.mods.UIPadding, info.scale
	if not pad then
		return 0, 0, 0, 0
	end
	return udim(pad.PaddingLeft, w, scale),
		udim(pad.PaddingTop, h, scale),
		udim(pad.PaddingRight, w, scale),
		udim(pad.PaddingBottom, h, scale)
end

local function constrain(info, w, h, pw, ph, skipAspect)
	local mods, scale = info.mods, info.scale
	local aspect = mods.UIAspectRatioConstraint
	if aspect and not skipAspect then
		local ratio = aspect.AspectRatio
		if aspect.AspectType.Name == "ScaleWithParentSize" then
			if aspect.DominantAxis.Name == "Width" then
				w, h = pw, pw / ratio
			else
				w, h = ph * ratio, ph
			end
		elseif w / ratio <= h then
			h = w / ratio
		else
			w = h * ratio
		end
	end
	local limit = mods.UISizeConstraint
	if limit then
		local min, max = limit.MinSize, limit.MaxSize
		w = math.max(math.min(w, max.X * scale), min.X * scale)
		h = math.max(math.min(h, max.Y * scale), min.Y * scale)
	end
	return w, h
end

-- Lays the text out for the given box and returns its bounds including padding.
local function measureText(info, w, h, autoX, autoY, pw)
	local instance, mods, scale = info.instance, info.mods, info.scale
	local left, top, right, bottom = padding(info, w, h)
	local text, placeholder = get(instance, "Text", ""), false
	if info.class == "TextBox" and text == "" then
		text, placeholder = get(instance, "PlaceholderText", ""), true
	end
	local family, weight, italic = Fonts.describe(get(instance, "FontFace", nil))
	local spec = {
		family = family,
		weight = weight,
		italic = italic,
		scale = scale,
		size = get(instance, "TextSize", 14) * scale,
		lineHeight = get(instance, "LineHeight", 1),
		runs = Text.parse(text, get(instance, "RichText", false)),
	}
	local wrapped = get(instance, "TextWrapped", false)
	local scaled = get(instance, "TextScaled", false) and not (autoX or autoY)
	local availW, availH = math.max(w - left - right, 0), math.max(h - top - bottom, 0)

	local limit = nil
	if autoX then
		-- Growing text stops at an explicit maximum width, or at the parent when wrapping.
		local max = mods.UISizeConstraint and mods.UISizeConstraint.MaxSize.X * scale or math.huge
		if wrapped then
			max = math.min(max, pw)
		end
		limit = max < math.huge and math.max(max - left - right, 0) or nil
	elseif wrapped or scaled then
		limit = availW
	end
	if scaled then
		local bounds = mods.UITextSizeConstraint
		local min = math.max(bounds and bounds.MinTextSize or 1, 1)
		local max = math.min(bounds and bounds.MaxTextSize or 100, 100)
		spec.size = Text.fit(spec, availW, availH, min, math.max(min, max), scale)
	end
	info.text = { spec = spec, block = Text.layout(spec, limit, not scaled), placeholder = placeholder }
	return info.text.block.width + left + right, info.text.block.height + top + bottom
end

local function finishText(info)
	local instance, text, pad = info.instance, info.text, info.padding
	local block, spec = text.block, text.spec
	local availW, availH = info.w - pad[1] - pad[3], info.h - pad[2] - pad[4]
	text.fits = block.width <= availW + 0.5 and block.height <= availH + 0.5
	if not text.fits and get(instance, "TextTruncate", { Name = "None" }).Name ~= "None" then
		local lineHeight = spec.size * spec.lineHeight
		Text.truncate(block, spec, availW, math.max(1, math.floor((availH + 0.5) / lineHeight)))
	end
	local visible = get(instance, "MaxVisibleGraphemes", -1)
	if visible >= 0 then
		Text.reveal(block, visible)
		text.revealed = true
	end
end

local compute

local function sortedItems(info, layout)
	local items = {}
	for index, child in info.children do
		child.index = index
		if child.visible then
			table.insert(items, child)
		end
	end
	local byName = layout.SortOrder.Name == "Name"
	table.sort(items, function(a, b)
		if byName and a.name ~= b.name then
			return a.name < b.name
		elseif not byName and a.order ~= b.order then
			return a.order < b.order
		end
		return a.index < b.index
	end)
	return items
end

local function flexRatios(item, layoutFlex)
	local flexItem = item.mods.UIFlexItem
	local mode = flexItem and flexItem.FlexMode.Name or "None"
	if mode == "Fill" then
		return 1, 1
	elseif mode == "Grow" then
		return 1, 0
	elseif mode == "Shrink" then
		return 0, 1
	elseif mode == "Custom" then
		return flexItem.GrowRatio, flexItem.ShrinkRatio
	elseif layoutFlex == "Fill" then
		return 1, 1
	end
	return 0, 0
end

-- measureX / measureY: that axis is being sized from its content, so nothing
-- may stretch, shrink or wrap along it yet.
local function arrangeList(nodes, info, list, cw, ch, measureX, measureY)
	local scale, pad = info.scale, info.padding
	local horizontal = list.FillDirection.Name == "Horizontal"
	local mainAvail, crossAvail = cw, ch
	local measureMain, measureCross = measureX, measureY
	local mainFlex, crossFlex = get(list, "HorizontalFlex", ALIGN).Name, get(list, "VerticalFlex", ALIGN).Name
	local mainAlign, crossAlign = ALIGN[list.HorizontalAlignment.Name], ALIGN[list.VerticalAlignment.Name]
	if not horizontal then
		mainAvail, crossAvail = ch, cw
		measureMain, measureCross = measureY, measureX
		mainFlex, crossFlex = crossFlex, mainFlex
		mainAlign, crossAlign = crossAlign, mainAlign
	end
	local gap, crossGap = udim(list.Padding, mainAvail, scale), udim(list.Padding, crossAvail, scale)
	local function main(item)
		return horizontal and item.w or item.h
	end
	local function cross(item)
		return horizontal and item.h or item.w
	end
	local function resize(item, mainSize, crossSize)
		if horizontal then
			compute(nodes, item, cw, ch, scale, mainSize, crossSize)
		else
			compute(nodes, item, cw, ch, scale, crossSize, mainSize)
		end
	end

	local lines, line = {}, nil
	local wraps = get(list, "Wraps", false) and not measureMain
	for _, item in sortedItems(info, list) do
		compute(nodes, item, cw, ch, scale)
		local size = main(item)
		if not line or (wraps and line.main + gap + size > mainAvail + EPS) then
			line = { items = {}, main = -gap, cross = 0 }
			table.insert(lines, line)
		end
		line.main += gap + size
		table.insert(line.items, item)
	end

	local blockCross = math.max(#lines - 1, 0) * crossGap
	for _, line in lines do
		local free = mainAvail - line.main
		if not measureMain and math.abs(free) > EPS then
			local ratios, total = {}, 0
			for index, item in line.items do
				local grow, shrink = flexRatios(item, mainFlex)
				ratios[index] = free > 0 and grow or shrink
				total += ratios[index]
			end
			if total > 0 then
				for index, item in line.items do
					if ratios[index] > 0 then
						resize(item, math.max(main(item) + free * ratios[index] / total, 0), nil)
					end
				end
				line.main = mainAvail
			end
		end
		for _, item in line.items do
			if crossFlex == "Fill" and not measureCross then
				resize(item, main(item), (crossAvail - blockCross) / #lines)
			end
			line.cross = math.max(line.cross, cross(item))
		end
	end
	for _, line in lines do
		blockCross += line.cross
	end

	local crossCursor, extent = (crossAvail - blockCross) * crossAlign, 0
	for _, line in lines do
		local count, free = #line.items, mainAvail - line.main
		local cursor, between = free * mainAlign, gap
		if free > 0 and not measureMain then
			if mainFlex == "SpaceBetween" and count > 1 then
				cursor, between = 0, gap + free / (count - 1)
			elseif mainFlex == "SpaceAround" then
				cursor, between = free / count / 2, gap + free / count
			elseif mainFlex == "SpaceEvenly" then
				cursor, between = free / (count + 1), gap + free / (count + 1)
			end
		end
		for _, item in line.items do
			local across = crossCursor + (line.cross - cross(item)) * crossAlign
			item.rx = pad[1] + (horizontal and cursor or across)
			item.ry = pad[2] + (horizontal and across or cursor)
			cursor += main(item) + between
		end
		extent = math.max(extent, line.main)
		crossCursor += line.cross + crossGap
	end
	if horizontal then
		return extent, blockCross
	end
	return blockCross, extent
end

local function arrangeGrid(nodes, info, grid, cw, ch, measureX, measureY)
	local scale, pad = info.scale, info.padding
	local items = sortedItems(info, grid)
	local cellW, cellH = udim(grid.CellSize.X, cw, scale), udim(grid.CellSize.Y, ch, scale)
	local gapX, gapY = udim(grid.CellPadding.X, cw, scale), udim(grid.CellPadding.Y, ch, scale)
	local horizontal = grid.FillDirection.Name == "Horizontal"
	local count, perLine = #items, grid.FillDirectionMaxCells
	local avail, cell, gap = cw, cellW, gapX
	if not horizontal then
		avail, cell, gap = ch, cellH, gapY
	end
	if (horizontal and measureX) or (not horizontal and measureY) then
		perLine = perLine > 0 and perLine or math.max(count, 1)
	else
		local fit = math.max(1, math.floor((avail + gap + EPS) / math.max(cell + gap, EPS)))
		perLine = perLine > 0 and math.min(perLine, fit) or fit
	end
	local lineCount = math.ceil(count / perLine)
	local columns = horizontal and math.min(count, perLine) or lineCount
	local rows = horizontal and lineCount or math.min(count, perLine)
	local blockW = columns * cellW + math.max(columns - 1, 0) * gapX
	local blockH = rows * cellH + math.max(rows - 1, 0) * gapY
	local alignX, alignY = ALIGN[grid.HorizontalAlignment.Name], ALIGN[grid.VerticalAlignment.Name]
	local corner = grid.StartCorner.Name
	for index, item in items do
		local along, across = (index - 1) % perLine, (index - 1) // perLine
		-- A short last line is aligned on its own, as Roblox does.
		local inLine = math.min(perLine, count - across * perLine)
		local column, row = along, across
		local lineW, lineH = inLine * (cellW + gapX) - gapX, blockH
		if not horizontal then
			column, row = across, along
			lineW, lineH = blockW, inLine * (cellH + gapY) - gapY
		end
		if corner:find("Right") then
			column = (horizontal and inLine or columns) - 1 - column
		end
		if corner:find("Bottom") then
			row = (horizontal and rows or inLine) - 1 - row
		end
		compute(nodes, item, cw, ch, scale, cellW, cellH)
		item.rx = pad[1] + (cw - lineW) * alignX + column * (cellW + gapX)
		item.ry = pad[2] + (ch - lineH) * alignY + row * (cellH + gapY)
	end
	return blockW, blockH
end

-- Positions the children of a node of size w x h; returns the content extent
-- including padding (what AutomaticSize grows to).
local function arrange(nodes, info, w, h, measureX, measureY)
	local mods, scale = info.mods, info.scale
	local left, top, right, bottom = padding(info, w, h)
	info.padding = { left, top, right, bottom }
	local cw, ch = math.max(w - left - right, 0), math.max(h - top - bottom, 0)
	if info.class == "ScrollingFrame" then
		-- Children of a scrolling frame are laid out against its canvas.
		local canvas = info.instance.CanvasSize
		cw = math.max(cw, udim(canvas.X, w, scale) - left - right)
		ch = math.max(ch, udim(canvas.Y, h, scale) - top - bottom)
	end

	local layout = mods.UIListLayout or mods.UIGridLayout
	local ex, ey = 0, 0
	if mods.UIListLayout then
		ex, ey = arrangeList(nodes, info, layout, cw, ch, measureX, measureY)
	elseif layout then
		ex, ey = arrangeGrid(nodes, info, layout, cw, ch, measureX, measureY)
	end
	for _, child in info.children do
		if layout and not child.visible then
			compute(nodes, child, cw, ch, scale)
			child.rx, child.ry = left, top
		elseif not layout then
			compute(nodes, child, cw, ch, scale)
			child.rx = left + udim(child.position.X, cw, scale) - child.anchor.X * child.w
			child.ry = top + udim(child.position.Y, ch, scale) - child.anchor.Y * child.h
			if child.visible then
				ex = math.max(ex, child.rx - left + child.w)
				ey = math.max(ey, child.ry - top + child.h)
			end
		end
	end
	info.contentSize = { ex, ey }
	return ex + left + right, ey + top + bottom
end

-- Resolves the size of a GuiObject inside a parent content box of pw x ph and
-- lays out its subtree. forcedW / forcedH come from grid cells and flex.
function compute(nodes, info, pw, ph, parentScale, forcedW, forcedH)
	local mods = info.mods
	local own = mods.UIScale and get(mods.UIScale, "Scale", 1) or 1
	info.scale = parentScale * own
	-- A UIScale multiplies the whole resolved size of its parent, scale part included.
	local w = forcedW or udim(info.size.X, pw, parentScale) * own
	local h = forcedH or udim(info.size.Y, ph, parentScale) * own
	if not (forcedW and forcedH) then
		w, h = constrain(info, w, h, pw, ph)
	end
	local autoX = (info.auto == "X" or info.auto == "XY") and not forcedW
	local autoY = (info.auto == "Y" or info.auto == "XY") and not forcedH

	local textW, textH = 0, 0
	if TEXT_CLASSES[info.class] then
		textW, textH = measureText(info, w, h, autoX, autoY, pw)
	end
	local extentX, extentY = arrange(nodes, info, w, h, autoX, autoY)
	if autoX or autoY then
		-- Size acts as the minimum; the content pass above ran against that minimum.
		w = autoX and math.max(w, extentX, textW) or w
		h = autoY and math.max(h, extentY, textH) or h
		w, h = constrain(info, w, h, pw, ph, true)
		arrange(nodes, info, w, h, false, false)
	end
	info.w, info.h = w, h
	if info.text then
		finishText(info)
	end
	return info
end

local function place(info, x, y, inset)
	local instance = info.instance
	info.x, info.y = x + info.rx, y + info.ry
	if instance then
		-- Roblox reports positions relative to the area below the top bar.
		set(instance, "AbsolutePosition", roblox.Vector2.new(info.x, info.y - inset))
		set(instance, "AbsoluteSize", roblox.Vector2.new(info.w, info.h))
		if info.text then
			local block = info.text.block
			set(instance, "TextBounds", roblox.Vector2.new(math.ceil(block.width), math.ceil(block.height)))
			set(instance, "TextFits", info.text.fits)
		end
		local layout = info.mods.UIListLayout or info.mods.UIGridLayout
		if layout then
			set(layout, "AbsoluteContentSize", roblox.Vector2.new(info.contentSize[1], info.contentSize[2]))
		end
	end
	for _, child in info.children do
		place(child, info.x, info.y, inset)
	end
end

-- Returns the node table keyed by instance and the root nodes in draw order.
function Layout.run(roots, width, height, options)
	local inset = options and options.topInset or 58
	local nodes, order = {}, {}
	for index, root in roots do
		local info
		if root:IsA("GuiObject") then
			-- A bare GuiObject is laid out as if the viewport were its parent.
			info = { name = "Root", class = "Root", children = {}, mods = {}, visible = true, zIndex = 1, rotation = 0 }
			info.children[1] = scan(nodes, root, info)
			info.rx, info.ry, info.w, info.h, info.scale = 0, 0, width, height, 1
		else
			info = scan(nodes, root, nil)
			local insetTop = (info.class == "ScreenGui" and not get(root, "IgnoreGuiInset", false)) and inset or 0
			info.ry, info.w, info.h = insetTop, width, height - insetTop
			info.scale = info.mods.UIScale and get(info.mods.UIScale, "Scale", 1) or 1
		end
		info.index, info.order = index, get(root, "DisplayOrder", 0)
		arrange(nodes, info, info.w, info.h, false, false)
		place(info, 0, 0, inset)
		table.insert(order, info)
	end
	table.sort(order, function(a, b)
		if a.order ~= b.order then
			return a.order < b.order
		end
		return a.index < b.index
	end)
	return nodes, order
end

return Layout
