-- Display-scoped bind (bind.c): two displays coexist, objects land on the
-- right panel, and the appswap discipline holds per display — C-side clean
-- (lv_obj_clean from the embedder) must invalidate Lua-held handles for
-- lua-created objects on the bound display, exactly as tests/appswap.lua
-- proves for the default path.
local lvgl = require("lvgl")

-- left: the harness's SDL display (the default), bound explicitly
local left = lvgl.bind()
-- right: a second, headless display created by the harness
local right = harness_bind_display(320, 200)

-- resolution is per-handle, not the default display's
assert(left.HOR_RES() == lvgl.HOR_RES(), "left should be the default display")
assert(right.HOR_RES() == 320 and right.VER_RES() == 200,
       "right should report its own resolution")

-- objects land on their own display, and only there
left.Label { text = "LEFT-ONLY" }
right.Label { text = "RIGHT-ONLY" }
assert(left.mirror():find("LEFT-ONLY", 1, true), "left label missing")
assert(not left.mirror():find("RIGHT-ONLY", 1, true), "right label leaked to left")
assert(right.mirror():find("RIGHT-ONLY", 1, true), "right label missing")
assert(not right.mirror():find("LEFT-ONLY", 1, true), "left label leaked to right")

-- parent defaulting matches the module contract: nil-parent, table-only,
-- colon call, and explicit parents
local a = right.Object(nil, { w = 10, h = 10 })
local b = right:Object { w = 10, h = 10 }
local c = b:Label { text = "child" }
assert(c:get_parent() == b, "explicit parent must still work")
assert(a:get_screen() == right.screen(), "nil-parent must land on right's screen")
assert(b:get_screen() == right.screen(), "colon call must land on right's screen")

-- appswap, per display: 5 generations of build / C-wipe / GC on the bound
-- display; stale handles must raise, not crash — and the other display's
-- tree must survive untouched
local stale = {}
for gen = 1, 5 do
  local root = right.Object(nil, { w = right.HOR_RES(), h = right.VER_RES(),
                                   bg_color = "#000000", border_width = 0 })
  for i = 1, 10 do
    local card = root:Object{ x = i * 3, y = i * 2, w = 40, h = 20 }
    card:Label{ text = "rgen" .. gen .. ":" .. i }
    if i % 5 == 0 then stale[#stale + 1] = card end
  end
  assert(right.mirror():find("rgen" .. gen, 1, true),
         "gen " .. gen .. " not on right display")
  right.clean()              -- the embedder's C-side wipe (lv_obj_clean)
  collectgarbage("collect")  -- stale userdata finalizers must not UAF
  collectgarbage("collect")
end
local ok = pcall(function() stale[1]:set{ x = 0 } end)
assert(ok == false, "using a C-deleted object should raise, not succeed")
assert(left.mirror():find("LEFT-ONLY", 1, true),
       "left display must survive right's swaps")

-- theme calls are per display and re-callable; nil uninstalls
right:set_theme {
  screen = { bg_color = "#204060" },
  label = { text_color = "#ff0000" },
}
right.Label { text = "themed" }
right:set_theme { label = { text_color = "#00ff00" } }
right:set_theme(nil)

-- bind is idempotent: one handle per display
assert(lvgl.bind(left.disp) == left, "re-bind must return the cached handle")
assert(harness_bind_display and lvgl.bind(right.disp) == right,
       "re-bind of the second display must return the cached handle")

print("bindswap: OK")
