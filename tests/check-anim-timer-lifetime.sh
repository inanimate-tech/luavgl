#!/bin/bash
# Assertion for tests/anim-timer-lifetime.lua — run from the build dir.
set -e
out=$(./simulator/harness ../tests/anim-timer-lifetime.lua 600 2>&1 | grep "anim-timer-lifetime:")
echo "$out"
echo "$out" | grep -q -- "-> OK$"
echo "check-anim-timer-lifetime: OK"
