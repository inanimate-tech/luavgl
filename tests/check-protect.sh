#!/bin/bash
# Assertion for tests/protect.lua — run from the build dir. A script must not
# reach or change a table every later script shares: the widget
# constructors, a shared metatable, or a cached display handle.
set -e
out=$(./simulator/harness ../tests/protect.lua 300 2>&1 | grep "protect:")
echo "$out"
echo "$out" | grep -q -- "-> OK$"
echo "check-protect: OK"
