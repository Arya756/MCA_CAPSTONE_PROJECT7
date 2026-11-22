#!/bin/bash
# ==============================================================================
# Script:  run_bug_injection.sh
# Owner:   Member 2 (LRU and replacement verification)
#
# Purpose: Prove the LRU tests can actually catch mistakes.
#   1. Control run : real RTL must PASS both testbenches.
#   2. Mutants     : each deliberately broken COPY of the RTL (made in a temp
#                    directory, the real RTL is never modified) must FAIL the
#                    directed testbench. Most must also fail the random test.
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
problems=0

# run_tb <rtl file> <testbench file> <pass marker>  -> prints PASS or FAIL
run_tb () {
    local file="$1" tb="$2" marker="$3" out
    if ! iverilog -g2012 -o "$TMP/sim.vvp" "$file" rtl/main_memory.v "$tb" 2>"$TMP/err.txt"; then
        echo "COMPILE-ERROR"; return
    fi
    out="$(vvp "$TMP/sim.vvp")"
    if echo "$out" | grep -q "$marker"; then echo "PASS"; else echo "FAIL"; fi
}

# check <label> <rtl file> <exp directed> <exp random>
check () {
    local label="$1" file="$2" exp_d="$3" exp_r="$4" got_d got_r status="ok"
    got_d="$(run_tb "$file" tb/tb_lru_directed.v "LRU test: PASS")"
    got_r="$(run_tb "$file" tb/tb_lru_random.v   "Random test: PASS")"
    if [ "$got_d" != "$exp_d" ] || [ "$got_r" != "$exp_r" ]; then
        status="PROBLEM"; problems=$((problems+1))
    fi
    printf "  %-24s directed: %-5s random: %-5s (expected %s / %s)  %s\n" \
           "$label" "$got_d" "$got_r" "$exp_d" "$exp_r" "$status"
}

make_mutant () {   # <name> <sed expression> <description> <expected random verdict>
    sed "$2" "$RTL" > "$TMP/$1.v"
    if cmp -s "$RTL" "$TMP/$1.v"; then
        echo "  [$1] mutation did NOT apply (pattern not found) -> PROBLEM"; problems=$((problems+1)); return
    fi
    echo "  Bug: $3"
    check "$1" "$TMP/$1.v" FAIL "$4"
}

echo "=== Bug-injection check for the 2-way LRU cache ==="
echo "Control (real RTL, both testbenches must pass):"
check "control" "$RTL" PASS PASS

echo "Mutants (directed test must catch every one):"
make_mutant bug1_hit_update      's/lru\[req_index\] <= ~hit_way;/lru[req_index] <= hit_way;/' \
            "hit update flipped (lru <= hit_way instead of ~hit_way)" FAIL
make_mutant bug2_refill_update   's/lru\[req_index\] <= ~victim_way;/lru[req_index] <= victim_way;/' \
            "refill update flipped (lru <= victim_way instead of ~victim_way)" FAIL
make_mutant bug3_victim_polarity 's/^\( *\)lru\[req_index\];/\1~lru[req_index];/' \
            "victim choice inverted when both ways are valid" FAIL
# bug4 cannot change behaviour in normal operation: after reset the LRU bit already
# points at the empty way. Random traffic therefore cannot see it; only the directed
# test 12 (which forces the LRU bit) can.
make_mutant bug4_ignore_valid    "s/(!valid0\[req_index\]) ? 1'b0 :/1'b0 ? 1'b0 :/;s/(!valid1\[req_index\]) ? 1'b1 :/1'b0 ? 1'b1 :/" \
            "victim ignores valid bits (empty way not used first)" PASS

echo "==================================================="
if [ "$problems" -eq 0 ]; then
    echo "BUG-INJECTION RESULT: OK (real RTL passes, every mutant caught by the directed test)"
    exit 0
else
    echo "BUG-INJECTION RESULT: $problems problem(s)"
    exit 1
fi
