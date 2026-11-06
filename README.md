# Respiratory Panel Reimbursement & Competitive Benchmark

Market-access analytics for a 22-target syndromic respiratory PCR panel (the "study panel").
It benchmarks Medicare reimbursement for broad multiplex panels against competitor codes and
cheaper targeted tests, then positions competing platforms on breadth vs speed.

> Analysis write-up, rationale and recommendations: coming soon.

## Data

- **CMS Clinical Laboratory Fee Schedule, CY2026 Q3 V1** (public): `data/raw/cms_clfs_2026_q3.csv`, 2,206 codes
- **Competitor attribution and platform facts**: manufacturer releases, FDA documents, AMA PLA list
  and payer policies, encoded in `sql/duckdb/02_respiratory_code_map.sql` and `scripts/build_charts.py`

The study company and its products are de-identified in all outputs; competitors are named.

## Run

```bash
pip install -r requirements.txt
python run_pipeline.py        # DuckDB build with QA checks
python scripts/build_charts.py
```

## Layout

```
sql/snowflake/   original Snowflake build (admin archive, fee benchmark, backup helper)
sql/duckdb/      local DuckDB port: 01 import CLFS, 02 code map, 03 fee benchmark + export
scripts/         build_charts.py, chart_style.py
outputs/         tables/ and figures/ (C01 rate parity, C02 price ladder, C03 positioning)
```
