/* lvgl.mirror() — compact, model-readable serialization of the active
 * screen's object tree. Used by arc to publish the device's view as tokens:
 * one entry per visible object, class short-name plus label text, child
 * order preserved, capped well under the transport budget.
 */
#include "luavgl.h"
#include "private.h"

#define LUAVGL_MIRROR_MAX 512
#define LUAVGL_MIRROR_LABEL_MAX 24

typedef struct {
  char buf[LUAVGL_MIRROR_MAX];
  int len;
} luavgl_mirror_buf_t;

static void luavgl_mirror_emit(luavgl_mirror_buf_t *m, const char *s, int n)
{
  if (n < 0)
    n = (int)lv_strlen(s);
  if (m->len + n >= LUAVGL_MIRROR_MAX - 4)
    return; /* silently truncate; the tail matters less than not overflowing */
  lv_memcpy(m->buf + m->len, s, n);
  m->len += n;
}

static const char *luavgl_mirror_class(const lv_obj_t *obj)
{
  const lv_obj_class_t *cls = lv_obj_get_class(obj);
  if (cls == &lv_label_class)
    return "label";
  if (cls == &lv_obj_class)
    return "obj";
  const char *name = cls->name ? cls->name : "?";
  if (lv_strlen(name) > 3 && name[0] == 'l' && name[1] == 'v' && name[2] == '_')
    name += 3; /* "lv_led" -> "led" */
  return name;
}

static void luavgl_mirror_walk(luavgl_mirror_buf_t *m, lv_obj_t *obj)
{
  if (lv_obj_has_flag(obj, LV_OBJ_FLAG_HIDDEN))
    return;
  luavgl_mirror_emit(m, luavgl_mirror_class(obj), -1);
  if (lv_obj_get_class(obj) == &lv_label_class) {
    const char *text = lv_label_get_text(obj);
    if (text && *text) {
      luavgl_mirror_emit(m, ":", 1);
      int n = (int)lv_strlen(text);
      luavgl_mirror_emit(
          m, text, n > LUAVGL_MIRROR_LABEL_MAX ? LUAVGL_MIRROR_LABEL_MAX : n);
    }
  }
  uint32_t count = lv_obj_get_child_count(obj);
  if (count > 0) {
    luavgl_mirror_emit(m, "[", 1);
    for (uint32_t i = 0; i < count; i++) {
      if (i > 0)
        luavgl_mirror_emit(m, ",", 1);
      luavgl_mirror_walk(m, lv_obj_get_child(obj, i));
    }
    luavgl_mirror_emit(m, "]", 1);
  }
}

/* Serialize one screen's tree; shared by the module-level mirror() (default
 * display) and the display-bound handle's mirror (bind.c). */
static int luavgl_mirror_screen(lua_State *L, lv_obj_t *scr)
{
  luavgl_mirror_buf_t m = {.len = 0};
  uint32_t count = lv_obj_get_child_count(scr);
  for (uint32_t i = 0; i < count; i++) {
    if (i > 0)
      luavgl_mirror_emit(&m, ",", 1);
    luavgl_mirror_walk(&m, lv_obj_get_child(scr, i));
  }
  lua_pushlstring(L, m.buf, m.len);
  return 1;
}

static int luavgl_mirror(lua_State *L)
{
  return luavgl_mirror_screen(L, lv_screen_active());
}
