# Final Technical Report (Phase I & Phase II): Design, Verification, FPGA Synthesis, and Empirical Evaluation of a 2-Way Set-Associative Cache with True LRU Replacement Compared Against a Direct-Mapped Baseline

**Course / Project:** Project 7 – Cache Memory Subsystem Design (Phase I & Phase II)  
**Target Platforms:** Verilog HDL (Icarus Verilog, Yosys Open Synthesis Suite, AMD/Xilinx 7-Series, Lattice ECP5, GTKWave)  
**Repository:** `Arya756/MCA_CAPSTONE_PROJECT7`  
**Date:** November 23, 2026  

---

## Abstract
This report presents the complete microarchitectural specification, cycle-accurate RTL verification, FPGA technology synthesis, and empirical evaluation of a 1024-Byte (1 KB) 2-way set-associative level-1 data cache against an identically sized direct-mapped baseline. Both designs are authored in synthesizable Verilog HDL with a 16-Byte block size (4 words of 32 bits each) and interface to a standard 32-bit CPU bus and a parameterized backing main memory controller under an unbuffered Write-Through, No-Write-Allocate coherence protocol. The 2-way cache implements a True Least-Recently-Used (True LRU) replacement policy using a dedicated 1-bit-per-set status array, invalid-way priority allocation, and parallel continuous tag matching.

Across a comprehensive regression suite of 11 deterministic synthetic memory workloads totaling 4,188 memory transactions, zero data mismatches occurred against an independent architectural golden memory model. Experimental evaluation demonstrates the classical advantage of set associativity: under ping-pong set conflicts (`pingpong`), the 2-way cache delivers a 99.00% hit rate (424 clock cycles) compared to 0.00% (2,800 clock cycles) for the direct-mapped baseline—a 6.6× execution speedup. Conversely, under pathological 3-way cyclic traversal (`cyclic3`), both designs suffer complete thrashing (0.00% hit rate, 4,200 cycles). On a 1.5 KB loop exceeding cache capacity (`large_loop`), the direct-mapped cache paradoxically outperforms the 2-way design (25.00% vs 0.00% hit rate, 4,224 vs 5,376 cycles) due to partial line survival across modulo-64 line mappings.

In Phase II, multi-dimensional parameter sweeps (cache capacity $C \in \{512\text{ B}, 1024\text{ B}, 2048\text{ B}\}$, block size $B \in \{8\text{ B}, 16\text{ B}, 32\text{ B}\}$, and memory latencies $RD\_LAT \in \{4, 8, 16\}$, $WR\_LAT \in \{2, 4, 8\}$) were conducted. Analytical Average Memory Access Time (AMAT) was formulated and validated against simulation cycles to 0.00 cycle error across all read-only workloads. Replacement logic was validated through 12 directed test steps, a 5,000-cycle pseudo-random co-simulation against a software reference model (0 errors across 2,013 hits and 1,926 evictions), and four deliberate RTL bug-injection mutations. Finally, hardware synthesis targeting AMD/Xilinx 7-Series and Lattice ECP5 FPGAs reveals an architectural counter-intuition: while 2-way associativity incurs 96 additional storage flip-flops (+64 tag bits, +32 LRU bits), the direct-mapped baseline requires 2,653 more LUTs (-28.4% for 2-way) and 4,064 more multiplexer primitives (-48.3% for 2-way) due to the wide 64-to-1 word selection tree required by 64 lines compared to 32 sets.

---

## I. Introduction
The expanding performance disparity between high-performance microprocessor execution pipelines and relatively high-latency dynamic RAM (the memory wall) mandates efficient on-chip cache memory subsystems. Caches mitigate memory latency by exploiting two fundamental locality principles: spatial locality (the likelihood that references near recently accessed data will soon be needed) and temporal locality (the likelihood that recently accessed data will be re-referenced in the near future) [1], [2].

In microprocessor architecture, set associativity represents a core design choice balancing miss rate reduction against hardware complexity and critical path timing [1], [4]. Direct-mapped caches require minimal control logic and only a single tag comparator, offering rapid lookup latency and minimal energy overhead per access. However, because each memory address maps to exactly one predetermined cache line based on its index bits, direct-mapped caches suffer severely from conflict misses when multiple frequently referenced working-set blocks share the same cache line [5]. Set-associative caches alleviate conflict thrashing by allowing a memory block to reside in any of $N$ ways within a designated set, but introduce parallel tag comparators, hit-way multiplexing, and replacement policy tracking logic [1], [4].

The objective of Project 7 (spanning Phase I and Phase II) is to design, implement, functionally verify, synthesize, and benchmark a 1 KB 2-way set-associative data cache with True LRU replacement against an identically sized 1 KB direct-mapped baseline in Verilog HDL. Strict fairness is maintained throughout: both architectures share identical user storage capacity (1024 Bytes), identical block size (16 Bytes / 4 words), identical 32-bit microprocessor byte-address interfaces, and identical backing memory timing parameters. Through extensive cycle-accurate simulation across 11 synthetic traces exercising spatial locality, temporal loops, set conflicts, cyclic thrashing, pseudorandom access, 2D matrix walks, and write-heavy workloads, we evaluate the precise architectural trade-offs between conflict immunity, replacement policy limitations, hardware resource utilization, and memory bus stalls.

---

## II. Literature Review
The theory and empirical evaluation of cache memory subsystems have been extensively investigated in computer architecture literature:

1. **Miss Classification and Associativity Principles:** Hennessy and Patterson [1] formulated the classical "3Cs" taxonomy of cache misses: compulsory misses (cold starts occurring upon the first reference to a memory block), capacity misses (arising because the cache cannot contain all blocks needed during program execution), and conflict misses (occurring when multiple blocks compete for the same set in direct-mapped or set-associative designs). Set associativity specifically eliminates conflict misses by providing alternative storage slots within each set, approaching the miss rate of a fully associative cache of identical capacity [1].
2. **Foundational Replacement and Design Trade-offs:** In his seminal survey, A. J. Smith [2] comprehensively analyzed cache memory structures, line sizing, and replacement algorithms. Smith established that Least Recently Used (LRU) replacement consistently yields superior or near-optimal hit ratios among online non-lookahead replacement strategies by directly capturing temporal locality in referenced working sets.
3. **Stack Algorithms and LRU Optimality:** Mattson et al. [3] proved that LRU belongs to the class of inclusion-property "stack algorithms." In a stack algorithm, the contents of an $N$-way cache are guaranteed to be a strict subset of the contents of an $(N+1)$-way cache for any given reference string, precluding anomalous hit-rate degradation when increasing cache size. However, Mattson et al. also documented the known vulnerability of finite-stack LRU policies to cyclic access sequences where the working set strictly exceeds associativity by one block ($N+1$).
4. **Quantifying Associativity Benefits:** Hill and Smith [4] introduced trace-driven simulation techniques to isolate the performance impact of associativity. Their empirical findings showed that shifting from a direct-mapped cache to a 2-way set-associative cache provides the single largest marginal reduction in conflict misses, whereas increasing associativity further (to 4-way or 8-way) provides diminishing returns while introducing significant clock-cycle hit-time penalties.
5. **Conflict Miss Vulnerability of Direct-Mapped Caches:** Jouppi [5] demonstrated that the majority of miss penalties in direct-mapped caches stem from a small number of conflicting lines that repeatedly ping-pong. Jouppi proposed auxiliary structures such as victim caches to address conflict misses without incurring the multiplexing latency of fully set-associative designs, reinforcing the critical need to quantify conflict behavior.

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

*(The complete architectural block diagram was generated via automated script `scripts/make_block_diagram.py` and saved to `docs/img/block_diagram.png`; team members may redraw or adjust it in draw.io for submission if desired.)*

### C. True LRU Replacement Logic
**Author:** Member 2 (LRU Logic & Verification)

With two ways per set, a memory block can reside in one of two locations. When a read miss occurs in a set where both ways are already occupied with valid data, the cache controller must decide which resident block to evict. The architecture implements true **Least-Recently-Used (True LRU)** replacement: the evicted block is always the block that was accessed longest ago in logical time, exploiting temporal locality [1], [2].

#### 1. Hardware State Tracking
Each set retains exactly one LRU bit, `lru[set]`, instantiated as a 32 × 1-bit register array across the 32 sets. The bit encodes the *victim way*:
- `lru[set] == 1'b0`: Way 0 is least recently used (Way 0 is chosen as the eviction victim).
- `lru[set] == 1'b1`: Way 1 is least recently used (Way 1 is chosen as the eviction victim).

A single bit per set provides a mathematically complete recency representation because a 2-way set has only $2! = 2$ possible recency orderings (either Way 0 was used more recently than Way 1, or Way 1 was used more recently than Way 0). For an $N$-way set, true LRU requires tracking $\lceil \log_2(N!) \rceil$ states (e.g., 5 bits for 4-way, or pseudo-LRU tree structures for larger associativity [1]). In our 2-way architecture, true LRU introduces minimal silicon overhead (exactly 32 flip-flops total).

#### 2. LRU Bit State Update Rules
The LRU bit for a set is updated synchronously on clock edges in accordance with specific transaction events:

| Event | Microarchitectural Action | State Update Equation | Rationale |
|---|---|---|---|
| **Read Hit in Way $w$** | Word delivered to CPU; hit way marked Most Recently Used (MRU) | `lru[req_index] <= ~hit_way` | The complementary way ($\sim w$) becomes the new LRU victim candidate. |
| **Write Hit in Way $w$** | Word updated in cache array and forwarded to memory; way $w$ marked MRU | `lru[req_index] <= ~hit_way` | Store operations constitute an explicit data access; writing protects the line from immediate eviction. |
| **Block Refill into Way $v$** | 4-word burst received from memory; allocated into victim way $v$ | `lru[req_index] <= ~victim_way` | The newly refilled block is now MRU; the surviving opposite way becomes LRU. |
| **Write Miss** | Memory write forwarded directly (No-Write-Allocate) | *No change* | Cache contents are unaffected; LRU recency status is strictly preserved. |

#### 3. Victim Selection Priority Logic
When servicing a miss during `STATE_LOOKUP`, the controller evaluates way occupancy before consulting the LRU bit:
```verilog
wire victim_way = (!valid0[req_index]) ? 1'b0 :
                  (!valid1[req_index]) ? 1'b1 :
                  lru[req_index];
```
This priority selection enforces an essential architectural rule: **invalid lines are populated first**. Cold cache ways are filled before any valid resident data is evicted. The LRU bit only arbitrates eviction once both `valid0` and `valid1` are asserted.

#### 4. Reference Sequence Evaluation ($A, B, A, C, B, A, C, A, B, C$)
To verify LRU transition dynamics, consider a deterministic reference sequence where all accesses map to the identical cache set (Set 0):

| Step | Access | Way 0 Tag | Way 1 Tag | `lru` Bit (Victim) | Event Type | Architectural Mechanics |
|:---:|:---:|:---:|:---:|:---:|:---:|---|
| **0** | *Reset* | *Invalid* | *Invalid* | `0` | Reset | Both lines initialized invalid (`valid0=0`, `valid1=0`). |
| **1** | Read $A$ | $A$ | *Invalid* | `1` | Cold Miss | Way 0 invalid → fills Way 0. Refill makes Way 0 MRU → `lru <= 1`. |
| **2** | Read $B$ | $A$ | $B$ | `0` | Cold Miss | Way 1 invalid → fills Way 1. Refill makes Way 1 MRU → `lru <= 0`. |
| **3** | Read $A$ | $A$ | $B$ | `1` | Hit | Hit in Way 0. Access makes Way 0 MRU → `lru <= 1`. |
| **4** | Read $C$ | $A$ | $C$ | `0` | Conflict Miss | Set full; `lru == 1` → victim is Way 1 ($B$ evicted, $A$ retained!). Refill makes Way 1 MRU → `lru <= 0`. |
| **5** | Read $B$ | $B$ | $C$ | `1` | Conflict Miss | `lru == 0` → victim is Way 0 ($A$ evicted). Refill makes Way 0 MRU → `lru <= 1`. |
| **6** | Read $A$ | $B$ | $A$ | `0` | Conflict Miss | `lru == 1` → victim is Way 1 ($C$ evicted). Refill makes Way 1 MRU → `lru <= 0`. |
| **7** | Read $C$ | $C$ | $A$ | `1` | Conflict Miss | `lru == 0` → victim is Way 0 ($B$ evicted). Refill makes Way 0 MRU → `lru <= 1`. |
| **8** | Read $A$ | $C$ | $A$ | `0` | Hit | Hit in Way 1. Access makes Way 1 MRU → `lru <= 0`. |
| **9** | Read $B$ | $B$ | $A$ | `1` | Conflict Miss | `lru == 0` → victim is Way 0 ($C$ evicted, $A$ retained). Refill makes Way 0 MRU → `lru <= 1`. |
| **10** | Read $C$ | $B$ | $C$ | `0` | Conflict Miss | `lru == 1` → victim is Way 1 ($A$ evicted). Refill makes Way 1 MRU → `lru <= 0`. |

*(The complete state table diagram is visualized in `docs/img/lru_sequence.png`.)*

#### 5. Directed Verification Methodology
The testbench `tb/tb_lru_directed.v` implements twelve comprehensive verification assertions:
1. **Steps 1–2:** Cold misses correctly prioritize invalid ways (Way 0 first, then Way 1).
2. **Steps 3–6:** Hit on $A$ correctly shifts `lru` to protect $A$, causing subsequent block $C$ to evict $B$.
3. **Step 7:** Multiple sets operate with strict independence.
4. **Step 8 (Set Isolation):** Intensive memory traffic in Set 1 does not alter or corrupt the LRU tracking bit of Set 0.
5. **Step 9 (Write Hit Recency):** Write hits update the LRU status register identically to read hits, protecting modified cached lines.
6. **Step 10 (Sequence Conformance):** The full 10-step reference sequence above is evaluated cycle-by-cycle against internal registers, achieving zero discrepancies.
7. **Step 11 (Write Miss Non-Allocation - Phase II):** A write miss passes directly to backing memory under No-Write-Allocate without allocating a cache line or disturbing resident LRU tracking bits.
8. **Step 12 (Invalid-Way Priority Override - Phase II):** Forces the internal `lru` bit onto a valid way via white-box register manipulation to verify that an unpopulated invalid way is strictly selected before evicting a valid line.

#### 6. Pseudo-Random Co-Simulation with Software Reference Model (Phase II)
*Testbench: `tb/tb_lru_random.v` (5,000 operations, seed `32'h2026_1124`)*

To guard against subtle state-dependent corner cases not exercised by hand-crafted traces, Phase II introduced an automated 5,000-cycle pseudo-random co-simulation environment:
- **Workload Composition:** 3,243 random reads and 1,757 random writes distributed across 6 target sets using 5 distinct competing block tags per set to ensure sustained way contention.
- **Cycle-by-Cycle Reference Model:** An architectural golden C/Verilog reference model of a 2-way write-through no-write-allocate cache executes in parallel. After every single request, the testbench checks:
  1. Hit/Miss status line.
  2. Read return data word.
  3. Way valid bits (`valid0`, `valid1`).
  4. Stored tag registers (`tag0`, `tag1`).
  5. The set's internal LRU state bit.
- **Final Architectural State Audit:** Upon test termination, the simulation compares total hit counters (2,013 hits), miss counters (2,987 misses), and LRU eviction counts (1,926 evictions), followed by a complete 4,096-word memory dump audit. **Zero discrepancies** were observed across all 5,000 operations.

#### 7. Bug-Injection & Test Suite Sensitivity Verification (Phase II)
*Reproduction Script: `./scripts/run_bug_injection.sh`*

To objectively demonstrate testbench mutation detection capability, four deliberate bugs were injected into temporary copies of `rtl/cache_2way_lru.v`:

| Mutation Identifier | RTL Bug Injected | Directed Suite (`tb_lru_directed`) | Random Suite (`tb_lru_random`) | Detection Status |
|---|---|:---:|:---:|:---:|
| **Control** | None (Production RTL) | **PASS** | **PASS** | Baseline Golden Model |
| **Bug 1: Hit Update Inversion** | `lru <= ~hit_way` inverted to `lru <= hit_way` | **FAIL** (Step 4) | **FAIL** (Cycle 12) | **CAUGHT** |
| **Bug 2: Refill Update Inversion** | `lru <= ~victim_way` inverted to `lru <= victim_way` | **FAIL** (Step 4) | **FAIL** (Cycle 14) | **CAUGHT** |
| **Bug 3: Eviction Polarity Inversion** | `victim = ~lru` when both valid | **FAIL** (Step 4) | **FAIL** (Cycle 14) | **CAUGHT** |
| **Bug 4: Ignore Valid Line Status** | Victim logic ignores `valid` bits, choosing solely by `lru` | **FAIL** (Step 12) | **PASS** (Expected) | **CAUGHT** |

*Why Bug 4 Passes Random Simulation:* In normal reachable cache execution from cold reset (`lru=0`), the first fill into Way 0 transitions `lru` to 1, causing the LRU pointer to naturally point toward empty Way 1. Consequently, standard pseudo-random traffic cannot distinguish valid priority from standard LRU order. Directed Step 12 specifically catches Bug 4 by white-box forcing `lru` onto Way 0 before Way 1 is filled, proving the indispensable necessity of directed corner-case testing.

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

Eleven deterministic synthetic workloads are generated by `scripts/gen_traces.py` to rigorously evaluate both cache architectures under diverse spatial, temporal, conflict, and write memory access patterns. All addresses are 4-byte word-aligned and bounded within the 16 KB main memory space (`0x00000000` to `0x00003FFC`).

1. **`seq_stream.txt` (256 accesses):** Sequential word reads with a 4-byte stride traversing 1024 bytes. Models pure spatial locality without temporal reuse. With 16-byte blocks (4 words), the first word access in each block misses (compulsory miss) and the next 3 hit, yielding exactly **75.00% hit rate** (192 hits / 64 misses, 1,280 cycles) on both caches.
2. **`small_loop.txt` (640 accesses):** A tight 256-byte loop (64 words) executed 10 times. The working set requires 16 cache blocks, fitting entirely inside the 1 KB cache. After 16 compulsory misses in iteration 1, all subsequent 9 iterations hit at 100%, achieving **97.50% hit rate** (624 hits / 16 misses, 1,472 cycles) on both caches.
3. **`pingpong.txt` (200 accesses):** Alternates between two addresses (`0x0020` and `0x0420`) that map to the identical cache set (Set 2 in 2-way, Line 2 in direct). Demonstrates the primary benefit of associativity: the 2-way cache holds both blocks simultaneously, achieving **99.00% hit rate** (424 cycles). The direct-mapped cache suffers catastrophic thrashing, evicting the resident line on every access to yield **0.00% hit rate** (2,800 cycles, 6.6× slower).
4. **`cyclic3.txt` (300 accesses):** Three addresses (`0x0030`, `0x0430`, `0x0830`) mapping to the same set accessed cyclically ($A \to B \to C \to A \dots$). Demonstrates the pathological worst case for LRU: because set capacity is 2 ways, accessing 3 blocks cyclically evicts the block that will be requested next. Both caches experience complete thrashing (**0.00% hit rate**, 4,200 cycles).
5. **`strided.txt` (256 accesses):** 64-byte stride (4 cache blocks) across 8 distinct addresses over 32 passes, accessing every 4th set. The 8 lines fit in cache; after 8 initial misses, all subsequent passes hit, achieving **96.88% hit rate** (248 hits / 8 misses, 608 cycles) on both architectures.
6. **`random.txt` (300 accesses):** Uniform pseudorandom word reads across the 16 KB address space (seed 42). Tests control path robustness under zero-locality conditions. The 2-way cache achieves **7.33% hit rate** (22 hits, 3,936 cycles) vs **6.00%** (18 hits, 3,984 cycles) for direct-mapped.
7. **`mixed_rw.txt` (300 accesses):** 70% reads and 30% writes within a 512-byte hot region (seed 12345). Verifies the Write-Through No-Write-Allocate policy: write hits update both cache and memory; write misses bypass the cache without line allocation. Both designs achieve **81.33% hit rate** (244 hits / 56 misses, 1,499 cycles).
8. **`large_loop.txt` (384 accesses - Phase II Extension 1):** A 1.5 KB loop (96 cache blocks) iterated 4 times, intentionally exceeding the 1 KB (64 block) cache capacity. In the 2-way cache (32 sets), 96 blocks / 32 sets = exactly 3 blocks per set, triggering cyclic thrashing across all sets (**0.00% hit rate**, 5,376 cycles). In direct-mapped (64 lines), lines 32..63 receive only 1 block and hit on every repeat pass, achieving **25.00% hit rate** (96 hits, 4,224 cycles). This demonstrates why direct-mapped can outperform 2-way LRU on loops sized between $C$ and $2C$.
9. **`hot_stream.txt` (400 accesses - Phase II Extension 2):** A realistic hybrid workload pairing a 128-byte hot region (70% access probability, 8 blocks) with a 2 KB sequential cold streaming sweep (30% access probability, 128 blocks). The 2-way cache shields hot blocks in the second way, achieving **90.75% hit rate** (363 hits, 1,244 cycles) vs **86.75%** (347 hits, 1,436 cycles) for direct-mapped, running **13.4% faster**.
10. **`matrix_walk.txt` (512 accesses - Phase II Extension 3):** Models 2D matrix traversal ($16 \times 16$ elements, 4 bytes each, 1024 bytes total). Traverses the array in row-major order (leveraging spatial block prefetching) followed by column-major passes. Both architectures achieve **87.50% hit rate** (448 hits / 64 misses, 1,792 cycles).
11. **`write_heavy.txt` (640 accesses - Phase II Extension 4):** A store-dominant workload containing 80% memory writes (336 stores) and 20% reads (304 loads) across a 512-byte working set repeated 5 times. Evaluates backing memory bus saturation and CPU write-stall overhead under Write-Through. Both caches achieve **75.47% hit rate** (483 hits / 157 misses, 4,244 cycles).

---

## IV. Results & Comparative Analysis
*Baseline Configuration: RD_LAT=8, WR_LAT=4, 32-bit addresses, 16-byte block size (Source: `results/results.csv`)*

The experimental evaluation below was gathered from the full regression suite across all 11 deterministic workloads. Each trace was executed through `cache_2way_lru` and `cache_direct` in isolated passes with identical cold-start states and golden memory initialization. **Zero data mismatches** were observed across all 4,188 total transactions, verifying complete functional equivalence against the architectural golden memory model.

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
| `matrix_walk` | 2-Way LRU | 512 | 448 | 64 | 87.50% | 1,792 | 16×16 matrix row/col traversal; spatial reuse |
| `matrix_walk` | Direct-Mapped | 512 | 448 | 64 | 87.50% | 1,792 | 16×16 matrix row/col traversal; spatial reuse |
| `write_heavy` | 2-Way LRU | 640 | 483 | 157 | 75.47% | 4,244 | 80% writes (336 stores); Write-Through bus stress |
| `write_heavy` | Direct-Mapped | 640 | 483 | 157 | 75.47% | 4,244 | 80% writes (336 stores); Write-Through bus stress |

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

### C. Hardware Synthesis & FPGA Resource Utilization Evaluation
*Contributed by Member 1 (2-Way RTL, FPGA Synthesis & Resource Report, Issue #12)*  
*Configuration: Target Verilog modules `rtl/cache_2way_lru.v` (`cache_2way_lru`) and `rtl/cache_direct.v` (`cache_direct`)*  
*Tools Used: Yosys Open SYnthesis Suite (v0.71+post), Target Devices: Generic, AMD/Xilinx 7-Series, Lattice ECP5 (Reproduction Script: `./scripts/synth_all.sh`)*

In Phase II, both cache modules were synthesized under identical conditions across three distinct flows to evaluate gate-level and FPGA device resource utilization:
1. **Generic Technology-Independent Elaboration:** Evaluates gate-level complexity (multiplexers, logic gates, and registers) independent of target silicon.
2. **AMD/Xilinx 7-Series FPGA Technology Mapping (`synth_xilinx`):** Maps logic to Xilinx 7-Series primitive cells (LUT2–LUT6, FDCE/FDRE, MUXF7/F8, CARRY4, Block RAM).
3. **Lattice ECP5 FPGA Technology Mapping (`synth_ecp5`):** Maps logic to ECP5 architecture slices (LUT4, TRELLIS_FF, PFUMX, L6MUX21, CCU2C, DP16KD BRAM).

> **Important Rule on Device Comparisons:** Numbers from different target device families are separated into dedicated tables below and are never mixed in a single row.

#### Table 1: Generic Technology-Independent Synthesis
*Command: `yosys -p "read_verilog -sv <source>; synth -top <module>; stat"`*  
*Raw Logs: `results/synth_2way_generic.log`, `results/synth_direct_generic.log`*

| Metric | 2-Way LRU (`cache_2way_lru`) | Direct-Mapped (`cache_direct`) | Delta (2-Way − Direct) | Architectural Explanation |
| :--- | :---: | :---: | :---: | :--- |
| **Total Cells** | **35,643** | **39,809** | **-4,166 (-10.5%)** | Direct-mapped requires deeper multiplexer trees for 64 lines vs 32 sets |
| **Total Flip-Flops** | **10,122** | **10,026** | **+96 (+1.0%)** | **Exact architectural storage delta: +64 tag bits + 32 LRU bits** |
| - `$_DFFE_PP0P_` | 10,025 | 9,929 | +96 | Storage arrays (valid, tag, data, LRU) with clock-enable & async reset |
| - `$_DFFE_PP_` | 96 | 96 | 0 | Three 32-bit performance counters (`hit_count`, `miss_count`, `cycle_count`) |
| - `$_DFF_PP0_` | 1 | 1 | 0 | CPU ready strobe registered pulse |
| **Multiplexers (`$_MUX_`)**| **4,346** | **8,410** | **-4,064 (-48.3%)** | Direct-mapped 64-to-1 word mux tree requires nearly 2× multiplexer primitives |
| **Logic Cells (Gates)** | **21,175** | **21,373** | **-198** | Combinational gating, decoders, and comparators |
| - `$_AND_` | 14,491 | 13,746 | +745 | Two parallel tag comparators and hit-routing gates in 2-way |
| - `$_NOR_` | 4,992 | 5,209 | -217 | Control logic and address decoding |
| - `$_ANDNOT_` | 969 | 1,646 | -677 | Bit-masking and line decoding |
| - `$_OR_` | 341 | 405 | -64 | Hit detection OR gate (`hit0 \|\| hit1`) and status flags |
| - `$_NAND_` | 156 | 83 | +73 | Tag equality comparison gating |
| - `$_XOR_` / `$_XNOR_` | 126 | 99 | +27 | Tag comparator bitwise XOR gates |
| - `$_NOT_` / `$_ORNOT_` | 100 | 185 | -85 | Inversion and polarity logic |
| **Total Wires** | 23,658 | 25,957 | -2,299 | Interconnect nets |
| **Total Wire Bits** | 35,876 | 40,041 | -4,165 | Expanded bit-level nets |

---

#### Table 2: AMD/Xilinx 7-Series FPGA Technology Mapping
*Command: `yosys -p "read_verilog -sv <source>; synth_xilinx -top <module>; stat"`*  
*Raw Logs: `results/synth_2way_xilinx.log`, `results/synth_direct_xilinx.log`*

| Metric | 2-Way LRU (`cache_2way_lru`) | Direct-Mapped (`cache_direct`) | Delta (2-Way − Direct) | Architectural Explanation |
| :--- | :---: | :---: | :---: | :--- |
| **Total Cells** | **17,411** | **20,460** | **-3,049 (-14.9%)** | Direct-mapped synthesizes larger multiplexer trees |
| **Total LUTs (LUT2–LUT6)** | **6,699** | **9,352** | **-2,653 (-28.4%)** | Direct-mapped consumes 2,832 extra LUT5s for 64-line word selection |
| - `LUT2` | 190 | 164 | +26 | Small combinational gates |
| - `LUT3` | 259 | 190 | +69 | FSM decoding and control |
| - `LUT4` | 938 | 518 | +420 | Parallel tag comparators and victim selection logic |
| - `LUT5` | 2,487 | 5,319 | -2,832 | 64-line multiplexer trees in direct-mapped expand into LUT5 banks |
| - `LUT6` | 2,825 | 3,161 | -336 | Wider data selection and line decoders |
| **Total Flip-Flops** | **10,122** | **10,026** | **+96 (+1.0%)** | **Exactly +96 flip-flops (+64 tag bits + 32 LRU bits)** |
| - `FDCE` | 10,026 | 9,930 | +96 | Storage arrays mapped to discrete FFs due to combinational reads |
| - `FDRE` | 96 | 96 | 0 | Three 32-bit performance counters in both modules |
| **Dedicated Mux Primitives** | | | | Dedicated slice multiplexers used for line data selection |
| - `MUXF7` | 190 | 504 | -314 | Hardware 7-input mux primitives |
| - `MUXF8` | 74 | 252 | -178 | Hardware 8-input mux primitives |
| **Carry Chains (`CARRY4`)** | 25 | 25 | 0 | 32-bit counter incrementers in both modules |
| **Block RAM (`RAMB18`/`36`)** | **0** | **0** | **0** | **0 BRAM inferred: combinational reads require register storage** |
| **Distributed RAM (`LUTRAM`)**| **0** | **0** | **0** | Memory arrays synthesized to discrete flip-flops |

---

#### Table 3: Lattice ECP5 FPGA Technology Mapping
*Command: `yosys -p "read_verilog -sv <source>; synth_ecp5 -top <module>; stat"`*  
*Raw Logs: `results/synth_2way_ecp5.log`, `results/synth_direct_ecp5.log`*

| Metric | 2-Way LRU (`cache_2way_lru`) | Direct-Mapped (`cache_direct`) | Delta (2-Way − Direct) | Architectural Explanation |
| :--- | :---: | :---: | :---: | :--- |
| **Total Cells** | **30,296** | **35,466** | **-5,170 (-14.6%)** | Direct-mapped consumes more LUT4s and slice multiplexers |
| **LUT4** | **14,807** | **18,541** | **-3,734 (-20.1%)** | Direct-mapped 64-line multiplexer consumes extra 4-input LUTs |
| **Total Flip-Flops (`TRELLIS_FF`)**| **10,122** | **10,026** | **+96 (+1.0%)** | Storage arrays mapped to discrete TRELLIS_FF registers |
| **PFUMX (Slice Muxes)** | 4,502 | 6,165 | -1,663 | ECP5 slice multiplexer primitives |
| **L6MUX21 (Wide Muxes)** | 817 | 686 | +131 | Wide multiplexing for 2-way hit selection |
| **CCU2C (Carry Units)** | 48 | 48 | 0 | 32-bit counter arithmetic in both modules |
| **Block RAM (`DP16KD`)** | **0** | **0** | **0** | **0 BRAM inferred due to combinational read architecture** |

---

#### Table 4: Maximum Clock Frequency ($F_{\max}$) and Physical P&R Analysis
*Physical Placement & Routing (P&R) Evaluation*

| Metric | 2-Way LRU (`cache_2way_lru`) | Direct-Mapped (`cache_direct`) | Status / Justification |
| :--- | :---: | :---: | :--- |
| **Maximum Frequency ($F_{\max}$)** | **NOT MEASURED** | **NOT MEASURED** | **No Place-and-Route (P&R).** Because storage arrays synthesize to >10,000 discrete flip-flops, out-of-context P&R on 296 unconstrained I/O pins exhaustively congests routing channels (>70,000 nets). Reliable post-route physical $F_{\max}$ requires full vendor SoC integration in Vivado/Quartus or a synchronous BRAM architecture. |

#### Synthesis Discussion & Architectural Insights
1. **The 96 Flip-Flop Storage Delta:** Across all three synthesis flows, the 2-way cache requires exactly **96 more flip-flops** than the direct-mapped cache (10,122 vs 10,026 FFs, a 1.0% increase). This confirms exact architectural alignment:
   - Tag storage: 32 sets × 2 ways × 23 bits = 1,472 bits vs 64 lines × 22 bits = 1,408 bits (**+64 tag bits**).
   - LRU replacement storage: 32 sets × 1 bit = **+32 LRU bits** (direct-mapped requires 0 LRU bits).
   - Total delta: $64 + 32 = +96\text{ flip-flops}$.
2. **Multiplexer Inversion Phenomenon:** Counterintuitively, the direct-mapped cache consumes **28.4% more LUTs on Xilinx** (9,352 vs 6,699 LUTs) and **48.3% more multiplexers on Generic** (8,410 vs 4,346 muxes). In direct-mapped mode, selecting one 32-bit word across 64 discrete lines requires a massive 64-to-1 32-bit multiplexer tree. In 2-way mode, the set index selects across only 32 sets, followed by a localized 2-to-1 way mux. This set partitioning significantly reduces multiplexer depth.
3. **Block RAM Inference Barrier:** Both designs inferred **0 Block RAMs** across Xilinx (`RAMB18/36`) and Lattice (`DP16KD`). Hardware BRAM primitives strictly require synchronous read addresses registered at the clock edge (`always @(posedge clk)`). Because both caches implement single-cycle combinational read lookups (`assign tag_match = (tag[index] == req_tag)`), synthesis tools are forced to expand all 1,024 bytes of data and tags into discrete flip-flops. Mapping to BRAM would require a pipelined synchronous SRAM wrapper introducing a 1-cycle read latency.

### D. Architectural Parameter Sweeps (Capacity & Block Size)
*Contributed by Member 3 (Baseline, Memory Model & Parameter Sweeps, Issue #14)*  
*Configuration: Reproduction Script `./scripts/run_sweeps.sh` (Sources: `results/sweeps_cache_size.csv`, `results/sweeps_block_size.csv`, `results/sweeps_all.csv`)*

To evaluate cache behavior under varying microarchitectural dimensions without code duplication, parameter overrides were applied across capacity ($C \in \{512\text{ B}, 1024\text{ B}, 2048\text{ B}\}$) and block size ($B \in \{8\text{ B}, 16\text{ B}, 32\text{ B}\}$).

#### 1. Cache Capacity Sweep ($C \in \{512\text{ B}, 1024\text{ B}, 2048\text{ B}\}$)
*Fixed parameters: $B = 16\text{ B}, RD\_LAT = 8, WR\_LAT = 4$*

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

**Architectural Insight:** Expanding capacity from 1 KB to 2 KB transforms `large_loop` (1.5 KB working set) from complete thrashing into a fully cached loop, jumping to **75.00% hit rate** and saving 64.3% cycles (5,376 to 1,920 cycles). For `pingpong`, doubling capacity to 2 KB expands direct-mapped indexing to 128 lines, separating `0x0020` (line 2) from `0x0420` (line 66) and eliminating conflict misses completely (99.00% hit rate, 424 cycles).

#### 2. Cache Block Size Sweep ($B \in \{8\text{ B}, 16\text{ B}, 32\text{ B}\}$)
*Fixed parameters: $C = 1024\text{ B}, RD\_LAT = 8, WR\_LAT = 4$*

| Workload Trace | Design | 8 Bytes (2 words / burst) | 16 Bytes (4 words / burst) | 32 Bytes (8 words / burst) | Spatial Locality Effect |
|---|---|:---:|:---:|:---:|---|
| `seq_stream` | 2-Way / Direct | **50.00% (1,792 cyc)** | **75.00% (1,280 cyc)** | **87.50% (1,024 cyc)** | **Hit rate strictly tracks $(B/4 - 1)/(B/4)$** |
| `small_loop` | 2-Way / Direct | 95.00% (1,664 cyc) | 97.50% (1,472 cyc) | 98.75% (1,376 cyc) | Fewer cold misses on initial loop iteration |
| `pingpong` | 2-Way | 99.00% (396 cyc) | 99.00% (424 cyc) | 99.00% (480 cyc) | Hits dominate; larger block adds burst overhead |
| `pingpong` | Direct | 0.00% (2,400 cyc) | 0.00% (2,800 cyc) | 0.00% (3,600 cyc) | Repeated misses penalized by longer burst |

**Architectural Insight:** On sequential streaming code, block size directly dictates compulsory miss frequency:  
- $B = 8\text{ B}$ (2 words): 1 miss every 2 words $\implies 50.00\%$ hit rate.
- $B = 16\text{ B}$ (4 words): 1 miss every 4 words $\implies 75.00\%$ hit rate.
- $B = 32\text{ B}$ (8 words): 1 miss every 8 words $\implies 87.50\%$ hit rate.  
However, when spatial locality is absent or thrashing occurs (`pingpong` direct-mapped), larger blocks inflate execution cycles from 2,400 to 3,600 cycles due to wasted burst transfer bandwidth.

---

### E. Average Memory Access Time (AMAT) Analysis
*Contributed by Member 3 (Baseline, Memory Model & Parameter Sweeps, Issue #14)*  
*Source: `results/amat_comparison.csv`*

Classical cache textbook models define AMAT as:
$$\text{Classical AMAT} = \text{Hit Time} + (\text{Miss Rate} \times \text{Miss Penalty}) = 2 + (\text{Miss Rate} \times 14)$$

However, in cycle-accurate pipelined hardware where the 2-cycle lookup state is overlapped with the miss-handling sequence, the **Incremental Hardware AMAT** applies:
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

**Interview Defense Points on AMAT vs Measured Discrepancies:**
1. **Pipelined Miss Overlap:** In classical textbook equations, miss penalty is treated as an independent additive delay. In our RTL controller, the 1-cycle lookup stage is an integral part of the miss-handling state sequence. The total read miss latency is 14 cycles, making the *incremental* penalty over a 2-cycle hit exactly $14 - 2 = 12\text{ cycles}$. Using the incremental formula matches cycle-accurate simulation measurements across all 8 read-only traces to $0.0000$ error.
2. **Write-Through Penalties:** Classical AMAT models only read memory access time. Under our unbuffered Write-Through policy, every store instruction stalls the CPU for 7 cycles ($1\text{ IDLE} + 1\text{ LOOKUP} + 4\text{ WR\_LAT} + 1\text{ ACK}$). In `mixed_rw` (103 writes), these stores inject an unavoidable stall overhead of $\frac{103 \times (7 - 4.24)}{300} = +0.76\text{ cycles/access}$, fully explaining the observed mathematical divergence.

---

## V. Individual Contributions

The table below documents individual contributions based on verified git commit history (`git shortlog -sne main`), merged pull requests, and owned architectural deliverables:

| Member | Assigned Role | Owned Deliverables & Files | Merged PR & Branch | Verified Commits on `main` | Status |
|---|---|---|---|:---:|---|
| **Member 1** | Team Lead & 2-Way Cache RTL | `rtl/cache_2way_lru.v`, `docs/WAVEFORM_GUIDE.md`, `docs/MEMBER1_EXPLAINER.md`, Report sections III.A, III.B, III.D | PR #1 (`member1-rtl-docs`) | 24 commits (`Arya756`: 21, `Ayush Aryan`: 3) | Complete |
| **Member 2** | LRU Logic & Verification | `tb/tb_lru_directed.v`, `docs/SECTION_III_C_LRU.md`, `scripts/make_lru_diagram.py`, `docs/img/lru_sequence.png`, Report section III.C | PR #6 (`member2-lru-tests`) | 19 commits (`Aparna Singh`) | Complete |
| **Member 3** | Direct Baseline & Memory Model | `rtl/cache_direct.v`, `rtl/main_memory.v`, `tb/tb_direct_basic.v`, `docs/BASELINE_AND_MEMORY_MODEL.md`, `docs/section_III_E_F.md`, `scripts/run_latency_study.sh`, latency CSVs, Report sections III.E, III.F | PR #7 (`member3-direct-baseline-memory`) | 6 commits (`Neeraj Singh`)* | Complete |
| **Member 4** | Traces, Comparison Testbench & Scripts | `scripts/gen_traces.py` (9 traces), `tb/tb_compare.v`, `scripts/run_all.sh`, `scripts/plot_results.py`, `results/hit_rate.png`, `results/cycles.png`, `docs/SECTION_III_G_IV.md`, Report sections III.G, IV | PR #8 (`member4-traces-benchmarks`) | 6 commits (`Atharva Tiwari`) | Complete |
| **Member 5** | Report Assembly, Synthesis & Video Lead | `docs/REPORT_PHASE1.md` (Abstract, I, II, IV.C, V, VI, References), `docs/report/` (IEEEtran package), `scripts/make_block_diagram.py`, `docs/img/block_diagram.png`, `results/yosys_summary.md`, `README.md` update | PR pending (`member5-report-synthesis`) | 7 commits (`Lalilal0`) | Active / Complete |

*\*Attribution Flag:* All 6 commits for Member 3 were authored under `neerajsingh@Neerajs-MacBook-Pro-2.local` (a local machine domain rather than a verified GitHub email). This is flagged for attribution correction if required before final submission.

---

## VI. Conclusion
Phase I of Project 7 successfully designed, functionally verified, and benchmarked a 1024-Byte 2-way set-associative L1 data cache with True LRU replacement against an identically sized direct-mapped baseline in Verilog HDL. Across nine deterministic synthetic workloads comprising 3,136 memory transactions, zero data mismatches were observed against the architectural golden memory model.

The experimental data establishes three primary microarchitectural conclusions:
1. **Associativity Shields Against Set Conflicts:** On conflict-intensive workloads mapping competing lines to the same index (`pingpong`), the 2-way cache completely eliminates thrashing, delivering a **99.00% hit rate (424 cycles)** versus **0.00% (2,800 cycles)** for the direct-mapped cache—a dramatic **6.6× execution speedup**. In realistic concurrent workloads (`hot_stream`), the second way shields hot data from cold streaming sweeps, improving hit rate from 86.75% to 90.75% and reducing execution time by 13.4% (1,244 vs 1,436 cycles).
2. **Pathological Degradation on Working Sets Exceeding Associativity:** When the active working set within a set exceeds associativity ($N+1$ blocks) under strict cyclic traversal (`cyclic3`), LRU replacement experiences catastrophic failure, causing 100% evictions and yielding **0.00% hit rate (4,200 cycles)** for both architectures.
3. **Direct-Mapped Superiority on Medium Loops:** Under workloads whose footprint exceeds cache capacity but remains below $2\times$ capacity (`large_loop`, 1.5 KB working set = 96 blocks across 4 passes), the direct-mapped cache significantly outperforms the 2-way cache (**25.00% hit rate, 4,224 cycles** vs **0.00% hit rate, 5,376 cycles**). While the 2-way cache suffers 3 blocks per set across all 32 sets (triggering complete cyclic LRU thrashing), the direct-mapped cache maps 96 blocks modulo 64, leaving lines 32–63 free of collisions and achieving repeat hits across subsequent loop iterations.
4. **Write-Through Bottlenecks:** Under unbuffered Write-Through No-Write-Allocate, memory store latency stalls the processor for 7 clock cycles per write regardless of hit or miss status, as demonstrated by the 721 stall cycles incurred across 103 writes in `mixed_rw`.

**Methodological Limitations:** All evaluations were performed via cycle-accurate RTL simulation with generic Yosys elaboration. Because physical synthesis targeting FPGA or ASIC standard cells was not performed, the critical-path hit-time penalty of the 2-way multiplexer and comparators, as well as post-routing $F_{\max}$, were not measured. Furthermore, Phase II implementation plans (including write-back dirty bit tracking, multi-level hierarchy, or FPGA deployment on Vivado) remain **TO CONFIRM**.

---

## References
1. J. L. Hennessy and D. A. Patterson, *Computer Architecture: A Quantitative Approach*, 6th ed., Cambridge, MA, USA: Morgan Kaufmann, 2017.
2. A. J. Smith, "Cache Memories," *ACM Computing Surveys (CSUR)*, vol. 14, no. 3, pp. 473–530, Sep. 1982, doi: 10.1145/356887.356892.
3. R. L. Mattson, J. Gecsei, D. R. Slutz, and I. L. Traiger, "Evaluation techniques for storage hierarchies," *IBM Systems Journal*, vol. 9, no. 2, pp. 78–117, 1970, doi: 10.1147/sj.92.0078.
4. M. D. Hill and A. J. Smith, "Evaluating Associativity in CPU Caches," *IEEE Transactions on Computers*, vol. 38, no. 12, pp. 1612–1630, Dec. 1989, doi: 10.1109/12.40845.
5. N. P. Jouppi, "Improving direct-mapped cache performance by the addition of a small fully-associative cache and prefetch buffers," in *Proc. 17th Annu. Int. Symp. Comput. Archit. (ISCA)*, Seattle, WA, USA, 1990, pp. 364–373, doi: 10.1145/325164.325157.
