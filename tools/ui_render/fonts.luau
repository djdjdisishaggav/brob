-- Font files and metrics. Static TTFs come from the Fontsource CDN on demand
-- and are cached in tools/.cache/fonts; only the tables needed for horizontal
-- metrics are parsed (head, hhea, hmtx, cmap).
local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")

local Fonts = {}

local SOURCE = "https://cdn.jsdelivr.net/fontsource/fonts/%s@latest/latin-%d-%s.ttf"

-- Roblox sizes text by the font's overall glyph box, not its em square:
-- TextSize is the pixel distance between `top` and `bottom` (font units per
-- 1000 em, taken from the full upstream fonts because the latin subsets
-- downloaded here have a recalculated, smaller box).
local FAMILIES = {
	FredokaOne = { css = "Fredoka One", id = "fredoka-one", weights = { 400 }, top = 974, bottom = 236 },
	Nunito = {
		css = "Nunito",
		id = "nunito",
		weights = { 200, 300, 400, 500, 600, 700, 800, 900 },
		italic = true,
		top = 1011,
		bottom = 353,
	},
	Montserrat = {
		css = "Montserrat",
		id = "montserrat",
		weights = { 100, 200, 300, 400, 500, 600, 700, 800, 900 },
		italic = true,
		top = 968,
		bottom = 251,
	},
}
-- Anything not listed renders with Montserrat, the face Roblox itself
-- substitutes for Gotham.
local FALLBACK = "Montserrat"
Fonts.FAMILIES = FAMILIES

local function findRoot()
	local dir = process.cwd:gsub("[/\\]+$", "")
	local probe = dir
	while probe ~= "" do
		if fs.isFile(probe .. "/rokit.toml") then
			return probe
		end
		probe = probe:match("^(.*)/[^/]*$") or ""
	end
	return dir
end

Fonts.root = findRoot()
Fonts.cacheDir = Fonts.root .. "/tools/.cache/fonts"

local function parse(bytes)
	local b = buffer.fromstring(bytes)
	local function u16(o)
		return buffer.readu8(b, o) * 256 + buffer.readu8(b, o + 1)
	end
	local function i16(o)
		local v = u16(o)
		return v >= 32768 and v - 65536 or v
	end
	local function u32(o)
		return u16(o) * 65536 + u16(o + 2)
	end

	local tables = {}
	for i = 0, u16(4) - 1 do
		local record = 12 + i * 16
		tables[buffer.readstring(b, record, 4)] = u32(record + 8)
	end
	local head, hhea, hmtx, cmap = tables.head, tables.hhea, tables.hmtx, tables.cmap
	assert(head and hhea and hmtx and cmap, "not a TrueType font with horizontal metrics")

	local font = {
		unitsPerEm = u16(head + 18),
		yMin = i16(head + 38),
		yMax = i16(head + 42),
		ascender = i16(hhea + 4),
		descender = i16(hhea + 6),
		advances = {},
	}
	local metricCount = u16(hhea + 34)
	local function advanceOf(glyph)
		return u16(hmtx + math.min(glyph, metricCount - 1) * 4)
	end

	-- Prefer a full-range (format 12) Unicode subtable, else a BMP (format 4) one.
	local best, bestRank = nil, 0
	for i = 0, u16(cmap + 2) - 1 do
		local record = cmap + 4 + i * 8
		local platform, offset = u16(record), cmap + u32(record + 4)
		local format = u16(offset)
		local unicode = platform == 0 or platform == 3
		local rank = (unicode and format == 12 and 2) or (unicode and format == 4 and 1) or 0
		if rank > bestRank then
			best, bestRank = offset, rank
		end
	end
	assert(best, "font has no Unicode cmap")

	local advances = font.advances
	if bestRank == 2 then
		for group = 0, u32(best + 12) - 1 do
			local record = best + 16 + group * 12
			local first, last, glyph = u32(record), u32(record + 4), u32(record + 8)
			for code = first, last do
				advances[code] = advanceOf(glyph + code - first)
			end
		end
	else
		local span = u16(best + 6)
		local ends, starts = best + 14, best + 16 + span
		local deltas, ranges = starts + span, starts + span * 2
		for s = 0, span - 2, 2 do
			local first, last, delta, range = u16(starts + s), u16(ends + s), u16(deltas + s), u16(ranges + s)
			for code = first, math.min(last, 0xFFFE) do
				local glyph
				if range == 0 then
					glyph = (code + delta) % 65536
				else
					glyph = u16(ranges + s + range + (code - first) * 2)
					glyph = glyph ~= 0 and (glyph + delta) % 65536 or 0
				end
				if glyph ~= 0 then
					advances[code] = advanceOf(glyph)
				end
			end
		end
	end
	return font
end
Fonts.parse = parse

local function nearest(list, value)
	local best = list[1]
	for _, candidate in list do
		if math.abs(candidate - value) < math.abs(best - value) then
			best = candidate
		end
	end
	return best
end

local loaded = {}

-- Returns the font for a family key ("Nunito"), numeric weight and italic flag.
function Fonts.get(familyKey, weight, italic)
	local family = FAMILIES[familyKey] or FAMILIES[FALLBACK]
	weight = nearest(family.weights, weight or 400)
	local style = (italic and family.italic) and "italic" or "normal"
	local key = `{family.id}-{weight}-{style}`
	local font = loaded[key]
	if font then
		return font
	end

	local path = `{Fonts.cacheDir}/{key}.ttf`
	if not fs.isFile(path) then
		local url = SOURCE:format(family.id, weight, style)
		local ok, response = pcall(net.request, url)
		if not ok or not response.ok then
			error(`ui_render: could not download {url} ({ok and response.statusCode or response})`)
		end
		fs.writeDir(Fonts.cacheDir)
		fs.writeFile(path, response.body)
	end

	font = parse(fs.readFile(path))
	font.key, font.path = key, path
	font.css, font.weight, font.style = family.css, weight, style
	-- Italic or bold requested from a family without that face: the browser synthesises it.
	font.cssStyle = italic and "italic" or "normal"
	local unit = font.unitsPerEm / 1000
	font.top, font.bottom = family.top * unit, family.bottom * unit
	font.fallbackAdvance = font.advances[0x6E] or font.unitsPerEm * 0.6
	loaded[key] = font
	return font
end

local WEIGHTS = {
	Thin = 100,
	ExtraLight = 200,
	Light = 300,
	Regular = 400,
	Medium = 500,
	SemiBold = 600,
	Bold = 700,
	ExtraBold = 800,
	Heavy = 900,
}

-- Resolves a Roblox Font datatype (or nil) to a family key, weight and italic flag.
function Fonts.describe(fontFace)
	if not fontFace then
		return FALLBACK, 400, false
	end
	local key = tostring(fontFace.Family):match("([%w_%-]+)%.json$") or FALLBACK
	local weight = fontFace.Weight
	weight = WEIGHTS[type(weight) == "string" and weight or weight.Name] or 400
	local style = fontFace.Style
	return key, weight, (type(style) == "string" and style or style.Name) == "Italic"
end

-- CSS px font size that makes the font's glyph box `textSize` pixels tall.
function Fonts.emSize(font, textSize)
	return textSize * font.unitsPerEm / (font.top + font.bottom)
end

function Fonts.width(font, text, textSize)
	local total, advances, fallback = 0, font.advances, font.fallbackAdvance
	for _, code in utf8.codes(text) do
		total += advances[code] or fallback
	end
	return total * textSize / (font.top + font.bottom)
end

-- @font-face rules for every cached font file, for the HTML screenshot wrapper.
function Fonts.fontFaceCss()
	local byId, rules = {}, {}
	for _, family in FAMILIES do
		byId[family.id] = family.css
	end
	local names = fs.isDir(Fonts.cacheDir) and fs.readDir(Fonts.cacheDir) or {}
	table.sort(names)
	for _, name in names do
		local id, weight, style = name:match("^(.-)%-(%d+)%-(%a+)%.ttf$")
		if id and byId[id] then
			local src = `file://{Fonts.cacheDir}/{name}`
			local face = `font-family:"{byId[id]}";font-weight:{weight};font-style:{style};src:url("{src}")`
			table.insert(rules, `@font-face \{{face}}`)
		end
	end
	return table.concat(rules, "\n")
end

return Fonts
