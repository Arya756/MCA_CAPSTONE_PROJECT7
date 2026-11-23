#!/bin/bash
# ==============================================================================
# Script:  run_all.sh
# Project: Project 7 - 2-Way Set-Associative vs Direct-Mapped Cache
# Owner:   Member 4 (Traces, Comparison Testbench, Scripts)
#
# Description:
#   One-command automated test runner (works on fresh clone):
#   1. Generates all 11 memory traces via scripts/gen_traces.py.
#   2. Compiles and executes tb_lru_directed (verifies LRU replacement).
#   3. Compiles and executes tb_direct_basic (verifies direct-mapped baseline).
#   4. Compiles and executes tb_compare (cross-checks data against golden memory,
#      evaluates cache metrics across all 11 traces, writes results/results.csv).
#   5. Generates hit-rate and cycles bar charts via scripts/plot_results.py.
#   6. Validates zero mismatches and all test passes. Exits non-zero on error.
#
# Phase II (Member 4): updated to run all 11 traces (added matrix_walk, write_heavy).
#
# Usage:
#   ./scripts/run_all.sh          # Run from project root
#   bash scripts/run_all.sh       # Alternative invocation
# ==============================================================================

set -uo pipefail

# Ensure standard bin paths (Homebrew on macOS, Linux standard paths)
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

echo "============================================================"
echo " PROJECT 7: CACHE REGRESSION SUITE (Phase II)"
echo " Working Directory: $REPO_ROOT"
echo " Date: $(date)"
echo "============================================================"

# Check tool dependencies - fail clearly if missing
MISSING_TOOLS=0
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 not found! Install from https://python.org or: brew install python3"; MISSING_TOOLS=1; }
command -v iverilog >/dev/null 2>&1 || { echo "ERROR: iverilog not found! Install with: sudo apt install iverilog  OR  brew install icarus-verilog"; MISSING_TOOLS=1; }
command -v vvp     >/dev/null 2>&1 || { echo "ERROR: vvp not found! (should come with iverilog)"; MISSING_TOOLS=1; }
if [ "$MISSING_TOOLS" -ne 0 ]; then
    echo ""
    echo "FATAL: Required tools missing. See errors above. Exiting."
    exit 1
fi

echo "Tools OK: python3=$(python3 --version 2>&1 | cut -d' ' -f2)  iverilog=$(iverilog -V 2>&1 | head -1)"

# Create required directories
mkdir -p traces results docs/img

# Clean up stale build/sim artifacts
rm -f lru_test.vvp direct_test.vvp compare_test.vvp

# ------------------------------------------------------------------------------
# STEP 1: Generate Traces (11 traces: 9 Phase I + 2 Phase II additions)
# ------------------------------------------------------------------------------
echo ""
echo ">>> [1/5] Generating memory traces..."
python3 scripts/gen_traces.py || { echo "FAIL: Trace generation failed!"; exit 1; }

# Verify trace count
TRACE_COUNT=$(ls -1 traces/*.txt 2>/dev/null | wc -l | tr -d ' ')
echo "    Generated $TRACE_COUNT trace files in traces/"
if [ "$TRACE_COUNT" -lt 11 ]; then
    echo "ERROR: Expected at least 11 traces, found $TRACE_COUNT. Check scripts/gen_traces.py."
    exit 1
fi

# ------------------------------------------------------------------------------
# STEP 2: Run Directed LRU Testbench
# ------------------------------------------------------------------------------
echo ""
echo ">>> [2/5] Compiling and running tb_lru_directed..."
iverilog -g2012 -o lru_test.vvp rtl/cache_2way_lru.v rtl/main_memory.v tb/tb_lru_directed.v || {
    echo "FAIL: Compilation of tb_lru_directed failed!"; exit 1;
}
LRU_OUTPUT=$(vvp lru_test.vvp)
echo "$LRU_OUTPUT"
rm -f lru_test.vvp

if ! echo "$LRU_OUTPUT" | grep -q "LRU test: PASS"; then
    echo "ERROR: tb_lru_directed did not pass! See output above."
    exit 1
fi

# ------------------------------------------------------------------------------
# STEP 3: Run Direct-Mapped Baseline Testbench
# ------------------------------------------------------------------------------
echo ""
echo ">>> [3/5] Compiling and running tb_direct_basic..."
iverilog -g2012 -o direct_test.vvp rtl/cache_direct.v rtl/main_memory.v tb/tb_direct_basic.v || {
    echo "FAIL: Compilation of tb_direct_basic failed!"; exit 1;
}
DIRECT_OUTPUT=$(vvp direct_test.vvp)
echo "$DIRECT_OUTPUT"
rm -f direct_test.vvp

if ! echo "$DIRECT_OUTPUT" | grep -q "DIRECT test: PASS"; then
    echo "ERROR: tb_direct_basic did not pass! See output above."
    exit 1
fi

# ------------------------------------------------------------------------------
# STEP 4: Run Side-by-Side Comparison Testbench (11 traces)
# ------------------------------------------------------------------------------
echo ""
echo ">>> [4/5] Compiling and running tb_compare across all 11 traces..."
iverilog -g2012 -o compare_test.vvp rtl/cache_2way_lru.v rtl/cache_direct.v rtl/main_memory.v tb/tb_compare.v || {
    echo "FAIL: Compilation of tb_compare failed!"; exit 1;
}
COMPARE_OUTPUT=$(vvp compare_test.vvp)
echo "$COMPARE_OUTPUT"
rm -f compare_test.vvp

if ! echo "$COMPARE_OUTPUT" | grep -q "mismatches: 0"; then
    echo "ERROR: tb_compare detected data mismatches! See output above. Do NOT submit."
    exit 1
fi

if ! echo "$COMPARE_OUTPUT" | grep -q "Compare test: PASS"; then
    echo "ERROR: tb_compare failed! See output above."
    exit 1
fi

# ------------------------------------------------------------------------------
# STEP 5: Generate Result Charts (hit_rate.png and cycles.png)
# ------------------------------------------------------------------------------
echo ""
echo ">>> [5/5] Generating result charts..."
if python3 -c "import matplotlib" 2>/dev/null; then
    python3 scripts/plot_results.py || {
        echo "WARNING: Chart generation failed (non-critical). Results CSV is still valid."
    }
else
    echo "NOTE: matplotlib not installed. Skipping chart generation."
    echo "      Install with: pip3 install matplotlib"
    echo "      Then run: python3 scripts/plot_results.py"
fi

# ------------------------------------------------------------------------------
# FINAL REGRESSION SUMMARY
# ------------------------------------------------------------------------------
echo ""
echo "============================================================"
echo "               ALL REGRESSION TESTS PASSED!                 "
echo "============================================================"
echo " - LRU test: PASS"
echo " - DIRECT test: PASS"
echo " - mismatches: 0"
echo " - Traces tested: $TRACE_COUNT"
echo " - Results saved to: results/results.csv"
if [ -f results/hit_rate.png ] && [ -f results/cycles.png ]; then
    echo " - Charts saved to:  results/hit_rate.png, results/cycles.png"
fi
echo "============================================================"
echo ""
echo "Results Summary (results/results.csv):"
cat results/results.csv
echo ""
echo "Regression complete with exit status 0."
exit 0
