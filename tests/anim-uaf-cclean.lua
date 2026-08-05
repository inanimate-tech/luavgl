-- Device crash-loop repro (2026-08-05): objects deleted from the C side
-- (lv_obj_clean in the firmware's lvgl.open()) skip luavgl's handle
-- invalidation for lua_created objects, so a surviving infinite Anim's
-- exec_cb writes through a dangling pointer. Pre-fix: ASan abort here.
-- Post-fix: handles null cleanly and the orphan anim self-deletes.
local lvgl = require("lvgl")
local root = lvgl.Object(nil, { w = lvgl.HOR_RES(), h = lvgl.VER_RES(),
                                bg_color = "#000000", border_width = 0 })
local pulse = root:Object{ w = 10, h = 10, radius = lvgl.RADIUS_CIRCLE,
                           bg_color = "#40c0ff", border_width = 0 }
pulse:Anim{ run = true, start_value = 60, end_value = 255, duration = 300,
  repeat_count = lvgl.ANIM_REPEAT_INFINITE, path = "ease_in_out",
  exec_cb = function(o, v) o:set{ bg_opa = v } end }
harness_clean_screen()   -- what the firmware's second lvgl.open() does
local ok = pcall(function() pulse:set{ x = 1 } end)
assert(ok == false, "stale handle must raise after C-side clean")
print("anim-uaf-cclean: handles invalidated, pumping for the anim...")
