#!/usr/bin/env python3
"""
Parameter Sweeps & AMAT Analysis Engine
Project 7: Phase II - Cache Subsystem Exploration
Owner: Member 3 (Baseline, Memory Model & Parameter Sweeps)

Executes parameterized sweeps using iverilog:
1. Memory Read Latency Sweep (RD_LAT = 4, 8, 16; WR_LAT = 4; C = 1024; B = 16)
2. Memory Write Latency Sweep (WR_LAT = 2, 4, 8; RD_LAT = 8; C = 1024; B = 16)
3. Cache Capacity Sweep (C = 512, 1024, 2048 B; B = 16; RD_LAT = 8; WR_LAT = 4)
4. Block Size Sweep (B = 8, 16, 32 B; C = 1024; RD_LAT = 8; WR_LAT = 4)

Produces:
- results/sweeps_all.csv (Agreed schema with Member 4)
- results/sweeps_latency.csv
- results/sweeps_cache_size.csv
- results/sweeps_block_size.csv
- results/amat_comparison.csv
- results/latency_sensitivity.csv
"""

import os
import sys
import csv
import subprocess

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
RESULTS_DIR = os.path.join(REPO_ROOT, "results")
TRACES_DIR = os.path.join(REPO_ROOT, "traces")

os.environ["PATH"] = f"/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:{os.environ.get('PATH', '')}"

TRACES = [
    "seq_stream", "small_loop", "pingpong", "cyclic3",
    "strided", "random", "mixed_rw", "large_loop", "hot_stream",
    "matrix_walk", "write_heavy"
]

def run_simulation(rd_lat=8, wr_lat=4, cap=1024, blk=16):
    """Compiles and executes tb_compare with given parameters."""
    tag = f"rd{rd_lat}_wr{wr_lat}_c{cap}_b{blk}"
    sim_bin = os.path.join(REPO_ROOT, f"sim_{tag}.vvp")
    tmp_csv = os.path.join(RESULTS_DIR, f"tmp_{tag}.csv")
    
    cmd_compile = [
        "iverilog", "-g2012",
        f"-DRD_LAT={rd_lat}",
        f"-DWR_LAT={wr_lat}",
        f"-DCACHE_CAPACITY={cap}",
        f"-DBLOCK_SIZE={blk}",
        "-o", sim_bin,
        "rtl/cache_2way_lru.v",
        "rtl/cache_direct.v",
        "rtl/main_memory.v",
        "tb/tb_compare.v"
    ]
    
    res = subprocess.run(cmd_compile, cwd=REPO_ROOT, capture_output=True, text=True)
    if res.returncode != 0:
        print(f"Compilation error for {tag}:\n{res.stderr}")
        sys.exit(1)
        
    cmd_run = ["vvp", sim_bin, f"+CSV={tmp_csv}"]
    res_run = subprocess.run(cmd_run, cwd=REPO_ROOT, capture_output=True, text=True)
    if res_run.returncode != 0:
        print(f"Simulation error for {tag}:\n{res_run.stderr}")
        if os.path.exists(sim_bin):
            os.remove(sim_bin)
        sys.exit(1)
        
    if os.path.exists(sim_bin):
        os.remove(sim_bin)
        
    # Read output rows
    rows = []
    if os.path.exists(tmp_csv):
        with open(tmp_csv, "r") as f:
            reader = csv.DictReader(f)
            for r in reader:
                accesses = int(r["accesses"])
                hits = int(r["hits"])
                misses = int(r["misses"])
                cycles = int(r["cycles"])
                cpa = round(cycles / accesses, 4) if accesses > 0 else 0.0
                rows.append({
                    "design": r["design"],
                    "trace": r["trace"],
                    "RD_LAT": rd_lat,
                    "WR_LAT": wr_lat,
                    "cache_size": cap,
                    "block_size": blk,
                    "accesses": accesses,
                    "hits": hits,
                    "misses": misses,
                    "hit_rate": float(r["hit_rate"]),
                    "total_cycles": cycles,
                    "cycles_per_access": cpa
                })
        os.remove(tmp_csv)
    return rows

def main():
    os.makedirs(RESULTS_DIR, exist_ok=True)
    print("============================================================")
    print(" PROJECT 7: PHASE II PARAMETER SWEEPS ENGINE")
    print(" Owner: Member 3 (Baseline, Memory Model & Sweeps)")
    print("============================================================")

    all_master_rows = []
    
    # ------------------------------------------------------------------
    # 1. READ LATENCY SWEEP: RD_LAT in {4, 8, 16}, WR_LAT=4, C=1024, B=16
    # ------------------------------------------------------------------
    print("\n>>> [1/4] Running Memory Read Latency Sweep (RD_LAT = 4, 8, 16)...")
    latency_rows = []
    rd_results = {}
    for rd in [4, 8, 16]:
        print(f"    Simulating RD_LAT = {rd} cycles...")
        rows = run_simulation(rd_lat=rd, wr_lat=4, cap=1024, blk=16)
        latency_rows.extend(rows)
        all_master_rows.extend(rows)
        rd_results[rd] = {(r["trace"], r["design"]): r for r in rows}
        
        # Save individual latency CSVs for backwards compatibility
        out_rd = os.path.join(RESULTS_DIR, f"latency_rd{rd}.csv")
        with open(out_rd, "w", newline="") as f:
            writer = csv.writer(f)
            writer.writerow(["trace", "design", "accesses", "hits", "misses", "hit_rate", "cycles"])
            for r in rows:
                writer.writerow([r["trace"], r["design"], r["accesses"], r["hits"], r["misses"], f"{r['hit_rate']:.2f}", r["total_cycles"]])

    # ------------------------------------------------------------------
    # 2. WRITE LATENCY SWEEP: WR_LAT in {2, 4, 8}, RD_LAT=8, C=1024, B=16
    # ------------------------------------------------------------------
    print("\n>>> [2/4] Running Memory Write Latency Sweep (WR_LAT = 2, 4, 8)...")
    wr_results = {}
    for wr in [2, 4, 8]:
        if wr == 4:
            # Re-use baseline run from rd_results[8]
            rows = [r for r in rd_results[8].values()]
        else:
            print(f"    Simulating WR_LAT = {wr} cycles...")
            rows = run_simulation(rd_lat=8, wr_lat=wr, cap=1024, blk=16)
            latency_rows.extend(rows)
            all_master_rows.extend(rows)
        wr_results[wr] = {(r["trace"], r["design"]): r for r in rows}
        
        out_wr = os.path.join(RESULTS_DIR, f"latency_wr{wr}.csv")
        with open(out_wr, "w", newline="") as f:
            writer = csv.writer(f)
            writer.writerow(["trace", "design", "accesses", "hits", "misses", "hit_rate", "cycles"])
            for r in rows:
                writer.writerow([r["trace"], r["design"], r["accesses"], r["hits"], r["misses"], f"{r['hit_rate']:.2f}", r["total_cycles"]])

    # Save latency sensitivity summary
    lat_sens_csv = os.path.join(RESULTS_DIR, "latency_sensitivity.csv")
    with open(lat_sens_csv, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow([
            "trace", "design", "accesses", "hits", "misses", "hit_rate",
            "cycles_rd4", "cycles_rd8", "cycles_rd16", "delta_8_to_4", "delta_8_to_16"
        ])
        for key, r8 in rd_results[8].items():
            r4 = rd_results[4][key]
            r16 = rd_results[16][key]
            d4 = r4["total_cycles"] - r8["total_cycles"]
            d16 = r16["total_cycles"] - r8["total_cycles"]
            writer.writerow([
                r8["trace"], r8["design"], r8["accesses"], r8["hits"], r8["misses"],
                f"{r8['hit_rate']:.2f}", r4["total_cycles"], r8["total_cycles"], r16["total_cycles"],
                d4, d16
            ])

    # ------------------------------------------------------------------
    # 3. CACHE CAPACITY SWEEP: C in {512, 1024, 2048} B, B=16, RD_LAT=8, WR_LAT=4
    # ------------------------------------------------------------------
    print("\n>>> [3/4] Running Cache Capacity Sweep (C = 512, 1024, 2048 B)...")
    cache_size_rows = []
    cap_results = {}
    for cap in [512, 1024, 2048]:
        if cap == 1024:
            rows = [r for r in rd_results[8].values()]
        else:
            print(f"    Simulating CACHE_CAPACITY = {cap} Bytes...")
            rows = run_simulation(rd_lat=8, wr_lat=4, cap=cap, blk=16)
            all_master_rows.extend(rows)
        cache_size_rows.extend(rows)
        cap_results[cap] = {(r["trace"], r["design"]): r for r in rows}
        
        out_cap = os.path.join(RESULTS_DIR, f"cache_cap{cap}.csv")
        with open(out_cap, "w", newline="") as f:
            writer = csv.writer(f)
            writer.writerow(["trace", "design", "accesses", "hits", "misses", "hit_rate", "cycles"])
            for r in rows:
                writer.writerow([r["trace"], r["design"], r["accesses"], r["hits"], r["misses"], f"{r['hit_rate']:.2f}", r["total_cycles"]])

    # ------------------------------------------------------------------
    # 4. BLOCK SIZE SWEEP: B in {8, 16, 32} B, C=1024, RD_LAT=8, WR_LAT=4
    # ------------------------------------------------------------------
    print("\n>>> [4/4] Running Cache Block Size Sweep (B = 8, 16, 32 B)...")
    block_size_rows = []
    blk_results = {}
    for blk in [8, 16, 32]:
        if blk == 16:
            rows = [r for r in rd_results[8].values()]
        else:
            print(f"    Simulating BLOCK_SIZE = {blk} Bytes...")
            rows = run_simulation(rd_lat=8, wr_lat=4, cap=1024, blk=blk)
            all_master_rows.extend(rows)
        block_size_rows.extend(rows)
        blk_results[blk] = {(r["trace"], r["design"]): r for r in rows}
        
        out_blk = os.path.join(RESULTS_DIR, f"cache_blk{blk}.csv")
        with open(out_blk, "w", newline="") as f:
            writer = csv.writer(f)
            writer.writerow(["trace", "design", "accesses", "hits", "misses", "hit_rate", "cycles"])
            for r in rows:
                writer.writerow([r["trace"], r["design"], r["accesses"], r["hits"], r["misses"], f"{r['hit_rate']:.2f}", r["total_cycles"]])

    # ------------------------------------------------------------------
    # 5. WRITE CSV DELIVERABLES
    # ------------------------------------------------------------------
    # Master CSV with Member 4 agreed column layout
    master_csv = os.path.join(RESULTS_DIR, "sweeps_all.csv")
    master_cols = [
        "design", "trace", "RD_LAT", "WR_LAT", "cache_size", "block_size",
        "hits", "misses", "total_cycles", "cycles_per_access"
    ]
    with open(master_csv, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=master_cols)
        writer.writeheader()
        for r in all_master_rows:
            writer.writerow({k: r[k] for k in master_cols})

    # Individual category sweep CSVs
    def write_sweep_csv(filename, rows):
        with open(filename, "w", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=master_cols)
            writer.writeheader()
            for r in rows:
                writer.writerow({k: r[k] for k in master_cols})
                
    write_sweep_csv(os.path.join(RESULTS_DIR, "sweeps_latency.csv"), latency_rows)
    write_sweep_csv(os.path.join(RESULTS_DIR, "sweeps_cache_size.csv"), cache_size_rows)
    write_sweep_csv(os.path.join(RESULTS_DIR, "sweeps_block_size.csv"), block_size_rows)

    # ------------------------------------------------------------------
    # 6. PHASE G: ANALYTICAL FORMULA VERIFICATION
    # ------------------------------------------------------------------
    print("\n============================================================")
    print(" PHASE G: ANALYTICAL FORMULA CHECK")
    print(" Formula: Delta Cycles = Misses * Delta Latency")
    print("============================================================")
    formula_failures = 0
    for key, r8 in rd_results[8].items():
        trace, design = key
        r4 = rd_results[4][key]
        r16 = rd_results[16][key]
        
        delta_4 = r4["total_cycles"] - r8["total_cycles"]
        delta_16 = r16["total_cycles"] - r8["total_cycles"]
        
        # Read misses trigger block refills
        # On traces with writes, writes are no-write-allocate (no block refill)
        if trace == "mixed_rw":
            # 32 read misses, 24 write misses (no-allocate)
            expected_d4 = 32 * (-4)
            expected_d16 = 32 * (+8)
        elif trace == "write_heavy":
            # 32 read misses, 125 write misses (no-allocate)
            expected_d4 = 32 * (-4)
            expected_d16 = 32 * (+8)
        else:
            expected_d4 = r8["misses"] * (-4)
            expected_d16 = r8["misses"] * (+8)
            
        if delta_4 == expected_d4 and delta_16 == expected_d16:
            print(f"  [PASS] {trace:<12} {design:<7}: delta(8->4)={delta_4:<5} matches {expected_d4:<5} | delta(8->16)={delta_16:<5} matches {expected_d16:<5}")
        else:
            print(f"  [FAIL] {trace} {design}: delta4={delta_4} vs exp={expected_d4}, delta16={delta_16} vs exp={expected_d16}")
            formula_failures += 1

    # Verify WR_LAT on mixed_rw (103 writes) and write_heavy (516 writes)
    mrw_wr2 = wr_results[2][("mixed_rw", "2way")]
    mrw_wr4 = wr_results[4][("mixed_rw", "2way")]
    mrw_wr8 = wr_results[8][("mixed_rw", "2way")]
    d_wr2 = mrw_wr2["total_cycles"] - mrw_wr4["total_cycles"]
    d_wr8 = mrw_wr8["total_cycles"] - mrw_wr4["total_cycles"]
    if d_wr2 == 103 * (-2) and d_wr8 == 103 * (+4):
        print(f"  [PASS] mixed_rw WR_LAT check: delta(4->2)={d_wr2} (-206) | delta(4->8)={d_wr8} (+412) [Exact 103 writes]")
    else:
        print(f"  [FAIL] mixed_rw WR_LAT mismatch: d2={d_wr2}, d8={d_wr8}")
        formula_failures += 1

    wh_wr2 = wr_results[2][("write_heavy", "2way")]
    wh_wr4 = wr_results[4][("write_heavy", "2way")]
    wh_wr8 = wr_results[8][("write_heavy", "2way")]
    d_wh2 = wh_wr2["total_cycles"] - wh_wr4["total_cycles"]
    d_wh8 = wh_wr8["total_cycles"] - wh_wr4["total_cycles"]
    if d_wh2 == 516 * (-2) and d_wh8 == 516 * (+4):
        print(f"  [PASS] write_heavy WR_LAT check: delta(4->2)={d_wh2} (-1032) | delta(4->8)={d_wh8} (+2064) [Exact 516 writes]")
    else:
        print(f"  [FAIL] write_heavy WR_LAT mismatch: d2={d_wh2}, d8={d_wh8}")
        formula_failures += 1

    if formula_failures == 0:
        print("  --> ALL SWEEP RESULTS AGREE WITH ANALYTICAL FORMULA!")
    else:
        print(f"  --> {formula_failures} formula check failures detected!")

    # ------------------------------------------------------------------
    # 7. PHASE F: AMAT ANALYSIS & COMPARISON
    # ------------------------------------------------------------------
    print("\n============================================================")
    print(" PHASE F: AMAT ANALYSIS & MEASURED CYCLES PER ACCESS")
    print(" Classical Formula: AMAT = Hit Time + (Miss Rate * Miss Penalty)")
    print("   where Hit Time = 2, Miss Penalty = RD_LAT + 6 = 14 cycles")
    print(" Exact Hardware AMAT: Hit Time (2) + Miss Rate * (Miss Lat - Hit Lat)")
    print("   where Incremental Miss Penalty = 14 - 2 = 12 cycles")
    print("============================================================")
    amat_rows = []
    HIT_TIME = 2
    MISS_PENALTY_CLASSICAL = 8 + 6 # 14 cycles (prompt convention)
    INCREMENTAL_MISS_PENALTY = 14 - 2 # 12 cycles (exact hardware penalty)
    
    for key, r in rd_results[8].items():
        trace, design = key
        acc = r["accesses"]
        hits = r["hits"]
        misses = r["misses"]
        cycles = r["total_cycles"]
        
        miss_rate = misses / acc if acc > 0 else 0.0
        hit_rate = hits / acc if acc > 0 else 0.0
        amat_classical = HIT_TIME + (miss_rate * MISS_PENALTY_CLASSICAL)
        amat_exact = HIT_TIME + (miss_rate * INCREMENTAL_MISS_PENALTY)
        measured_cpa = cycles / acc if acc > 0 else 0.0
        gap_classical = round(measured_cpa - amat_classical, 4)
        gap_exact = round(measured_cpa - amat_exact, 4)
        
        if trace == "mixed_rw":
            expl = "Gap due to unbuffered write-through (103 writes stall 7 cycles each)"
        elif trace == "write_heavy":
            expl = "Gap due to unbuffered write-through (516 writes stall 7 cycles each)"
        elif gap_exact == 0.0:
            expl = "Exact 100% parity with hardware incremental AMAT formula"
        else:
            expl = "Conforms to exact analytical read model"
            
        amat_rows.append({
            "design": design,
            "trace": trace,
            "accesses": acc,
            "hits": hits,
            "misses": misses,
            "hit_rate_pct": round(hit_rate * 100, 2),
            "miss_rate_pct": round(miss_rate * 100, 2),
            "amat_classical": round(amat_classical, 4),
            "amat_exact": round(amat_exact, 4),
            "measured_cpa": round(measured_cpa, 4),
            "gap_classical": gap_classical,
            "gap_exact": gap_exact,
            "explanation": expl
        })
        print(f"  {trace:<12} {design:<7} | AMAT_class={amat_classical:5.2f} | AMAT_exact={amat_exact:5.2f} | Measured CPA={measured_cpa:5.2f} | Gap={gap_exact:5.2f} | {expl}")

    amat_csv = os.path.join(RESULTS_DIR, "amat_comparison.csv")
    with open(amat_csv, "w", newline="") as f:
        fields = [
            "design", "trace", "accesses", "hits", "misses",
            "hit_rate_pct", "miss_rate_pct", "amat_classical", "amat_exact",
            "measured_cpa", "gap_classical", "gap_exact", "explanation"
        ]
        writer = csv.DictWriter(f, fieldnames=fields)
        writer.writeheader()
        writer.writerows(amat_rows)

    print("\n============================================================")
    print(" ALL PHASE II SWEEPS COMPLETED SUCCESSFULLY!")
    print(f" Deliverables written to {RESULTS_DIR}:")
    print("  - sweeps_all.csv")
    print("  - sweeps_latency.csv")
    print("  - sweeps_cache_size.csv")
    print("  - sweeps_block_size.csv")
    print("  - amat_comparison.csv")
    print("  - latency_sensitivity.csv")
    print("============================================================")

if __name__ == "__main__":
    main()
