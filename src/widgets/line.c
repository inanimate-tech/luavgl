#include <string.h>

#include "luavgl.h"
#include "private.h"
#include "rotable.h"

/**
 * lv_line: an anti-aliased polyline, styled with line_width / line_color /
 * line_rounded / line_opa.
 *
 * The one sharp edge in this binding is point lifetime. lv_line_set_points()
 * stores the POINTER, it does not copy — so a Lua table converted on the
 * stack and then collected would leave the widget reading freed memory. We
 * therefore keep our own lv_malloc'd array per object, reuse it while the
 * point count is unchanged (the common case: a clock hand moving every
 * frame), and free it on LV_EVENT_DELETE.
 */

typedef struct {
  lv_point_precise_t *points;
  uint32_t count;
} luavgl_line_points_t;

static void line_points_delete_cb(lv_event_t *e)
{
  luavgl_line_points_t *p = lv_event_get_user_data(e);
  if (p == NULL) {
    return;
  }
  if (p->points) {
    lv_free(p->points);
  }
  lv_free(p);
}

static luavgl_line_points_t *line_points_of(lv_obj_t *obj, uint32_t count)
{
  luavgl_line_points_t *p = NULL;
  uint32_t i;
  uint32_t n = lv_obj_get_event_count(obj);

  /* Find the store we attached at create time. */
  for (i = 0; i < n; i++) {
    lv_event_dsc_t *dsc = lv_obj_get_event_dsc(obj, i);
    if (lv_event_dsc_get_cb(dsc) == line_points_delete_cb) {
      p = lv_event_dsc_get_user_data(dsc);
      break;
    }
  }

  if (p == NULL) {
    p = lv_malloc(sizeof(luavgl_line_points_t));
    if (p == NULL) {
      return NULL;
    }
    p->points = NULL;
    p->count = 0;
    lv_obj_add_event_cb(obj, line_points_delete_cb, LV_EVENT_DELETE, p);
  }

  if (p->count != count) {
    if (p->points) {
      lv_free(p->points);
    }
    p->points = count ? lv_malloc(count * sizeof(lv_point_precise_t)) : NULL;
    p->count = p->points ? count : 0;
  }

  return p;
}

/**
 * points = {{x1, y1}, {x2, y2}, ...}
 * Anything that is not a table of pairs is rejected loudly rather than
 * drawing a garbage line.
 */
static int line_set_points(lua_State *L, lv_obj_t *obj, int idx)
{
  uint32_t count, i;
  luavgl_line_points_t *p;

  if (!lua_istable(L, idx)) {
    return luaL_error(L, "line points: expect a table of {x, y} pairs");
  }

  count = (uint32_t)lua_rawlen(L, idx);
  if (count < 2) {
    return luaL_error(L, "line points: need at least 2 points, got %d",
                      (int)count);
  }

  p = line_points_of(obj, count);
  if (p == NULL || p->points == NULL) {
    return luaL_error(L, "line points: out of memory for %d points",
                      (int)count);
  }

  for (i = 0; i < count; i++) {
    lua_rawgeti(L, idx, i + 1);
    if (!lua_istable(L, -1)) {
      lua_pop(L, 1);
      return luaL_error(L, "line points: item %d is not an {x, y} pair",
                        (int)i + 1);
    }
    lua_rawgeti(L, -1, 1);
    lua_rawgeti(L, -2, 2);
    p->points[i].x = (lv_value_precise_t)lua_tonumber(L, -2);
    p->points[i].y = (lv_value_precise_t)lua_tonumber(L, -1);
    lua_pop(L, 3);
  }

  lv_line_set_points(obj, p->points, p->count);
  return 0;
}

static int luavgl_line_create(lua_State *L)
{
  return luavgl_obj_create_helper(L, lv_line_create);
}

/* clang-format off */
static const luavgl_value_setter_t line_property_table[] = {
    {"y_invert", 0, {.setter = (setter_int_t)lv_line_set_y_invert}},
};
/* clang-format on */

LUALIB_API int luavgl_line_set_property_kv(lua_State *L, void *data)
{
  lv_obj_t *obj = data;
  const char *key;
  int ret;

  /* `points` is a table, so it cannot go through the scalar setter table. */
  if (lua_type(L, -2) == LUA_TSTRING) {
    key = lua_tostring(L, -2);
    if (strcmp(key, "points") == 0) {
      return line_set_points(L, obj, lua_absindex(L, -1));
    }
  }

  ret = luavgl_set_property(L, obj, line_property_table);
  if (ret == 0) {
    return 0;
  }

  ret = luavgl_obj_set_property_kv(L, obj);
  if (ret != 0) {
    LV_LOG_ERROR("unkown property for line");
  }

  return ret;
}

static int luavgl_line_set(lua_State *L)
{
  lv_obj_t *obj = luavgl_to_obj(L, 1);

  if (!lua_istable(L, -1)) {
    luaL_error(L, "expect a table on 2nd para.");
    return 0;
  }

  luavgl_iterate(L, -1, luavgl_line_set_property_kv, obj);

  return 0;
}

static const rotable_Reg luavgl_line_methods[] = {
    {"set", LUA_TFUNCTION, {luavgl_line_set}},

    {0,     0,             {0}              },
};

static void luavgl_line_init(lua_State *L)
{
  luavgl_obj_newmetatable(L, &lv_line_class, "lv_line", luavgl_line_methods);
  lua_pop(L, 1);
}
