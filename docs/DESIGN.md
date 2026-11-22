# Mushroom Guardians lobby UI: design specification

This is the design source for the lobby interface. Tokens live in
[`design/tokens.json`](../design/tokens.json) (importable into Penpot as design
tokens) and are compiled into `src/shared/ThemeTokens.luau`; components are
implemented once in `src/client/UI/Kit`. Screens are composed from Kit parts only.

## 1. Visual language

A warm, hand-carved world: panels are dark bark with a lighter wooden frame and
a little moss growing over two corners; text is parchment; actions are chunky
buttons that sit on a darker ledge and sink when pressed. Magic shows up
sparingly as spore-teal and crystal-violet accents.

| Role | Token | Use |
| --- | --- | --- |
| Bark 950-300 | `color.bark.*` | panels, cards, wood borders, shadows |
| Parchment 100-500 | `color.parchment.*` | text, light details |
| Moss 300-800 | `color.moss.*` | primary action, success, available |
| Amber 300-700 | `color.amber.*` | titles, selection, lantern light, leader |
| Spore 300-700 | `color.spore.*` | magic, info, countdown, focus |
| Crystal 300-700 | `color.crystal.*` | locked content, full parties |
| Cap 300-700 | `color.cap.*` | danger, errors, notification badges |
| Stone 300-700 | `color.stone.*` | disabled and unavailable |

Rules:

- One accent per meaning. Amber always means "selected / yours", violet always
  means "sealed" (locked or full), red always means "problem", teal always means
  "magic in progress" (countdown, loading, info), green always means "go".
- Colour never carries meaning alone: every state also has a word or an icon.
- No pure white, no pure black, no neon. Nothing uses default Roblox styling.

### Typography

| Style | Font | Size | Use |
| --- | --- | --- | --- |
| Display | Fredoka One | 28 | big numbers, hero titles |
| Title | Fredoka One | 22 | panel titles (amber 300) |
| Heading | Fredoka One | 18 | section and card titles, button labels (17) |
| Body / BodyStrong | Nunito SemiBold / Bold | 15 | running text |
| Label | Nunito ExtraBold | 13 | field labels, small caps headings |
| Caption | Nunito Bold | 12 | hints, chips. Nothing is smaller than this. |

Sizes are design units on a 1280x720 reference screen.

### Spacing, shape, depth

- 4-unit grid: 4, 8, 12, 16, 20, 24, 32. Panel padding 16, gaps between
  related controls 8, between groups 12-16.
- Radii: chips 6 or pill, cards and buttons 10, panels 14.
- Strokes: 2 for controls, 3 for the panel frame.
- Depth is a ledge, not a blur: buttons 4, cards 3, panels 6 units of darker
  material under the face. Panels also get a two-layer soft shadow.

### Scaling

Everything is authored in design units and scaled by `UIScale`:

- Panels: `Kit.autoScale(root, designSize)` follows `min(w/1280, h/720)`, never
  below 0.85 (readability) and never so large that the panel exceeds 94% of the
  screen (so it shrinks further only when it must, e.g. on a phone).
- HUD: `Kit.autoScale(root)` follows the same base with a 0.9 floor.
- The player's UI Size setting multiplies both.

## 2. Component states (Kit)

| Component | Normal | Hover | Pressed | Selected | Disabled | Locked | Loading |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Button | gradient face on ledge, outlined label | face 12% lighter | face sinks 3 units, 8% darker | n/a | stone face, muted label, no outline | n/a | spinner replaces icon, face darker, input ignored |
| Icon button | wood tile | lighter, name tag appears | sinks | amber tile, dark icon | stone tile | n/a | n/a |
| Card | bark face | lighter | sinks | amber frame, warm face, check badge | stone face | veil, violet lock badge, stays tappable to explain | n/a |
| Toggle | dark track, muted knob left | - | knob slides | moss track, bright knob right | stone | n/a | n/a |
| Badge | red dot or count on an icon button when something is waiting | | | | | | |

Variants of Button: Primary (moss: the one main action of a surface),
Secondary (wood: navigation, neutral actions), Accent (amber: Ready/Start
confirmation moments), Danger (cap red: Leave, Cancel, Decline).

Error state: a cap-red banner inside the surface that failed, with a Warning
icon and the server's sentence. Countdown state: spore-teal ring and number.

## 3. Screens

All sizes in design units. "World visible" means the panel must not exceed
about 35% of a 16:9 desktop screen.

### 3.1 Create Party (720 x 432, centred)

Opened by stepping onto a station pad (or its prompt). Focus order: map on the
left, run options on the right, main action bottom right.

```
+--------------------------------------------------------------------+
| (emblem) CREATE PARTY                         [ station chip ]     |  header 46
+--------------------------------------------------------------------+
| +----------------------------+   DIFFICULTY                        |
| |                            |   [ Normal ][ Hard (lock) ][ Night ]|  3 cards 62 high
| |  <   map preview (3D)   >  |   requirement / summary line        |
| |                            |   ------------------------------    |
| +----------------------------+   (sprout) Peaceful Mode    [toggle]|
|  CHAPTER 1            o o o      description line                  |
|  Sporewood Hollow                PARTY SIZE        [1][2][3][4]    |
|  two-line description            (you)(+)(+)( )   slots row        |
+--------------------------------------------------------------------+
| [ Back ]                               [ Invite ]      [ Create ]  |  footer
+--------------------------------------------------------------------+
```

- Left column (300 wide): preview 300x170 in a ViewportFrame with a wood frame;
  round arrow buttons overlap its left and right edges; page dots under it;
  chapter label (Label, amber), name (Heading 20), description (Body, 2 lines,
  secondary colour).
- Locked chapter: preview dimmed by a veil with a centred violet lock badge and
  the requirement sentence; Create is disabled and reads "Locked".
- Difficulty: three cards in a row. Each shows the name and 1-3 diamond pips.
  Locked ones use the Card locked state. The line under the row shows the
  selected difficulty's summary, or - after tapping a locked card - its
  requirement sentence with a small lock icon in violet.
- Peaceful Mode: icon, name, one-line description, toggle on the right. Hidden
  completely when `Config.PeacefulMode.Enabled` is false.
- Party size: four small numbered cards (1-4). Defaults to the station's size.
- Slots row: as many slots as the chosen size. First slot is the local player
  (avatar, amber ring, crown). Queued invites show the invitee's avatar with a
  dashed/teal ring and "Invited". Remaining slots are empty rings with a plus.
  Slots beyond the chosen size are not drawn.
- Footer: Back (Secondary, left). Invite (Secondary, with UserPlus icon; opens
  the invite picker; disabled when size is 1 with the reason in the hint line).
  Create (Primary, right). While the request is in flight Create shows the
  loading state and the other controls ignore input.
- Error: banner above the footer with the server's message; it clears on the
  next change.

### 3.2 Party panel (300 wide, right edge, vertically centred)

Shown while the player is in a party. Compact: header with chapter name,
difficulty chip and Peaceful chip; member rows (avatar 34, name, LEADER / READY
/ NOT READY chip); empty rows "Open slot"; pending invites as rows with a clock
icon and a small cancel button for the leader.

| Phase | Member sees | Leader sees |
| --- | --- | --- |
| Forming | [Ready] (Accent) / [Not ready] toggle, [Leave] | [Start] (Primary; disabled with "Waiting for N" until all ready), [Invite], [Leave] |
| Countdown | big teal number in a ring, "Starting...", [Leave] | same number, [Cancel] (Danger) |
| Teleporting | spinner, "Travelling to <chapter>..." | same |
| Error | red banner with the message above the Forming controls | same |

### 3.3 Join prompt (400 x 124, bottom centre)

Shown when the player steps onto a pad whose station already has a party.
Leader name, chapter, difficulty, member count as filled/empty pips, and
[Join] (Primary). When the party is full or starting the button is disabled and
reads "Full" / "Starting"; the card then explains why.

### 3.4 Invite card (360 x 96, top centre under the HUD)

"<Name> invited you" with run details, a draining time bar, [Accept]
(Primary) and [Decline] (Danger). Up to two stacked.

### 3.5 Invite picker (300 x up to 320 popover)

List of other players in the server with avatar and name. Queue mode (from
Create Party): rows toggle selected. Send mode (from the party panel): each row
has an [Invite] button that shows loading, then "Invited" or the error.
Empty state: "No other guardians are here yet."

### 3.6 HUD dock (top centre)

One row of 44-unit icon buttons on a slim bark strip: Party, Notifications,
Settings, then any external features (Pets, Shop, Stats, News) that actually
exist in this place. Currency pills (icon + amount) sit to the left of the
strip when the player has matching leaderstats. Badges: party = pending
invites, notifications = unread count. The open popover's button is selected.

### 3.7 Settings (340 x 300 popover under the dock)

Rows: UI Size (Small / Normal / Large segmented cards), Reduce Motion (toggle),
Party Invites (toggle), Ambient Effects (toggle). Each row has a one-line
description. Changes apply at once and are saved by the server.

### 3.8 Notifications (340 x up to 340 popover under the dock)

Newest first; level-coloured left bar and icon, message, relative time.
Empty state: "Nothing new in the grove."

### 3.9 Toasts (360 wide, top centre)

Transient one-line messages with a level-coloured left bar; at most three.

### 3.10 Teleport overlay

Full-screen bark veil at 35% opacity with a centred compact card: spinner,
"Travelling to <chapter>", difficulty and Peaceful chips, and a line that the
party is being sent together.

## 4. World signage

Station signs and status boards use the same fonts and status colours
(`Theme.Status`): OPEN (moss), FORMING (amber), FULL (violet), STARTING (teal),
CLOSED (stone), ERROR (red).
