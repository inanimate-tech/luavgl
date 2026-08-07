-- lv_line and lv_arc bindings.
--
-- Both widgets were compiled into every build already (LV_USE_LINE and
-- LV_USE_ARC are 1 in the simulator's and the device's lv_conf) but had no
-- Lua binding, so every round app hand-rolled geometry out of axis-aligned
-- Objects. See arc-spike NEXT.md item 2.

local root = lvgl.Object(nil, { w = 300, h = 300 })
root:set { bg_color = "#ffffff", bg_opa = lvgl.OPA(100) }

-- ------------------------------------------------------------------ line
local line = root:Line {
  points = { { 20, 20 }, { 150, 90 }, { 280, 40 } },
  line_width = 8,
  line_color = "#e2001a",     -- was STYLE_TYPE_INT: a colour string silently
  line_rounded = true,        -- failed to parse before this branch
  line_opa = lvgl.OPA(100),
}
assert(line ~= nil, "Line created")

-- Moving a line is the hot path for a clock hand: same point count every
-- frame, so the binding reuses its buffer rather than reallocating.
for i = 1, 50 do
  local a = i / 8
  line:set { points = { { 150, 150 }, { 150 + math.sin(a) * 120, 150 - math.cos(a) * 120 } } }
end

-- A different count must reallocate cleanly.
line:set { points = { { 0, 0 }, { 50, 50 }, { 100, 0 }, { 150, 50 } } }

-- Bad input must raise, not draw garbage or read freed memory.
local ok = pcall(function() line:set { points = { { 1, 1 } } } end)
assert(not ok, "a single point is rejected")
ok = pcall(function() line:set { points = "nope" } end)
assert(not ok, "a non-table is rejected")
ok = pcall(function() line:set { points = { 1, 2 } } end)
assert(not ok, "a flat list is rejected")

-- ------------------------------------------------------------------- arc
local arc = root:Arc {
  w = 200, h = 200,
  rotation = 270,             -- put zero at 12 o'clock
  angles = { 0, 150 },        -- a 25-minute wedge, in clock terms
  arc_width = 90,
  arc_color = "#1e7fd4",
  arc_opa = lvgl.OPA(100),
  align = lvgl.ALIGN.CENTER,
}
assert(arc ~= nil, "Arc created")

arc:set { angles = { 30, 60 } }
arc:set { start_angle = 10, end_angle = 200 }
arc:set { bg_angles = { 0, 360 } }
arc:set { range = { 0, 100 }, value = 42 }
assert(arc:get_value() == 42, "arc value round-trips")

ok = pcall(function() arc:set { angles = { 1 } } end)
assert(not ok, "a malformed angle pair is rejected")

-- Deleting must free the line's point buffer without a use-after-free; the
-- harness runs under whatever sanitisers the build has on.
line:delete()
arc:delete()

print("line_arc: ok")

-- ---------------------------------------------- constructor dispatch
-- Widget-specific properties must work in the CONSTRUCTOR table, not only
-- via obj:set{} afterwards. They used to be dropped silently: the create
-- helper hardcoded the generic setter, which resolves names through LVGL's
-- property registry and so knows nothing of composite ones like `angles`.
-- The widget kept its defaults and said nothing, which is the worst way to
-- fail. See luavgl_obj_create_helper.
local built = root:Arc {
  w = 100, h = 100,
  rotation = 270,
  bg_angles = { 0, 360 },
  angles = { 10, 80 },
}
built:set { value = 7, range = { 0, 10 } }
assert(built:get_value() == 7, "arc built from a constructor table is live")

local built_line = root:Line {
  points = { { 0, 0 }, { 10, 10 }, { 20, 0 } },
  line_width = 4,
}
assert(built_line ~= nil, "line points accepted in the constructor table")
built:delete()
built_line:delete()

print("line_arc: constructor dispatch ok")

-- ------------------------------------------------------------------ scale
-- The whole dial in one widget: 60 ticks around a full turn, every fifth
-- one major. Replaces 60 hand-placed lines.
local scale = root:Scale {
  w = 260, h = 260,
  mode = "round_inner",
  total_tick_count = 61,          -- 61 so the last lands on the first
  major_tick_every = 5,
  label_show = false,
  angle_range = 360,
  rotation = 270,                 -- first tick at 12 o'clock
  range = { 0, 60 },
}
assert(scale ~= nil, "Scale created from a constructor table")

-- ITEMS is the MINOR ticks, INDICATOR the MAJOR ones, MAIN the enclosing arc.
scale:set_style({ line_width = 4, line_color = "#14141a", length = 10 },
                lvgl.PART.ITEMS)
scale:set_style({ line_width = 14, line_color = "#14141a", length = 30 },
                lvgl.PART.INDICATOR)
scale:set_style({ arc_opa = lvgl.OPA(0) }, lvgl.PART.MAIN)

scale:set { mode = "round_outer" }
scale:set { total_tick_count = 12, major_tick_every = 3 }

ok = pcall(function() scale:set { mode = "sideways" } end)
assert(not ok, "an unknown scale mode is rejected rather than silently straight")
ok = pcall(function() scale:set { range = { 5 } } end)
assert(not ok, "a malformed scale range is rejected")

scale:delete()
print("line_arc: scale ok")
