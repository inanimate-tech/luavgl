-- The lvgl-demo generation's view portion, host-runnable: arc lines are
-- stubbed, the luavgl code is byte-identical to m5stick-arc/app/lvgl-demo.lua.
local lvgl = require("lvgl")

local root = lvgl.Object(nil, {
  w = lvgl.HOR_RES(), h = lvgl.VER_RES(),
  bg_color = "#0a0a14", border_width = 0, radius = 0, pad_all = 0,
})
root:clear_flag(lvgl.FLAG.SCROLLABLE)

local counter = root:Label{
  text = "0", text_color = "#ffd040",
  text_font = lvgl.Font("montserrat", 40), align = lvgl.ALIGN.CENTER,
}
root:Label{ text = "A: count up", text_color = "#555566",
  text_font = lvgl.Font("montserrat", 12), align = lvgl.ALIGN.BOTTOM_LEFT, x = 6, y = -4 }

local pulse = root:Object{ w = 10, h = 10, radius = lvgl.RADIUS_CIRCLE,
  bg_color = "#40c0ff", border_width = 0, align = lvgl.ALIGN.TOP_RIGHT, x = -8, y = 8 }
pulse:Anim{ run = true, start_value = 60, end_value = 255, duration = 900,
  repeat_count = lvgl.ANIM_REPEAT_INFINITE, path = "ease_in_out",
  exec_cb = function(o, v) o:set{ bg_opa = math.floor(v * 100 / 255) } end }

-- simulate three bump intents
local count = 0
for i = 1, 3 do count = count + 1; counter:set{ text = tostring(count) } end
assert(lvgl.mirror():find("3", 1, true), "counter should read 3")
print("arc-demo: OK")
