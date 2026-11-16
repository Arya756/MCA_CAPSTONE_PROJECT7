#!/usr/bin/env bash
# Generator script for docs/img/block_diagram.png
# Owner: Member 5 (Report, Diagrams, Synthesis, Video)
# Project 7: 2-Way Set-Associative Cache with LRU vs Direct-Mapped
""":"
# Python execution wrapper
command -v uv >/dev/null 2>&1 && exec uv run --with matplotlib python3 "$0" "$@"
exec python3 "$0" "$@"
"""

import sys
import os
import matplotlib.pyplot as plt
import matplotlib.patches as patches
from matplotlib.patches import FancyBboxPatch, ArrowStyle

def create_block_diagram(output_path):
    fig, ax = plt.subplots(figsize=(18, 12), dpi=300)
    ax.set_xlim(0, 100)
    ax.set_ylim(0, 100)
    ax.axis('off')

    # Color Palette - Professional Engineering Style
    c_bg = "#f8f9fa"
    c_cpu = "#e3f2fd"
    c_cpu_b = "#1976d2"
    c_mem = "#fff3e0"
    c_mem_b = "#f57c00"
    c_way0 = "#e8f5e9"
    c_way0_b = "#388e3c"
    c_way1 = "#ede7f6"
    c_way1_b = "#512da8"
    c_ctrl = "#fce4ec"
    c_ctrl_b = "#c2185b"
    c_lru = "#fffde7"
    c_lru_b = "#fbc02d"
    c_wire = "#37474f"
    c_bus = "#263238"

    # Background canvas
    fig.patch.set_facecolor('white')

    # Title Banner
    ax.text(50, 97.5, "2-Way Set-Associative Cache Architecture (cache_2way_lru.v)",
            ha='center', va='center', fontsize=18, fontweight='bold', color='#1a237e')
    ax.text(50, 95.5, "32 Sets × 2 Ways | 16-Byte Blocks (4 Words) | True LRU Replacement | Write-Through No-Write-Allocate",
            ha='center', va='center', fontsize=11, fontstyle='italic', color='#455a64')

    # =========================================================================
    # 1. 32-BIT CPU ADDRESS DECOMPOSITION (Top)
    # =========================================================================
    # Total width: 70 units (x=15 to 85, y=88 to 93)
    ax.text(50, 92.5, "CPU 32-Bit Address Decomposition: cpu_addr[31:0]",
            ha='center', va='center', fontsize=11, fontweight='bold', color=c_bus)

    # Tag field [31:9] -> 23 bits (width 40)
    tag_box = FancyBboxPatch((15, 87), 40, 4, boxstyle="round,pad=0.2",
                             ec=c_cpu_b, fc='#bbdefb', lw=1.5)
    ax.add_patch(tag_box)
    ax.text(35, 89.5, "TAG: req_tag = cpu_addr[31:9]\n(23 bits)",
            ha='center', va='center', fontsize=10, fontweight='bold')

    # Index field [8:4] -> 5 bits (width 16)
    idx_box = FancyBboxPatch((56, 87), 16, 4, boxstyle="round,pad=0.2",
                             ec='#00796b', fc='#b2dfdb', lw=1.5)
    ax.add_patch(idx_box)
    ax.text(64, 89.5, "INDEX: req_index = cpu_addr[8:4]\n(5 bits → 32 Sets: 0..31)",
            ha='center', va='center', fontsize=9, fontweight='bold')

    # Offset field [3:0] -> 4 bits (width 13)
    off_box = FancyBboxPatch((73, 87), 12, 4, boxstyle="round,pad=0.2",
                             ec='#f57c00', fc='#ffe0b2', lw=1.5)
    ax.add_patch(off_box)
    ax.text(79, 89.5, "OFFSET: [3:0]\n[3:2] Word | [1:0] Byte",
            ha='center', va='center', fontsize=8.5, fontweight='bold')

    # =========================================================================
    # 2. CPU BUS INTERFACE (Left Column: x=3 to 13, y=55 to 80)
    # =========================================================================
    cpu_box = FancyBboxPatch((3, 56), 11, 26, boxstyle="round,pad=0.4",
                             ec=c_cpu_b, fc=c_cpu, lw=2)
    ax.add_patch(cpu_box)
    ax.text(8.5, 80, "CPU BUS\nINTERFACE", ha='center', va='center',
            fontsize=11, fontweight='bold', color=c_cpu_b)
    
    cpu_signals = [
        "→ cpu_req",
        "→ cpu_we",
        "→ cpu_addr[31:0]",
        "→ cpu_wdata[31:0]",
        "← cpu_ready",
        "← cpu_rdata[31:0]"
    ]
    for i, sig in enumerate(cpu_signals):
        color = '#b71c1c' if '←' in sig else '#0d47a1'
        ax.text(4, 75 - i*3.2, sig, ha='left', va='center', fontsize=9,
                fontweight='semibold', family='monospace', color=color)

    # Latch Box
    latch_box = FancyBboxPatch((16, 68), 9, 13, boxstyle="round,pad=0.2",
                               ec='#78909c', fc='#eceff1', lw=1.5)
    ax.add_patch(latch_box)
    ax.text(20.5, 78.5, "LATCH REGS", ha='center', va='center', fontsize=9, fontweight='bold')
    ax.text(20.5, 75, "req_addr[31:0]\nreq_we\nreq_wdata[31:0]",
            ha='center', va='center', fontsize=8, family='monospace')
    ax.annotate("", xy=(16, 73), xytext=(14, 73),
                arrowprops=dict(arrowstyle="->", color=c_wire, lw=1.5))

    # =========================================================================
    # 3. WAY 0 & WAY 1 STORAGE ARRAYS (Center: x=29 to 68)
    # =========================================================================
    # WAY 0
    way0_box = FancyBboxPatch((28, 64), 38, 17, boxstyle="round,pad=0.3",
                              ec=c_way0_b, fc=c_way0, lw=2)
    ax.add_patch(way0_box)
    ax.text(47, 79, "WAY 0 STORAGE ARRAY (32 Sets)", ha='center', va='center',
            fontsize=11, fontweight='bold', color=c_way0_b)

    # Sub-arrays Way 0
    v0_box = FancyBboxPatch((29.5, 66), 6, 10.5, boxstyle="square,pad=0.1", ec='#4caf50', fc='white', lw=1.2)
    ax.add_patch(v0_box)
    ax.text(32.5, 71.5, "valid0\n[32×1b]", ha='center', va='center', fontsize=8.5, fontweight='bold')

    t0_box = FancyBboxPatch((36.5, 66), 11, 10.5, boxstyle="square,pad=0.1", ec='#4caf50', fc='white', lw=1.2)
    ax.add_patch(t0_box)
    ax.text(42, 71.5, "tag0\n[32 × 23-bit]", ha='center', va='center', fontsize=8.5, fontweight='bold')

    d0_box = FancyBboxPatch((48.5, 66), 16.5, 10.5, boxstyle="square,pad=0.1", ec='#4caf50', fc='white', lw=1.2)
    ax.add_patch(d0_box)
    ax.text(56.7, 71.5, "data0\n[32 × 4 words]\n(128b / block)", ha='center', va='center', fontsize=8.5, fontweight='bold')

    # WAY 1
    way1_box = FancyBboxPatch((28, 44), 38, 17, boxstyle="round,pad=0.3",
                              ec=c_way1_b, fc=c_way1, lw=2)
    ax.add_patch(way1_box)
    ax.text(47, 59, "WAY 1 STORAGE ARRAY (32 Sets)", ha='center', va='center',
            fontsize=11, fontweight='bold', color=c_way1_b)

    # Sub-arrays Way 1
    v1_box = FancyBboxPatch((29.5, 46), 6, 10.5, boxstyle="square,pad=0.1", ec='#7e57c2', fc='white', lw=1.2)
    ax.add_patch(v1_box)
    ax.text(32.5, 51.5, "valid1\n[32×1b]", ha='center', va='center', fontsize=8.5, fontweight='bold')

    t1_box = FancyBboxPatch((36.5, 46), 11, 10.5, boxstyle="square,pad=0.1", ec='#7e57c2', fc='white', lw=1.2)
    ax.add_patch(t1_box)
    ax.text(42, 51.5, "tag1\n[32 × 23-bit]", ha='center', va='center', fontsize=8.5, fontweight='bold')

    d1_box = FancyBboxPatch((48.5, 46), 16.5, 10.5, boxstyle="square,pad=0.1", ec='#7e57c2', fc='white', lw=1.2)
    ax.add_patch(d1_box)
    ax.text(56.7, 51.5, "data1\n[32 × 4 words]\n(128b / block)", ha='center', va='center', fontsize=8.5, fontweight='bold')

    # LRU Array Box
    lru_box = FancyBboxPatch((28, 32), 17, 9.5, boxstyle="round,pad=0.2",
                             ec=c_lru_b, fc=c_lru, lw=2)
    ax.add_patch(lru_box)
    ax.text(36.5, 38.5, "TRUE LRU ARRAY", ha='center', va='center', fontsize=9.5, fontweight='bold', color='#f57f17')
    ax.text(36.5, 35, "lru [32 × 1-bit]\n0 = Way0 LRU, 1 = Way1 LRU",
            ha='center', va='center', fontsize=8, family='monospace')

    # =========================================================================
    # 4. TAG COMPARATORS & HIT LOGIC (Right of Arrays: x=70 to 86)
    # =========================================================================
    # Comparator 0
    cmp0 = FancyBboxPatch((70, 71), 14, 8, boxstyle="round,pad=0.2",
                          ec=c_way0_b, fc='#c8e6c9', lw=1.5)
    ax.add_patch(cmp0)
    ax.text(77, 75, "TAG COMPARE 0\ntag0 == req_tag && valid0\n→ hit0",
            ha='center', va='center', fontsize=8, fontweight='bold')

    # Comparator 1
    cmp1 = FancyBboxPatch((70, 51), 14, 8, boxstyle="round,pad=0.2",
                          ec=c_way1_b, fc='#d1c4e9', lw=1.5)
    ax.add_patch(cmp1)
    ax.text(77, 55, "TAG COMPARE 1\ntag1 == req_tag && valid1\n→ hit1",
            ha='center', va='center', fontsize=8, fontweight='bold')

    # Hit OR Gate & hit_way
    hit_gate = FancyBboxPatch((87, 60), 10.5, 10, boxstyle="round,pad=0.2",
                              ec='#37474f', fc='#cfd8dc', lw=1.5)
    ax.add_patch(hit_gate)
    ax.text(92.25, 65, "HIT LOGIC\nhit = hit0 || hit1\nhit_way = hit1",
            ha='center', va='center', fontsize=8, fontweight='bold')

    # Connect tag0 to cmp0 and tag1 to cmp1
    ax.annotate("", xy=(70, 75), xytext=(47.5, 75),
                arrowprops=dict(arrowstyle="->", color=c_wire, lw=1.2))
    ax.annotate("", xy=(70, 55), xytext=(47.5, 55),
                arrowprops=dict(arrowstyle="->", color=c_wire, lw=1.2))

    # Connect cmp outputs to hit_gate
    ax.annotate("", xy=(87, 67), xytext=(84, 75),
                arrowprops=dict(arrowstyle="->", color='#2e7d32', lw=1.5))
    ax.annotate("", xy=(87, 63), xytext=(84, 55),
                arrowprops=dict(arrowstyle="->", color='#512da8', lw=1.5))

    # =========================================================================
    # 5. HIT-WAY DATA MUX & WORD SELECT
    # =========================================================================
    mux_box = FancyBboxPatch((70, 34), 16, 12, boxstyle="round,pad=0.2",
                             ec='#0288d1', fc='#e1f5fe', lw=1.5)
    ax.add_patch(mux_box)
    ax.text(78, 43, "HIT-WAY & WORD MUX", ha='center', va='center', fontsize=9, fontweight='bold', color='#0277bd')
    ax.text(78, 39, "Way0/1 Word MUX\nsel: hit_way (hit1)\nword_sel: cpu_addr[3:2]",
            ha='center', va='center', fontsize=8)
    ax.text(78, 35.5, "→ cpu_rdata[31:0]", ha='center', va='center', fontsize=8.5,
            fontweight='bold', family='monospace', color='#0d47a1')

    # Data lines into Mux
    ax.annotate("", xy=(70, 42), xytext=(65, 70),
                arrowprops=dict(arrowstyle="->", color='#2e7d32', lw=1.2, linestyle='--'))
    ax.annotate("", xy=(70, 39), xytext=(65, 50),
                arrowprops=dict(arrowstyle="->", color='#512da8', lw=1.2, linestyle='--'))

    # =========================================================================
    # 6. VICTIM SELECT & LRU UPDATE LOGIC
    # =========================================================================
    victim_box = FancyBboxPatch((48, 32), 19, 9.5, boxstyle="round,pad=0.2",
                                ec='#e65100', fc='#ffe0b2', lw=1.5)
    ax.add_patch(victim_box)
    ax.text(57.5, 39, "VICTIM SELECT LOGIC", ha='center', va='center',
            fontsize=9.5, fontweight='bold', color='#e65100')
    ax.text(57.5, 35, "!valid0 ? Way0 :\n!valid1 ? Way1 : lru[set]\n→ victim_way",
            ha='center', va='center', fontsize=8, family='monospace')

    # LRU into victim
    ax.annotate("", xy=(48, 36.5), xytext=(45, 36.5),
                arrowprops=dict(arrowstyle="->", color='#f57f17', lw=1.5))

    # =========================================================================
    # 7. CONTROLLER FINITE STATE MACHINE (FSM) (Bottom Left: x=3 to 50, y=3 to 27)
    # =========================================================================
    fsm_outer = FancyBboxPatch((3, 3), 48, 26, boxstyle="round,pad=0.3",
                               ec=c_ctrl_b, fc=c_ctrl, lw=2)
    ax.add_patch(fsm_outer)
    ax.text(27, 26.5, "CONTROLLER FSM (cache_2way_lru.v)", ha='center', va='center',
            fontsize=11, fontweight='bold', color=c_ctrl_b)

    # 4 State Boxes
    # State IDLE (3'b000)
    s_idle = FancyBboxPatch((5, 16.5), 18, 7.5, boxstyle="round,pad=0.2",
                            ec='#880e4f', fc='white', lw=1.2)
    ax.add_patch(s_idle)
    ax.text(14, 21.5, "STATE_IDLE (3'b000)", ha='center', va='center', fontsize=8.5, fontweight='bold')
    ax.text(14, 18.5, "Wait cpu_req\nLatch addr/data/we", ha='center', va='center', fontsize=7.5)

    # State LOOKUP (3'b001)
    s_lookup = FancyBboxPatch((29, 16.5), 20, 7.5, boxstyle="round,pad=0.2",
                              ec='#880e4f', fc='white', lw=1.2)
    ax.add_patch(s_lookup)
    ax.text(39, 21.5, "STATE_LOOKUP (3'b001)", ha='center', va='center', fontsize=8.5, fontweight='bold')
    ax.text(39, 18.5, "Parallel Tag Match\nHit: cpu_ready=1 (2 cyc)\nMiss: Branch Fetch/Write",
            ha='center', va='center', fontsize=7.5)

    # State MISS_FETCH (3'b010)
    s_fetch = FancyBboxPatch((5, 5.5), 19, 8.5, boxstyle="round,pad=0.2",
                             ec='#880e4f', fc='white', lw=1.2)
    ax.add_patch(s_fetch)
    ax.text(14.5, 11, "STATE_MISS_FETCH (3'b010)", ha='center', va='center', fontsize=8.5, fontweight='bold')
    ax.text(14.5, 7.5, "Read block from mem\nReceive 4-word burst\nRefill victim way, lru<=~vict\ncpu_ready=1 (14 cyc)",
            ha='center', va='center', fontsize=7)

    # State WRITE_THROUGH (3'b011)
    s_wt = FancyBboxPatch((29, 5.5), 20, 8.5, boxstyle="round,pad=0.2",
                          ec='#880e4f', fc='white', lw=1.2)
    ax.add_patch(s_wt)
    ax.text(39, 11, "STATE_WRITE_THROUGH (3'b011)", ha='center', va='center', fontsize=8.5, fontweight='bold')
    ax.text(39, 7.5, "mem_we=1, forward word\nNo-Write-Allocate (miss bypass)\nAwait mem_ready\ncpu_ready=1 (7 cyc)",
            ha='center', va='center', fontsize=7)

    # FSM Transition Arrows
    # IDLE -> LOOKUP
    ax.annotate("", xy=(29, 20.25), xytext=(23, 20.25),
                arrowprops=dict(arrowstyle="->", color='#880e4f', lw=1.5))
    ax.text(26, 21.2, "cpu_req", ha='center', va='center', fontsize=7, color='#880e4f', fontweight='bold')

    # LOOKUP -> MISS_FETCH (Read miss)
    ax.annotate("", xy=(14.5, 14), xytext=(35, 16.5),
                arrowprops=dict(arrowstyle="->", color='#c2185b', lw=1.2, connectionstyle="arc3,rad=0.2"))
    ax.text(23, 14.5, "!hit && !req_we", ha='center', va='center', fontsize=7, color='#c2185b', fontweight='bold')

    # LOOKUP -> WRITE_THROUGH (req_we)
    ax.annotate("", xy=(39, 14), xytext=(39, 16.5),
                arrowprops=dict(arrowstyle="->", color='#c2185b', lw=1.2))
    ax.text(43.5, 15.25, "req_we", ha='center', va='center', fontsize=7, color='#c2185b', fontweight='bold')

    # Return to IDLE
    ax.annotate("", xy=(7, 16.5), xytext=(7, 14),
                arrowprops=dict(arrowstyle="->", color='#2e7d32', lw=1.2))
    ax.text(4, 15, "done", ha='center', va='center', fontsize=6.5, color='#2e7d32')

    # =========================================================================
    # 8. MEMORY CONTROLLER INTERFACE & REFILL (Right Column: x=88 to 98, y=5 to 45)
    # =========================================================================
    mem_box = FancyBboxPatch((86, 6), 11, 40, boxstyle="round,pad=0.4",
                             ec=c_mem_b, fc=c_mem, lw=2)
    ax.add_patch(mem_box)
    ax.text(91.5, 43, "MAIN MEMORY\nINTERFACE", ha='center', va='center',
            fontsize=10.5, fontweight='bold', color=c_mem_b)

    mem_signals = [
        "← mem_req",
        "← mem_we",
        "← mem_addr[31:0]",
        "← mem_wdata[31:0]",
        "→ mem_ready",
        "→ mem_rdata[31:0]",
        "─────────────",
        "Refill Buffer:",
        "refill_buf[0..3]",
        "4 words (16B burst)",
        "RD_LAT: 8 cycles",
        "WR_LAT: 4 cycles"
    ]
    for i, sig in enumerate(mem_signals):
        color = '#b71c1c' if '←' in sig else ('#2e7d32' if '→' in sig else '#455a64')
        weight = 'bold' if 'Buffer' in sig or 'LAT' in sig else 'normal'
        ax.text(87, 39 - i*2.7, sig, ha='left', va='center', fontsize=7.5,
                family='monospace', color=color, fontweight=weight)

    # Memory bus arrows
    ax.annotate("", xy=(86, 25), xytext=(51, 10),
                arrowprops=dict(arrowstyle="<->", color=c_bus, lw=1.5, linestyle=':'))
    ax.text(68, 16, "Refill / Write-Through Bus\n(4-word burst / 1-word store)",
            ha='center', va='center', fontsize=8, color=c_bus, fontstyle='italic')

    # Refill path into Way0 / Way1
    ax.annotate("", xy=(48, 64), xytext=(51, 32),
                arrowprops=dict(arrowstyle="->", color='#e65100', lw=1.5, linestyle='--'))
    ax.text(54, 43, "refill_buf → victim_way", ha='left', va='center',
            fontsize=7.5, color='#e65100', fontweight='bold')

    # Index distribution lines
    ax.annotate("", xy=(32.5, 81), xytext=(64, 87),
                arrowprops=dict(arrowstyle="->", color='#00796b', lw=1.2, connectionstyle="arc3,rad=-0.1"))
    ax.text(48, 83.5, "req_index[4:0] (Set 0..31 select)", ha='center', va='center',
            fontsize=8, color='#00796b', fontweight='bold')

    # Save figure
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    plt.tight_layout()
    plt.savefig(output_path, dpi=300, facecolor=fig.get_facecolor(), bbox_inches='tight')
    plt.close()
    print(f"Successfully generated block diagram at: {output_path}")

if __name__ == "__main__":
    out = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "docs", "img", "block_diagram.png")
    if len(sys.argv) > 1:
        out = sys.argv[1]
    create_block_diagram(out)
