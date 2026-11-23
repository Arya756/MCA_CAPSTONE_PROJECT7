#!/bin/bash
# ==============================================================================
# Script:  run_sweeps.sh
# Project: Project 7 - Cache Memory Subsystem (Phase II)
# Owner:   Member 3 (Baseline, Memory Model & Parameter Sweeps)
# Issue:   Closes #14
#
# Description:
#   One-command reproducible runner for all Phase II parameter sweeps:
#     1. Memory Read Latency Sweep (RD_LAT = 4, 8, 16)
#     2. Memory Write Latency Sweep (WR_LAT = 2, 4, 8)
#     3. Cache Capacity Sweep (CACHE_CAPACITY = 512, 1024, 2048 Bytes)
#     4. Cache Block Size Sweep (BLOCK_SIZE = 8, 16, 32 Bytes)
#     5. AMAT vs Measured Cycles per access comparison
#     6. Automatic formula verification: Delta Cycles = Misses * Delta Latency
#
# Usage:
#   ./scripts/run_sweeps.sh
# ==============================================================================

set -uo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

echo "============================================================"
echo " PROJECT 7: REPRODUCIBLE PARAMETER SWEEPS RUNNER"
echo " Working Directory: $REPO_ROOT"
echo " Date: $(date)"
echo "============================================================"

# Ensure traces exist
if [ ! -f "traces/seq_stream.txt" ]; then
    echo ">>> Generating memory traces..."
    python3 scripts/gen_traces.py || { echo "ERROR: Trace generation failed!"; exit 1; }
fi

# Run the master sweep engine
python3 scripts/parameter_sweeps.py || {
    echo "ERROR: Parameter sweeps failed!"
    exit 1
}

echo ""
echo "Sweep execution finished with exit status 0."
exit 0
