#!/bin/bash
# Assertion for tests/app-reset.lua — run from the build dir.
set -e
out=$(./simulator/harness ../tests/app-reset.lua 700 2>&1 | grep "app-reset:")
echo "$out"
echo "$out" | grep -q -- "-> OK$"
echo "check-app-reset: OK"
