# Hardware Synthesis & Resource Utilization Report (Phase II)

**Project:** Project 7 – 2-Way Set-Associative Cache with LRU vs Direct-Mapped Baseline  
**Course:** MCA Capstone Design - Advanced Computer Architecture  
**Owner:** Member 1 (2-Way Cache RTL & Synthesis/Resource Report)  
**Issue:** Closes #12  
**Date:** November 23, 2026  
**Tools Used:** Yosys Open SYnthesis Suite (v0.71+post)  
**Target Designs:** `rtl/cache_2way_lru.v` (`cache_2way_lru`) and `rtl/cache_direct.v` (`cache_direct`)  
**Reproduction Script:** `./scripts/synth_all.sh`

---

## 1. Overview & Evaluation Methodology

In accordance with Phase II requirements, both cache modules were synthesized under identical conditions using three distinct synthesis flows:
1. **Generic Technology-Independent Elaboration:** Evaluates architectural gate-level complexity (multiplexers, logic gates, and registers) independent of target silicon.
2. **AMD/Xilinx 7-Series FPGA Technology Mapping:** Maps logic to Xilinx 7-Series primitive cells (LUT2–LUT6, FDCE/FDRE, MUXF7/F8, CARRY4, and Block RAM).
3. **Lattice ECP5 FPGA Technology Mapping:** Maps logic to ECP5 architecture slices (LUT4, TRELLIS_FF, PFUMX, L6MUX21, CCU2C, and DP16KD BRAM).

> **Important Rule on Device Comparisons:** Numbers from different target device families are separated into dedicated tables below and are never mixed in a single row.

---

## 2. Synthesis Results by Target Architecture

### Table 1: Generic Technology-Independent Synthesis
*Command: `yosys -p "read_verilog -sv <source>; synth -top <module>; stat"`*  
*Raw Logs: `results/synth_2way_generic.log`, `results/synth_direct_generic.log`*

| Metric | 2-Way LRU (`cache_2way_lru`) | Direct-Mapped (`cache_direct`) | Delta (2-Way − Direct) | Architectural Explanation |
| :--- | :---: | :---: | :---: | :--- |
| **Total Cells** | **35,643** | **39,809** | **-4,166 (-10.5%)** | Direct-mapped requires deeper multiplexer trees for 64 lines vs 32 sets |
| **Total Flip-Flops** | **10,122** | **10,026** | **+96 (+1.0%)** | **Exact architectural storage delta: +64 tag bits + 32 LRU bits** |
| - `$_DFFE_PP0P_` | 10,025 | 9,929 | +96 | Storage arrays (valid, tag, data, LRU) with clock-enable & async reset |
| - `$_DFFE_PP_` | 96 | 96 | 0 | Three 32-bit performance counters (`hit_count`, `miss_count`, `cycle_count`) |
| - `$_DFF_PP0_` | 1 | 1 | 0 | CPU ready strobe registered pulse |
| **Multiplexers (`$_MUX_`)**| **4,346** | **8,410** | **-4,064 (-48.3%)** | Direct-mapped 64-to-1 word mux tree requires nearly 2× multiplexer primitives |
| **Logic Cells (Gates)** | **21,175** | **21,373** | **-198** | Combinational gating, decoders, and comparators |
| - `$_AND_` | 14,491 | 13,746 | +745 | Two parallel tag comparators and hit-routing gates in 2-way |
| - `$_NOR_` | 4,992 | 5,209 | -217 | Control logic and address decoding |
| - `$_ANDNOT_` | 969 | 1,646 | -677 | Bit-masking and line decoding |
| - `$_OR_` | 341 | 405 | -64 | Hit detection OR gate (`hit0 \|\| hit1`) and status flags |
| - `$_NAND_` | 156 | 83 | +73 | Tag equality comparison gating |
| - `$_XOR_` / `$_XNOR_` | 126 | 99 | +27 | Tag comparator bitwise XOR gates |
| - `$_NOT_` / `$_ORNOT_` | 100 | 185 | -85 | Inversion and polarity logic |
| **Total Wires** | 23,658 | 25,957 | -2,299 | Interconnect nets |
| **Total Wire Bits** | 35,876 | 40,041 | -4,165 | Expanded bit-level nets |

---

### Table 2: AMD/Xilinx 7-Series FPGA Technology Mapping
*Command: `yosys -p "read_verilog -sv <source>; synth_xilinx -top <module>; stat"`*  
*Raw Logs: `results/synth_2way_xilinx.log`, `results/synth_direct_xilinx.log`*

| Metric | 2-Way LRU (`cache_2way_lru`) | Direct-Mapped (`cache_direct`) | Delta (2-Way − Direct) | Architectural Explanation |
| :--- | :---: | :---: | :---: | :--- |
| **Total Cells** | **17,411** | **20,460** | **-3,049 (-14.9%)** | Direct-mapped synthesizes larger multiplexer trees |
| **Total LUTs (LUT2–LUT6)** | **6,699** | **9,352** | **-2,653 (-28.4%)** | Direct-mapped consumes 2,832 extra LUT5s for 64-line word selection |
| - `LUT2` | 190 | 164 | +26 | Small combinational gates |
| - `LUT3` | 259 | 190 | +69 | FSM decoding and control |
| - `LUT4` | 938 | 518 | +420 | Parallel tag comparators and victim selection logic |
| - `LUT5` | 2,487 | 5,319 | -2,832 | 64-line multiplexer trees in direct-mapped expand into LUT5 banks |
| - `LUT6` | 2,825 | 3,161 | -336 | Wider data selection and line decoders |
| **Total Flip-Flops** | **10,122** | **10,026** | **+96 (+1.0%)** | **Exactly +96 flip-flops (+64 tag bits + 32 LRU bits)** |
| - `FDCE` | 10,026 | 9,930 | +96 | Storage arrays mapped to discrete FFs due to combinational reads |
| - `FDRE` | 96 | 96 | 0 | Three 32-bit performance counters in both modules |
| **Dedicated Mux Primitives** | | | | Dedicated slice multiplexers used for line data selection |
| - `MUXF7` | 190 | 504 | -314 | Hardware 7-input mux primitives |
| - `MUXF8` | 74 | 252 | -178 | Hardware 8-input mux primitives |
| **Carry Chains (`CARRY4`)** | 25 | 25 | 0 | 32-bit counter incrementers in both modules |
| **Block RAM (`RAMB18`/`36`)** | **0** | **0** | **0** | **0 BRAM inferred: combinational reads require register storage** |
| **Distributed RAM (`LUTRAM`)**| **0** | **0** | **0** | Memory arrays synthesized to discrete flip-flops |

---

### Table 3: Lattice ECP5 FPGA Technology Mapping
*Command: `yosys -p "read_verilog -sv <source>; synth_ecp5 -top <module>; stat"`*  
*Raw Logs: `results/synth_2way_ecp5.log`, `results/synth_direct_ecp5.log`*

| Metric | 2-Way LRU (`cache_2way_lru`) | Direct-Mapped (`cache_direct`) | Delta (2-Way − Direct) | Architectural Explanation |
| :--- | :---: | :---: | :---: | :--- |
| **Total Cells** | **30,296** | **35,466** | **-5,170 (-14.6%)** | Direct-mapped consumes more LUT4s and slice multiplexers |
| **LUT4** | **14,807** | **18,541** | **-3,734 (-20.1%)** | Direct-mapped 64-line multiplexer consumes extra 4-input LUTs |
| **Total Flip-Flops (`TRELLIS_FF`)**| **10,122** | **10,026** | **+96 (+1.0%)** | Storage arrays mapped to discrete TRELLIS_FF registers |
| **PFUMX (Slice Muxes)** | 4,502 | 6,165 | -1,663 | ECP5 slice multiplexer primitives |
| **L6MUX21 (Wide Muxes)** | 817 | 686 | +131 | Wide multiplexing for 2-way hit selection |
| **CCU2C (Carry Units)** | 48 | 48 | 0 | 32-bit counter arithmetic in both modules |
| **Block RAM (`DP16KD`)** | **0** | **0** | **0** | **0 BRAM inferred due to combinational read architecture** |

---

### Table 4: Maximum Clock Frequency ($F_{\max}$)
*Physical Placement & Routing (P&R) Evaluation*

| Metric | 2-Way LRU (`cache_2way_lru`) | Direct-Mapped (`cache_direct`) | Status / Justification |
| :--- | :---: | :---: | :--- |
| **Maximum Frequency ($F_{\max}$)** | **NOT MEASURED** | **NOT MEASURED** | **No Place-and-Route (P&R).** Because storage arrays synthesize to >10,000 discrete flip-flops, out-of-context P&R on 296 unconstrained I/O pins exhaustively congests routing channels (>70,000 nets). Reliable post-route physical $F_{\max}$ requires full vendor SoC integration in Vivado/Quartus or a synchronous BRAM architecture. |

---

## 3. Microarchitectural Cost Analysis

### A. Origin of the 2-Way Cache's Extra Hardware Cost
The synthesis logs strictly support and verify the origin of the 2-Way cache's extra hardware:
1. **Storage Array Delta (+96 Flip-Flops):**
   - Direct-Mapped Storage: $(64 \text{ lines} \times 128\text{ data bits}) + (64 \times 22\text{ tag bits}) + (64 \times 1\text{ valid bit}) = 9,664\text{ bits}$.
   - 2-Way LRU Storage: $(32 \text{ sets} \times 2 \times 128\text{ data bits}) + (32 \times 2 \times 23\text{ tag bits}) + 64\text{ valid bits} + 32\text{ LRU bits} = 9,760\text{ bits}$.
   - Exact Architectural Storage Delta: $9,760 - 9,664 = \mathbf{+96\text{ bits}}$ (+64 tag bits and +32 true LRU bits).
   - Across **all three synthesis flows**, the synthesized flip-flop count shows **exactly +96 registers** (10,122 vs 10,026), proving 100% mathematical and microarchitectural parity.
2. **Two Parallel Tag Comparators:**
   - 2-Way requires evaluating two 23-bit tag comparators simultaneously (`hit0` and `hit1`), evidenced by +745 `$_AND_` and +23 `$_XOR_` cells in generic synthesis, and +420 `LUT4` cells in Xilinx mapping.
3. **Hit Multiplexer & LRU Update Logic:**
   - 2-Way requires a final 2-to-1 hit-way multiplexer to select the winning way (`cpu_rdata <= (hit_way) ? data1 : data0`), plus LRU flip-flop toggle logic (`lru[req_index] <= ~hit_way`).

### B. Why Direct-Mapped Has More Total Cells and LUTs
A common naive assumption is that a 2-way cache must always synthesize into more total logic cells than a direct-mapped cache. The synthesis logs disprove this assumption:
- In Direct-Mapped cache, reading a 32-bit word from the 64 lines requires a **64-to-1 word multiplexer tree** (6 index bits to select 1 line out of 64).
- In 2-Way cache, reading a word only requires a **32-to-1 word multiplexer tree** per way (5 index bits to select 1 set out of 32), followed by a 2-to-1 hit mux.
- In FPGA architectures, wide multiplexers expand into deep trees of `LUT5`/`LUT6` and dedicated `MUXF7`/`MUXF8` primitives. Direct-mapped requires **5,319 LUT5s** vs **2,487 LUT5s** in 2-way (+2,832 LUT5s), and **504 MUXF7 / 252 MUXF8** vs **190 MUXF7 / 74 MUXF8**.
- **Key Takeaway:** Raw cell/LUT counts alone do not show which design "costs more" in silicon. The direct-mapped design incurs larger multiplexer overhead for line selection, whereas the 2-way design incurs wider tag comparison and state update logic.

### C. Performance Counters Impact
Both modules include three 32-bit performance counters (`hit_count`, `miss_count`, `cycle_count`). In Xilinx mapping, these account for:
- Exactly **96 `FDRE` flip-flops** ($3 \times 32$) in both modules.
- Exactly **25 `CARRY4` arithmetic carry units** in both modules.
Because these counters are identical across both modules, they add zero bias to the comparison.

---

## 4. Difference from Phase I Logs (`results/yosys_summary.md`)

For tracking purposes and report updates by Member 5:
- **Phase I Counts:** 2-Way = 10,120 FFs; Direct = 10,024 FFs (Delta = +96 FFs). Total cells: 35,630 vs 39,780.
- **Phase II Counts:** 2-Way = 10,122 FFs; Direct = 10,026 FFs (Delta = +96 FFs). Total cells: 35,643 vs 39,809.
- **Explanation of +2 FF Difference:** In Phase II, Member 3 parameterized the cache capacities and block sizes using dynamic `$clog2` calculations, adding a 4-bit refill burst counter register (`refill_count`) in place of a fixed 2-bit counter. Both modules gained exactly 2 flip-flops. The relative storage delta (+96 FFs) remains completely identical.

---

## 5. Engineering Limitations

1. **Generic & Out-of-Context Synthesis:** All numbers were produced via open-source Yosys technology synthesis. They do not represent post-place-and-route ASIC silicon area or FPGA layout.
2. **Distributed Register Storage (0 BRAM):** Both designs implement combinational (asynchronous) read paths. Standard FPGA Block RAMs (Xilinx RAMB18/36 or ECP5 DP16KD) require registered (synchronous) read addresses. Consequently, all 1 KB of cache data is mapped to discrete flip-flops, causing high register utilization (~10,000 registers).
3. **No Physical Fmax ($F_{\max}$ NOT MEASURED):** Physical placement and routing of over 10,000 discrete flip-flops with 296 unconstrained I/O pins out-of-context causes routing channel exhaustion in open-source P&R tools. Accurate physical clock frequency requires an in-system SoC harness or vendor EDA flow (Vivado/Quartus).
4. **No Hardware Board Test:** Verification was conducted via cycle-accurate RTL simulation and technology synthesis; physical FPGA bitstream programming was not performed.
