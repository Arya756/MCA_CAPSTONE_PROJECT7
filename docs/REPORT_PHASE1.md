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
*TODO: Member 3 (Direct-Mapped Baseline & Memory Model)*  
Explain the rationale and operational mechanics of the **Write-Through, No-Write-Allocate** policy:
- **Write Hit:** Updates data word in matching cache line/way, updates LRU bit, and writes through to main memory.
- **Write Miss (No-Write-Allocate):** Sends write directly to main memory without allocating or refilling a cache line. Prevents cache pollution on write-only streams.
- Trade-off analysis: Simplicity and memory coherence vs increased memory bus traffic.

### F. Fair Comparison Methodology
*TODO: Member 3 (Direct-Mapped Baseline & Memory Model)*  
Detail the fairness controls enforced across both experimental setups:
- Identical 1 KB capacity and 16-byte block granularity.
- Identical memory bus timing (8-cycle read burst latency `RD_LAT`, 4-cycle write latency `WR_LAT`).
- Same write policy (write-through no-write-allocate).
- Identical cycle counting and transaction semantics.

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
*TODO: Member 4 & Member 5*  
Insert the experimental results from `results/results.csv`:

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

*TODO: Member 5:*  
- Add comparative bar charts (`hit_rate.png` and `cycles.png`).
- Add Yosys synthesis resource utilization table (cell count, flip-flops, wires).

---

## V. Individual Contributions

| Member | Assigned Role | Owned Files & Deliverables | Real Commit Count | Status |
|---|---|---|---|---|
| **Member 1** | Team Lead & 2-Way RTL | `rtl/cache_2way_lru.v`, report sections III.A, III.B, III.D | *Checked via git log* | Starter Ready |
| **Member 2** | LRU Logic & Verification | `tb/tb_lru_directed.v`, LRU diagram, section III.C | *Checked via git log* | Starter Ready |
| **Member 3** | Direct Baseline & Memory | `rtl/cache_direct.v`, `rtl/main_memory.v`, `tb/tb_direct_basic.v`, sections III.E, III.F | *Checked via git log* | Starter Ready |
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
