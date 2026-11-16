# Project 7 IEEE Report Package (Phase I)

**Document:** IEEEtran Formatted Technical Report  
**Author:** Member 5 (Report, Diagrams, Synthesis, Video Lead)  
**Output Target:** `Project7_Phase1_Report.pdf`  

---

## Files in this Directory

* **`main.tex`**: The primary LaTeX document configured with the standard `IEEEtran` document class (`[journal,10pt,twocolumn]{IEEEtran}`).
* **`references.bib`**: BibTeX bibliography containing verified citations with DOIs.
* **`block_diagram.png`**: High-resolution microarchitectural block diagram of the 2-way LRU cache.
* **`lru_sequence.png`**: State transition diagram of the LRU replacement bit across sequence $A,B,A,C,B,A,C,A,B,C$.
* **`waveform_hit.png`**: GTKWave waveform capture of 2-cycle read hit.
* **`waveform_miss.png`**: GTKWave waveform capture of 14-cycle read miss refill.
* **`hit_rate.png`**: Benchmark comparison bar chart of hit rates across all 9 workloads.
* **`cycles.png`**: Benchmark comparison bar chart of execution cycles across all 9 workloads.

---

## How to Compile in Overleaf (1-Click Setup)

1. Open [Overleaf](https://www.overleaf.com/) and click **New Project** → **Upload Project**.
2. Zip this entire directory (`docs/report/`) or upload the individual files:
   - `main.tex`
   - `references.bib`
   - The 6 `.png` figure files
3. Set the compiler to **pdfLaTeX** (default in Overleaf).
4. Click **Recompile**.
5. Download the compiled PDF as `Project7_Phase1_Report.pdf`.

---

## How to Compile Locally (if TeX Live / MacTeX is installed)

```bash
# Compile LaTeX document and generate PDF
pdflatex main.tex
bibtex main
pdflatex main.tex
pdflatex main.tex
mv main.pdf Project7_Phase1_Report.pdf
```
*(If `pdflatex` is not installed on macOS: install with `brew install --cask mactex` or `brew install basictex`.)*
