/* arc_theme.c — arc's base theme: dark, flat, readable.
 *
 * New Objects are invisible layout boxes (transparent, no border/pad,
 * not scrollable — re-add with obj:add_flag(lvgl.FLAG.SCROLLABLE)).
 * Labels default to off-white, sized from the display's DPI (montserrat
 * nearest 20px-at-240dpi). Installed by the firmware driver and the
 * desktop harness so both render identically.
 */
#include "luavgl.h"

static lv_style_t arc_style_obj;
static lv_style_t arc_style_label;
static lv_theme_t arc_theme;
static bool arc_theme_inited;

/* g_builtin_montserrat comes from font.c (same translation unit). */
static const lv_font_t *arc_pick_font(int32_t dpi)
{
  int32_t target = 20 * dpi / 240;
  const lv_font_t *best = LV_FONT_DEFAULT;
  int32_t best_d = INT32_MAX;
  for (size_t i = 0;
       i < sizeof(g_builtin_montserrat) / sizeof(g_builtin_montserrat[0]);
       i++) {
    int32_t d = target - g_builtin_montserrat[i].size;
    if (d < 0) d = -d;
    if (d < best_d) { best_d = d; best = g_builtin_montserrat[i].font; }
  }
  return best;
}

static void arc_theme_apply(lv_theme_t *th, lv_obj_t *obj)
{
  (void)th;
  if (lv_obj_check_type(obj, &lv_obj_class)) {
    lv_obj_add_style(obj, &arc_style_obj, 0);
    lv_obj_clear_flag(obj, LV_OBJ_FLAG_SCROLLABLE);
  }
  else if (lv_obj_check_type(obj, &lv_label_class)) {
    lv_obj_add_style(obj, &arc_style_label, 0);
  }
}

void luavgl_arc_theme_init(lv_display_t *disp)
{
  if (!arc_theme_inited) {
    lv_style_init(&arc_style_obj);
    lv_style_set_bg_opa(&arc_style_obj, LV_OPA_TRANSP);
    lv_style_set_border_width(&arc_style_obj, 0);
    lv_style_set_outline_width(&arc_style_obj, 0);
    lv_style_set_radius(&arc_style_obj, 0);
    lv_style_set_pad_all(&arc_style_obj, 0);

    lv_style_init(&arc_style_label);
    lv_style_set_text_color(&arc_style_label, lv_color_hex(0xececf2));

    lv_theme_set_apply_cb(&arc_theme, arc_theme_apply);
    arc_theme_inited = true;
  }
  /* font depends on this display's dpi — set it each install.
   * arc_style_label is a shared static, so this write is process-global:
   * with more than one display, the last luavgl_arc_theme_init() call wins
   * for all of them. Fine today (one display per process); would need a
   * per-display style if/when a multi-display face port lands. */
  lv_style_set_text_font(&arc_style_label, arc_pick_font(lv_display_get_dpi(disp)));
  lv_display_set_theme(disp, &arc_theme);

  /* the screen predates the theme install — style it directly */
  lv_obj_t *scr = lv_display_get_screen_active(disp);
  lv_obj_set_style_bg_color(scr, lv_color_hex(0x0b0b10), 0);
  lv_obj_set_style_bg_opa(scr, LV_OPA_COVER, 0);
  lv_obj_set_style_pad_all(scr, 0, 0);
}
