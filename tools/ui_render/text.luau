-- Rich text parsing, line breaking, truncation and TextScaled fitting.
local Fonts = require("./fonts")

local Text = {}

local EPS = 0.01
local ENTITIES = { lt = "<", gt = ">", amp = "&", quot = '"', apos = "'" }
local PLAIN = {}

local function hexColor(value)
	local r, g, b = value:match("rgb%(%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*%)")
	if r then
		return string.format("#%02x%02x%02x", r, g, b)
	end
	return value:match("^#%x%x%x%x%x%x$")
end

-- Splits text into styled runs; `{ br = true }` marks a forced line break.
function Text.parse(text, rich)
	local runs = {}
	local function push(chunk, style)
		local first = true
		for segment in (chunk .. "\n"):gmatch("(.-)\n") do
			if not first then
				table.insert(runs, { br = true })
			end
			first = false
			if segment ~= "" then
				table.insert(runs, { text = segment, style = style })
			end
		end
	end
	if not rich then
		push(text, PLAIN)
		return runs
	end

	local stack, pos = { PLAIN }, 1
	while pos <= #text do
		local open, close = text:find("<[^<>]+>", pos)
		local chunk = text:sub(pos, (open or #text + 1) - 1)
		if chunk ~= "" then
			push((chunk:gsub("&(%a+);", ENTITIES)), stack[#stack])
		end
		if not open then
			break
		end
		local tag = text:sub(open + 1, close - 1)
		local closing, name = tag:match("^(/?)%s*(%a+)")
		name = name and name:lower()
		if name == "br" then
			table.insert(runs, { br = true })
		elseif closing == "/" then
			if #stack > 1 then
				table.remove(stack)
			end
		elseif name then
			-- Unknown tags still push a frame so their closing tag pops the right one.
			local style = table.clone(stack[#stack])
			if name == "b" then
				style.bold = true
			elseif name == "i" then
				style.italic = true
			elseif name == "u" then
				style.underline = true
			elseif name == "s" then
				style.strike = true
			elseif name == "font" then
				local color = tag:match("color%s*=%s*[\"']([^\"']+)[\"']")
				style.color = color and hexColor(color) or style.color
				style.size = tonumber(tag:match("size%s*=%s*[\"']([%d%.]+)[\"']")) or style.size
			end
			table.insert(stack, style)
		end
		pos = close + 1
	end
	return runs
end

local function fontFor(spec, style)
	local weight = style.bold and math.max(spec.weight, 700) or spec.weight
	local font = Fonts.get(spec.family, weight, spec.italic or style.italic or false)
	return font, style.size and style.size * spec.scale or spec.size
end

local function finish(block, spec)
	block.width, block.height = 0, 0
	for _, line in block.lines do
		line.height = line.size * spec.lineHeight
		block.width = math.max(block.width, line.width)
		block.height += line.height
	end
	return block
end

-- spec: { runs, family, weight, italic, size (px), scale, lineHeight }.
-- Wraps at maxWidth when given; breakWords also splits words wider than a line.
function Text.layout(spec, maxWidth, breakWords)
	local lines = {}
	if #spec.runs == 0 then
		return { lines = lines, width = 0, height = 0 }
	end
	local line
	local function newLine()
		line = { pieces = {}, width = 0, size = spec.size }
		table.insert(lines, line)
	end
	local function measure(text, style)
		local font, size = fontFor(spec, style)
		return Fonts.width(font, text, size)
	end
	local function append(text, style)
		local font, size = fontFor(spec, style)
		local width = Fonts.width(font, text, size)
		local last = line.pieces[#line.pieces]
		if last and last.style == style then
			last.text ..= text
			last.width += width
		else
			table.insert(line.pieces, { text = text, style = style, font = font, size = size, width = width })
		end
		line.width += width
		line.size = math.max(line.size, size)
	end
	newLine()

	-- A word may span several runs; spaces are held back so a line never ends with them.
	local word, wordWidth, spaces, spaceWidth = {}, 0, {}, 0
	local function flush()
		if #word == 0 then
			return
		end
		if maxWidth and line.width > 0 and line.width + spaceWidth + wordWidth > maxWidth + EPS then
			newLine()
			spaces = {}
		end
		for _, part in spaces do
			append(part.text, part.style)
		end
		spaces, spaceWidth = {}, 0
		local splitting = maxWidth and breakWords and line.width + wordWidth > maxWidth + EPS
		for _, part in word do
			if splitting then
				for _, code in utf8.codes(part.text) do
					local char = utf8.char(code)
					if line.width > 0 and line.width + measure(char, part.style) > maxWidth + EPS then
						newLine()
					end
					append(char, part.style)
				end
			else
				append(part.text, part.style)
			end
		end
		word, wordWidth = {}, 0
	end

	for _, run in spec.runs do
		if run.br then
			flush()
			spaces, spaceWidth = {}, 0
			newLine()
		else
			for chunk, gap in run.text:gmatch("([^ ]*)( *)") do
				if chunk ~= "" then
					table.insert(word, { text = chunk, style = run.style })
					wordWidth += measure(chunk, run.style)
				end
				if gap ~= "" then
					flush()
					table.insert(spaces, { text = gap, style = run.style })
					spaceWidth += measure(gap, run.style)
				end
			end
		end
	end
	flush()
	return finish({ lines = lines }, spec)
end

-- TextTruncate.AtEnd: keeps maxLines lines and ends overflowing ones with an ellipsis.
function Text.truncate(block, spec, maxWidth, maxLines)
	local lines = block.lines
	local dropped = #lines > maxLines
	for index = #lines, maxLines + 1, -1 do
		table.remove(lines, index)
	end
	for index, line in lines do
		local last = line.pieces[#line.pieces]
		if last and (line.width > maxWidth + EPS or (dropped and index == #lines)) then
			local ellipsis = Fonts.width(last.font, "…", last.size)
			while last and line.width + ellipsis > maxWidth + EPS do
				if last.text == "" then
					table.remove(line.pieces)
					last = line.pieces[#line.pieces]
				else
					local start = utf8.offset(last.text, -1)
					local width = Fonts.width(last.font, last.text:sub(start), last.size)
					last.text = last.text:sub(1, start - 1)
					last.width -= width
					line.width -= width
				end
			end
			if not last then
				last = { text = "", style = PLAIN, width = 0 }
				last.font, last.size = fontFor(spec, PLAIN)
				table.insert(line.pieces, last)
			end
			last.text ..= "…"
			last.width += ellipsis
			line.width += ellipsis
		end
	end
	return finish(block, spec)
end

-- MaxVisibleGraphemes: hides characters without moving the ones that remain.
function Text.reveal(block, count)
	for _, line in block.lines do
		for _, piece in line.pieces do
			local length = utf8.len(piece.text) or #piece.text
			if length > count then
				piece.text = piece.text:sub(1, utf8.offset(piece.text, count + 1) - 1)
			end
			count = math.max(count - length, 0)
		end
	end
end

-- TextScaled: the largest whole text size (times `step`) whose wrapped text fits.
function Text.fit(spec, width, height, minSize, maxSize, step)
	local best, low, high = minSize, minSize, maxSize
	while low <= high do
		local middle = (low + high) // 2
		local trial = table.clone(spec)
		trial.size = middle * step
		local block = Text.layout(trial, width, false)
		if block.width <= width + EPS and block.height <= height + EPS then
			best, low = middle, middle + 1
		else
			high = middle - 1
		end
	end
	return best * step
end

return Text
