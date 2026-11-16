#!/usr/bin/env bash
# Generator script for docs/img/block_diagram.png and docs/img/block_diagram.drawio
# Owner: Member 5 (Report, Diagrams, Synthesis, Video Lead)
# Project 7: 2-Way Set-Associative Cache Architecture
""":"
command -v uv >/dev/null 2>&1 && exec uv run --with matplotlib python3 "$0" "$@"
exec python3 "$0" "$@"
"""

import sys
import os
import matplotlib.pyplot as plt
import matplotlib.patches as patches
from matplotlib.patches import FancyBboxPatch, Rectangle

def route_wire(ax, pts, color="#37474f", lw=1.5, ls="-", arrow=True, arrow_scale=12):
    """Draws an orthogonal multi-segment wire with optional arrowhead at the end."""
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    ax.plot(xs, ys, color=color, lw=lw, ls=ls, zorder=3)
    if arrow and len(pts) >= 2:
        ax.annotate("", xy=pts[-1], xytext=pts[-2],
                    arrowprops=dict(arrowstyle="->", color=color, lw=lw,
                                    mutation_scale=arrow_scale),
                    zorder=4)

def draw_block_diagram(output_png):
    fig, ax = plt.subplots(figsize=(24, 15), dpi=300)
    ax.set_xlim(0, 114)
    ax.set_ylim(0, 100)
    ax.axis('off')
    fig.patch.set_facecolor('#ffffff')

    # Color Palette
    c_cpu_b = "#1a73e8"
    c_cpu_f = "#e8f0fe"
    c_mem_b = "#e37400"
    c_mem_f = "#fef7e0"
    c_w0_b = "#137333"
    c_w0_f = "#e6f4ea"
    c_w1_b = "#7627bb"
    c_w1_f = "#f3e8fd"
    c_fsm_b = "#c5221f"
    c_fsm_f = "#fce8e6"
    c_mux_b = "#0288d1"
    c_mux_f = "#e1f5fe"
    c_lru_b = "#f29900"
    c_lru_f = "#fff8e1"
    c_grey_b = "#5f6368"
    c_grey_f = "#f1f3f4"

    # Header
    ax.text(57, 98.2, "Microarchitectural Block Diagram: 2-Way Set-Associative Cache (cache_2way_lru.v)",
            ha='center', va='center', fontsize=18, fontweight='bold', color='#202124')
    ax.text(57, 96.2, "32 Sets × 2 Ways | 16-Byte Block Burst (4 Words) | True LRU Replacement | Write-Through No-Write-Allocate",
            ha='center', va='center', fontsize=11, fontstyle='italic', color='#5f6368')

    # =========================================================================
    # 1. CPU ADDRESS SPLIT (Top Bar: y=89.5 to 94.5)
    # =========================================================================
    addr_bg = FancyBboxPatch((16, 89.0), 76, 5.2, boxstyle="round,pad=0.2",
                             ec="#70757a", fc="#ffffff", lw=1.2, ls="--")
    ax.add_patch(addr_bg)
    ax.text(17.2, 91.6, "CPU Address:\ncpu_addr[31:0]", ha='left', va='center',
            fontsize=9.5, fontweight='bold', color="#202124")

    # Tag Field [31:9]
    tag_box = Rectangle((31, 89.4), 26, 4.4, ec=c_cpu_b, fc="#d2e3fc", lw=1.5, zorder=2)
    ax.add_patch(tag_box)
    ax.text(44, 91.6, "TAG: req_tag = cpu_addr[31:9]\n(23 bits: [31:9])",
            ha='center', va='center', fontsize=9, fontweight='bold', color="#174ea6")

    # Index Field [8:4]
    idx_box = Rectangle((59, 89.4), 19, 4.4, ec="#137333", fc="#ceead6", lw=1.5, zorder=2)
    ax.add_patch(idx_box)
    ax.text(68.5, 91.6, "INDEX: req_index = cpu_addr[8:4]\n(5 bits → 32 Sets: 0..31)",
            ha='center', va='center', fontsize=9, fontweight='bold', color="#0d652d")

    # Offset Field [3:0]
    off_box = Rectangle((80, 89.4), 11, 4.4, ec="#e37400", fc="#ffe7d9", lw=1.5, zorder=2)
    ax.add_patch(off_box)
    ax.text(85.5, 91.6, "OFFSET: [3:0]\n[3:2] Word | [1:0] Byte",
            ha='center', va='center', fontsize=8, fontweight='bold', color="#b06000")

    # =========================================================================
    # 2. CPU BUS INTERFACE (Left Column: x=2 to 14, y=52 to 84)
    # =========================================================================
    cpu_card = FancyBboxPatch((2, 52), 12, 32, boxstyle="round,pad=0.4",
                              ec=c_cpu_b, fc=c_cpu_f, lw=2)
    ax.add_patch(cpu_card)
    ax.text(8, 81.5, "CPU BUS\nINTERFACE", ha='center', va='center',
            fontsize=11, fontweight='bold', color=c_cpu_b)

    sigs_in = [
        ("→ cpu_req", "Control Strobe"),
        ("→ cpu_we", "1=Write, 0=Read"),
        ("→ cpu_addr[31:0]", "32-bit Address"),
        ("→ cpu_wdata[31:0]", "32-bit Write Word")
    ]
    sigs_out = [
        ("← cpu_ready", "Acknowledge Pulse"),
        ("← cpu_rdata[31:0]", "32-bit Read Word")
    ]
    for i, (sig, desc) in enumerate(sigs_in):
        ax.text(2.6, 76.5 - i*3.5, sig, ha='left', va='center', fontsize=8,
                fontweight='bold', family='monospace', color='#174ea6')
        ax.text(2.6, 75.0 - i*3.5, f"  ({desc})", ha='left', va='center', fontsize=7, color='#5f6368')

    for i, (sig, desc) in enumerate(sigs_out):
        ax.text(2.6, 62.5 - i*3.5, sig, ha='left', va='center', fontsize=8,
                fontweight='bold', family='monospace', color='#b31412')
        ax.text(2.6, 61.0 - i*3.5, f"  ({desc})", ha='left', va='center', fontsize=7, color='#5f6368')

    # Route cpu_addr to top address split
    route_wire(ax, [(14, 70), (15.2, 70), (15.2, 91.6), (16, 91.6)], color=c_cpu_b, lw=2)

    # =========================================================================
    # 3. WAY 0 & WAY 1 STORAGE ARRAYS (x=18 to 54)
    # =========================================================================
    # WAY 0 Container (y=67 to 84)
    w0_box = FancyBboxPatch((18, 67), 36, 17, boxstyle="round,pad=0.3",
                            ec=c_w0_b, fc=c_w0_f, lw=2)
    ax.add_patch(w0_box)
    ax.text(36, 81.8, "WAY 0 STORAGE ARRAY (32 Sets × 16 Bytes)", ha='center', va='center',
            fontsize=10, fontweight='bold', color=c_w0_b)

    v0 = Rectangle((19.5, 68.5), 5.5, 11, ec=c_w0_b, fc="white", lw=1.2, zorder=2)
    ax.add_patch(v0)
    ax.text(22.25, 74, "valid0\n[32 × 1b]\n(Valid)", ha='center', va='center', fontsize=8)

    t0 = Rectangle((26, 68.5), 11, 11, ec=c_w0_b, fc="white", lw=1.2, zorder=2)
    ax.add_patch(t0)
    ax.text(31.5, 74, "tag0\n[32 × 23b]\n(Stored Tag)", ha='center', va='center', fontsize=8.5, fontweight='bold')

    d0 = Rectangle((38, 68.5), 15, 11, ec=c_w0_b, fc="white", lw=1.2, zorder=2)
    ax.add_patch(d0)
    ax.text(45.5, 74, "data0\n[32 Sets × 4 Words]\n(128b Block / 16B)", ha='center', va='center', fontsize=8.5, fontweight='bold')

    # WAY 1 Container (y=47 to 64)
    w1_box = FancyBboxPatch((18, 47), 36, 17, boxstyle="round,pad=0.3",
                            ec=c_w1_b, fc=c_w1_f, lw=2)
    ax.add_patch(w1_box)
    ax.text(36, 61.8, "WAY 1 STORAGE ARRAY (32 Sets × 16 Bytes)", ha='center', va='center',
            fontsize=10, fontweight='bold', color=c_w1_b)

    v1 = Rectangle((19.5, 48.5), 5.5, 11, ec=c_w1_b, fc="white", lw=1.2, zorder=2)
    ax.add_patch(v1)
    ax.text(22.25, 54, "valid1\n[32 × 1b]\n(Valid)", ha='center', va='center', fontsize=8)

    t1 = Rectangle((26, 48.5), 11, 11, ec=c_w1_b, fc="white", lw=1.2, zorder=2)
    ax.add_patch(t1)
    ax.text(31.5, 54, "tag1\n[32 × 23b]\n(Stored Tag)", ha='center', va='center', fontsize=8.5, fontweight='bold')

    d1 = Rectangle((38, 48.5), 15, 11, ec=c_w1_b, fc="white", lw=1.2, zorder=2)
    ax.add_patch(d1)
    ax.text(45.5, 54, "data1\n[32 Sets × 4 Words]\n(128b Block / 16B)", ha='center', va='center', fontsize=8.5, fontweight='bold')

    # Index Bus Routing: drops at x=16.5 vertically outside arrays
    route_wire(ax, [(68.5, 89.4), (68.5, 86.8), (16.5, 86.8), (16.5, 74), (18, 74)], color="#137333", lw=1.8)
    route_wire(ax, [(16.5, 74), (16.5, 54), (18, 54)], color="#137333", lw=1.8)
    route_wire(ax, [(16.5, 54), (16.5, 38.5), (18, 38.5)], color="#137333", lw=1.8)
    ax.text(16.0, 78, "req_index[4:0] (Set 0..31)", ha='right', va='center',
            fontsize=8, color="#137333", fontweight='bold', rotation=90)

    # =========================================================================
    # 4. TAG COMPARATORS & HIT LOGIC (x=64 to 90)
    # =========================================================================
    # Comparator 0
    cmp0 = FancyBboxPatch((64, 71.5), 15.5, 8, boxstyle="round,pad=0.2",
                          ec=c_w0_b, fc="#ceead6", lw=1.5)
    ax.add_patch(cmp0)
    ax.text(71.75, 76.5, "TAG COMPARATOR 0", ha='center', va='center', fontsize=8.5, fontweight='bold', color=c_w0_b)
    ax.text(71.75, 73.5, "tag0 == req_tag && valid0\n→ hit0", ha='center', va='center', fontsize=7.5, family='monospace')

    # Comparator 1
    cmp1 = FancyBboxPatch((64, 51.5), 15.5, 8, boxstyle="round,pad=0.2",
                          ec=c_w1_b, fc="#e8d0fb", lw=1.5)
    ax.add_patch(cmp1)
    ax.text(71.75, 56.5, "TAG COMPARATOR 1", ha='center', va='center', fontsize=8.5, fontweight='bold', color=c_w1_b)
    ax.text(71.75, 53.5, "tag1 == req_tag && valid1\n→ hit1", ha='center', va='center', fontsize=7.5, family='monospace')

    # Route tag0 and tag1 to comparators
    route_wire(ax, [(37, 75.5), (64, 75.5)], color=c_w0_b, lw=1.5)
    route_wire(ax, [(37, 55.5), (64, 55.5)], color=c_w1_b, lw=1.5)
    ax.text(61, 76.8, "tag0[22:0]", ha='center', va='bottom', fontsize=7.5, color=c_w0_b)
    ax.text(61, 56.8, "tag1[22:0]", ha='center', va='bottom', fontsize=7.5, color=c_w1_b)

    # Route req_tag down to both comparators cleanly in open corridor
    route_wire(ax, [(44, 89.4), (44, 86.8), (71.75, 86.8), (71.75, 79.5)], color="#174ea6", lw=1.5)
    route_wire(ax, [(71.75, 71.5), (71.75, 59.5)], color="#174ea6", lw=1.5, ls=":")
    ax.text(54, 87.8, "req_tag[22:0] (from cpu_addr[31:9])", ha='center', va='bottom',
            fontsize=8, color="#174ea6", fontweight='bold')

    # Hit Logic Box
    hit_box = FancyBboxPatch((82, 61), 12.5, 10, boxstyle="round,pad=0.2",
                             ec=c_grey_b, fc=c_grey_f, lw=1.5)
    ax.add_patch(hit_box)
    ax.text(88.25, 68, "HIT LOGIC", ha='center', va='center', fontsize=9, fontweight='bold', color="#202124")
    ax.text(88.25, 64.5, "hit = hit0 || hit1\nhit_way = hit1", ha='center', va='center',
            fontsize=8, family='monospace', fontweight='bold', color="#174ea6")

    # Connect cmp0 and cmp1 to hit_box
    route_wire(ax, [(79.5, 75.5), (80.8, 75.5), (80.8, 67), (82, 67)], color=c_w0_b, lw=1.5)
    route_wire(ax, [(79.5, 55.5), (80.8, 55.5), (80.8, 64), (82, 64)], color=c_w1_b, lw=1.5)

    # =========================================================================
    # 5. DATA MULTIPLEXING & CPU READ WORD (HIT MUX: x=64 to 94.5)
    # =========================================================================
    mux_box = FancyBboxPatch((64, 35), 30.5, 13, boxstyle="round,pad=0.3",
                             ec=c_mux_b, fc=c_mux_f, lw=1.8)
    ax.add_patch(mux_box)
    ax.text(79.25, 45.8, "HIT-WAY & WORD SELECT MULTIPLEXER", ha='center', va='center',
            fontsize=9.5, fontweight='bold', color="#0277bd")
    ax.text(71, 41, "Way 0/1 Mux (128b)\nsel: hit_way (hit1)", ha='center', va='center', fontsize=8)
    ax.text(87, 41, "Word Mux (32b)\nsel: req_word_sel = addr[3:2]", ha='center', va='center', fontsize=8)

    # Route data0 and data1 into Mux - through clear corridor at x=56.5 and x=59
    route_wire(ax, [(54, 74), (58, 74), (58, 44), (64, 44)], color=c_w0_b, lw=1.5)
    route_wire(ax, [(54, 54), (60, 54), (60, 39.5), (64, 39.5)], color=c_w1_b, lw=1.5)
    ax.text(58.3, 62, "data0[127:0]", ha='center', va='center', fontsize=7.5, color=c_w0_b, rotation=-90)
    ax.text(60.3, 48, "data1[127:0]", ha='center', va='center', fontsize=7.5, color=c_w1_b, rotation=-90)

    # Route hit_way down to Mux
    route_wire(ax, [(88.25, 61), (88.25, 49.5), (76, 49.5), (76, 48)], color="#174ea6", lw=1.5)
    ax.text(82, 50.8, "hit_way", ha='center', va='bottom', fontsize=7.5, color="#174ea6", fontweight='bold')

    # Route req_word_sel from Offset field to Mux
    route_wire(ax, [(85.5, 89.4), (85.5, 86.8), (92.5, 86.8), (92.5, 48)], color="#e37400", lw=1.4)
    ax.text(92.8, 65, "req_word_sel[1:0] (cpu_addr[3:2])", ha='left', va='center',
            fontsize=7.5, color="#e37400", rotation=-90)

    # Route cpu_rdata[31:0] output cleanly UNDER LRU/Victim boxes at y=28.5
    route_wire(ax, [(64, 36.5), (62, 36.5), (62, 28.5), (15.2, 28.5), (15.2, 59), (14, 59)], color="#b31412", lw=2)
    ax.text(37.5, 29.5, "cpu_rdata[31:0] (32-bit Read Data Word returning to CPU)", ha='center', va='bottom',
            fontsize=8.5, fontweight='bold', color="#b31412")

    # =========================================================================
    # 6. TRUE LRU & VICTIM SELECTION LOGIC (x=18 to 54, y=32 to 45)
    # =========================================================================
    lru_box = FancyBboxPatch((18, 32.5), 16.5, 12, boxstyle="round,pad=0.2",
                             ec=c_lru_b, fc=c_lru_f, lw=1.8)
    ax.add_patch(lru_box)
    ax.text(26.25, 42.5, "TRUE LRU ARRAY", ha='center', va='center',
            fontsize=9.5, fontweight='bold', color=c_lru_b)
    ax.text(26.25, 38.0, "lru [32 × 1-bit]\n0 = Way 0 is LRU\n1 = Way 1 is LRU",
            ha='center', va='center', fontsize=8, family='monospace')
    ax.text(26.25, 34.0, "Update on Hit: lru <= ~hit_way\nUpdate on Fill: lru <= ~victim_way",
            ha='center', va='center', fontsize=6.8, color="#70757a")

    vict_box = FancyBboxPatch((36.5, 32.5), 17.5, 12, boxstyle="round,pad=0.2",
                              ec="#b06000", fc="#ffe7d9", lw=1.8)
    ax.add_patch(vict_box)
    ax.text(45.25, 42.5, "VICTIM SELECT LOGIC", ha='center', va='center',
            fontsize=9.5, fontweight='bold', color="#b06000")
    ax.text(45.25, 37.0, "1. !valid0 → Way 0\n2. !valid1 → Way 1\n3. else    → lru[set]\n→ victim_way",
            ha='center', va='center', fontsize=7.5, family='monospace', fontweight='bold')

    # Connect LRU to Victim
    route_wire(ax, [(34.5, 38.5), (36.5, 38.5)], color=c_lru_b, lw=1.5)

    # =========================================================================
    # 7. CONTROLLER FSM (Bottom Left: x=2 to 57, y=1.5 to 26)
    # =========================================================================
    fsm_outer = FancyBboxPatch((2, 1.5), 55, 25, boxstyle="round,pad=0.3",
                               ec=c_fsm_b, fc=c_fsm_f, lw=2)
    ax.add_patch(fsm_outer)
    ax.text(29.5, 25.2, "CONTROLLER FINITE STATE MACHINE (FSM)", ha='center', va='center',
            fontsize=11.5, fontweight='bold', color=c_fsm_b)

    s_idle = Rectangle((4, 14), 23, 8.5, ec=c_fsm_b, fc="white", lw=1.2, zorder=2)
    ax.add_patch(s_idle)
    ax.text(15.5, 20.2, "STATE_IDLE (3'b000)", ha='center', va='center', fontsize=9, fontweight='bold')
    ax.text(15.5, 16.8, "Wait for cpu_req\nLatch addr/data/we\nActive cycle accounting",
            ha='center', va='center', fontsize=7.5)

    s_look = Rectangle((32, 14), 23, 8.5, ec=c_fsm_b, fc="white", lw=1.2, zorder=2)
    ax.add_patch(s_look)
    ax.text(43.5, 20.2, "STATE_LOOKUP (3'b001)", ha='center', va='center', fontsize=9, fontweight='bold')
    ax.text(43.5, 16.8, "Parallel Tag Match\nHit: cpu_ready=1 (2 cyc)\nMiss: Branch Fetch / Store",
            ha='center', va='center', fontsize=7.5)

    s_fetch = Rectangle((4, 3.5), 23, 8.5, ec=c_fsm_b, fc="white", lw=1.2, zorder=2)
    ax.add_patch(s_fetch)
    ax.text(15.5, 9.8, "STATE_MISS_FETCH (3'b010)", ha='center', va='center', fontsize=8.5, fontweight='bold')
    ax.text(15.5, 6.2, "Issue mem_req (RD_LAT=8 cyc)\nReceive 4-Word Burst (4 cyc)\nRefill victim way, lru<=~vict\ncpu_ready=1 (14 cyc total)",
            ha='center', va='center', fontsize=7)

    s_wt = Rectangle((32, 3.5), 23, 8.5, ec=c_fsm_b, fc="white", lw=1.2, zorder=2)
    ax.add_patch(s_wt)
    ax.text(43.5, 9.8, "STATE_WRITE_THROUGH (3'b011)", ha='center', va='center', fontsize=8.5, fontweight='bold')
    ax.text(43.5, 6.2, "No-Write-Allocate (miss bypass)\nmem_we=1 (WR_LAT=4 cyc)\nAwait mem_ready acknowledge\ncpu_ready=1 (7 cyc total)",
            ha='center', va='center', fontsize=7)

    # FSM Transitions
    # IDLE -> LOOKUP
    route_wire(ax, [(27, 18.2), (32, 18.2)], color=c_fsm_b, lw=1.8)
    ax.text(29.5, 19.3, "cpu_req", ha='center', va='bottom', fontsize=7.5, fontweight='bold', color=c_fsm_b)

    # LOOKUP -> IDLE (Read Hit)
    route_wire(ax, [(43.5, 22.5), (43.5, 23.8), (15.5, 23.8), (15.5, 22.5)], color="#137333", lw=1.8)
    ax.text(29.5, 24.2, "Hit (Read): cpu_ready=1", ha='center', va='bottom', fontsize=7.5, fontweight='bold', color="#137333")

    # LOOKUP -> MISS_FETCH (Read Miss)
    route_wire(ax, [(37, 14), (37, 12.8), (20, 12.8), (20, 12)], color=c_fsm_b, lw=1.5)
    ax.text(28.5, 13.3, "!hit && !req_we", ha='center', va='bottom', fontsize=7, color=c_fsm_b, fontweight='bold')

    # LOOKUP -> WRITE_THROUGH (Store)
    route_wire(ax, [(43.5, 14), (43.5, 12)], color=c_fsm_b, lw=1.5)
    ax.text(47, 13.0, "req_we", ha='center', va='center', fontsize=7, color=c_fsm_b, fontweight='bold')

    # MISS_FETCH -> IDLE (Refill done)
    route_wire(ax, [(4, 7.8), (2.5, 7.8), (2.5, 18.2), (4, 18.2)], color="#137333", lw=1.4)
    ax.text(1.2, 13, "burst done", ha='center', va='center', fontsize=6.5, color="#137333", rotation=90)

    # WRITE_THROUGH -> IDLE (mem_ready)
    route_wire(ax, [(55, 7.8), (56.5, 7.8), (56.5, 18.2), (55, 18.2)], color="#137333", lw=1.4)
    ax.text(57.8, 13, "mem_ready", ha='center', va='center', fontsize=6.5, color="#137333", rotation=-90)

    # Connect FSM cpu_ready to CPU card
    route_wire(ax, [(15.5, 22.5), (15.5, 54), (14, 54)], color="#b31412", lw=1.5)
    ax.text(13.8, 48, "cpu_ready", ha='right', va='center', fontsize=7.5, color="#b31412", fontweight='bold')

    # =========================================================================
    # 8. BACKING MEMORY INTERFACE & REFILL BUFFER (Right Column: x=96 to 112)
    # =========================================================================
    mem_card = FancyBboxPatch((96, 2), 16, 85, boxstyle="round,pad=0.4",
                              ec=c_mem_b, fc=c_mem_f, lw=2)
    ax.add_patch(mem_card)
    ax.text(104, 83.0, "BACKING MAIN MEMORY\nINTERFACE", ha='center', va='center',
            fontsize=11, fontweight='bold', color=c_mem_b)

    mem_sigs = [
        ("← mem_req", "Memory Request"),
        ("← mem_we", "1=Store, 0=Burst Read"),
        ("← mem_addr[31:0]", "Block-Aligned Addr"),
        ("← mem_wdata[31:0]", "Write Word Data"),
        ("→ mem_ready", "Ready / Burst Strobe"),
        ("→ mem_rdata[31:0]", "Burst Read Word")
    ]
    for i, (sig, desc) in enumerate(mem_sigs):
        color = '#b31412' if '←' in sig else '#137333'
        ax.text(96.8, 77.5 - i*3.6, sig, ha='left', va='center', fontsize=8,
                fontweight='bold', family='monospace', color=color)
        ax.text(96.8, 76.0 - i*3.6, f"  ({desc})", ha='left', va='center', fontsize=7, color='#5f6368')

    # Refill Buffer Box
    buf_box = Rectangle((97.5, 33), 13, 19, ec="#b06000", fc="white", lw=1.2, zorder=2)
    ax.add_patch(buf_box)
    ax.text(104, 49.5, "REFILL BUFFER", ha='center', va='center', fontsize=9, fontweight='bold', color="#b06000")
    ax.text(104, 42.0, "refill_buf[0..3]\n4 Words (16B Burst)\nWord 0: bits[31:0]\nWord 1: bits[63:32]\nWord 2: bits[95:64]\nWord 3: bits[127:96]",
            ha='center', va='center', fontsize=7.5, family='monospace')

    # Memory Timing Model Box
    param_box = Rectangle((97.5, 5), 13, 25, ec="#70757a", fc="#ffffff", lw=1.2, zorder=2)
    ax.add_patch(param_box)
    ax.text(104, 27.5, "MEMORY TIMINGS", ha='center', va='center', fontsize=9, fontweight='bold', color="#202124")
    ax.text(104, 16.5, "Block Read (Burst):\nRD_LAT = 8 cycles\nBurst  = 4 cycles\nTotal  = 14 cycles\n─────────────\nWord Write (WT):\nWR_LAT = 4 cycles\nTotal  = 7 cycles",
            ha='center', va='center', fontsize=7.5, family='monospace')

    # Clean Refill Data Bus connection from Refill Buffer to Way 0 and Way 1
    route_wire(ax, [(97.5, 42.5), (95.0, 42.5), (95.0, 31.0), (52.0, 31.0), (52.0, 68.5)], color="#b06000", lw=1.8, ls="--")
    route_wire(ax, [(52.0, 48.5), (51.0, 48.5)], color="#b06000", lw=1.8, ls="--")
    ax.text(74, 31.8, "Refill Data Bus: refill_buf[0..3] → victim_way", ha='center', va='bottom',
            fontsize=8, fontweight='bold', color="#b06000")

    # Connect victim_way to steer refill
    route_wire(ax, [(54, 38.5), (56, 38.5), (56, 31.0)], color="#b06000", lw=1.5)
    ax.text(56.5, 35.0, "victim_way", ha='left', va='center', fontsize=7.5, color="#b06000", fontweight='bold')

    # Save figure
    os.makedirs(os.path.dirname(output_png), exist_ok=True)
    plt.tight_layout()
    plt.savefig(output_png, dpi=300, facecolor=fig.get_facecolor(), bbox_inches='tight')
    plt.close()
    print(f"Successfully generated block diagram at: {output_png}")

def generate_drawio_xml(output_file):
    """Generates standard uncompressed Draw.io XML format so it can be opened directly in Draw.io."""
    xml_content = """<mxfile host="Electron" modified="2026-11-16T12:00:00.000Z" agent="Antigravity" version="21.0.0" type="device">
  <diagram id="cache_2way_lru" name="2-Way Set-Associative Cache Architecture">
    <mxGraphModel dx="1422" dy="854" grid="1" gridSize="10" guides="1" tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1" pageWidth="1654" pageHeight="1169" math="0" shadow="0">
      <root>
        <mxCell id="0"/>
        <mxCell id="1" parent="0"/>
        <mxCell id="title" value="&lt;b&gt;2-Way Set-Associative Cache Architecture (cache_2way_lru.v)&lt;/b&gt;&lt;br&gt;32 Sets × 2 Ways | 16-Byte Blocks (4 Words) | True LRU Replacement | Write-Through No-Write-Allocate" style="text;html=1;align=center;verticalAlign=middle;resizable=0;points=[];autosize=1;strokeColor=none;fillColor=none;fontSize=16;" vertex="1" parent="1">
          <mxGeometry x="400" y="20" width="850" height="40" as="geometry"/>
        </mxCell>
        <mxCell id="addr_bg" value="CPU 32-Bit Address [31:0]" style="swimlane;fontStyle=1;align=center;verticalAlign=top;childLayout=stackLayout;horizontal=1;startSize=26;horizontalStack=1;resizeParent=1;resizeParentMax=0;resizeLast=0;collapsible=1;marginBottom=0;html=1;fillColor=#ffffff;strokeColor=#70757a;" vertex="1" parent="1">
          <mxGeometry x="380" y="80" width="800" height="70" as="geometry"/>
        </mxCell>
        <mxCell id="addr_tag" value="TAG: req_tag = cpu_addr[31:9] (23 bits)" style="text;html=1;strokeColor=#1a73e8;fillColor=#d2e3fc;align=center;verticalAlign=middle;spacingLeft=4;spacingRight=4;overflow=hidden;rotatable=0;points=[[0,0.5],[1,0.5]];portConstraint=eastwest;fontStyle=1;" vertex="1" parent="addr_bg">
          <mxGeometry y="26" width="380" height="44" as="geometry"/>
        </mxCell>
        <mxCell id="addr_idx" value="INDEX: req_index = cpu_addr[8:4] (5 bits → 32 Sets)" style="text;html=1;strokeColor=#137333;fillColor=#ceead6;align=center;verticalAlign=middle;spacingLeft=4;spacingRight=4;overflow=hidden;rotatable=0;points=[[0,0.5],[1,0.5]];portConstraint=eastwest;fontStyle=1;" vertex="1" parent="addr_bg">
          <mxGeometry x="380" y="26" width="260" height="44" as="geometry"/>
        </mxCell>
        <mxCell id="addr_off" value="OFFSET: [3:0]&#xa;[3:2] Word | [1:0] Byte" style="text;html=1;strokeColor=#e37400;fillColor=#ffe7d9;align=center;verticalAlign=middle;spacingLeft=4;spacingRight=4;overflow=hidden;rotatable=0;points=[[0,0.5],[1,0.5]];portConstraint=eastwest;fontStyle=1;" vertex="1" parent="addr_bg">
          <mxGeometry x="640" y="26" width="160" height="44" as="geometry"/>
        </mxCell>
        <mxCell id="cpu_bus" value="&lt;b&gt;CPU BUS INTERFACE&lt;/b&gt;&lt;br&gt;&lt;br&gt;→ cpu_req&lt;br&gt;→ cpu_we&lt;br&gt;→ cpu_addr[31:0]&lt;br&gt;→ cpu_wdata[31:0]&lt;br&gt;← cpu_ready&lt;br&gt;← cpu_rdata[31:0]" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#e8f0fe;strokeColor=#1a73e8;align=left;spacingLeft=10;fontFamily=Courier New;" vertex="1" parent="1">
          <mxGeometry x="60" y="180" width="180" height="200" as="geometry"/>
        </mxCell>
        <mxCell id="way0" value="&lt;b&gt;WAY 0 STORAGE ARRAY (32 Sets)&lt;/b&gt;&lt;br&gt;&lt;br&gt;valid0 [32 × 1b] | tag0 [32 × 23b] | data0 [32 × 4 words = 128b]" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#e6f4ea;strokeColor=#137333;align=center;" vertex="1" parent="1">
          <mxGeometry x="360" y="190" width="460" height="120" as="geometry"/>
        </mxCell>
        <mxCell id="way1" value="&lt;b&gt;WAY 1 STORAGE ARRAY (32 Sets)&lt;/b&gt;&lt;br&gt;&lt;br&gt;valid1 [32 × 1b] | tag1 [32 × 23b] | data1 [32 × 4 words = 128b]" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#f3e8fd;strokeColor=#7627bb;align=center;" vertex="1" parent="1">
          <mxGeometry x="360" y="340" width="460" height="120" as="geometry"/>
        </mxCell>
        <mxCell id="cmp0" value="&lt;b&gt;TAG COMPARATOR 0&lt;/b&gt;&lt;br&gt;tag0 == req_tag &amp;&amp; valid0&#xa;→ hit0" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#ceead6;strokeColor=#137333;align=center;fontFamily=Courier New;" vertex="1" parent="1">
          <mxGeometry x="880" y="210" width="220" height="70" as="geometry"/>
        </mxCell>
        <mxCell id="cmp1" value="&lt;b&gt;TAG COMPARATOR 1&lt;/b&gt;&lt;br&gt;tag1 == req_tag &amp;&amp; valid1&#xa;→ hit1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#e8d0fb;strokeColor=#7627bb;align=center;fontFamily=Courier New;" vertex="1" parent="1">
          <mxGeometry x="880" y="360" width="220" height="70" as="geometry"/>
        </mxCell>
        <mxCell id="hit_logic" value="&lt;b&gt;HIT LOGIC&lt;/b&gt;&lt;br&gt;hit = hit0 || hit1&#xa;hit_way = hit1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#f1f3f4;strokeColor=#5f6368;align=center;fontFamily=Courier New;" vertex="1" parent="1">
          <mxGeometry x="1160" y="280" width="160" height="80" as="geometry"/>
        </mxCell>
        <mxCell id="hit_mux" value="&lt;b&gt;HIT-WAY &amp; WORD MUX&lt;/b&gt;&lt;br&gt;128b Way MUX (sel: hit_way)&#xa;32b Word MUX (sel: addr[3:2])&#xa;→ cpu_rdata[31:0]" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#e1f5fe;strokeColor=#0288d1;align=center;" vertex="1" parent="1">
          <mxGeometry x="880" y="470" width="260" height="90" as="geometry"/>
        </mxCell>
        <mxCell id="lru" value="&lt;b&gt;TRUE LRU ARRAY&lt;/b&gt;&lt;br&gt;lru [32 × 1-bit]&#xa;0 = Way 0 LRU, 1 = Way 1 LRU" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#fff8e1;strokeColor=#e37400;align=center;" vertex="1" parent="1">
          <mxGeometry x="360" y="490" width="200" height="70" as="geometry"/>
        </mxCell>
        <mxCell id="victim" value="&lt;b&gt;VICTIM SELECT LOGIC&lt;/b&gt;&lt;br&gt;!valid0 ? Way 0 :&#xa;!valid1 ? Way 1 : lru[set]&#xa;→ victim_way" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#ffe7d9;strokeColor=#b06000;align=center;fontFamily=Courier New;" vertex="1" parent="1">
          <mxGeometry x="600" y="490" width="220" height="70" as="geometry"/>
        </mxCell>
        <mxCell id="fsm" value="&lt;b&gt;CONTROLLER FSM (cache_2way_lru.v)&lt;/b&gt;&lt;br&gt;&lt;br&gt;STATE_IDLE (000): Latch inputs, active counter&#xa;STATE_LOOKUP (001): Parallel compare, hit in 2 cycles&#xa;STATE_MISS_FETCH (010): 4-word burst refill (14 cycles)&#xa;STATE_WRITE_THROUGH (011): Forward store to mem (7 cycles)" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#fce8e6;strokeColor=#c5221f;align=left;spacingLeft=15;" vertex="1" parent="1">
          <mxGeometry x="60" y="600" width="760" height="150" as="geometry"/>
        </mxCell>
        <mxCell id="mem_bus" value="&lt;b&gt;MAIN MEMORY INTERFACE&lt;/b&gt;&lt;br&gt;&lt;br&gt;← mem_req&#xa;← mem_we&#xa;← mem_addr[31:0]&#xa;← mem_wdata[31:0]&#xa;→ mem_ready&#xa;→ mem_rdata[31:0]&lt;br&gt;&lt;br&gt;&lt;b&gt;Refill Buffer:&lt;/b&gt; 4 Words (16B burst)&#xa;&lt;b&gt;RD_LAT:&lt;/b&gt; 8 cycles&#xa;&lt;b&gt;WR_LAT:&lt;/b&gt; 4 cycles" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#fef7e0;strokeColor=#f9ab00;align=left;spacingLeft=10;fontFamily=Courier New;" vertex="1" parent="1">
          <mxGeometry x="1380" y="180" width="220" height="400" as="geometry"/>
        </mxCell>
        <mxCell id="edge1" style="edgeStyle=orthogonalEdgeStyle;rounded=0;orthogonalLoop=1;jettySize=auto;html=1;exitX=1;exitY=0.5;entryX=0;entryY=0.5;strokeColor=#137333;strokeWidth=2;" edge="1" parent="1" source="way0" target="cmp0">
          <mxGeometry relative="1" as="geometry"/>
        </mxCell>
        <mxCell id="edge2" style="edgeStyle=orthogonalEdgeStyle;rounded=0;orthogonalLoop=1;jettySize=auto;html=1;exitX=1;exitY=0.5;entryX=0;entryY=0.5;strokeColor=#7627bb;strokeWidth=2;" edge="1" parent="1" source="way1" target="cmp1">
          <mxGeometry relative="1" as="geometry"/>
        </mxCell>
        <mxCell id="edge3" style="edgeStyle=orthogonalEdgeStyle;rounded=0;orthogonalLoop=1;jettySize=auto;html=1;exitX=1;exitY=0.5;entryX=0;entryY=0.25;strokeColor=#137333;strokeWidth=2;" edge="1" parent="1" source="cmp0" target="hit_logic">
          <mxGeometry relative="1" as="geometry"/>
        </mxCell>
        <mxCell id="edge4" style="edgeStyle=orthogonalEdgeStyle;rounded=0;orthogonalLoop=1;jettySize=auto;html=1;exitX=1;exitY=0.5;entryX=0;entryY=0.75;strokeColor=#7627bb;strokeWidth=2;" edge="1" parent="1" source="cmp1" target="hit_logic">
          <mxGeometry relative="1" as="geometry"/>
        </mxCell>
      </root>
    </mxGraphModel>
  </diagram>
</mxfile>"""
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(xml_content)
    print(f"Successfully generated Draw.io XML at: {output_file}")

if __name__ == "__main__":
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    png_path = os.path.join(base_dir, "docs", "img", "block_diagram.png")
    drawio_path = os.path.join(base_dir, "docs", "img", "block_diagram.drawio")
    if len(sys.argv) > 1:
        png_path = sys.argv[1]
    draw_block_diagram(png_path)
    generate_drawio_xml(drawio_path)
