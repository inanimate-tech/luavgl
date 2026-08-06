-- Theme contract: with NO styling, an Object is an invisible flat layout
-- box and a Label is off-white at the DPI-derived default size.
local box = lvgl.Object(nil, { x = 20, y = 20, w = 200, h = 100 })
local lbl = box:Label{ text = "HELLO", x = 4, y = 4 }
