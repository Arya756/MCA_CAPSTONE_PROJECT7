# Baseline Architecture & Memory Model Documentation
**Author:** Member 3 (Direct-Mapped Baseline & Memory Model)  
**Project:** Project 7 – Cache Memory Subsystem (Phase I)

---

## 1. Architectural Baseline Equivalence Confirmation (Task 1)

> **Equivalence Confirmation Statement:**  
> The direct-mapped baseline configuration matches the 2-way set-associative cache with an identical data capacity of 1024 bytes (1 KB) and identical block granularity of 16 bytes (4 words per block). While the direct-mapped cache is organized as 64 lines (Index: 6 bits, Tag: 22 bits, Offset: 4 bits), the 2-way design is organized as 32 sets of 2 ways each (32 × 2 × 16 B = 1024 B; Index: 5 bits, Tag: 23 bits, Offset: 4 bits). Both architectures enforce a strict Write-Through, No-Write-Allocate policy with matched write latencies (4 cycles) and refill burst latencies (8 cycles). Because total user storage capacity, block sizing, and memory transaction protocols are completely symmetric, all performance differentials in hit rates and execution cycles stem strictly from set associativity and conflict miss dynamics, ensuring a completely fair, unbiased comparison.

### Parameter Comparison Matrix

| Architectural Parameter | Direct-Mapped Baseline (`cache_direct`) | 2-Way Set-Associative (`cache_2way_lru`) | Fairness Notes |
|---|---|---|---|
| **User Data Capacity** | 1024 Bytes (1 KB) | 1024 Bytes (1 KB) | Exactly Identical |
| **Block Size** | 16 Bytes (4 words) | 16 Bytes (4 words) | Identical burst refill size |
| **Total Lines / Slots** | 64 lines | 64 lines (32 sets × 2 ways) | Equal storage capacity |
| **Offset Width** | 4 bits (`addr[3:0]`) | 4 bits (`addr[3:0]`) | Bits `[3:2]` select word in block |
| **Index Width** | 6 bits (`addr[9:4]`) | 5 bits (`addr[8:4]`) | Sets = 64 / 2 = 32 sets |
| **Tag Width** | 22 bits (`addr[31:10]`) | 23 bits (`addr[31:9]`) | Direct-mapped saves 1 tag bit |
| **Write Hit Policy** | Write-Through | Write-Through | Updates cache line & main memory |
| **Write Miss Policy**| No-Write-Allocate | No-Write-Allocate | Bypasses cache directly to memory |
| **Memory Bus Interface** | 32-bit burst bus | 32-bit burst bus | Identical handshaking protocol |

---

## 2. Main Memory Subsystem & Latency Model (Task 2)

The main memory module (`rtl/main_memory.v`) models a synchronous, word-addressed backing memory system of 4096 words (16 KB) with parameterized read and write wait latencies.

### 2.1 Default Latency Configuration
- **Read Latency (`RD_LAT` = 8 clock cycles):** The delay from request initiation until the first word of a 4-word block is presented on the data bus.
- **Write Latency (`WR_LAT` = 4 clock cycles):** The wait time required to commit a 32-bit data word into the backing storage array before acknowledging completion.

### 2.2 Block-Read Transaction Protocol
When a cache experiences a read miss, it initiates a 16-byte block burst refill:
1. **Request Phase (Cycle 0):** Cache asserts `mem_req = 1`, `mem_we = 0`, and places the word-aligned address on `mem_addr`.
2. **Access Wait Phase (Cycles 1 to `RD_LAT - 1`):** Memory latches the base block address (`{mem_addr[13:4], 2'b00}`) and counts elapsed clock cycles. `mem_ready` remains `0`.
3. **Burst Delivery Phase (4 Consecutive Cycles):**
   - **Burst Cycle 0:** Memory asserts `mem_ready = 1` and outputs `word[0]` (`offset = 0x0`).
   - **Burst Cycle 1:** `mem_ready = 1`, outputs `word[1]` (`offset = 0x4`).
   - **Burst Cycle 2:** `mem_ready = 1`, outputs `word[2]` (`offset = 0x8`).
   - **Burst Cycle 3:** `mem_ready = 1`, outputs `word[3]` (`offset = 0xC`).
4. **Completion:** On the cycle after `word[3]`, `mem_ready` drops to `0`, and memory transitions back to `STATE_IDLE`.

```
Clock:     | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10| 11| 12|
mem_req:   --/----\______________________________________________
mem_we:    ------------------------------------------------------ (0 = Read)
mem_ready: ________________________________/---------------\_____
mem_rdata: XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX| W0 | W1 | W2 | W3 |X
           |<------ RD_LAT = 8 cycles ---->|<-- 4-word burst -->|
```

### 2.3 Word-Write Transaction Protocol
For both write hits and write misses under Write-Through:
1. **Request Phase (Cycle 0):** Cache asserts `mem_req = 1`, `mem_we = 1`, and presents `mem_addr` and `mem_wdata`.
2. **Write Wait Phase (Cycles 1 to `WR_LAT - 1`):** Memory waits for internal array write setup. `mem_ready` remains `0`.
3. **Commit & Acknowledge Phase (Cycle `WR_LAT`):** Memory updates `mem_array[mem_addr[13:2]] <= mem_wdata`, and pulses `mem_ready = 1` for 1 clock cycle.
4. **Return to Idle:** On the following cycle, `mem_ready` deasserts to `0`.

```
Clock:     | 0 | 1 | 2 | 3 | 4 | 5 |
mem_req:   --/----\_________________
mem_we:    --/----\_________________ (1 = Write)
mem_wdata: --[==== D_IN ====]_______
mem_ready: ________________/---\____
           |<- WR_LAT = 4 ->| ACK
```

### 2.4 Making Latencies Easy to Change
The memory latencies are parameterized at both the module and testbench levels. They can be dynamically overridden at compilation time without altering the Verilog source code using:
```bash
# Example: Compile regression suite with Read Latency = 4 cycles
iverilog -g2012 -DRD_LAT=4 rtl/cache_2way_lru.v rtl/cache_direct.v rtl/main_memory.v tb/tb_compare.v

# Example: Compile regression suite with Read Latency = 16 cycles
iverilog -g2012 -DRD_LAT=16 rtl/cache_2way_lru.v rtl/cache_direct.v rtl/main_memory.v tb/tb_compare.v

# Example: Compile regression suite with Write Latency = 2 or 8 cycles
iverilog -g2012 -DWR_LAT=2 rtl/cache_2way_lru.v rtl/cache_direct.v rtl/main_memory.v tb/tb_compare.v
iverilog -g2012 -DWR_LAT=8 rtl/cache_2way_lru.v rtl/cache_direct.v rtl/main_memory.v tb/tb_compare.v
```
Or via the automated script `scripts/run_latency_study.sh`.

---

### 2.5 Write Latency Sensitivity Study (WR_LAT = 2, 4, 8 Cycles, RD_LAT = 8)

To evaluate execution cycle sensitivity to main memory write latency under the Write-Through policy, a full regression sweep was executed with $WR\_LAT \in \{2, 4, 8\}$ clock cycles:

| Trace Name | Architecture | Accesses | Writes | Cycles (WR_LAT=2) | Cycles (WR_LAT=4) | Cycles (WR_LAT=8) | Delta (4 → 2) | Delta (4 → 8) | Analytical Verification |
|---|---|---|---|---|---|---|---|---|---|
| `seq_stream` | 2-Way LRU | 256 | 0 | 1,280 | 1,280 | 1,280 | 0 | 0 | Read-only workload |
| `seq_stream` | Direct-Mapped | 256 | 0 | 1,280 | 1,280 | 1,280 | 0 | 0 | Read-only workload |
| `small_loop` | 2-Way LRU | 640 | 0 | 1,472 | 1,472 | 1,472 | 0 | 0 | Read-only workload |
| `small_loop` | Direct-Mapped | 640 | 0 | 1,472 | 1,472 | 1,472 | 0 | 0 | Read-only workload |
| `pingpong` | 2-Way LRU | 200 | 0 | 424 | 424 | 424 | 0 | 0 | Read-only workload |
| `pingpong` | Direct-Mapped | 200 | 0 | 2,800 | 2,800 | 2,800 | 0 | 0 | Read-only workload |
| `cyclic3` | 2-Way LRU | 300 | 0 | 4200 | 4200 | 4200 | 0 | 0 | Read-only workload |
| `cyclic3` | Direct-Mapped | 300 | 0 | 4200 | 4200 | 4200 | 0 | 0 | Read-only workload |
| `strided` | 2-Way LRU | 256 | 0 | 608 | 608 | 608 | 0 | 0 | Read-only workload |
| `strided` | Direct-Mapped | 256 | 0 | 608 | 608 | 608 | 0 | 0 | Read-only workload |
| `random` | 2-Way LRU | 300 | 0 | 3,936 | 3,936 | 3,936 | 0 | 0 | Read-only workload |
| `random` | Direct-Mapped | 300 | 0 | 3,984 | 3,984 | 3,984 | 0 | 0 | Read-only workload |
| **`mixed_rw`** | **2-Way LRU** | **300** | **103** | **1,293** | **1,499** | **1,911** | **-206** | **+412** | **★ Exact: $103 \times (-2) = -206$, $103 \times (+4) = +412$** |
| **`mixed_rw`** | **Direct-Mapped** | **300** | **103** | **1,293** | **1,499** | **1,911** | **-206** | **+412** | **★ Exact: $103 \times (-2) = -206$, $103 \times (+4) = +412$** |

**Key Architectural Insight:** Under a Write-Through policy without write buffers, every memory write stalls the pipeline for $WR\_LAT$ cycles. In `mixed_rw.txt` (which contains exactly 103 store instructions), the cycle change strictly satisfies $\Delta \text{Cycles} = \text{Writes} \times \Delta WR\_LAT$. Traces without stores exhibit zero cycle variance.

---

## 3. Phase II Baseline Re-Confirmation & Parity Checklist (Task 1)

As mandated by Phase II Responsibility 1, the baseline Direct-Mapped cache (`rtl/cache_direct.v`) has been re-audited against the 2-way associative cache (`rtl/cache_2way_lru.v`) to guarantee fair comparison:

1. **Capacity Parity:**
   - `cache_direct`: $\text{CACHE\_CAPACITY} = 1024\text{ Bytes}$, $\text{BLOCK\_SIZE} = 16\text{ Bytes} \implies 64\text{ lines} \times 16\text{ B} = 1024\text{ B}$.
   - `cache_2way_lru`: $\text{CACHE\_CAPACITY} = 1024\text{ Bytes}$, $\text{BLOCK\_SIZE} = 16\text{ Bytes}$, $\text{NUM\_WAYS} = 2 \implies 32\text{ sets} \times 2\text{ ways} \times 16\text{ B} = 1024\text{ B}$.
   - **Conclusion:** Both provide identical data bit capacity (8,192 data bits).

2. **Block Sizing & Refill Protocol Parity:**
   - Both modules define $\text{WORDS\_PER\_BLOCK} = 4$ (16 Bytes / 4 Bytes per word).
   - Both utilize the identical 4-cycle sequential burst refill handshake with `main_memory.v`.

3. **Write Policy Parity:**
   - Both modules enforce **Write-Through, No-Write-Allocate**.
   - Store hits write through to memory while concurrently updating the resident block.
   - Store misses bypass the cache without allocating or fetching any line.

4. **Address Breakdown Symmetry:**
   - Offset: 4 bits in both (`addr[3:0]`).
   - Direct: 6 index bits (`addr[9:4]`), 22 tag bits (`addr[31:10]`).
   - 2-Way: 5 index bits (`addr[8:4]`), 23 tag bits (`addr[31:9]`).
   - The 1-bit difference in tag width mathematically reflects the factor-of-2 difference in set count ($64 \to 32$), ensuring zero wasted addressing space.
