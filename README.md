# Project 7: 2-Way Set-Associative Cache with LRU vs Direct-Mapped Cache

[![Verilog HDL](https://img.shields.io/badge/Language-Verilog%20HDL-blue.svg)](https://en.wikipedia.org/wiki/Verilog)
[![Toolchain](https://img.shields.io/badge/Simulation-Icarus%20Verilog%20%7C%20GTKWave-brightgreen.svg)](http://iverilog.icarus.com/)
[![Synthesis](https://img.shields.io/badge/Synthesis-Yosys%20Open%20Synthesis-orange.svg)](https://yosyshq.net/yosys/)
[![Regression](https://img.shields.io/badge/Regression-PASS%20%7C%200%20Mismatches-success.svg)](scripts/run_all.sh)

A complete, self-contained hardware evaluation kit designed and modeled in synthesizable Verilog HDL. This project implements, verifies, synthesizes, and benchmarks a **1 KB 2-Way Set-Associative L1 Data Cache with True LRU Replacement** against an architectural **1 KB Direct-Mapped Baseline Cache**. Both caches operate under an identical **Write-Through, No-Write-Allocate** memory policy to ensure a strictly fair architectural comparison.

---

## Technical Report

- **Final IEEE Technical Report (PDF):** [`docs/report/Project7_Final_Report.pdf`](docs/report/Project7_Final_Report.pdf) (compiled from IEEEtran LaTeX source in [`docs/report/main.tex`](docs/report/main.tex))
- **Comprehensive Markdown Report:** [`docs/REPORT_PHASE1.md`](docs/REPORT_PHASE1.md)
- **Overleaf / LaTeX Package:** Available in [`docs/report/`](docs/report/) (contains `main.tex`, `references.bib`, `IEEEtran.cls`)

---

## Team Members & Responsibilities

Reference: [`docs/TEAM_TASKS.md`](docs/TEAM_TASKS.md)

| Member | Role | Primary File Ownership | Deliverables & Tasks |
|---|---|---|---|
| **Member 1** (Lead) | Architecture, RTL & Synthesis | `rtl/cache_2way_lru.v`, `scripts/synth_all.sh` | 2-way RTL, multi-target FPGA synthesis (Generic, Xilinx 7-Series, Lattice ECP5), resource tables (`results/resource_table.md`), waveform guide (`docs/WAVEFORM_GUIDE.md`) |
| **Member 2** | LRU & Multi-Level Verification | `tb/tb_lru_directed.v`, `tb/tb_lru_random.v`, `scripts/run_bug_injection.sh` | True LRU state logic, directed replacement testbench (Steps 1–12), 5,000-cycle pseudo-random co-simulation against software reference model, 4-mutation bug injection |
| **Member 3** | Baseline, Sweeps & AMAT | `rtl/cache_direct.v`, `rtl/main_memory.v`, `scripts/run_sweeps.sh` | Direct-mapped baseline, memory burst protocol, capacity sweeps (512B–2KB), block size sweeps (8B–32B), latency sensitivity, hardware AMAT derivation |
| **Member 4** | Traces, Plots & Automation | `scripts/gen_traces.py`, `tb/tb_compare.v`, `scripts/run_all.sh`, `scripts/plot_results.py` | 11 synthetic evaluation traces, golden memory cross-checking testbench, automated regression runner, hit-rate & cycle comparison bar charts |
| **Member 5** | Final Report & Documentation | `docs/`, `docs/report/`, `README.md` | Final IEEE technical report assembly (LaTeX & Markdown), repository documentation, results cross-validation |

---

## Architectural Comparison Summary

Both caches provide exactly **1024 Bytes (1 KB)** of user data capacity organized into **16-byte blocks** (4 words of 32 bits each).

| Parameter | 2-Way Set-Associative Cache | Direct-Mapped Baseline Cache | Fairness & Rationale |
|---|---|---|---|
| **Data Capacity** | 1024 Bytes (1 KB) | 1024 Bytes (1 KB) | Equal storage capacity |
| **Block Size** | 16 Bytes (4 × 32-bit words) | 16 Bytes (4 × 32-bit words) | Equal spatial granularity |
| **Associativity** | 2 Ways per Set | 1 Way (Direct-Mapped) | Primary design comparison |
| **Sets / Lines** | 32 Sets (`1024 / (16 × 2)`) | 64 Lines (`1024 / 16`) | Determined by associativity |
| **Offset Field** | 4 bits: `addr[3:0]` (`addr[3:2]` word select) | 4 bits: `addr[3:0]` (`addr[3:2]` word select) | Identical block addressing |
| **Index Field** | 5 bits: `addr[8:4]` (32 sets) | 6 bits: `addr[9:4]` (64 lines) | $\log_2(\text{Sets})$ vs $\log_2(\text{Lines})$ |
| **Tag Field** | 23 bits: `addr[31:9]` | 22 bits: `addr[31:10]` | 32 − Index − Offset |
| **Replacement Policy** | True LRU (1 bit per set, `~hit_way`) | Direct replacement (no choice) | Evaluates conflict miss reduction |
| **Write Policy** | Write-Through, No-Write-Allocate | Write-Through, No-Write-Allocate | Strictly identical memory bus traffic |
| **Memory Latency** | 8-cycle read burst, 4-cycle write | 8-cycle read burst, 4-cycle write | Parameterized backing memory interface |

---

## Repository Structure

```
MCA_CAPSTONE_PROJECT7/
├── .gitignore                      # Git ignore rules for build/sim artifacts
├── .mailmap                        # Git contributor attribution mapping
├── README.md                       # Master project overview and execution instructions
├── docs/
│   ├── img/                        # Waveforms, diagrams, and benchmark plots
│   │   ├── block_diagram.png       # Microarchitecture block diagram
│   │   ├── cycles.png              # Execution cycles bar chart
│   │   ├── hit_rate.png            # Hit-rate comparison bar chart
│   │   ├── lru_sequence.png        # LRU 10-step reference state transition diagram
│   │   ├── waveform_hit.png        # 2-cycle read hit GTKWave waveform
│   │   └── waveform_miss.png       # 14-cycle read miss refill waveform
│   ├── BASELINE_AND_MEMORY_MODEL.md# Member 3 memory interface documentation
│   ├── LRU_VERIFICATION.md         # Member 2 directed, random & mutation test notes
│   ├── MEMBER1_EXPLAINER.md        # Member 1 architectural deep dive
│   ├── MEMBER3_PHASE2_RESULTS.md   # Member 3 sweep results and AMAT derivation
│   ├── REPORT_PHASE1.md            # Comprehensive final technical report (Markdown)
│   ├── SECTION_RESOURCES.md        # Member 1 synthesis analysis and limitations
│   ├── TEAM_TASKS.md               # Team task division and ownership breakdown
│   ├── WAVEFORM_GUIDE.md           # GTKWave inspection instructions
│   └── report/                     # IEEEtran LaTeX package and final PDF
│       ├── IEEEtran.cls            # IEEE journal document class
│       ├── main.tex                # Complete IEEEtran LaTeX report source
│       ├── references.bib          # BibTeX bibliography
│       └── Project7_Final_Report.pdf # Final compiled Technical Report PDF
├── results/
│   ├── amat_comparison.csv         # AMAT vs measured cycles validation
│   ├── cycles.png                  # Plot of execution cycles across 11 traces
│   ├── hit_rate.png                # Plot of hit rates across 11 traces
│   ├── latency_sensitivity.csv     # Memory latency sweep results (RD 4/8/16, WR 2/4/8)
│   ├── resource_table.csv          # Multi-target FPGA resource metrics (CSV)
│   ├── resource_table.md           # Hardware synthesis results and analysis (Markdown)
│   ├── results.csv                 # Automated testbench benchmark output (11 traces)
│   ├── sweeps_all.csv              # Capacity and block size sweep master matrix
│   └── yosys_cmd.txt               # Synthesis commands and logs reference
├── rtl/
│   ├── cache_2way_lru.v            # 2-way set-associative cache with True LRU
│   ├── cache_direct.v              # Direct-mapped baseline cache
│   └── main_memory.v               # Parameterized memory model (4-word burst)
├── scripts/
│   ├── gen_traces.py               # Deterministic synthetic trace generator (11 traces)
│   ├── make_block_diagram.py       # Diagram generator script
│   ├── make_lru_diagram.py         # LRU state sequence diagram generator
│   ├── plot_results.py             # Matplotlib benchmark chart generator
│   ├── run_all.sh                  # One-command automated compilation & regression
│   ├── run_bug_injection.sh        # LRU mutation/bug-injection sensitivity runner
│   ├── run_latency_study.sh        # Memory latency sensitivity sweep runner
│   ├── run_sweeps.sh               # Architectural parameter sweep runner (C & B)
│   └── synth_all.sh                # Multi-target FPGA synthesis execution script
├── tb/
│   ├── tb_compare.v                # Side-by-side golden memory verification testbench
│   ├── tb_direct_basic.v           # Direct-mapped baseline self-checking testbench
│   ├── tb_lru_directed.v           # True LRU self-checking directed testbench (12 steps)
│   └── tb_lru_random.v             # 5,000-cycle pseudo-random co-simulation testbench
└── traces/                         # Generated memory trace files (.txt, 11 workloads)
```

---

## Toolchain Setup

### Linux / Ubuntu / Debian / WSL
```bash
sudo apt update
sudo apt install -y iverilog yosys gtkwave python3 python3-matplotlib
```

### macOS (Homebrew)
```bash
brew install icarus-verilog yosys gtkwave python3
pip3 install matplotlib
```

---

## How to Run the Project

### 1. Master Regression Suite (11 Workloads)
Run the complete regression suite with a single command from the project root:

```bash
./scripts/run_all.sh
```

**What this script executes:**
1. Generates all 11 deterministic memory traces in `traces/` via `scripts/gen_traces.py`.
2. Compiles and executes `tb/tb_lru_directed.v`, verifying all 12 directed LRU replacement rules (`LRU test: PASS`).
3. Compiles and executes `tb/tb_direct_basic.v`, verifying direct-mapped functionality and conflict eviction (`DIRECT test: PASS`).
4. Compiles and executes `tb/tb_compare.v` across all 11 traces, verifying **0 data mismatches** against the golden memory model and writing `results/results.csv` (`Compare test: PASS`).
5. Generates publication-quality benchmark charts via `scripts/plot_results.py` saved to `results/hit_rate.png` and `results/cycles.png`.

---

### 2. Multi-Level LRU Verification & Bug Injection
To run the 5,000-cycle pseudo-random co-simulation against the software reference model:

```bash
iverilog -g2012 -o /tmp/rand.vvp rtl/cache_2way_lru.v rtl/main_memory.v tb/tb_lru_random.v && vvp /tmp/rand.vvp
```

To run the mutation testing script that evaluates 4 deliberate RTL mutations against directed and random suites:

```bash
./scripts/run_bug_injection.sh
```
*Expected output: `BUG-INJECTION RESULT: OK (all 4 bugs caught)`.*

---

### 3. Architectural Parameter Sweeps & AMAT
To execute parameter sweeps across capacity ($C \in \{512\text{B}, 1024\text{B}, 2048\text{B}\}$) and block size ($B \in \{8\text{B}, 16\text{B}, 32\text{B}\}$):

```bash
./scripts/run_sweeps.sh
```
*Outputs: `results/sweeps_cache_size.csv`, `results/sweeps_block_size.csv`, and `results/sweeps_all.csv`.*

To run the read ($RD\_LAT \in \{4, 8, 16\}$) and write ($WR\_LAT \in \{2, 4, 8\}$) latency sensitivity sweeps:

```bash
./scripts/run_latency_study.sh
```

---

### 4. Multi-Target FPGA Synthesis
To synthesize both cache architectures across Generic, AMD/Xilinx 7-Series, and Lattice ECP5 FPGA flows:

```bash
./scripts/synth_all.sh
```
*Outputs: `results/resource_table.md`, `results/resource_table.csv`, and raw synthesis logs in `results/synth_*.log`.*

---

## Benchmark Results (11 Traces)

From `results/results.csv` ($RD\_LAT = 8, WR\_LAT = 4$):

| Workload Trace | Accesses | 2-Way Hits | Direct Hits | 2-Way Hit Rate | Direct Hit Rate | 2-Way Cycles | Direct Cycles | Architectural Locality & Behavior |
|---|---|---|---|---|---|---|---|---|
| `seq_stream.txt` | 256 | 192 | 192 | **75.00%** | **75.00%** | 1,280 | 1,280 | Pure spatial locality (4B stride); 1 miss per 4-word block |
| `small_loop.txt` | 640 | 624 | 624 | **97.50%** | **97.50%** | 1,472 | 1,472 | 256B loop fits in 1KB cache; temporal reuse |
| `pingpong.txt` | 200 | 198 | 0 | **99.00%** | **0.00%** | **424** | **2,800** | Alternating same set: 2-way eliminates conflict (**6.6× speedup**) |
| `cyclic3.txt` | 300 | 0 | 0 | **0.00%** | **0.00%** | 4,200 | 4,200 | 3-way cyclic conflict: pathological worst-case for 2-way LRU |
| `strided.txt` | 256 | 248 | 248 | **96.88%** | **96.88%** | 608 | 608 | 64B stride hits every 4th set; working set retained |
| `random.txt` | 300 | 22 | 18 | **7.33%** | **6.00%** | **3,936** | **3,984** | Absence of locality; datapath stress test |
| `mixed_rw.txt` | 300 | 244 | 244 | **81.33%** | **81.33%** | 1,499 | 1,499 | 70% read / 30% write; Write-Through verified |
| `large_loop.txt` | 384 | 0 | 96 | **0.00%** | **25.00%** | **5,376** | **4,224** | 1.5KB loop: Direct-mapped wins on non-colliding lines |
| `hot_stream.txt` | 400 | 363 | 347 | **90.75%** | **86.75%** | **1,244** | **1,436** | 2nd way protects hot region from cold stream (**13.4% faster**) |
| `matrix_walk.txt` | 512 | 448 | 448 | **87.50%** | **87.50%** | 1,792 | 1,792 | 16×16 matrix traversal; row-major spatial reuse |
| `write_heavy.txt` | 640 | 483 | 483 | **75.47%** | **75.47%** | 4,244 | 4,244 | 80% writes (336 stores); Write-Through bus stress |

---

## Multi-Target FPGA Synthesis Summary

From `results/resource_table.md` (synthesized with Yosys v0.71+):

| Metric | 2-Way LRU Cache | Direct-Mapped Baseline | Delta (2-Way vs Direct) | Architectural Explanation |
|---|:---:|:---:|:---:|---|
| **Generic Cells** | 35,643 | 39,809 | -4,166 (-10.5% for 2-way) | Direct-mapped requires 11.7% more cells for deeper mux trees |
| **Generic Muxes** | 4,346 | 8,410 | -4,064 (-48.3% for 2-way) | Direct-mapped consumes **93.5% more muxes** (64-to-1 word mux tree) |
| **Xilinx 7-Series LUTs** | 6,699 | 9,352 | -2,653 (-28.4% for 2-way) | Direct-mapped consumes **39.6% more LUTs** (extra 2,832 LUT5s for muxes) |
| **ECP5 LUT4s** | 14,807 | 18,541 | -3,734 (-20.1% for 2-way) | Direct-mapped consumes **25.2% more LUT4s** and slice muxes |
| **Flip-Flops (All Targets)** | 10,122 | 10,026 | **+96 (+1.0%)** | **Exact storage delta: +64 tag bits + 32 LRU bits** |
| **Block RAM (BRAM)** | **0** | **0** | **0** | **0 inferred: single-cycle combinational reads require discrete FFs** |

> **Critical Synthesis Caveat:** The direct-mapped baseline consumes more LUTs and multiplexers *solely* because both microarchitectures store lines in discrete registers with single-cycle combinational reads, where a 64-to-1 word selection tree is larger and deeper than a 32-to-1 tree followed by a 2-to-1 way mux. In physical ASIC or FPGA implementations mapped to synchronous Block RAM or SRAM macros, set associativity inherently requires more logic (parallel comparators and hit multiplexing) without this multiplexer tree penalty. This result must not be interpreted as associativity being cheaper in general.
