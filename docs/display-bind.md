# Display-scoped binding (arc fork)

LVGL 9 is natively multi-display (`lv_display_t` instances), but luavgl's
classic entry points (`luavgl_set_root` + `luaopen_lvgl`, or the firmware's
`lvgl.open()`) assume the default display. The arc fork adds a
display-scoped handle so an embedder can drive two panels from one
`lua_State`. The single-display path is untouched — it is simply the
default-display case.

## Getting a handle

**From C** (the embedder binds a specific display):

```c
#include <luavgl.h>

/* Pushes the handle table onto the Lua stack. Initialises the lvgl module
 * if needed (idempotent). Binding the same display twice returns the SAME
 * cached handle table. */
LUALIB_API int luavgl_bind_display(lua_State *L, lv_display_t *disp);
```

Typical embedder shape (e.g. a Resident `lvgl.bind(name)` that maps a
name to an `lv_display_t *`): look up the display, call
`luavgl_bind_display(L, disp)`, return 1.

**From Lua** (when displays are discoverable from Lua):

```lua
local lvgl = require("lvgl")
local left  = lvgl.bind()                        -- default display
local right = lvgl.bind(some_disp_userdata)      -- an lv_disp userdata,
                                                 -- e.g. from lvgl.disp.get_next(...)
```

## The handle

Widget constructors are scoped: with no explicit parent they land on the
bound display's **active screen**, resolved at call time (so an embedder
deleting/rebuilding screens never leaves the handle pointing at a stale
root). Explicit parents pass through unchanged. Both call styles work:

```lua
left.Label  { text = "on A" }
right:Label { text = "on B" }           -- colon call is equivalent
local box = right.Object(nil, { w = 40, h = 20 })
box:Label { text = "child of box" }     -- explicit parent, as always
```

Handle members beyond the constructors:

| member | meaning |
|---|---|
| `h.disp` | the `lv_disp` userdata (`get_res`, `set_rotation`, `get_layer_top`, ...) |
| `h.screen()` | active screen as a luavgl object (C-owned: not deletable from Lua) |
| `h.clean()` | `lv_obj_clean(active screen)` — the C-side wipe; invalidates Lua handles |
| `h.HOR_RES()` / `h.VER_RES()` | this display's resolution (not the default display's) |
| `h.mirror()` | tree serialization of this display's screen (`lvgl.mirror()` scoped) |
| `h.set_default()` | `lv_display_set_default(disp)` |
| `h:set_theme{...}` / `h:set_theme(nil)` | per-display default styles, below |

Everything not listed falls through (via `__index`) to the plain module
table: `Anim`, `Timer`, `Style`, `Font`, constants, `palette`, `disp`.
Timers and animations remain global — that is LVGL's model.

Two handles coexist; each display renders only its own tree.
`tests/bindswap.lua` (logic + use-after-free discipline) and
`tests/bind-theme.lua` + `tests/check-bind.sh` (pixel assertions on both
displays) are the proof.

## Theme surface from Lua

`h:set_theme{}` installs a per-display LVGL theme whose defaults apply to
objects **created afterwards** on that display (existing objects keep
their styles — LVGL applies themes at creation). The previously installed
theme (e.g. the arc C theme from `luavgl_arc_theme_init`) becomes the
parent and applies first, so Lua values override C defaults per property.

```lua
h:set_theme {
  screen = { bg_color = "#0b0b10" },            -- applied to the active
                                                -- screen immediately
  object = { bg_opa = 0, border_width = 0 },    -- base defaults for EVERY
                                                -- widget (the base-class
                                                -- pass, like the arc theme)
  label  = { text_color = "#ececf2",            -- per-class defaults,
             text_font = lvgl.Font("montserrat", 20) }, -- layered on top
}
```

- Values are style tables (any `lvgl.Style` property) or `lvgl.Style`
  userdata. Styles handed to `set_theme` must not be `style:delete()`d
  while the theme holds them.
- Class keys: `object`, `label`, `button`, `image`, `textarea`,
  `checkbox`, `dropdown`, `roller`, `led`, `line`, `arc`, `scale`
  (present when the widget is compiled in).
- `screen` is special: it is added to the **current** active screen right
  away (background color, padding, ...). Re-calling `set_theme` replaces
  the previous screen style rather than stacking.
- Each `set_theme{...}` call replaces the previous slot set for that
  display. `set_theme(nil)` uninstalls, restoring the prior theme.
- One-off tweaks don't need a theme at all: `h.screen():set{ bg_color = ... }`
  styles the screen object directly, today as before.

## Lifecycle and memory notes

- **C-side deletion stays safe.** The fork's handle-invalidation fix
  (`lv_obj_clean` from the embedder must invalidate Lua-held handles;
  `tests/appswap.lua`) applies unchanged on bound displays —
  `tests/bindswap.lua` runs the same 5-generation build/wipe/GC loop
  against a second display under AddressSanitizer.
- **No default-display juggling.** Creation parents to the bound display's
  screen explicitly, and LVGL only consults the default display for
  parentless screen creation — which the handle never does. `h.set_default()`
  exists for embedder code that needs the global default moved.
- **Replaced theme styles are kept alive on purpose.** Objects created
  under an earlier `set_theme` still reference those `lv_style_t`s;
  freeing them would dangle. A few dozen bytes per replaced slot, and
  themes are typically set once per app generation.
- Handles, disp userdata, and theme state are cached in the Lua registry
  per display and live for the display's lifetime (they are not reclaimed
  if a display is ever deleted — displays are process-lifetime objects in
  the intended embeddings).
- The arc C theme's label font is still a process-global (see
  `arc_theme.c`); a per-display font is exactly what `set_theme{ label =
  { text_font = ... } }` is for.

## Pinning

Consumers pin this fork by branch: **`arc` is the integration branch**
device firmware builds against (PlatformIO `library.json` at the repo
root). Feature branches (like `genmon/display-bind`) merge into `arc`;
upstream (`XuNeo/luavgl`) is tracked manually. If you need a frozen
build, pin a commit SHA or cut a tag from `arc`.
