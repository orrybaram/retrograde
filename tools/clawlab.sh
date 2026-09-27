#!/usr/bin/env bash
# Claw Lab: fly Freight into the DORSAL ARM's claw. See dev/claw_lab/ClawLab.gd for the keys.
#   tools/clawlab.sh            windowed
#   tools/clawlab.sh --shots    stage a delivery, screenshot each beat to .playtest/clawlab/, quit
set -euo pipefail
cd "$(dirname "$0")/.."
exec godot --path . res://dev/claw_lab/ClawLab.tscn -- "$@"
