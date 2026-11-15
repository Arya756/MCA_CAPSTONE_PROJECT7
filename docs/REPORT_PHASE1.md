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
**Author:** Member 1 (Team Lead)

To ensure a strictly fair comparison between the 2-way set-associative cache and the direct-mapped baseline, both architectures are sized for an identical user data capacity of **1024 Bytes (1 KB)** and an identical block size of **16 Bytes (4 words of 32 bits each)**. Both designs interface with a standard 32-bit microprocessor byte address.

#### 1. Parameter Derivations and Comparison

The architectural dimensions are derived directly from the fundamental cache formulas:

Block Count = Data Capacity / Block Size = 1024 Bytes / 16 Bytes = 64 blocks

- **Direct-Mapped Cache (1 Way):**
  - Number of cache lines: 64 / 1 = 64 lines.
  - Block offset field: log2(Block Size) = log2(16) = **4 bits** (`addr[3:0]`). Within this field, `addr[1:0]` is the 2-bit byte offset (assumed word-aligned `2'b00`), and `addr[3:2]` selects one of the 4 words within the block.
  - Set index field: log2(Number of Lines) = log2(64) = **6 bits** (`addr[9:4]`), selecting lines 0 through 63.
  - Tag field: 32 - Index Bits - Offset Bits = 32 - 6 - 4 = **22 bits** (`addr[31:10]`).

- **2-Way Set-Associative Cache (2 Ways):**
  - Number of sets: Data Capacity / (Block Size x Ways) = 1024 / (16 x 2) = **32 sets**.
  - Block offset field: log2(16) = **4 bits** (`addr[3:0]`), with `addr[3:2]` selecting 1 of 4 words.
  - Set index field: log2(32) = **5 bits** (`addr[8:4]`), selecting sets 0 through 31.
  - Tag field: 32 - Index Bits - Offset Bits = 32 - 5 - 4 = **23 bits** (`addr[31:9]`).

| Parameter | 2-Way Set-Associative Cache | Direct-Mapped Baseline | Fairness Rationale |
|---|---|---|---|
| **User Data Capacity** | 1024 Bytes (1 KB) | 1024 Bytes (1 KB) | Equal storage capacity |
| **Block Size (Burst Unit)** | 16 Bytes (4 words) | 16 Bytes (4 words) | Identical memory transfer size |
| **Associativity (Ways/Set)** | 2 Ways | 1 Way (Direct-Mapped) | Primary design comparison |
| **Total Sets / Lines** | 32 Sets | 64 Lines | Capacity / (Block Size × Ways) |
| **Block Offset Width** | 4 bits (`addr[3:0]`) | 4 bits (`addr[3:0]`) | log₂(16 Bytes) |
| **Word Select Bits** | 2 bits (`addr[3:2]`) | 2 bits (`addr[3:2]`) | Selects 1 of 4 words in block |
| **Set Index Width** | 5 bits (`addr[8:4]`) | 6 bits (`addr[9:4]`) | log₂(Sets) |
| **Tag Width** | 23 bits (`addr[31:9]`) | 22 bits (`addr[31:10]`) | 32 − Index − Offset |
| **Valid Bits** | 64 bits (2 bits per set) | 64 bits (1 bit per line) | 1 bit per stored block |
| **Replacement Bits** | 32 bits (1 bit per set) | 0 bits (No choice) | True LRU tracking bit |

#### 2. Address Bit Decomposition

```text
Direct-Mapped Address Decomposition (32 bits):
 31                        10 9        4 3    2 1    0
+----------------------------+----------+------+------+
|        TAG (22 bits)       | INDEX(6) | WORD | BYTE |
+----------------------------+----------+------+------+
                              64 Lines   16-Byte Offset

2-Way Set-Associative Address Decomposition (32 bits):
 31                         9 8        4 3    2 1    0
+----------------------------+----------+------+------+
|        TAG (23 bits)       | INDEX(5) | WORD | BYTE |
+----------------------------+----------+------+------+
                              32 Sets    16-Byte Offset
```

**Why the Tag Width Differs:**  
In the 2-way cache, grouping two lines into each set halves the total number of sets from 64 to 32. Halving the set count reduces the index field from 6 bits to 5 bits. Because the total address is fixed at 32 bits and the block offset remains 4 bits, the unused index bit shifts into the tag field, increasing tag width from 22 bits to 23 bits.

---

### B. Hardware Architecture & Datapath
**Author:** Member 1 (Team Lead)

The 2-way set-associative cache datapath consists of two parallel storage ways (Way 0 and Way 1), parallel tag comparators, hit-way multiplexing logic, a True LRU tracking array, and memory bus interfacing logic.

#### 1. Datapath Components
- **Storage Arrays:**  
  Each of the 32 sets contains storage for both ways:
  - `valid0` and `valid1`: 32 x 1-bit registers indicating whether the cached block holds valid data.
  - `tag0` and `tag1`: 32 x 23-bit registers storing the memory block tag.
  - `data0` and `data1`: 32 x 4 x 32-bit storage arrays holding four 32-bit words per block.
  - `lru`: 32 x 1-bit registers tracking the replacement state for each set.
- **Parallel Tag Comparators:**  
  When an address arrives, both ways are checked concurrently in hardware using continuous assignment:
  ```verilog
  wire hit0 = valid0[req_index] && (tag0[req_index] == req_tag);
  wire hit1 = valid1[req_index] && (tag1[req_index] == req_tag);
  wire hit  = hit0 || hit1;
  wire hit_way = hit1; // 0 if hit on Way 0, 1 if hit on Way 1
  ```
- **Hit-Way Multiplexer:**  
  On a read hit, `hit_way` steers the requested 32-bit word directly to the CPU bus:
  ```verilog
  cpu_rdata = (hit_way == 1'b1) ? data1[req_index][req_word_sel]
                                : data0[req_index][req_word_sel];
  ```
- **Bus Interfaces:**  
  - *Processor Side:* Handshake via `cpu_req`, `cpu_we`, `cpu_addr`, `cpu_wdata`, `cpu_ready`, and `cpu_rdata`.
  - *Memory Side:* Handshake via `mem_req`, `mem_we`, `mem_addr`, `mem_wdata`, `mem_ready`, and `mem_rdata`.

*(The architectural block diagram created in draw.io is maintained in `docs/img/block_diagram.png`.)*

### C. True LRU Replacement Logic
*TODO: Member 2 (LRU Logic & Verification)*  
Detail the single-bit-per-set True LRU tracking mechanism:
- Meaning of `lru[set]`: pointing to the victim way (`0` for Way 0, `1` for Way 1).
- Update logic on Read/Write hit: `lru[set] <= ~hit_way`.
- Update logic on block refill: `lru[set] <= ~victim_way`.
- Victim priority selection: invalid ways selected first (`!valid0 ? 0 : !valid1 ? 1 : lru[set]`), preventing unnecessary evictions.
Include the state transition table across the access sequence `A, B, A, C, B, A, C, A, B, C`.

### D. Controller Finite State Machine (FSM) and Timing Analysis
**Author:** Member 1 (Team Lead)

#### 1. FSM State Design (4 States vs 7 States)
While theoretical cache specifications often split operation across 7 states (`IDLE`, `LOOKUP`, `HIT_RESPOND`, `MISS_FETCH`, `REFILL`, `WRITE_THROUGH`, `RESPOND`), our Verilog implementation streamlines the controller into **4 operational states**: `STATE_IDLE`, `STATE_LOOKUP`, `STATE_MISS_FETCH`, and `STATE_WRITE_THROUGH`.

```text
               +---------------+
               |  STATE_IDLE   |<-------------------------+
               +---------------+                          |
                       |                                  |
              cpu_req  | latch inputs                     |
                       v                                  |
               +---------------+   Read Hit (2 cycles)    |
               | STATE_LOOKUP  |--------------------------+
               +---------------+   cpu_ready = 1          |
                 |           |                            |
      Read Miss  |           | Write Hit / Write Miss     |
      mem_req=1  |           | mem_req=1, mem_we=1        |
                 v           v                            |
    +------------------+   +---------------------+        |
    | STATE_MISS_FETCH |   | STATE_WRITE_THROUGH |        |
    +------------------+   +---------------------+        |
      |                      |                            |
      | 4-word burst done    | mem_ready = 1              |
      | refill, cpu_ready=1  | cpu_ready = 1              |
      +----------------------+----------------------------+
```

**Why 4 States Were Chosen:**
1. **Immediate Hit Response:** Because parallel tag comparison is combinational, tag matching and data multiplexing complete during `STATE_LOOKUP`. Asserting `cpu_ready <= 1'b1` directly from `LOOKUP` eliminates a separate `HIT_RESPOND` bubble state, keeping read hit latency to exactly **2 clock cycles**.
2. **Refill on Final Burst Word:** In `STATE_MISS_FETCH`, incoming words 0, 1, and 2 are buffered in `refill_buf`. When the 4th word (word 3) arrives with `mem_ready = 1`, the cache immediately writes the entire block into the selected victim way, updates the LRU bit, drives `cpu_rdata`, asserts `cpu_ready <= 1'b1`, and returns to `IDLE` in the same clock edge. This avoids a stalled `REFILL` or `RESPOND` cycle.

#### 2. FSM State Transition Table

| Current State | Input / Condition | Next State | Outputs & Datapath Actions |
|---|---|---|---|
| `STATE_IDLE` | `cpu_req == 0` | `STATE_IDLE` | `cpu_ready = 0`, `mem_req = 0`, wait for request |
| `STATE_IDLE` | `cpu_req == 1` | `STATE_LOOKUP` | Latch `req_addr`, `req_we`, `req_wdata` |
| `STATE_LOOKUP` | `hit && !req_we` (Read Hit) | `STATE_IDLE` | Multiplex hit word to `cpu_rdata`, `cpu_ready = 1`, `lru[index] <= ~hit_way` |
| `STATE_LOOKUP` | `hit && req_we` (Write Hit) | `STATE_WRITE_THROUGH` | Update cache word, `lru[index] <= ~hit_way`, `mem_req = 1`, `mem_we = 1` |
| `STATE_LOOKUP` | `!hit && !req_we` (Read Miss) | `STATE_MISS_FETCH` | `mem_req = 1`, `mem_we = 0`, `mem_addr = {req_addr[31:4], 4'b0}` |
| `STATE_LOOKUP` | `!hit && req_we` (Write Miss) | `STATE_WRITE_THROUGH` | Send write directly to memory: `mem_req = 1`, `mem_we = 1` |
| `STATE_MISS_FETCH` | `mem_ready == 1 && count < 3` | `STATE_MISS_FETCH` | Latch burst word into `refill_buf[count]`, increment `count` |
| `STATE_MISS_FETCH` | `mem_ready == 1 && count == 3` | `STATE_IDLE` | Write all 4 words into victim way, update tag/valid, `lru <= ~victim_way`, drive `cpu_rdata`, `cpu_ready = 1` |
| `STATE_WRITE_THROUGH` | `mem_ready == 0` | `STATE_WRITE_THROUGH` | Wait for memory write acknowledgment |
| `STATE_WRITE_THROUGH` | `mem_ready == 1` | `STATE_IDLE` | Memory write acknowledged: `cpu_ready = 1` |

#### 3. Exact Cycle-by-Cycle Latency Breakdown

All latencies were experimentally verified via `results/lru_directed.vcd` under a 10 ns clock period (`#5 clk = ~clk`):

- **Read Hit Latency (2 Clock Cycles = 20 ns):**
  - *Cycle 1 (Request & Dispatch):* CPU asserts `cpu_req = 1`. Controller samples request and enters `STATE_LOOKUP`.
  - *Cycle 2 (Lookup, Mux & Respond):* Parallel tag comparators evaluate `hit0=1` (or `hit1=1`). Data word is routed via hit multiplexer to `cpu_rdata`, LRU bit updates (`lru <= ~hit_way`), `cpu_ready <= 1'b1` is asserted, and controller returns to `STATE_IDLE`.

- **Read Miss Latency (14 Clock Cycles = 140 ns):**
  Tracing from initial request issue to CPU handshake completion accounts for every clock cycle:

| Cycle # | Clock Time Window | Controller State | Memory State | Detailed RTL & Hardware Action |
|---|---|---|---|---|
| **Cycle 1** | 45 ns to 55 ns | `STATE_IDLE` | `MEM_IDLE` | CPU asserts `cpu_req = 1`. Controller latches address and transitions to `STATE_LOOKUP`. |
| **Cycle 2** | 55 ns to 65 ns | `STATE_LOOKUP` | `MEM_IDLE` | Parallel tag compare misses (`hit0=0, hit1=0`). Controller asserts `mem_req <= 1'b1`, `mem_we <= 1'b0`, and enters `STATE_MISS_FETCH`. |
| **Cycle 3** | 65 ns to 75 ns | `STATE_MISS_FETCH` | `MEM_WAIT` | `main_memory` samples `mem_req == 1`, latches block address, sets `timer <= 1`, and enters wait state. Cache drops `mem_req <= 0`. |
| **Cycles 4 to 9** | 75 ns to 135 ns | `STATE_MISS_FETCH` | `MEM_WAIT` | `main_memory` counts `timer` from 2 to 7 (6 wait cycles) satisfying `RD_LAT = 8`. |
| **Cycle 10** | 135 ns to 145 ns | `STATE_MISS_FETCH` | `MEM_BURST` | Memory asserts `mem_ready <= 1'b1`, drives Word 0. Cache buffers Word 0 into `refill_buf[0]`. |
| **Cycle 11** | 145 ns to 155 ns | `STATE_MISS_FETCH` | `MEM_BURST` | Memory drives Word 1. Cache buffers Word 1 into `refill_buf[1]`. |
| **Cycle 12** | 155 ns to 165 ns | `STATE_MISS_FETCH` | `MEM_BURST` | Memory drives Word 2. Cache buffers Word 2 into `refill_buf[2]`. |
| **Cycle 13** | 165 ns to 175 ns | `STATE_MISS_FETCH` | `MEM_BURST` | Memory drives Word 3. Cache completes refill into victim way, updates LRU bit, routes requested word to `cpu_rdata`, asserts `cpu_ready <= 1'b1`, and returns to `STATE_IDLE`. |
| **Cycle 14** | 175 ns to 185 ns | `STATE_IDLE` | `MEM_IDLE` | `cpu_ready` is active on CPU bus. CPU reads data word and drops `cpu_req = 0`. Handshake complete. |

Total Read Miss Latency = 1 + 1 + 1 + 6 + 4 + 1 = **14 Clock Cycles (140 ns)**

- **Write Hit and Write Miss Latency (7 Clock Cycles = 70 ns):**
  Under write-through no-write-allocate, both write hits and write misses take identical time (7 clock cycles):
  - Cycle 1 (CPU Request): CPU asserts `cpu_req = 1, cpu_we = 1`. Controller latches address and data (`IDLE` to `LOOKUP`).
  - Cycle 2 (Lookup & Memory Request): Tag comparison evaluates hit/miss. On write hit, cache updates internal data word and LRU bit; on write miss, no cache allocation occurs (no-write-allocate). Controller asserts `mem_req <= 1'b1, mem_we <= 1'b1` and enters `STATE_WRITE_THROUGH`.
  - Cycle 3 (Memory Cycle 1 of 4): Memory samples write request, latches word address and data, and sets `timer <= 1` in `STATE_WRITE_WAIT`. Cache deasserts `mem_req`.
  - Cycle 4 (Memory Cycle 2 of 4): Memory in `STATE_WRITE_WAIT` increments `timer <= 2`.
  - Cycle 5 (Memory Cycle 3 of 4): Memory in `STATE_WRITE_WAIT` increments `timer <= 3` (reaching `WR_LAT - 1`).
  - Cycle 6 (Memory Cycle 4 of 4 / Commit): Memory reaches `timer >= WR_LAT - 1`, writes word to `mem_array`, asserts `mem_ready <= 1'b1`, and returns to `STATE_IDLE`. Concurrently, cache detects `mem_ready == 1`, asserts `cpu_ready <= 1'b1`, and returns to `STATE_IDLE`.
  - Cycle 7 (Handshake Completion): `cpu_ready = 1` is active on CPU bus. CPU detects ready, completes write, and drops `cpu_req <= 0`.

Total Write Latency = 1 (CPU dispatch) + 1 (Cache lookup & mem request) + 4 (Memory write latency) + 1 (CPU completion handshake) = **7 Clock Cycles (70 ns)**

*(Detailed GTKWave waveforms, signal lists, and zoom windows are documented in [`docs/WAVEFORM_GUIDE.md`](WAVEFORM_GUIDE.md).)*

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
| **Member 1** | Team Lead & 2-Way RTL | `rtl/cache_2way_lru.v`, `docs/WAVEFORM_GUIDE.md`, `docs/MEMBER1_EXPLAINER.md`, report sections III.A, III.B, III.D | *6 commits on branch member1-rtl-docs* | Complete |
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
