-- Simulates 5 generations sharing one lua_State: build a screen, then
-- "reset the app" the way the firmware extension will (delete the app's
-- tree), force a full GC so stale userdata finalizers run against deleted
-- objects, and build again.
local lvgl = require("lvgl")
local stale = {}
for gen = 1, 5 do
  local root = lvgl.Object(nil, { w = lvgl.HOR_RES(), h = lvgl.VER_RES(),
                                  bg_color = "#000000", border_width = 0 })
  for i = 1, 20 do
    local card = root:Object{ x = i * 3, y = i * 2, w = 40, h = 20,
                              bg_color = "#203040", border_width = 0 }
    card:Label{ text = "gen" .. gen .. ":" .. i }
    if i % 5 == 0 then stale[#stale + 1] = card end  -- keep refs across resets
  end
  assert(lvgl.mirror():find("gen" .. gen, 1, true), "gen " .. gen .. " not on screen")
  root:delete()              -- the firmware reset path deletes the app's tree
  collectgarbage("collect")  -- stale userdata finalizers must not UAF
  collectgarbage("collect")
end
-- Touching a deleted object must be a Lua error, not a crash.
local ok = pcall(function() stale[1]:set{ x = 0 } end)
assert(ok == false, "using a deleted object should raise, not succeed")
print("appswap: OK")
