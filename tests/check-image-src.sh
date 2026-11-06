#!/bin/bash
# Assertion for tests/image-src.lua — run from the build dir. A forged
# lv_image_dsc_t string, a light userdata or a non-font userdata must raise
# a Lua error; ASan catches a regression that reads through one instead.
set -e
out=$(./simulator/harness ../tests/image-src.lua 300 2>&1 | grep "image-src:")
echo "$out"
echo "$out" | grep -q -- "-> OK$"
echo "check-image-src: OK"
