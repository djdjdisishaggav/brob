-- Headless renderer for Roblox GUI trees: lays the tree out the way Roblox
-- would, writes the computed rectangles back onto the instances and serialises
-- the result as SVG (and PNG through headless Chrome). See README.md.
local fs = require("@lune/fs")
local process = require("@lune/process")

local Fonts = require("@self/fonts")
local Layout = require("@self/layout")
local Svg = require("@self/svg")
local Text = require("@self/text")

local Render = {}
Render.Fonts = Fonts

local function rootList(roots)
	local list, out = type(roots) == "table" and roots or { roots }, {}
	for _, root in list do
		if root:IsA("LayerCollector") or root:IsA("GuiObject") then
			table.insert(out, root)
		else
			-- A container such as PlayerGui stands for the ScreenGuis inside it.
			for _, child in root:GetChildren() do
				if child:IsA("LayerCollector") then
					table.insert(out, child)
				end
			end
		end
	end
	return out
end

local function dimensions(viewport)
	if not viewport then
		return 1280, 720
	end
	return viewport.X or viewport[1], viewport.Y or viewport[2]
end

-- Computes every rectangle, writes AbsoluteSize / AbsolutePosition / TextBounds
-- onto the instances and returns `{ [Instance] = node }` plus the root nodes
-- in draw order. A node has x, y, w, h (screen pixels), scale, visible, text.
function Render.layout(roots, viewport, options)
	local width, height = dimensions(viewport)
	return Layout.run(rootList(roots), width, height, options)
end

function Render.toSvg(roots, options)
	options = options or {}
	local width, height = dimensions(options.viewport)
	local nodes, order = Layout.run(rootList(roots), width, height, options)
	return Svg.render(order, width, height, options), nodes
end

local function absolute(path)
	if path:sub(1, 1) == "/" then
		return path
	end
	return process.cwd:gsub("[/\\]+$", "") .. "/" .. path
end

-- Writes `<name>.svg` beside the PNG and screenshots it with headless Chrome.
function Render.writePng(svg, pngPath, width, height, pixelRatio)
	local base = absolute(pngPath):gsub("%.png$", "")
	local pngFile, svgFile, htmlFile = base .. ".png", base .. ".svg", base .. ".render.html"
	fs.writeDir(base:match("^(.*)/[^/]*$"))
	fs.writeFile(svgFile, svg)
	-- The SVG is inlined so the page's @font-face rules apply to its text.
	fs.writeFile(
		htmlFile,
		table.concat({
			'<!doctype html><html><head><meta charset="utf-8"><style>',
			Fonts.fontFaceCss(),
			"html,body{margin:0;overflow:hidden;background:#000}svg{display:block}",
			"</style></head><body>",
			svg,
			"</body></html>",
		}, "\n")
	)
	if fs.isFile(pngFile) then
		fs.removeFile(pngFile)
	end
	local result = process.exec(process.env.CHROME_PATH or "google-chrome", {
		"--headless=new",
		"--no-sandbox",
		"--disable-gpu-sandbox",
		"--use-angle=swiftshader",
		"--enable-unsafe-swiftshader",
		"--hide-scrollbars",
		`--force-device-scale-factor={pixelRatio or 1}`,
		`--window-size={math.ceil(width)},{math.ceil(height)}`,
		"--virtual-time-budget=3000",
		"--screenshot=" .. pngFile,
		"file://" .. htmlFile,
	})
	fs.removeFile(htmlFile)
	if not fs.isFile(pngFile) then
		error(`ui_render: Chrome did not write {pngFile} (exit {result.code})\n{result.stderr}`)
	end
	return pngFile, svgFile
end

-- options: { viewport, path = "build/ui/name.png", background, title, pixelRatio, ... }
function Render.capture(roots, options)
	local width, height = dimensions(options.viewport)
	local svg, nodes = Render.toSvg(roots, options)
	local pngFile, svgFile = Render.writePng(svg, options.path, width, height, options.pixelRatio)
	return { png = pngFile, svg = svgFile, layout = nodes }
end

-- Size of plain text in pixels, wrapped at maxWidth when given.
function Render.measureText(text, textSize, fontFace, maxWidth)
	local family, weight, italic = Fonts.describe(fontFace)
	local spec = {
		family = family,
		weight = weight,
		italic = italic,
		scale = 1,
		size = textSize,
		lineHeight = 1,
		runs = Text.parse(text, false),
	}
	local block = Text.layout(spec, maxWidth, true)
	return math.ceil(block.width), math.ceil(block.height)
end

return Render
