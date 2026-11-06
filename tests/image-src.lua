-- Image sources and fonts (tests/check-image-src.sh): an embedder that runs
-- untrusted scripts must not let one name memory. LVGL reads an image source
-- whose first byte is below 0x20 as a pointer to an lv_image_dsc_t, and calls
-- through function pointers inside an lv_font_t, so the binding accepts only
-- lvgl.SYMBOL strings as image sources and only fonts it handed out.
local lvgl = require("lvgl")

local results = {}
local function check(name, ok) results[#results + 1] = (ok and "ok " or "FAIL ") .. name end
local function raises(f) return not pcall(f) end

local root = lvgl.Object(nil, { w = 200, h = 100 })

-- An lv_image_dsc_t spelled in a string: magic 0x19, a header, then a data
-- pointer the script chose. Before the fix LVGL drew whatever it pointed at.
local forged = "\x19" .. string.rep("\0", 7) .. string.pack("<I4I4", 0x10, 0x10)
    .. string.rep("\0", 16)

-- Image sources ------------------------------------------------------------
check("Image{src=forged} raises", raises(function() root:Image { src = forged } end))
local img = root:Image { src = lvgl.SYMBOL.OK }
check("Image{src=SYMBOL.OK} is accepted", img ~= nil)
check("set_src(forged) raises", raises(function() img:set_src(forged) end))
check("set{src=forged} raises", raises(function() img:set { src = forged } end))
check("get_img_size(forged) raises", raises(function() img:get_img_size(forged) end))
check("bg_image_src=forged raises", raises(function() root:set { bg_image_src = forged } end))
check("Style{bg_image_src=forged} raises",
  raises(function() lvgl.Style { bg_image_src = forged } end))
check("arc_image_src=forged raises",
  raises(function() root:set_style({ arc_image_src = forged }, 0) end))
check("empty string raises (first byte 0 is a descriptor)",
  raises(function() img:set_src("") end))
check("light userdata raises",
  raises(function() img:set_src(lvgl.BUILTIN_FONT.DEFAULT) end))
check("full userdata raises", raises(function() img:set_src(root) end))
check("number raises", raises(function() img:set_src(1234) end))
check("symbol plus text raises",
  raises(function() img:set_src(lvgl.SYMBOL.PLAY .. " play") end))
check("every lvgl.SYMBOL is accepted", (function()
  local n = 0
  for _, name in ipairs { "BULLET", "OK", "CLOSE", "PLAY", "WIFI", "NEW_LINE" } do
    img:set_src(lvgl.SYMBOL[name])
    n = n + 1
  end
  return n == 6
end)())
check("set_src(nil) is a no-op", pcall(function() img:set_src(nil) end))

-- A style keeps its image source by pointer. Hand it a symbol string the
-- script built at run time, drop every reference and collect: the source
-- LVGL keeps must be the static literal, not the freed string (ASan).
do
  local bytes = { lvgl.SYMBOL.HOME:byte(1, -1) }
  root:set { bg_image_src = string.char(table.unpack(bytes)) }
  bytes = nil
end
collectgarbage("collect")
collectgarbage("collect")

-- Fonts --------------------------------------------------------------------
local label = root:Label { text = "x" }
check("text_font=lvgl.Font is accepted",
  pcall(function() label:set { text_font = lvgl.Font("montserrat", 14) } end))
check("text_font=BUILTIN_FONT is accepted",
  pcall(function() label:set { text_font = lvgl.BUILTIN_FONT.DEFAULT } end))
check("text_font=full userdata raises",
  raises(function() label:set { text_font = root } end))
check("text_font=string raises",
  raises(function() label:set { text_font = "montserrat" } end))
check("Style{text_font=full userdata} raises",
  raises(function() lvgl.Style { text_font = root } end))
check("set_style{text_font=full userdata} raises",
  raises(function() label:set_style({ text_font = root }, 0) end))
-- a light userdata that names something other than a font
local ok_disp, disp = pcall(function() return label:get("display") end)
if ok_disp and type(disp) == "userdata" then
  check("text_font=other light userdata raises",
    raises(function() label:set { text_font = disp } end))
end

local failed = 0
for _, r in ipairs(results) do
  print("image-src: " .. r)
  if r:sub(1, 4) == "FAIL" then failed = failed + 1 end
end
print("image-src: " .. (failed == 0 and "-> OK" or ("-> " .. failed .. " FAILED")))
