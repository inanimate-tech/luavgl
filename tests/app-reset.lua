-- luavgl_app_reset (tests/check-app-reset.sh): an embedder keeps one
-- lua_State across apps. After app A's reset, none of A's callbacks run
-- under app B, A's closures are collectable, and the handles A kept fail
-- cleanly rather than touching freed memory.
local lvgl = require("lvgl")
local d = lvgl.bind()

local results = {}
local function check(name, ok) results[#results + 1] = (ok and "ok " or "FAIL ") .. name end

-- What A's closures hold, so collection is observable.
local weak = setmetatable({}, { __mode = "v" })
local reset_done = false
local after = { timer = 0, anim_exec = 0, anim_done = 0 }

---------------------------------------------------------------- app A
-- A runs in a frame of its own: values left in a live frame's registers
-- would count as references and hide what the reset released.
local function app_a()
  local payload = {}
  weak.payload = payload
  local root = lvgl.Object(nil, { w = 200, h = 100 })
  local box = root:Object { w = 20, h = 20 }

  -- a timer, the reported bug
  weak.timer = lvgl.Timer { period = 10, cb = function()
    local _ = payload
    if reset_done then after.timer = after.timer + 1 end
  end }

  -- a long anim with a done_cb: neither callback may run after the reset
  weak.anim = box:Anim { run = true, start_value = 0, end_value = 100,
    duration = 5000,
    exec_cb = function(o, v) if reset_done then after.anim_exec = after.anim_exec + 1 end end,
    done_cb = function() if reset_done then after.anim_done = after.anim_done + 1 end end }

  -- a theme from plain tables, and a Style of the app's own
  d:set_theme { label = { text_color = "#ff0000" }, object = { width = 77 } }
  weak.style = lvgl.Style { radius = 5 }
  box:add_style(weak.style, 0)

  -- an object on the top layer, which no screen change deletes
  d.disp:get_layer_top():Label { text = "A on top" }
end
app_a()

-- the handles A leaves behind in the next app's reach
local stale_timer = weak.timer
weak.timer = nil
local stale_anim = weak.anim
weak.anim = nil

-- a boolean only: holding the pin table would itself keep A's styles alive
local pins = debug.getregistry()["luavgl.styles"]
check("styles pinned before reset", pins ~= nil and next(pins) ~= nil)
pins = nil

---------------------------------------------------------------- reset
harness_app_reset()
reset_done = true
collectgarbage("collect")
collectgarbage("collect")

check("A's closures collected", weak.payload == nil)
check("A's Style collected", weak.style == nil)
check("style pins released", debug.getregistry()["luavgl.styles"] == nil)
check("top layer emptied", d.disp:get_layer_top():get_child_cnt() == 0)
check("stale timer raises", pcall(function() stale_timer:pause() end) == false)
check("stale timer delete is harmless", pcall(function() stale_timer:delete() end))
check("stale anim raises", pcall(function() stale_anim:stop() end) == false)

-- With no root left, lvgl.Object(nil) makes a screen of its own. One the
-- app never loads is on no active screen, so the reset deletes it.
local spare = lvgl.Object(nil, {})
check("spare is a screen", rawequal(spare:get_screen(), spare))
harness_app_reset()
check("spare screen deleted", pcall(function() spare:set { x = 0 } end) == false)

---------------------------------------------------------------- app B
-- an anim whose done_cb restarts it once: it must stay pinned through the
-- restart, so a GC in between cannot free it while LVGL drives it
local loops = 0
local b_box = d.Object(nil, { w = 10, h = 10 })
b_box:Anim { run = true, start_value = 0, end_value = 10, duration = 50,
  exec_cb = function(o, v) o:set { x = v } end,
  done_cb = function(a)
    loops = loops + 1
    if loops < 3 then a:start() end
    collectgarbage("collect")
  end }

-- an anim with no exec_cb is refused where Lua can catch it
check("anim without exec_cb raises",
  pcall(function() b_box:Anim { run = true, start_value = 0, end_value = 1, duration = 10 } end) == false)

-- a new Object is not themed by A's theme (which made Objects 77 wide;
-- theme slots match classes exactly, so it must be a plain Object)
local plain = d.Object(nil, {})

lvgl.Timer { period = 400, repeat_count = 1, cb = function()
  local c = plain:get_coords()
  check("A's theme uninstalled", (c.x2 - c.x1 + 1) ~= 77)
  check("A's timer silent", after.timer == 0)
  check("A's anim silent", after.anim_exec == 0 and after.anim_done == 0)
  check("restarted anim looped", loops == 3)
  local failed = false
  for _, r in ipairs(results) do
    print("app-reset: " .. r)
    if r:sub(1, 4) == "FAIL" then failed = true end
  end
  print("app-reset: -> " .. (failed and "FAIL" or "OK"))
end }
