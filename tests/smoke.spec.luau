-- Smoke test for the harness itself: the shared modules load and behave.
local Harness = require("../tools/harness")

local h = Harness.new()
local ctx = h:context("server")
local shared = h:service("ReplicatedStorage"):FindFirstChild("MushroomLobby")
assert(shared, "ReplicatedStorage.MushroomLobby missing from the built place")

local Config = ctx.require(shared.Config)
local Theme = ctx.require(shared.Theme)
local Unlocks = ctx.require(shared.Unlocks)
local Net = ctx.require(shared.Net)

assert(Config.Places.Gameplay == 129614341268000, "gameplay place id")
assert(Config.Places.Lobby == 106448766989936, "lobby place id")
assert(#Config.Stations == 4, "four stations")
assert(typeof(Theme.Color.Bark800) == "Color3", "theme colours are Color3")
assert(typeof(Theme.Font.Display) == "Font", "theme fonts are Font")

local progress = Unlocks.emptyProgress()
assert(Unlocks.isUnlocked(progress, "sporewood_hollow", "normal"))
assert(not Unlocks.isUnlocked(progress, "sporewood_hollow", "hard"))
assert(not Unlocks.isChapterUnlocked(progress, "glowcap_caverns"))
assert(Unlocks.chapterRequirement(progress, "glowcap_caverns") == "Clear Sporewood Hollow on Normal to unlock")
assert(
	Unlocks.difficultyRequirement(progress, "sporewood_hollow", "hard")
		== "Clear Sporewood Hollow on Normal to unlock Hard"
)
progress =
	Unlocks.sanitize({ cleared = { sporewood_hollow = { normal = true, bogus = true }, nope = { normal = true } } })
assert(Unlocks.isUnlocked(progress, "sporewood_hollow", "hard"))
assert(Unlocks.isChapterUnlocked(progress, "glowcap_caverns"))
assert(progress.cleared.nope == nil and progress.cleared.sporewood_hollow.bogus == nil, "sanitize drops unknown keys")
assert(Unlocks.bestDifficulty(progress, "sporewood_hollow", "nightmare") == "hard")

local request, push = Net.createServer(shared)
assert(request.ClassName == "RemoteFunction" and push.ClassName == "RemoteEvent")
assert(Net.fail("PartyFull").message == "This party is full.")

print("harness smoke: ok")
