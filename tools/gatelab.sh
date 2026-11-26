#!/usr/bin/env bash
# Gate Lab: compare Gate looks side by side. See dev/GateLab.gd for the keys.
#   tools/gatelab.sh            windowed
#   tools/gatelab.sh --shots    write every variant to .playtest/gatelab/ and quit
set -euo pipefail
cd "$(dirname "$0")/.."
exec godot --path . res://dev/GateLab.tscn -- "$@"
