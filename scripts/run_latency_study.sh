#!/bin/bash
# ==============================================================================
# Script:  run_latency_study.sh
# Project: Project 7 - Cache Memory Subsystem (Phase I)
# Owner:   Member 3 (Direct-Mapped Baseline & Memory Model)
#
# Description:
#   Performs an automated latency sensitivity study by compiling and executing
#   tb_compare across all 7 traces under three read latency configurations:
#     - RD_LAT = 4  (Fast backing memory)
#     - RD_LAT = 8  (Baseline default memory)
#     - RD_LAT = 16 (High-latency / slow backing memory)
#   Generates individual CSV outputs and compiles results/latency_sensitivity.csv.
# ==============================================================================

set -uo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

echo "============================================================"
echo " PROJECT 7: MEMORY LATENCY SENSITIVITY STUDY"
echo " Owner: Member 3 (Baseline and Memory Model)"
echo " Date:  $(date)"
echo "============================================================"

# Ensure traces exist
if [ ! -f "traces/seq_stream.txt" ]; then
    echo "Generating traces..."
    python3 scripts/gen_traces.py
fi

mkdir -p results

LATENCIES=(4 8 16)

for LAT in "${LATENCIES[@]}"; do
    echo ""
    echo "------------------------------------------------------------"
    echo ">>> Running full regression with RD_LAT = ${LAT} cycles..."
    echo "------------------------------------------------------------"
    
    SIM_BIN="compare_rd${LAT}.vvp"
    OUT_CSV="results/results_rd${LAT}.csv"
    
    iverilog -g2012 -DRD_LAT=${LAT} -o "${SIM_BIN}" \
        rtl/cache_2way_lru.v rtl/cache_direct.v rtl/main_memory.v tb/tb_compare.v || {
        echo "ERROR: Failed to compile tb_compare with RD_LAT=${LAT}"
        exit 1
    }
    
    vvp "${SIM_BIN}" "+CSV=${OUT_CSV}" || {
        echo "ERROR: Simulation failed for RD_LAT=${LAT}"
        rm -f "${SIM_BIN}"
        exit 1
    }
    
    rm -f "${SIM_BIN}"
    echo "Completed RD_LAT=${LAT}. Output saved to ${OUT_CSV}."
done

# Generate consolidated comparison table
CONSOLIDATED="results/latency_sensitivity.csv"
echo "trace,design,accesses,hits,misses,hit_rate,cycles_rd4,cycles_rd8,cycles_rd16,delta_8_to_4,delta_8_to_16" > "${CONSOLIDATED}"

python3 - << 'EOF'
import csv

def read_results(filename):
    data = {}
    with open(filename, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            key = (row['trace'], row['design'])
            data[key] = row
    return data

d4  = read_results("results/results_rd4.csv")
d8  = read_results("results/results_rd8.csv")
d16 = read_results("results/results_rd16.csv")

with open("results/latency_sensitivity.csv", "w", newline="") as f:
    writer = csv.writer(f)
    writer.writerow([
        "trace", "design", "accesses", "hits", "misses", "hit_rate",
        "cycles_rd4", "cycles_rd8", "cycles_rd16", "delta_8_to_4", "delta_8_to_16"
    ])
    for key, r8 in d8.items():
        r4 = d4.get(key, {})
        r16 = d16.get(key, {})
        c4 = int(r4.get('cycles', 0))
        c8 = int(r8.get('cycles', 0))
        c16 = int(r16.get('cycles', 0))
        d_4 = c4 - c8
        d_16 = c16 - c8
        writer.writerow([
            r8['trace'], r8['design'], r8['accesses'], r8['hits'], r8['misses'], r8['hit_rate'],
            c4, c8, c16, d_4, d_16
        ])
EOF

echo ""
echo "============================================================"
echo " LATENCY SENSITIVITY STUDY COMPLETE"
echo " Consolidated results stored in: ${CONSOLIDATED}"
echo "============================================================"
cat "${CONSOLIDATED}"
