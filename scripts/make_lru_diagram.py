import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

# One set, 2 ways. lru bit = way that is the VICTIM (least recently used).
# Rules: hit way w -> lru = ~w ; fill into way v -> lru = ~v ;
# victim = invalid way0, else invalid way1, else lru.
seq = list("ABACBACABC")
w = [None, None]
lru = 0
rows = []
for i, a in enumerate(seq, 1):
    if a in w:
        way = w.index(a)
        kind, victim, evicted = "HIT", "-", "-"
        lru = 1 - way
    else:
        if w[0] is None: v = 0
        elif w[1] is None: v = 1
        else: v = lru
        evicted = w[v] if w[v] else "-"
        w[v] = a
        kind, victim = "MISS", f"Way {v}"
        lru = 1 - v
    rows.append([i, a, kind, victim, evicted, w[0] or "-", w[1] or "-",
                 lru, f"Way {lru} ({w[lru] or '-'})"])

cols = ["#", "Access", "Result", "Victim\nchosen", "Evicted",
        "Way 0", "Way 1", "LRU bit\nafter", "Next victim\nwould be"]
fig, ax = plt.subplots(figsize=(11, 5.6))
ax.axis("off")
ax.set_title("2-way LRU: state of one set over the sequence A,B,A,C,B,A,C,A,B,C\n"
             "(lru bit = way that will be evicted next)", fontsize=12, pad=10)
t = ax.table(cellText=rows, colLabels=cols, loc="center", cellLoc="center")
t.auto_set_font_size(False); t.set_fontsize(10); t.scale(1, 1.6)
for j in range(len(cols)):
    c = t[0, j]; c.set_facecolor("#1f3a5f"); c.get_text().set_color("white")
    c.get_text().set_fontweight("bold")
for i, r in enumerate(rows, 1):
    col = "#d9f2d9" if r[2] == "HIT" else "#fbe0e0"
    for j in range(len(cols)):
        t[i, j].set_facecolor(col)
hits = sum(r[2] == "HIT" for r in rows)
fig.text(0.5, 0.03, f"Hits: {hits}/10   Misses: {10-hits}/10   (green = hit, red = miss)",
         ha="center", fontsize=10)
plt.savefig("lru_sequence.png", dpi=200, bbox_inches="tight")
for r in rows: print(r)
