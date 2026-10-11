# F3

F3 is a small corner HUD for Roblox. It draws four debug panels, one in each screen corner, plus a draggable `F3` button and a hotkey that toggles the panels on and off.

Each panel is a `CanvasGroup`, so showing and hiding the whole menu fades the background, the text, and the text outlines together.

## Install

1. Put `F3.lua` in a `ModuleScript`. A common spot is `ReplicatedStorage` under the name `F3`.
2. Require it from a `LocalScript`.

There is no other dependency.

## Quick start

```lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local F3 = require(ReplicatedStorage:WaitForChild("F3"))

local gui = Instance.new("ScreenGui")
gui.Name = "F3"
gui.ResetOnSpawn = false
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local menu = F3.new({
	ScreenGui = gui,
	ToggleKey = Enum.KeyCode.F3,
})

local title = menu.LeftTop:Text({ Text = "Roblox F3", Color = Color3.fromRGB(255, 255, 100) })
local fps = menu.LeftTop:Text({ Text = "FPS: --" })

fps.Text = "FPS: 60"
```

Press `F3` or click the round button at the left center of the screen to hide or show the panels. The button is draggable.

## API

### F3.new(args)

Creates the menu and all four panels. Returns the menu object.

| Field | Type | Notes |
| --- | --- | --- |
| `ScreenGui` | `ScreenGui` | Required. The menu parents its panels here. |
| `ToggleKey` | `Enum.KeyCode` | Optional, defaults to `Enum.KeyCode.F3`. |
| `Visible` | `boolean` | Optional, defaults to `true`. |
| `Theme` | `Theme` | Optional. Any field you leave out falls back to the defaults. |

### Corners

The menu has four containers:

- `menu.LeftTop`
- `menu.RightTop`
- `menu.LeftBottom`
- `menu.RightBottom`

Each one is a `CanvasGroup` placed 10 px from the relevant screen edges. The panel width is `Theme.CornerWidth` (default `0.3`, a fraction of screen width), and the height grows with its content.

Text in the right corners is right aligned, text in the left corners is left aligned.

### Container methods

```lua
container:Text(args)          -- adds a TextLabel, returns a text control
container:Row(args)           -- nested container, children laid out horizontally
container:Column(args)        -- nested container, children laid out vertically
container:Clear()             -- destroys all children
container:Destroy()           -- destroys the container and its children
```

`Row` and `Column` return a container, so you can chain them:

```lua
menu.RightBottom:Column({ Spacing = 4 })
	:Row({ Spacing = 8 })
	:Column()
	:Text({ Text = "nested text", Wrap = true })
```

### Container args

| Field | Type | Notes |
| --- | --- | --- |
| `Spacing` | `number` | Padding between children. Defaults to `Theme.Spacing`. |
| `HorizontalAlignment` | `Enum.HorizontalAlignment` | Defaults to `Left`. |
| `VerticalAlignment` | `Enum.VerticalAlignment` | Defaults to `Top`. |

### Text args

| Field | Type | Notes |
| --- | --- | --- |
| `Text` | `string` | Defaults to an empty string. Rich text is enabled, see `F3.Color`. |
| `Color` | `Color3` | Defaults to `Theme.TextColor`. |
| `Font` | `Font` | Defaults to `Theme.Font`. |
| `Size` | `number` | Defaults to `Theme.TextSize`. |
| `Wrap` | `boolean` | Defaults to `false`. |

### Text control

`Text`, `Color`, `Font`, `Size`, and `Wrap` can be reassigned at runtime and the label updates right away:

```lua
local pos = menu.LeftBottom:Text({ Text = "XYZ: 0 / 0 / 0" })
pos.Text = string.format("XYZ: %d / %d / %d", x, y, z)
```

Every label gets a `UIStroke` outline using `Theme.StrokeColor`, so the text stays readable over any background.

### F3.Color(color, text)

Wraps a string in a rich text color tag. Because labels use rich text, you can mix colors in a single line:

```lua
menu.RightTop:Text({
	Text = F3.Color(Color3.fromRGB(85, 255, 85), "green") .. " and " ..
		F3.Color(Color3.fromRGB(255, 85, 85), "red"),
})
```

### Theme

`F3.new` merges your theme over these defaults.

| Field | Default |
| --- | --- |
| `Font` | Ubuntu |
| `TextSize` | `14` |
| `TextColor` | white |
| `StrokeColor` | black |
| `StrokeTransparency` | `0.5` |
| `BackgroundColor` | black |
| `BackgroundTransparency` | `0.35` |
| `CornerRadius` | `6` |
| `CornerWidth` | `0.3` |
| `Spacing` | `2` |

### Visible

`menu.Visible` reads and writes the menu state. Assigning it fades the panels in or out over 0.3 seconds:

```lua
menu.Visible = false
```

The `F3` button and the `ToggleKey` hotkey do the same thing.

### Destroy

```lua
menu:Destroy()
```

Removes the panels, the button, and all connections.

## Hiding the corner backgrounds

By default each corner draws a black rounded rectangle behind its text. If you want only the text, set the corner's `BackgroundTransparency` to `1`. The corner instance is the live `CanvasGroup`, so the change applies immediately:

```lua
menu.LeftTop.Instance.BackgroundTransparency = 1
```

To hide all four:

```lua
for _, corner in { menu.LeftTop, menu.RightTop, menu.LeftBottom, menu.RightBottom } do
	corner.Instance.BackgroundTransparency = 1
end
```

If you never want the backgrounds, set it in the theme instead, so the panels start without them:

```lua
local menu = F3.new({
	ScreenGui = gui,
	Theme = { BackgroundTransparency = 1 },
})
```

Setting `BackgroundTransparency` does not affect the fade. The fade drives `GroupTransparency` and the per-element transparency, so it works the same with or without a background.

## Notes

- The menu runs entirely on the client. Build it in a `LocalScript`.
- The theme is read when panels and text are created. Changes to `menu.Theme` after `F3.new` do not rebuild existing panels, so pass theme values up front.
- The `F3` button is separate from the panels and does not fade with them, so you always have something to click.
