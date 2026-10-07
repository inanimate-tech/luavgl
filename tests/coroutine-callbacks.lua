-- Repro for a device panic (2026-10-07): an Anim, Timer or event callback
-- created inside a coroutine kept that coroutine's lua_State as the one to
-- call back on. Once the coroutine ended and was collected, the next frame
-- called into a freed thread (LoadProhibited on the device). Hosts that run
-- handlers in coroutines, so that they can yield, hit this with every
-- animation a handler starts.
--
-- The freed-thread access happens inside liblua, which ASan does not
-- instrument here, so this checks the cause instead: every callback must run
-- on the main thread, whichever thread registered it.
local lvgl = require("lvgl")
local root = lvgl.Object(nil, { w = lvgl.HOR_RES(), h = lvgl.VER_RES(),
                                bg_color = "#000000", border_width = 0 })
local dot = root:Object{ w = 10, h = 10, bg_color = "#40c0ff", border_width = 0 }

local seen = { anim = 0, timer = 0, event = 0 }
local wrong = {}
local function note(what)
  local _, ismain = coroutine.running()
  seen[what] = seen[what] + 1
  if not ismain then wrong[what] = true end
end

-- Kept alive (but finished) so that the unfixed code calls into a valid,
-- dead thread rather than freed memory.
DEAD = coroutine.create(function()
  dot:Anim{ run = true, start_value = 0, end_value = 255, duration = 200,
    repeat_count = lvgl.ANIM_REPEAT_INFINITE,
    exec_cb = function(o, v) note("anim"); o:set{ bg_opa = v } end }
  lvgl.Timer{ period = 20, cb = function() note("timer") end }
  dot:onevent(lvgl.EVENT.DRAW_MAIN, function() note("event") end)
end)
assert(coroutine.resume(DEAD))
assert(coroutine.status(DEAD) == "dead")

lvgl.Timer{ period = 600, cb = function(t)
  local ok = seen.anim > 0 and seen.timer > 0 and seen.event > 0
    and not wrong.anim and not wrong.timer and not wrong.event
  print(string.format("coroutine-callbacks: anim=%d%s timer=%d%s event=%d%s -> %s",
    seen.anim, wrong.anim and "(off main)" or "",
    seen.timer, wrong.timer and "(off main)" or "",
    seen.event, wrong.event and "(off main)" or "",
    ok and "OK" or "FAIL"))
  t:pause()
end }
