-- A failed size lookup on the LAST name segment must raise a Lua error,
-- not read past the buffer. pcall proves it is a catchable error.
local lvgl = require("lvgl")
local ok, err = pcall(function()
  return lvgl.Font("nosuchfontname", 99)
end)
assert(ok == false, "expected an error for unknown font")
print("font_crash: OK")
