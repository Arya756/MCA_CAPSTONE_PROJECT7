#!/usr/bin/env python3
"""
scripts/plot_waveform.py
Generates digital timing diagrams from results/lru_directed.vcd:
1. docs/img/waveform_miss.png: 30 ns to 200 ns (cold miss on Addr A)
2. docs/img/waveform_hit.png: 350 ns to 400 ns (read hit on Addr A)

Signals plotted (stacked, one row per signal):
- clk, cpu_req, cpu_we, cpu_addr (hex), state (localparam label),
  hit0, hit1, hit_way, victim_way, mem_req, mem_ready, mem_rdata (hex),
  refill_count, cpu_ready, cpu_rdata (hex)
"""

import os
import sys

# Ensure matplotlib cache is in a writable directory
os.environ.setdefault("MPLCONFIGDIR", "/tmp/matplotlib")

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Polygon


# FSM state name mapping from rtl/cache_2way_lru.v localparams
STATE_NAMES = {
    0: "STATE_IDLE",
    1: "STATE_LOOKUP",
    2: "STATE_MISS_FETCH",
    3: "STATE_WRITE_THROUGH"
}

STATE_COLORS = {
    "STATE_IDLE": "#f1f3f4",
    "STATE_LOOKUP": "#fef7e0",
    "STATE_MISS_FETCH": "#fce8e6",
    "STATE_WRITE_THROUGH": "#f3e8fd"
}

# Signal order and display types
SIGNALS_TO_PLOT = [
    ("clk", "bit"),
    ("cpu_req", "bit"),
    ("cpu_we", "bit"),
    ("cpu_addr", "hex"),
    ("state", "state"),
    ("hit0", "bit"),
    ("hit1", "bit"),
    ("hit_way", "bit"),
    ("victim_way", "bit"),
    ("mem_req", "bit"),
    ("mem_ready", "bit"),
    ("mem_rdata", "hex"),
    ("refill_count", "dec"),
    ("cpu_ready", "bit"),
    ("cpu_rdata", "hex")
]


def parse_vcd(vcd_path):
    """
    Robust native VCD parser. Extracts all signals under tb_lru_directed.uut_cache.
    Returns:
        sig_info: dict of {var_id: {"name": str, "size": int}}
        waveforms: dict of {var_name: list of (timestamp_ps, value_str)}
    """
    sig_info = {}
    path_stack = []
    
    with open(vcd_path, "r", encoding="utf-8") as f:
        # 1. Parse header definitions
        for line in f:
            line = line.strip()
            if not line:
                continue
            if line.startswith("$scope"):
                parts = line.split()
                if len(parts) >= 3:
                    path_stack.append(parts[2])
            elif line.startswith("$upscope"):
                if path_stack:
                    path_stack.pop()
            elif line.startswith("$var"):
                parts = line.split()
                if len(parts) >= 5:
                    vtype, size, vid, vname = parts[1], parts[2], parts[3], parts[4]
                    full_path = ".".join(path_stack + [vname])
                    if "uut_cache" in full_path:
                        sig_info[vid] = {"name": vname, "size": int(size), "path": full_path}
            elif line.startswith("$enddefinitions"):
                break

        # Map variable ID to target signal name
        vid_to_name = {vid: info["name"] for vid, info in sig_info.items()}
        target_names = {name for name, _ in SIGNALS_TO_PLOT}
        waveforms = {name: [] for name in target_names}

        # 2. Parse value change records
        time_ps = 0
        for line in f:
            line = line.strip()
            if not line:
                continue
            if line.startswith("#"):
                time_ps = int(line[1:])
            elif line[0] in "01xXzZ" and len(line) > 1 and not line.startswith("b") and not line.startswith("B"):
                val = line[0]
                vid = line[1:]
                if vid in vid_to_name and vid_to_name[vid] in target_names:
                    waveforms[vid_to_name[vid]].append((time_ps, val))
            elif line.startswith("b") or line.startswith("B"):
                parts = line[1:].split()
                if len(parts) == 2:
                    val, vid = parts
                    if vid in vid_to_name and vid_to_name[vid] in target_names:
                        waveforms[vid_to_name[vid]].append((time_ps, val))

    return waveforms


def get_signal_intervals(changes, t_start_ns, t_end_ns):
    """
    Decomposes a signal into time intervals [t1, t2) with constant value over [t_start_ns, t_end_ns].
    """
    t_start_ps = int(t_start_ns * 1000)
    t_end_ps = int(t_end_ns * 1000)

    # Initial value prior to t_start_ps
    init_val = "0"
    for t, val in changes:
        if t <= t_start_ps:
            init_val = val
        else:
            break

    win_changes = [(t, v) for t, v in changes if t_start_ps < t <= t_end_ps]

    intervals = []
    curr_t = t_start_ps
    curr_v = init_val
    for t, v in win_changes:
        if t > curr_t:
            intervals.append((curr_t / 1000.0, t / 1000.0, curr_v))
        curr_t = t
        curr_v = v
    if curr_t < t_end_ps:
        intervals.append((curr_t / 1000.0, t_end_ps / 1000.0, curr_v))

    return intervals


def format_value(sig_type, raw_val):
    """Formats binary raw strings into display labels."""
    if raw_val in ["x", "X", "z", "Z", ""]:
        return raw_val

    if sig_type == "state":
        try:
            val_int = int(raw_val, 2)
            return STATE_NAMES.get(val_int, f"S{val_int}")
        except ValueError:
            return raw_val
    elif sig_type == "hex":
        try:
            val_int = int(raw_val, 2)
            return f"0x{val_int:08X}"
        except ValueError:
            return raw_val
    elif sig_type == "dec":
        try:
            return str(int(raw_val, 2))
        except ValueError:
            return raw_val
    elif sig_type == "bit":
        return "1" if raw_val in ["1", "b1", "1'b1"] else "0"
    return raw_val


def plot_waveform(waveforms, t_start_ns, t_end_ns, title_text, output_path):
    """
    Renders a stacked digital timing diagram to output_path.
    """
    num_signals = len(SIGNALS_TO_PLOT)
    fig_height = 0.55 * num_signals + 2.2
    fig, ax = plt.subplots(figsize=(14, fig_height), dpi=180)

    # Detect cpu_req rise and cpu_ready rise/fall timestamps in window
    req_changes = waveforms.get("cpu_req", [])
    ready_changes = waveforms.get("cpu_ready", [])

    t_req_rise = None
    for t_ps, v in req_changes:
        t_ns = t_ps / 1000.0
        if t_start_ns <= t_ns <= t_end_ns and v == "1":
            t_req_rise = t_ns
            break

    t_ready_rise = None
    t_ready_fall = None
    for t_ps, v in ready_changes:
        t_ns = t_ps / 1000.0
        if t_start_ns <= t_ns <= t_end_ns:
            if v == "1" and t_ready_rise is None:
                t_ready_rise = t_ns
            elif v == "0" and t_ready_rise is not None and t_ready_fall is None:
                t_ready_fall = t_ns

    # Plot each signal row (from top to bottom)
    row_height = 1.0
    y_labels = []
    y_ticks = []

    for idx, (sig_name, sig_type) in enumerate(reversed(SIGNALS_TO_PLOT)):
        y_base = idx * row_height
        y_ticks.append(y_base + 0.45)
        y_labels.append(sig_name)

        intervals = get_signal_intervals(waveforms.get(sig_name, []), t_start_ns, t_end_ns)

        if sig_type == "bit":
            # 1-bit step line
            x_pts = []
            y_pts = []
            for t1, t2, val in intervals:
                bit_val = 1 if val in ["1", "b1"] else 0
                y_val = y_base + (0.80 if bit_val == 1 else 0.15)
                x_pts.extend([t1, t2])
                y_pts.extend([y_val, y_val])

            line_color = "#0b57d0" if sig_name != "clk" else "#444746"
            lw = 1.5 if sig_name != "clk" else 1.2
            ax.plot(x_pts, y_pts, color=line_color, lw=lw, drawstyle="default")

        else:
            # Multi-bit bus (labeled boxes with beveled transitions)
            bevel = min(0.4, (t_end_ns - t_start_ns) * 0.005)
            for t1, t2, raw_val in intervals:
                lbl = format_value(sig_type, raw_val)
                y_bot = y_base + 0.12
                y_top = y_base + 0.78
                y_mid = (y_top + y_bot) / 2.0

                # Determine box color
                if sig_type == "state":
                    face_color = STATE_COLORS.get(lbl, "#e8f0fe")
                    edge_color = "#747775"
                else:
                    face_color = "#e8f0fe"
                    edge_color = "#1a73e8"

                # Construct polygon with beveled ends
                poly_pts = [
                    (t1, y_mid),
                    (min(t1 + bevel, t2), y_top),
                    (max(t2 - bevel, t1), y_top),
                    (t2, y_mid),
                    (max(t2 - bevel, t1), y_bot),
                    (min(t1 + bevel, t2), y_bot)
                ]
                patch = Polygon(poly_pts, closed=True, facecolor=face_color, edgecolor=edge_color, lw=1.1)
                ax.add_patch(patch)

                # Centered text label if interval is wide enough
                duration = t2 - t1
                if duration > 1.5:
                    font_size = 7.5
                    if len(lbl) > 12 and duration < 15.0:
                        font_size = 6.0
                    ax.text(
                        (t1 + t2) / 2.0, y_mid, lbl,
                        ha="center", va="center",
                        fontsize=font_size, fontweight="bold",
                        family="monospace", color="#1f1f1f",
                        clip_on=True
                    )

    # Vertical markers at cpu_req rise and cpu_ready rise/fall
    top_y = num_signals * row_height
    dt_markers = (t_ready_rise - t_req_rise) if (t_req_rise and t_ready_rise) else 100.0

    if t_req_rise is not None:
        ax.axvline(x=t_req_rise, color="#0b57d0", linestyle="--", lw=1.4, alpha=0.9, zorder=5)
        # If markers are close, shift req label to left
        ha_req = "right" if dt_markers < 20.0 else "left"
        x_req = (t_req_rise - 0.5) if dt_markers < 20.0 else (t_req_rise + 0.5)
        ax.text(x_req, top_y + 0.1, f"cpu_req rise ({t_req_rise:.0f} ns)",
                color="#0b57d0", fontsize=8.5, fontweight="bold", ha=ha_req, va="bottom")

    if t_ready_rise is not None:
        ax.axvline(x=t_ready_rise, color="#b3261e", linestyle="--", lw=1.4, alpha=0.9, zorder=5)
        # If done marker is close (<= 15ns), place ready label to left; otherwise right
        dt_done = (t_ready_fall - t_ready_rise) if t_ready_fall else 100.0
        ha_ready = "right" if (dt_done <= 15.0 and dt_markers >= 20.0) else "left"
        x_ready = (t_ready_rise - 0.5) if ha_ready == "right" else (t_ready_rise + 0.5)
        ax.text(x_ready, top_y + 0.1, f"cpu_ready rise ({t_ready_rise:.0f} ns)",
                color="#b3261e", fontsize=8.5, fontweight="bold", ha=ha_ready, va="bottom")

    if t_ready_fall is not None:
        ax.axvline(x=t_ready_fall, color="#747775", linestyle=":", lw=1.2, alpha=0.8, zorder=4)
        ax.text(t_ready_fall + 0.5, top_y + 0.1, f"done ({t_ready_fall:.0f} ns)",
                color="#444746", fontsize=7.5, ha="left", va="bottom")

    # Cycle span annotation between markers
    if t_req_rise is not None and t_ready_rise is not None:
        span_y = top_y + 0.65
        cycles_to_ready = (t_ready_rise - t_req_rise) / 10.0
        cycles_to_finish = (t_ready_fall - t_req_rise) / 10.0 if t_ready_fall else cycles_to_ready + 1.0

        ax.annotate(
            "", xy=(t_ready_rise, span_y), xytext=(t_req_rise, span_y),
            arrowprops=dict(arrowstyle="<->", color="#1f1f1f", lw=1.3)
        )
        mid_x = (t_req_rise + t_ready_rise) / 2.0
        c_r_str = f"{cycles_to_ready:.0f} cycle" if cycles_to_ready == 1.0 else f"{cycles_to_ready:.0f} cycles"
        c_f_str = f"{cycles_to_finish:.0f} cycle" if cycles_to_finish == 1.0 else f"{cycles_to_finish:.0f} cycles"
        ax.text(
            mid_x, span_y + 0.12,
            f"{c_r_str} to cpu_ready ({c_f_str} total)",
            ha="center", va="bottom", fontsize=8.5, fontweight="bold", color="#1f1f1f"
        )

    # Clock cycle vertical grid lines
    ax.set_xlim(t_start_ns, t_end_ns)
    ax.set_ylim(-0.2, top_y + 1.3)

    # Grid ticks every 10 ns (major clock edge) and 5 ns (minor half cycle)
    clk_edges = [t for t in range(int(t_start_ns), int(t_end_ns) + 1, 10)]
    for edge in clk_edges:
        ax.axvline(x=edge, color="#e0e0e0", linestyle="-", lw=0.6, zorder=0)

    ax.set_xticks(clk_edges)
    ax.set_xlabel("Simulation Time (ns)", fontsize=10, fontweight="bold", labelpad=8)
    ax.set_yticks(y_ticks)
    ax.set_yticklabels(y_labels, fontsize=9, fontweight="bold", family="monospace")

    ax.set_title(title_text, fontsize=12, fontweight="bold", pad=28)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.spines["left"].set_color("#747775")
    ax.spines["bottom"].set_color("#747775")

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    plt.tight_layout()
    plt.savefig(output_path, dpi=180, bbox_inches="tight")
    plt.close()
    print(f"Generated: {output_path}")


def main():
    vcd_path = "results/lru_directed.vcd"
    if not os.path.exists(vcd_path):
        print(f"Error: {vcd_path} not found. Run ./scripts/run_all.sh first.")
        sys.exit(1)

    print(f"Parsing {vcd_path}...")
    waveforms = parse_vcd(vcd_path)

    # 1. Read Miss Window: 30 ns to 200 ns
    miss_out = "docs/img/waveform_miss.png"
    miss_title = "Read miss, Addr A — 13 cycles between cpu_req rise and cpu_ready rise (14 cycles total)"
    plot_waveform(waveforms, 30.0, 200.0, miss_title, miss_out)

    # 2. Read Hit Window: 350 ns to 400 ns
    hit_out = "docs/img/waveform_hit.png"
    hit_title = "Read hit, Addr A — 1 cycle between cpu_req rise and cpu_ready rise (2 cycles total)"
    plot_waveform(waveforms, 350.0, 400.0, hit_title, hit_out)

    print("Waveform generation completed successfully!")


if __name__ == "__main__":
    main()
