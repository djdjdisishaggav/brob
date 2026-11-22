-- Mushroom Guardians UI kit: the only place that knows how panels, buttons,
-- cards and icons are drawn. Screens compose these parts and never style raw
-- instances themselves, which keeps every state (hover, pressed, selected,
-- disabled, locked, loading) consistent across the lobby.
--
-- Everything is laid out in design units for a 1280x720 reference screen and
-- scaled with UIScale (see Kit.autoScale).

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("MushroomLobby")

local Theme = require(Shared.Theme)
local Icons = require(script.Icons)

local Color = Theme.Color
local Semantic = Theme.Semantic

local Kit = {}

Kit.Theme = Theme
Kit.Icons = Icons
-- When true, tweens apply instantly and looping animations stay still.
Kit.reduceMotion = false

local BORDERLESS = {
	Frame = true,
	TextLabel = true,
	TextButton = true,
	TextBox = true,
	ImageLabel = true,
	ImageButton = true,
	ScrollingFrame = true,
	ViewportFrame = true,
	CanvasGroup = true,
}

--------------------------------------------------------------------------------
-- Construction helpers
--------------------------------------------------------------------------------

-- Creates an instance, applies props, parents children, then sets Parent last.
function Kit.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className) :: any
	if BORDERLESS[className] then
		instance.BorderSizePixel = 0
	end
	local parent = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				instance[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

-- Corner radius in design units; anything at or above Radius.Pill makes a pill.
function Kit.corner(radius: number): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = if radius >= Theme.Radius.Pill then UDim.new(0.5, 0) else UDim.new(0, radius)
	return corner
end

function Kit.stroke(color: Color3, thickness: number?, transparency: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Color = color
	stroke.Thickness = thickness or Theme.Stroke.Regular
	stroke.Transparency = transparency or 0
	return stroke
end

-- Outline around glyphs, for text that sits on busy or coloured surfaces.
function Kit.textStroke(color: Color3, thickness: number?, transparency: number?): UIStroke
	local stroke = Kit.stroke(color, thickness or 1.5, transparency)
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	return stroke
end

-- Vertical gradient from `top` to `bottom` unless a rotation is given.
function Kit.gradient(top: Color3, bottom: Color3, rotation: number?): UIGradient
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(top, bottom)
	gradient.Rotation = rotation or 90
	return gradient
end

function Kit.padding(left: number, top: number?, right: number?, bottom: number?): UIPadding
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, left)
	padding.PaddingTop = UDim.new(0, top or left)
	padding.PaddingRight = UDim.new(0, right or left)
	padding.PaddingBottom = UDim.new(0, bottom or top or left)
	return padding
end

function Kit.list(direction: "Horizontal" | "Vertical", gap: number, props: { [string]: any }?): UIListLayout
	local layout = Instance.new("UIListLayout") :: any
	layout.FillDirection = Enum.FillDirection[direction]
	layout.Padding = UDim.new(0, gap)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	if props then
		for key, value in props do
			layout[key] = value
		end
	end
	return layout
end

-- Animates properties, or applies them at once when motion is reduced.
function Kit.tween(instance: Instance, duration: number, goals: { [string]: any }, style: Enum.EasingStyle?): Tween?
	if Kit.reduceMotion or duration <= 0 then
		for key, value in goals do
			(instance :: any)[key] = value
		end
		return nil
	end
	local info = TweenInfo.new(duration, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(instance, info, goals)
	tween:Play()
	return tween
end

function Kit.screen(name: string, displayOrder: number, parent: Instance?): ScreenGui
	return Kit.new("ScreenGui", {
		Name = name,
		DisplayOrder = displayOrder,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = parent,
	})
end

--------------------------------------------------------------------------------
-- Text
--------------------------------------------------------------------------------

local TEXT_STYLES = {
	Display = { Font = Theme.Font.Display, Size = Theme.FontSize.Display, Color = Semantic.TextTitle },
	Title = { Font = Theme.Font.Display, Size = Theme.FontSize.Title, Color = Semantic.TextTitle },
	Heading = { Font = Theme.Font.Display, Size = Theme.FontSize.Heading, Color = Semantic.TextPrimary },
	Body = { Font = Theme.Font.Body, Size = Theme.FontSize.Body, Color = Semantic.TextPrimary },
	BodyStrong = { Font = Theme.Font.BodyBold, Size = Theme.FontSize.Body, Color = Semantic.TextPrimary },
	Label = { Font = Theme.Font.BodyHeavy, Size = Theme.FontSize.Label, Color = Semantic.TextSecondary },
	Caption = { Font = Theme.Font.BodyBold, Size = Theme.FontSize.Caption, Color = Semantic.TextMuted },
}

-- Styles: Display, Title, Heading, Body, BodyStrong, Label, Caption.
-- Defaults to one full-width, left-aligned line; override with props.
function Kit.text(style: string, text: string, props: { [string]: any }?): TextLabel
	local preset = TEXT_STYLES[style]
	if not preset then
		error(`unknown text style "{style}"`, 2)
	end
	local label = Kit.new("TextLabel", {
		Name = style,
		BackgroundTransparency = 1,
		FontFace = preset.Font,
		TextSize = preset.Size,
		TextColor3 = preset.Color,
		Text = text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		Size = UDim2.new(1, 0, 0, math.ceil(preset.Size * 1.35)),
	})
	if props then
		for key, value in props do
			(label :: any)[key] = value
		end
	end
	return label
end

--------------------------------------------------------------------------------
-- Icons, chips, avatars, spinner
--------------------------------------------------------------------------------

function Kit.icon(name: string, size: number, color: Color3?, accent: Color3?, cut: Color3?): Frame
	return Icons.create(name, size, {
		fg = color or Semantic.TextPrimary,
		accent = accent,
		cut = cut or Semantic.SurfacePanel,
	})
end

-- Small pill label, e.g. LEADER, READY, a station name.
function Kit.chip(options: {
	Text: string,
	Color: Color3?,
	TextColor: Color3?,
	Icon: string?,
	LayoutOrder: number?,
}): Frame
	local background = options.Color or Semantic.SurfaceInset
	local textColor = options.TextColor or Semantic.TextPrimary
	local chip = Kit.new("Frame", {
		Name = "Chip",
		BackgroundColor3 = background,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 22),
		LayoutOrder = options.LayoutOrder or 0,
	}, {
		Kit.corner(Theme.Radius.Pill),
		Kit.padding(9, 0, 9, 0),
		Kit.list("Horizontal", 5, { VerticalAlignment = Enum.VerticalAlignment.Center }),
	})
	if options.Icon then
		local icon = Kit.icon(options.Icon, 13, textColor, nil, background)
		icon.LayoutOrder = 1
		icon.Parent = chip
	end
	Kit.text("Caption", string.upper(options.Text), {
		Name = "Text",
		FontFace = Theme.Font.BodyHeavy,
		TextColor3 = textColor,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		LayoutOrder = 2,
		Parent = chip,
	})
	return chip
end

-- Round player portrait. Without a UserId it shows the placeholder silhouette.
function Kit.avatar(options: { UserId: number?, Size: number, RingColor: Color3?, LayoutOrder: number? }): Frame
	local size = options.Size
	local root = Kit.new("Frame", {
		Name = "Avatar",
		BackgroundColor3 = Semantic.SurfaceInset,
		Size = UDim2.fromOffset(size, size),
		LayoutOrder = options.LayoutOrder or 0,
	}, {
		Kit.corner(Theme.Radius.Pill),
		Kit.stroke(options.RingColor or Semantic.BorderWood, 2),
	})
	local placeholder = Kit.icon("User", math.floor(size * 0.62), Color.Parchment500, nil, Semantic.SurfaceInset)
	placeholder.AnchorPoint = Vector2.new(0.5, 0.5)
	placeholder.Position = UDim2.fromScale(0.5, 0.5)
	placeholder.Parent = root
	if options.UserId and options.UserId > 0 then
		Kit.new("ImageLabel", {
			Name = "Portrait",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Image = `rbxthumb://type=AvatarHeadShot&id={options.UserId}&w=150&h=150`,
			ZIndex = 20,
			Parent = root,
		}, { Kit.corner(Theme.Radius.Pill) })
	end
	return root
end

-- Ring of dots that chases round while something is loading.
function Kit.spinner(size: number, color: Color3?): Frame
	local dots = 8
	local root = Kit.new("Frame", {
		Name = "Spinner",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size, size),
	})
	local frames = {}
	local dotSize = math.max(2, size * 0.2)
	for index = 1, dots do
		local angle = (index - 1) / dots * math.pi * 2
		local radius = (size - dotSize) / 2
		frames[index] = Kit.new("Frame", {
			Name = "Dot" .. index,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(size / 2 + math.cos(angle) * radius, size / 2 + math.sin(angle) * radius),
			Size = UDim2.fromOffset(dotSize, dotSize),
			BackgroundColor3 = color or Semantic.TextPrimary,
			BackgroundTransparency = 0.85 - 0.85 * (index / dots),
			Parent = root,
		}, { Kit.corner(Theme.Radius.Pill) })
	end
	if not Kit.reduceMotion then
		local phase, elapsed = 0, 0
		local connection
		connection = RunService.Heartbeat:Connect(function(dt)
			elapsed += dt
			if elapsed < 0.09 then
				return
			end
			elapsed = 0
			phase = (phase + 1) % dots
			for index, frame in frames do
				local step = (index - phase - 1) % dots + 1
				frame.BackgroundTransparency = 0.85 - 0.85 * (step / dots)
			end
		end)
		root.Destroying:Connect(function()
			connection:Disconnect()
		end)
	end
	return root
end

function Kit.divider(props: { [string]: any }?): Frame
	local divider = Kit.new("Frame", {
		Name = "Divider",
		BackgroundColor3 = Semantic.BorderDark,
		BackgroundTransparency = 0.55,
		Size = UDim2.new(1, 0, 0, 2),
	})
	if props then
		for key, value in props do
			(divider :: any)[key] = value
		end
	end
	return divider
end

--------------------------------------------------------------------------------
-- Panel
--------------------------------------------------------------------------------

export type Panel = {
	Root: Frame,
	Surface: Frame,
	Body: Frame,
	Header: Frame?,
	HeaderSlot: Frame?,
	Title: TextLabel?,
}

local function mossTuft(x: UDim, y: UDim, diameter: number, color: Color3, zIndex: number): Frame
	return Kit.new("Frame", {
		Name = "Moss",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(x, y),
		Size = UDim2.fromOffset(diameter, diameter),
		BackgroundColor3 = color,
		ZIndex = zIndex,
	}, { Kit.corner(Theme.Radius.Pill), Kit.stroke(Color.Moss800, 1.5) })
end

-- Carved-wood panel with a soft shadow, a dark lower lip, an optional title
-- bar and moss growing over two corners. Content goes in `Body`.
function Kit.panel(options: {
	Name: string?,
	Size: UDim2,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Title: string?,
	Icon: string?,
	HeaderHeight: number?,
	BodyPadding: number?,
	Moss: boolean?,
	Parent: Instance?,
}): Panel
	local radius = Theme.Radius.Lg
	local headerHeight = if options.Title then options.HeaderHeight or 46 else 0
	local lip = Theme.Ledge.Panel

	local root = Kit.new("Frame", {
		Name = options.Name or "Panel",
		BackgroundTransparency = 1,
		Size = options.Size,
		Position = options.Position or UDim2.new(),
		AnchorPoint = options.AnchorPoint or Vector2.zero,
	})

	Kit.new("Frame", {
		Name = "ShadowFar",
		BackgroundColor3 = Semantic.SurfaceShadow,
		BackgroundTransparency = 0.86,
		Position = UDim2.fromOffset(-9, 2),
		Size = UDim2.new(1, 18, 1, 18),
		ZIndex = 1,
		Parent = root,
	}, { Kit.corner(radius + 9) })
	Kit.new("Frame", {
		Name = "ShadowNear",
		BackgroundColor3 = Semantic.SurfaceShadow,
		BackgroundTransparency = 0.7,
		Position = UDim2.fromOffset(-4, 3),
		Size = UDim2.new(1, 8, 1, 10),
		ZIndex = 2,
		Parent = root,
	}, { Kit.corner(radius + 4) })
	Kit.new("Frame", {
		Name = "Lip",
		BackgroundColor3 = Color.Bark900,
		Position = UDim2.fromOffset(0, lip),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
		Parent = root,
	}, { Kit.corner(radius), Kit.stroke(Semantic.BorderDark, 3) })

	local surface = Kit.new("Frame", {
		Name = "Surface",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 4,
		Parent = root,
	}, {
		Kit.corner(radius),
		Kit.gradient(Semantic.SurfacePanelTop, Semantic.SurfacePanel),
		Kit.new("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			LineJoinMode = Enum.LineJoinMode.Round,
			Color = Color3.new(1, 1, 1),
			Thickness = Theme.Stroke.Bold,
		}, { Kit.gradient(Semantic.BorderWoodLight, Semantic.BorderWood) }),
	})
	-- Thin inner line that makes the border read as a carved frame.
	Kit.new("Frame", {
		Name = "InnerLine",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(3, 3),
		Size = UDim2.new(1, -6, 1, -6),
		ZIndex = 1,
		Parent = surface,
	}, { Kit.corner(radius - 3), Kit.stroke(Semantic.BorderDark, 1.5, 0.45) })

	local panel: Panel = { Root = root, Surface = surface, Body = nil :: any }

	if options.Title then
		local headerTop = Theme.lighten(Semantic.SurfaceHeader, 0.07)
		local header = Kit.new("Frame", {
			Name = "Header",
			BackgroundColor3 = Color3.new(1, 1, 1),
			Size = UDim2.new(1, 0, 0, headerHeight),
			ZIndex = 2,
			Parent = surface,
		}, { Kit.corner(radius), Kit.gradient(headerTop, Semantic.SurfaceHeader) })
		-- UICorner rounds all four corners, so square off the bottom two.
		Kit.new("Frame", {
			Name = "HeaderBase",
			BackgroundColor3 = Semantic.SurfaceHeader,
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.new(1, 0, 0.5, 0),
			ZIndex = 1,
			Parent = header,
		})
		Kit.new("Frame", {
			Name = "HeaderEdge",
			BackgroundColor3 = Semantic.BorderDark,
			BackgroundTransparency = 0.4,
			Position = UDim2.new(0, 0, 1, 0),
			Size = UDim2.new(1, 0, 0, 2),
			ZIndex = 2,
			Parent = header,
		})
		local emblem =
			Kit.icon(options.Icon or "Mushroom", 26, Color.Parchment100, Color.Cap400, Semantic.SurfaceHeader)
		emblem.AnchorPoint = Vector2.new(0, 0.5)
		emblem.Position = UDim2.new(0, 16, 0.5, 0)
		emblem.ZIndex = 3
		emblem.Parent = header
		panel.Title = Kit.text("Title", options.Title, {
			Name = "Title",
			Position = UDim2.new(0, 52, 0, 0),
			Size = UDim2.new(0.6, -52, 1, 0),
			ZIndex = 3,
			Parent = header,
		})
		Kit.textStroke(Semantic.BorderDark, 1.5, 0.35).Parent = panel.Title
		panel.HeaderSlot = Kit.new("Frame", {
			Name = "HeaderSlot",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.5, 0),
			Size = UDim2.new(0.4, 0, 0, 30),
			ZIndex = 3,
			Parent = header,
		}, {
			Kit.list("Horizontal", 8, {
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
		})
		panel.Header = header
	end

	local bodyTop = if options.Title then headerHeight + 2 else 0
	panel.Body = Kit.new("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, bodyTop),
		Size = UDim2.new(1, 0, 1, -bodyTop),
		ZIndex = 2,
		Parent = surface,
	}, { Kit.padding(options.BodyPadding or Theme.Space.Lg) })

	if options.Moss ~= false then
		local zero, one = UDim.new(0, 0), UDim.new(1, 0)
		local tufts = {
			mossTuft(zero + UDim.new(0, 8), zero + UDim.new(0, 1), 15, Color.Moss600, 5),
			mossTuft(zero + UDim.new(0, 22), zero + UDim.new(0, -3), 21, Color.Moss500, 6),
			mossTuft(zero + UDim.new(0, 40), zero + UDim.new(0, -1), 16, Color.Moss400, 7),
			mossTuft(zero + UDim.new(0, 54), zero + UDim.new(0, 0), 11, Color.Moss600, 5),
			mossTuft(one + UDim.new(0, -50), one + UDim.new(0, 2), 12, Color.Moss600, 5),
			mossTuft(one + UDim.new(0, -36), one + UDim.new(0, 3), 18, Color.Moss500, 6),
			mossTuft(one + UDim.new(0, -18), one + UDim.new(0, 1), 22, Color.Moss400, 7),
			mossTuft(one + UDim.new(0, -3), one + UDim.new(0, -12), 13, Color.Moss600, 5),
		}
		for _, tuft in tufts do
			tuft.Parent = root
		end
	end

	root.Parent = options.Parent
	return panel
end

--------------------------------------------------------------------------------
-- Buttons
--------------------------------------------------------------------------------

export type Button = {
	Root: Frame,
	Face: TextButton,
	SetText: (text: string) -> (),
	SetEnabled: (enabled: boolean) -> (),
	SetLoading: (loading: boolean) -> (),
	SetVariant: (variant: string) -> (),
	IsEnabled: () -> boolean,
}

-- Shared press/hover behaviour for anything built as a face on a ledge.
-- `refresh(hovered, pressed)` restyles; returns a function that forces a restyle.
local function bindStates(face: GuiButton, refresh: (hovered: boolean, pressed: boolean) -> ()): () -> ()
	local hovered, pressed = false, false
	face.MouseEnter:Connect(function()
		hovered = true
		refresh(hovered, pressed)
	end)
	face.MouseLeave:Connect(function()
		hovered, pressed = false, false
		refresh(hovered, pressed)
	end)
	face.MouseButton1Down:Connect(function()
		pressed = true
		refresh(hovered, pressed)
	end)
	face.MouseButton1Up:Connect(function()
		pressed = false
		refresh(hovered, pressed)
	end)
	return function()
		refresh(hovered, pressed)
	end
end

-- Chunky game button: a gradient face sitting on a darker ledge that it sinks
-- into when pressed. Variants: Primary, Secondary, Accent, Danger.
function Kit.button(options: {
	Name: string?,
	Text: string,
	Icon: string?,
	Variant: string?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	TextSize: number?,
	Enabled: boolean?,
	OnActivated: (() -> ())?,
	Parent: Instance?,
}): Button
	local ledge = Theme.Ledge.Button
	local radius = Theme.Radius.Md
	local variantName = options.Variant or "Primary"
	local enabled = options.Enabled ~= false
	local loading = false

	local root = Kit.new("Frame", {
		Name = options.Name or (options.Text:gsub("%s", "") .. "Button"),
		BackgroundTransparency = 1,
		Size = options.Size or UDim2.fromOffset(140, 44),
		Position = options.Position or UDim2.new(),
		AnchorPoint = options.AnchorPoint or Vector2.zero,
		LayoutOrder = options.LayoutOrder or 0,
	})
	local baseStroke = Kit.stroke(Semantic.BorderDark, 2)
	local base = Kit.new("Frame", {
		Name = "Ledge",
		Size = UDim2.fromScale(1, 1),
		Parent = root,
	}, { Kit.corner(radius), baseStroke })
	local faceGradient = Kit.gradient(Color3.new(1, 1, 1), Color3.new(1, 1, 1))
	local face = Kit.new("TextButton", {
		Name = "Face",
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.new(1, 0, 1, -ledge),
		ZIndex = 2,
		Parent = root,
	}, { Kit.corner(radius), faceGradient })
	Kit.new("Frame", {
		Name = "Shine",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.78,
		Position = UDim2.fromOffset(7, 3),
		Size = UDim2.new(1, -14, 0, 3),
		Parent = face,
	}, { Kit.corner(Theme.Radius.Pill) })
	local content = Kit.new("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = face,
	}, {
		Kit.list("Horizontal", 7, {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	})
	local labelStroke = Kit.textStroke(Semantic.BorderDark, 1.5, 0.25)
	local label = Kit.text("Heading", options.Text, {
		Name = "Label",
		TextSize = options.TextSize or 17,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 2,
		Parent = content,
	})
	labelStroke.Parent = label

	local iconHolder = Kit.new("Frame", {
		Name = "IconHolder",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(20, 20),
		LayoutOrder = 1,
		Visible = options.Icon ~= nil,
		Parent = content,
	})
	local function drawIcon(variant: Theme.ButtonVariant)
		iconHolder:ClearAllChildren()
		if loading then
			Kit.spinner(20, variant.Text).Parent = iconHolder
		elseif options.Icon then
			Kit.icon(options.Icon, 20, variant.Text, nil, variant.FaceBottom).Parent = iconHolder
		end
		iconHolder.Visible = loading or options.Icon ~= nil
	end

	local lastVariant: Theme.ButtonVariant? = nil
	local function refresh(hovered: boolean, pressed: boolean)
		local active = enabled and not loading
		local variant = if enabled then Theme.Button[variantName] or Theme.Button.Primary else Theme.Button.Disabled
		local top, bottom = variant.FaceTop, variant.FaceBottom
		if active and pressed then
			top, bottom = Theme.darken(top, 0.08), Theme.darken(bottom, 0.08)
		elseif active and hovered then
			top, bottom = Theme.lighten(top, 0.12), Theme.lighten(bottom, 0.12)
		elseif loading then
			top, bottom = Theme.darken(top, 0.12), Theme.darken(bottom, 0.12)
		end
		faceGradient.Color = ColorSequence.new(top, bottom)
		base.BackgroundColor3 = variant.Ledge
		baseStroke.Color = variant.Stroke
		label.TextColor3 = variant.Text
		-- Light text gets a dark outline; dark text on a bright face does not need one.
		local lightText = variant.Text.R + variant.Text.G + variant.Text.B > 1.5
		labelStroke.Color = variant.Ledge
		labelStroke.Transparency = if lightText and enabled then 0.2 else 1
		face.Position = UDim2.fromOffset(0, if active and pressed then ledge - 1 else 0)
		face.Selectable = active
		if lastVariant ~= variant then
			lastVariant = variant
			drawIcon(variant)
		end
	end
	local restyle = bindStates(face, refresh)
	restyle()

	face.Activated:Connect(function()
		if enabled and not loading and options.OnActivated then
			options.OnActivated()
		end
	end)

	root.Parent = options.Parent
	return {
		Root = root,
		Face = face,
		SetText = function(text: string)
			label.Text = text
		end,
		SetEnabled = function(value: boolean)
			if enabled ~= value then
				enabled = value
				restyle()
			end
		end,
		SetLoading = function(value: boolean)
			if loading ~= value then
				loading = value
				lastVariant = nil
				restyle()
			end
		end,
		SetVariant = function(variant: string)
			if variantName ~= variant then
				variantName = variant
				restyle()
			end
		end,
		IsEnabled = function()
			return enabled and not loading
		end,
	}
end

export type IconButton = {
	Root: Frame,
	Face: TextButton,
	SetSelected: (selected: boolean) -> (),
	SetEnabled: (enabled: boolean) -> (),
	SetBadge: (count: number?) -> (),
}

-- Square icon tile for the HUD and for arrows. Selected tiles turn amber;
-- a badge shows a count (or a plain dot for 0) when something needs attention.
function Kit.iconButton(options: {
	Name: string?,
	Icon: string,
	Size: number?,
	IconSize: number?,
	Variant: string?,
	Label: string?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	Enabled: boolean?,
	OnActivated: (() -> ())?,
	Parent: Instance?,
}): IconButton
	local size = options.Size or 44
	local iconSize = options.IconSize or math.floor(size * 0.55)
	local ledge = Theme.Ledge.Button
	local radius = math.min(Theme.Radius.Md + 2, size / 2)
	local enabled = options.Enabled ~= false
	local selected = false

	local root = Kit.new("Frame", {
		Name = options.Name or (options.Icon .. "Button"),
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size, size + ledge),
		Position = options.Position or UDim2.new(),
		AnchorPoint = options.AnchorPoint or Vector2.zero,
		LayoutOrder = options.LayoutOrder or 0,
	})
	local baseStroke = Kit.stroke(Semantic.BorderDark, 2)
	local base = Kit.new("Frame", {
		Name = "Ledge",
		Size = UDim2.fromScale(1, 1),
		Parent = root,
	}, { Kit.corner(radius), baseStroke })
	local faceGradient = Kit.gradient(Color3.new(1, 1, 1), Color3.new(1, 1, 1))
	local face = Kit.new("TextButton", {
		Name = "Face",
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.new(1, 0, 1, -ledge),
		ZIndex = 2,
		Parent = root,
	}, { Kit.corner(radius), faceGradient })
	Kit.new("Frame", {
		Name = "Shine",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.8,
		Position = UDim2.fromOffset(6, 3),
		Size = UDim2.new(1, -12, 0, 3),
		Parent = face,
	}, { Kit.corner(Theme.Radius.Pill) })
	local iconHolder = Kit.new("Frame", {
		Name = "IconHolder",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(iconSize, iconSize),
		ZIndex = 2,
		Parent = face,
	})

	local badge = Kit.new("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(20, 20),
		BackgroundColor3 = Semantic.StateBadge,
		Visible = false,
		ZIndex = 5,
		Parent = root,
	}, { Kit.corner(Theme.Radius.Pill), Kit.stroke(Color.Parchment100, 2) })
	local badgeText = Kit.text("Caption", "", {
		Name = "Count",
		FontFace = Theme.Font.Display,
		TextColor3 = Color.Parchment100,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		Parent = badge,
	})

	local hint: Frame? = nil
	if options.Label then
		hint = Kit.new("Frame", {
			Name = "Hint",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 1, 6),
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 22),
			BackgroundColor3 = Semantic.SurfaceInset,
			Visible = false,
			ZIndex = 10,
			Parent = root,
		}, { Kit.corner(Theme.Radius.Sm), Kit.stroke(Semantic.BorderWood, 1.5), Kit.padding(8, 0, 8, 0) })
		Kit.text("Caption", options.Label, {
			TextColor3 = Semantic.TextPrimary,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			Parent = hint,
		})
	end

	local lastVariant: Theme.ButtonVariant? = nil
	local function refresh(hovered: boolean, pressed: boolean)
		local variant = Theme.Button[options.Variant or "Secondary"]
		if not enabled then
			variant = Theme.Button.Disabled
		elseif selected then
			variant = Theme.Button.Accent
		end
		local top, bottom = variant.FaceTop, variant.FaceBottom
		if enabled and pressed then
			top, bottom = Theme.darken(top, 0.08), Theme.darken(bottom, 0.08)
		elseif enabled and hovered then
			top, bottom = Theme.lighten(top, 0.12), Theme.lighten(bottom, 0.12)
		end
		faceGradient.Color = ColorSequence.new(top, bottom)
		base.BackgroundColor3 = variant.Ledge
		baseStroke.Color = variant.Stroke
		face.Position = UDim2.fromOffset(0, if enabled and pressed then ledge - 1 else 0)
		face.Selectable = enabled
		if hint then
			hint.Visible = hovered and enabled
		end
		if lastVariant ~= variant then
			lastVariant = variant
			iconHolder:ClearAllChildren()
			Kit.icon(options.Icon, iconSize, variant.Text, nil, variant.FaceBottom).Parent = iconHolder
		end
	end
	local restyle = bindStates(face, refresh)
	restyle()

	face.Activated:Connect(function()
		if enabled and options.OnActivated then
			options.OnActivated()
		end
	end)

	root.Parent = options.Parent
	return {
		Root = root,
		Face = face,
		SetSelected = function(value: boolean)
			if selected ~= value then
				selected = value
				restyle()
			end
		end,
		SetEnabled = function(value: boolean)
			if enabled ~= value then
				enabled = value
				restyle()
			end
		end,
		SetBadge = function(count: number?)
			badge.Visible = count ~= nil
			if count and count > 0 then
				badge.Size = UDim2.fromOffset(20, 20)
				badgeText.Text = if count > 9 then "9+" else tostring(count)
			else
				badge.Size = UDim2.fromOffset(12, 12)
				badgeText.Text = ""
			end
		end,
	}
end

--------------------------------------------------------------------------------
-- Toggle
--------------------------------------------------------------------------------

export type Toggle = {
	Root: TextButton,
	SetValue: (value: boolean) -> (),
	GetValue: () -> boolean,
	SetEnabled: (enabled: boolean) -> (),
}

-- Pill switch. OnChanged fires only for user input, not for SetValue.
function Kit.toggle(options: {
	Name: string?,
	Value: boolean?,
	Enabled: boolean?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	OnChanged: ((value: boolean) -> ())?,
	Parent: Instance?,
}): Toggle
	local value = options.Value == true
	local enabled = options.Enabled ~= false
	local width, height, knobSize = 50, 28, 20

	local trackStroke = Kit.stroke(Semantic.BorderWood, 2)
	local root = Kit.new("TextButton", {
		Name = options.Name or "Toggle",
		AutoButtonColor = false,
		Text = "",
		Size = UDim2.fromOffset(width, height),
		Position = options.Position or UDim2.new(),
		AnchorPoint = options.AnchorPoint or Vector2.zero,
		LayoutOrder = options.LayoutOrder or 0,
	}, { Kit.corner(Theme.Radius.Pill), trackStroke })
	local knob = Kit.new("Frame", {
		Name = "Knob",
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.fromOffset(knobSize, knobSize),
		Parent = root,
	}, { Kit.corner(Theme.Radius.Pill), Kit.stroke(Semantic.BorderDark, 1.5) })

	local function refresh(animate: boolean)
		local trackColor = if value then Color.Moss500 else Semantic.SurfaceInset
		local knobColor = if value then Color.Parchment100 else Color.Parchment400
		if not enabled then
			trackColor = Color.Stone700
			knobColor = Color.Stone500
		end
		local knobX = if value then width - knobSize - 4 else 4
		local duration = if animate then Theme.Motion.Base else 0
		Kit.tween(root, duration, { BackgroundColor3 = trackColor })
		Kit.tween(knob, duration, { Position = UDim2.new(0, knobX, 0.5, 0), BackgroundColor3 = knobColor })
		trackStroke.Color = if value and enabled then Color.Moss700 else Semantic.BorderWood
		root.Selectable = enabled
	end
	refresh(false)

	root.Activated:Connect(function()
		if not enabled then
			return
		end
		value = not value
		refresh(true)
		if options.OnChanged then
			options.OnChanged(value)
		end
	end)

	root.Parent = options.Parent
	return {
		Root = root,
		SetValue = function(newValue: boolean)
			if value ~= newValue then
				value = newValue
				refresh(true)
			end
		end,
		GetValue = function()
			return value
		end,
		SetEnabled = function(newEnabled: boolean)
			if enabled ~= newEnabled then
				enabled = newEnabled
				refresh(false)
			end
		end,
	}
end

--------------------------------------------------------------------------------
-- Card
--------------------------------------------------------------------------------

export type Card = {
	Root: Frame,
	Face: TextButton,
	Content: Frame,
	SetSelected: (selected: boolean) -> (),
	SetLocked: (locked: boolean) -> (),
	SetEnabled: (enabled: boolean) -> (),
}

-- Selectable tile. Selected: amber frame and a check badge. Locked: dimmed
-- under a veil with a violet lock badge; it still reports taps (with
-- locked = true) so the screen can explain the requirement.
function Kit.card(options: {
	Name: string?,
	Size: UDim2,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	Selected: boolean?,
	Locked: boolean?,
	OnActivated: ((locked: boolean) -> ())?,
	Parent: Instance?,
}): Card
	local ledge = Theme.Ledge.Card
	local radius = Theme.Radius.Md
	local selected = options.Selected == true
	local locked = options.Locked == true
	local enabled = true

	local root = Kit.new("Frame", {
		Name = options.Name or "Card",
		BackgroundTransparency = 1,
		Size = options.Size,
		Position = options.Position or UDim2.new(),
		AnchorPoint = options.AnchorPoint or Vector2.zero,
		LayoutOrder = options.LayoutOrder or 0,
	})
	local outline = Kit.stroke(Semantic.BorderDark, 2)
	Kit.new("Frame", {
		Name = "Ledge",
		BackgroundColor3 = Color.Bark950,
		Size = UDim2.fromScale(1, 1),
		Parent = root,
	}, { Kit.corner(radius), outline })
	local faceGradient = Kit.gradient(Color3.new(1, 1, 1), Color3.new(1, 1, 1))
	local face = Kit.new("TextButton", {
		Name = "Face",
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.new(1, 0, 1, -ledge),
		ZIndex = 2,
		Parent = root,
	}, { Kit.corner(radius), faceGradient })
	local content = Kit.new("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = face,
	})
	local veil = Kit.new("Frame", {
		Name = "LockVeil",
		BackgroundColor3 = Color.Bark950,
		BackgroundTransparency = 0.45,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
		Visible = false,
		Parent = face,
	}, { Kit.corner(radius) })

	local function badge(name: string, color: Color3, icon: string, iconColor: Color3): Frame
		local holder = Kit.new("Frame", {
			Name = name,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -5, 0, 5),
			Size = UDim2.fromOffset(22, 22),
			BackgroundColor3 = color,
			Visible = false,
			ZIndex = 6,
			Parent = root,
		}, { Kit.corner(Theme.Radius.Pill), Kit.stroke(Semantic.BorderDark, 2) })
		local glyph = Kit.icon(icon, 14, iconColor, nil, color)
		glyph.AnchorPoint = Vector2.new(0.5, 0.5)
		glyph.Position = UDim2.fromScale(0.5, 0.5)
		glyph.Parent = holder
		return holder
	end
	local checkBadge = badge("SelectedBadge", Semantic.StateSelected, "Check", Color.Bark900)
	local lockBadge = badge("LockBadge", Color.Crystal500, "Lock", Color.Parchment100)

	local function refresh(hovered: boolean, pressed: boolean)
		local interactive = enabled and not locked
		local top, bottom = Color.Bark500, Color.Bark600
		if locked or not enabled then
			top, bottom = Color.Stone600, Color.Stone700
		elseif selected then
			top, bottom = Color.Bark400:Lerp(Color.Amber500, 0.28), Color.Bark500:Lerp(Color.Amber600, 0.22)
		end
		if interactive and pressed then
			top, bottom = Theme.darken(top, 0.08), Theme.darken(bottom, 0.08)
		elseif interactive and hovered and not selected then
			top, bottom = Theme.lighten(top, 0.1), Theme.lighten(bottom, 0.1)
		end
		faceGradient.Color = ColorSequence.new(top, bottom)
		outline.Color = if selected and not locked then Semantic.StateSelected else Semantic.BorderDark
		outline.Thickness = if selected and not locked then 2.5 else 2
		face.Position = UDim2.fromOffset(0, if interactive and pressed then ledge - 1 else 0)
		veil.Visible = locked
		lockBadge.Visible = locked
		checkBadge.Visible = selected and not locked
		face.Selectable = enabled
	end
	local restyle = bindStates(face, refresh)
	restyle()

	face.Activated:Connect(function()
		if enabled and options.OnActivated then
			options.OnActivated(locked)
		end
	end)

	root.Parent = options.Parent
	return {
		Root = root,
		Face = face,
		Content = content,
		SetSelected = function(value: boolean)
			if selected ~= value then
				selected = value
				restyle()
			end
		end,
		SetLocked = function(value: boolean)
			if locked ~= value then
				locked = value
				restyle()
			end
		end,
		SetEnabled = function(value: boolean)
			if enabled ~= value then
				enabled = value
				restyle()
			end
		end,
	}
end

--------------------------------------------------------------------------------
-- Screen scaling
--------------------------------------------------------------------------------

local userScale = 1
local scalers: { [UIScale]: () -> number } = {}
local viewportConnection: RBXScriptConnection? = nil

local function viewportSize(): Vector2
	local camera = Workspace.CurrentCamera
	return if camera then camera.ViewportSize else Theme.ReferenceResolution
end

local function baseScale(viewport: Vector2): number
	local reference = Theme.ReferenceResolution
	return math.min(viewport.X / reference.X, viewport.Y / reference.Y)
end

-- Scale for a panel of `designSize`: follows the screen, never drops below a
-- readable size, and never lets the panel exceed 94% of the screen.
function Kit.fitScale(viewport: Vector2, designSize: Vector2, factor: number?): number
	local fit = math.min(viewport.X * 0.94 / designSize.X, viewport.Y * 0.94 / designSize.Y)
	local wanted = math.max(baseScale(viewport), 0.85) * (factor or 1)
	return math.clamp(math.min(fit, wanted), 0.4, 2.2)
end

-- Scale for always-visible HUD pieces: slightly larger floor so touch targets stay usable.
function Kit.hudScale(viewport: Vector2, factor: number?): number
	return math.clamp(math.max(baseScale(viewport), 0.9) * (factor or 1), 0.8, 2)
end

local function refreshScalers()
	for scale, compute in scalers do
		scale.Scale = compute()
	end
end

-- Adds a UIScale to `target` that tracks the screen size and the player's UI
-- size setting. Pass a design size to keep a panel on screen, or nil for HUD scaling.
function Kit.autoScale(target: GuiObject, designSize: Vector2?): UIScale
	local scale = Instance.new("UIScale")
	local function compute(): number
		local viewport = viewportSize()
		if designSize then
			return Kit.fitScale(viewport, designSize, userScale)
		end
		return Kit.hudScale(viewport, userScale)
	end
	scalers[scale] = compute
	scale.Scale = compute()
	scale.Destroying:Connect(function()
		scalers[scale] = nil
	end)
	scale.Parent = target

	if not viewportConnection then
		local camera = Workspace.CurrentCamera
		if camera then
			viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(refreshScalers)
		end
	end
	return scale
end

-- Applies the player's UI size setting (a multiplier) to every auto-scaled element.
function Kit.setUserScale(factor: number)
	userScale = factor
	refreshScalers()
end

-- Recomputes every auto scale, e.g. after the viewport changed.
function Kit.refreshScale()
	refreshScalers()
end

return Kit
