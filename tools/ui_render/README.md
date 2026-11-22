# ui_render

A headless renderer for Roblox GUI trees. It lays a tree out the way Roblox
would, writes the computed rectangles back onto the instances, and serialises
the result as layered SVG and (through headless Chrome) PNG. It exists so the
lobby UI can be reviewed at several screen sizes without Roblox Studio.

It is an approximation for visual QA of layout, clipping, overlap, colour and
text. It is not a pixel-exact emulator; see [Known deviations](#known-deviations).

## Usage

```sh
lune run tools/ui_render/demo      # writes build/ui/demo-{1280x720,1920x1080,844x390}.{svg,png}
lune run tests/ui_render.spec      # layout maths
```

```lua
local roblox = require("@lune/roblox")
local Render = require("../tools/ui_render") -- path relative to the calling file

-- roots: one ScreenGui, a list of them, or a container such as PlayerGui.
local result = Render.capture(playerGui, {
	viewport = roblox.Vector2.new(1280, 720),
	path = "build/ui/create-party-1280x720.png",
})
print(result.png, result.svg)
```

Chrome is taken from `CHROME_PATH` (falls back to `google-chrome` on `PATH`).

With the harness, build the UI in a client context and pass the player's
PlayerGui (instances come from the same `@lune/roblox` library):

```lua
local Harness = require("../tools/harness")
local h = Harness.new()
local player = h:addPlayer({ name = "Tester", userId = 1 })
h:setLocalPlayer(player)
-- ... run the client UI code so it parents ScreenGuis to PlayerGui ...
Render.capture(player:FindFirstChild("PlayerGui"), { viewport = h.camera.ViewportSize, path = "build/ui/lobby.png" })
```

## API

| Function | Returns |
| --- | --- |
| `Render.layout(roots, viewport, options?)` | `nodes, order`. `nodes[instance]` has `x, y, w, h` (screen pixels, before rotation), `scale` (accumulated UIScale), `visible`, `padding`, and for text objects `text = { block = { lines, width, height }, spec, fits }`. Also writes `AbsoluteSize`, `AbsolutePosition`, `TextBounds`, `TextFits` and `UIListLayout/UIGridLayout.AbsoluteContentSize` onto the instances. |
| `Render.toSvg(roots, options?)` | `svg, nodes`. Runs the layout itself. |
| `Render.writePng(svg, pngPath, width, height, pixelRatio?)` | `pngPath, svgPath` (absolute). Writes `<name>.svg` beside the PNG. |
| `Render.capture(roots, options)` | `{ png, svg, layout }`. Layout + SVG + PNG; `options.path` is the PNG path. |
| `Render.measureText(text, textSize, fontFace?, maxWidth?)` | `width, height` in whole pixels, wrapped at `maxWidth` when given. |

`viewport` is a `Vector2` or `{ X, Y }` (default 1280 x 720). Options, all optional:

| Option | Meaning |
| --- | --- |
| `viewport` | Screen size (`toSvg`, `capture`). |
| `background` | What stands in for the 3D world: a CSS colour, or a list of colours with an optional `angle` in degrees, e.g. `{ "#40566a", "#1b2821", angle = 90 }`. Default is a muted forest-dusk gradient. |
| `title` | SVG `<title>`. |
| `topInset` | Height of the Roblox top bar, default `58`. ScreenGuis with `IgnoreGuiInset = false` start below it, and `AbsolutePosition` is reported relative to it, as in Roblox. Pass `0` to match the harness's `GetGuiInset` mock. |
| `roundedClip` | `true` makes `ClipsDescendants` follow `UICorner`. Roblox does not do this (see below), so it is off by default. |
| `showTopbar` | Draws the approximate footprint of Roblox's own top-left buttons, to spot HUD collisions. |
| `pixelRatio` | Device scale factor for the PNG (`capture`), default `1`. |

A root may also be a bare GuiObject (laid out as if the viewport were its parent)
or a SurfaceGui / BillboardGui; pass the canvas size as `viewport` for those.

## SVG structure

One `<g id data-name data-class>` per instance (ids are made unique with a
numeric suffix, `data-name` keeps the original), nested like the instance tree,
so layer names survive an import into Penpot. Backgrounds and strokes are
`<rect rx>`, gradients are `<linearGradient>` in `<defs>`, clipping uses
`<clipPath>`, and text is `<text>` with one `<tspan>` per line.

The SVG names its fonts (`Fredoka One`, `Nunito`, `Montserrat`) but does not
embed them. The PNG path loads the cached TTFs through an HTML wrapper; a design
tool needs those fonts installed to show the same text.

## Fonts

| Roblox family | Rendered with |
| --- | --- |
| `rbxasset://fonts/families/FredokaOne.json` | Fredoka One (one weight, 400) |
| `rbxasset://fonts/families/Nunito.json` | Nunito at the requested weight (200-900), with italics |
| `GothamSSm.json`, `Montserrat.json` and anything else | Montserrat at the nearest weight, the face Roblox itself substitutes for Gotham |

Static TTFs (latin subset) are downloaded on demand from the Fontsource CDN
(`cdn.jsdelivr.net/fontsource/fonts/<id>@latest/latin-<weight>-<style>.ttf`)
into `tools/.cache/fonts/`, which is gitignored. Widths come from the files'
`cmap` and `hmtx` tables.

Text size follows the published description of Roblox's behaviour
([Understanding Roblox typography](https://fluff.blog/2024/07/24/understanding-roblox-typography.html)):
`TextSize` is the pixel distance between the font's lowest and highest glyph
extents, not the em size. The extents are constants in `fonts.luau`, read from
the full upstream fonts (Fredoka One 974 / -236, Nunito 1039 / -276 per 1000
units). So `TextSize = 20` is a 16.5px CSS font size in Fredoka One and 15.2px
in Nunito. A line box is `TextSize * LineHeight` tall with the glyph box centred
in it, and `TextBounds.Y` is the sum of the line boxes.

## Supported

- **Roots:** ScreenGui `Enabled`, `DisplayOrder`, `IgnoreGuiInset` / `ScreenInsets`; a UIScale, UIPadding or layout directly under a ScreenGui.
- **Objects:** Frame, TextLabel, TextButton, TextBox (placeholder text when empty), ImageLabel, ImageButton, ScrollingFrame, CanvasGroup, ViewportFrame. A Folder is transparent: its children are laid out in the Folder's parent.
- **GuiObject:** `Size`, `Position`, `AnchorPoint`, `Rotation` (about the centre, children rotate with the parent), `Visible`, `ZIndex` (Sibling behaviour), `LayoutOrder`, `BackgroundColor3`, `BackgroundTransparency`, `ClipsDescendants`, `AutomaticSize`.
- **Text:** `Text`, `TextColor3`, `TextTransparency`, `TextSize`, `FontFace`, both alignments, `TextWrapped` (word wrap, over-long words break), `TextTruncate`, `TextScaled` with UITextSizeConstraint, `LineHeight`, `RichText` (`<b>`, `<i>`, `<u>`, `<s>`, `<font color="#rrggbb" | "rgb(r,g,b)" size="n">`, `<br/>`, the five XML entities; other tags are stripped), `TextStrokeColor3` / `TextStrokeTransparency`, `MaxVisibleGraphemes`.
- **Modifiers:** UICorner, UIStroke (`Color`, `Thickness`, `Transparency`, `LineJoinMode`, `ApplyStrokeMode`, `BorderStrokePosition`, `Enabled`, a child UIGradient), UIGradient (`Color`, `Transparency`, `Rotation`, `Offset`, `Enabled`; multiplied with the background colour, and with the text colour on text objects), UIPadding, UIScale (cumulative; scales offsets, text sizes, stroke thickness, corner radii, padding and size constraints), UIListLayout (`FillDirection`, `Padding`, both alignments, `SortOrder`, `Wraps`, `HorizontalFlex` / `VerticalFlex`), UIFlexItem (`FlexMode`, `GrowRatio`, `ShrinkRatio`), UIGridLayout (`CellSize`, `CellPadding`, `FillDirection`, `FillDirectionMaxCells`, `StartCorner`, both alignments, `SortOrder`), UIAspectRatioConstraint, UISizeConstraint, UITextSizeConstraint.
- **Placeholders:** an ImageLabel / ImageButton with an `Image` draws a block tinted with `ImageColor3` at 70% of its opacity plus a faint cross; with an empty `Image` only the background. A ViewportFrame draws its background, a hatch and the caption "3D preview".

## Not supported

`SizeConstraint`, `BorderSizePixel` (treated as 0), ZIndexBehavior Global,
image pixels and `ScaleType` / slicing, `CanvasPosition` and scroll bars,
`GroupColor3`, UITableLayout, UIPageLayout, UIDragDetector, `TextDirection`,
OpenType features, `<stroke>`, `<uc>`, `<sc>`, `<font face | weight | transparency>`
and `<mark>` rich text tags, emoji and scripts outside the latin subset
(measured with a fallback width and drawn with whatever the browser substitutes),
BillboardGui distance scaling, and anything animated (the render is a still of
the current property values).

## Known deviations

None of this has been compared against Roblox Studio; the rules below are from
the documentation and published behaviour, and each is a place where the real
client may differ.

- **Rounded clipping is deliberately not applied.** In Roblox `ClipsDescendants` clips to the plain rectangle and ignores UICorner; only a CanvasGroup clips to its rounded shape. The renderer does the same, so a child that pokes out of a rounded corner here will poke out in game. `roundedClip = true` switches to the idealised behaviour.
- **Text metrics are the least certain part.** The glyph-box rule comes from one published source. The other plausible rule (the `hhea` ascender and descender) gives the same size for Fredoka One and 3.7% smaller text for Nunito. The same extents are used for every weight of a family, although the real box varies by a percent or two between weights. Montserrat uses its `hhea` values (968 / -251), because its glyph box differs between builds of the font, so text in the fallback family is only roughly sized. Roblox may also round font sizes to whole pixels. Kerning is disabled in the output so that it matches the measured advance widths; kerned text is usually slightly narrower. Treat text that fits with less than about 5% to spare as at risk.
- **Vertical text position** follows the same glyph-box rule: the tallest accent touches the top of the line box and the deepest descender the bottom. The real client may sit a pixel or two off this.
- **Rich text bold in Fredoka One** (which has one weight) is synthesised by the browser but measured with regular widths.
- **TextTruncate** always cuts at a character and adds an ellipsis; `SplitWord` and `AtEnd` are treated alike.
- **TextScaled** searches whole text sizes from 1 to 100 with word wrapping and never splits a word, which is close to but not exactly Roblox's search.
- **AutomaticSize** grows to the larger of `Size` and the content extent (children plus padding, or the layout's content size). Children sized by scale on the automatic axis are resolved against the minimum size first; Roblox's own rule for that circular case differs in detail. A wrapping list only wraps on an axis that is not automatic.
- **Flex.** `UIFlexAlignment.Fill` gives every item an equal share of the free space on top of its own size. `UIFlexMode.Grow` and `Shrink` use a ratio of 1 as documented; `GrowRatio` / `ShrinkRatio` only apply in `Custom` mode. Wrapped lines are spaced by `Padding` on both axes.
- **UIAspectRatioConstraint** with `ScaleWithParentSize` takes the parent's size on the dominant axis and ignores the element's own `Size`.
- **UISizeConstraint / UITextSizeConstraint** limits are multiplied by the accumulated UIScale; Roblox may apply them unscaled.
- **UIGradient** at angles other than 0 / 90 / 180 / 270 uses the CSS gradient length (the projection of the box on the gradient axis), which may not match Roblox's on non-square elements. `Offset` shifts the gradient by a fraction of the element's size along X and Y.
- **UIStroke** is drawn straight after the element's background, below its children, and is cut off by a clipping ancestor. A Contextual stroke on text is an SVG outline drawn under the glyphs; its corner shapes at large thickness differ slightly from Roblox's.
- **ScrollingFrame** lays children out against `max(frame size, CanvasSize)` and ignores `AutomaticCanvasSize`, so the Roblox default `CanvasSize` of `{0, 0}, {2, 0}` doubles the height that scale-sized children see, as it does in game. Scroll bars are not drawn and do not take space.
- **UIListLayout.SortOrder** defaults to `Name` under Lune, as `Instance.new` does in the engine; Studio's insert menu sets `LayoutOrder`. Set it explicitly.
- **Top bar.** The inset is a constant 58px and the `showTopbar` shapes are approximate; device safe areas (notches) are not modelled.
- **Computed properties** are written once per layout call. Game code that reads `AbsoluteSize` and then changes properties needs another `Render.layout` call to see the result.
