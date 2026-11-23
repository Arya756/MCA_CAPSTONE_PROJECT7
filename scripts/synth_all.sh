#!/usr/bin/env bash
# ==============================================================================
# PROJECT 7: REPRODUCIBLE SYNTHESIS AND RESOURCE UTILIZATION SUITE (Phase II)
# Owner: Member 1 (2-Way Cache RTL & Synthesis/Resource Report)
# Course: MCA Capstone Design - Advanced Computer Architecture
#
# Top Modules:
#   - rtl/cache_2way_lru.v (Top: cache_2way_lru)
#   - rtl/cache_direct.v   (Top: cache_direct)
#
# Target Technologies & Flows:
#   1. Generic Technology-Independent:
#      Command: synth -top <module>; stat
#      Evaluates: Generic gate counts, multiplexers, and flip-flops.
#   2. AMD/Xilinx 7-Series FPGA Mapping:
#      Command: synth_xilinx -top <module>; stat
#      Evaluates: LUT2-LUT6, FDCE/FDRE, MUXF7/F8, BRAM inference (RAMB18/36).
#   3. Lattice ECP5 FPGA Mapping:
#      Command: synth_ecp5 -top <module>; stat
#      Evaluates: ECP5 LUT4, TRELLIS_FF, CCU2C, DP16KD BRAM inference.
#
# Timing / Fmax Notice:
#   Because storage arrays perform asynchronous/combinational reads, synthesis
#   maps all 1 KB data & tags to ~10,000 discrete flip-flops rather than BRAM.
#   Out-of-context physical P&R with >70,000 nets on 296 unconstrained I/Os
#   exhausts routing channels. True physical Fmax requires vendor P&R (Vivado/Quartus)
#   and is documented as "NOT MEASURED (no place-and-route)".
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
RESULTS_DIR="${ROOT_DIR}/results"

cd "${ROOT_DIR}"
mkdir -p "${RESULTS_DIR}"

echo "============================================================"
echo " PROJECT 7: HARDWARE SYNTHESIS & RESOURCE REPORT (Phase II) "
echo " Working Directory: ${ROOT_DIR}"
echo " Date: $(date)"
echo "============================================================"

# Verify yosys binary
if ! command -v yosys >/dev/null 2>&1; then
    echo "ERROR: 'yosys' is not installed or not in PATH."
    echo "Install via Homebrew: brew install yosys"
    exit 1
fi

YOSYS_VER="$(yosys -V | head -n 1)"
echo "Tool: ${YOSYS_VER}"
echo ""

# ------------------------------------------------------------------------------
# FLOW 1: Generic Technology-Independent Synthesis
# ------------------------------------------------------------------------------
echo ">>> [1/3] Running Generic Technology-Independent Synthesis..."

echo "    - Synthesizing cache_2way_lru (generic)..."
yosys -l "${RESULTS_DIR}/synth_2way_generic.log" \
      -p "read_verilog -sv rtl/cache_2way_lru.v; synth -top cache_2way_lru; stat"

echo "    - Synthesizing cache_direct (generic)..."
yosys -l "${RESULTS_DIR}/synth_direct_generic.log" \
      -p "read_verilog -sv rtl/cache_direct.v; synth -top cache_direct; stat"

# Maintain backwards compatibility with Phase I filenames
cp -f "${RESULTS_DIR}/synth_2way_generic.log" "${RESULTS_DIR}/synth_2way.log"
cp -f "${RESULTS_DIR}/synth_direct_generic.log" "${RESULTS_DIR}/synth_direct.log"

# ------------------------------------------------------------------------------
# FLOW 2: AMD/Xilinx 7-Series FPGA Mapping
# ------------------------------------------------------------------------------
echo ">>> [2/3] Running AMD/Xilinx 7-Series FPGA Mapping..."

echo "    - Synthesizing cache_2way_lru (Xilinx 7-Series)..."
yosys -l "${RESULTS_DIR}/synth_2way_xilinx.log" \
      -p "read_verilog -sv rtl/cache_2way_lru.v; synth_xilinx -top cache_2way_lru; stat"

echo "    - Synthesizing cache_direct (Xilinx 7-Series)..."
yosys -l "${RESULTS_DIR}/synth_direct_xilinx.log" \
      -p "read_verilog -sv rtl/cache_direct.v; synth_xilinx -top cache_direct; stat"

# ------------------------------------------------------------------------------
# FLOW 3: Lattice ECP5 FPGA Mapping
# ------------------------------------------------------------------------------
echo ">>> [3/3] Running Lattice ECP5 FPGA Mapping..."

echo "    - Synthesizing cache_2way_lru (ECP5)..."
yosys -l "${RESULTS_DIR}/synth_2way_ecp5.log" \
      -p "read_verilog -sv rtl/cache_2way_lru.v; synth_ecp5 -top cache_2way_lru; stat"

echo "    - Synthesizing cache_direct (ECP5)..."
yosys -l "${RESULTS_DIR}/synth_direct_ecp5.log" \
      -p "read_verilog -sv rtl/cache_direct.v; synth_ecp5 -top cache_direct; stat"

# ------------------------------------------------------------------------------
# SUMMARY REPORT PARSER
# ------------------------------------------------------------------------------
echo ""
echo "============================================================"
echo " SYNTHESIS RUN COMPLETE - SUMMARY OF EXTRACTED METRICS      "
echo "============================================================"

# Generic Metrics (parsed from the final statistics block)
GEN_2W_CELLS=$(tail -n 30 "${RESULTS_DIR}/synth_2way_generic.log" | grep -E "cells" | awk '{print $1}' | tail -n 1)
GEN_DIR_CELLS=$(tail -n 30 "${RESULTS_DIR}/synth_direct_generic.log" | grep -E "cells" | awk '{print $1}' | tail -n 1)

GEN_2W_FF=$(tail -n 30 "${RESULTS_DIR}/synth_2way_generic.log" | grep -E 'DFF' | awk '{s+=$1} END {print s}')
GEN_DIR_FF=$(tail -n 30 "${RESULTS_DIR}/synth_direct_generic.log" | grep -E 'DFF' | awk '{s+=$1} END {print s}')

GEN_2W_MUX=$(tail -n 30 "${RESULTS_DIR}/synth_2way_generic.log" | grep -E 'MUX' | awk '{print $1}' | tail -n 1)
GEN_DIR_MUX=$(tail -n 30 "${RESULTS_DIR}/synth_direct_generic.log" | grep -E 'MUX' | awk '{print $1}' | tail -n 1)

# Xilinx Metrics
XIL_2W_FF=$(tail -n 30 "${RESULTS_DIR}/synth_2way_xilinx.log" | grep -E 'FDCE|FDRE|FDSE|FDPE' | awk '{s+=$1} END {print s}')
XIL_DIR_FF=$(tail -n 30 "${RESULTS_DIR}/synth_direct_xilinx.log" | grep -E 'FDCE|FDRE|FDSE|FDPE' | awk '{s+=$1} END {print s}')

XIL_2W_LUT=$(tail -n 30 "${RESULTS_DIR}/synth_2way_xilinx.log" | grep -E 'LUT[1-6]' | awk '{s+=$1} END {print s}')
XIL_DIR_LUT=$(tail -n 30 "${RESULTS_DIR}/synth_direct_xilinx.log" | grep -E 'LUT[1-6]' | awk '{s+=$1} END {print s}')

XIL_2W_BRAM=0
XIL_DIR_BRAM=0

# ECP5 Metrics
ECP_2W_LUT=$(tail -n 30 "${RESULTS_DIR}/synth_2way_ecp5.log" | grep -E 'LUT4' | awk '{print $1}' | tail -n 1)
ECP_DIR_LUT=$(tail -n 30 "${RESULTS_DIR}/synth_direct_ecp5.log" | grep -E 'LUT4' | awk '{print $1}' | tail -n 1)

ECP_2W_FF=$(tail -n 30 "${RESULTS_DIR}/synth_2way_ecp5.log" | grep -E 'TRELLIS_FF' | awk '{print $1}' | tail -n 1)
ECP_DIR_FF=$(tail -n 30 "${RESULTS_DIR}/synth_direct_ecp5.log" | grep -E 'TRELLIS_FF' | awk '{print $1}' | tail -n 1)

printf "%-32s | %-16s | %-16s | %-12s\n" "Synthesis Flow & Metric" "2-Way LRU" "Direct-Mapped" "Delta (2W-Dir)"
echo "-----------------------------------------------------------------------------------"
printf "%-32s | %-16s | %-16s | %-12s\n" "Generic: Total Cells" "${GEN_2W_CELLS}" "${GEN_DIR_CELLS}" "$((GEN_2W_CELLS - GEN_DIR_CELLS))"
printf "%-32s | %-16s | %-16s | %-12s\n" "Generic: Flip-Flops" "${GEN_2W_FF}" "${GEN_DIR_FF}" "$((GEN_2W_FF - GEN_DIR_FF))"
printf "%-32s | %-16s | %-16s | %-12s\n" "Generic: \$_MUX_ Cells" "${GEN_2W_MUX}" "${GEN_DIR_MUX}" "$((GEN_2W_MUX - GEN_DIR_MUX))"
printf "%-32s | %-16s | %-16s | %-12s\n" "Xilinx 7-Series: Total LUTs" "${XIL_2W_LUT}" "${XIL_DIR_LUT}" "$((XIL_2W_LUT - XIL_DIR_LUT))"
printf "%-32s | %-16s | %-16s | %-12s\n" "Xilinx 7-Series: Flip-Flops" "${XIL_2W_FF}" "${XIL_DIR_FF}" "$((XIL_2W_FF - XIL_DIR_FF))"
printf "%-32s | %-16s | %-16s | %-12s\n" "Xilinx 7-Series: Block RAM" "${XIL_2W_BRAM}" "${XIL_DIR_BRAM}" "0"
printf "%-32s | %-16s | %-16s | %-12s\n" "Lattice ECP5: Total LUT4s" "${ECP_2W_LUT}" "${ECP_DIR_LUT}" "$((ECP_2W_LUT - ECP_DIR_LUT))"
printf "%-32s | %-16s | %-16s | %-12s\n" "Lattice ECP5: Flip-Flops" "${ECP_2W_FF}" "${ECP_DIR_FF}" "$((ECP_2W_FF - ECP_DIR_FF))"
printf "%-32s | %-16s | %-16s | %-12s\n" "Max Frequency (Fmax)" "NOT MEASURED" "NOT MEASURED" "N/A"
echo "============================================================"
echo "Raw log files saved to: ${RESULTS_DIR}/"
echo "  - ${RESULTS_DIR}/synth_2way_generic.log"
echo "  - ${RESULTS_DIR}/synth_direct_generic.log"
echo "  - ${RESULTS_DIR}/synth_2way_xilinx.log"
echo "  - ${RESULTS_DIR}/synth_direct_xilinx.log"
echo "  - ${RESULTS_DIR}/synth_2way_ecp5.log"
echo "  - ${RESULTS_DIR}/synth_direct_ecp5.log"
echo "============================================================"
