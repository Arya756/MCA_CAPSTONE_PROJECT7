# Section III.E and Section III.F Technical Report Text
**Author:** Member 3 (Direct-Mapped Baseline & Memory Model)  
**Project:** Project 7 – Cache Memory Subsystem (Phase I)  
**Backup Location:** `docs/section_III_E_F.md`

---

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

---

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

