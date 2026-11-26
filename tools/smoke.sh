#!/bin/bash
# Boot the main scene headless for N frames (default 300) and fail on any
# engine/script ERROR or case-mismatch WARNING in the output.
set -uo pipefail
cd "$(dirname "$0")/.."
frames="${1:-300}"
out=$("${GODOT_BIN:-godot}" --headless --path . --quit-after "$frames" 2>&1)
echo "$out"
if echo "$out" | grep -qE '^(SCRIPT )?ERROR|Case mismatch'; then
	echo "SMOKE: FAILED"
	exit 1
fi
echo "SMOKE: OK ($frames frames)"
