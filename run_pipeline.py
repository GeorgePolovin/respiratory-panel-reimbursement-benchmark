"""Rebuild the respiratory fee benchmark in DuckDB from the public CMS fee schedule.

    python run_pipeline.py        # DuckDB build + exports (stops on any REVIEW status)
    python scripts/build_charts.py

The Snowflake originals in sql/snowflake/ build the same objects in a
Snowflake account; the DuckDB port lets anyone reproduce them locally.
"""

from pathlib import Path
import os

import duckdb

ROOT = Path(__file__).resolve().parent
STEPS = ["sql/duckdb/01_import_clfs.sql", "sql/duckdb/02_respiratory_code_map.sql",
         "sql/duckdb/03_fee_benchmark.sql"]


def main():
    os.chdir(ROOT)
    (ROOT / "outputs" / "tables").mkdir(parents=True, exist_ok=True)
    with duckdb.connect() as con:  # in-memory: the build takes about a second
        for step in STEPS:
            for stmt in con.extract_statements((ROOT / step).read_text()):
                rel = con.query(stmt.query)
                if rel is None:
                    continue
                cols = [c for c in rel.columns if c.endswith("status")]
                for row in rel.fetchall() if cols else []:
                    for c in cols:
                        if str(row[rel.columns.index(c)]).startswith("REVIEW"):
                            raise SystemExit(f"QA check failed in {step}: {c}")
            print(f"> {step}")
    print("Pipeline complete: all QA checks passed.")


if __name__ == "__main__":
    main()
