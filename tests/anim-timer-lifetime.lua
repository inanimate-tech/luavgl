-- Object lifetimes on LVGL 9 (tests/check-anim-timer-lifetime.sh):
--   * a stopped anim is released (LVGL 9 calls deleted_cb, not
--     completed_cb, when lv_anim_delete removes an anim), without its
--     done_cb; a completed one runs done_cb once and is released; one whose
--     done_cb restarts it keeps running
--   * an anim with no exec_cb is refused where Lua can catch it, rather
--     than raising from lv_timer_handler (an unprotected error: abort)
--   * a timer whose repeat_count runs out is paused, not freed under its
--     handle (its __gc would free it again)
--   * a screen's get_parent() is nil, not a crash
local lvgl = require("lvgl")
local results = {}
local function check(name, ok) results[#results + 1] = (ok and "ok " or "FAIL ") .. name end

check("screen has no parent", lvgl.Object():get_screen():get_parent() == nil)

local weak = setmetatable({}, { __mode = "v" })
local root = lvgl.Object(nil, { w = 200, h = 100 })
local box = root:Object { w = 20, h = 20 }

local done = { stop = 0, complete = 0 }
local function anim(key, duration)
  return box:Anim { run = true, start_value = 0, end_value = 100,
    duration = duration, exec_cb = function(o, v) o:set { x = v } end,
    done_cb = function() done[key] = done[key] + 1 end }
end

-- stop releases the anim; a cancelled anim is not done
local function start_and_stop()
  local a = anim("stop", 5000)
  weak.stopped = a
  a:stop()
end
start_and_stop()
collectgarbage("collect")
collectgarbage("collect")
check("stopped anim skipped done_cb", done.stop == 0)
check("stopped anim collected", weak.stopped == nil)

-- completion runs done_cb once, then releases the anim
local function start_short() weak.completed = anim("complete", 50) end
start_short()

-- a done_cb that restarts its anim keeps it running through a GC
local loops = 0
box:Anim { run = true, start_value = 0, end_value = 10, duration = 30,
  exec_cb = function(o, v) o:set { y = v } end,
  done_cb = function(a)
    loops = loops + 1
    if loops < 3 then a:start() end
    collectgarbage("collect")
  end }

-- no exec_cb: refused at start, with or without a delay
check("anim without exec_cb refused",
  pcall(function() box:Anim { run = true, start_value = 0, end_value = 1, duration = 10 } end) == false)
check("delayed anim without exec_cb refused",
  pcall(function() box:Anim { run = true, start_value = 0, end_value = 1, duration = 10,
    delay = 50, early_apply = false } end) == false)

-- repeat_count: runs its count, then stays a valid paused handle
local fired = 0
local once = lvgl.Timer { period = 20, repeat_count = 2, cb = function() fired = fired + 1 end }

lvgl.Timer { period = 300, repeat_count = 1, cb = function()
  collectgarbage("collect")
  collectgarbage("collect")
  check("completed anim ran done_cb once", done.complete == 1)
  check("completed anim collected", weak.completed == nil)
  check("restarted anim looped", loops == 3)
  check("repeat_count timer fired its count", fired == 2)
  check("spent timer handle still usable", pcall(function() once:resume(); once:pause() end))
  local failed = false
  for _, r in ipairs(results) do
    print("anim-timer-lifetime: " .. r)
    if r:sub(1, 4) == "FAIL" then failed = true end
  end
  print("anim-timer-lifetime: -> " .. (failed and "FAIL" or "OK"))
end }
-- the harness then lua_close()s: both spent timers' __gc must free them once
