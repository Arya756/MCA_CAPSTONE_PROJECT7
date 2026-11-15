#!/usr/bin/env python3
"""
Trace Generator for Cache Evaluation
Project 7 - 2-Way Set-Associative vs Direct-Mapped Cache
Owner: Member 4 (Traces, Comparison Testbench, Scripts)

Generates 7 deterministic memory access traces into traces/ directory:
1. seq_stream.txt: Sequential word accesses with 4B stride (~75% hit rate).
2. small_loop.txt: Tight 256B loop that fits inside 1KB cache (~97.5% hit rate).
3. pingpong.txt: Alternating 2 addresses in same set (favors 2-way: 99% vs 0%).
4. cyclic3.txt: 3-way cyclic conflict on same set (hurts LRU: 0% hit rate).
5. strided.txt: 64B strided access, hitting every 4th set.
6. random.txt: Deterministic uniform random word accesses (seed 42).
7. mixed_rw.txt: Hot region with 70% reads and 30% writes (tests write-through).

All addresses are word-aligned and strictly kept within the 4096-word (16 KB)
main_memory capacity range: 0x00000000 to 0x00003FFC.
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
    print("All 7 traces generated successfully.")

if __name__ == "__main__":
    main()
