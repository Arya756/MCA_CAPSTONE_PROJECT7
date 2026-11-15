# Team Task Plan – Project 7
**Phase I | Deadline: Nov 16, 2026, 11:59 PM IST**

> **Rule for everyone:** work on your own branch (`member1-...`), commit small and often with clear messages, open a pull request, and have another member review it. Commit history is graded per person. Every member must also be able to explain the WHOLE design in the interview, not only their part.

---

## Timeline

| Date | Goal |
|---|---|
| Nov 13 (today) | Member 1 creates repo and pushes the starter zip. Everyone clones, installs tools, runs `./scripts/run_all.sh` |
| Nov 14 | Each member finishes their own task and pushes it. Report sections drafted |
| Nov 15 | Merge all PRs. Record video. Finish report. Final run of all tests |
| Nov 16 (before 6 PM) | Final check, submit the Google Form. Do not wait for the last hour |

**Setup:** `sudo apt install iverilog yosys gtkwave` (Windows: install Icarus Verilog + GTKWave, or use WSL).

---

## Member 1 – Team lead and 2-way cache RTL

**Owns:** `rtl/cache_2way_lru.v`

**Tasks**
1. Create the GitHub repo, add the starter files, add all 4 others as collaborators, protect main (PR only).
2. Read and be able to explain the 2-way cache line by line: address split, parallel tag compare (`hit0`, `hit1`), hit-way mux, FSM states.
3. Add comments and a short parameter table at the top of the file (tag/index/offset widths).
4. Add a waveform dump (`$dumpfile`/`$dumpvars`) to `tb_lru_directed.v` and save one GTKWave screenshot of a hit and a miss to `docs/img/`.
5. Write report sections III.A, III.B, III.D (parameters, architecture, FSM).

**Deliverables:** repo, commented 2-way RTL, 1–2 waveform screenshots. **Commits expected: at least 5.**

---

## Member 2 – LRU logic and replacement verification

**Owns:** LRU/victim logic inside the 2-way cache, `tb/tb_lru_directed.v`

**Tasks**
1. Explain and document the LRU rule: update on hit (`lru <= ~hit_way`), update on fill, victim = invalid way first else LRU way.
2. Extend `tb_lru_directed.v` with 2 more directed tests: (a) two different sets do not disturb each other's LRU bit, (b) a write hit also updates LRU.
3. Draw a state table or small diagram of the LRU bit changing across the sequence A,B,A,C,B,A,C,A,B,C and save to `docs/img/`.
4. Write report section III.C (LRU) and the LRU part of the discussion.

**Deliverables:** extended directed testbench (all PASS), LRU diagram. **Commits expected: at least 5.**

---

## Member 3 – Direct-mapped baseline and memory model

**Owns:** `rtl/cache_direct.v`, `rtl/main_memory.v`

**Tasks**
1. Confirm the baseline has the same capacity (1 KB), block size and write policy as the 2-way cache, so the comparison is fair. Write this up in 5–6 lines.
2. Document the memory model (latencies: 8-cycle block read, 4-cycle word write) and make the latencies easy to change. Run the full regression with `RD_LAT = 4` and `16` and record how the cycle counts change.
3. Add a short testbench `tb/tb_direct_basic.v` (write then read the same address, read two addresses that conflict).
4. Write report section III.E (write policy) and III.F (comparison methodology, fairness).

**Deliverables:** baseline documentation, latency-sensitivity table, extra testbench. **Commits expected: at least 5.**

---

## Member 4 – Traces, comparison testbench, scripts

**Owns:** `scripts/gen_traces.py`, `traces/`, `tb/tb_compare.v`, `scripts/run_all.sh`

**Tasks**
1. Explain each trace: what locality pattern it models and what result you expect before running it.
2. Add 2 more traces (for example a larger loop of about 1.5 KB, and a read-mostly stream with a hot region) and re-run.
3. Write a small Python script `scripts/plot_results.py` that reads `results/results.csv` and produces a hit-rate bar chart and a cycles bar chart in `results/`.
4. Make sure `run_all.sh` works on a fresh clone. Report any mismatches (there should be 0).
5. Write report sections III.G (traces) and IV (results table and chart).

**Deliverables:** 9 traces, charts, a regression that runs in one command. **Commits expected: at least 5.**

---

## Member 5 – Report, diagrams, synthesis, video

**Owns:** `docs/`, final report, video

**Tasks**
1. Draw the block diagram (address split, two ways, comparators, hit mux, LRU bit, FSM) in draw.io and export to `docs/img/`.
2. Run Yosys on both designs (command is in `results/`) and summarize flip-flops and cells. If anyone has Vivado, record LUT/BRAM/Fmax instead and note it.
3. Assemble the IEEE report from `docs/REPORT_PHASE1.md` in the IEEE template (Word or Overleaf IEEEtran). Check formatting, figures, references. Fill the Individual Contributions table using the real commit log.
4. Organize and record the video using `docs/VIDEO_SCRIPT.md`; upload it (YouTube unlisted or Drive with open link) and put the link in the README.
5. Write report sections Abstract, Introduction, Literature Review, Conclusion; add 2–3 more verified references.

**Deliverables:** final PDF report, block diagram, video link, resource summary. **Commits expected: at least 5.**

---

## Video (max 5 minutes) – who says what

| Time | Speaker | Content |
|---|---|---|
| 0:00–0:30 | All 5 | Name each, one line on the project idea |
| 0:30–1:30 | Member 1 | Block diagram and architecture |
| 1:30–2:15 | Member 2 | LRU logic and directed test running |
| 2:15–2:50 | Member 3 | Baseline and fair-comparison setup |
| 2:50–3:50 | Member 4 | Run `run_all.sh`, show results and chart |
| 3:50–4:40 | Member 5 | Resource summary, what is planned for Phase II |

> Record screen + voice, rehearse once, keep it under 4:45 to be safe.

---

## Final Submission Checklist (Member 1 and Member 5 verify)

- [ ] Repo contains: report PDF, video link in README, all RTL, testbenches, traces, scripts, results, docs
- [ ] Every member has multiple commits under their own GitHub account
- [ ] Fresh clone: `./scripts/run_all.sh` runs and shows **0 mismatches** and **LRU test PASS**
- [ ] Report has: Abstract, Literature Review, Proposed Solution, Individual Contributions, References
- [ ] Video under 5:00, all 5 names clearly said, project idea stated, prototype demonstrated
- [ ] Repo link submitted in the Google Form before the deadline

---

## Interview Prep (Phase II) – everyone should be able to answer

1. How are tag, index and offset computed for each cache, and why do the widths differ?
2. What happens on a read hit, read miss and write in the 2-way cache, cycle by cycle?
3. How does the LRU bit work with only 2 ways? Why is it just 1 bit per set?
4. Why does the ping-pong trace favor 2-way, and why does the 3-way cyclic trace hurt LRU?
5. Why is the direct-mapped cache slightly better on some traces?
6. What are the write policy and its drawback? (write-through is slow on every write)
7. How did you make the comparison fair, and how did you verify correctness?
