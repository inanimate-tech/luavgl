#include <string.h>

#include "luavgl.h"
#include "private.h"
#include "rotable.h"

/**
 * lv_scale: a tick scale, straight or round. On a round panel this is the
 * whole dial in one widget — total_tick_count ticks around angle_range
 * degrees, every major_tick_every one drawn long.
 *
 * The three parts each style a different thing, and getting them mixed up is
 * the usual way to lose an afternoon — verified against lv_scale.c, not
 * guessed:
 *   PART.ITEMS     the MINOR ticks   (lv_obj_init_draw_line_dsc, ITEMS)
 *   PART.INDICATOR the MAJOR ticks AND the labels
 *   PART.MAIN      the enclosing arc (set arc_opa 0 to hide it)
 *
 * Tick length is the `length` style property (LV_STYLE_LENGTH), which this
 * branch also had to bind — without it every tick is zero-length, so a
 * scale renders as nothing at all and looks like a broken widget.
 *
 * `mode` takes a string — "round_inner", "round_outer", "horizontal_top",
 * "horizontal_bottom", "vertical_left", "vertical_right" — rather than a
 * bare integer, because a mis-typed integer here silently draws a straight
 * scale on a round dial.
 */

static const struct {
  const char *name;
  lv_scale_mode_t mode;
} scale_modes[] = {
    {"horizontal_top",    LV_SCALE_MODE_HORIZONTAL_TOP   },
    {"horizontal_bottom", LV_SCALE_MODE_HORIZONTAL_BOTTOM},
    {"vertical_left",     LV_SCALE_MODE_VERTICAL_LEFT    },
    {"vertical_right",    LV_SCALE_MODE_VERTICAL_RIGHT   },
    {"round_inner",       LV_SCALE_MODE_ROUND_INNER      },
    {"round_outer",       LV_SCALE_MODE_ROUND_OUTER      },
};

static int scale_set_mode(lua_State *L, lv_obj_t *obj, int idx)
{
  size_t i;
  const char *name;

  if (lua_type(L, idx) == LUA_TNUMBER) {
    lv_scale_set_mode(obj, (lv_scale_mode_t)lua_tointeger(L, idx));
    return 0;
  }

  name = lua_tostring(L, idx);
  if (name == NULL) {
    return luaL_error(L, "scale mode: expect a string or an integer");
  }

  for (i = 0; i < sizeof(scale_modes) / sizeof(scale_modes[0]); i++) {
    if (strcmp(name, scale_modes[i].name) == 0) {
      lv_scale_set_mode(obj, scale_modes[i].mode);
      return 0;
    }
  }

  return luaL_error(L, "scale mode: unknown mode '%s'", name);
}

static int scale_set_range(lua_State *L, lv_obj_t *obj, int idx)
{
  int32_t min, max;

  if (!lua_istable(L, idx) || lua_rawlen(L, idx) != 2) {
    return luaL_error(L, "scale range: expect {min, max}");
  }

  lua_rawgeti(L, idx, 1);
  lua_rawgeti(L, idx, 2);
  min = (int32_t)lua_tointeger(L, -2);
  max = (int32_t)lua_tointeger(L, -1);
  lua_pop(L, 2);

  lv_scale_set_range(obj, min, max);
  return 0;
}

static int luavgl_scale_create(lua_State *L)
{
  return luavgl_obj_create_helper(L, lv_scale_create);
}

/* clang-format off */
static const luavgl_value_setter_t scale_property_table[] = {
    {"total_tick_count",   0, {.setter = (setter_int_t)lv_scale_set_total_tick_count}},
    {"major_tick_every",   0, {.setter = (setter_int_t)lv_scale_set_major_tick_every}},
    {"label_show",         0, {.setter = (setter_int_t)lv_scale_set_label_show}},
    {"angle_range",        0, {.setter = (setter_int_t)lv_scale_set_angle_range}},
    {"rotation",           0, {.setter = (setter_int_t)lv_scale_set_rotation}},
    {"post_draw",          0, {.setter = (setter_int_t)lv_scale_set_post_draw}},
    {"draw_ticks_on_top",  0, {.setter = (setter_int_t)lv_scale_set_draw_ticks_on_top}},
};
/* clang-format on */

LUALIB_API int luavgl_scale_set_property_kv(lua_State *L, void *data)
{
  lv_obj_t *obj = data;
  const char *key;
  int ret;

  if (lua_type(L, -2) == LUA_TSTRING) {
    key = lua_tostring(L, -2);
    if (strcmp(key, "mode") == 0) {
      return scale_set_mode(L, obj, lua_absindex(L, -1));
    }
    if (strcmp(key, "range") == 0) {
      return scale_set_range(L, obj, lua_absindex(L, -1));
    }
  }

  ret = luavgl_set_property(L, obj, scale_property_table);
  if (ret == 0) {
    return 0;
  }

  ret = luavgl_obj_set_property_kv(L, obj);
  if (ret != 0) {
    LV_LOG_ERROR("unkown property for scale");
  }

  return ret;
}

static int luavgl_scale_set(lua_State *L)
{
  lv_obj_t *obj = luavgl_to_obj(L, 1);

  if (!lua_istable(L, -1)) {
    luaL_error(L, "expect a table on 2nd para.");
    return 0;
  }

  luavgl_iterate(L, -1, luavgl_scale_set_property_kv, obj);

  return 0;
}

static const rotable_Reg luavgl_scale_methods[] = {
    {"set", LUA_TFUNCTION, {luavgl_scale_set}},

    {0,     0,             {0}               },
};

static void luavgl_scale_init(lua_State *L)
{
  luavgl_obj_newmetatable(L, &lv_scale_class, "lv_scale",
                          luavgl_scale_methods);
  lua_pop(L, 1);
}
