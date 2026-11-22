-- Dusk lighting for the lobby: warm low sun, cool teal-violet shadows and
-- enough ambient light that players and signs stay clearly readable.
--
-- `apply` is idempotent. It owns only the effects it names (MG_*), creating
-- them when missing and leaving every other Lighting child untouched.

local LightingSetup = {}

LightingSetup.EffectNames = {
	Atmosphere = "MG_Atmosphere",
	Bloom = "MG_Bloom",
	ColorCorrection = "MG_ColorCorrection",
	SunRays = "MG_SunRays",
}

local rgb = Color3.fromRGB

local function ensure(lighting: Instance, className: string, name: string): any
	local existing = lighting:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	local created = Instance.new(className)
	created.Name = name
	created.Parent = lighting
	return created
end

function LightingSetup.apply(lighting: Lighting)
	lighting.ClockTime = 17.6
	lighting.GeographicLatitude = 28
	lighting.Brightness = 2.4
	lighting.ExposureCompensation = 0.2
	lighting.GlobalShadows = true
	lighting.ShadowSoftness = 0.35
	-- Lifted ambient: the courtyard sits in the walls' long shadows at this hour.
	lighting.Ambient = rgb(104, 96, 122)
	lighting.OutdoorAmbient = rgb(150, 140, 164)
	lighting.ColorShift_Top = rgb(255, 204, 150)
	lighting.ColorShift_Bottom = rgb(92, 110, 150)
	lighting.EnvironmentDiffuseScale = 0.7
	lighting.EnvironmentSpecularScale = 0.35
	lighting.FogColor = rgb(196, 160, 168)
	lighting.FogStart = 0
	lighting.FogEnd = 100000

	local names = LightingSetup.EffectNames

	local atmosphere = ensure(lighting, "Atmosphere", names.Atmosphere) :: Atmosphere
	atmosphere.Density = 0.27
	atmosphere.Offset = 0.12
	atmosphere.Color = rgb(222, 178, 160)
	atmosphere.Decay = rgb(96, 84, 132)
	atmosphere.Glare = 0.15
	atmosphere.Haze = 1.4

	local bloom = ensure(lighting, "BloomEffect", names.Bloom) :: BloomEffect
	bloom.Intensity = 0.45
	bloom.Size = 26
	bloom.Threshold = 1.15
	bloom.Enabled = true

	local correction = ensure(lighting, "ColorCorrectionEffect", names.ColorCorrection) :: ColorCorrectionEffect
	correction.Brightness = 0.02
	correction.Contrast = 0.08
	correction.Saturation = 0.12
	correction.TintColor = rgb(255, 246, 238)
	correction.Enabled = true

	local sunRays = ensure(lighting, "SunRaysEffect", names.SunRays) :: SunRaysEffect
	sunRays.Intensity = 0.05
	sunRays.Spread = 0.6
	sunRays.Enabled = true
end

return LightingSetup
