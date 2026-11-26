#!/bin/bash
# Run gdUnit4 test suites headless. Extra args are passed to the gdUnit4 runner,
# e.g. `tools/test.sh -a res://test/TierDataTest.gd` to run a single suite.
set -uo pipefail
cd "$(dirname "$0")/.."
export GODOT_BIN="${GODOT_BIN:-$(command -v godot)}"
args=("$@")
[ ${#args[@]} -eq 0 ] && args=(-a res://test)
addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode "${args[@]}" 2>&1 \
	| sed 's/\x1b\[[0-9;]*[A-Za-z]//g' \
	| grep -vE 'remote port number|Remote Debugger: Unable|at: (connect_to_host|create_tcp)'
exit "${PIPESTATUS[0]}"
