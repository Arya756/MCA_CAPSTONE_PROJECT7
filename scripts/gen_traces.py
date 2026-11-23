#!/usr/bin/env python3
"""
Trace Generator for Cache Evaluation
Project 7 - 2-Way Set-Associative vs Direct-Mapped Cache
Owner: Member 4 (Traces, Comparison Testbench, Scripts)

Generates 11 deterministic memory access traces into traces/ directory:
1. seq_stream.txt:   Sequential word accesses with 4B stride (~75% hit rate).
2. small_loop.txt:   Tight 256B loop that fits inside 1KB cache (~97.5% hit rate).
3. pingpong.txt:     Alternating 2 addresses in same set (favors 2-way: 99% vs 0%).
4. cyclic3.txt:      3-way cyclic conflict on same set (hurts LRU: 0% hit rate).
5. strided.txt:      64B strided access, hitting every 4th set.
6. random.txt:       Deterministic uniform random word accesses (seed 42).
7. mixed_rw.txt:     Hot region with 70% reads and 30% writes (tests write-through).
8. large_loop.txt:   ~1.5KB loop exceeding cache capacity (capacity/conflict misses).
9. hot_stream.txt:   Read-mostly stream with a hot 128B region + cold 2KB sweep.
10. matrix_walk.txt: Row-major then column-major walk of a 16x16 word matrix.
11. write_heavy.txt: Write-intensive stream exercising write-through on most accesses.

All addresses are word-aligned and strictly kept within the 4096-word (16 KB)
main_memory capacity range: 0x00000000 to 0x00003FFC.

Phase II additions (Member 4):
  - matrix_walk: demonstrates spatial locality gap between row-major (good) and
    column-major (bad) traversal patterns on a 16x16 matrix.
  - write_heavy: stresses the write-through no-write-allocate policy; writes do
    not load a block on a miss, so hit rate reflects only reads.
"""

import os
import random

TRACES_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "traces")
MEM_MAX_ADDR = 4096 * 4 - 4  # 0x00003FFC (16 KB range, word-aligned)

def validate_addr(addr):
    assert 0 <= addr <= MEM_MAX_ADDR, f"Address 0x{addr:08X} out of main memory range [0, 0x{MEM_MAX_ADDR:08X}]!"
    assert (addr % 4) == 0, f"Address 0x{addr:08X} is not 4-byte word aligned!"
    return addr

def write_trace(filename, description, operations):
    filepath = os.path.join(TRACES_DIR, filename)
    with open(filepath, "w") as f:
        f.write(f"# Trace: {filename}\n")
        f.write(f"# Description: {description}\n")
        f.write("# Format: R <hex_addr> | W <hex_addr> <hex_data>\n")
        for op in operations:
            if op[0] == "R":
                addr = validate_addr(op[1])
                f.write(f"R {addr:08X}\n")
            elif op[0] == "W":
                addr = validate_addr(op[1])
                data = op[2] & 0xFFFFFFFF
                f.write(f"W {addr:08X} {data:08X}\n")
    print(f"Generated {filename} ({len(operations)} operations)")

def gen_seq_stream():
    """
    T1: Sequential Stream (256 operations)
    Locality Pattern: High spatial locality, zero temporal locality. Stride = 4 bytes.
    Expected Result: Since each block is 16 bytes (4 words), the first access to a block
    misses and refills, while the next 3 accesses hit. Expected hit rate is exactly ~75%
    for both caches.
    """
    ops = []
    # 256 consecutive word reads (1024 bytes total, addresses 0x0000 to 0x03FC)
    for i in range(256):
        addr = i * 4
        ops.append(("R", addr))
    write_trace("seq_stream.txt", "Sequential stream with 4B stride (~75% hit rate)", ops)

def gen_small_loop():
    """
    T2: Small Loop (640 operations)
    Locality Pattern: Strong temporal and spatial locality. Working set = 256 bytes
    (16 cache blocks of 64 words total), looped 10 times.
    Expected Result: Working set (256B) fits easily inside the 1KB cache. The first
    iteration incurs 16 cold misses, and all subsequent 9 iterations achieve 100% hits.
    Overall expected hit rate is (640 - 16) / 640 = 97.5% on both caches.
    """
    ops = []
    base_addr = 0x0400  # Starts at 1 KB offset
    num_words = 64      # 64 words = 256 bytes
    iterations = 10
    for _ in range(iterations):
        for w in range(num_words):
            ops.append(("R", base_addr + w * 4))
    write_trace("small_loop.txt", "256B loop executed 10 times (~97.5% hit rate)", ops)

def gen_pingpong():
    """
    T3: Ping-Pong Conflict (200 operations)
    Locality Pattern: Alternates between two memory addresses mapping to the SAME line (Line 2 in direct)
    and SAME set (Set 2 in 2-way):
      - Addr A: 0x0020 (Line 2, Tag 0 in direct; Set 2, Tag 0 in 2-way)
      - Addr B: 0x0420 (Line 2, Tag 1 in direct; Set 2, Tag 2 in 2-way)
    Expected Result:
      - 2-Way Set-Associative: Way 0 holds Addr A, Way 1 holds Addr B. After 2 cold misses,
        both blocks remain cached in the 2 ways -> 198 hits / 200 = 99.0% hit rate!
      - Direct-Mapped: Only 1 line per set. Every access evicts the previous block,
        thrashing the single line -> 0 hits / 200 = 0.0% hit rate!
    """
    ops = []
    addr_a = 0x0020
    addr_b = 0x0420
    for _ in range(100):
        ops.append(("R", addr_a))
        ops.append(("R", addr_b))
    write_trace("pingpong.txt", "Ping-pong between two addresses in Set 2 (favors 2-way: 99% vs 0%)", ops)

def gen_cyclic3():
    """
    T4: 3-Way Cyclic Conflict (300 operations)
    Locality Pattern: 3 distinct addresses mapping to the SAME set (Set 3 in 2-way, Line 3 in direct),
    accessed cyclically in sequence:
      - Addr A: 0x0030
      - Addr B: 0x0430
      - Addr C: 0x0830
    Expected Result:
      - Direct-Mapped: Thrashes completely (0% hit rate after cold misses).
      - 2-Way Cache with LRU: 2-way capacity is 2 blocks per set. Cyclic access of length 3
        (A -> B -> C -> A -> B -> C...) always accesses the block that was evicted 2 steps ago.
        This is the pathological worst-case for LRU replacement -> 0% hit rate after cold misses!
    """
    ops = []
    addrs = [0x0030, 0x0430, 0x0830]
    for _ in range(100):
        for a in addrs:
            ops.append(("R", a))
    write_trace("cyclic3.txt", "3-way cyclic conflict on Set 3 (hurts LRU replacement)", ops)

def gen_strided():
    """
    T5: Strided Access (256 operations)
    Locality Pattern: Stride of 64 bytes (4 cache blocks of 16B each).
    Since index is bits [8:4] for 2-way cache, a 64-byte stride advances the set index
    by 64 / 16 = 4 sets. Thus it accesses every 4th set (Set 0, 4, 8, 12, ...).
    Expected Result: Repeated sweeps over 8 strided sets (512 bytes footprint). Both
    caches retain these 8 lines across sweeps, achieving high hit rates on repeat passes.
    """
    ops = []
    base = 0x0100
    stride = 64  # 64 bytes = 4 cache blocks -> hits every 4th set
    points = 8
    passes = 32
    for _ in range(passes):
        for p in range(points):
            ops.append(("R", base + p * stride))
    write_trace("strided.txt", "64B strided access hitting every 4th set", ops)

def gen_random():
    """
    T6: Pseudorandom Access (300 operations)
    Locality Pattern: Uniform random word accesses generated with fixed deterministic seed (42).
    Addresses are uniformly distributed across the 16KB address space.
    Expected Result: Poor temporal and spatial locality. Stress test for cache control logic,
    hit rates typically between 5% and 15%. Verifies functional robustness and timing across random interleavings.
    """
    random.seed(42)
    ops = []
    for _ in range(300):
        word_idx = random.randint(0, 4095)
        addr = word_idx * 4
        ops.append(("R", addr))
    write_trace("random.txt", "Deterministic uniform random word accesses (seed 42)", ops)

def gen_mixed_rw():
    """
    T7: Mixed Read/Write Access (300 operations)
    Locality Pattern: Hot memory region of 512 bytes (32 blocks, 128 words from 0x0800 to 0x09FC).
    70% Reads, 30% Writes.
    Expected Result: Verifies the Write-Through No-Write-Allocate policy:
      - Write hits update cache and write-through to main memory.
      - Write misses go directly to memory without cache allocation.
      - Subsequent reads verify that data written to memory or cache is read back correctly.
    """
    random.seed(12345)
    ops = []
    base = 0x0800
    num_words = 128
    for i in range(300):
        addr = base + (random.randint(0, num_words - 1) * 4)
        if random.random() < 0.30:
            data = 0xAA000000 | (i & 0x00FFFFFF)
            ops.append(("W", addr, data))
        else:
            ops.append(("R", addr))
    write_trace("mixed_rw.txt", "Hot region with 70% reads and 30% writes (tests write-through)", ops)

def gen_large_loop():
    """
    T8: Large Loop (~1.5 KB Working Set) (400 operations)
    Locality Pattern: Strong temporal locality BUT working set EXCEEDS 1 KB cache
    capacity. A loop of 384 words = 1536 bytes (96 cache blocks of 16B each)
    is iterated 4 times. Since the working set (1.5 KB) exceeds the cache
    capacity (1 KB), conflict and capacity misses are expected.
    Expected Result:
      - Direct-Mapped (64 lines): 1536B / 16B = 96 blocks need 96 lines,
        but only 64 lines are available. 32 blocks (33%) will thrash on each
        pass. First pass: 96 cold misses. Subsequent passes: ~32 conflict
        misses per pass from the 32 contending lines.
      - 2-Way (32 sets, 64 blocks total): 96 blocks in 32 sets = 3 blocks per
        set on average. Some sets see 2 or fewer (all cached), while some see
        3+ (LRU evictions). The 2-way cache should have noticeably fewer
        conflict misses than direct-mapped due to the extra associativity
        absorbing some of the conflicts.
    """
    ops = []
    base_addr = 0x0000
    num_words = 384  # 384 words = 1536 bytes = 1.5 KB
    iterations = 4
    # 4 passes over 1.5 KB data region to stress capacity/conflict misses
    for _ in range(iterations):
        # Read every 4th word (one per block) to maximize block coverage
        # while keeping operation count manageable
        for w in range(num_words):
            if w % 4 == 0:  # Sample one word per block
                ops.append(("R", base_addr + w * 4))
    write_trace("large_loop.txt",
                "1.5KB loop exceeding cache capacity (tests capacity/conflict misses)", ops)


def gen_hot_stream():
    """
    T9: Read-Mostly Stream with Hot Region (400 operations)
    Locality Pattern: Models a realistic workload with a HOT region that is
    accessed frequently (high temporal locality) and a COLD streaming region
    that is traversed linearly (high spatial, low temporal locality).
    - Hot Region: 128 bytes (8 blocks) at addresses 0x1000-0x107F, accessed
      ~70% of the time with random reads within the region.
    - Cold Stream: 2048 bytes (128 blocks) at addresses 0x2000-0x27FF,
      accessed ~30% of the time with sequential reads that advance linearly.
    Expected Result:
      - The hot region (128B = 8 blocks) fits entirely within 1 KB cache in
        both designs, so hot region accesses should be mostly hits after warmup.
      - The cold stream sweeps through many sets. In the direct-mapped cache,
        cold stream blocks may conflict with hot region blocks depending on
        index mapping, potentially evicting hot data. In the 2-way cache, the
        extra way provides a buffer to keep hot blocks cached even as cold
        stream data flows through the same sets.
      - The 2-way cache should show a measurable hit rate advantage over the
        direct-mapped cache due to better conflict tolerance for the hot
        region under cold stream pressure.
    """
    random.seed(99999)
    ops = []
    hot_base = 0x1000   # Hot region: 128 bytes (0x1000 to 0x107F)
    hot_words = 32       # 32 words = 128 bytes
    cold_base = 0x2000   # Cold stream: 2048 bytes (0x2000 to 0x27FF)
    cold_words = 512     # 512 words = 2048 bytes
    cold_ptr = 0         # Linear pointer into cold stream

    for _ in range(400):
        if random.random() < 0.70:
            # Hot region: random read within 128-byte working set
            word_idx = random.randint(0, hot_words - 1)
            ops.append(("R", hot_base + word_idx * 4))
        else:
            # Cold stream: sequential read advancing linearly
            addr = cold_base + (cold_ptr % cold_words) * 4
            ops.append(("R", addr))
            cold_ptr += 1

    write_trace("hot_stream.txt",
                "Read-mostly stream with hot 128B region + cold 2KB linear sweep", ops)


def gen_matrix_walk():
    """
    T10: Matrix Walk - Row-Major vs Column-Major (Phase II addition)
    Locality Pattern: Models a 16x16 word (1024-byte) matrix traversal.
      - Phase A: row-major order (stride = 4B, one word per step) - high spatial locality.
      - Phase B: column-major order (stride = 64B, 16 words per column step) - poor spatial locality.
    Both phases access the same 256 words (1 KB of data).

    Expected Behavior:
      - Row-major phase: 64 blocks * (1 miss + 3 hits) = 75% hit rate. Same for both caches.
      - Column-major phase: stride = 64B = 4 cache blocks apart. Each column step lands in a
        different block, so nearly every access misses (cold start on each of 16 blocks per row).
        In direct-mapped, columns 0 and 8 (addresses differ by 512B = exactly 32 sets * 16B)
        map to the same lines, causing extra conflict misses in direct vs 2-way.
      - Overall: demonstrates that access ORDER over the same data set matters as much as data size.

    Layout: matrix base = 0x1000 (4096 bytes from start), 16x16 = 256 words.
    Max address: 0x1000 + 255*4 = 0x13FC  (well within 0x3FFC limit).
    """
    ROWS, COLS = 16, 16
    base = 0x1000  # 4 KB offset - matrix starts here

    ops = []

    # Phase A: row-major traversal (good spatial locality)
    for r in range(ROWS):
        for c in range(COLS):
            addr = base + (r * COLS + c) * 4
            ops.append(("R", addr))

    # Phase B: column-major traversal (poor spatial locality - same data set)
    for c in range(COLS):
        for r in range(ROWS):
            addr = base + (r * COLS + c) * 4
            ops.append(("R", addr))

    write_trace("matrix_walk.txt",
                "16x16 matrix: row-major then column-major traversal (spatial locality comparison)", ops)


def gen_write_heavy():
    """
    T11: Write-Heavy Stream (Phase II addition)
    Locality Pattern: 80% writes, 20% reads over a 512-byte working set looped 5 times.
    Stresses write-through no-write-allocate policy directly.

    Expected Behavior:
      - Under write-through no-write-allocate: a write MISS does NOT load the block.
        Only reads can fill the cache. So hit rate is dominated by the small read fraction.
      - Working set = 128 words = 512 bytes (32 cache blocks). Fits in 1 KB cache.
      - Reads in iteration 1 are cold misses; reads in iterations 2-5 hit (block still cached
        because writes don't evict on a no-write-allocate policy).
      - Each write hits main memory directly (write-through) even when the block is cached.
        Cycle cost of writes is WR_LAT (4 cycles each), dominating total cycles.

    Purpose: Isolates the cost of the write-through policy. Proves that write-intensive
    workloads are expensive under write-through regardless of associativity, since every
    write stalls for WR_LAT cycles. Both caches behave identically here.
    """
    base = 0x0800   # 2 KB offset
    words = 128     # 128 words = 512 bytes (32 blocks)
    iterations = 5

    rng = random.Random(99)  # deterministic seed
    ops = []
    for it in range(iterations):
        for w in range(words):
            addr = base + w * 4
            if rng.random() < 0.80:
                # Write: data = iteration * 1000 + word index (deterministic value)
                data = it * 1000 + w
                ops.append(("W", addr, data))
            else:
                ops.append(("R", addr))

    write_trace("write_heavy.txt",
                "80% writes over 512B working set x5 iterations (stresses write-through policy)", ops)


def main():
    os.makedirs(TRACES_DIR, exist_ok=True)
    print("Generating deterministic traces in traces/ ...")
    gen_seq_stream()
    gen_small_loop()
    gen_pingpong()
    gen_cyclic3()
    gen_strided()
    gen_random()
    gen_mixed_rw()
    gen_large_loop()
    gen_hot_stream()
    # Phase II additions
    gen_matrix_walk()
    gen_write_heavy()
    print("All 11 traces generated successfully.")

if __name__ == "__main__":
    main()
