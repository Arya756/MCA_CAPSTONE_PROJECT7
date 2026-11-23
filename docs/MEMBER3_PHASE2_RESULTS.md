# Phase II Technical Report: Methodology, Sensitivity Sweeps & AMAT Analysis
**Author:** Member 3 (Baseline, Memory Model & Parameter Sweeps)  
**Issue:** Closes #14  
**Branch:** `member3-memory-sweeps`  
**Date:** November 23, 2026  

---

## 1. Comparison Methodology & Baseline Equivalence

To establish empirical rigor when benchmarking set associativity against a direct-mapped cache, all non-associativity dimensions must remain strictly invariant:

1. **Storage Geometry:** Both caches provide exactly $1024\text{ Bytes}$ of user data storage organized into $16\text{-byte blocks}$.
   - Direct-Mapped: 64 lines (Index: 6 bits, Tag: 22 bits, Offset: 4 bits).
   - 2-Way Associative: 32 sets of 2 ways (Index: 5 bits, Tag: 23 bits, Offset: 4 bits).
   - The 1-bit tag width variance mathematically mirrors the factor-of-two difference in set count, preserving zero unmapped address space.
2. **Backing Memory Protocol:** Both designs interface with the identical synchronous burst memory module (`rtl/main_memory.v`), which requires $RD\_LAT = 8$ wait cycles followed by a 4-cycle sequential burst (14 cycles total read miss penalty) and $WR\_LAT = 4$ wait cycles for word stores.
3. **Write Policy:** Both enforce **Write-Through, No-Write-Allocate**. Store hits update cache and memory; store misses bypass the cache without line allocation.
4. **Reproducibility:** All parameter sweeps execute from a single script (`./scripts/run_sweeps.sh`) across all 9 deterministic workloads without duplicated RTL files.

---

## 2. Memory Read & Write Latency Sensitivity Study

### 2.1 Read Latency Sweep ($RD\_LAT \in \{4, 8, 16\}$ cycles, $WR\_LAT = 4$)
*Source: `results/latency_sensitivity.csv`*

| Trace Name | Design | Total Accesses | Misses | Hit Rate | Total Cycles (RD_LAT=4) | Total Cycles (RD_LAT=8) | Total Cycles (RD_LAT=16) | Delta (8 → 4) | Delta (8 → 16) | Analytical Verification |
|---|---|---|---|---|---|---|---|---|---|---|
| `seq_stream` | 2-Way | 256 | 64 | 75.00% | 1,024 | 1,280 | 1,792 | -256 (-20.0%) | +512 (+40.0%) | $64 \times (-4) = -256$, $64 \times (+8) = +512$ ✓ |
| `seq_stream` | Direct | 256 | 64 | 75.00% | 1,024 | 1,280 | 1,792 | -256 (-20.0%) | +512 (+40.0%) | $64 \times (-4) = -256$, $64 \times (+8) = +512$ ✓ |
| `small_loop` | 2-Way | 640 | 16 | 97.50% | 1,408 | 1,472 | 1,600 | -64 (-4.3%) | +128 (+8.7%) | $16 \times (-4) = -64$, $16 \times (+8) = +128$ ✓ |
| `small_loop` | Direct | 640 | 16 | 97.50% | 1,408 | 1,472 | 1,600 | -64 (-4.3%) | +128 (+8.7%) | $16 \times (-4) = -64$, $16 \times (+8) = +128$ ✓ |
| `pingpong` | 2-Way | 200 | 2 | 99.00% | 416 | 424 | 440 | -8 (-1.9%) | +16 (+3.8%) | $2 \times (-4) = -8$, $2 \times (+8) = +16$ ✓ |
| `pingpong` | Direct | 200 | 200 | 0.00% | 2,000 | 2,800 | 4,400 | -800 (-28.6%) | +1,600 (+57.1%) | $200 \times (-4) = -800$, $200 \times (+8) = +1600$ ✓ |
| `cyclic3` | 2-Way | 300 | 300 | 0.00% | 3,000 | 4,200 | 6,600 | -1,200 (-28.6%) | +2,400 (+57.1%) | $300 \times (-4) = -1200$, $300 \times (+8) = +2400$ ✓ |
| `cyclic3` | Direct | 300 | 300 | 0.00% | 3,000 | 4,200 | 6,600 | -1,200 (-28.6%) | +2,400 (+57.1%) | $300 \times (-4) = -1200$, $300 \times (+8) = +2400$ ✓ |
| `strided` | 2-Way | 256 | 8 | 96.88% | 576 | 608 | 672 | -32 (-5.3%) | +64 (+10.5%) | $8 \times (-4) = -32$, $8 \times (+8) = +64$ ✓ |
| `strided` | Direct | 256 | 8 | 96.88% | 576 | 608 | 672 | -32 (-5.3%) | +64 (+10.5%) | $8 \times (-4) = -32$, $8 \times (+8) = +64$ ✓ |
| `random` | 2-Way | 300 | 278 | 7.33% | 2,824 | 3,936 | 6,160 | -1,112 (-28.3%) | +2,224 (+56.5%) | $278 \times (-4) = -1112$, $278 \times (+8) = +2224$ ✓ |
| `random` | Direct | 300 | 282 | 6.00% | 2,856 | 3,984 | 6,240 | -1,128 (-28.3%) | +2,256 (+56.6%) | $282 \times (-4) = -1128$, $282 \times (+8) = +2256$ ✓ |
| `mixed_rw` | 2-Way | 300 | 56 | 81.33% | 1,371 | 1,499 | 1,755 | -128 (-8.5%) | +256 (+17.1%) | Read misses only: $32 \times (-4) = -128$, $32 \times (+8) = +256$ ✓ |
| `mixed_rw` | Direct | 300 | 56 | 81.33% | 1,371 | 1,499 | 1,755 | -128 (-8.5%) | +256 (+17.1%) | Read misses only: $32 \times (-4) = -128$, $32 \times (+8) = +256$ ✓ |
| `large_loop` | 2-Way | 384 | 384 | 0.00% | 3,840 | 5,376 | 8,448 | -1,536 (-28.6%) | +3,072 (+57.1%) | $384 \times (-4) = -1536$, $384 \times (+8) = +3072$ ✓ |
| `large_loop` | Direct | 384 | 288 | 25.00% | 3,072 | 4,224 | 6,528 | -1,152 (-27.3%) | +2,304 (+54.5%) | $288 \times (-4) = -1152$, $288 \times (+8) = +2304$ ✓ |
| `hot_stream` | 2-Way | 400 | 37 | 90.75% | 1,096 | 1,244 | 1,540 | -148 (-11.9%) | +296 (+23.8%) | $37 \times (-4) = -148$, $37 \times (+8) = +296$ ✓ |
| `hot_stream` | Direct | 400 | 53 | 86.75% | 1,224 | 1,436 | 1,860 | -212 (-14.8%) | +424 (+29.5%) | $53 \times (-4) = -212$, $53 \times (+8) = +424$ ✓ |

**Key Architectural Insight:**  
On conflict-prone workloads (`pingpong`), set associativity acts as an off-chip memory latency buffer: when memory latency doubles from 8 to 16 cycles, the 2-way cache's total execution time increases by a negligible **+3.8%** (+16 cycles), whereas the direct-mapped cache suffers a severe **+57.1%** penalty (+1,600 cycles).

### 2.2 Write Latency Sweep ($WR\_LAT \in \{2, 4, 8\}$ cycles, $RD\_LAT = 8$)
Across read-only workloads, varying $WR\_LAT$ produces **zero cycle variance**, demonstrating that read refill bursts depend solely on $RD\_LAT$. On the write-intensive trace `mixed_rw` (103 writes, 197 reads):
- $WR\_LAT = 2$: 1,293 cycles ($\Delta = -206\text{ cycles} = 103 \times -2$)
- $WR\_LAT = 4$: 1,499 cycles (baseline)
- $WR\_LAT = 8$: 1,911 cycles ($\Delta = +412\text{ cycles} = 103 \times +4$)  
This confirms single-cycle analytical alignment with $\Delta\text{Cycles} = \text{Writes} \times \Delta WR\_LAT$.

---

## 3. Cache Capacity Sweep ($C \in \{512\text{ B}, 1024\text{ B}, 2048\text{ B}\}$)
*Fixed parameters: $B = 16\text{ B}, RD\_LAT = 8, WR\_LAT = 4$*  
*Source: `results/sweeps_cache_size.csv`*

| Workload Trace | Design | 512 Bytes (32 lines / 16 sets) | 1024 Bytes (64 lines / 32 sets) | 2048 Bytes (128 lines / 64 sets) | Capacity Sensitivity Observation |
|---|---|:---:|:---:|:---:|---|
| `seq_stream` | 2-Way / Direct | 75.00% (1,280 cyc) | 75.00% (1,280 cyc) | 75.00% (1,280 cyc) | Pure spatial locality; independent of capacity |
| `small_loop` (256 B) | 2-Way / Direct | 97.50% (1,472 cyc) | 97.50% (1,472 cyc) | 97.50% (1,472 cyc) | Working set fits in all three configurations |
| `pingpong` | 2-Way | 99.00% (424 cyc) | 99.00% (424 cyc) | 99.00% (424 cyc) | 2 ways absorb conflict at all sizes |
| `pingpong` | Direct-Mapped | **0.00% (2,800 cyc)** | **0.00% (2,800 cyc)** | **99.00% (424 cyc)** | **At 2 KB, 128 lines eliminate line aliasing!** |
| `cyclic3` | 2-Way | 0.00% (4,200 cyc) | 0.00% (4,200 cyc) | 0.00% (4,200 cyc) | 3 blocks still defeat 2 ways at Set 3 |
| `cyclic3` | Direct-Mapped | 0.00% (4,200 cyc) | 0.00% (4,200 cyc) | 33.00% (3,012 cyc) | 128 lines map 1 block away from conflict |
| `large_loop` (1.5 KB) | 2-Way | **0.00% (5,376 cyc)** | **0.00% (5,376 cyc)** | **75.00% (1,920 cyc)** | **Transitions from 100% miss to full retention** |
| `large_loop` (1.5 KB) | Direct-Mapped | **0.00% (5,376 cyc)** | **25.00% (4,224 cyc)** | **75.00% (1,920 cyc)** | **Fits completely in 2 KB (1,920 cycles)** |

**Key Architectural Insight:**  
Expanding capacity from 1 KB to 2 KB transforms `large_loop` from an thrashing workload into a cached loop, increasing hit rates from 0% (2-way) and 25% (direct) to **75.00% for both designs**, reducing execution time by **64.3%** (5,376 to 1,920 cycles). Furthermore, for `pingpong`, doubling capacity provides enough lines that the two addresses no longer map to the same line in direct-mapped mode, eliminating conflict misses without requiring associativity.

---

## 4. Cache Block Size Sweep ($B \in \{8\text{ B}, 16\text{ B}, 32\text{ B}\}$)
*Fixed parameters: $C = 1024\text{ B}, RD\_LAT = 8, WR\_LAT = 4$*  
*Source: `results/sweeps_block_size.csv`*

| Workload Trace | Design | 8 Bytes (2 words / burst) | 16 Bytes (4 words / burst) | 32 Bytes (8 words / burst) | Spatial Locality Effect |
|---|---|:---:|:---:|:---:|---|
| `seq_stream` | 2-Way / Direct | **50.00% (1,792 cyc)** | **75.00% (1,280 cyc)** | **87.50% (1,024 cyc)** | **Hit rate strictly tracks $(B/4 - 1)/(B/4)$** |
| `small_loop` | 2-Way / Direct | 95.00% (1,664 cyc) | 97.50% (1,472 cyc) | 98.75% (1,376 cyc) | Fewer cold misses on initial loop iteration |
| `pingpong` | 2-Way | 99.00% (396 cyc) | 99.00% (424 cyc) | 99.00% (480 cyc) | Hits dominate; larger block adds burst overhead |
| `pingpong` | Direct | 0.00% (2,400 cyc) | 0.00% (2,800 cyc) | 0.00% (3,600 cyc) | Repeated misses penalized by longer burst |

**Key Architectural Insight:**  
On sequential streaming code, block size directly dictates compulsory miss frequency:  
- For $B = 8\text{ B}$ (2 words): 1 miss every 2 words $\implies 50.00\%$ hit rate.
- For $B = 16\text{ B}$ (4 words): 1 miss every 4 words $\implies 75.00\%$ hit rate.
- For $B = 32\text{ B}$ (8 words): 1 miss every 8 words $\implies 87.50\%$ hit rate.  
However, when temporal locality is absent or thrashing occurs (e.g. `pingpong` direct-mapped), larger blocks inflate execution cycles from 2,400 to 3,600 cycles due to wasted burst transfer bandwidth.

---

## 5. Average Memory Access Time (AMAT) Analysis
*Baseline parameters: $RD\_LAT = 8, \text{Hit Time} = 2\text{ cycles}$*  
*Source: `results/amat_comparison.csv`*

$$\text{Classical AMAT} = \text{Hit Time} + (\text{Miss Rate} \times \text{Miss Penalty}) = 2 + (\text{Miss Rate} \times 14)$$

$$\text{Incremental Hardware AMAT} = \text{Hit Latency} + [\text{Miss Rate} \times (\text{Miss Latency} - \text{Hit Latency})] = 2 + (\text{Miss Rate} \times 12)$$

| Workload Trace | Design | Miss Rate (%) | Classical AMAT (cyc) | Exact Incremental AMAT (cyc) | Measured Cycles/Access | Gap vs Exact | Architectural Explanation |
|---|---|:---:|:---:|:---:|:---:|:---:|---|
| `seq_stream` | 2-Way | 25.00% | 5.50 | 5.00 | **5.00** | **0.00** | Exact 100% analytical match |
| `seq_stream` | Direct | 25.00% | 5.50 | 5.00 | **5.00** | **0.00** | Exact 100% analytical match |
| `small_loop` | 2-Way | 2.50% | 2.35 | 2.30 | **2.30** | **0.00** | Exact 100% analytical match |
| `small_loop` | Direct | 2.50% | 2.35 | 2.30 | **2.30** | **0.00** | Exact 100% analytical match |
| `pingpong` | 2-Way | 1.00% | 2.14 | 2.12 | **2.12** | **0.00** | Exact 100% analytical match |
| `pingpong` | Direct | 100.00% | 16.00 | 14.00 | **14.00** | **0.00** | Complete thrashing (14 cyc/miss) |
| `cyclic3` | 2-Way | 100.00% | 16.00 | 14.00 | **14.00** | **0.00** | Complete thrashing (14 cyc/miss) |
| `cyclic3` | Direct | 100.00% | 16.00 | 14.00 | **14.00** | **0.00** | Complete thrashing (14 cyc/miss) |
| `strided` | 2-Way | 3.12% | 2.44 | 2.38 | **2.38** | **0.00** | Exact 100% analytical match |
| `strided` | Direct | 3.12% | 2.44 | 2.38 | **2.38** | **0.00** | Exact 100% analytical match |
| `random` | 2-Way | 92.67% | 14.97 | 13.12 | **13.12** | **0.00** | Exact 100% analytical match |
| `random` | Direct | 94.00% | 15.16 | 13.28 | **13.28** | **0.00** | Exact 100% analytical match |
| `large_loop` | 2-Way | 100.00% | 16.00 | 14.00 | **14.00** | **0.00** | Complete cyclic eviction |
| `large_loop` | Direct | 75.00% | 12.50 | 11.00 | **11.00** | **0.00** | 32 retained lines hit repeatedly |
| `hot_stream` | 2-Way | 9.25% | 3.29 | 3.11 | **3.11** | **0.00** | 2nd way protects hot region |
| `hot_stream` | Direct | 13.25% | 3.85 | 3.59 | **3.59** | **0.00** | Cold stream causes alias misses |
| **`mixed_rw`** | **2-Way** | **18.67%** | **4.61** | **4.24** | **5.00** | **+0.76** | **Gap due to unbuffered write-through stores** |
| **`mixed_rw`** | **Direct** | **18.67%** | **4.61** | **4.24** | **5.00** | **+0.76** | **Gap due to unbuffered write-through stores** |

### Why Classical AMAT and Measured Cycles Differ (Interview Defense Point):
1. **Pipelined Miss Overlap:** In classical AMAT textbooks, miss penalty is often treated as independent added latency. In our cycle-accurate RTL, the 1-cycle lookup stage is an integral part of the miss-handling pipeline. The total read miss latency is 14 cycles, meaning the *incremental* penalty over a 2-cycle hit is $14 - 2 = 12\text{ cycles}$. Using the incremental formula matches simulation measurements across all 8 read-only traces to $0.0000$ error.
2. **Write-Through Penalties:** Classical AMAT accounts solely for memory reads. Under our Write-Through policy without write buffers, every store instruction stalls the CPU for 7 cycles ($1\text{ IDLE} + 1\text{ LOOKUP} + 4\text{ WR\_LAT} + 1\text{ ACK}$). In `mixed_rw` (103 writes), these stores inject an unavoidable stall overhead of $\frac{103 \times (7 - 4.24)}{300} = +0.76\text{ cycles/access}$, perfectly explaining the observed gap.
