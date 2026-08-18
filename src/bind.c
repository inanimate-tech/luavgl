/* bind.c — display-scoped binding (Inanimate fork).
 *
 * LVGL 9 is natively multi-display; luavgl's module surface assumes the
 * default display. luavgl_bind_display(L, disp) pushes a HANDLE table bound
 * to one lv_display_t:
 *
 *   left  = lvgl.bind(dispA)      -- or C: luavgl_bind_display(L, dispA)
 *   right = lvgl.bind(dispB)
 *   left.Label{ text = "on A" }   -- parents to A's active screen
 *   right.Label{ text = "on B" }  -- parents to B's active screen
 *
 * The handle exposes the widget constructors scoped to its display (default
 * parent = that display's active screen, resolved at call time so screen
 * swaps and C-side rebuilds are safe), plus:
 *
 *   handle.disp          -- the lv_disp userdata (get_res, set_rotation, ...)
 *   handle.screen()      -- active screen as a luavgl object
 *   handle.clean()       -- lv_obj_clean(active screen): the C-side wipe
 *   handle.HOR_RES() / handle.VER_RES() -- this display's resolution
 *   handle.mirror()      -- serialization of this display's screen tree
 *   handle.set_default() -- lv_display_set_default(disp)
 *   handle:set_theme{...} / handle:set_theme(nil)
 *
 * Everything else (Anim, Timer, Style, Font, constants, palette, disp lib)
 * falls through to the plain module via __index — those surfaces are
 * process-global in LVGL and stay that way.
 *
 * Handles are cached: binding the same display twice returns the same table.
 * The single-display path (lvgl.open() / luavgl_set_root + luaopen_lvgl) is
 * untouched; it remains the default-display case.
 */
#include "luavgl.h"
#include "private.h"

/* registry["luavgl.bound"]  : disp lightuserdata -> handle table
 * registry["luavgl.themes"] : disp lightuserdata -> theme userdata */
static void luavgl_bind_subtable(lua_State *L, const char *key)
{
  lua_pushstring(L, key);
  lua_rawget(L, LUA_REGISTRYINDEX);
  if (lua_isnoneornil(L, -1)) {
    lua_pop(L, 1);
    lua_newtable(L);
    lua_pushstring(L, key);
    lua_pushvalue(L, -2);
    lua_rawset(L, LUA_REGISTRYINDEX);
  }
}

/* Push the luavgl object for an existing (C-owned) lvgl obj, creating the
 * userdata on first sight. Mirrors the pattern used throughout disp.c. */
static void luavgl_bind_push_obj(lua_State *L, lv_obj_t *obj)
{
  lua_pushlightuserdata(L, obj);
  lua_rawget(L, LUA_REGISTRYINDEX);
  if (lua_isnoneornil(L, -1)) {
    lua_pop(L, 1);
    luavgl_add_lobj(L, obj)->lua_created = false;
  }
}

static lv_display_t *luavgl_bound_disp(lua_State *L, int upidx)
{
  luavgl_disp_t *d = lua_touserdata(L, lua_upvalueindex(upidx));
  return d->disp;
}

static lv_obj_t *luavgl_bound_screen_of(lua_State *L, lv_display_t *disp)
{
  lv_obj_t *scr = lv_display_get_screen_active(disp);
  if (scr == NULL)
    luaL_error(L, "bound display has no active screen");
  return scr;
}

/* Widget constructor scoped to a display. upvalues: 1 = the real create
 * cfunction, 2 = disp userdata, 3 = the handle table (so handle:Label{} and
 * handle.Label{} both work). Explicit parents pass through unchanged. */
static int luavgl_bound_create(lua_State *L)
{
  if (lua_istable(L, 1) && lua_rawequal(L, 1, lua_upvalueindex(3)))
    lua_remove(L, 1); /* colon call: drop the handle */

  int t = lua_type(L, 1);
  if (t == LUA_TNONE || t == LUA_TNIL || t == LUA_TTABLE) {
    if (t == LUA_TNIL)
      lua_remove(L, 1);
    /* no explicit parent: the bound display's active screen, resolved NOW —
     * a screen deleted and rebuilt by the embedder is never held stale */
    lv_obj_t *scr = luavgl_bound_screen_of(L, luavgl_bound_disp(L, 2));
    luavgl_bind_push_obj(L, scr);
    lua_insert(L, 1);
  }

  lua_pushvalue(L, lua_upvalueindex(1));
  lua_insert(L, 1);
  lua_call(L, lua_gettop(L) - 1, LUA_MULTRET);
  return lua_gettop(L);
}

static int luavgl_bound_screen(lua_State *L)
{
  luavgl_bind_push_obj(L, luavgl_bound_screen_of(L, luavgl_bound_disp(L, 1)));
  return 1;
}

/* The embedder's reset path (lv_obj_clean from C) made callable per-display:
 * Lua-held handles for the cleaned subtree are invalidated, not left
 * dangling — same discipline tests/appswap.lua proves for the default path */
static int luavgl_bound_clean(lua_State *L)
{
  lv_obj_clean(luavgl_bound_screen_of(L, luavgl_bound_disp(L, 1)));
  return 0;
}

static int luavgl_bound_hor_res(lua_State *L)
{
  lua_pushinteger(
      L, lv_display_get_horizontal_resolution(luavgl_bound_disp(L, 1)));
  return 1;
}

static int luavgl_bound_ver_res(lua_State *L)
{
  lua_pushinteger(L,
                  lv_display_get_vertical_resolution(luavgl_bound_disp(L, 1)));
  return 1;
}

static int luavgl_bound_mirror(lua_State *L)
{
  return luavgl_mirror_screen(L,
                              luavgl_bound_screen_of(L, luavgl_bound_disp(L, 1)));
}

static int luavgl_bound_set_default(lua_State *L)
{
  lv_display_set_default(luavgl_bound_disp(L, 1));
  return 0;
}

/*
** Theme surface: per-display default styles, applied to objects as they are
** created on that display (LVGL's theme mechanism — existing objects keep
** their styles).
*/

typedef struct luavgl_theme_slot_s {
  const lv_obj_class_t *clz;
  lv_style_t *style;
  int ref; /* registry ref pinning the Style userdata */
} luavgl_theme_slot_t;

typedef struct luavgl_bound_theme_s {
  lv_theme_t theme; /* must stay first: apply cb downcasts */
  luavgl_theme_slot_t slots[16];
  int n_slots;
  lv_style_t *scr_style; /* style added directly to the active screen */
  int scr_ref;
  lv_obj_t *scr_obj; /* which screen scr_style was added to */
  bool installed;
} luavgl_bound_theme_t;

/* Class slots settable from Lua. "object" is the base pass: LVGL applies
 * themes per class level, so an "object" style is the base default for
 * every widget (that is how the C base theme keeps objects flat), with the
 * class-specific slot layered on top. */
static const struct {
  const char *name;
  const lv_obj_class_t *clz;
} luavgl_theme_classes[] = {
    {"object",   &lv_obj_class     },
#if LV_USE_LABEL
    {"label",    &lv_label_class   },
#endif
#if LV_USE_BUTTON
    {"button",   &lv_button_class  },
#endif
#if LV_USE_IMAGE
    {"image",    &lv_image_class   },
#endif
#if LV_USE_TEXTAREA
    {"textarea", &lv_textarea_class},
#endif
#if LV_USE_CHECKBOX
    {"checkbox", &lv_checkbox_class},
#endif
#if LV_USE_DROPDOWN
    {"dropdown", &lv_dropdown_class},
#endif
#if LV_USE_ROLLER
    {"roller",   &lv_roller_class  },
#endif
#if LV_USE_LED
    {"led",      &lv_led_class     },
#endif
#if LV_USE_LINE
    {"line",     &lv_line_class    },
#endif
#if LV_USE_ARC
    {"arc",      &lv_arc_class     },
#endif
#if LV_USE_SCALE
    {"scale",    &lv_scale_class   },
#endif
};

static void luavgl_bound_theme_apply(lv_theme_t *th, lv_obj_t *obj)
{
  luavgl_bound_theme_t *t = (luavgl_bound_theme_t *)th;
  for (int i = 0; i < t->n_slots; i++) {
    if (lv_obj_check_type(obj, t->slots[i].clz))
      lv_obj_add_style(obj, t->slots[i].style, 0);
  }
}

static luavgl_bound_theme_t *luavgl_bound_theme_get(lua_State *L,
                                                    lv_display_t *disp)
{
  luavgl_bound_theme_t *t;

  luavgl_bind_subtable(L, "luavgl.themes");
  lua_pushlightuserdata(L, disp);
  lua_rawget(L, -2);
  if (lua_isnoneornil(L, -1)) {
    lua_pop(L, 1);
    t = lua_newuserdata(L, sizeof(*t));
    lv_memset(t, 0, sizeof(*t));
    t->scr_ref = LUA_NOREF;
    lua_pushlightuserdata(L, disp);
    lua_pushvalue(L, -2);
    lua_rawset(L, -4); /* themes[disp] = ud, anchors it for good */
  } else {
    t = lua_touserdata(L, -1);
  }
  lua_pop(L, 2); /* ud, subtable */
  return t;
}

/* Style at idx: either an lvgl.Style userdata or a plain table (wrapped into
 * a Style). Pops nothing; pins the Style via a registry ref returned in
 * *ref. Styles passed here must not be style:delete()'d while themed. */
static lv_style_t *luavgl_bound_resolve_style(lua_State *L, int idx, int *ref)
{
  idx = lua_absindex(L, idx);
  if (lua_istable(L, idx)) {
    lua_pushcfunction(L, luavgl_style_create);
    lua_pushvalue(L, idx);
    lua_call(L, 1, 1);
  } else {
    lua_pushvalue(L, idx);
  }

  luavgl_style_t *s = luavgl_check_style(L, -1);
  *ref = luaL_ref(L, LUA_REGISTRYINDEX);
  return &s->style;
}

/* handle:set_theme{ screen = ..., object = ..., label = ..., ... }
 *   values: style table or lvgl.Style userdata
 *   screen: added to the CURRENT active screen immediately (bg color etc.)
 *   class slots: become that display's defaults for newly created objects
 * handle:set_theme(nil) uninstalls, restoring the previously installed
 * theme (e.g. the C base theme). Each call replaces the previous slot set.
 * upvalues: 1 = disp userdata, 2 = the handle table. */
static int luavgl_bound_set_theme(lua_State *L)
{
  if (lua_istable(L, 1) && lua_rawequal(L, 1, lua_upvalueindex(2)))
    lua_remove(L, 1); /* colon call: drop the handle */

  lv_display_t *disp = luavgl_bound_disp(L, 1);
  luavgl_bound_theme_t *t = luavgl_bound_theme_get(L, disp);

  /* this call's table replaces the previous slot set */
  for (int i = 0; i < t->n_slots; i++)
    luaL_unref(L, LUA_REGISTRYINDEX, t->slots[i].ref);
  t->n_slots = 0;

  if (lua_isnoneornil(L, 1)) {
    if (t->installed) {
      lv_display_set_theme(disp, t->theme.parent);
      t->installed = false;
    }
    return 0;
  }
  luaL_checktype(L, 1, LUA_TTABLE);

  int n_classes =
      sizeof(luavgl_theme_classes) / sizeof(luavgl_theme_classes[0]);
  for (int i = 0; i < n_classes; i++) {
    lua_getfield(L, 1, luavgl_theme_classes[i].name);
    if (!lua_isnil(L, -1)) {
      if (t->n_slots >= (int)(sizeof(t->slots) / sizeof(t->slots[0])))
        return luaL_error(L, "too many theme slots");
      luavgl_theme_slot_t *slot = &t->slots[t->n_slots];
      slot->clz = luavgl_theme_classes[i].clz;
      slot->style = luavgl_bound_resolve_style(L, -1, &slot->ref);
      t->n_slots++;
    }
    lua_pop(L, 1);
  }

  /* screen styles go straight onto the current active screen */
  lua_getfield(L, 1, "screen");
  if (!lua_isnil(L, -1)) {
    lv_obj_t *scr = lv_display_get_screen_active(disp);
    if (scr != NULL) {
      if (t->scr_style != NULL && t->scr_obj == scr)
        lv_obj_remove_style(scr, t->scr_style, 0);
      if (t->scr_ref != LUA_NOREF)
        luaL_unref(L, LUA_REGISTRYINDEX, t->scr_ref);
      t->scr_style = luavgl_bound_resolve_style(L, -1, &t->scr_ref);
      t->scr_obj = scr;
      lv_obj_add_style(scr, t->scr_style, 0);
    }
  }
  lua_pop(L, 1);

  if (!t->installed) {
    lv_theme_set_apply_cb(&t->theme, luavgl_bound_theme_apply);
    lv_theme_t *parent = lv_display_get_theme(disp);
    /* parent applies first, so Lua defaults override C ones (base theme) */
    if (parent != NULL && parent != &t->theme)
      lv_theme_set_parent(&t->theme, parent);
    lv_display_set_theme(disp, &t->theme);
    t->installed = true;
  }
  return 0;
}

LUALIB_API int luavgl_bind_display(lua_State *L, lv_display_t *disp)
{
  if (disp == NULL)
    return luaL_error(L, "no display to bind");

  /* the module must be initialised (metatables, widgets); idempotent */
  luaL_requiref(L, "lvgl", luaopen_lvgl, 0);
  int module = lua_gettop(L);

  /* cached handle? bind is idempotent per display */
  luavgl_bind_subtable(L, "luavgl.bound");
  int bound = lua_gettop(L);
  lua_pushlightuserdata(L, disp);
  lua_rawget(L, bound);
  if (!lua_isnoneornil(L, -1)) {
    lua_replace(L, module);
    lua_settop(L, module);
    return 1;
  }
  lua_pop(L, 1);

  lua_newtable(L);
  int handle = lua_gettop(L);

  luavgl_disp_get(L, disp); /* the (cached) lv_disp userdata */
  int dispud = lua_gettop(L);
  lua_pushvalue(L, dispud);
  lua_setfield(L, handle, "disp");

  /* widget constructors, scoped to this display */
  for (int i = 0; widget_create_methods[i].name != NULL; i++) {
    lua_pushcfunction(L, widget_create_methods[i].func);
    lua_pushvalue(L, dispud);
    lua_pushvalue(L, handle);
    lua_pushcclosure(L, luavgl_bound_create, 3);
    lua_setfield(L, handle, widget_create_methods[i].name);
  }

  static const struct {
    const char *name;
    lua_CFunction fn;
  } methods[] = {
      {"screen",      luavgl_bound_screen     },
      {"clean",       luavgl_bound_clean      },
      {"HOR_RES",     luavgl_bound_hor_res    },
      {"VER_RES",     luavgl_bound_ver_res    },
      {"mirror",      luavgl_bound_mirror     },
      {"set_default", luavgl_bound_set_default},
  };
  for (size_t i = 0; i < sizeof(methods) / sizeof(methods[0]); i++) {
    lua_pushvalue(L, dispud);
    lua_pushcclosure(L, methods[i].fn, 1);
    lua_setfield(L, handle, methods[i].name);
  }

  lua_pushvalue(L, dispud);
  lua_pushvalue(L, handle);
  lua_pushcclosure(L, luavgl_bound_set_theme, 2);
  lua_setfield(L, handle, "set_theme");

  /* everything else resolves on the plain module (Anim, Style, constants) */
  lua_createtable(L, 0, 1);
  lua_pushvalue(L, module);
  lua_setfield(L, -2, "__index");
  lua_setmetatable(L, handle);

  /* cache it */
  lua_pushlightuserdata(L, disp);
  lua_pushvalue(L, handle);
  lua_rawset(L, bound);

  lua_pushvalue(L, handle);
  lua_replace(L, module);
  lua_settop(L, module);
  return 1;
}

/* lvgl.bind(disp?) — disp is an lv_disp userdata (lvgl.disp.get_default(),
 * get_next(), ...); nil binds the default display. */
static int luavgl_bind(lua_State *L)
{
  lv_display_t *disp;
  if (lua_isnoneornil(L, 1))
    disp = lv_display_get_default();
  else
    disp = luavgl_check_disp(L, 1)->disp;
  return luavgl_bind_display(L, disp);
}
