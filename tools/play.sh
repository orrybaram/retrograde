#!/bin/bash
# Launch the game under the agent playtest driver (scripts/Playtest.gd).
#
#   tools/play.sh playtests/launch.play      run a scenario, exit 0 = all asserts passed
#   tools/play.sh serve [port]               start a live session; drive it with tools/playctl
#
# Options (before the target):
#   --headless   no window (fast, but `screenshot` fails)
#   --out DIR    output dir for transcript.jsonl + screenshots (default .playtest/)
#   --timeout S  real-time watchdog, fails the run (default 300; off for serve)
#
# Screenshots need a real window, so the default is windowed.
set -uo pipefail
cd "$(dirname "$0")/.."
godot_args=()
extra=()
out="$PWD/.playtest"
while [[ $# -gt 0 ]]; do
	case "$1" in
		--headless) godot_args+=(--headless); shift ;;
		--out) out="$2"; shift 2 ;;
		--timeout) extra+=(--playtest-timeout="$2"); shift 2 ;;
		*) break ;;
	esac
done
target="${1:?usage: tools/play.sh [--headless] [--out DIR] <scenario.play|serve> [port]}"
port="${2:-7777}"
mkdir -p "$out"

if [[ "$target" == "serve" ]]; then
	log="$out/godot.log"
	"${GODOT_BIN:-godot}" ${godot_args[@]+"${godot_args[@]}"} --path . -- --playtest=serve --playtest-port="$port" --playtest-out="$out" ${extra[@]+"${extra[@]}"} >"$log" 2>&1 &
	echo $! >"$out/godot.pid"
	for _ in $(seq 1 150); do
		if grep -q "PLAYTEST READY" "$log"; then
			echo "playtest session ready on port $port (pid $(cat "$out/godot.pid"), log $log)"
			exit 0
		fi
		kill -0 "$(cat "$out/godot.pid")" 2>/dev/null || break
		sleep 0.2
	done
	echo "playtest session failed to start; see $log" >&2
	tail -20 "$log" >&2
	exit 1
fi

[[ "$target" == res://* ]] || target="res://${target#./}"
"${GODOT_BIN:-godot}" ${godot_args[@]+"${godot_args[@]}"} --path . -- --playtest="$target" --playtest-out="$out" ${extra[@]+"${extra[@]}"} 2>&1 \
	| grep -vE 'remote port number|Remote Debugger: Unable|at: (connect_to_host|create_tcp)'
exit "${PIPESTATUS[0]}"
