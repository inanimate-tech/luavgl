-- Image sources and fonts (tests/check-image-src.sh): an embedder that runs
-- untrusted scripts must not let one name memory.
--
-- LVGL reads an image source whose first byte is below 0x20 as a pointer to
-- an lv_image_dsc_t, so the binding accepts only what lv_image_src_get_type
-- calls a symbol (first byte 0x80 and up, drawn as text) or, in a build with
-- LUAVGL_IMAGE_SRC_FILE, a path. LVGL calls through function pointers inside
-- an lv_font_t, so text_font accepts only fonts luavgl handed out.
--
-- A style and a dropdown keep their source by pointer: the lifetime cases
-- below hand them strings built at run time, drop every reference and
-- collect, then the harness renders. ASan reports a use-after-free if the
-- binding did not keep the string alive.
local lvgl = require("lvgl")

local results = {}
local function check(name, ok) results[#results + 1] = (ok and "ok " or "FAIL ") .. name end
local function raises(f) return not pcall(f) end

local OK, HOME, PLAY = "\xEF\x80\x8C", "\xEF\x80\x95", "\xEF\x81\x8B" -- LV_SYMBOL_*
local EMOJI = "\xF0\x9F\x98\x80" -- not an LV_SYMBOL, still a symbol to LVGL

local root = lvgl.Object(nil, { w = 240, h = 135 })

-- An lv_image_dsc_t spelled in a string: magic 0x19, a header, then a data
-- pointer the script chose, which LVGL reads and draws from if the binding
-- lets the string through.
local forged = string.pack("<BBI2I2I2I2I2I4I8I8",
  0x19, 0x10, 0, 16, 16, 64, 0, 1024, 0x414141414140, 0)

-- Refused --------------------------------------------------------------------
local img = root:Image { src = OK }
check("Image{src=forged} raises", raises(function() root:Image { src = forged } end))
check("set_src(forged) raises", raises(function() img:set_src(forged) end))
check("set{src=forged} raises", raises(function() img:set { src = forged } end))
check("get_img_size(forged) raises", raises(function() img:get_img_size(forged) end))
check("bg_image_src=forged raises", raises(function() root:set { bg_image_src = forged } end))
check("Style{bg_image_src=forged} raises",
  raises(function() lvgl.Style { bg_image_src = forged } end))
check("set_style{arc_image_src=forged} raises",
  raises(function() root:set_style({ arc_image_src = forged }, 0) end))
local dd = root:Dropdown { options = "a\nb", w = 100, y = 60 }
check("dropdown symbol=forged raises", raises(function() dd:set { symbol = forged } end))
check("Dropdown{symbol=forged} raises",
  raises(function() root:Dropdown { options = "a", symbol = forged } end))
check("empty string raises (first byte 0 is a descriptor)",
  raises(function() img:set_src("") end))
check("light userdata raises",
  raises(function() img:set_src(lvgl.BUILTIN_FONT.DEFAULT) end))
check("full userdata raises", raises(function() img:set_src(root) end))
check("number raises", raises(function() img:set_src(1234) end))

-- Accepted -------------------------------------------------------------------
check("symbol is accepted", pcall(function() img:set_src(PLAY) end))
check("symbol plus text is accepted", pcall(function() img:set_src(PLAY .. " play") end))
check("glyph outside LV_SYMBOL_* is accepted", pcall(function() img:set_src(EMOJI) end))
check("set_src(nil) is a no-op", pcall(function() img:set_src(nil) end))
check("src reads back as the string", (function()
  img:set_src(OK)
  return img:get("src") == OK
end)())
check("dropdown symbol is accepted and reads back", (function()
  dd:set { symbol = HOME }
  return dd:get("symbol") == HOME
end)())

-- Lifetime: strings a style or dropdown keeps by pointer -----------------------
local function runtime(s) return string.char(s:byte(1, -1)) .. "" end

local styled = root:Object { w = 40, h = 40, x = 0, y = 0 }
do styled:set { bg_image_src = runtime(HOME .. " a") } end

local per_state = root:Object { w = 40, h = 40, x = 40, y = 0 }
do per_state:set_style({ bg_image_src = runtime(HOME .. " b") }, 0) end

local style = lvgl.Style {}
do style:set { bg_image_src = runtime(HOME .. " c") } end
local with_style = root:Object { w = 40, h = 40, x = 80, y = 0 }
with_style:add_style(style, 0)

do dd:set { symbol = runtime(PLAY .. " d") } end

-- replaced: the first string goes, the second must stay
do styled:set { bg_image_src = runtime(OK .. " e") } end

collectgarbage("collect")
collectgarbage("collect")
check("lifetime cases set up", true)

-- A deleted object's strings are released with it (and do not break a
-- later object at the same address).
do
  local gone = root:Object { w = 10, h = 10 }
  gone:set { bg_image_src = runtime(OK .. " f") }
  gone:delete()
end
collectgarbage("collect")
check("delete after anchoring", true)

-- Fonts ------------------------------------------------------------------------
local label = root:Label { text = "x", y = 100 }
check("text_font=lvgl.Font is accepted",
  pcall(function() label:set { text_font = lvgl.Font("montserrat", 14) } end))
check("text_font=BUILTIN_FONT is accepted",
  pcall(function() label:set { text_font = lvgl.BUILTIN_FONT.DEFAULT } end))
check("text_font read back is accepted", pcall(function()
  label:set { text_font = label:get("text_font") }
end))
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
