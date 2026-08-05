-- Empty / space-only segments must not underflow the trim loop.
local lvgl = require("lvgl")
pcall(function() return lvgl.Font(" , ,montserrat", 16) end)
pcall(function() return lvgl.Font(",", 16) end)
pcall(function() return lvgl.Font("   ", 16) end)
print("font_names: OK")
