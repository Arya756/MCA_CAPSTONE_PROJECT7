# Section III.C – LRU Replacement (Member 2)

## III.C LRU Replacement Policy

With two ways per set, a block can live in one of two places, so a miss in a full set forces the cache to choose which of the two resident blocks to evict. We use true Least-Recently-Used (LRU) replacement: the evicted block is the one that was accessed longest ago. LRU exploits temporal locality, since a block used recently is likely to be used again soon [1].

**State.** Each set keeps one LRU bit, `lru[set]`. It stores the *victim way*: `lru = 0` means Way 0 is least recently used, `lru = 1` means Way 1 is. One bit is enough because a set with two ways has only two possible recency orders, so the full ordering fits in a single bit. (For N ways, true LRU would need to track N! orderings, which is why larger caches use approximations such as tree-PLRU [1].)

**Update rule.** The bit is updated whenever a way is used:

| Event | Update |
|---|---|
| Read hit or write hit in way *w* | `lru <= ~w` (the other way becomes LRU) |
| Refill of a missed block into way *v* | `lru <= ~v` (the new block is most recent) |
| Write miss (no-write-allocate) | no change, nothing is placed in the cache |

A write hit updates LRU exactly like a read hit, because writing a block is a use of that block.

**Victim selection.** On a read miss the victim way is chosen in this order:

1. If Way 0 is invalid, use Way 0.
2. Else if Way 1 is invalid, use Way 1.
3. Else (both valid) use the way named by `lru[set]`.

Invalid ways are used first so that a set is filled before any valid block is evicted. The LRU bit only matters once both ways hold valid data.

**Worked example.** Fig. X shows one set over the access sequence A, B, A, C, B, A, C, A, B, C (all mapping to the same set). The first two accesses fill Way 0 and Way 1. The hit on A makes B the LRU block, so the miss on C evicts B rather than A. The result is 2 hits and 8 misses, with the contents of both ways and the LRU bit listed after every access.

> **Fig. X.** LRU state of one set over A,B,A,C,B,A,C,A,B,C. Source: `docs/img/lru_sequence.png`.

**Verification.** `tb/tb_lru_directed.v` checks the LRU logic with twelve directed steps. The expected outcomes were derived by hand before running, and each step checks hit or miss, the data returned and, in the later steps, the internal way contents and the `lru` bit.

| Step | What it checks |
|---|---|
| 1–2 | Cold misses fill Way 0, then Way 1 (invalid way is used first) |
| 3–6 | A hit on A makes B the LRU block, so a new block C evicts B and A is kept |
| 7 | A second set behaves independently |
| 8 | Traffic in Set 1 does not change Set 0's LRU bit or its victim choice |
| 9 | A write hit updates LRU, so the written block is protected and the other way is evicted |
| 10 | The full sequence A,B,A,C,B,A,C,A,B,C matches Fig. X after every access |
| 11 | A write miss does not allocate, evict or change the LRU bit, and the write still reaches memory (write-through) |
| 12 | An empty way is chosen before the LRU way, even when the LRU bit points at the valid way (the bit is forced for this test) |

All twelve steps pass, and the full regression reports 0 data mismatches.

**Random reference-model test.** `tb/tb_lru_random.v` sends the same pseudo-random sequence of 5000 reads and writes (fixed seed, about 35 % writes, 6 sets with 5 competing blocks each) to the RTL and to a behavioural reference model of a 2-way LRU, write-through, no-write-allocate cache. After every access it compares the hit/miss result, the returned word and the valid bits, tags and LRU bit of the accessed set; at the end it compares the hit/miss counters and the whole main memory. In the reference run the model saw 2013 hits, 2987 misses and 1926 LRU evictions, and all 5000 accesses matched.

**Bug-injection check.** To show the tests can fail, `scripts/run_bug_injection.sh` makes four deliberately broken copies of the RTL (the real file is never changed) and runs both testbenches on each:

| Broken copy | Directed test | Random test |
|---|---|---|
| Real RTL (control) | PASS | PASS |
| Hit update flipped (`lru <= hit_way`) | FAIL | FAIL |
| Refill update flipped (`lru <= victim_way`) | FAIL | FAIL |
| Victim choice inverted when both ways valid | FAIL | FAIL |
| Victim ignores valid bits | FAIL | PASS |

The last row is expected. After reset the LRU bit already points at the empty way, so ignoring the valid bits cannot change behaviour under normal traffic, and random operations cannot expose it. Only directed step 12, which forces the LRU bit onto the valid way, catches it.

## LRU part of the Discussion (Section V)

- **LRU pays off when blocks conflict.** In `pingpong`, two blocks map to the same set. The direct-mapped cache evicts one with every access and gets 0 hits in 200 accesses. The 2-way cache keeps both blocks, with 198 hits in 200 accesses (99.0 %). Total cycles drop from 2800 to 424, which is 84.9 % fewer cycles, or about 6.6 times faster. LRU is never even asked to evict after the two cold misses, because both blocks fit.
- **LRU gives no benefit without conflicts.** In `seq_stream`, `small_loop`, `strided` and `mixed_rw` both designs have identical hit counts, so the extra comparator and LRU state buy nothing for these access patterns.
- **LRU has a known worst case.** In `cyclic3`, three blocks map to one two-way set and are accessed in a repeating cycle A, B, C. When the block is needed again, LRU has just evicted it, because it was the least recently used. The result is 0 hits in 300 accesses for the 2-way cache. This is the classic pattern where a working set of N+1 blocks defeats LRU in an N-way set [1], [3]. In our runs the direct-mapped cache also gets 0 hits on this trace, so here LRU does not lose to the baseline; it simply gains nothing from the extra way.
- **LRU is cheap for two ways.** The whole policy costs one bit per set and a one-bit mux in the victim path, which is why true LRU is practical here while larger caches approximate it.

*Numbers above come from `results/results.csv` of the current repository. Before submission, re-check them against a fresh run of `./scripts/run_all.sh`.*
