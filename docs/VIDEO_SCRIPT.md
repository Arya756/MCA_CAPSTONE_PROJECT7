# Video Presentation Script: Project 7
**Maximum Duration:** 5:00 minutes (Target: ~4:30)  
**Format:** Screen recording with synchronized audio voiceover  
**Team:** Project 7 – 2-Way Set-Associative Cache with LRU vs Direct-Mapped Cache  

---

## Presentation Breakdown

| Time Window | Speaker | Section & Content | Visual / Demonstration |
|---|---|---|---|
| **0:00 – 0:30** | **All 5 Members** | **Team Introduction & Problem Statement**<br>- Each member introduces themselves by name and team role.<br>- High-level project pitch: Designing, modeling, and comparing a 1 KB 2-way set-associative cache with True LRU against an identical direct-mapped baseline in Verilog HDL. | Title slide displaying project title, university name, team member names, and GitHub repository URL. |
| **0:30 – 1:30** | **Member 1** (Team Lead) | **2-Way Architecture & Hardware Datapath**<br>- Explain the 32-bit address decomposition: 23-bit Tag, 5-bit Index (32 sets), 4-bit Offset (16-byte block, 4 words).<br>- Explain the parallel tag comparison (`hit0`, `hit1`) and hit-way multiplexer datapath.<br>- Walk through the 4-state controller FSM (`IDLE`, `LOOKUP`, `MISS_FETCH`, `WRITE_THROUGH`). | Architectural block diagram (from `docs/img/`) showing address split, dual tag arrays, comparators, multiplexer, and FSM transition graph. |
| **1:30 – 2:15** | **Member 2** | **True LRU Replacement & Directed Verification**<br>- Explain the 1-bit-per-set True LRU tracking mechanism: `lru[set] <= ~hit_way` on hits and `~victim_way` on fills.<br>- Emphasize invalid-way priority before evicting valid ways.<br>- Demonstrate the self-checking directed testbench `tb_lru_directed.v` executing in terminal and passing. | Terminal view running `iverilog` / `vvp` on `tb_lru_directed.v`, showing `LRU test: PASS` and GTKWave waveform showing LRU bit toggle on hit. |
| **2:15 – 2:50** | **Member 3** | **Direct-Mapped Baseline & Memory Model**<br>- Explain why the comparison is strictly fair: identical 1 KB capacity (64 lines), 16B block size, and write-through no-write-allocate policy.<br>- Walk through the parameterized `main_memory.v` model: 8-cycle read latency (`RD_LAT`) with 4-word burst protocol, 4-cycle write latency (`WR_LAT`).<br>- Demonstrate `tb_direct_basic.v` executing and passing. | Terminal showing `tb_direct_basic.v` passing with `DIRECT test: PASS`, and memory timing diagram showing the 4-word burst protocol. |
| **2:50 – 3:50** | **Member 4** | **Synthetic Traces & Regression Evaluation**<br>- Run `./scripts/run_all.sh` live in the terminal.<br>- Explain key trace behaviors: `seq_stream` achieves ~75% hit rate; `small_loop` achieves 97.5% hit rate.<br>- Highlight the contrast in `pingpong`: 2-way achieves 99.0% hit rate, while direct-mapped thrashes at 0.0% hit rate.<br>- Explain why `cyclic3` hurts LRU replacement (0.0% hit rate).<br>- Confirm zero data mismatches against the golden memory model. | Live execution of `./scripts/run_all.sh`, followed by display of `results/results.csv` and comparative hit-rate bar chart. |
| **3:50 – 4:40** | **Member 5** | **Hardware Synthesis & Future Roadmap**<br>- Present Yosys synthesis results for both caches (cell count, flip-flops, multiplexer complexity).<br>- Discuss trade-off: 2-way associativity eliminates conflict misses at the expense of dual comparators and multiplexer hardware.<br>- Outline Phase II enhancements: write-back dirty-bit policy and FPGA hardware validation. | Yosys cell count summary table and synthesis resource comparison slide. |

---

## Recording Checklist
- [ ] Rehearse timing with a stopwatch; ensure total time is strictly under 4:45.
- [ ] Screen resolution set to 1080p (1920x1080) with clear, high-contrast terminal fonts.
- [ ] Audio levels balanced across all 5 team members.
- [ ] Video uploaded to YouTube (Unlisted) or Google Drive (public link).
- [ ] Final video link pasted into `README.md`.
