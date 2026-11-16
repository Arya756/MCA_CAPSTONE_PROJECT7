# Hardware Synthesis & Resource Utilization Evaluation

**Course / Project:** Project 7 – Cache Memory Subsystem Design (Phase I)  
**Author / Owner:** Member 5 (Report, Diagrams, Synthesis, Video)  
**Date:** November 16, 2026  
**Target Designs:** `rtl/cache_2way_lru.v` and `rtl/cache_direct.v`  

---

## 1. Synthesis Setup and Execution Commands

Synthesis is driven via the Yosys Open SYnthesis Suite using generic technology elaboration commands specified in `results/yosys_cmd.txt`:

```bash
# Synthesize 2-Way Set-Associative Cache
yosys -l results/yosys_2way.txt -p "read_verilog -sv rtl/cache_2way_lru.v; synth -top cache_2way_lru; stat"

# Synthesize Direct-Mapped Cache Baseline
yosys -l results/yosys_direct.txt -p "read_verilog -sv rtl/cache_direct.v; synth -top cache_direct; stat"
```

### Tool Installation Note
On the current evaluation machine, `yosys` was not pre-installed. To install and run synthesis on fresh environments:
* **macOS (Homebrew):** `brew install yosys`
* **Ubuntu / Debian Linux:** `sudo apt-get install yosys`

---

## 2. Architectural Resource Analysis & Storage Array Domination

When synthesized under generic Yosys RTL synthesis (`synth`), both cache designs exhibit characteristic cell and register footprints dictated by their behavioral memory modeling:

### Storage Array Register Allocation
In both RTL implementations (`rtl/cache_2way_lru.v` and `rtl/cache_direct.v`), the cache storage structures are coded as behavioral multi-dimensional register arrays (`reg [...] data [...]`, `reg [...] tag [...]`, `reg valid [...]`):
* **Direct-Mapped Cache (`cache_direct`):**
  - Data storage: 64 lines × 16 bytes/line × 8 bits = 8,192 flip-flop bits
  - Tag storage: 64 lines × 22 tag bits = 1,408 flip-flop bits
  - Valid storage: 64 lines × 1 valid bit = 64 flip-flop bits
  - **Total Architectural Storage Bits:** 9,664 register bits
* **2-Way Set-Associative Cache (`cache_2way_lru`):**
  - Data storage: 32 sets × 2 ways × 16 bytes × 8 bits = 8,192 flip-flop bits
  - Tag storage: 32 sets × 2 ways × 23 tag bits = 1,472 flip-flop bits (+64 tag bits due to 23b vs 22b tag width)
  - Valid storage: 32 sets × 2 ways × 1 valid bit = 64 flip-flop bits
  - LRU replacement storage: 32 sets × 1 LRU bit = 32 flip-flop bits
  - **Total Architectural Storage Bits:** 9,760 register bits (+96 bits vs direct-mapped)

### Important Caveat on Generic Synthesis Numbers
1. **Flip-Flop Domination:** Because the RTL infers flip-flops rather than technology-specific SRAM macros or FPGA Block RAMs (BRAM), the generic flip-flop and DFF cell count in both designs is overwhelmingly dominated by the 1 KB data array (~8,192 registers) and tag/valid storage.
2. **Logic & Multiplexing Delta:** The true hardware cost of 2-way associativity resides in the combinational logic:
   - Two parallel 23-bit tag comparators (`hit0`, `hit1`) vs one 22-bit comparator.
   - Hit-way multiplexers routing 128-bit cache line data.
   - Victim selection priority logic (`!valid0 ? Way0 : (!valid1 ? Way1 : lru)`).
   - 1-bit per set True LRU update logic (`lru <= ~hit_way` on hit, `lru <= ~victim_way` on refill).
3. **No FPGA / ASIC Timing Figures:** Yosys generic elaboration produces generic cell statistics (e.g., `$_DFF_*`, `$_MUX_`, `$_AND_`, `$_OR_`). It does **not** map to target FPGA LUTs/BRAMs or standard-cell ASIC libraries, and therefore does **not** provide maximum clock frequency ($F_{\max}$), setup/hold slack, or critical path wire delays.
4. **FPGA / Vivado Status:** Vivado implementation numbers (LUT count, BRAM utilization, and post-routing $F_{\max}$) were not collected in Phase I; this is planned for Phase II hardware prototyping.
