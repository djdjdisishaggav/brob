-- Feature tour for tools/ui_render. Builds a GUI with plain Instance.new (no
-- game modules) and renders it at three viewport sizes into build/ui/.
-- Usage: lune run tools/ui_render/demo
local roblox = require("@lune/roblox")

local Render = require("../ui_render")

local Instance, Enum = roblox.Instance, roblox.Enum
local UDim, UDim2, Vector2, Color3 = roblox.UDim, roblox.UDim2, roblox.Vector2, roblox.Color3

local FAMILY = "rbxasset://fonts/families/%s.json"
local function font(family, weight, style)
	return roblox.Font.new(
		FAMILY:format(family),
		Enum.FontWeight[weight or "Regular"],
		Enum.FontStyle[style or "Normal"]
	)
end
local DISPLAY, BODY, BOLD, HEAVY =
	font("FredokaOne"), font("Nunito", "SemiBold"), font("Nunito", "Bold"), font("Nunito", "ExtraBold")

local C = {}
for name, value in
	{
		night = "#17120e",
		bark900 = "#2a1e15",
		bark800 = "#3b2a1d",
		bark700 = "#4d3826",
		bark600 = "#654a31",
		cream = "#fff1d0",
		parchment = "#e9d3a4",
		moss = "#79b74c",
		mossDeep = "#4c8a34",
		mossLedge = "#2c5a22",
		cap = "#d8513a",
		capLedge = "#8a2b1f",
		gold = "#f4c24f",
		crystal = "#5fd0c8",
		slate = "#8d8577",
		white = "#ffffff",
	}
do
	C[name] = Color3.fromHex(value)
end

local function make(class, props, children)
	local instance = Instance.new(class)
	for key, value in props do
		instance[key] = value
	end
	for _, child in children or {} do
		child.Parent = instance
	end
	return instance
end

local function corner(offset, scale)
	return make("UICorner", { CornerRadius = UDim.new(scale or 0, offset) })
end

local function stroke(color, thickness, props, children)
	local instance = make("UIStroke", { Color = color, Thickness = thickness }, children)
	for key, value in props or {} do
		instance[key] = value
	end
	return instance
end

local function gradient(from, to, rotation)
	return make("UIGradient", { Color = roblox.ColorSequence.new(from, to), Rotation = rotation or 90 })
end

local function padding(left, top, right, bottom)
	return make("UIPadding", {
		PaddingLeft = UDim.new(0, left),
		PaddingTop = UDim.new(0, top or left),
		PaddingRight = UDim.new(0, right or left),
		PaddingBottom = UDim.new(0, bottom or top or left),
	})
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

local function frame(name, props, children)
	local base = { Name = name, BackgroundTransparency = 1, BorderSizePixel = 0 }
	for key, value in props do
		base[key] = value
	end
	return make("Frame", base, children)
end

local function label(name, text, size, face, color, props, children)
	local base = {
		Name = name,
		Text = text,
		TextSize = size,
		FontFace = face,
		TextColor3 = color,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		TextXAlignment = Enum.TextXAlignment.Left,
	}
	for key, value in props or {} do
		base[key] = value
	end
	return make("TextLabel", base, children)
end

-- A button is a dark "ledge" with the lighter face sitting 4px above it.
local function button(name, text, top, bottom, ledge, props, children)
	local face = make("TextButton", {
		Name = "Face",
		Text = text,
		TextSize = 22,
		FontFace = DISPLAY,
		TextColor3 = C.white,
		BackgroundColor3 = C.white,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Size = UDim2.new(1, 0, 1, -5),
	}, { corner(12), gradient(top, bottom), stroke(ledge, 2, { ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
	local outline = stroke(ledge, 1.5)
	outline.Parent = make("TextLabel", {
		Name = "Outline",
		Text = text,
		TextSize = 22,
		FontFace = DISPLAY,
		TextColor3 = C.white,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = face,
	})
	face.TextTransparency = 1
	local base = { Name = name, BackgroundColor3 = ledge, BackgroundTransparency = 0, Size = UDim2.fromOffset(150, 52) }
	for key, value in props or {} do
		base[key] = value
	end
	local holder = frame(name, base, { corner(12), face })
	for _, child in children or {} do
		child.Parent = holder
	end
	return holder
end

local function difficultyCard(order, name, note, selected, locked)
	local card = frame("Card" .. name, {
		BackgroundColor3 = C.white,
		BackgroundTransparency = 0,
		Size = UDim2.new(0, 0, 1, 0),
		LayoutOrder = order,
	}, {
		corner(12),
		gradient(selected and C.bark600 or C.bark700, C.bark800),
		stroke(selected and C.gold or C.bark900, selected and 3 or 2, nil, {
			selected and gradient(C.cream, C.gold) or nil,
		}),
		padding(8, 8),
		list("Vertical", 2, { HorizontalAlignment = Enum.HorizontalAlignment.Center }),
		label("Name", name, 18, DISPLAY, selected and C.gold or C.cream, {
			Size = UDim2.new(1, 0, 0, 22),
			TextXAlignment = Enum.TextXAlignment.Center,
		}),
		label("Note", note, 12, BOLD, C.parchment, {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Center,
		}),
	})
	if not locked then
		return card
	end
	-- Locked cards fade as a group, which only a CanvasGroup can do.
	card.Size = UDim2.fromScale(1, 1)
	return make("CanvasGroup", {
		Name = "Locked" .. name,
		BackgroundTransparency = 1,
		GroupTransparency = 0.45,
		Size = UDim2.new(0, 0, 1, 0),
		LayoutOrder = order,
	}, { card })
end

local function partySlot(order, name, state)
	local filled = name ~= nil
	return frame("Slot" .. order, {
		BackgroundColor3 = filled and C.bark700 or C.bark900,
		BackgroundTransparency = filled and 0 or 0.4,
		LayoutOrder = order,
	}, {
		corner(10),
		stroke(filled and C.bark600 or C.slate, 1.5, { Transparency = filled and 0 or 0.5 }),
		padding(6, 6, 10, 6),
		list("Horizontal", 8, { VerticalAlignment = Enum.VerticalAlignment.Center }),
		frame("Avatar", {
			BackgroundColor3 = filled and C.crystal or C.bark800,
			BackgroundTransparency = 0,
			Size = UDim2.fromScale(1, 1),
			LayoutOrder = 1,
		}, { corner(0, 1), make("UIAspectRatioConstraint", { AspectRatio = 1 }) }),
		label("Name", name or "Empty slot", 15, filled and BOLD or BODY, filled and C.cream or C.slate, {
			Size = UDim2.fromScale(0, 1),
			TextTruncate = Enum.TextTruncate.AtEnd,
			LayoutOrder = 2,
		}, { make("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }) }),
		state and label("State", state, 11, HEAVY, C.night, {
			BackgroundColor3 = state == "READY" and C.moss or C.gold,
			BackgroundTransparency = 0,
			AutomaticSize = Enum.AutomaticSize.XY,
			TextXAlignment = Enum.TextXAlignment.Center,
			LayoutOrder = 3,
		}, { corner(0, 1), padding(8, 3) }) or nil,
	})
end

local function hudButton(order, name, selected, alert)
	return frame(name, {
		BackgroundColor3 = selected and C.gold or C.bark800,
		BackgroundTransparency = 0,
		Size = UDim2.fromOffset(46, 46),
		LayoutOrder = order,
	}, {
		corner(0, 0.5),
		stroke(selected and C.cream or C.bark600, 2),
		-- Nested UIScale: the selected button is 15% larger inside the scaled HUD.
		selected and make("UIScale", { Scale = 1.15 }) or nil,
		make("ImageLabel", {
			Name = "Icon",
			Image = "rbxassetid://0",
			ImageColor3 = selected and C.bark900 or C.cream,
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.5, 0.5),
		}),
		alert and label("Alert", alert, 12, HEAVY, C.white, {
			BackgroundColor3 = C.cap,
			BackgroundTransparency = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -5, 0, 5),
			Size = UDim2.fromOffset(20, 20),
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 2,
		}, { corner(0, 1), stroke(C.night, 2, { ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) }) or nil,
	})
end

local function alignmentSample(order, xAlign, yAlign)
	return label(xAlign .. yAlign, xAlign:sub(1, 1) .. yAlign:sub(1, 1), 14, HEAVY, C.cream, {
		BackgroundColor3 = C.bark800,
		BackgroundTransparency = 0.15,
		TextXAlignment = Enum.TextXAlignment[xAlign],
		TextYAlignment = Enum.TextYAlignment[yAlign],
		LayoutOrder = order,
	}, { corner(6), padding(5, 3) })
end

local function build(scale)
	local panel = frame("Panel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 10),
		Size = UDim2.fromOffset(820, 452),
		BackgroundColor3 = C.white,
		BackgroundTransparency = 0,
	}, {
		make("UIScale", { Scale = scale }),
		corner(22),
		gradient(C.bark700, C.bark900),
		stroke(C.white, 4, nil, { gradient(C.bark600, C.night) }),
		padding(22, 16, 22, 20),
		frame("Ribbon", {
			BackgroundColor3 = C.cap,
			BackgroundTransparency = 0,
			Position = UDim2.fromOffset(-46, -30),
			Size = UDim2.fromOffset(92, 30),
			Rotation = -14,
			ZIndex = 3,
		}, {
			corner(8),
			stroke(C.capLedge, 2),
			label("Text", "NEW RUN", 14, HEAVY, C.white, {
				Size = UDim2.fromScale(1, 1),
				TextXAlignment = Enum.TextXAlignment.Center,
			}),
		}),
		frame("Header", { Size = UDim2.new(1, 0, 0, 44) }, {
			label("Title", "CREATE PARTY", 34, DISPLAY, C.white, { Size = UDim2.fromScale(0.6, 1) }, {
				gradient(C.cream, C.gold),
				stroke(C.night, 2),
			}),
			label(
				"Station",
				'Station  <b>Duo Grove</b>  ·  <font color="#79b74c">OPEN</font>',
				15,
				BODY,
				C.parchment,
				{
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.fromScale(1, 0.5),
					AutomaticSize = Enum.AutomaticSize.XY,
					RichText = true,
				}
			),
		}),
		frame("Body", { Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, 0, 1, -54) }, {
			list("Horizontal", 18),
			frame("MapColumn", { Size = UDim2.new(0, 300, 1, 0), LayoutOrder = 1 }, {
				list("Vertical", 8),
				make("CanvasGroup", {
					Name = "Preview",
					BackgroundColor3 = C.night,
					Size = UDim2.new(1, 0, 0, 168),
					LayoutOrder = 1,
				}, {
					corner(14),
					make("ViewportFrame", {
						Name = "MapView",
						BackgroundColor3 = Color3.fromHex("#23423a"),
						Size = UDim2.fromScale(1, 1),
					}),
					frame("Spore", {
						BackgroundColor3 = C.crystal,
						BackgroundTransparency = 0.35,
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.new(1, -6, 1, -6),
						Size = UDim2.fromOffset(84, 84),
					}, { corner(0, 0.5) }),
					label("Chapter", "CHAPTER 1", 12, HEAVY, C.night, {
						BackgroundColor3 = C.gold,
						BackgroundTransparency = 0,
						Position = UDim2.fromOffset(10, 10),
						AutomaticSize = Enum.AutomaticSize.XY,
					}, { corner(0, 1), padding(10, 4) }),
				}),
				frame("MapNav", { Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 2 }, {
					list("Horizontal", 8, { VerticalAlignment = Enum.VerticalAlignment.Center }),
					label("Prev", "<", 22, DISPLAY, C.cream, {
						BackgroundColor3 = C.bark600,
						BackgroundTransparency = 0,
						Size = UDim2.fromOffset(36, 36),
						TextXAlignment = Enum.TextXAlignment.Center,
						LayoutOrder = 1,
					}, { corner(10) }),
					label("MapName", "Sporewood Hollow", 22, DISPLAY, C.cream, {
						Size = UDim2.fromScale(0, 1),
						TextXAlignment = Enum.TextXAlignment.Center,
						LayoutOrder = 2,
					}, { make("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }) }),
					label("Next", ">", 22, DISPLAY, C.cream, {
						BackgroundColor3 = C.bark600,
						BackgroundTransparency = 0,
						Size = UDim2.fromOffset(36, 36),
						TextXAlignment = Enum.TextXAlignment.Center,
						LayoutOrder = 3,
					}, { corner(10) }),
				}),
				label(
					"Description",
					"A damp grove of giant caps where the first spore beasts gather. Hold the lantern ring until dawn.",
					14,
					BODY,
					C.parchment,
					{
						Size = UDim2.new(1, 0, 0, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						TextWrapped = true,
						LineHeight = 1.1,
						TextYAlignment = Enum.TextYAlignment.Top,
						LayoutOrder = 3,
					}
				),
				label(
					"Truncated",
					"Best clear: Nightmare in 14:02 by MossyBoots_TheUnbelievablyLongNamed",
					13,
					BOLD,
					C.slate,
					{
						Size = UDim2.new(1, 0, 0, 18),
						TextTruncate = Enum.TextTruncate.AtEnd,
						LayoutOrder = 4,
					}
				),
				make(
					"TextBox",
					{
						Name = "InviteBox",
						Text = "",
						PlaceholderText = "Invite by player name",
						PlaceholderColor3 = C.slate,
						TextSize = 14,
						FontFace = BODY,
						TextColor3 = C.cream,
						TextXAlignment = Enum.TextXAlignment.Left,
						BackgroundColor3 = C.night,
						BorderSizePixel = 0,
						Size = UDim2.new(1, 0, 0, 30),
						LayoutOrder = 5,
					},
					{
						corner(8),
						padding(10, 0),
						stroke(C.bark600, 1.5, { ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
					}
				),
				frame("ClipBox", {
					BackgroundColor3 = C.bark900,
					BackgroundTransparency = 0,
					ClipsDescendants = true,
					Size = UDim2.new(1, 0, 0, 34),
					LayoutOrder = 6,
				}, {
					corner(10),
					label("Clipped", "Frame clips square, CanvasGroup clips round", 15, BOLD, C.cream, {
						Position = UDim2.fromOffset(-14, -8),
						Size = UDim2.new(1, 40, 0, 30),
						BackgroundColor3 = C.mossDeep,
						BackgroundTransparency = 0,
					}, { padding(18, 0) }),
				}),
			}),
			frame("SetupColumn", { Size = UDim2.fromScale(0, 1), LayoutOrder = 2 }, {
				make("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }),
				list("Vertical", 8),
				label(
					"DifficultyCaption",
					"DIFFICULTY",
					13,
					HEAVY,
					C.slate,
					{ Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 1 }
				),
				frame("Difficulty", { Size = UDim2.new(1, 0, 0, 84), LayoutOrder = 2 }, {
					list("Horizontal", 10, { HorizontalFlex = Enum.UIFlexAlignment.Fill }),
					difficultyCard(1, "Normal", "Recommended", true, false),
					difficultyCard(2, "Hard", "Clear Normal to unlock", false, true),
					difficultyCard(3, "Nightmare", "Clear Hard to unlock", false, true),
				}),
				label(
					"PartyCaption",
					"PARTY  2 / 4",
					13,
					HEAVY,
					C.slate,
					{ Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 3 }
				),
				make("ScrollingFrame", {
					Name = "Party",
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					CanvasSize = UDim2.new(),
					ScrollBarThickness = 0,
					Size = UDim2.new(1, 0, 0, 96),
					LayoutOrder = 4,
				}, {
					make("UIGridLayout", {
						CellSize = UDim2.new(0.5, -5, 0, 43),
						CellPadding = UDim2.fromOffset(10, 10),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					partySlot(1, "Z1raelRam", "LEADER"),
					partySlot(2, "MossyBoots_TheUnbelievablyLongNamed", "READY"),
					partySlot(3, nil, nil),
					partySlot(4, nil, nil),
				}),
				frame("Peaceful", { Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 5 }, {
					label(
						"Text",
						'<b>Peaceful Mode</b><br/><font size="12" color="#8d8577">No enemies, no rewards</font>',
						15,
						BODY,
						C.cream,
						{
							Size = UDim2.new(1, -70, 1, 0),
							RichText = true,
						}
					),
					frame("Toggle", {
						BackgroundColor3 = C.mossDeep,
						BackgroundTransparency = 0,
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.fromScale(1, 0.5),
						Size = UDim2.fromOffset(56, 30),
					}, {
						corner(0, 1),
						stroke(C.mossLedge, 2),
						frame("Knob", {
							BackgroundColor3 = C.cream,
							BackgroundTransparency = 0,
							AnchorPoint = Vector2.new(1, 0.5),
							Position = UDim2.new(1, -4, 0.5, 0),
							Size = UDim2.fromOffset(22, 22),
						}, { corner(0, 1) }),
					}),
				}),
				frame("Actions", { Size = UDim2.new(1, 0, 0, 52), LayoutOrder = 6 }, {
					list("Horizontal", 12, { VerticalAlignment = Enum.VerticalAlignment.Bottom }),
					button(
						"Back",
						"Back",
						C.bark600,
						C.bark700,
						C.night,
						{ Size = UDim2.fromOffset(110, 52), LayoutOrder = 1 }
					),
					button("Invite", "Invite", C.crystal, Color3.fromHex("#2f8f89"), Color3.fromHex("#1c5552"), {
						Size = UDim2.fromOffset(120, 52),
						LayoutOrder = 2,
					}),
					button("Create", "Create Party", C.moss, C.mossDeep, C.mossLedge, { LayoutOrder = 3 }, {
						make("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }),
					}),
				}),
			}),
		}),
	})

	local hud = frame("Hud", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 12),
		AutomaticSize = Enum.AutomaticSize.XY,
	}, {
		make("UIScale", { Scale = scale }),
		list("Horizontal", 10, { VerticalAlignment = Enum.VerticalAlignment.Center }),
		frame("Coins", {
			BackgroundColor3 = C.night,
			BackgroundTransparency = 0.25,
			AutomaticSize = Enum.AutomaticSize.XY,
			LayoutOrder = 0,
		}, {
			corner(0, 1),
			stroke(C.bark600, 2),
			padding(8, 6, 14, 6),
			list("Horizontal", 8, { VerticalAlignment = Enum.VerticalAlignment.Center }),
			frame("Coin", { BackgroundColor3 = C.gold, BackgroundTransparency = 0, Size = UDim2.fromOffset(22, 22) }, {
				corner(0, 1),
			}),
			label("Amount", "12,480", 18, DISPLAY, C.cream, { AutomaticSize = Enum.AutomaticSize.XY }),
		}),
		hudButton(1, "Party", true, nil),
		hudButton(2, "Notifications", false, "3"),
		hudButton(3, "Shop", false, nil),
		hudButton(4, "Settings", false, nil),
	})

	local samples = frame("Samples", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -16),
		Size = UDim2.fromOffset(190, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.night,
		BackgroundTransparency = 0.3,
	}, {
		make("UIScale", { Scale = scale }),
		corner(12),
		padding(10),
		list("Vertical", 6),
		label("Sizes", "Aa 12", 12, BODY, C.cream, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 1 }),
		label("Sizes", "Aa 16 bold", 16, BOLD, C.cream, { AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 2 }),
		label(
			"Sizes",
			"Aa 22 display",
			22,
			DISPLAY,
			C.gold,
			{ AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 3 }
		),
		label("Italic", "Nunito italic 14", 14, font("Nunito", "Regular", "Italic"), C.parchment, {
			AutomaticSize = Enum.AutomaticSize.XY,
			LayoutOrder = 4,
		}),
		frame("Alignment", { Size = UDim2.new(1, 0, 0, 96), LayoutOrder = 5 }, {
			make("UIGridLayout", {
				CellSize = UDim2.new(1 / 3, -4, 1 / 3, -4),
				CellPadding = UDim2.fromOffset(6, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			alignmentSample(1, "Left", "Top"),
			alignmentSample(2, "Center", "Top"),
			alignmentSample(3, "Right", "Top"),
			alignmentSample(4, "Left", "Center"),
			alignmentSample(5, "Center", "Center"),
			alignmentSample(6, "Right", "Center"),
			alignmentSample(7, "Left", "Bottom"),
			alignmentSample(8, "Center", "Bottom"),
			alignmentSample(9, "Right", "Bottom"),
		}),
		label("Countdown", "3", 14, DISPLAY, C.white, {
			BackgroundColor3 = C.cap,
			BackgroundTransparency = 0,
			Size = UDim2.new(1, 0, 0, 54),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			LayoutOrder = 6,
		}, {
			corner(10),
			padding(0, 4),
			stroke(C.capLedge, 2),
			make("UITextSizeConstraint", { MaxTextSize = 44 }),
		}),
	})

	return {
		make("ScreenGui", { Name = "DemoPanel", DisplayOrder = 2, IgnoreGuiInset = true }, { panel }),
		make("ScreenGui", { Name = "DemoHud", DisplayOrder = 1, IgnoreGuiInset = true }, { hud, samples }),
	}
end

for _, size in { { 1280, 720 }, { 1920, 1080 }, { 844, 390 } } do
	local width, height = size[1], size[2]
	-- The same rule real client code would use: design at 1280x720, scale to fit.
	local roots = build(math.min(width / 1280, height / 720))
	local result = Render.capture(roots, {
		viewport = Vector2.new(width, height),
		path = `build/ui/demo-{width}x{height}.png`,
		title = `ui_render demo {width}x{height}`,
		showTopbar = true,
	})
	print(`wrote {result.png}`)
end
