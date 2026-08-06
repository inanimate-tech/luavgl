-- A sheet-contract chunk must run unmodified in the harness.
lvgl = lvgl.open()
local scr = lvgl.Object(nil, { w = lvgl.HOR_RES(), h = lvgl.VER_RES() })
local lbl = scr:Label{ text = "42" }
function view_update() lbl:set{ text = "43" } end
view_update()
-- and a second open() must wipe and still work (remix-over-remix)
lvgl = lvgl.open()
local scr2 = lvgl.Object(nil, { w = 100, h = 50 })
scr2:Label{ text = "again" }
