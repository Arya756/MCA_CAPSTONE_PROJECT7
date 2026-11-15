#!/bin/bash
# ==============================================================================
# Script:  run_all.sh
# Project: Project 7 - 2-Way Set-Associative vs Direct-Mapped Cache
# Owner:   Member 4 (Traces, Comparison Testbench, Scripts)
#
# Description:
#   One-command automated test runner:
#   1. Generates all memory traces via scripts/gen_traces.py.
#   2. Compiles and executes tb_lru_directed (verifies LRU replacement).
#   3. Compiles and executes tb_direct_basic (verifies direct-mapped baseline).
#   4. Compiles and executes tb_compare (cross-checks data against golden memory,
#      evaluates cache metrics across all traces, writes results/results.csv).
#   5. Validates zero mismatches and all test passes. Exits non-zero on error.
# ==============================================================================

set -uo pipefail

# Ensure standard bin paths (Homebrew on macOS, Linux standard paths)
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

echo "============================================================"
echo " PROJECT 7: CACHE REGRESSION SUITE"
echo " Working Directory: $REPO_ROOT"
echo " Date: $(date)"
echo "============================================================"

# Check tool dependencies
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 not found!"; exit 1; }
command -v iverilog >/dev/null 2>&1 || { echo "ERROR: iverilog not found! (Install with: sudo apt install iverilog or brew install icarus-verilog)"; exit 1; }
command -v vvp >/dev/null 2>&1 || { echo "ERROR: vvp not found!"; exit 1; }

# Create required directories
mkdir -p traces results docs/img

# Clean up stale build/sim artifacts
rm -f lru_test.vvp direct_test.vvp compare_test.vvp

# ------------------------------------------------------------------------------
# STEP 1: Generate Traces
# ------------------------------------------------------------------------------
echo ""
echo ">>> [1/4] Generating memory traces..."
python3 scripts/gen_traces.py || { echo "FAIL: Trace generation failed!"; exit 1; }

# ------------------------------------------------------------------------------
# STEP 2: Run Directed LRU Testbench
# ------------------------------------------------------------------------------
echo ""
echo ">>> [2/4] Compiling and running tb_lru_directed..."
iverilog -g2012 -o lru_test.vvp rtl/cache_2way_lru.v rtl/main_memory.v tb/tb_lru_directed.v || {
    echo "FAIL: Compilation of tb_lru_directed failed!"; exit 1;
}
LRU_OUTPUT=$(vvp lru_test.vvp)
echo "$LRU_OUTPUT"
rm -f lru_test.vvp

if ! echo "$LRU_OUTPUT" | grep -q "LRU test: PASS"; then
    echo "ERROR: tb_lru_directed did not pass!"
    exit 1
fi

# ------------------------------------------------------------------------------
# STEP 3: Run Direct-Mapped Baseline Testbench
# ------------------------------------------------------------------------------
echo ""
echo ">>> [3/4] Compiling and running tb_direct_basic..."
iverilog -g2012 -o direct_test.vvp rtl/cache_direct.v rtl/main_memory.v tb/tb_direct_basic.v || {
    echo "FAIL: Compilation of tb_direct_basic failed!"; exit 1;
}
DIRECT_OUTPUT=$(vvp direct_test.vvp)
echo "$DIRECT_OUTPUT"
rm -f direct_test.vvp

if ! echo "$DIRECT_OUTPUT" | grep -q "DIRECT test: PASS"; then
    echo "ERROR: tb_direct_basic did not pass!"
    exit 1
fi

# ------------------------------------------------------------------------------
# STEP 4: Run Side-by-Side Comparison Testbench
# ------------------------------------------------------------------------------
echo ""
echo ">>> [4/4] Compiling and running tb_compare across all traces..."
iverilog -g2012 -o compare_test.vvp rtl/cache_2way_lru.v rtl/cache_direct.v rtl/main_memory.v tb/tb_compare.v || {
    echo "FAIL: Compilation of tb_compare failed!"; exit 1;
}
COMPARE_OUTPUT=$(vvp compare_test.vvp)
echo "$COMPARE_OUTPUT"
rm -f compare_test.vvp

if ! echo "$COMPARE_OUTPUT" | grep -q "mismatches: 0"; then
    echo "ERROR: tb_compare detected data mismatches!"
    exit 1
fi

if ! echo "$COMPARE_OUTPUT" | grep -q "Compare test: PASS"; then
    echo "ERROR: tb_compare failed!"
    exit 1
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
echo " - Results saved to: results/results.csv"
echo "============================================================"
echo ""
echo "Results Summary (results/results.csv):"
cat results/results.csv
echo ""
echo "Regression complete with exit status 0."
exit 0
