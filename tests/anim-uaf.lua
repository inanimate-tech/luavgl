-- Repro for the device crash-loop (2026-08-05): an infinite Anim created by
-- one look survives the next look's panel wipe (lvgl.open -> lv_obj_clean)
-- because lv_anim.var is the luavgl wrapper, not the lv_obj — LVGL's
-- delete-time lv_anim_delete(obj, NULL) never matches it. The anim's
-- exec_cb then drives obj:set{} on a freed object at frame rate.
local lvgl = require("lvgl")
local root = lvgl.Object(nil, { w = lvgl.HOR_RES(), h = lvgl.VER_RES(),
                                bg_color = "#000000", border_width = 0 })
local pulse = root:Object{ w = 10, h = 10, radius = lvgl.RADIUS_CIRCLE,
                           bg_color = "#40c0ff", border_width = 0 }
pulse:Anim{ run = true, start_value = 60, end_value = 255, duration = 300,
  repeat_count = lvgl.ANIM_REPEAT_INFINITE, path = "ease_in_out",
  exec_cb = function(o, v) o:set{ bg_opa = v } end }
root:delete()   -- the second look's lvgl.open() does exactly this
print("anim-uaf: scene deleted, pumping...")
-- harness keeps pumping lv_timer_handler after the script returns; if the
-- surviving anim UAFs, ASan aborts the run.
