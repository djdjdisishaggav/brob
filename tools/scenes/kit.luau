-- Design-system board: every Kit component in every state, rendered from the
-- real Luau modules. Output: design/boards/design-system.{svg,png}
-- Usage: lune run tools/scenes/kit
local process = require("@lune/process")

local Scenes = require("./common")

local env = Scenes.setup()
local Kit, Theme, Harness, roblox = env.Kit, env.Theme, env.Harness, env.roblox
local UDim2, Vector2, Enum = roblox.UDim2, roblox.Vector2, roblox.Enum

local WIDTH, HEIGHT = 1600, 1180

local screen = Kit.screen("DesignSystem", 1, env.playerGui)
local board = Kit.new("Frame", {
	Name = "Board",
	BackgroundColor3 = Theme.Color.Bark900,
	Size = UDim2.fromScale(1, 1),
	Parent = screen,
})

local function section(title, x, y, width, height)
	Kit.text("Label", string.upper(title), {
		Name = title .. "Title",
		TextColor3 = Theme.Color.Amber300,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(width, 18),
		Parent = board,
	})
	return Kit.new("Frame", {
		Name = title,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(x, y + 26),
		Size = UDim2.fromOffset(width, height),
		Parent = board,
	})
end

local function caption(parent, text, x, y, width)
	return Kit.text("Caption", text, {
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(width or 120, 16),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = parent,
	})
end

Kit.text("Display", "Mushroom Guardians  -  Lobby design system", {
	Position = UDim2.fromOffset(32, 20),
	Size = UDim2.fromOffset(900, 40),
	Parent = board,
})
Kit.text(
	"Body",
	"Rendered from src/client/UI/Kit and design/tokens.json. Sizes are design units on a 1280x720 screen.",
	{
		TextColor3 = Theme.Semantic.TextSecondary,
		Position = UDim2.fromOffset(32, 58),
		Size = UDim2.fromOffset(1000, 22),
		Parent = board,
	}
)

-- Palette ---------------------------------------------------------------------
do
	local palette = section("Colour palette", 32, 100, 760, 250)
	local ramps = {
		{ "Bark", { 950, 900, 800, 700, 600, 500, 400, 300 } },
		{ "Parchment", { 500, 400, 300, 200, 100 } },
		{ "Moss", { 800, 700, 600, 500, 400, 300 } },
		{ "Amber", { 700, 600, 500, 400, 300 } },
		{ "Spore", { 700, 600, 500, 400, 300 } },
		{ "Crystal", { 700, 600, 500, 400, 300 } },
		{ "Cap", { 700, 600, 500, 400, 300 } },
		{ "Stone", { 700, 600, 500, 400, 300 } },
	}
	for row, ramp in ramps do
		local y = (row - 1) * 30
		Kit.text("Caption", ramp[1], {
			Position = UDim2.fromOffset(0, y),
			Size = UDim2.fromOffset(80, 24),
			TextColor3 = Theme.Semantic.TextSecondary,
			Parent = palette,
		})
		for index, shade in ramp[2] do
			local color = Theme.Color[ramp[1] .. shade]
			local swatch = Kit.new("Frame", {
				Name = ramp[1] .. shade,
				BackgroundColor3 = color,
				Position = UDim2.fromOffset(84 + (index - 1) * 82, y),
				Size = UDim2.fromOffset(76, 24),
				Parent = palette,
			}, { Kit.corner(6), Kit.stroke(Theme.Color.Bark950, 1.5) })
			local light = color.R + color.G + color.B > 1.4
			Kit.text("Caption", `{shade}  #{color:ToHex():upper()}`, {
				TextColor3 = if light then Theme.Color.Bark900 else Theme.Color.Parchment100,
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.fromScale(1, 1),
				TextSize = 11,
				Parent = swatch,
			})
		end
	end
end

-- Typography ------------------------------------------------------------------
do
	local typeSection = section("Typography", 832, 100, 360, 250)
	local samples = {
		{ "Display", "Display 28 - Fredoka One" },
		{ "Title", "Title 22 - Fredoka One" },
		{ "Heading", "Heading 18 - Fredoka One" },
		{ "Body", "Body 15 - Nunito SemiBold" },
		{ "BodyStrong", "Body strong 15 - Nunito Bold" },
		{ "Label", "LABEL 13 - NUNITO EXTRABOLD" },
		{ "Caption", "Caption 12 - Nunito Bold (minimum size)" },
	}
	local y = 0
	for _, sample in samples do
		local label = Kit.text(sample[1], sample[2], { Position = UDim2.fromOffset(0, y), Parent = typeSection })
		y += label.Size.Y.Offset + 6
	end
end

-- Status + station colours ------------------------------------------------------
do
	local status = section("Station status", 1224, 100, 344, 110)
	local order = { "Available", "Occupied", "Full", "Starting", "Unavailable", "Error" }
	for index, name in order do
		local entry = Theme.Status[name]
		local column, row = (index - 1) % 3, math.floor((index - 1) / 3)
		local chip = Kit.chip({ Text = entry.Label, Color = entry.Color, TextColor = Theme.Color.Bark900 })
		chip.Position = UDim2.fromOffset(column * 114, row * 44)
		chip.Parent = status
		caption(status, name, column * 114 - 8, row * 44 + 24, 110).TextXAlignment = Enum.TextXAlignment.Left
	end

	local stations = section("Station accents", 1224, 236, 344, 110)
	for index, station in env.Config.Stations do
		local x = (index - 1) * 86
		Kit.new("Frame", {
			Name = station.Id,
			BackgroundColor3 = Theme.Station[station.Id],
			Position = UDim2.fromOffset(x, 0),
			Size = UDim2.fromOffset(76, 40),
			Parent = stations,
		}, { Kit.corner(10), Kit.stroke(Theme.Color.Bark950, 2) })
		Kit.text("Heading", station.Name, {
			TextColor3 = Theme.Color.Bark900,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(x, 0),
			Size = UDim2.fromOffset(76, 40),
			TextSize = 16,
			Parent = stations,
		})
		caption(stations, `{station.DefaultSize} player{if station.DefaultSize > 1 then "s" else ""}`, x - 10, 46, 96)
	end
end

-- Buttons ---------------------------------------------------------------------
do
	local buttons = section("Buttons  -  normal / hover / pressed / disabled / loading", 32, 372, 760, 300)
	local variants = { "Primary", "Secondary", "Accent", "Danger" }
	local states = { "Normal", "Hover", "Pressed", "Disabled", "Loading" }
	for column, state in states do
		caption(buttons, state, 90 + (column - 1) * 134, 0, 124)
	end
	for row, variant in variants do
		local y = 22 + (row - 1) * 58
		Kit.text("Caption", variant, {
			Position = UDim2.fromOffset(0, y),
			Size = UDim2.fromOffset(84, 44),
			TextColor3 = Theme.Semantic.TextSecondary,
			Parent = buttons,
		})
		for column, state in states do
			local button = Kit.button({
				Text = if variant == "Danger" then "Leave" elseif variant == "Accent" then "Ready" else "Create",
				Icon = if variant == "Secondary" then "UserPlus" else nil,
				Variant = variant,
				Size = UDim2.fromOffset(124, 44),
				Position = UDim2.fromOffset(90 + (column - 1) * 134, y),
				Parent = buttons,
			})
			if variant == "Secondary" then
				button.SetText("Invite")
			end
			if state == "Hover" then
				Harness.fire(button.Face, "MouseEnter")
			elseif state == "Pressed" then
				Harness.fire(button.Face, "MouseEnter")
				Harness.fire(button.Face, "MouseButton1Down")
			elseif state == "Disabled" then
				button.SetEnabled(false)
			elseif state == "Loading" then
				button.SetLoading(true)
			end
		end
	end
end

-- Cards -----------------------------------------------------------------------
do
	local cards = section("Cards  -  normal / hover / selected / locked / disabled", 832, 372, 736, 130)
	local states = { "Normal", "Hover", "Selected", "Locked", "Disabled" }
	for index, state in states do
		local x = (index - 1) * 146
		local card = Kit.card({ Size = UDim2.fromOffset(134, 66), Position = UDim2.fromOffset(x, 0), Parent = cards })
		Kit.text("Heading", if state == "Locked" then "Hard" else "Normal", {
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(0, 8),
			Size = UDim2.new(1, 0, 0, 24),
			Parent = card.Content,
		})
		local pips = Kit.new("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 36),
			Size = UDim2.new(1, 0, 0, 16),
			Parent = card.Content,
		}, { Kit.list("Horizontal", 3, { HorizontalAlignment = Enum.HorizontalAlignment.Center }) })
		for _ = 1, if state == "Locked" then 2 else 1 do
			Kit.icon("Diamond", 14, Theme.Color.Amber400).Parent = pips
		end
		if state == "Hover" then
			Harness.fire(card.Face, "MouseEnter")
		elseif state == "Selected" then
			card.SetSelected(true)
		elseif state == "Locked" then
			card.SetLocked(true)
		elseif state == "Disabled" then
			card.SetEnabled(false)
		end
		caption(cards, state, x, 76, 134)
	end
end

-- Icon buttons, toggles, chips, avatars ---------------------------------------
do
	local hud = section("Icon buttons  -  normal / hover / pressed / selected / disabled / badge", 832, 528, 736, 96)
	local states = { "Normal", "Hover", "Pressed", "Selected", "Disabled", "Badge 3", "Badge dot" }
	local icons = { "Party", "Bell", "Gear", "Bell", "Bag", "Bell", "Party" }
	for index, state in states do
		local x = (index - 1) * 96
		local button = Kit.iconButton({ Icon = icons[index], Position = UDim2.fromOffset(x + 20, 0), Parent = hud })
		if state == "Hover" then
			Harness.fire(button.Face, "MouseEnter")
		elseif state == "Pressed" then
			Harness.fire(button.Face, "MouseEnter")
			Harness.fire(button.Face, "MouseButton1Down")
		elseif state == "Selected" then
			button.SetSelected(true)
		elseif state == "Disabled" then
			button.SetEnabled(false)
		elseif state == "Badge 3" then
			button.SetBadge(3)
		elseif state == "Badge dot" then
			button.SetBadge(0)
		end
		caption(hud, state, x - 6, 58, 96)
	end

	local misc = section("Toggle, chips, avatars, spinner", 832, 650, 736, 110)
	Kit.toggle({ Value = false, Position = UDim2.fromOffset(0, 4), Parent = misc })
	Kit.toggle({ Value = true, Position = UDim2.fromOffset(64, 4), Parent = misc })
	Kit.toggle({ Value = true, Enabled = false, Position = UDim2.fromOffset(128, 4), Parent = misc })
	caption(misc, "Off", -35, 38, 120)
	caption(misc, "On", 29, 38, 120)
	caption(misc, "Disabled", 93, 38, 120)

	local chips = {
		{ Text = "Leader", Color = Theme.Color.Amber400, TextColor = Theme.Color.Bark900, Icon = "Crown" },
		{ Text = "Ready", Color = Theme.Color.Moss500, TextColor = Theme.Color.Parchment100, Icon = "Check" },
		{ Text = "Not ready", Color = Theme.Color.Bark900, TextColor = Theme.Color.Parchment300 },
		{ Text = "Peaceful", Color = Theme.Color.Spore600, TextColor = Theme.Color.Parchment100, Icon = "Sprout" },
		{ Text = "Locked", Color = Theme.Color.Crystal600, TextColor = Theme.Color.Parchment100, Icon = "Lock" },
	}
	local chipRow = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(214, 6),
		Size = UDim2.fromOffset(520, 24),
		Parent = misc,
	}, { Kit.list("Horizontal", 8) })
	for index, options in chips do
		options.LayoutOrder = index
		Kit.chip(options).Parent = chipRow
	end

	local avatarRow = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(214, 46),
		Size = UDim2.fromOffset(520, 44),
		Parent = misc,
	}, { Kit.list("Horizontal", 12, { VerticalAlignment = Enum.VerticalAlignment.Center }) })
	Kit.avatar({ UserId = 1001, Size = 40, RingColor = Theme.Color.Amber400, LayoutOrder = 1 }).Parent = avatarRow
	Kit.avatar({ Size = 40, LayoutOrder = 2 }).Parent = avatarRow
	Kit.avatar({ Size = 40, RingColor = Theme.Color.Spore400, LayoutOrder = 3 }).Parent = avatarRow
	local spinner = Kit.spinner(28, Theme.Color.Spore400)
	spinner.LayoutOrder = 4
	spinner.Parent = avatarRow
end

-- Icons -----------------------------------------------------------------------
do
	local icons = section("Icon set (drawn from rounded shapes, no image assets)", 32, 690, 760, 150)
	for index, name in Kit.Icons.Names do
		local column, row = (index - 1) % 12, math.floor((index - 1) / 12)
		local x, y = column * 63, row * 70
		Kit.new("Frame", {
			Name = name .. "Tile",
			BackgroundColor3 = Theme.Color.Bark700,
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(44, 44),
			Parent = icons,
		}, { Kit.corner(10) })
		local icon = Kit.icon(name, 28, Theme.Color.Parchment100, Theme.Color.Amber400, Theme.Color.Bark700)
		icon.Position = UDim2.fromOffset(x + 8, y + 8)
		icon.Parent = icons
		caption(icons, name, x - 10, y + 46, 64).TextSize = 11
	end
end

-- Panel -----------------------------------------------------------------------
do
	local panels = section("Panel with header, error banner and countdown", 832, 786, 736, 360)
	local panel = Kit.panel({
		Name = "SamplePanel",
		Title = "PANEL TITLE",
		Size = UDim2.fromOffset(360, 250),
		Position = UDim2.fromOffset(6, 14),
		Parent = panels,
	})
	Kit.chip({ Text = "Duo station", Color = Theme.Station.duo, TextColor = Theme.Color.Bark900 }).Parent =
		panel.HeaderSlot
	Kit.text("Label", "SECTION LABEL", { Parent = panel.Body })
	Kit.text("Body", "Body text sits on bark with parchment ink. Secondary lines use a softer tone.", {
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 0, 44),
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = panel.Body,
	})
	Kit.divider({ Position = UDim2.fromOffset(0, 76), Parent = panel.Body })
	Kit.button({
		Text = "Back",
		Variant = "Secondary",
		Size = UDim2.fromOffset(100, 44),
		Position = UDim2.new(0, 0, 1, -44),
		Parent = panel.Body,
	})
	Kit.button({
		Text = "Create",
		Size = UDim2.fromOffset(140, 44),
		Position = UDim2.new(1, -140, 1, -44),
		Parent = panel.Body,
	})

	local plain = Kit.panel({
		Name = "PlainPanel",
		Size = UDim2.fromOffset(330, 250),
		Position = UDim2.fromOffset(396, 14),
		Parent = panels,
	})
	local banner = Kit.new("Frame", {
		Name = "ErrorBanner",
		BackgroundColor3 = Theme.Color.Cap700,
		Size = UDim2.new(1, 0, 0, 40),
		Parent = plain.Body,
	}, { Kit.corner(8), Kit.stroke(Theme.Color.Cap400, 1.5) })
	local warning = Kit.icon("Warning", 20, Theme.Color.Cap300, nil, Theme.Color.Cap700)
	warning.Position = UDim2.fromOffset(10, 10)
	warning.Parent = banner
	Kit.text("BodyStrong", "The teleport failed. Try again.", {
		Position = UDim2.fromOffset(38, 0),
		Size = UDim2.new(1, -46, 1, 0),
		TextSize = 14,
		Parent = banner,
	})
	local ring = Kit.new("Frame", {
		Name = "CountdownRing",
		BackgroundColor3 = Theme.Color.Bark900,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 58),
		Size = UDim2.fromOffset(96, 96),
		Parent = plain.Body,
	}, { Kit.corner(Theme.Radius.Pill), Kit.stroke(Theme.Color.Spore400, 5) })
	Kit.text("Display", "4", {
		TextSize = Theme.FontSize.Countdown,
		TextColor3 = Theme.Color.Spore300,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		Parent = ring,
	})
	Kit.text("Body", "Starting...", {
		TextColor3 = Theme.Semantic.TextSecondary,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.new(0, 0, 0, 160),
		Parent = plain.Body,
	})
end

-- Spacing ---------------------------------------------------------------------
do
	local spacing = section("Spacing, radius and depth", 32, 866, 760, 280)
	local x = 0
	for _, name in { "Xs", "Sm", "Md", "Lg", "Xl", "Xxl", "Xxxl" } do
		local value = Theme.Space[name]
		Kit.new("Frame", {
			BackgroundColor3 = Theme.Color.Spore500,
			Position = UDim2.fromOffset(x, 0),
			Size = UDim2.fromOffset(value, 28),
			Parent = spacing,
		})
		caption(spacing, tostring(value), x + value / 2 - 30, 32, 60)
		x += value + 34
	end
	x = 0
	for _, name in { "Sm", "Md", "Lg", "Xl" } do
		local value = Theme.Radius[name]
		Kit.new("Frame", {
			BackgroundColor3 = Theme.Color.Bark600,
			Position = UDim2.fromOffset(x, 70),
			Size = UDim2.fromOffset(84, 52),
			Parent = spacing,
		}, { Kit.corner(value), Kit.stroke(Theme.Color.Bark400, 2) })
		caption(spacing, `radius {value}`, x - 18, 128, 120)
		x += 110
	end
	local notes = {
		"Depth is a ledge of darker material under the face: button 4, card 3, panel 6.",
		"Strokes: 2 on controls, 3 on the panel frame. Selected = amber frame + check badge.",
		"Locked = veil + violet lock badge. Disabled = stone. Error = cap-red banner with the server's sentence.",
		"Countdown and loading = spore teal. Every state pairs its colour with a word or icon.",
	}
	for index, note in notes do
		Kit.text("Body", note, {
			TextColor3 = Theme.Semantic.TextSecondary,
			TextSize = 14,
			Position = UDim2.fromOffset(0, 150 + (index - 1) * 24),
			Size = UDim2.fromOffset(760, 22),
			Parent = spacing,
		})
	end
end

env.capture("design-system", WIDTH, HEIGHT, { dir = "design/boards", background = "#1B1410" })
process.exit(0)
