#include <string.h>

#include "luavgl.h"
#include "private.h"
#include "rotable.h"

/**
 * lv_arc: an anti-aliased arc, styled with arc_width / arc_color /
 * arc_rounded / arc_opa. Angles are DEGREES, zero at 3 o'clock, increasing
 * clockwise — LVGL's convention, left alone here so the LVGL docs read true.
 * `rotation` moves the zero point, so rotation = 270 puts zero at 12.
 *
 * The indicator arc is start_angle..end_angle; the track behind it is
 * bg_start_angle..bg_end_angle. Set the pair together with `angles = {s, e}`
 * / `bg_angles = {s, e}` to avoid the transient state where start has moved
 * and end has not.
 */

static int arc_set_angle_pair(lua_State *L, lv_obj_t *obj, int idx, bool bg)
{
  lv_value_precise_t s, e;

  if (!lua_istable(L, idx) || lua_rawlen(L, idx) != 2) {
    return luaL_error(L, "arc angles: expect {start, end}");
  }

  lua_rawgeti(L, idx, 1);
  lua_rawgeti(L, idx, 2);
  s = (lv_value_precise_t)lua_tonumber(L, -2);
  e = (lv_value_precise_t)lua_tonumber(L, -1);
  lua_pop(L, 2);

  if (bg) {
    lv_arc_set_bg_angles(obj, s, e);
  } else {
    lv_arc_set_angles(obj, s, e);
  }
  return 0;
}

static int arc_set_range(lua_State *L, lv_obj_t *obj, int idx)
{
  int32_t min, max;

  if (!lua_istable(L, idx) || lua_rawlen(L, idx) != 2) {
    return luaL_error(L, "arc range: expect {min, max}");
  }

  lua_rawgeti(L, idx, 1);
  lua_rawgeti(L, idx, 2);
  min = (int32_t)lua_tointeger(L, -2);
  max = (int32_t)lua_tointeger(L, -1);
  lua_pop(L, 2);

  lv_arc_set_range(obj, min, max);
  return 0;
}

static int luavgl_arc_create(lua_State *L)
{
  return luavgl_obj_create_helper(L, lv_arc_create);
}

/* clang-format off */
static const luavgl_value_setter_t arc_property_table[] = {
    {"start_angle",    0, {.setter = (setter_int_t)lv_arc_set_start_angle}},
    {"end_angle",      0, {.setter = (setter_int_t)lv_arc_set_end_angle}},
    {"bg_start_angle", 0, {.setter = (setter_int_t)lv_arc_set_bg_start_angle}},
    {"bg_end_angle",   0, {.setter = (setter_int_t)lv_arc_set_bg_end_angle}},
    {"rotation",       0, {.setter = (setter_int_t)lv_arc_set_rotation}},
    {"mode",           0, {.setter = (setter_int_t)lv_arc_set_mode}},
    {"value",          0, {.setter = (setter_int_t)lv_arc_set_value}},
    {"change_rate",    0, {.setter = (setter_int_t)lv_arc_set_change_rate}},
};
/* clang-format on */

LUALIB_API int luavgl_arc_set_property_kv(lua_State *L, void *data)
{
  lv_obj_t *obj = data;
  const char *key;
  int ret;

  /* Table-valued properties cannot go through the scalar setter table. */
  if (lua_type(L, -2) == LUA_TSTRING) {
    key = lua_tostring(L, -2);
    if (strcmp(key, "angles") == 0) {
      return arc_set_angle_pair(L, obj, lua_absindex(L, -1), false);
    }
    if (strcmp(key, "bg_angles") == 0) {
      return arc_set_angle_pair(L, obj, lua_absindex(L, -1), true);
    }
    if (strcmp(key, "range") == 0) {
      return arc_set_range(L, obj, lua_absindex(L, -1));
    }
  }

  ret = luavgl_set_property(L, obj, arc_property_table);
  if (ret == 0) {
    return 0;
  }

  ret = luavgl_obj_set_property_kv(L, obj);
  if (ret != 0) {
    LV_LOG_ERROR("unkown property for arc");
  }

  return ret;
}

static int luavgl_arc_set(lua_State *L)
{
  lv_obj_t *obj = luavgl_to_obj(L, 1);

  if (!lua_istable(L, -1)) {
    luaL_error(L, "expect a table on 2nd para.");
    return 0;
  }

  luavgl_iterate(L, -1, luavgl_arc_set_property_kv, obj);

  return 0;
}

static int luavgl_arc_get_value(lua_State *L)
{
  lv_obj_t *obj = luavgl_to_obj(L, 1);
  lua_pushinteger(L, lv_arc_get_value(obj));
  return 1;
}

static const rotable_Reg luavgl_arc_methods[] = {
    {"set",       LUA_TFUNCTION, {luavgl_arc_set}      },
    {"get_value", LUA_TFUNCTION, {luavgl_arc_get_value}},

    {0,           0,             {0}                   },
};

static void luavgl_arc_init(lua_State *L)
{
  luavgl_obj_newmetatable(L, &lv_arc_class, "lv_arc", luavgl_arc_methods);
  lua_pop(L, 1);
}
