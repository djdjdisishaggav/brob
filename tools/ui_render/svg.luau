-- Serialises laid-out nodes as layered, editable SVG: one <g> per instance,
-- real rects, gradients and clip paths in <defs>, and text as <text>.
local Fonts = require("./fonts")
local Layout = require("./layout")

local get, ALIGN = Layout.get, Layout.ALIGN

local Svg = {}

local DEFAULT_BACKGROUND = { "#40566a", "#2f4a40", "#1b2821", angle = 90 }
local ANCHOR = { [0] = "start", [0.5] = "middle", [1] = "end" }
local JOIN = { Round = "round", Miter = "miter", Bevel = "bevel" }

local function num(value)
	local text = string.format("%.2f", value):gsub("%.?0+$", "")
	return (text == "-0" or text == "") and "0" or text
end

local function hexRgb(r, g, b)
	return string.format("#%02x%02x%02x", math.round(r * 255), math.round(g * 255), math.round(b * 255))
end

local function hex(color)
	return hexRgb(color.R, color.G, color.B)
end

local function escape(text)
	return (tostring(text):gsub('[&<>"]', { ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;", ['"'] = "&quot;" }))
end

local function emit(ctx, depth, line)
	table.insert(ctx.out, string.rep("  ", depth) .. line)
end

local function uniqueId(ctx, name)
	local id = name:gsub("[^%w_%-]", "_")
	if not id:match("^%a") then
		id = "_" .. id
	end
	local candidate, count = id, 1
	while ctx.used[candidate] do
		count += 1
		candidate = `{id}-{count}`
	end
	ctx.used[candidate] = true
	return candidate
end

local function rectAttrs(x, y, w, h, radius)
	local attrs = `x="{num(x)}" y="{num(y)}" width="{num(w)}" height="{num(h)}"`
	return radius > 0 and `{attrs} rx="{num(radius)}"` or attrs
end

local function opacityAttr(name, value)
	return value < 0.999 and ` {name}="{num(value)}"` or ""
end

local function sample(keypoints, time)
	local a, b = keypoints[1], keypoints[#keypoints]
	for index = 1, #keypoints - 1 do
		if time <= keypoints[index + 1].Time then
			a, b = keypoints[index], keypoints[index + 1]
			break
		end
	end
	local span = b.Time - a.Time
	return a.Value, b.Value, span > 0 and math.clamp((time - a.Time) / span, 0, 1) or 1
end

local function gradientLine(box, degrees, offsetX, offsetY)
	local angle = math.rad(degrees)
	local dx, dy = math.cos(angle), math.sin(angle)
	local half = (math.abs(box.w * dx) + math.abs(box.h * dy)) / 2
	local cx, cy = box.x + box.w * (0.5 + offsetX), box.y + box.h * (0.5 + offsetY)
	local from, to = `x1="{num(cx - dx * half)}" y1="{num(cy - dy * half)}"`, `x2="{num(cx + dx * half)}" y2="{num(cy + dy * half)}"`
	return `gradientUnits="userSpaceOnUse" {from} {to}`
end

-- Fill value and opacity for a colour, multiplied by a UIGradient spanning `box` when there is one.
local function paint(ctx, gradient, color, alpha, box)
	if not gradient then
		return hex(color), alpha
	end
	local colors, alphas = gradient.Color.Keypoints, gradient.Transparency.Keypoints
	local times, seen = {}, {}
	for _, keypoints in { colors, alphas } do
		for _, key in keypoints do
			if not seen[key.Time] then
				seen[key.Time] = true
				table.insert(times, key.Time)
			end
		end
	end
	table.sort(times)
	local stops = {}
	for _, time in times do
		local a, b, t = sample(colors, time)
		local r, g, bl = a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t
		local from, to, u = sample(alphas, time)
		local opacity = (1 - (from + (to - from) * u)) * alpha
		local stopColor = hexRgb(r * color.R, g * color.G, bl * color.B)
		table.insert(stops, `<stop offset="{num(time)}" stop-color="{stopColor}"{opacityAttr("stop-opacity", opacity)}/>`)
	end
	local id = uniqueId(ctx, "paint")
	local line = gradientLine(box, gradient.Rotation, gradient.Offset.X, gradient.Offset.Y)
	table.insert(ctx.defs, `<linearGradient id="{id}" {line}>{table.concat(stops)}</linearGradient>`)
	return `url(#{id})`, 1
end

local function cornerRadius(info)
	local corner = info.mods.UICorner
	if not corner then
		return 0
	end
	local radius, short = get(corner, "CornerRadius", nil), math.min(info.w, info.h)
	local value = radius and (radius.Scale * short + radius.Offset * info.scale) or 8 * info.scale
	return math.clamp(value, 0, short / 2)
end

local function fontAttrs(font, size)
	local attrs = `font-family="{font.css}" font-weight="{font.weight}" font-size="{num(Fonts.emSize(font, size))}"`
	return font.cssStyle == "italic" and attrs .. ' font-style="italic"' or attrs
end

local function drawText(ctx, info, depth)
	local instance, text = info.instance, info.text
	local block, spec = text.block, text.spec
	local alpha = 1 - get(instance, "TextTransparency", 0)
	if #block.lines == 0 or alpha <= 0 then
		return
	end
	local pad = info.padding
	local left, top = info.x + pad[1], info.y + pad[2]
	local width, height = info.w - pad[1] - pad[3], info.h - pad[2] - pad[4]
	local alignX = ALIGN[get(instance, "TextXAlignment", ALIGN).Name] or 0.5
	local alignY = ALIGN[get(instance, "TextYAlignment", ALIGN).Name] or 0.5
	local font = Fonts.get(spec.family, spec.weight, spec.italic)
	local color = text.placeholder and get(instance, "PlaceholderColor3", nil) or instance.TextColor3
	local fill, opacity = paint(ctx, info.mods.UIGradient, color, alpha, info)
	-- Revealed text keeps its final position, so it cannot be re-centred by the anchor.
	local anchor = text.revealed and "start" or ANCHOR[alignX]
	local attrs = `{fontAttrs(font, spec.size)} fill="{fill}"{opacityAttr("fill-opacity", opacity)} text-anchor="{anchor}"`

	local stroke = info.mods.UIStroke
	local legacy = 1 - get(instance, "TextStrokeTransparency", 1)
	if stroke and stroke.ApplyStrokeMode.Name == "Contextual" and stroke.Thickness > 0 then
		local outline, outlineOpacity = paint(ctx, info.strokeGradient, stroke.Color, 1 - stroke.Transparency, info)
		-- Half of an SVG stroke sits under the glyph, so it is drawn at twice the thickness.
		local width2 = num(stroke.Thickness * info.scale * 2)
		attrs ..= ` stroke="{outline}" stroke-width="{width2}"{opacityAttr("stroke-opacity", outlineOpacity)}`
		attrs ..= ` stroke-linejoin="{JOIN[stroke.LineJoinMode.Name] or "round"}" paint-order="stroke"`
	elseif legacy > 0 then
		attrs ..= ` stroke="{hex(instance.TextStrokeColor3)}" stroke-width="{num(2 * info.scale)}"`
		attrs ..= `{opacityAttr("stroke-opacity", legacy)} stroke-linejoin="round" paint-order="stroke"`
	end

	-- Preserved whitespace counts towards the anchored width, so the element stays on one line.
	local spans = {}
	local lineTop = top + (height - block.height) * alignY
	local ascent = font.top / (font.top + font.bottom)
	for _, line in block.lines do
		local baseline = lineTop + (line.height - line.size) / 2 + line.size * ascent
		local x = text.revealed and left + (width - line.width) * alignX or left + width * alignX
		local parts = {}
		for _, piece in line.pieces do
			local style, override = piece.style, ""
			if style.bold then
				override ..= ` font-weight="{math.max(spec.weight, 700)}"`
			end
			if style.italic then
				override ..= ' font-style="italic"'
			end
			if style.color then
				override ..= ` fill="{style.color}"`
			end
			if style.size then
				override ..= ` font-size="{num(Fonts.emSize(piece.font, piece.size))}"`
			end
			if style.underline or style.strike then
				local lines = (style.underline and "underline " or "") .. (style.strike and "line-through" or "")
				override ..= ` text-decoration="{lines}"`
			end
			local content = escape(piece.text)
			table.insert(parts, override == "" and content or `<tspan{override}>{content}</tspan>`)
		end
		table.insert(spans, `<tspan x="{num(x)}" y="{num(baseline)}">{table.concat(parts)}</tspan>`)
		lineTop += line.height
	end
	emit(ctx, depth, `<text {attrs} xml:space="preserve">{table.concat(spans)}</text>`)
end

local function drawStroke(ctx, info, depth, radius)
	local stroke = info.mods.UIStroke
	if not stroke or (info.text and stroke.ApplyStrokeMode.Name == "Contextual") then
		return
	end
	local thickness, alpha = stroke.Thickness * info.scale, 1 - stroke.Transparency
	if thickness <= 0 or alpha <= 0 then
		return
	end
	-- Roblox draws the border outside the element; the SVG stroke is centred on its path.
	local position = get(stroke, "BorderStrokePosition", ALIGN).Name
	local grow = (position == "Inner" and -thickness or position == "Center" and 0 or thickness) / 2
	local join = stroke.LineJoinMode.Name
	local rounded = radius > 0 and math.max(radius + grow, 0) or (join == "Round" and math.max(grow, 0) or 0)
	local outer = { x = info.x - grow * 2, y = info.y - grow * 2, w = info.w + grow * 4, h = info.h + grow * 4 }
	local color, opacity = paint(ctx, info.strokeGradient, stroke.Color, alpha, outer)
	local shape = rectAttrs(info.x - grow, info.y - grow, info.w + grow * 2, info.h + grow * 2, rounded)
	local attrs = `fill="none" stroke="{color}" stroke-width="{num(thickness)}"{opacityAttr("stroke-opacity", opacity)}`
	if rounded == 0 and join ~= "Miter" then
		attrs ..= ` stroke-linejoin="{JOIN[join] or "round"}"`
	end
	emit(ctx, depth, `<rect {shape} {attrs}/>`)
end

local drawNode

local function drawChildren(ctx, info, depth)
	local sorted = table.clone(info.children)
	for index, child in sorted do
		child.index = index
	end
	table.sort(sorted, function(a, b)
		if a.zIndex ~= b.zIndex then
			return a.zIndex < b.zIndex
		end
		return a.index < b.index
	end)
	for _, child in sorted do
		drawNode(ctx, child, depth)
	end
end

function drawNode(ctx, info, depth)
	if not info.visible then
		return
	end
	local instance, class = info.instance, info.class
	local x, y, w, h = info.x, info.y, info.w, info.h
	local attrs = `id="{uniqueId(ctx, info.name)}" data-name="{escape(info.name)}" data-class="{class}"`
	if info.rotation ~= 0 then
		attrs ..= ` transform="rotate({num(info.rotation)} {num(x + w / 2)} {num(y + h / 2)})"`
	end
	if class == "CanvasGroup" then
		attrs ..= opacityAttr("opacity", 1 - get(instance, "GroupTransparency", 0))
	end
	emit(ctx, depth, `<g {attrs}>`)

	local radius = cornerRadius(info)
	local shape = rectAttrs(x, y, w, h, radius)
	local drawable = w > 0 and h > 0
	local alpha = 1 - get(instance, "BackgroundTransparency", 0)
	if alpha > 0 and drawable then
		local fill, opacity = paint(ctx, info.mods.UIGradient, instance.BackgroundColor3, alpha, info)
		emit(ctx, depth + 1, `<rect {shape} fill="{fill}"{opacityAttr("fill-opacity", opacity)}/>`)
	end

	if (class == "ImageLabel" or class == "ImageButton") and drawable then
		local image, tint = get(instance, "Image", ""), get(instance, "ImageColor3", nil)
		local imageAlpha = 1 - get(instance, "ImageTransparency", 0)
		if image ~= "" and imageAlpha > 0 then
			-- Image pixels are not available offline: a tinted block with a cross marks the slot.
			local r, g, b = tint and tint.R or 1, tint and tint.G or 1, tint and tint.B or 1
			local mark = (r * 0.3 + g * 0.6 + b * 0.1) > 0.5 and "#000000" or "#ffffff"
			local cross = `M{num(x)} {num(y)}L{num(x + w)} {num(y + h)}M{num(x + w)} {num(y)}L{num(x)} {num(y + h)}`
			local tinted = `fill="{hexRgb(r, g, b)}"{opacityAttr("fill-opacity", imageAlpha * 0.7)}`
			emit(ctx, depth + 1, `<rect {shape} {tinted} data-image="{escape(image)}"/>`)
			emit(ctx, depth + 1, `<path d="{cross}" stroke="{mark}" stroke-opacity="{num(imageAlpha * 0.25)}" fill="none"/>`)
		end
	elseif class == "ViewportFrame" and drawable then
		if not ctx.hatch then
			ctx.hatch = uniqueId(ctx, "viewport-hatch")
			local stripe = '<rect width="7" height="14" fill="#ffffff" fill-opacity="0.07"/>'
			local pattern = 'width="14" height="14" patternUnits="userSpaceOnUse" patternTransform="rotate(45)"'
			table.insert(ctx.defs, `<pattern id="{ctx.hatch}" {pattern}>{stripe}</pattern>`)
		end
		local caption = fontAttrs(Fonts.get("Nunito", 700, false), math.min(h / 4, 16 * info.scale))
		emit(ctx, depth + 1, `<rect {shape} fill="url(#{ctx.hatch})"/>`)
		emit(
			ctx,
			depth + 1,
			`<text x="{num(x + w / 2)}" y="{num(y + h / 2)}" {caption} dominant-baseline="central" text-anchor="middle" fill="#ffffff" fill-opacity="0.6">3D preview</text>`
		)
	end

	drawStroke(ctx, info, depth + 1, radius)

	-- Roblox clips to the plain rectangle; only a CanvasGroup follows its UICorner.
	local clips = class == "CanvasGroup" or get(instance, "ClipsDescendants", false)
	local inner = depth + 1
	if clips then
		local id = uniqueId(ctx, "clip")
		local rounded = (class == "CanvasGroup" or ctx.options.roundedClip) and radius or 0
		table.insert(ctx.defs, `<clipPath id="{id}"><rect {rectAttrs(x, y, w, h, rounded)}/></clipPath>`)
		emit(ctx, depth + 1, `<g clip-path="url(#{id})">`)
		inner = depth + 2
	end
	if info.text then
		drawText(ctx, info, inner)
	end
	drawChildren(ctx, info, inner)
	if clips then
		emit(ctx, depth + 1, "</g>")
	end
	emit(ctx, depth, "</g>")
end

-- options: background (CSS colour, or a list of colours with an optional
-- `angle`), title, roundedClip, showTopbar.
function Svg.render(order, width, height, options)
	local ctx = { out = {}, defs = {}, used = {}, options = options }
	local background = options.background or DEFAULT_BACKGROUND
	local fill = background
	if type(background) == "table" then
		local id, stops = uniqueId(ctx, "world"), {}
		for index, color in ipairs(background) do
			local offset = #background > 1 and (index - 1) / (#background - 1) or 0
			table.insert(stops, `<stop offset="{num(offset)}" stop-color="{color}"/>`)
		end
		local line = gradientLine({ x = 0, y = 0, w = width, h = height }, background.angle or 90, 0, 0)
		table.insert(ctx.defs, `<linearGradient id="{id}" {line}>{table.concat(stops)}</linearGradient>`)
		fill = `url(#{id})`
	end
	emit(ctx, 1, `<rect id="{uniqueId(ctx, "World")}" width="{num(width)}" height="{num(height)}" fill="{fill}"/>`)

	for _, root in order do
		if root.visible then
			local id = uniqueId(ctx, root.name)
			emit(ctx, 1, `<g id="{id}" data-name="{escape(root.name)}" data-class="{root.class}">`)
			drawChildren(ctx, root, 2)
			emit(ctx, 1, "</g>")
		end
	end
	if options.showTopbar then
		-- Approximate footprint of Roblox's own top-left buttons, to spot HUD collisions.
		emit(ctx, 1, '<g id="RobloxTopbar" fill="#101214" fill-opacity="0.55">')
		emit(ctx, 2, '<rect x="12" y="7" width="44" height="44" rx="22"/><rect x="64" y="7" width="44" height="44" rx="22"/>')
		emit(ctx, 1, "</g>")
	end

	local size = `width="{num(width)}" height="{num(height)}" viewBox="0 0 {num(width)} {num(height)}"`
	local head = {
		-- Kerning is off because the layout measures plain advance widths.
		`<svg xmlns="http://www.w3.org/2000/svg" {size} style="font-kerning:none;font-variant-ligatures:none">`,
		`  <title>{escape(options.title or "Roblox UI render")}</title>`,
		"  <defs>",
	}
	for _, def in ctx.defs do
		table.insert(head, "    " .. def)
	end
	table.insert(head, "  </defs>")
	return table.concat(head, "\n") .. "\n" .. table.concat(ctx.out, "\n") .. "\n</svg>\n"
end

return Svg
