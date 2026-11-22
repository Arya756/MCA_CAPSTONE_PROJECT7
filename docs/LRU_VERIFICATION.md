# LRU and Replacement Verification Notes (Member 2, Phase II)

All results below come from runs in this repository with the default memory
configuration (RD_LAT = 8, WR_LAT = 4), 1 KB 2-way cache, 16 B blocks, 32 sets.

## What is verified

| Check | File | What it proves |
|---|---|---|
| Directed steps 1-7 | `tb/tb_lru_directed.v` | Cold fills, hit updates LRU, LRU way is evicted, sets are independent |
| Directed step 8 | same | Traffic in one set does not change another set's LRU bit |
| Directed step 9 | same | A write hit updates the LRU bit and the cached data |
| Directed step 10 | same | Full sequence A,B,A,C,B,A,C,A,B,C matches the hand-derived table (`docs/img/lru_sequence.png`) |
| Directed step 11 | same | A write miss does not allocate or change LRU; the write still reaches memory |
| Directed step 12 | same | An empty way is used before the LRU way (LRU bit forced onto the valid way) |
| Random test | `tb/tb_lru_random.v` | 5000 random reads and writes match a reference model after every access |

Run commands:

```
./scripts/run_all.sh                       # directed tests + regression
iverilog -g2012 -o /tmp/rand.vvp rtl/cache_2way_lru.v rtl/main_memory.v tb/tb_lru_random.v && vvp /tmp/rand.vvp
./scripts/run_bug_injection.sh             # bug-injection check
```

## Random test details

- 5000 operations: 3243 reads and 1757 writes (fixed seed `32'h2026_1124`).
- Addresses come from 6 sets with 5 blocks each, so two ways are always contested.
- Reference model: 2-way LRU, write-through, no-write-allocate, written from the specification.
- Compared after every access: hit/miss, returned word, valid bits, tags, LRU bit of the set.
- Compared at the end: hit and miss counters, and all 4096 words of main memory.
- Result: model 2013 hits, 2987 misses, 1926 LRU evictions; RTL matched on every access.

## Bug-injection result

Each broken copy is made in a temporary directory by changing one line of
`rtl/cache_2way_lru.v`. The real RTL is never modified.

| Broken copy | Change | Directed | Random |
|---|---|---|---|
| control | none (real RTL) | PASS | PASS |
| bug1_hit_update | `lru <= ~hit_way` became `lru <= hit_way` | FAIL | FAIL |
| bug2_refill_update | `lru <= ~victim_way` became `lru <= victim_way` | FAIL | FAIL |
| bug3_victim_polarity | victim = `~lru` when both ways valid | FAIL | FAIL |
| bug4_ignore_valid | victim ignores both valid bits | FAIL | PASS |

Script verdict: `BUG-INJECTION RESULT: OK`.

Bug 4 passes the random test on purpose. After reset every set has `lru = 0`, and
the first fill into Way 0 sets `lru = 1`, so the LRU bit already points at the empty
way in every reachable state. The "empty way first" rule is therefore a safety net
that normal traffic cannot distinguish from plain LRU. Directed step 12 forces the
LRU bit onto the valid way with a hierarchical write, which is the only way to
exercise the rule, and it catches bug 4.

## Limitations

- The random test uses 6 of the 32 sets and 5 tags per set. It is aimed at replacement
  behaviour, not at covering the whole address space.
- Directed step 12 writes the internal `lru` register from the testbench, so it is a
  white-box test and depends on the signal name `lru` in the RTL.
- The reference model checks function (hit/miss, data, state), not cycle counts. Cycle
  counts are checked by `tb_compare.v`.
