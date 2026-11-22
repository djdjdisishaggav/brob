# Applying the lobby to the Roblox place

Everything in this repository targets the existing **Lobby** place
(`Z1raelRam's Place`, id `106448766989936`). Nothing here touches the gameplay
place (`129614341268000`), publishes the game, or changes the start place.

The source was written and checked without access to Roblox Studio, so these
steps have **not been run against the live place yet**. They are ordered so
that nothing existing is lost and every step can be undone.

Scripts under `tools/studio/` are pasted into the Studio command bar (or run
through a Studio MCP `run_code` tool) with the Lobby place open in edit mode.
Each one refuses to run in any other place.

## 1. Back up

Run `tools/studio/1_backup.luau`. It copies the current scripts, ScreenGuis,
Workspace models, lighting and storage into
`ServerStorage.LobbyBackup_<UTC time>`. Nothing is moved or deleted.

## 2. Inspect what exists

Run `tools/studio/2_inspect.luau` and read the output. It lists every script
(flagging teleport, DataStore, leaderstats and purchase code), the ScreenGuis
in StarterGui, remotes, top-level Workspace content and spawn locations.

Decide from that list:

- **Existing systems to keep** (pets, shop, stats, news, currency, data
  saving). Keep their scripts and ScreenGuis. For each ScreenGui that should
  get a HUD button, set its name in `Config.Hud.ExternalFeatures`
  (`src/shared/Config.luau`); the HUD only shows a button while that ScreenGui
  exists. Currency pills appear for `leaderstats` values named in
  `Config.Hud.CurrencyStats`.
- **Old matchmaking / teleport scripts and old lobby UI** that this package
  replaces. They must not keep running next to the new party system.
- **Real maps and difficulties.** `Config.Chapters`, `Config.Difficulties` and
  `Config.PeacefulMode` were written without seeing the gameplay place. Make
  them match what the gameplay place supports before going live.

## 3. Sync the code

Either:

- **Rojo**: `rojo serve` in this repository and connect with the Rojo Studio
  plugin. The project maps only three folders, all named `MushroomLobby`
  (`ReplicatedStorage`, `ServerScriptService`,
  `StarterPlayer.StarterPlayerScripts`) and leaves every other instance alone.
- **Without Rojo**: `lune run tools/make_installer`, then run the generated
  `build/install/NN_install.luau` chunks in order in the command bar. They
  recreate the same three folders.

## 4. Replace the old lobby and bake the new one

Edit the two `KEEP_...` lists at the top of `tools/studio/4_bake_lobby.luau`
using step 2, then run it. It:

1. moves the old Workspace content and old ScreenGuis into
   `ServerStorage.LobbyBackup_*.Replaced` (moved, not deleted);
2. builds `Workspace.MushroomLobby` (environment, four stations, spawn) from
   `World/LobbyBuilder`;
3. applies the lobby lighting.

It is recorded as one undo step. Old server scripts identified in step 2 as
replaced should then be disabled or moved into the backup folder as well.

If the place is not baked, the server builds the same lobby at start-up, so
the game is playable either way; baking makes the geometry editable in Studio
and removes the start-up cost.

## 5. Verify

Run `tools/studio/5_verify.luau` (read-only checklist), then press Play and
walk through this list. None of it has been confirmed in Studio yet.

| Check | Expected |
| --- | --- |
| Spawn | You face the four stations; every sign is readable from the spawn |
| Walk the perimeter | The lobby is a walled rectangle with no way out |
| Step on the Solo pad | Create Party opens with party size 1 |
| Step off the pad | The panel closes; the prompt on the pedestal reopens it |
| Map arrows | Chapters cycle; locked chapters show their requirement |
| Locked difficulty | Tapping it explains the requirement and does not select it |
| Create | Party panel appears on the right; station board shows FORMING or FULL |
| Second player steps on that pad | Join prompt; joining adds them to the panel and the lanterns |
| Invite from the panel | The other player gets an invite card; accept and decline both work |
| Ready / Start | Start is disabled until everyone is ready |
| Countdown | 5 seconds, visible on the panel and the station board; leader can cancel |
| Leave during countdown | Countdown is cancelled for the rest of the party |
| Teleport in Studio | Studio cannot teleport: the party returns with the error banner and the station shows ERROR for a few seconds. This is the error path working. |
| Teleport on a live server | The whole party arrives in the gameplay place on its own reserved server |
| HUD | Party, Notifications, Settings; extra buttons only for systems that exist |
| Settings | UI size, reduce motion, invites and ambient effects all take effect |
| Screen sizes | Use the Studio device emulator: 1920x1080, 1366x768, a tablet, a phone in landscape |

## 6. Gameplay place contract

The lobby sends each party to a reserved server of the gameplay place with
this teleport data, set by the server (read it in the gameplay place with
`Player:GetJoinData().TeleportData`, and trust it only when
`GetJoinData().SourcePlaceId` is the lobby):

```lua
{
	version = 1,
	partyId = "party-12",
	stationId = "duo",
	leaderUserId = 123,
	memberUserIds = { 123, 456 },
	chapterId = "sporewood_hollow",
	difficultyId = "normal",
	peaceful = false,
	maxSize = 2,
}
```

Unlocks are read from the DataStore `MG_Progress_v1`, key `player_<UserId>`,
value `{ cleared = { [chapterId] = { [difficultyId] = true } } }`. The
gameplay place has to write that when a run is cleared; until it does,
everyone has Chapter 1 on Normal and everything else stays locked.

Nothing in the gameplay place was read or changed for this work, so both
points are assumptions for its owner to confirm.

## Rolling back

Undo the bake in Studio, or delete `Workspace.MushroomLobby` and the three
`MushroomLobby` folders and move the contents of
`ServerStorage.LobbyBackup_*.Replaced` back to where they came from.
