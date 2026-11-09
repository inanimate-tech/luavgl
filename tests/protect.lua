-- Shared tables (tests/check-protect.sh): an embedder that runs untrusted
-- scripts one after another on one lua_State must not let a script reach a
-- table that every later script shares, and change it. The routes checked:
-- the table of widget constructors, through `lvgl.__index` and
-- `obj.__index`; every shared metatable, through getmetatable and
-- setmetatable; and the cached display handle.
local lvgl = require("lvgl")
local d = lvgl.bind()

local results = {}
local function check(name, ok) results[#results + 1] = (ok and "ok " or "FAIL ") .. name end
local function raises(f) return not pcall(f) end

-- A value that holds the widget constructors: the shared table, or a copy
-- of what is in it.
local function is_constructors(v)
  return type(v) == "table" and (rawget(v, "Object") ~= nil or rawget(v, "Label") ~= nil)
end

-- What a script gets reading key on v: nil when the read raises.
local function read(v, key)
  local ok, r = pcall(function() return v[key] end)
  return ok and r or nil
end

local root = lvgl.Object(nil, { w = 200, h = 100 })
local objects = {
  Object = root,
  Label = root:Label { text = "x" },
  Button = root:Button {},
  Image = root:Image {},
  Arc = root:Arc {},
}

-- Constructors: no __* key reaches them ---------------------------------
local meta_keys = { "__index", "__newindex", "__metatable", "__name", "__gc", "__call" }
local reached = {}
local function probe(what, v)
  for _, k in ipairs(meta_keys) do
    if is_constructors(read(v, k)) then reached[#reached + 1] = what .. "." .. k end
  end
end
probe("lvgl", lvgl)
probe("handle", d)
for name, o in pairs(objects) do probe(name, o) end
check("no lvgl/handle/object __* key returns the constructors (" ..
  table.concat(reached, ",") .. ")", #reached == 0)
check("lvgl.__index is nil", read(lvgl, "__index") == nil)
check("obj.__index raises or is nil", read(root, "__index") == nil)
check("label.__index raises or is nil", read(objects.Label, "__index") == nil)

-- getmetatable: false on every luavgl value --------------------------------
local values = {
  lvgl = lvgl,
  handle = d,
  ["handle.disp"] = d.disp,
  _root = rawget(lvgl, "_root"),
  timer = lvgl.Timer { period = 1000, paused = true, cb = function() end },
  style = lvgl.Style { radius = 3 },
  anim = root:Anim { run = false, start_value = 0, end_value = 1, duration = 100,
    exec_cb = function() end },
  group = lvgl.group.create(),
  ["lvgl.disp"] = lvgl.disp,
  ["lvgl.ALIGN"] = lvgl.ALIGN,
}
for name, o in pairs(objects) do values[name] = o end
local unprotected = {}
for name, v in pairs(values) do
  if getmetatable(v) ~= false then unprotected[#unprotected + 1] = name end
end
table.sort(unprotected)
check("getmetatable is false on every value (" .. table.concat(unprotected, ",") .. ")",
  #unprotected == 0)
check("setmetatable(lvgl, ...) raises", raises(function() setmetatable(lvgl, {}) end))
check("setmetatable(handle, nil) raises", raises(function() setmetatable(d, nil) end))
check("timer methods still resolve", pcall(function() values.timer:pause() end))
check("style methods still resolve", pcall(function() values.style:set { radius = 4 } end))
values.timer:delete()

-- Writes through every route: none may land.
local evil = function() return "evil" end
pcall(function() lvgl.__index.Label = evil end)
pcall(function() root.__index.Label = evil end)
pcall(function() objects.Button.__index.Label = evil end)
pcall(function() getmetatable(lvgl).__index.Label = evil end)
pcall(function() getmetatable(root).__index = evil end)
-- a label made through f is a real lv_label
local function builds_label(f)
  local ok, o = pcall(f)
  return ok and tostring(o):find("^label%(") ~= nil
end
check("root:Label still builds a label",
  builds_label(function() return root:Label { text = "y" } end))
check("lvgl.Label is still the constructor",
  builds_label(function() return lvgl.Label(root, { text = "z" }) end))
-- A custom widget an embedder registered on the widgets metatable from C
-- (the harness registers HarnessWidget) still resolves, as luavgl's own do.
check("a C-registered custom widget resolves on the module",
  pcall(function() return lvgl.HarnessWidget(root, {}) end))
check("a C-registered custom widget resolves on an object",
  pcall(function() return objects.Label:HarnessWidget {} end))
check("label methods still resolve", pcall(function() objects.Label:set { text = "w" } end))

-- The handle: what one app writes into it dies with the app -------------
check("bind() is cached within an app", lvgl.bind() == d)
d.injected = true
d.Label = evil
rawset(d, "Object", evil)
check("an app may still write its own handle", d.Label == evil)

harness_app_reset()

local d2 = lvgl.bind()
check("after reset, bind() builds a fresh handle", d2 ~= d)
check("the fresh handle has none of the old app's fields", rawget(d2, "injected") == nil)
check("the fresh handle's Label builds a label",
  builds_label(function() return d2.Label { text = "b" } end))
check("the fresh handle's Object builds an object",
  tostring(d2.Object {}):find("^obj%(") ~= nil)
check("the fresh handle's metatable is protected", getmetatable(d2) == false)
check("the fresh handle falls through to the module", d2.Style ~= nil and d2.ALIGN ~= nil)

-- Font names: lvgl.Font copies the name with LVGL's allocator and must give
-- it back to LVGL's allocator (ASan reports a mismatch when LVGL's is not
-- the C library's).
local fonts_ok = true
for i = 1, 50 do
  fonts_ok = fonts_ok and pcall(lvgl.Font, "nosuchfont, montserrat", 14)
  fonts_ok = fonts_ok and not pcall(lvgl.Font, "nosuchfont", 14)
end
check("lvgl.Font creates and fails without leaking its name", fonts_ok)

local failed = 0
for _, r in ipairs(results) do
  print("protect: " .. r)
  if r:sub(1, 4) == "FAIL" then failed = failed + 1 end
end
print("protect: " .. (failed == 0 and "-> OK" or ("-> " .. failed .. " FAILED")))
