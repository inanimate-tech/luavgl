/* harness.c — bake-off runner for model-generated luavgl scripts.
 *
 * Usage: harness <script.lua> [run_ms] [out.bmp] [w] [h]
 *
 * Creates a w×h SDL window (default 240×135, the M5Stick panel), a black
 * full-size root object, runs the script, pumps lv_timer_handler for
 * run_ms (default 2000), snapshots the screen to a 32bpp BMP, and exits:
 *   0 = script loaded, ran, and survived the pump
 *   2 = load or runtime error (message on stdout)
 */
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#include <lvgl.h>
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
#include <luavgl.h>

static int msghandler(lua_State *L)
{
  const char *msg = lua_tostring(L, 1);
  if (msg == NULL) msg = "(non-string error)";
  luaL_traceback(L, L, msg, 1);
  return 1;
}

static int write_bmp(const char *path, lv_draw_buf_t *buf)
{
  int w = buf->header.w, h = buf->header.h;
  uint32_t stride = buf->header.stride;
  FILE *f = fopen(path, "wb");
  if (!f) return -1;
  uint32_t img_size = (uint32_t)(w * 4) * (uint32_t)h;
  uint32_t off = 14 + 40;
  uint8_t fh[14] = {'B','M', 0,0,0,0, 0,0, 0,0, 0,0,0,0};
  uint32_t fsz = off + img_size;
  memcpy(fh + 2, &fsz, 4);
  memcpy(fh + 10, &off, 4);
  fwrite(fh, 1, 14, f);
  uint8_t ih[40] = {0};
  uint32_t hsz = 40; int32_t bw = w, bh = -h;  /* negative = top-down */
  uint16_t planes = 1, bpp = 32;
  memcpy(ih + 0, &hsz, 4);
  memcpy(ih + 4, &bw, 4);
  memcpy(ih + 8, &bh, 4);
  memcpy(ih + 12, &planes, 2);
  memcpy(ih + 14, &bpp, 2);
  memcpy(ih + 20, &img_size, 4);
  fwrite(ih, 1, 40, f);
  for (int y = 0; y < h; y++) fwrite(buf->data + (size_t)y * stride, 1, (size_t)w * 4, f);
  fclose(f);
  return 0;
}

int main(int argc, char **argv)
{
  if (argc < 2) { printf("usage: harness <script.lua> [run_ms] [out.bmp] [w] [h]\n"); return 1; }
  const char *script = argv[1];
  int run_ms = argc > 2 ? atoi(argv[2]) : 2000;
  const char *out_bmp = argc > 3 ? argv[3] : NULL;
  int w = argc > 4 ? atoi(argv[4]) : 240;
  int h = argc > 5 ? atoi(argv[5]) : 135;

  lv_init();
  lv_display_t *disp = lv_sdl_window_create(w, h);
  lv_display_set_default(disp);

  /* black, pad-free, border-free root covering the panel */
  lv_obj_t *root = lv_obj_create(lv_scr_act());
  lv_obj_set_size(root, LV_PCT(100), LV_PCT(100));
  lv_obj_set_style_bg_color(root, lv_color_black(), 0);
  lv_obj_set_style_bg_opa(root, LV_OPA_COVER, 0);
  lv_obj_set_style_pad_all(root, 0, 0);
  lv_obj_set_style_border_width(root, 0, 0);
  lv_obj_set_style_radius(root, 0, 0);
  lv_obj_clear_flag(root, LV_OBJ_FLAG_SCROLLABLE);

  lua_State *L = luaL_newstate();
  luaL_openlibs(L);
  luavgl_set_root(L, root);
  luaL_requiref(L, "lvgl", luaopen_lvgl, 1);
  lua_pop(L, 1);

  lua_pushcfunction(L, msghandler);
  int base = lua_gettop(L);
  int status = luaL_loadfile(L, script);
  if (status == LUA_OK) status = lua_pcall(L, 0, 0, base);
  if (status != LUA_OK) {
    printf("HARNESS_ERROR: %s\n", lua_tostring(L, -1));
    return 2;
  }

  for (int t = 0; t < run_ms; t += 5) {
    lv_timer_handler();
    usleep(5 * 1000);
  }

  if (out_bmp) {
    lv_draw_buf_t *snap = lv_snapshot_take(lv_scr_act(), LV_COLOR_FORMAT_ARGB8888);
    if (snap == NULL) { printf("HARNESS_ERROR: snapshot failed\n"); return 3; }
    if (write_bmp(out_bmp, snap) != 0) { printf("HARNESS_ERROR: bmp write failed\n"); return 3; }
    printf("HARNESS_OK: wrote %s\n", out_bmp);
  } else {
    printf("HARNESS_OK\n");
  }
  lua_close(L);
  return 0;
}
