# Section IV.D: Hardware Synthesis & Resource Utilization

**Course:** MCA Capstone Design - Advanced Computer Architecture  
**Project:** Project 7 – 2-Way Set-Associative Cache with LRU vs Direct-Mapped Baseline  
**Author:** Member 1 (2-Way Cache RTL & Synthesis/Resource Report)  
**Issue:** Closes #12  
**Date:** November 23, 2026  

---

## 1. Hardware Resource Comparison

To evaluate the physical silicon trade-offs between a 2-way set-associative cache and a direct-mapped baseline of identical 1 KB data capacity, both architectures were synthesized using the Yosys Open SYnthesis Suite (v0.71). Synthesis was performed directly on the cache modules (`cache_2way_lru` and `cache_direct`) using three distinct mapping passes:
1. **Generic Technology-Independent Synthesis** (`synth -top <module>; stat`)
2. **AMD/Xilinx 7-Series FPGA Mapping** (`synth_xilinx -top <module>; stat`)
3. **Lattice ECP5 FPGA Mapping** (`synth_ecp5 -top <module>; stat`)

The table below summarizes the key hardware metrics across both architectures:

### Table IV.1: Hardware Resource Utilization Comparison

| Synthesis Flow / Technology | Metric | 2-Way Set-Associative (`cache_2way_lru`) | Direct-Mapped Baseline (`cache_direct`) | Architectural Delta (2-Way − Direct) | Primary Cause of Difference |
| :--- | :--- | :---: | :---: | :---: | :--- |
| **Generic Synthesis** | Total Cells | 35,643 | 39,809 | -4,166 (-10.5%) | Direct-mapped synthesizes larger line multiplexing trees |
| *(Yosys 0.71)* | Flip-Flops | 10,122 | 10,026 | **+96 (+1.0%)** | **+64 tag bits and +32 true LRU replacement bits** |
| | Multiplexers (`$_MUX_`) | 4,346 | 8,410 | -4,064 (-48.3%) | 64-line word selection in direct vs 32-set selection in 2-way |
| | Logic Gates (AND/NOR/etc.) | 21,175 | 21,373 | -198 | Two tag comparators vs deeper address decoding |
| **AMD/Xilinx 7-Series** | Total LUTs (LUT2–LUT6) | 6,699 | 9,352 | -2,653 (-28.4%) | Direct-mapped requires 5,319 LUT5s for 64-to-1 word muxing |
| *(Yosys synth_xilinx)* | Flip-Flops (FDCE/FDRE) | 10,122 | 10,026 | **+96 (+1.0%)** | Storage array register difference (+64 tags, +32 LRU) |
| | Block RAM (RAMB18/36) | 0 | 0 | 0 | Storage arrays read combinationally (mapped to registers) |
| | Dedicated Muxes (MUXF7/F8) | 264 | 756 | -492 (-65.1%) | Dedicated slice muxes used for line data selection |
| **Lattice ECP5** | Total LUT4s | 14,807 | 18,541 | -3,734 (-20.1%) | Direct-mapped 64-line multiplexing tree expansion |
| *(Yosys synth_ecp5)* | Flip-Flops (TRELLIS_FF) | 10,122 | 10,026 | **+96 (+1.0%)** | Microarchitectural storage delta |
| | Block RAM (DP16KD) | 0 | 0 | 0 | Asynchronous read ports prevent BRAM inference |
| **Physical Timing** | Maximum Frequency ($F_{\max}$) | **NOT MEASURED** | **NOT MEASURED** | N/A | No physical P&R; see limitations below |

---

## 2. Analysis of Hardware Overhead and Area Trade-Offs

### A. The True Cost of Associativity (+96 Storage Bits)
A set-associative cache requires extra hardware to locate and replace data within a set. The synthesis results mathematically confirm where this extra cost originates:
1. **Tag Storage Difference (+64 bits):**
   - The direct-mapped cache has 64 lines, requiring 6 index bits ($2^6 = 64$) and 22 tag bits per line ($32 - 6 - 4 = 22\text{ bits}$). Total tag storage is $64 \times 22 = 1,408\text{ bits}$.
   - The 2-way cache has 32 sets of 2 lines each, requiring 5 index bits ($2^5 = 32$) and 23 tag bits per line ($32 - 5 - 4 = 23\text{ bits}$). Total tag storage is $64 \times 23 = 1,472\text{ bits}$.
   - The 2-way cache requires $1,472 - 1,408 = \mathbf{+64\text{ tag bits}}$.
2. **Replacement State (+32 bits):**
   - The 2-way cache tracks recency with 1 true LRU bit per set ($32 \times 1 = \mathbf{+32\text{ LRU bits}}$).
   - Direct-mapped requires zero replacement bits because each address maps to exactly one line.
3. **Total Flip-Flop Delta:**
   $$64\text{ (tag bits)} + 32\text{ (LRU bits)} = \mathbf{+96\text{ flip-flops}}$$
   Across all synthesis flows (Generic, Xilinx, and ECP5), the synthesized register count shows **exactly 10,122 vs 10,026 flip-flops (+96 registers)**. This confirms microarchitectural equivalence and exact mathematical parity.

### B. Two Tag Comparators and Hit Selection Logic
In addition to register storage, the 2-way cache evaluates two 23-bit tags in parallel on every clock cycle:
- Tag match logic: `hit0 = valid0[req_index] && (tag0[req_index] == req_tag)` and `hit1 = valid1[req_index] && (tag1[req_index] == req_tag)`.
- This requires two 23-bit equality comparators and an OR gate (`hit = hit0 || hit1`), as well as a 2-to-1 data multiplexer to route the winning way's word to the CPU (`cpu_rdata <= (hit_way) ? data1 : data0`).
- This extra logic is visible in Table IV.1 as an increase in small LUTs (+420 `LUT4` cells in Xilinx mapping and +745 `$_AND_` cells in generic mapping).

### C. Why Cell and LUT Counts Are Higher in Direct-Mapped
Table IV.1 reveals that the direct-mapped cache synthesizes into **more total cells and more LUTs** than the 2-way cache (-4,166 generic cells and -2,653 Xilinx LUTs for 2-way).
- **The Multiplexer Tree Effect:** When the CPU reads a 32-bit word from cache, the direct-mapped architecture must multiplex 1 out of 64 lines (a 64-to-1 32-bit multiplexer). The 2-way cache only multiplexes 1 out of 32 sets (a 32-to-1 32-bit multiplexer per way), followed by a simple 2-to-1 way hit multiplexer.
- In modern FPGA architectures, a 64-to-1 multiplexer expands into multiple cascaded levels of 5-input/6-input LUTs and dedicated multiplexers (`MUXF7` and `MUXF8`). The direct-mapped design requires **5,319 LUT5s** compared to **2,487 LUT5s** in 2-way, and **756 dedicated muxes** compared to **264**.
- **Important Takeaway:** Cell and LUT counts alone do not indicate which architecture has higher silicon cost. The direct-mapped cache incurs higher multiplexing cost, whereas the 2-way cache incurs higher comparison, state tracking, and routing complexity.

### D. Performance Counters Normalization
Both modules include three 32-bit performance counters (`hit_count`, `miss_count`, `cycle_count`) for benchmark profiling. In Xilinx mapping, these account for exactly **96 `FDRE` registers** and **25 `CARRY4` carry logic units** in both designs. Because both designs instantiate identical counters, their presence introduces zero relative bias.

---

## 3. Speed, Area, and Access Time Implications

- **Hit Latency Invariance:** Both the 2-way cache and the direct-mapped baseline complete a read hit in exactly **2 clock cycles** (`STATE_IDLE` request decode $\rightarrow$ `STATE_LOOKUP` tag match & data register commit).
- **Area vs Locality Benefit:** The 2-way cache costs +96 flip-flops and two parallel comparators. In return, as demonstrated in our workload evaluations, it completely eliminates conflict misses on pathological address sequences (`pingpong`: 99.00% hit rate in 2-way vs 0.00% in direct-mapped).
- **Average Memory Access Time (AMAT):** For detailed analytical cycle derivations, latency sweeps ($RD\_LAT$, $WR\_LAT$), and AMAT comparisons, see Member 3's section (*Section IV.B / `docs/MEMBER3_PHASE2_RESULTS.md`*).

---

## 4. Engineering Limitations & Threats to Validity

To maintain empirical honesty, the following constraints of this hardware evaluation must be noted:
1. **Generic Technology Mapping:** All reported metrics were produced via open-source Yosys synthesis. They reflect logical gate and FPGA cell allocations rather than post-route ASIC layout or physical silicon area.
2. **Distributed Register Storage (No Block RAM):** Both cache designs use combinational (asynchronous) read paths to achieve single-cycle data return during `STATE_LOOKUP`. Because commercial FPGA Block RAMs (e.g., AMD Xilinx `RAMB18E1`/`RAMB36E1` or Lattice `DP16KD`) require synchronous registered addresses (1-cycle read latency), Yosys cannot infer Block RAM. All 1 KB of user data and tags are mapped to discrete flip-flops (~10,000 registers).
3. **No Physical Place-and-Route Frequency ($F_{\max}$ NOT MEASURED):** Attempting out-of-context physical placement and routing (`nextpnr-ecp5` / Vivado) on an unconstrained design with >10,000 discrete flip-flops and 296 I/O ports leads to severe routing channel exhaustion (>70,000 nets). Reliable physical clock frequencies can only be extracted by integrating the cache into an SoC wrapper or converting the arrays to synchronous Block RAM.
4. **No Silicon Board Testing:** The designs were fully verified through cycle-accurate simulation (Icarus Verilog) and logic synthesis (Yosys); physical bitstream generation on an FPGA evaluation board (e.g., Digilent Basys3) was not conducted.
