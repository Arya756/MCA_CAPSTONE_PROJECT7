# Phase II – Member 3 Audit & Parameter Sweep Architecture
**Author:** Member 3 (Baseline, Memory Model & Parameter Sweeps)  
**Issue:** Closes #14  
**Branch:** `member3-memory-sweeps`  
**Date:** November 23, 2026  

---

## 1. Phase A: Repository Structure & Existing Component Audit

### 1.1 Directory Layout & Component Ownership
```
MCA_CAPSTONE_PROJECT7/
├── rtl/
│   ├── cache_direct.v          [Member 3] Direct-Mapped L1 Cache (1 KB baseline)
│   ├── main_memory.v           [Member 3] Parameterized Backing Memory Model
│   └── cache_2way_lru.v        [Member 1] 2-Way Set-Associative Cache with True LRU
├── tb/
│   ├── tb_direct_basic.v       [Member 3] Direct-mapped self-checking unit testbench
│   ├── tb_compare.v            [Shared] Cross-validation vs golden memory model
│   └── tb_lru_directed.v       [Member 2] Directed replacement verification testbench
├── scripts/
│   ├── run_all.sh              [Member 4] Master automated regression suite
│   ├── run_latency_study.sh    [Member 3] Phase I memory latency sensitivity sweep
│   ├── run_sweeps.sh           [Member 3 - Phase II] Unified parameter sweeps runner
│   ├── gen_traces.py           [Member 4] 9 deterministic trace generator
│   └── plot_results.py         [Member 4] Benchmark bar chart generator
└── results/
    ├── latency_sensitivity.csv [Member 3] Phase I RD_LAT sweep (4, 8, 16 cycles)
    └── results.csv             [Shared] Master benchmark results (9 traces)
```

---

## 2. Baseline Architecture Audit (cache_direct.v vs cache_2way_lru.v)

| Metric | `cache_direct.v` | `cache_2way_lru.v` | Parity Status |
|---|---|---|:---:|
| **Data Capacity** | 1024 Bytes (1 KB) | 1024 Bytes (1 KB) | **MATCH** |
| **Block Size** | 16 Bytes (4 words) | 16 Bytes (4 words) | **MATCH** |
| **Associativity** | 1 Way (Direct-Mapped) | 2 Ways (Set-Associative) | Controlled Variable |
| **Line / Set Count** | 64 Lines | 32 Sets (64 lines total) | **MATCH** |
| **Offset Field** | `addr[3:0]` (4 bits) | `addr[3:0]` (4 bits) | **MATCH** |
| **Index Field** | `addr[9:4]` (6 bits) | `addr[8:4]` (5 bits) | $\Delta = 1$ bit (Associativity) |
| **Tag Field** | `addr[31:10]` (22 bits) | `addr[31:9]` (23 bits) | $\Delta = 1$ bit (Tag compensation) |
| **Write Hit Policy** | Write-Through | Write-Through | **MATCH** |
| **Write Miss Policy** | No-Write-Allocate | No-Write-Allocate | **MATCH** |
| **Memory Interface** | 32-bit burst bus | 32-bit burst bus | **MATCH** |

---

## 3. Phase II Implementation Plan & Roadmap

1. **Phase A (This document):** Full repository inspection, parameter audit, and branch initialization.
2. **Phase B (Baseline Verification):** Rigorous verification of capacity, block size, and write policy across both designs.
3. **Phase C (Latency Sweeps):** RD_LAT $\in \{4, 8, 16\}$ and WR_LAT $\in \{2, 4, 8\}$ across all 9 traces.
4. **Phase D (Cache-Size Sweeps):** Parameterized capacity sweep: $C \in \{512\text{ B}, 1024\text{ B}, 2048\text{ B}\}$.
5. **Phase E (Block-Size Sweeps):** Parameterized block size sweep: $B \in \{8\text{ B}, 16\text{ B}, 32\text{ B}\}$.
6. **Phase F (AMAT vs Measured):** Theoretical AMAT vs cycle-accurate execution analysis.
7. **Phase G (Analytical Formula Check):** Validating $\Delta\text{Cycles} = \text{Misses} \times \Delta\text{Latency}$.
8. **Phase H (Testbench Strengthening):** Updating `tb/tb_direct_basic.v` with memory FSM idle-state departure monitor.
9. **Phase I (Results & Documentation):** Complete methodology and sensitivity tables for final report.
10. **Phase J (Submission & PR):** Final verification, zero mismatches, and opening PR with `Closes #14`.
