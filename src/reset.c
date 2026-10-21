/* reset.c — Inanimate fork: luavgl_app_reset.
 *
 * luavgl assumes a lua_State lives as long as the app it runs: timers,
 * running anims and styles are pinned in the registry until Lua deletes
 * them, and lua_close frees the rest. An embedder that keeps one state
 * across a sequence of apps has no lua_close between them, so without this
 * the outgoing app's timers go on firing its closures under the next app,
 * and everything those closures reach stays in the heap. See luavgl.h for
 * the contract.
 */

/* registry[obj] is the luavgl handle of any object Lua has seen; true when
 * Lua created the object (not merely looked it up). */
static bool luavgl_reset_lua_created(lua_State *L, lv_obj_t *obj)
{
  lua_pushlightuserdata(L, obj);
  lua_rawget(L, LUA_REGISTRYINDEX);
  luavgl_obj_t *lobj = lua_touserdata(L, -1);
  bool created = lobj != NULL && lobj->obj == obj && lobj->lua_created;
  lua_pop(L, 1);
  return created;
}

/* Delete the Lua-created children of a C-owned parent (a layer). */
static void luavgl_reset_children(lua_State *L, lv_obj_t *parent)
{
  if (parent == NULL)
    return;
  for (int32_t i = (int32_t)lv_obj_get_child_count(parent) - 1; i >= 0; i--) {
    lv_obj_t *child = lv_obj_get_child(parent, i);
    if (luavgl_reset_lua_created(L, child))
      lv_obj_delete(child);
  }
}

/* Lua-created objects outside the active screens: on the layers, which no
 * screen change touches, and screens of their own (lvgl.Object(nil) with no
 * root) that are not showing. */
static void luavgl_reset_objects(lua_State *L)
{
  for (lv_display_t *d = lv_display_get_next(NULL); d != NULL;
       d = lv_display_get_next(d)) {
    luavgl_reset_children(L, lv_display_get_layer_top(d));
    luavgl_reset_children(L, lv_display_get_layer_sys(d));
    luavgl_reset_children(L, lv_display_get_layer_bottom(d));

    lv_obj_t *active = lv_display_get_screen_active(d);
    for (int32_t i = (int32_t)d->screen_cnt - 1; i >= 0; i--) {
      lv_obj_t *scr = d->screens[i];
      if (scr != active && luavgl_reset_lua_created(L, scr))
        lv_obj_delete(scr);
    }
  }
}

/* Delete every timer Lua still holds: drop its callback and pin, invalidate
 * its handle, free it. A timer Lua already deleted is unpinned and paused,
 * and its own __gc frees it. */
static void luavgl_reset_timers(lua_State *L)
{
  lv_timer_t *t = lv_timer_get_next(NULL);
  while (t != NULL) {
    lv_timer_t *next = lv_timer_get_next(t);
    if (t->timer_cb == luavgl_timer_cb) {
      lua_pushlightuserdata(L, t);
      lua_rawget(L, LUA_REGISTRYINDEX);
      lv_timer_t **handle = luaL_testudata(L, -1, "lv_timer");
      lua_pop(L, 1);
      if (handle != NULL) {
        luavgl_timer_t *data = t->user_data;
        luaL_unref(L, LUA_REGISTRYINDEX, data->ref);
        lua_pushlightuserdata(L, t);
        lua_pushnil(L);
        lua_rawset(L, LUA_REGISTRYINDEX);
        *handle = NULL; /* methods raise "timer is null"; __gc skips it */
        free(data);
        lv_timer_delete(t);
      }
    }
    t = next;
  }
}

/* Uninstall every Lua theme and release its styles. Their screen style was
 * on a screen the embedder has deleted, so only the reference goes. */
static void luavgl_reset_themes(lua_State *L)
{
  lua_pushstring(L, "luavgl.themes");
  lua_rawget(L, LUA_REGISTRYINDEX);
  if (!lua_istable(L, -1)) {
    lua_pop(L, 1);
    return;
  }

  lua_pushnil(L);
  while (lua_next(L, -2) != 0) {
    lv_display_t *disp = lua_touserdata(L, -2);
    luavgl_bound_theme_t *t = lua_touserdata(L, -1);
    for (int i = 0; i < t->n_slots; i++)
      luaL_unref(L, LUA_REGISTRYINDEX, t->slots[i].ref);
    t->n_slots = 0;
    luaL_unref(L, LUA_REGISTRYINDEX, t->scr_ref);
    t->scr_ref = LUA_NOREF;
    t->scr_style = NULL;
    t->scr_obj = NULL;
    if (t->installed) {
      lv_display_set_theme(disp, t->theme.parent);
      t->installed = false;
    }
    lua_pop(L, 1); /* value; keep the key for lua_next */
  }
  lua_pop(L, 1); /* themes */
}

LUALIB_API void luavgl_app_reset(lua_State *L)
{
  luavgl_ctx_t *ctx = luavgl_context(L);
  ctx->resetting = true;

  /* every running anim, without its done_cb */
  lv_anim_delete(NULL, luavgl_anim_exec_cb);
  luavgl_reset_timers(L);
  luavgl_reset_objects(L);
  luavgl_reset_themes(L);

  /* every style pin: no object of the app's is left to carry one */
  lua_pushstring(L, "luavgl.styles");
  lua_pushnil(L);
  lua_rawset(L, LUA_REGISTRYINDEX);

  ctx->resetting = false;
}
