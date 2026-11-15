# GTKWave Waveform Inspection Guide: Project 7
**Owner:** Member 1 (Team Lead & 2-Way Cache RTL)  
**Simulation Target:** `tb/tb_lru_directed.v`  
**Dumpfile:** `results/lru_directed.vcd`  
**Clock Period:** 10 ns (100 MHz, `#5 clk = ~clk` in `tb_lru_directed.v`, timescale 1ns / 1ps)

---

## 1. Opening the Waveform in GTKWave

Run the regression or compile and run the directed testbench to generate the VCD file:
```bash
./scripts/run_all.sh
# Or compile tb_lru_directed directly:
iverilog -g2012 -o lru_test.vvp rtl/cache_2way_lru.v rtl/main_memory.v tb/tb_lru_directed.v
vvp lru_test.vvp
```

Open the resulting VCD in GTKWave:
```bash
gtkwave results/lru_directed.vcd
```

---

## 2. Signal Selection Checklist

In the GTKWave **SST** (left pane), navigate to `tb_lru_directed` and its sub-module `uut_cache`. Drag the following signals into the waveform display area:

| Group | Signal Path | Display Format | What to Observe |
|---|---|---|---|
| **Clock & Reset** | `tb_lru_directed.clk` | Binary | 10 ns period clock reference |
| | `tb_lru_directed.rst` | Binary | Active-high reset pulse (deasserts at t = 45 ns) |
| **CPU Bus** | `tb_lru_directed.cpu_req` | Binary | Request strobe from CPU |
| | `tb_lru_directed.cpu_we` | Binary | 0 = Read, 1 = Write |
| | `tb_lru_directed.cpu_addr[31:0]` | Hexadecimal | Target byte address |
| | `tb_lru_directed.cpu_ready` | Binary | Single-cycle handshake completion pulse |
| | `tb_lru_directed.cpu_rdata[31:0]` | Hexadecimal | 32-bit data word returned to CPU |
| **2-Way Controller** | `tb_lru_directed.uut_cache.state[2:0]` | Decimal / Hex | 0 = IDLE, 1 = LOOKUP, 2 = MISS_FETCH, 3 = WRITE_THROUGH |
| | `tb_lru_directed.uut_cache.hit0` | Binary | Tag match comparator output for Way 0 |
| | `tb_lru_directed.uut_cache.hit1` | Binary | Tag match comparator output for Way 1 |
| | `tb_lru_directed.uut_cache.lru[0]` | Binary | True LRU bit for Set 0 (0 = Way 0 victim, 1 = Way 1 victim) |
| **Memory Bus** | `tb_lru_directed.mem_req` | Binary | Memory burst request strobe |
| | `tb_lru_directed.mem_ready` | Binary | Memory ready pulse / burst strobe |
| | `tb_lru_directed.mem_rdata[31:0]` | Hexadecimal | 4-word burst data arriving from memory |

---

## 3. Screenshot 1: Read MISS (Step 1 Cold Miss on Addr A)

### Exact Simulation Timing (from `results/lru_directed.vcd`)
- **Target Address:** `ADDR_A = 32'h0000_0200` (Tag = 1, Set Index = 0, Word Offset = 0)
- **Start Time:** 45 ns (CPU asserts `cpu_req = 1`, `cpu_we = 0`, `cpu_addr = 0x00000200`)
- **Lookup Phase:** 45 ns to 55 ns
  - `state` transitions from `IDLE` to `LOOKUP`.
  - Tag comparators evaluate: `hit0 = 0`, `hit1 = 0` (Set 0 currently empty).
- **Miss Fetch & Bus Request:** 55 ns to 65 ns
  - Cache transitions to `MISS_FETCH` (`state = 2`).
  - Cache asserts `mem_req = 1`, `mem_addr = 0x00000200`.
- **Memory Latency Wait:** 65 ns to 135 ns (7 clock cycles)
  - `main_memory` waits `RD_LAT` cycles before driving data.
- **4-Word Block Burst:** 135 ns to 175 ns (4 clock cycles)
  - Memory pulses `mem_ready = 1` for 4 consecutive clock cycles delivering words 0, 1, 2, 3 (`0xAAAA0001`, etc.).
- **Refill, LRU Update & Completion:** 175 ns to 185 ns
  - Word 3 arrives. Cache refills Way 0, sets `valid0[0] = 1`, `tag0[0] = 1`.
  - Cache updates LRU bit: `lru[0] <= 1'b1` (Way 1 becomes the next LRU victim).
  - Cache asserts `cpu_ready = 1` and returns `cpu_rdata = 0xAAAA0001`.
  - At 185 ns, CPU samples `cpu_ready = 1` and drops `cpu_req`.
- **Total Measured Latency:** 140 ns = 14 clock cycles.

### GTKWave Zoom & Screenshot Settings
- In the GTKWave toolbar, set Zoom Range from 30 ns to 200 ns.
- Verify cursor is placed at 175 ns (when `cpu_ready` asserts).
- Export / Take screenshot and save to:
  `docs/img/waveform_miss.png`

---

## 4. Screenshot 2: Read HIT (Step 3 Read Hit on Addr A)

### Exact Simulation Timing (from `results/lru_directed.vcd`)
- **Target Address:** `ADDR_A = 32'h0000_0200` (Tag = 1, Set Index = 0, Word Offset = 0)
- **Start Time:** 365 ns (CPU asserts `cpu_req = 1`, `cpu_we = 0`, `cpu_addr = 0x00000200`)
- **Lookup Phase:** 365 ns to 375 ns
  - `state` transitions to `LOOKUP`.
  - Parallel tag comparators evaluate: `hit0 = 1` immediately (Way 0 valid and holds Tag 1), `hit1 = 0`.
- **Hit Respond & LRU Toggle:** 375 ns to 385 ns
  - Hit-way multiplexer selects Way 0 data word (`0xAAAA0001`).
  - Cache asserts `cpu_ready = 1`.
  - Cache updates LRU bit: `lru[0] <= ~hit_way = ~0 = 1'b1` (Way 1 is confirmed as the LRU victim).
  - Cache transitions directly back to `IDLE`.
- **Completion:** At 385 ns, CPU detects `cpu_ready = 1`, latches read data, and completes access.
- **Total Measured Latency:** 20 ns = 2 clock cycles.

### GTKWave Zoom & Screenshot Settings
- In the GTKWave toolbar, set Zoom Range from 350 ns to 400 ns.
- Place cursor at 375 ns (showing `hit0 = 1` and `cpu_ready = 1`).
- Export / Take screenshot and save to:
  `docs/img/waveform_hit.png`
