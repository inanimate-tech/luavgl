#include "luavgl.h"
#include "private.h"
#include "rotable.h"

static int luavgl_label_create(lua_State *L)
{
  return luavgl_obj_create_helper(L, lv_label_create);
}

static int luavgl_label_ins_text(lua_State *L)
{
  lv_obj_t *obj = luavgl_to_obj(L, 1);
  uint32_t pos = luavgl_tointeger(L, 2);
  const char *txt = lua_tostring(L, 3);

  lv_label_ins_text(obj, pos, txt);
  return 0;
}

static int luavgl_label_cut_text(lua_State *L)
{
  lv_obj_t *obj = luavgl_to_obj(L, 1);
  uint32_t pos = luavgl_tointeger(L, 2);
  uint32_t cnt = luavgl_tointeger(L, 3);

  lv_label_cut_text(obj, pos, cnt);
  return 0;
}

/* label:get_letter_pos(char_id) -> x, y
 * Where LVGL laid out the char_id-th character (0-based, counted in
 * characters, not bytes), relative to the label: lv_label_get_letter_pos.
 * What an effect needs to draw something at a character's place without
 * changing the label's text, and so without re-wrapping it. */
static int luavgl_label_get_letter_pos(lua_State *L)
{
  lv_obj_t *obj = luavgl_to_obj(L, 1);
  uint32_t char_id = luavgl_tointeger(L, 2);
  lv_point_t pos;

  lv_label_get_letter_pos(obj, char_id, &pos);
  lua_pushinteger(L, pos.x);
  lua_pushinteger(L, pos.y);
  return 2;
}

static int luavgl_label_tostring(lua_State *L)
{
  lv_obj_t *obj = luavgl_to_obj(L, 1);
  lua_pushfstring(L, "lv_label:%p, text: %s", obj, lv_label_get_text(obj));
  return 1;
}

static const rotable_Reg luavgl_label_methods[] = {
    {"ins_text",        LUA_TFUNCTION, {luavgl_label_ins_text}       },
    {"cut_text",        LUA_TFUNCTION, {luavgl_label_cut_text}       },
    {"get_letter_pos",  LUA_TFUNCTION, {luavgl_label_get_letter_pos} },

    {0,                 0,             {0}                           },
};

static void luavgl_label_init(lua_State *L)
{
  luavgl_obj_newmetatable(L, &lv_label_class, "lv_label", luavgl_label_methods);
  lua_pushcfunction(L, luavgl_label_tostring);
  lua_setfield(L, -2, "__tostring");
  lua_pop(L, 1);
}
