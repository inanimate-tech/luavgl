# Display-scoped binding

LVGL 9 can drive several displays. Upstream luavgl assumes there is only one.
This fork adds a handle tied to a single display.

- Bind a display and you get a handle.
- Widgets made through that handle appear on that display.
- Binding the same display twice returns the same handle.
- One display needs no changes: that is just the default-display case.

## Getting a handle

From C:

```c
#include <luavgl.h>

/* Pushes the handle table onto the Lua stack and returns 1. */
LUALIB_API int luavgl_bind_display(lua_State *L, lv_display_t *disp);
```

- It loads the lvgl module first if nothing has loaded it yet.
- A typical embedder maps a name to an `lv_display_t *` and calls this.

From Lua:

```lua
local lvgl = require("lvgl")
local left  = lvgl.bind()                    -- the default display
local right = lvgl.bind(some_disp_userdata)  -- e.g. from lvgl.disp.get_next()
```

## Using the handle

- A widget with no parent is placed on that display's active screen.
- The screen is looked up at the moment you create the widget, so it is never
  stale.
- A widget with an explicit parent behaves exactly as before.
- Dot calls and colon calls both work.

```lua
left.Label  { text = "on A" }
right:Label { text = "on B" }
local box = right.Object(nil, { w = 40, h = 20 })
box:Label { text = "child of box" }
```

The handle carries these members as well as the widget constructors:

| member | what it does |
|---|---|
| `h.disp` | the `lv_disp` userdata (`get_res`, `set_rotation`, ...) |
| `h.screen()` | the active screen as a luavgl object, owned by C and not deletable from Lua |
| `h.clean()` | empties the active screen and invalidates the Lua handles inside it |
| `h.HOR_RES()` / `h.VER_RES()` | this display's size, not the default display's |
| `h.mirror()` | `lvgl.mirror()` for this display's screen |
| `h.set_default()` | makes this display LVGL's global default |
| `h:set_theme{...}` | default styles for this display, below |

- Anything else falls through to the plain module: `Anim`, `Timer`, `Style`,
  `Font`, the constant tables, `palette`, `disp`.
- Timers and animations stay global, because that is LVGL's own model.
- Two handles can be live at once, and each display draws only its own widgets.
- `tests/bindswap.lua` covers the logic; `tests/bind-theme.lua` with
  `tests/check-bind.sh` checks the pixels on both displays.

## Themes

`h:set_theme{...}` sets default styles for one display.

```lua
h:set_theme {
  screen = { bg_color = "#0b0b10" },
  object = { bg_opa = 0, border_width = 0 },
  label  = { text_color = "#ececf2",
             text_font = lvgl.Font("montserrat", 20) },
}
```

- Defaults apply to widgets created after the call.
- Widgets that already exist keep the styles they were created with, because
  LVGL applies themes at creation time.
- Any theme already installed on the display becomes the parent and applies
  first, so your Lua values win property by property.
- Each value is a style table or an `lvgl.Style`.
- Do not call `style:delete()` on a style while a theme still holds it.
- `object` is the base pass: it applies to every widget, and the matching class
  key layers on top.
- Class keys are `object`, `label`, `button`, `image`, `textarea`, `checkbox`,
  `dropdown`, `roller`, `led`, `line`, `arc` and `scale`, each present when that
  widget is compiled in.
- `screen` is different: it styles the current active screen immediately.
- Calling `set_theme` again replaces the previous set rather than adding to it.
- `set_theme(nil)` removes your theme and restores the one underneath.
- A single tweak needs no theme at all: `h.screen():set{ bg_color = ... }`.

## Notes

- Deleting objects from C stays safe, and `tests/bindswap.lua` runs five
  build-and-wipe rounds on a second display under AddressSanitizer.
- The handle never reads LVGL's default display, because it always names the
  parent explicitly.
- `h.set_default()` exists for embedder code that does need the global default
  moved.
- Styles replaced by a later `set_theme` are kept in memory on purpose, because
  older widgets still point at them.
- That costs a few dozen bytes per replaced slot, and themes are usually set
  once per app.
- Handles, display userdata and theme state live in the Lua registry for as long
  as the display does.
- They are not reclaimed if a display is deleted, because displays are expected
  to last as long as the process.
- The C base theme's label font is a single process-wide value; use
  `set_theme{ label = { text_font = ... } }` for a per-display font.

## Pinning

- Build against `main`.
- Pin a commit SHA if you need a frozen build.
- Upstream (`XuNeo/luavgl`) is merged in by hand.
