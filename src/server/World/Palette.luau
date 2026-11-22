-- World colours. Accents come from the shared UI theme so the lobby and the
-- interface read as one product; natural materials are defined here.

local shared = game:GetService("ReplicatedStorage"):WaitForChild("MushroomLobby")
local Theme = require(shared:WaitForChild("Theme"))

local rgb = Color3.fromRGB
local C = Theme.Color

local Palette = {}

-- Ground
Palette.Grass = rgb(86, 132, 66)
Palette.GrassLight = rgb(98, 144, 70)
Palette.GrassDeep = rgb(74, 120, 62)
Palette.OuterGrass = rgb(52, 88, 58)
Palette.Soil = rgb(96, 72, 54)

-- Paving
Palette.Path = rgb(186, 164, 128)
Palette.PathLight = rgb(206, 186, 150)
Palette.PathDeep = rgb(152, 130, 102)
Palette.Kerb = rgb(112, 100, 90)

-- Stone
Palette.Stone = rgb(128, 124, 118)
Palette.StoneLight = rgb(158, 152, 140)
Palette.StoneDeep = rgb(92, 90, 92)

-- Timber
Palette.Bark = C.Bark500
Palette.BarkLight = C.Bark400
Palette.BarkDeep = C.Bark700
Palette.BarkDark = C.Bark800
Palette.Plank = rgb(150, 110, 72)
Palette.PlankLight = rgb(176, 136, 92)
Palette.Iron = rgb(56, 52, 56)

-- Foliage and moss
Palette.Moss = C.Moss600
Palette.MossLight = C.Moss500
Palette.MossDeep = C.Moss700
Palette.Canopy = rgb(44, 92, 74)
Palette.CanopyDeep = rgb(34, 70, 66)

-- Mushrooms
Palette.Stem = rgb(226, 210, 182)
Palette.StemShade = rgb(200, 182, 152)
Palette.Gill = rgb(240, 224, 196)
Palette.Spot = rgb(255, 244, 220)
Palette.CapRusset = rgb(172, 84, 58)
Palette.CapOchre = rgb(214, 156, 72)
Palette.CapCream = rgb(228, 202, 160)
Palette.CapTeal = rgb(72, 146, 140)
Palette.CapPlum = rgb(124, 92, 158)
Palette.CapBrown = rgb(150, 98, 64)
Palette.CapRoof = rgb(158, 88, 60)
-- Distant giants sit back in cooler, darker tones so the stations stay in front.
Palette.CapDusk = rgb(84, 66, 122)
Palette.CapDuskTeal = rgb(52, 96, 110)
Palette.CapDuskLight = rgb(136, 114, 176)
Palette.GillDusk = rgb(170, 154, 190)
Palette.StemDusk = rgb(160, 150, 160)

-- Light
Palette.LanternGlow = C.Amber300
Palette.LanternLight = rgb(255, 196, 120)
Palette.LanternCap = rgb(112, 62, 44)
Palette.SporeGlow = C.Spore400
Palette.SporeLight = C.Spore300
Palette.CrystalGlow = C.Crystal400
Palette.CrystalLight = C.Crystal300
Palette.WindowGlow = rgb(255, 206, 130)

-- Signage
Palette.SignBoard = C.Bark800
Palette.SignPanel = C.Bark900
Palette.SignText = C.Parchment100
Palette.SignTextSoft = C.Parchment300
Palette.SignTextMuted = C.Parchment400

Palette.Station = Theme.Station

return Palette
