local lvgl = require("lvgl")
local root = lvgl.Object(nil, { w = lvgl.HOR_RES(), h = lvgl.VER_RES(), bg_color = "#000000" })
root:Label{ text = "12:34" }
local card = root:Object{ w = 100, h = 40 }
card:Label{ text = "FOCUS" }
local m = lvgl.mirror()
assert(type(m) == "string", "mirror must return a string")
assert(m:find("12:34", 1, true), "mirror must contain label text, got: " .. m)
assert(m:find("FOCUS", 1, true), "mirror must reflect nested labels, got: " .. m)
print("mirror: OK  ->  " .. m)
