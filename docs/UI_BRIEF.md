# Brief for lobby UI screen authors

Read this whole file before writing code. It applies to every screen module
under `src/client/UI/`.

## Situation

- This repository holds the source of the Roblox **Lobby** place of the game
  Mushroom Guardians. There is no Roblox Studio in this environment. Code is
  checked headlessly: `tools/harness` runs the Luau modules on Lune with
  mocked Roblox services, and `tools/ui_render` lays out the resulting GUI
  tree and renders it to SVG/PNG. You verify your work by rendering scenes and
  LOOKING at the PNGs (the Read tool displays images).
- The look is defined by `docs/DESIGN.md` and implemented by the Kit
  (`src/client/UI/Kit/init.luau`, `Icons.luau`). Open
  `design/boards/design-system-1600x1180.png` to see every Kit part and state.
  Your screens must look like they belong on that board: a polished commercial
  Roblox game, not a prototype.

## Read first

`docs/DESIGN.md`, `src/client/UI/Kit/init.luau`, `src/client/UI/Kit/Icons.luau`,
`src/shared/Config.luau`, `src/shared/Theme.luau`, `src/shared/Net.luau`
(snapshot types), `src/shared/Unlocks.luau`, `tools/scenes/common.luau`,
`tools/scenes/kit.luau` (how a scene is built, how states are forced with
`Harness.fire`), `tools/harness/init.luau`, `tools/ui_render/README.md`.

## Shell and tool rules

- Start every shell command with
  `export PATH="$HOME/.rokit/bin:$PATH"; cd /tmp/hoplite/workspace`.
- The Bash tool rejects heredocs that write files, piping downloads into a
  shell, shell loops over variable commands, and running a program through a
  variable. Create and edit files with the Write/Edit tools only.
- Never run git commit/push. Leave your files in the working tree.
- Format with `stylua <your files>`. Check with `lune run tools/check -- --fast`
  (rojo build, luau-lsp analyze, selene, stylua). Other people are editing
  other files at the same time, so failures in files you do not own are not
  yours to fix; your own files must be clean (no analyze errors, no selene
  warnings, formatted).

## Luau rules (the code must run in Roblox and in the harness)

- `Instance.new(className)` only, never the two-argument form. Prefer
  `Kit.new(className, props, children)`, which also zeroes `BorderSizePixel`
  and sets `Parent` last.
- Text uses `FontFace` (via `Kit.text` styles or `Theme.Font.*`). Never read
  or write the legacy `Font` property.
- Do not read `AbsoluteSize`, `AbsolutePosition`, `TextBounds` or
  `ViewportSize` while building a screen; they are only valid after layout.
  Design with fixed design-unit sizes, `UIListLayout`, `UIPadding` and
  `AutomaticSize` instead.
- Globals available everywhere: `game`, `workspace`, `Instance`, `Enum`,
  `task`, datatypes (`UDim2`, `Vector2`, `Color3`, `CFrame`, ...), `TweenInfo`.
  Not available: `wait`, `spawn`, `delay` (use `task.*`).
- Buttons: connect `Activated` (works for mouse, touch and gamepad). Kit
  buttons, icon buttons, toggles and cards already do this and already handle
  hover, pressed, disabled, selected, locked and loading states; use their
  setters instead of restyling instances.
- Animation: only through `Kit.tween` (it honours `Kit.reduceMotion`). Keep
  motion short (`Theme.Motion`). Looping effects must stop when the screen is
  hidden or destroyed. In the harness tweens jump straight to their goal and
  `RunService.Heartbeat` only fires when a scene calls `env.h:step(dt)`.
- Colours, sizes and fonts come from `Theme` / `Kit`. No hard-coded hex
  colours, no default Roblox fonts or button colours, no emoji, no text smaller
  than 12 design units.
- No uploaded assets exist: no image, decal or sound asset ids. Icons come
  from `Kit.icon` (names in `Kit.Icons.Names`). Player portraits come from
  `Kit.avatar` (it uses `rbxthumb://`, which needs no upload).

## Architecture rules

- Screens are views. They never touch RemoteEvents, RemoteFunctions, the
  Store, or DataStores. Everything that changes state goes through the
  callbacks passed to `new(options)`. A callback documented as returning
  `Net.Result` may yield while the server answers: put the pressed button in
  its loading state, ignore further input on that surface until it returns,
  then show `result.message` in the screen's error banner when `result.ok` is
  false. Never assume success; the party state arrives separately through
  `Render`.
- Every control must do something real. If a feature is unavailable in the
  current state, disable the control and say why in words next to it. No
  placeholder text, no "coming soon", no fake buttons.
- Module shape:

  ```lua
  local Screen = {}
  Screen.__index = Screen
  function Screen.new(options) ... return setmetatable(self, Screen) end
  function Screen:Destroy() ... end   -- disconnects everything, destroys instances
  return Screen
  ```

- `options.parent` is either a `Kit.layer` frame or a ScreenGui, as stated for
  your screen. Inside a layer you position and size in design units; the layer
  is as large as the screen divided by the HUD scale (`Kit.layerSize()`), with
  the origin at the top-left below the Roblox top bar. Reserved areas inside
  the HUD layer (design units):
  - HUD dock: top centre, y 8 to 72.
  - Toasts and popovers (settings, notifications): top centre, from y 84.
  - Invite cards: top-left, x 16, from y 84.
  - Party panel: right edge (16 margin), never above y 84.
  - Join prompt: bottom centre, 24 above the bottom edge.
  - Phones in landscape show virtual controls in the bottom-left and
    bottom-right corners (about 200 x 170 design units each): keep those clear.
- Layout must hold at 1280x720, 1920x1080, 1366x768, 1024x768 and 844x390
  (phone landscape): nothing overlaps, clips, or runs off screen; long player
  names (20 characters) truncate with an ellipsis instead of breaking layout.

## Scenes and renders

Create one scene script `tools/scenes/<yours>.luau` following
`tools/scenes/kit.luau`: `Scenes.setup()` gives `env` with `Kit`, `Theme`,
`Config`, `Net`, `Unlocks`, `playerGui`, `player`, `roblox`, `Harness`,
`env.require("UI/Name")` to load a client module, and
`env.capture(name, width, height)` which sets the viewport and writes
`docs/renders/ui/<name>-<W>x<H>.png` (plus an `.svg` beside it). Force
interaction states with `Harness.fire(button.Face, "Activated")`,
`"MouseEnter"`, `"MouseButton1Down"`. End the script with `process.exit(0)`.

Render every state your screens have at 1280x720, and the most crowded state
at the other four viewports. Look at each PNG critically and fix what is wrong
(overlap, clipping, cramped or empty areas, weak hierarchy, misalignment,
unreadable text) until it holds up. Expect to iterate several times.

The renderer is an approximation: ViewportFrames and avatar images are drawn
as placeholders, fonts are close stand-ins, and UIStroke/gradient edges differ
slightly from Roblox. Judge layout, hierarchy and colour, not pixel-exactness.

## Final report

List: the public API of each module as implemented (exact signatures), every
state you rendered with its file name, what you checked at each viewport, the
output of the checks you ran, anything you could not verify headlessly, and
any Kit change you would have wanted (do not edit the Kit or other people's
files; build a local helper in your own module instead and say so).
