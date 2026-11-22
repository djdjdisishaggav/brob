-- Runs every offline check for the lobby source.
-- Usage: lune run tools/check [-- --fast]   (--fast skips the spec files)
local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")

local DEFINITIONS = "tools/.cache/globalTypes.d.luau"
local DEFINITIONS_URL = "https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau"

local fast = table.find(process.args, "--fast") ~= nil
local failures = {}

local function run(label, program, args)
	local result = process.exec(program, args)
	local output = (result.stdout .. result.stderr):gsub("%s+$", "")
	if result.ok then
		print(`[ ok ] {label}`)
	else
		print(`[FAIL] {label}`)
		table.insert(failures, label)
	end
	if not result.ok and output ~= "" then
		print(output)
	end
	return result
end

if not fs.isFile(DEFINITIONS) then
	fs.writeDir("tools/.cache")
	local response = net.request(DEFINITIONS_URL)
	assert(response.ok, "could not download Roblox type definitions")
	fs.writeFile(DEFINITIONS, response.body)
end

-- The generated theme must match the design tokens.
local before = fs.isFile("src/shared/ThemeTokens.luau") and fs.readFile("src/shared/ThemeTokens.luau") or ""
run("generate theme tokens", "lune", { "run", "tools/gen_theme" })
if fs.readFile("src/shared/ThemeTokens.luau") ~= before then
	print("[FAIL] src/shared/ThemeTokens.luau was stale; regenerated - commit the result")
	table.insert(failures, "theme tokens up to date")
end

if not fs.isDir("build") then
	fs.writeDir("build")
end
run("rojo build", "rojo", { "build", "default.project.json", "-o", "build/lobby.rbxl" })
run("rojo sourcemap", "rojo", { "sourcemap", "default.project.json", "-o", "sourcemap.json" })
run("luau-lsp analyze", "luau-lsp", {
	"analyze",
	"--sourcemap=sourcemap.json",
	"--definitions=" .. DEFINITIONS,
	"--base-luaurc=.luaurc",
	"--ignore=**/ThemeTokens.luau",
	"src",
})
run("selene", "selene", { "src" })
run("stylua --check", "stylua", { "--check", "src", "tools", "tests" })

if not fast then
	local specs = {}
	for _, name in fs.readDir("tests") do
		if name:match("%.spec%.luau$") then
			table.insert(specs, name)
		end
	end
	table.sort(specs)
	for _, name in specs do
		local result = run("spec " .. name, "lune", { "run", "tests/" .. name })
		if result.ok then
			local last = result.stdout:gsub("%s+$", ""):match("[^\n]*$")
			print("       " .. last)
		end
	end
end

if #failures > 0 then
	print(`\n{#failures} check(s) failed: {table.concat(failures, ", ")}`)
	process.exit(1)
end
print("\nall checks passed")
