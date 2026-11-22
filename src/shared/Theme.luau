--!strict
-- Mushroom Guardians visual language for Roblox UI and world signage.
-- Raw values come from design/tokens.json through ThemeTokens; this module
-- adds the Roblox-specific pieces (fonts, variant tables, helpers).

local Tokens = require(script.Parent.ThemeTokens)

export type ButtonVariant = {
	FaceTop: Color3,
	FaceBottom: Color3,
	Ledge: Color3,
	Stroke: Color3,
	Text: Color3,
}

local Theme = {}

Theme.Color = Tokens.Color
Theme.Semantic = Tokens.Semantic
Theme.Space = Tokens.Space
Theme.Radius = Tokens.Radius
Theme.Stroke = Tokens.Stroke
Theme.FontSize = Tokens.FontSize
Theme.Ledge = Tokens.Ledge
Theme.Motion = Tokens.Motion
Theme.Opacity = Tokens.Opacity

-- All UI is laid out in these design units and scaled to the screen.
Theme.ReferenceResolution = Vector2.new(1280, 720)

local NUNITO = "rbxasset://fonts/families/Nunito.json"
local FREDOKA = "rbxasset://fonts/families/FredokaOne.json"

Theme.Font = {
	-- Titles, buttons and numbers.
	Display = Font.new(FREDOKA, Enum.FontWeight.Regular, Enum.FontStyle.Normal),
	-- Running text and labels.
	Body = Font.new(NUNITO, Enum.FontWeight.SemiBold, Enum.FontStyle.Normal),
	BodyBold = Font.new(NUNITO, Enum.FontWeight.Bold, Enum.FontStyle.Normal),
	BodyHeavy = Font.new(NUNITO, Enum.FontWeight.ExtraBold, Enum.FontStyle.Normal),
}

local S = Tokens.Semantic

Theme.Button = {
	Primary = {
		FaceTop = S.ButtonPrimaryFaceTop,
		FaceBottom = S.ButtonPrimaryFaceBottom,
		Ledge = S.ButtonPrimaryLedge,
		Stroke = S.ButtonPrimaryStroke,
		Text = S.ButtonPrimaryText,
	},
	Secondary = {
		FaceTop = S.ButtonSecondaryFaceTop,
		FaceBottom = S.ButtonSecondaryFaceBottom,
		Ledge = S.ButtonSecondaryLedge,
		Stroke = S.ButtonSecondaryStroke,
		Text = S.ButtonSecondaryText,
	},
	Accent = {
		FaceTop = S.ButtonAccentFaceTop,
		FaceBottom = S.ButtonAccentFaceBottom,
		Ledge = S.ButtonAccentLedge,
		Stroke = S.ButtonAccentStroke,
		Text = S.ButtonAccentText,
	},
	Danger = {
		FaceTop = S.ButtonDangerFaceTop,
		FaceBottom = S.ButtonDangerFaceBottom,
		Ledge = S.ButtonDangerLedge,
		Stroke = S.ButtonDangerStroke,
		Text = S.ButtonDangerText,
	},
	Disabled = {
		FaceTop = S.ButtonDisabledFaceTop,
		FaceBottom = S.ButtonDisabledFaceBottom,
		Ledge = S.ButtonDisabledLedge,
		Stroke = S.ButtonDisabledStroke,
		Text = S.ButtonDisabledText,
	},
} :: { [string]: ButtonVariant }

-- Station status colours and labels, keyed by Net.StationStatus.
Theme.Status = {
	Available = { Color = S.StatusAvailable, Label = "OPEN" },
	Occupied = { Color = S.StatusOccupied, Label = "FORMING" },
	Full = { Color = S.StatusFull, Label = "FULL" },
	Starting = { Color = S.StatusStarting, Label = "STARTING" },
	Unavailable = { Color = S.StatusUnavailable, Label = "CLOSED" },
	Error = { Color = S.StatusError, Label = "ERROR" },
}

-- Station accent colours, keyed by station id.
Theme.Station = {
	solo = S.StationSolo,
	duo = S.StationDuo,
	trio = S.StationTrio,
	squad = S.StationSquad,
}

Theme.Notice = {
	info = S.StateInfo,
	success = S.StateSuccess,
	warning = S.StateWarning,
	error = S.StateDanger,
}

function Theme.lighten(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(1, 1, 1), amount)
end

function Theme.darken(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

return Theme
