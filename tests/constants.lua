local lvgl = require("lvgl")
assert(lvgl.TEXT_ALIGN and lvgl.TEXT_ALIGN.CENTER, "TEXT_ALIGN missing")
assert(lvgl.GRAD_DIR and lvgl.GRAD_DIR.VER, "GRAD_DIR missing")
lvgl.Object(nil, {
  w = lvgl.HOR_RES(), h = lvgl.VER_RES(),
  bg_color = "#001020", bg_grad_color = "#200010", bg_grad_dir = lvgl.GRAD_DIR.VER,
}):Label{ text = "centered", w = 200, text_align = lvgl.TEXT_ALIGN.CENTER, align = lvgl.ALIGN.CENTER }
print("constants: OK")
