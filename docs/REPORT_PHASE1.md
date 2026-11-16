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
**Author:** Member 4 (Traces, Comparison Testbench, Scripts)

Nine deterministic synthetic workloads are generated by `scripts/gen_traces.py` to rigorously evaluate both cache architectures under diverse spatial and temporal memory access patterns. All addresses are 4-byte word-aligned and bounded within the 16 KB main memory space (`0x00000000` to `0x00003FFC`).

1. **`seq_stream.txt` (256 accesses):** Sequential word reads with a 4-byte stride traversing 1024 bytes. Models pure spatial locality without temporal reuse. With 16-byte blocks (4 words), the first word access in each block misses (compulsory miss) and the next 3 hit, yielding exactly **75.00% hit rate** (192 hits / 64 misses) on both caches.
2. **`small_loop.txt` (640 accesses):** A tight 256-byte loop (64 words) executed 10 times. The working set requires 16 cache blocks, fitting entirely inside the 1 KB cache. After 16 compulsory misses in iteration 1, all subsequent 9 iterations hit at 100%, achieving **97.50% hit rate** on both caches.
3. **`pingpong.txt` (200 accesses):** Alternates between two addresses (`0x0020` and `0x0420`) that map to the identical cache set (Set 2 in 2-way, Line 2 in direct). Demonstrates the primary benefit of associativity: the 2-way cache holds both blocks simultaneously, achieving **99.00% hit rate** (424 cycles). The direct-mapped cache suffers catastrophic thrashing, evicting the resident line on every access to yield **0.00% hit rate** (2,800 cycles, 6.6× slower).
4. **`cyclic3.txt` (300 accesses):** Three addresses (`0x0030`, `0x0430`, `0x0830`) mapping to the same set accessed cyclically ($A \to B \to C \to A \dots$). Demonstrates the pathological worst case for LRU: because set capacity is 2 ways, accessing 3 blocks cyclically evicts the block that will be requested next. Both caches experience complete thrashing (**0.00% hit rate**, 4,200 cycles).
5. **`strided.txt` (256 accesses):** 64-byte stride (4 cache blocks) across 8 distinct addresses over 32 passes, accessing every 4th set. The 8 lines fit in cache; after 8 initial misses, all subsequent passes hit, achieving **96.88% hit rate** on both architectures.
6. **`random.txt` (300 accesses):** Uniform pseudorandom word reads across the 16 KB address space (seed 42). Tests control path robustness under zero-locality conditions. The 2-way cache achieves **7.33% hit rate** (22 hits) vs **6.00%** (18 hits) for direct-mapped.
7. **`mixed_rw.txt` (300 accesses):** 70% reads and 30% writes within a 512-byte hot region (seed 12345). Verifies the Write-Through No-Write-Allocate policy: write hits update both cache and memory; write misses bypass the cache without line allocation. Both designs achieve **81.33% hit rate** (244 hits / 56 misses, 1,499 cycles).
8. **`large_loop.txt` (384 accesses - Extension 1):** A 1.5 KB loop (96 cache blocks) iterated 4 times, intentionally exceeding the 1 KB (64 block) cache capacity. In the 2-way cache (32 sets), 96 blocks / 32 sets = exactly 3 blocks per set, triggering cyclic thrashing across all sets (**0.00% hit rate**, 5,376 cycles). In direct-mapped (64 lines), lines 32..63 receive only 1 block and hit on every repeat pass, achieving **25.00% hit rate** (4,224 cycles). This demonstrates why direct-mapped can outperform 2-way LRU on loops sized between $C$ and $2C$.
9. **`hot_stream.txt` (400 accesses - Extension 2):** A realistic hybrid workload pairing a 128-byte hot region (70% access probability, 8 blocks) with a 2 KB sequential cold streaming sweep (30% access probability, 128 blocks). The 2-way cache shields hot blocks in the second way, achieving **90.75% hit rate** (1,244 cycles) vs **86.75%** (1,436 cycles) for direct-mapped, running **13.4% faster**.

---

## IV. Results & Comparative Analysis
*Baseline Configuration: RD_LAT=8, WR_LAT=4, 32-bit addresses, 16-byte block size (Source: `results/results.csv`)*

The experimental evaluation below was gathered from the full regression suite across all 9 deterministic workloads. Each trace was executed through `cache_2way_lru` and `cache_direct` in isolated passes with identical cold-start states and golden memory initialization. **Zero data mismatches** were observed across all 3,136 total transactions, verifying complete functional equivalence against the architectural golden memory model.

| Trace Name | Design | Total Accesses | Hits | Misses | Hit Rate (%) | Total Cycles | Architectural Behavior |
|---|---|---|---|---|---|---|---|
| `seq_stream` | 2-Way LRU | 256 | 192 | 64 | 75.00% | 1,280 | Compulsory misses (1 per 4-word block); spatial parity |
| `seq_stream` | Direct-Mapped | 256 | 192 | 64 | 75.00% | 1,280 | Compulsory misses (1 per 4-word block); spatial parity |
| `small_loop` | 2-Way LRU | 640 | 624 | 16 | 97.50% | 1,472 | 256B working set fits in 1KB cache; temporal reuse |
| `small_loop` | Direct-Mapped | 640 | 624 | 16 | 97.50% | 1,472 | 256B working set fits in 1KB cache; temporal reuse |
| `pingpong` | 2-Way LRU | 200 | 198 | 2 | **99.00%** | **424** | 2 conflicting addresses fit in 2 ways (**6.6× speedup**) |
| `pingpong` | Direct-Mapped | 200 | 0 | 200 | **0.00%** | **2,800** | Thrashing on Set 2 with alternating lines |
| `cyclic3` | 2-Way LRU | 300 | 0 | 300 | 0.00% | 4,200 | 3-way cyclic access defeats 2-way LRU |
| `cyclic3` | Direct-Mapped | 300 | 0 | 300 | 0.00% | 4,200 | Thrashing on 1 line |
| `strided` | 2-Way LRU | 256 | 248 | 8 | 96.88% | 608 | 64B stride hits every 4th set; loop retained |
| `strided` | Direct-Mapped | 256 | 248 | 8 | 96.88% | 608 | 64B stride hits every 4th set; loop retained |
| `random` | 2-Way LRU | 300 | 22 | 278 | **7.33%** | **3,936** | Slight associativity benefit under uniform random |
| `random` | Direct-Mapped | 300 | 18 | 282 | **6.00%** | **3,984** | Absence of locality; stress test for datapath |
| `mixed_rw` | 2-Way LRU | 300 | 244 | 56 | 81.33% | 1,499 | 70% read / 30% write; Write-Through verified |
| `mixed_rw` | Direct-Mapped | 300 | 244 | 56 | 81.33% | 1,499 | 70% read / 30% write; Write-Through verified |
| `large_loop` | 2-Way LRU | 384 | 0 | 384 | **0.00%** | **5,376** | 3 blocks/set: catastrophic cyclic thrashing across all sets |
| `large_loop` | Direct-Mapped | 384 | 96 | 288 | **25.00%** | **4,224** | 32 non-colliding lines hit repeatedly (**Direct is better**) |
| `hot_stream` | 2-Way LRU | 400 | 363 | 37 | **90.75%** | **1,244** | 2nd way shields hot data from cold stream (**13.4% faster**) |
| `hot_stream` | Direct-Mapped | 400 | 347 | 53 | **86.75%** | **1,436** | Cold stream evicts hot lines on alias collisions |

> **Visualizations:** The hit-rate and execution-cycle bar charts generated by `scripts/plot_results.py` are saved in `results/hit_rate.png` and `results/cycles.png` (and mirrored in `docs/img/`).

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
1. **Linear Scaling with Miss Penalty:** The cycle variance across memory latency settings follows the exact analytical relationship:
   $$\Delta\text{cycles} = (\text{read misses}) \times (\Delta RD\_LAT)$$
   Shifting $RD\_LAT$ from 8 to 4 decreases execution time by exactly 4 cycles per read miss, while increasing $RD\_LAT$ to 16 adds exactly 8 cycles per read miss.
2. **Associativity as a Latency Buffer:** On conflict-prone traces such as `pingpong`, the 2-way associative cache experiences only 2 cold misses, causing its total execution time to increase by a mere 3.8% (424 to 440 cycles) when memory latency doubles. In stark contrast, the direct-mapped cache suffers 200 conflict misses, resulting in a 57.1% cycle increase (2,800 to 4,400 cycles). This demonstrates that set associativity effectively shields the CPU from off-chip memory latency bottlenecks.
3. **Simulation-Verified Read vs. Write Miss Decomposition in `mixed_rw`:** Across the 300 instructions of `mixed_rw.txt` (197 reads, 103 writes), the cache logs 244 hits and 56 misses. Direct cycle-accurate simulation measures the exact breakdown: **165 read hits, 32 read misses, 79 write hits, and 24 write misses**. Under No-Write-Allocate, write misses do not trigger block refills, meaning execution cycles scale solely with the 32 read misses:
   $$\Delta\text{cycles} = 32 \times (\Delta RD\_LAT)$$
   - For $RD\_LAT = 4$: $32 \times (-4) = -128\text{ cycles}$
   - For $RD\_LAT = 16$: $32 \times (+8) = +256\text{ cycles}$
   This confirms analytical and simulation parity to the exact single cycle.

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
| **`mixed_rw`** | **2-Way LRU** | **300** | **103** | **1,293** | **1,499** | **1,911** | **-206** | **+412** | **★ Exact: 103 × (-2) = -206 cycles, 103 × (+4) = +412 cycles** |
| **`mixed_rw`** | **Direct-Mapped** | **300** | **103** | **1,293** | **1,499** | **1,911** | **-206** | **+412** | **★ Exact: 103 × (-2) = -206 cycles, 103 × (+4) = +412 cycles** |

**Key Architectural Insights from Write Latency Sensitivity:**
1. **Direct Write-Stall Correlation:** Because Phase I uses an unbuffered Write-Through policy, every store instruction stalls the processor for exactly $WR\_LAT$ memory cycles regardless of whether it hit or missed in the cache. The cycle variance follows:
   $$\Delta\text{cycles} = (\text{writes}) \times (\Delta WR\_LAT)$$
   - For $WR\_LAT = 2$: $103 \times (-2) = -206\text{ cycles}$
   - For $WR\_LAT = 8$: $103 \times (+4) = +412\text{ cycles}$
2. **Workload Selectivity:** Traces comprising exclusively read instructions (`seq_stream`, `small_loop`, `pingpong`, `cyclic3`, `strided`, `random`) demonstrate zero cycle variance across $WR\_LAT$ changes, validating that read refill bursts depend solely on $RD\_LAT$. The write-heavy trace `mixed_rw` (103 writes) highlights the substantial CPU stall penalty of unbuffered write-through operations, motivating a write buffer or write-back policy for Phase II.

*TODO: Member 5:*  
- Add comparative bar charts (`hit_rate.png` and `cycles.png`).
- Add Yosys synthesis resource utilization table (cell count, flip-flops, wires).

---

## V. Individual Contributions

| Member | Assigned Role | Owned Files & Deliverables | Real Commit Count | Status |
|---|---|---|---|---|
| **Member 1** | Team Lead & 2-Way RTL | `rtl/cache_2way_lru.v`, `docs/WAVEFORM_GUIDE.md`, `docs/MEMBER1_EXPLAINER.md`, report sections III.A, III.B, III.D | *6 commits on branch member1-rtl-docs* | Complete |
| **Member 2** | LRU Logic & Verification | `tb/tb_lru_directed.v`, LRU diagram, section III.C | *Checked via git log* | Starter Ready |
| **Member 3** | Direct Baseline & Memory | `rtl/cache_direct.v`, `rtl/main_memory.v`, `tb/tb_direct_basic.v`, sections III.E, III.F, latency study | 16 commits | Completed |
| **Member 4** | Traces, Comparison & Scripts | `scripts/gen_traces.py`, `scripts/run_all.sh`, `scripts/plot_results.py`, `tb/tb_compare.v`, `traces/` (9 traces), `results/` (charts & CSV), sections III.G, IV | 6 commits on branch member4-traces-benchmarks | Complete |
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
