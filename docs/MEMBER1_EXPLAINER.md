# Member 1 Interview-Prep Guide: 2-Way Cache & Architecture Deep-Dive

**Author:** Member 1 (Team Lead & 2-Way Cache RTL Owner)  
**Project:** Project 7 – 2-Way Set-Associative Cache with LRU vs Direct-Mapped Baseline  
**Course / Context:** University MCA Capstone Hardware Evaluation  

---

## 1. Executive Summary

As Member 1, your core technical ownership is the **2-way set-associative cache RTL (`rtl/cache_2way_lru.v`)**, the overall **hardware datapath**, and the **controller FSM**. In the technical interview, you must be able to explain every line of RTL, trace cycle-by-cycle behavior for every access type, derive the address fields from first principles, and explain our empirical benchmark results.

---

## 2. Address Bit Decomposition: Step-by-Step Derivation

Both caches provide **1024 Bytes (1 KB)** of user data capacity organized into **16-byte blocks** (4 words of 32 bits each) on a standard **32-bit address bus**.

### A. Direct-Mapped Cache (64 Lines)
1. **Total Blocks:** 1024 Bytes / 16 Bytes per block = 64 blocks = 64 lines.
2. **Block Offset:** log2(16) = **4 bits** (`addr[3:0]`).
   - `addr[1:0]`: Byte offset (word-aligned accesses have 2'b00).
   - `addr[3:2]`: Word select (selects 1 of 4 words: 0, 1, 2, or 3).
3. **Set Index:** log2(64) = **6 bits** (`addr[9:4]`), selecting lines 0 to 63.
4. **Tag:** 32 - 6 - 4 = **22 bits** (`addr[31:10]`).

### B. 2-Way Set-Associative Cache (32 Sets x 2 Ways)
1. **Total Blocks:** 1024 Bytes / 16 Bytes per block = 64 blocks.
2. **Total Sets:** 64 blocks / 2 ways per set = **32 sets**.
3. **Block Offset:** log2(16) = **4 bits** (`addr[3:0]`).
   - `addr[3:2]` selects 1 of 4 words.
4. **Set Index:** log2(32) = **5 bits** (`addr[8:4]`), selecting sets 0 to 31.
5. **Tag:** 32 - 5 - 4 = **23 bits** (`addr[31:9]`).

### C. Interview Question: "Why does the 2-way cache have a 23-bit tag while the direct-mapped cache has a 22-bit tag?"
> **Answer:**  
> Both caches hold the exact same amount of data (1024 bytes) and use the same block size (16 bytes). Because the 2-way cache places 2 blocks into each set, it only needs **32 sets** instead of 64 lines. 32 sets require only **5 index bits** (log2 of 32), whereas 64 lines require **6 index bits** (log2 of 64).  
> Because the address width is fixed at 32 bits and offset is fixed at 4 bits, the 1 bit saved from the index field shifts directly into the tag field:
> - Direct-Mapped: 32 - 6 - 4 = 22 tag bits
> - 2-Way Cache: 32 - 5 - 4 = 23 tag bits

---

## 3. Why True LRU Needs Exactly 1 Bit Per Set for 2 Ways

### Theoretical Principle
For an N-way set-associative cache, full LRU requires encoding the permutation order of all N ways. The number of possible access orderings is N! (factorial). The minimum number of state bits required is ceiling(log2(N!)).

For a 2-way cache (N = 2):
ceiling(log2(2!)) = ceiling(log2(2)) = **1 bit per set**.

### Hardware Implementation
In each set, there are only two ways: Way 0 and Way 1. If Way 0 is accessed, Way 1 is automatically the least recently used. If Way 1 is accessed, Way 0 is automatically the least recently used.

In `rtl/cache_2way_lru.v`:
```verilog
reg lru [0:NUM_SETS-1];
```
- `lru[set] == 1'b0`: Way 0 is LRU (victim is Way 0).
- `lru[set] == 1'b1`: Way 1 is LRU (victim is Way 1).

**The LRU Update Rule:**
Whenever a way is accessed (read hit, write hit, or refill):
`lru[set] <= ~accessed_way`
- If Way 0 was accessed (`accessed_way = 0`), `lru <= ~0 = 1` (Way 1 becomes the next victim).
- If Way 1 was accessed (`accessed_way = 1`), `lru <= ~1 = 0` (Way 0 becomes the next victim).

**Victim Selection Priority:**
```verilog
wire victim_way = (!valid0[req_index]) ? 1'b0 :
                  (!valid1[req_index]) ? 1'b1 :
                  lru[req_index];
```
An invalid (empty) way is always filled first before evicting any valid block. If both ways are valid, the True LRU bit decides.

---

## 4. Cycle-by-Cycle Transaction Walkthroughs

The simulation clock period is **10 ns** (100 MHz). Every latency below has been verified in RTL simulation:

### A. Read Hit (Measured: Exactly 2 Clock Cycles = 20 ns)
1. **Cycle 1 (`STATE_IDLE` to `STATE_LOOKUP`):**  
   CPU asserts `cpu_req = 1`, `cpu_we = 0`, and drives `cpu_addr`.  
   At the rising clock edge, the cache samples `cpu_req == 1`, latches address into `req_addr`, and moves to `STATE_LOOKUP`.
2. **Cycle 2 (`STATE_LOOKUP` to `STATE_IDLE`):**  
   The parallel comparators evaluate:
   - `hit0 = valid0[index] && (tag0[index] == req_tag)`
   - `hit1 = valid1[index] && (tag1[index] == req_tag)`
   Because the tag matches in one of the ways (`hit == 1`):
   - The hit-way multiplexer steers `data0` (or `data1`) to `cpu_rdata`.
   - The LRU bit updates: `lru[index] <= ~hit_way`.
   - `cpu_ready <= 1'b1` is asserted.
   - The controller transitions directly back to `STATE_IDLE`.  
   *Handshake completed at the end of Cycle 2.*

---

### B. Read Miss (Measured: Exactly 14 Clock Cycles = 140 ns)
1. **Cycle 1 (45 ns to 55 ns, `IDLE` to `LOOKUP`):**  
   CPU asserts `cpu_req = 1`. Cache latches inputs, moves to `STATE_LOOKUP`.
2. **Cycle 2 (55 ns to 65 ns, `LOOKUP` to `MISS_FETCH`):**  
   Tag comparison evaluates: `hit0 = 0`, `hit1 = 0` (miss).  
   Cache registers miss, asserts `mem_req <= 1'b1`, `mem_we <= 1'b0`, `mem_addr <= {req_addr[31:4], 4'b0000}`, and enters `STATE_MISS_FETCH`.
3. **Cycle 3 (65 ns to 75 ns, Memory Request Latch):**  
   `main_memory` detects `mem_req == 1`, latches block address, sets `timer <= 1`, and enters wait state. Cache deasserts `mem_req <= 0`.
4. **Cycles 4 to 9 (75 ns to 135 ns, Memory Wait Latency):**  
   `main_memory` counts `timer` from 2 up to 7 (6 wait cycles) satisfying `RD_LAT = 8`.
5. **Cycle 10 (135 ns to 145 ns, Burst Word 0):**  
   Memory asserts `mem_ready <= 1'b1`, drives Word 0. Cache latches Word 0 into `refill_buf[0]`.
6. **Cycle 11 (145 ns to 155 ns, Burst Word 1):**  
   Memory drives Word 1 (`mem_ready = 1`). Cache latches Word 1 into `refill_buf[1]`.
7. **Cycle 12 (155 ns to 165 ns, Burst Word 2):**  
   Memory drives Word 2 (`mem_ready = 1`). Cache latches Word 2 into `refill_buf[2]`.
8. **Cycle 13 (165 ns to 175 ns, Burst Word 3, Refill & Respond):**  
   Memory drives Word 3 (`mem_ready = 1`).  
   Cache detects `refill_count == 3` (final word):
   - Selects victim way (`victim_way`).
   - Writes all 4 words into victim way data array (`refill_buf[0..2]` + incoming Word 3).
   - Writes `tag` and sets `valid = 1`.
   - Updates LRU bit: `lru[index] <= ~victim_way`.
   - Forwards requested word to `cpu_rdata`.
   - Asserts `cpu_ready <= 1'b1`.
   - Transitions to `STATE_IDLE`.
9. **Cycle 14 (175 ns to 185 ns, Handshake Completion):**  
   CPU samples `cpu_ready == 1`, reads `cpu_rdata`, and drops `cpu_req = 0`.

Total Read Miss Latency = 1 + 1 + 1 + 6 + 4 + 1 = **14 Clock Cycles (140 ns)**.

---

### C. Write Hit (Measured: Exactly 7 Clock Cycles = 70 ns)
*Policy: Write-Through, No-Write-Allocate.*
1. **Cycle 1 (45 ns to 55 ns, `IDLE` to `LOOKUP`):**  
   CPU asserts `cpu_req = 1`, `cpu_we = 1`, `cpu_wdata`. Cache latches inputs into `req_addr`, `req_wdata`.
2. **Cycle 2 (55 ns to 65 ns, `LOOKUP` to `WRITE_THROUGH`):**  
   Tag compare is a HIT. Cache writes the updated word into the matching cache way, updates `lru[index] <= ~hit_way`, asserts `mem_req <= 1'b1, mem_we <= 1'b1`, and enters `STATE_WRITE_THROUGH`.
3. **Cycle 3 (65 ns to 75 ns, Memory Cycle 1 of 4):**  
   `main_memory` samples `mem_req == 1, mem_we == 1`, latches write address and data, and sets `timer <= 1` in `STATE_WRITE_WAIT`. Cache drops `mem_req <= 0`.
4. **Cycle 4 (75 ns to 85 ns, Memory Cycle 2 of 4):**  
   `main_memory` in `STATE_WRITE_WAIT` increments `timer` to 2.
5. **Cycle 5 (85 ns to 95 ns, Memory Cycle 3 of 4):**  
   `main_memory` in `STATE_WRITE_WAIT` increments `timer` to 3.
6. **Cycle 6 (95 ns to 105 ns, Memory Cycle 4 of 4):**  
   `main_memory` reaches `timer >= WR_LAT - 1` (3 >= 3), commits write to `mem_array`, asserts `mem_ready <= 1'b1`, and returns to `STATE_IDLE`. Cache in `STATE_WRITE_THROUGH` detects `mem_ready == 1`, asserts `cpu_ready <= 1'b1`, and transitions to `STATE_IDLE`.
7. **Cycle 7 (105 ns to 115 ns, Handshake Completion):**  
   `cpu_ready` is high on the CPU bus. CPU detects `cpu_ready == 1`, completes the write transaction, and drops `cpu_req = 0`.

Total Write Hit Latency = 1 + 1 + 4 (memory latency) + 1 = **7 Clock Cycles (70 ns)**.

---

### D. Write Miss (Measured: Exactly 7 Clock Cycles = 70 ns)
*Under No-Write-Allocate, a write miss does NOT fetch or allocate a block.*
1. **Cycle 1 (`IDLE` to `LOOKUP`):** CPU asserts request (`cpu_req = 1, cpu_we = 1`).
2. **Cycle 2 (`LOOKUP` to `WRITE_THROUGH`):**  
   Tag compare is a MISS. Because policy is no-write-allocate:
   - Cache data arrays are **NOT** modified.
   - Cache tags and valid bits are **NOT** modified.
   - LRU bit is **NOT** modified.
   - Controller forwards the word write directly to memory: `mem_req <= 1'b1, mem_we <= 1'b1`.
3. **Cycles 3 to 6 (Memory Write Execution, 4 cycles):**  
   `main_memory` executes the exact same 4-cycle write sequence as Write Hit.
4. **Cycle 7 (Handshake Completion):**  
   `cpu_ready` is sampled by CPU, completing transaction.

Total Write Miss Latency = **7 Clock Cycles (70 ns)**.

---

## 5. Benchmark Deep-Dive: Real Results & Explanations

Here are our actual empirical results from `results/results.csv`:

| Workload Trace | Accesses | 2-Way LRU Hits | Direct Hits | 2-Way Cycles | Direct Cycles | Cycle Ratio |
|---|---|---|---|---|---|---|
| `seq_stream.txt` | 256 | 192 (75.00%) | 192 (75.00%) | 1,280 | 1,280 | 1.0x (Identical) |
| `small_loop.txt` | 640 | 624 (97.50%) | 624 (97.50%) | 1,472 | 1,472 | 1.0x (Identical) |
| `pingpong.txt` | 200 | 198 (99.00%) | 0 (0.00%) | **424** | **2,800** | **6.6x faster on 2-way!** |
| `cyclic3.txt` | 300 | 0 (0.00%) | 0 (0.00%) | 4,200 | 4,200 | 1.0x (Both thrash) |
| `strided.txt` | 256 | 248 (96.88%) | 248 (96.88%) | 608 | 608 | 1.0x (Identical) |
| `random.txt` | 300 | 22 (7.33%) | 18 (6.00%) | 3,936 | 3,984 | 2-Way slightly faster |
| `mixed_rw.txt` | 300 | 244 (81.33%) | 244 (81.33%) | 1,499 | 1,499 | 1.0x (Identical) |

### A. Why 2-Way Cache Dominates on `pingpong.txt` (424 vs 2,800 cycles)
- **The Pattern:** The trace alternates repeatedly between two addresses:
  - Address A: `0x00000020` (Set index 2, Tag 0)
  - Address B: `0x00000420` (Set index 2, Tag 2 in 2-way; Line index 2, Tag 1 in Direct)
- **Direct-Mapped Behavior:**  
  Direct-mapped has only 1 line at index 2. Access A refills line 2. Next access B evicts A. Next access A evicts B. Every single access is a conflict miss!
  Hits = 0, Misses = 200 -> Cycles = 200 x 14 = **2800 cycles**.
- **2-Way Set-Associative Behavior:**  
  Set 2 has two ways. First access A fills Way 0 (cold miss). Second access B fills Way 1 (cold miss). Both blocks are now resident in the cache simultaneously! All remaining 198 accesses are hits!
  Hits = 198, Misses = 2 -> Cycles = (198 x 2) + (2 x 14) = 396 + 28 = **424 cycles**.
- **Conclusion:** Set associativity completely eliminates ping-pong conflict thrashing, yielding a **6.6x performance speedup**.

### B. Why `cyclic3.txt` Destroys LRU Performance (0% Hit Rate)
- **The Pattern:** 3 distinct addresses mapping to Set 3 (`0x0030`, `0x0430`, `0x0830`), accessed cyclically:
  A -> B -> C -> A -> B -> C -> A ...
- **What Happens Cycle-by-Cycle in 2-Way LRU:**
  1. Access A: fills Way 0. LRU victim = Way 1.
  2. Access B: fills Way 1. LRU victim = Way 0 (since Way 1 was just used).
  3. Access C: Set 3 is full! The victim is Way 0 (holds A). A is evicted, Way 0 gets C. LRU victim = Way 1.
  4. Access A: A was just evicted! Miss! The victim is Way 1 (holds B). B is evicted, Way 1 gets A. LRU victim = Way 0.
  5. Access B: B was just evicted! Miss! The victim is Way 0 (holds C). C is evicted...
- **The Mathematical Rule:**  
  A cyclic reference pattern of length N + 1 on an N-way set-associative cache under LRU replacement is the **pathological worst case**. The block accessed at each step is always the one that was evicted N accesses ago. Hit rate drops to **0.00%**.

---

## 6. Interview Quick-Fire Questions & Cheat-Sheet

**Q1: What are the states of your cache controller?**  
> "Our implementation uses 4 states: `IDLE`, `LOOKUP`, `MISS_FETCH`, and `WRITE_THROUGH`. We combined the hit response directly into `LOOKUP` to achieve a 2-cycle hit, and refill directly on the 4th burst word in `MISS_FETCH` to avoid bubble states."

**Q2: What is the write policy, and why did you choose it?**  
> "Both caches use Write-Through, No-Write-Allocate. Write-through ensures main memory is always coherent with cache data without needing dirty bits or writeback buffers. No-write-allocate avoids refilling full 16-byte blocks on write misses, preventing cache pollution from transient writes. Both caches use the exact same policy to ensure a fair comparison."

**Q3: How do you select the victim on a miss?**  
> "First, we check if either way is invalid: if Way 0 is empty (`!valid0`), we pick Way 0; else if Way 1 is empty (`!valid1`), we pick Way 1. Only if both ways are valid do we read the LRU bit (`lru[set]`). This prevents evicting valid data when an empty line is available."

**Q4: How does `main_memory` deliver data on a block read?**  
> "After a parameterized latency of `RD_LAT = 8` clock cycles, `main_memory` bursts 4 consecutive 32-bit words over 4 clock cycles, pulsing `mem_ready = 1` for each word. The cache latches each word into a refill buffer and commits the block on the 4th word."
