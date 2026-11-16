# Hardware Synthesis & Resource Utilization Evaluation

**Course / Project:** Project 7 – Cache Memory Subsystem Design (Phase I)  
**Author / Owner:** Member 5 (Report, Diagrams, Synthesis, Video Lead)  
**Date:** November 16, 2026  
**Target Designs:** `rtl/cache_2way_lru.v` and `rtl/cache_direct.v`  
**Tool Used:** Yosys Open SYnthesis Suite (v0.71)  

---

## 1. Synthesis Execution Commands

Synthesis was performed directly using the technology elaboration and mapping script from `results/yosys_cmd.txt`:

```bash
# Synthesize 2-Way Set-Associative Cache (cache_2way_lru)
yosys -l results/yosys_2way.txt -p "read_verilog -sv rtl/cache_2way_lru.v; synth -top cache_2way_lru; stat"

# Synthesize Direct-Mapped Cache Baseline (cache_direct)
yosys -l results/yosys_direct.txt -p "read_verilog -sv rtl/cache_direct.v; synth -top cache_direct; stat"
```

The full raw execution logs are saved in:
* [`results/yosys_2way.txt`](yosys_2way.txt)
* [`results/yosys_direct.txt`](yosys_direct.txt)

---

## 2. Synthesis Results Summary

The table below summarizes the extracted gate-level cell, register, and wire statistics:

| Metric | 2-Way Set-Associative (`cache_2way_lru`) | Direct-Mapped Baseline (`cache_direct`) | Delta (2-Way vs Direct) | Architectural Explanation |
|---|:---:|:---:|:---:|---|
| **Total Cells** | **35,630** | **39,780** | -4,150 cells (-10.4%) | Direct-mapped synthesizes larger decoding logic trees for 64 lines vs 32 sets |
| **Total Flip-Flops** | **10,120** | **10,024** | **+96 flip-flops (+1.0%)** | **Exactly matches architectural storage delta: +64 tag bits + 32 LRU bits** |
| - `$_DFFE_PP0P_` | 10,023 | 9,927 | +96 | Storage arrays with clock-enable and asynchronous reset |
| - `$_DFFE_PP_` | 96 | 96 | 0 | Performance counters (`hit_count`, `miss_count`, `cycle_count`) |
| - `$_DFF_PP0_` | 1 | 1 | 0 | CPU ready strobe registered pulse |
| **Logic Cells (Gates)** | 25,510 | 29,756 | -4,246 | Combinational logic for muxes, decoders, and comparators |
| - `$_AND_` | 14,485 | 13,723 | +762 | Tag equality comparison & write-enable decoding |
| - `$_MUX_` | 4,349 | 8,411 | -4,062 | 64-line word multiplexer tree in direct vs 32-set 2-way |
| - `$_NOR_` | 4,989 | 5,223 | -234 | Control logic and address decoding |
| - `$_ANDNOT_` | 966 | 1,648 | -682 | Masking and state decoding |
| - `$_OR_` | 339 | 406 | -67 | Hit OR gate (`hit = hit0 \|\| hit1`) and status flags |
| - `$_NAND_` / `$_XOR_` | 270 | 192 | +78 | Tag comparator XOR gates |
| **Total Wires** | 23,649 | 25,932 | -2,283 | Interconnect routing nets |
| **Total Wire Bits** | 35,861 | 40,010 | -4,149 | Bit-level net expansion |
| **Public Wires** | 448 | 412 | +36 | Additional internal signals for 2 ways |
| **Public Wire Bits** | 10,256 | 10,156 | +100 | Port and internal vector width |

---

## 3. Analysis & Key Takeaways

1. **Exact Storage Delta Verification:**
   - Architectural storage derivation:
     - Direct-Mapped: $(64 \times 128\text{ data}) + (64 \times 22\text{ tag}) + (64 \times 1\text{ valid}) = 9,664\text{ bits}$.
     - 2-Way LRU: $(32 \times 2 \times 128\text{ data}) + (32 \times 2 \times 23\text{ tag}) + 64\text{ valid} + 32\text{ LRU} = 9,760\text{ bits}$.
     - Delta = **+96 bits**.
   - Synthesized Flip-Flops: **10,120 vs 10,024 = exactly +96 DFFs!** This confirms complete mathematical and microarchitectural parity.
2. **Flip-Flop Domination:**
   Because both designs model memory arrays behaviorally using multi-dimensional `reg` arrays rather than dedicated SRAM macros or FPGA Block RAMs (BRAM), the flip-flop count in both designs is dominated by the 1 KB data store (~8,192 flip-flops) and tag arrays.
3. **No FPGA / Physical Timing Figures in Phase I:**
   Generic Yosys elaboration outputs cell counts for standard logic primitives. It does not perform physical placement or routing against an FPGA target (e.g. AMD Xilinx Artix-7). Therefore, physical clock frequency ($F_{\max}$), setup/hold slack, and LUT/BRAM numbers are not available for Phase I and are reserved for Phase II Vivado deployment.
