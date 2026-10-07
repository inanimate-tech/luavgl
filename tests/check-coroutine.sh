#!/bin/bash
# Assertion for tests/coroutine-callbacks.lua — run from the build dir.
set -e
out=$(./simulator/harness ../tests/coroutine-callbacks.lua 900 2>&1 | grep "coroutine-callbacks:")
echo "$out"
echo "$out" | grep -q -- "-> OK$"
echo "check-coroutine: OK"
