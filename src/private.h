#pragma once

#include <lauxlib.h>
#include <lua.h>
#include <lvgl.h>

#include "src/lvgl_private.h"

#include <stdbool.h>
#include <stdint.h>

static void dumpstack(lua_State *L);
static void dumptable(lua_State *L, int index);

/* metatable */
int luavgl_obj_getmetatable(lua_State *L, const lv_obj_class_t *clz);
int luavgl_obj_setmetatable(lua_State *L, int idx, const lv_obj_class_t *clz);

static void luavgl_obj_remove_event_all(lua_State *L, luavgl_obj_t *obj);

/* util functions */
static void luavgl_check_callable(lua_State *L, int index);
static int luavgl_check_continuation(lua_State *L, int index);
static lua_State *luavgl_main_thread(lua_State *L);

static int luavgl_obj_set_style_kv(lua_State *L, lv_obj_t *obj, int selector);

static int luavgl_pcall_int(lua_State *L, int nargs, int nresult);

/* font.c: record a font as one a script may set */
static void luavgl_font_mint(lua_State *L, const lv_font_t *font);

/* util.c: keep a string alive for as long as `owner` (an lv_obj_t or a
 * style) may hold a pointer to it. See luavgl_anchor_string. */
static const char *luavgl_anchor_string(lua_State *L, const void *owner,
                                        const char *key, int idx);
static void luavgl_anchor_release(lua_State *L, const void *owner);
