# Phase I Technical Report: Design and Implementation of a 2-Way Set-Associative Cache with True LRU Replacement Compared Against a Direct-Mapped Baseline

**Course / Project:** Project 7 – Cache Memory Subsystem Design (Phase I)  
**Target Platform:** Verilog HDL (Icarus Verilog, Yosys, GTKWave)  
**Repository:** `MCA_CAPSTONE_PROJECT7`  
**Date:** November 15, 2026  

---

## Abstract
*TODO: Member 5 (Report Lead)*  
Provide a concise 150–250 word summary covering the objective of designing a 1 KB 2-way set-associative cache with True LRU replacement in Verilog HDL, comparing it against an identically sized direct-mapped baseline under write-through no-write-allocate policy, the synthetic trace evaluation methodology, and key experimental findings (including ping-pong conflict immunity and LRU cyclic degradation).

---

## I. Introduction
*TODO: Member 5 (Report Lead)*  
Introduce the memory hierarchy gap between high-speed microprocessors and relatively high-latency main memory. Explain the fundamental principles of spatial and temporal locality. State the motivation for comparing a 2-way set-associative cache against a direct-mapped cache under equal silicon capacity (1 KB) and identical block sizing (16 B), highlighting the trade-offs between hardware complexity, hit rate, and cycle latency.

---

## II. Literature Review
*TODO: Member 5 (Report Lead)*  
Survey foundational cache literature:
1. Hennessy, J. L., & Patterson, D. A. *Computer Architecture: A Quantitative Approach* (Principles of set associativity, conflict misses, and miss classification into 3Cs: Compulsory, Capacity, Conflict).
2. Smith, A. J. (1982). "Cache Memories." *ACM Computing Surveys* (Analysis of replacement algorithms, direct-mapped vs set-associative trade-offs).
3. Mattson, R. L., et al. (1970). "Evaluation techniques for storage hierarchies" (Stack replacement algorithms and LRU optimality bounds).

---

## III. Proposed Solution

### A. Cache Parameters and Address Decomposition
*TODO: Member 1 (Team Lead)*  
Document the exact architectural parameters for both cache architectures under an identical 1 KB data capacity and 16-byte block size:
- **Direct-Mapped Cache (64 Lines):**
  - Offset: 4 bits (`addr[3:0]`), with `addr[3:2]` selecting 1 of 4 words.
  - Index: 6 bits (`addr[9:4]`, selecting lines 0 to 63).
  - Tag: 22 bits (`addr[31:10]`).
- **2-Way Set-Associative Cache (32 Sets × 2 Ways):**
  - Offset: 4 bits (`addr[3:0]`), with `addr[3:2]` selecting 1 of 4 words.
  - Index: 5 bits (`addr[8:4]`, selecting sets 0 to 31).
  - Tag: 23 bits (`addr[31:9]`).
Include the parameter equations and proof that both designs provide exactly 1024 bytes of user data storage.

### B. Hardware Architecture & Datapath
*TODO: Member 1 (Team Lead)*  
Present the block diagram (referenced from `docs/img/`) showing the parallel tag comparison paths (`hit0`, `hit1`), the hit-way multiplexer, valid bits, and the processor-side and memory-side buses.

### C. True LRU Replacement Logic
*TODO: Member 2 (LRU Logic & Verification)*  
Detail the single-bit-per-set True LRU tracking mechanism:
- Meaning of `lru[set]`: pointing to the victim way (`0` for Way 0, `1` for Way 1).
- Update logic on Read/Write hit: `lru[set] <= ~hit_way`.
- Update logic on block refill: `lru[set] <= ~victim_way`.
- Victim priority selection: invalid ways selected first (`!valid0 ? 0 : !valid1 ? 1 : lru[set]`), preventing unnecessary evictions.
Include the state transition table across the access sequence `A, B, A, C, B, A, C, A, B, C`.

### D. Controller Finite State Machine (FSM)
*TODO: Member 1 (Team Lead)*  
Describe the 4 FSM states common to both cache controllers:
- `STATE_IDLE`: Waiting for active `cpu_req`.
- `STATE_LOOKUP`: Performing parallel tag comparison and hit/miss determination.
- `STATE_MISS_FETCH`: Interfacing with `main_memory` for 4-word burst refills.
- `STATE_WRITE_THROUGH`: Performing memory word writes and awaiting write acknowledgment.
Include the FSM state diagram and timing waveforms from GTKWave (`docs/img/lru_directed.vcd`).

### E. Write Policy
In both cache architectures, memory store transactions are governed by a **Write-Through, No-Write-Allocate** policy. This policy was deliberately chosen for Phase I to guarantee absolute cache-memory coherence while minimizing controller control path complexity.

1. **Write Hit Operation:**
   - **Direct-Mapped Cache (`cache_direct`):** During `STATE_LOOKUP`, when `valid_array[req_index] == 1` and `tag_array[req_index] == req_tag`, a write hit occurs. The controller updates the targeted 32-bit word in `data_array[req_index][req_word_sel]` and immediately transitions to `STATE_WRITE_THROUGH`. The write transaction is forwarded across the memory bus (`mem_req = 1`, `mem_we = 1`, `mem_addr = req_addr`, `mem_wdata = req_wdata`), holding until `mem_ready` asserts after `WR_LAT` cycles (default 4 cycles).
   - **2-Way Set-Associative Cache (`cache_2way_lru`):** Tag comparators evaluate Way 0 and Way 1 in parallel. Upon a hit in Way 0 or Way 1, the corresponding way's data array (`data0` or `data1`) is updated. Concurrently, the set's LRU tracking bit is updated (`lru[req_set] <= ~hit_way`) so that the accessed way is marked as most recently used. The write is simultaneously propagated to `main_memory` via `STATE_WRITE_THROUGH`.

2. **Write Miss Operation (No-Write-Allocate):**
   - When a write request targets an address not currently cached (tag mismatch or valid bit deasserted), neither architecture allocates a cache line or initiates a block refill.
   - The write is dispatched directly to `main_memory` in `STATE_WRITE_THROUGH`. 
   - **Cache Pollution Prevention:** No-Write-Allocate ensures that write-only memory streams (such as `memset`, array initialization, or streaming buffer outputs) do not evict active, hot lines from the cache, thereby preserving working-set temporal locality for subsequent reads.

3. **Trade-Off Analysis:**
   - *Advantages:* Simplifies hardware implementation by eliminating dirty bits, per-line modified flags, and write-back eviction buffers. Memory and cache remain perfectly synchronized at all times, drastically simplifying system recovery, DMA snooping, and multi-core consistency.
   - *Disadvantages:* Every store transaction incurs backing memory write latency (`WR_LAT = 4` cycles), creating higher memory bus contention during write-dense workload phases compared to write-back caching.

### F. Fair Comparison Methodology
To establish rigorous empirical rigor, the comparative analysis between the direct-mapped baseline and the 2-way set-associative cache enforces strict architectural controls, ensuring that observed hit rate and cycle count variances arise solely from cache associativity:

1. **Storage Capacity and Organization Parity:**
   - Both caches provide exactly **1024 Bytes (1 KB)** of user data capacity.
   - Both caches operate with an identical **16-byte block size** (4 words per block), requiring identical burst transaction bandwidth from backing memory.
   - The direct-mapped baseline is organized as 64 lines (Index: 6 bits, Tag: 22 bits), whereas the 2-way design is organized as 32 sets of 2 ways (Index: 5 bits, Tag: 23 bits). The aggregate storage is identical ($64 \times 16\text{ B} = 32 \times 2 \times 16\text{ B} = 1024\text{ B}$).

2. **Identical Memory Subsystem & Bus Timings:**
   - Both DUTs are benchmarked against the identical backing memory module (`rtl/main_memory.v`).
   - Block refill latency is uniformly fixed to `RD_LAT = 8` cycles followed by a 4-cycle burst (14 active cycles total miss latency).
   - Word write latency is uniformly fixed to `WR_LAT = 4` cycles (5 active cycles total write latency).

3. **Symmetrical Active Cycle Counting:**
   - Execution cycles are monitored strictly during active processor service cycles (from `cpu_req = 1` until `cpu_ready = 1`). Idle intervals between trace stimuli are excluded to avoid artificial skew from testbench delays.

4. **Independent Sequential Passes & Golden Memory Verification:**
   - The comparison testbench (`tb/tb_compare.v`) executes each trace through `cache_2way_lru` and `cache_direct` in isolated passes with identical initial memory contents and cold-cache states, cross-checking all read outputs against an independent architectural golden memory array. Across all benchmark traces, zero data mismatches are observed.

### G. Evaluation Traces & Locality Patterns
*TODO: Member 4 (Traces, Comparison Testbench, Scripts)*  
Document the 7 synthetic workloads generated by `scripts/gen_traces.py` and the 2 Phase II extensions:
1. `seq_stream.txt`: 256 sequential accesses with 4B stride (~75% hit rate).
2. `small_loop.txt`: 256B tight loop executed 10 times (~97.5% hit rate).
3. `pingpong.txt`: Ping-pong conflict on Set 2 (demonstrates 2-way associativity benefit: 99% vs 0%).
4. `cyclic3.txt`: 3-way cyclic conflict on Set 3 (pathological LRU thrashing: 0% hit rate).
5. `strided.txt`: 64B strided access hitting every 4th set.
6. `random.txt`: Deterministic uniform random accesses across 16 KB range.
7. `mixed_rw.txt`: 70% read / 30% write distribution over hot working set.
8. *Phase II Extension 1 (TODO Member 4):* 1.5 KB loop exceeding cache capacity.
9. *Phase II Extension 2 (TODO Member 4):* Read-mostly stream with hot localized region.

---

## IV. Results & Comparative Analysis
*Baseline Configuration: RD_LAT=8, WR_LAT=4, 32-bit addresses, 16-byte block size (Source: `results/results.csv`)*

The experimental evaluation below was gathered from the full regression suite using 32-bit address traces, with backing memory parameters set to `RD_LAT = 8` cycles and `WR_LAT = 4` cycles. All numbers are extracted directly from cycle-accurate simulation logs:

| Trace Name | Design | Total Accesses | Hits | Misses | Hit Rate (%) | Total Cycles |
|---|---|---|---|---|---|---|
| `seq_stream` | 2-Way LRU | 256 | 192 | 64 | 75.00% | 1,280 |
| `seq_stream` | Direct-Mapped | 256 | 192 | 64 | 75.00% | 1,280 |
| `small_loop` | 2-Way LRU | 640 | 624 | 16 | 97.50% | 1,472 |
| `small_loop` | Direct-Mapped | 640 | 624 | 16 | 97.50% | 1,472 |
| `pingpong` | 2-Way LRU | 200 | 198 | 2 | 99.00% | 424 |
| `pingpong` | Direct-Mapped | 200 | 0 | 200 | 0.00% | 2,800 |
| `cyclic3` | 2-Way LRU | 300 | 0 | 300 | 0.00% | 4,200 |
| `cyclic3` | Direct-Mapped | 300 | 0 | 300 | 0.00% | 4,200 |
| `strided` | 2-Way LRU | 256 | 248 | 8 | 96.88% | 608 |
| `strided` | Direct-Mapped | 256 | 248 | 8 | 96.88% | 608 |
| `random` | 2-Way LRU | 300 | 22 | 278 | 7.33% | 3,936 |
| `random` | Direct-Mapped | 300 | 18 | 282 | 6.00% | 3,984 |
| `mixed_rw` | 2-Way LRU | 300 | 244 | 56 | 81.33% | 1,499 |
| `mixed_rw` | Direct-Mapped | 300 | 244 | 56 | 81.33% | 1,499 |

### A. Memory Read Latency Sensitivity Study (RD_LAT = 4, 8, 16 Cycles)
*Contributed by Member 3 (Direct-Mapped Baseline & Memory Model)*  
*Configuration: RD_LAT ∈ {4, 8, 16}, WR_LAT=4, 32-bit addresses, 16-byte blocks (Sources: `results/latency_rd4.csv`, `results/latency_rd8.csv`, `results/latency_rd16.csv`, consolidated in `results/latency_sensitivity.csv`)*

To evaluate cache resilience against varying memory subsystem delays, a full regression sweep was executed with read latency parameters $RD\_LAT \in \{4, 8, 16\}$ clock cycles. The table below illustrates the cycle impact across all 7 benchmark workloads (consolidated in `results/latency_sensitivity.csv`):

| Trace Name | Architecture | Accesses | Misses | Hit Rate | Cycles (RD_LAT=4) | Cycles (RD_LAT=8) | Cycles (RD_LAT=16) | Delta (8 → 4) | Delta (8 → 16) |
|---|---|---|---|---|---|---|---|---|---|
| `seq_stream` | 2-Way LRU | 256 | 64 | 75.00% | 1,024 | 1,280 | 1,792 | -256 (-20.0%) | +512 (+40.0%) |
| `seq_stream` | Direct-Mapped | 256 | 64 | 75.00% | 1,024 | 1,280 | 1,792 | -256 (-20.0%) | +512 (+40.0%) |
| `small_loop` | 2-Way LRU | 640 | 16 | 97.50% | 1,408 | 1,472 | 1,600 | -64 (-4.3%) | +128 (+8.7%) |
| `small_loop` | Direct-Mapped | 640 | 16 | 97.50% | 1,408 | 1,472 | 1,600 | -64 (-4.3%) | +128 (+8.7%) |
| `pingpong` | 2-Way LRU | 200 | 2 | 99.00% | 416 | 424 | 440 | -8 (-1.9%) | +16 (+3.8%) |
| `pingpong` | Direct-Mapped | 200 | 200 | 0.00% | 2,000 | 2,800 | 4,400 | -800 (-28.6%) | +1,600 (+57.1%) |
| `cyclic3` | 2-Way LRU | 300 | 300 | 0.00% | 3,000 | 4,200 | 6,600 | -1,200 (-28.6%) | +2,400 (+57.1%) |
| `cyclic3` | Direct-Mapped | 300 | 300 | 0.00% | 3,000 | 4,200 | 6,600 | -1,200 (-28.6%) | +2,400 (+57.1%) |
| `strided` | 2-Way LRU | 256 | 8 | 96.88% | 576 | 608 | 672 | -32 (-5.3%) | +64 (+10.5%) |
| `strided` | Direct-Mapped | 256 | 8 | 96.88% | 576 | 608 | 672 | -32 (-5.3%) | +64 (+10.5%) |
| `random` | 2-Way LRU | 300 | 278 | 7.33% | 2,824 | 3,936 | 6,160 | -1,112 (-28.3%) | +2,224 (+56.5%) |
| `random` | Direct-Mapped | 300 | 282 | 6.00% | 2,856 | 3,984 | 6,240 | -1,128 (-28.3%) | +2,256 (+56.6%) |
| `mixed_rw` | 2-Way LRU | 300 | 56 | 81.33% | 1,371 | 1,499 | 1,755 | -128 (-8.5%) | +256 (+17.1%) |
| `mixed_rw` | Direct-Mapped | 300 | 56 | 81.33% | 1,371 | 1,499 | 1,755 | -128 (-8.5%) | +256 (+17.1%) |

**Key Architectural Insights from Read Latency Sensitivity:**
1. **Linear Scaling with Miss Penalty:** The cycle variance across memory latency settings follows the exact analytical formula $\Delta \text{Cycles} = \Delta RD\_LAT \times \text{Read Misses}$. Shifting $RD\_LAT$ from 8 to 4 decreases execution time by exactly 4 cycles per miss, while increasing $RD\_LAT$ to 16 adds 8 cycles per miss.
2. **Associativity as a Latency Buffer:** On conflict-prone traces such as `pingpong`, the 2-way associative cache experiences only 2 cold misses, causing its total execution time to increase by a mere 3.8% (424 to 440 cycles) when memory latency doubles. In stark contrast, the direct-mapped cache suffers 200 conflict misses, resulting in a 57.1% cycle increase (2,800 to 4,400 cycles). This demonstrates that set associativity effectively shields the CPU from off-chip memory latency bottlenecks.

### B. Memory Write Latency Sensitivity Study (WR_LAT = 2, 4, 8 Cycles)
*Contributed by Member 3 (Direct-Mapped Baseline & Memory Model)*  
*Configuration: WR_LAT ∈ {2, 4, 8}, RD_LAT=8, 32-bit addresses, 16-byte blocks (Sources: `results/latency_wr2.csv`, `results/latency_wr4.csv`, `results/latency_wr8.csv`)*

To analyze the performance impact of backing memory write stalls under the unbuffered Write-Through policy, a parameter sweep was conducted across write latencies $WR\_LAT \in \{2, 4, 8\}$ cycles (with $RD\_LAT = 8$ held constant):

| Trace Name | Architecture | Accesses | Writes | Cycles (WR_LAT=2) | Cycles (WR_LAT=4) | Cycles (WR_LAT=8) | Delta (4 → 2) | Delta (4 → 8) | Analytical Verification |
|---|---|---|---|---|---|---|---|---|---|
| `seq_stream` | 2-Way LRU | 256 | 0 | 1,280 | 1,280 | 1,280 | 0 | 0 | Read-only workload |
| `seq_stream` | Direct-Mapped | 256 | 0 | 1,280 | 1,280 | 1,280 | 0 | 0 | Read-only workload |
| `small_loop` | 2-Way LRU | 640 | 0 | 1,472 | 1,472 | 1,472 | 0 | 0 | Read-only workload |
| `small_loop` | Direct-Mapped | 640 | 0 | 1,472 | 1,472 | 1,472 | 0 | 0 | Read-only workload |
| `pingpong` | 2-Way LRU | 200 | 0 | 424 | 424 | 424 | 0 | 0 | Read-only workload |
| `pingpong` | Direct-Mapped | 200 | 0 | 2,800 | 2,800 | 2,800 | 0 | 0 | Read-only workload |
| `cyclic3` | 2-Way LRU | 300 | 0 | 4,200 | 4,200 | 4,200 | 0 | 0 | Read-only workload |
| `cyclic3` | Direct-Mapped | 300 | 0 | 4,200 | 4,200 | 4,200 | 0 | 0 | Read-only workload |
| `strided` | 2-Way LRU | 256 | 0 | 608 | 608 | 608 | 0 | 0 | Read-only workload |
| `strided` | Direct-Mapped | 256 | 0 | 608 | 608 | 608 | 0 | 0 | Read-only workload |
| `random` | 2-Way LRU | 300 | 0 | 3,936 | 3,936 | 3,936 | 0 | 0 | Read-only workload |
| `random` | Direct-Mapped | 300 | 0 | 3,984 | 3,984 | 3,984 | 0 | 0 | Read-only workload |
| **`mixed_rw`** | **2-Way LRU** | **300** | **103** | **1,293** | **1,499** | **1,911** | **-206** | **+412** | **★ Exact: $103 \times (-2) = -206$, $103 \times (+4) = +412$** |
| **`mixed_rw`** | **Direct-Mapped** | **300** | **103** | **1,293** | **1,499** | **1,911** | **-206** | **+412** | **★ Exact: $103 \times (-2) = -206$, $103 \times (+4) = +412$** |

**Key Architectural Insights from Write Latency Sensitivity:**
1. **Direct Write-Stall Correlation:** Because Phase I uses an unbuffered Write-Through policy, every store instruction stalls the processor for exactly $WR\_LAT$ memory cycles regardless of whether it hit or missed in the cache. The cycle variance precisely matches $\Delta \text{Cycles} = \text{Writes} \times \Delta WR\_LAT$.
2. **Workload Selectivity:** Traces comprising exclusively read instructions (`seq_stream`, `small_loop`, `pingpong`, `cyclic3`, `strided`, `random`) demonstrate zero cycle variance across $WR\_LAT$ changes, validating that read refill bursts depend solely on $RD\_LAT$. The write-heavy trace `mixed_rw` (103 writes) highlights the substantial CPU stall penalty of unbuffered write-through operations, motivating a write buffer or write-back policy for Phase II.

*TODO: Member 5:*  
- Add comparative bar charts (`hit_rate.png` and `cycles.png`).
- Add Yosys synthesis resource utilization table (cell count, flip-flops, wires).

---

## V. Individual Contributions

| Member | Assigned Role | Owned Files & Deliverables | Real Commit Count | Status |
|---|---|---|---|---|
| **Member 1** | Team Lead & 2-Way RTL | `rtl/cache_2way_lru.v`, report sections III.A, III.B, III.D | *Checked via git log* | Starter Ready |
| **Member 2** | LRU Logic & Verification | `tb/tb_lru_directed.v`, LRU diagram, section III.C | *Checked via git log* | Starter Ready |
| **Member 3** | Direct Baseline & Memory | `rtl/cache_direct.v`, `rtl/main_memory.v`, `tb/tb_direct_basic.v`, sections III.E, III.F, latency study | 13 commits | Completed |
| **Member 4** | Traces, Comparison & Scripts | `scripts/gen_traces.py`, `scripts/run_all.sh`, `tb/tb_compare.v`, `traces/`, sections III.G, IV | *Checked via git log* | Starter Ready |
| **Member 5** | Report, Synthesis & Video | `docs/`, `results/yosys_cmd.txt`, IEEE report formatting, video recording | *Checked via git log* | Starter Ready |

---

## VI. Conclusion
*TODO: Member 5 (Report Lead)*  
Summarize how Phase I achieved complete architectural functional verification and established the baseline performance gap between direct-mapped and 2-way set-associative caches. Outline Phase II roadmap (write-back policy investigation, multi-level hierarchy, Vivado FPGA deployment).

---

## References
1. J. L. Hennessy and D. A. Patterson, *Computer Architecture: A Quantitative Approach*, 6th ed., Cambridge, MA: Morgan Kaufmann, 2017.
2. A. J. Smith, "Cache Memories," *ACM Computing Surveys (CSUR)*, vol. 14, no. 3, pp. 473–530, Sep. 1982.
3. R. L. Mattson, J. Gecsei, D. R. Slutz, and I. L. Traiger, "Evaluation techniques for storage hierarchies," *IBM Systems Journal*, vol. 9, no. 2, pp. 78–117, 1970.
4. *TODO: Member 5 to add 2–3 additional IEEE/ACM peer-reviewed references.*
