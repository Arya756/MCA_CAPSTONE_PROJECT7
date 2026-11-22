#!/bin/bash
# ==============================================================================
# Script:  run_bug_injection.sh
# Owner:   Member 2 (LRU and replacement verification)
#
# Purpose: Prove the LRU tests can actually catch mistakes.
#   1. Control run : real RTL must PASS.
#   2. Mutants     : each deliberately broken COPY of the RTL (made in a temp
#                    directory, the real RTL is never modified) must FAIL.
# Usage:   ./scripts/run_bug_injection.sh      (run from the repo root)
# ==============================================================================
set -uo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

RTL=rtl/cache_2way_lru.v
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
failures=0

run_case () {            # $1 = label, $2 = rtl file, $3 = expected (PASS|FAIL)
    local label="$1" file="$2" expect="$3" out verdict
    if ! iverilog -g2012 -o "$TMP/sim.vvp" "$file" rtl/main_memory.v tb/tb_lru_directed.v 2>"$TMP/err.txt"; then
        echo "  [$label] COMPILE ERROR"; cat "$TMP/err.txt"; failures=$((failures+1)); return
    fi
    out="$(vvp "$TMP/sim.vvp")"
    if echo "$out" | grep -q "LRU test: PASS"; then verdict="PASS"; else verdict="FAIL"; fi
    local nfail; nfail=$(echo "$out" | grep -c "FAIL:")
    if [ "$verdict" = "$expect" ]; then
        echo "  [$label] testbench verdict = $verdict ($nfail failing checks)  -> as expected"
    else
        echo "  [$label] testbench verdict = $verdict, expected $expect  -> PROBLEM"
        failures=$((failures+1))
    fi
}

make_mutant () {         # $1 = name, $2 = sed expression, $3 = description
    sed "$2" "$RTL" > "$TMP/$1.v"
    if cmp -s "$RTL" "$TMP/$1.v"; then
        echo "  [$1] mutation did NOT apply (pattern not found) -> PROBLEM"; failures=$((failures+1)); return
    fi
    echo "  Bug: $3"
    run_case "$1" "$TMP/$1.v" FAIL
}

echo "=== Bug-injection check for the 2-way LRU cache ==="
echo "Control (real RTL, must pass):"
run_case "control" "$RTL" PASS

echo "Mutants (each must be caught by tb_lru_directed):"
make_mutant bug1_hit_update    's/lru\[req_index\] <= ~hit_way;/lru[req_index] <= hit_way;/' \
            "hit update flipped (lru <= hit_way instead of ~hit_way)"
make_mutant bug2_refill_update 's/lru\[req_index\] <= ~victim_way;/lru[req_index] <= victim_way;/' \
            "refill update flipped (lru <= victim_way instead of ~victim_way)"
make_mutant bug3_victim_polarity 's/^\( *\)lru\[req_index\];/\1~lru[req_index];/' \
            "victim choice inverted when both ways are valid"

echo "==================================================="
if [ "$failures" -eq 0 ]; then
    echo "BUG-INJECTION RESULT: OK (real RTL passes, all mutants caught)"
    exit 0
else
    echo "BUG-INJECTION RESULT: $failures problem(s)"
    exit 1
fi
