-- Generates src/shared/ThemeTokens.luau from design/tokens.json so the Roblox
-- UI and the design tokens (importable into Penpot) cannot drift apart.
-- Usage: lune run tools/gen_theme
local fs = require("@lune/fs")
local serde = require("@lune/serde")

local SOURCE = "design/tokens.json"
local TARGET = "src/shared/ThemeTokens.luau"

local tokens = serde.decode("json", fs.readFile(SOURCE))

local function pascal(parts)
	local out = {}
	for _, part in parts do
		table.insert(out, (part:gsub("^%l", string.upper)))
	end
	return table.concat(out)
end

-- Flattens a token group into { {path = {...}, value = "..."} }, in a stable order.
local function flatten(group, path, out)
	local keys = {}
	for key in group do
		if key:sub(1, 1) ~= "$" then
			table.insert(keys, key)
		end
	end
	table.sort(keys, function(a, b)
		local na, nb = tonumber(a), tonumber(b)
		if na and nb then
			return na > nb
		end
		return a < b
	end)
	for _, key in keys do
		local node = group[key]
		local nextPath = table.clone(path)
		table.insert(nextPath, key)
		if node["$value"] ~= nil then
			table.insert(out, { path = nextPath, value = node["$value"], type = node["$type"] })
		else
			flatten(node, nextPath, out)
		end
	end
	return out
end

local function lookup(reference)
	local node = tokens.core
	for part in reference:gmatch("[^%.]+") do
		node = node and node[part]
	end
	if not node or node["$value"] == nil then
		error("unresolved token reference {" .. reference .. "}")
	end
	return node["$value"]
end

local function resolve(value)
	local reference = value:match("^{(.+)}$")
	if reference then
		return resolve(lookup(reference))
	end
	return value
end

local function colorLiteral(hex)
	local r, g, b = hex:match("^#(%x%x)(%x%x)(%x%x)$")
	if not r then
		error("bad colour " .. hex)
	end
	return `Color3.fromRGB({tonumber(r, 16)}, {tonumber(g, 16)}, {tonumber(b, 16)})`
end

local lines = {
	"-- GENERATED from design/tokens.json by tools/gen_theme.luau. Do not edit by hand.",
	"return {",
}

local function section(name, entries, render)
	table.insert(lines, `\t{name} = \{`)
	for _, entry in entries do
		table.insert(lines, `\t\t{entry.key} = {render(entry.value)},`)
	end
	table.insert(lines, "\t},")
end

local function entriesOf(group, prefixDepth)
	local entries = {}
	for _, token in flatten(group, {}, {}) do
		local parts = table.clone(token.path)
		for _ = 1, prefixDepth or 0 do
			table.remove(parts, 1)
		end
		table.insert(entries, { key = pascal(parts), value = resolve(token.value) })
	end
	return entries
end

local function numberLiteral(value)
	return tostring(assert(tonumber(value), "bad number " .. tostring(value)))
end

local function stringLiteral(value)
	return string.format("%q", value)
end

section("Color", entriesOf(tokens.core.color), colorLiteral)
section("Semantic", entriesOf(tokens.semantic), colorLiteral)
section("Space", entriesOf(tokens.core.space), numberLiteral)
section("Radius", entriesOf(tokens.core.radius), numberLiteral)
section("Stroke", entriesOf(tokens.core.stroke), numberLiteral)
section("FontSize", entriesOf(tokens.core.fontSize), numberLiteral)
section("FontFamily", entriesOf(tokens.core.fontFamily), stringLiteral)
section("Ledge", entriesOf(tokens.core.ledge), numberLiteral)
section("Motion", entriesOf(tokens.core.motion), numberLiteral)
section("Opacity", entriesOf(tokens.core.opacity), numberLiteral)
table.insert(lines, "}")
table.insert(lines, "")

fs.writeFile(TARGET, table.concat(lines, "\n"))
print(`wrote {TARGET}`)
