# Project 7: 2-Way Set-Associative Cache with LRU vs Direct-Mapped Cache

[![Verilog HDL](https://img.shields.io/badge/Language-Verilog%20HDL-blue.svg)](https://en.wikipedia.org/wiki/Verilog)
[![Toolchain](https://img.shields.io/badge/Simulation-Icarus%20Verilog%20%7C%20GTKWave-brightgreen.svg)](http://iverilog.icarus.com/)
[![Synthesis](https://img.shields.io/badge/Synthesis-Yosys%20Open%20Synthesis-orange.svg)](https://yosyshq.net/yosys/)
[![Regression](https://img.shields.io/badge/Regression-PASS%20%7C%200%20Mismatches-success.svg)](scripts/run_all.sh)

A complete, self-contained hardware evaluation kit designed and modeled in Verilog HDL. This project implements and benchmarks a **1 KB 2-Way Set-Associative L1 Cache with True LRU Replacement** against a baseline **1 KB Direct-Mapped Cache**. Both caches operate under an identical **Write-Through, No-Write-Allocate** memory policy to ensure a strictly fair architectural comparison.

---

## Report and Video

- **Technical Report (PDF):** `docs/report/Project7_Phase1_Report.pdf` (LaTeX source and Overleaf package in [`docs/report/`](docs/report/), markdown draft in [`docs/REPORT_PHASE1.md`](docs/REPORT_PHASE1.md))
- Video: TO BE ADDED
- **Video Script & Schedule:** Available in [`docs/VIDEO_SCRIPT.md`](docs/VIDEO_SCRIPT.md)

---

## Team Members & Responsibilities

Reference: [`docs/TEAM_TASKS.md`](docs/TEAM_TASKS.md)

| Member | Role | Primary File Ownership | Deliverables & Tasks |
|---|---|---|---|
| **Member 1** (Lead) | Architecture & Lead | `rtl/cache_2way_lru.v` | Repo setup, 2-way RTL, GTKWave waveform guide (`docs/WAVEFORM_GUIDE.md`), explainer (`docs/MEMBER1_EXPLAINER.md`), report sections III.A, III.B, III.D |
| **Member 2** | LRU & Verification | `tb/tb_lru_directed.v` | True LRU state logic, directed replacement testbench, LRU state diagram, report section III.C |
| **Member 3** | Baseline & Memory | `rtl/cache_direct.v`, `rtl/main_memory.v` | Direct-mapped baseline, memory burst protocol, `tb_direct_basic.v`, report sections III.E, III.F |
| **Member 4** | Traces & Automation | `scripts/gen_traces.py`, `tb/tb_compare.v`, `scripts/run_all.sh` | 7+ evaluation traces, golden memory verification testbench, automated regression runner, report sections III.G, IV |
| **Member 5** | Synthesis & Documentation | `docs/`, `results/yosys_cmd.txt` | Yosys synthesis execution, IEEE report compilation, video recording, report Abstract, I, II, VI |

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
| **Index Field** | 5 bits: `addr[8:4]` (32 sets) | 6 bits: `addr[9:4]` (64 lines) | log₂(Sets) vs log₂(Lines) |
| **Tag Field** | 23 bits: `addr[31:9]` | 22 bits: `addr[31:10]` | 32 − Index − Offset |
| **Replacement Policy** | True LRU (1 bit per set, `~hit_way`) | Direct replacement (no choice) | Evaluates conflict miss reduction |
| **Write Policy** | Write-Through, No-Write-Allocate | Write-Through, No-Write-Allocate | Strictly identical memory bus traffic |
| **Memory Latency** | 8-cycle read burst, 4-cycle write | 8-cycle read burst, 4-cycle write | Identical backing memory interface |

---

## Repository Structure

```
MCA_CAPSTONE_PROJECT7/
├── .gitignore                      # Git ignore rules for build/sim artifacts
├── README.md                       # Master project overview and instructions
├── docs/
│   ├── img/                        # Waveforms, diagrams, and figures (.gitkeep)
│   ├── MEMBER1_EXPLAINER.md        # Member 1 interview-prep deep-dive guide
│   ├── REPORT_PHASE1.md            # IEEE report skeleton with section owners
│   ├── TEAM_TASKS.md               # Team task plan and deliverables
│   ├── VIDEO_SCRIPT.md             # Timed 5-minute video presentation script
│   └── WAVEFORM_GUIDE.md           # GTKWave waveform inspection instructions
├── results/
│   ├── results.csv                 # Automated testbench benchmark output
│   └── yosys_cmd.txt               # Synthesis commands and resource inspection
├── rtl/
│   ├── cache_2way_lru.v            # 2-way set-associative cache with True LRU
│   ├── cache_direct.v              # Direct-mapped baseline cache
│   └── main_memory.v               # Parameterized memory model (4-word burst)
├── scripts/
│   ├── gen_traces.py               # Deterministic synthetic trace generator
│   └── run_all.sh                  # One-command automated compilation & regression
├── tb/
│   ├── tb_compare.v                # Side-by-side golden memory verification testbench
│   ├── tb_direct_basic.v           # Direct-mapped baseline self-checking testbench
│   └── tb_lru_directed.v           # True LRU self-checking directed testbench
└── traces/                         # Generated memory trace files (.txt)
```

---

## Toolchain Setup

### Linux / Ubuntu / Debian / WSL
```bash
sudo apt update
sudo apt install -y iverilog yosys gtkwave python3
```

### macOS (Homebrew)
```bash
brew install icarus-verilog yosys gtkwave python3
```

---

## Quick Start: One-Command Regression

Run the complete regression suite with a single command from the project root:

```bash
./scripts/run_all.sh
```

### What this script executes:
1. Runs `scripts/gen_traces.py` to generate all 7 deterministic memory traces in `traces/`.
2. Compiles and executes `tb/tb_lru_directed.v` with Icarus Verilog, verifying all directed LRU replacement rules (`LRU test: PASS`).
3. Compiles and executes `tb/tb_direct_basic.v`, verifying direct-mapped functionality and conflict eviction (`DIRECT test: PASS`).
4. Compiles and executes `tb/tb_compare.v` across all traces, verifying **0 data mismatches** against the golden memory model and populating `results/results.csv`.
5. Prints the regression summary and benchmark table.

---

## Benchmark Results (7 Traces)

Generated dynamically into `results/results.csv`:

| Workload Trace | Accesses | 2-Way LRU Hits | Direct Hits | 2-Way Hit Rate | Direct Hit Rate | Locality Pattern & Observation |
|---|---|---|---|---|---|---|
| `seq_stream.txt` | 256 | 192 | 192 | **75.00%** | **75.00%** | Spatial locality (4B stride): 1 miss per 4-word block |
| `small_loop.txt` | 640 | 624 | 624 | **97.50%** | **97.50%** | 256B working set fits completely in 1KB cache |
| `pingpong.txt` | 200 | 198 | 0 | **99.00%** | **0.00%** | Alternating same set: 2-way eliminates conflict; direct thrashes |
| `cyclic3.txt` | 300 | 0 | 0 | **0.00%** | **0.00%** | 3-way cyclic conflict: pathological worst-case for LRU |
| `strided.txt` | 256 | 248 | 248 | **96.88%** | **96.88%** | 64B stride hits every 4th set; loop retained |
| `random.txt` | 300 | 22 | 18 | **7.33%** | **6.00%** | Absence of locality; stress test for control logic |
| `mixed_rw.txt` | 300 | 244 | 244 | **81.33%** | **81.33%** | 70% read / 30% write hot set; tests write-through path |

---

## Synthesis with Yosys

To synthesize either design and inspect cell/flip-flop utilization:

```bash
# Synthesize 2-Way Cache with True LRU:
yosys -p "read_verilog -sv rtl/cache_2way_lru.v; synth -top cache_2way_lru; stat"

# Synthesize Direct-Mapped Baseline:
yosys -p "read_verilog -sv rtl/cache_direct.v; synth -top cache_direct; stat"
```
See [`results/yosys_cmd.txt`](results/yosys_cmd.txt) for advanced scripting options.
