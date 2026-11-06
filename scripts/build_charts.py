"""Charts for the respiratory-panel reimbursement benchmark and competitor positioning.

Run after run_pipeline.py (from the repo root):  python scripts/build_charts.py

Reads outputs/tables/respiratory_fee_benchmark.csv (exported by sql/duckdb/03) and writes:
    outputs/figures/C01_broad_panel_rate_parity.png/.svg
    outputs/figures/C02_targeted_test_price_ladder.png/.svg
    outputs/figures/C03_competitor_positioning.png/.svg
    outputs/tables/competitor_positioning.csv
"""

from pathlib import Path
import sys

import numpy as np
import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parent))
from chart_style import CONTEXT, INDIGO, INK, MUTED, ORANGE, TEAL, clean, finish, new_figure  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "outputs"
FIG = OUT / "figures"
SRC = "Source: CMS Clinical Laboratory Fee Schedule CY2026 Q3, national limit amounts (Medicare)."

# Verified from manufacturer releases / FDA documents (see notes/competitive_analysis_business_case.md)
# (company, product, max targets, time to result in minutes (upper bound), CLIA-waived?)
PRODUCTS = [
    ("Study company", "Study panel", 22, 45, False),
    ("Study company", "POC panel", 15, 15, True),
    ("QIAGEN", "QIAstat-Dx Resp. Panel Plus", 21, 60, False),
    ("Roche", "cobas eplex RP3", 19, 120, False),
    ("Diasorin (Luminex)", "LIAISON PLEX Resp. Flex", 19, 120, False),
    ("Diasorin (Luminex)", "NxTAG RPP v2 (96-well batch)", 21, 180, False),
    ("BD", "BD MAX Resp. Viral Panel", 4, 120, False),
    ("Cepheid", "Xpert Xpress CoV-2/Flu/RSV plus", 4, 36, True),
    ("Roche", "cobas liat SARS-CoV-2/Flu/RSV", 4, 20, True),
    ("Abbott", "ID NOW (one target per test)", 1, 13, True),
]


def positioning():
    from matplotlib.lines import Line2D
    d = pd.DataFrame(PRODUCTS, columns=["company", "product", "targets", "minutes", "waived"])
    d.to_csv(OUT / "tables" / "competitor_positioning.csv", index=False)
    fig, ax = new_figure((0.09, 0.17, 0.86, 0.64))
    clean(ax, "both")
    offsets = {"Study panel": (-12, -10), "POC panel": (12, 0), "QIAstat-Dx Resp. Panel Plus": (-12, 10),
               "cobas eplex RP3": (-12, 10), "LIAISON PLEX Resp. Flex": (-12, -12),
               "NxTAG RPP v2 (96-well batch)": (-12, 0), "BD MAX Resp. Viral Panel": (12, 0),
               "Xpert Xpress CoV-2/Flu/RSV plus": (12, 8), "cobas liat SARS-CoV-2/Flu/RSV": (12, -2),
               "ID NOW (one target per test)": (12, -12)}
    for r in d.itertuples():
        own = r.company == "Study company"
        ax.scatter(r.targets, r.minutes, s=150, marker="^" if r.waived else "o",
                   color=TEAL if own else INDIGO, edgecolor="white", linewidth=1.5, zorder=3)
        dx, dy = offsets[r.product]
        ax.annotate(f"{r.company}: {r.product}", (r.targets, r.minutes), xytext=(dx, dy),
                    textcoords="offset points", fontsize=10.5, color=INK, va="center",
                    ha="right" if dx < 0 else "left")
    ax.axvline(5.5, color=ORANGE, linestyle="--", linewidth=1.3)
    ax.text(5.8, 192, "Medicare outpatient coverage limit: ≤5 targets", color=INK, fontsize=10.5, va="top")
    ax.set_xlim(0, 25)
    ax.set_ylim(0, 200)
    ax.set_xlabel("Maximum targets per test")
    ax.set_ylabel("Time to result, minutes (upper bound)")
    handles = [Line2D([], [], marker="o", linestyle="", color=TEAL, markersize=9, label="Study company"),
               Line2D([], [], marker="o", linestyle="", color=INDIGO, markersize=9, label="Competitor"),
               Line2D([], [], marker="o", linestyle="", color=MUTED, markersize=9, label="Lab-based (moderate complexity)"),
               Line2D([], [], marker="^", linestyle="", color=MUTED, markersize=9, label="CLIA-waived (point of care)")]
    ax.legend(handles=handles, loc="upper left", frameon=False, fontsize=10.5, bbox_to_anchor=(0.26, 0.86))
    finish(fig, FIG / "C03_competitor_positioning",
           "Breadth vs speed: competitors split into two camps",
           "Broad lab panels (19-22 targets, 45-180 min) vs fast waived 1-4 plex tests (13-36 min)",
           "Sources: manufacturer press releases, package inserts and FDA documents (2023-2026). Times are vendor-stated upper bounds;\n"
           "NxTAG = up to 96 samples in <3 h after extraction. Hologic Panther Fusion omitted (modular batch; run time not verified).", "C03")


def ylabel(r):
    return r.description if r.hcpcs_code == "study PLA" else f"{r.hcpcs_code}  {r.description}"


def main():
    m = pd.read_csv(OUT / "tables" / "respiratory_fee_benchmark.csv", dtype={"hcpcs_code": str})
    t = pd.DataFrame(dict(
        hcpcs_code=m.hcpcs_code,
        description=m.test_configuration.where(m.minimum_targets != m.maximum_targets,
                                            m.test_configuration + ", " + m.maximum_targets.astype(str) + " targets"),
        competitive_role=m.competitive_role, max_targets=m.maximum_targets,
        medicare_national_limit_usd=m.national_rate,
        index_vs_study_product=m.index_vs_study_panel)).sort_values(
        ["medicare_national_limit_usd", "max_targets"], ascending=[False, False]).reset_index(drop=True)
    product_rate = m.study_panel_rate.iloc[0]

    # C01: broad panels, rate parity
    b = t[t.competitive_role != "Targeted substitute"].reset_index(drop=True)
    fig, ax = new_figure((0.40, 0.22, 0.52, 0.59))
    clean(ax)
    y = np.arange(len(b))
    colors = [TEAL if r in ("Study product", "Own portfolio") else CONTEXT for r in b.competitive_role]
    ax.barh(y, b.medicare_national_limit_usd, color=colors, height=0.62)
    for i, r in b.iterrows():
        ax.text(r.medicare_national_limit_usd + 5, i, f"${r.medicare_national_limit_usd:,.2f}",
                va="center", fontsize=12.5, color=INK)
    ax.set_yticks(y, [ylabel(r) for r in b.itertuples()], fontsize=11.5)
    ax.invert_yaxis()
    ax.set_xlim(0, 480)
    ax.set_xlabel("Medicare national limit per test (USD)")
    finish(fig, FIG / "C01_broad_panel_rate_parity",
           "Six of eight broad-panel codes are paid the same $416.78",
           "The study panel earns no premium over QIAGEN, Roche ePlex RP2 or the generic code",
           "CMS CLFS CY2026 Q3 national limits. Teal = study company. Brands per AMA PLA list / payer policies.\nMedicare LCD L38916 / MolDX: panels >5 targets are NOT covered in the outpatient (Part B) setting.", "C01")

    # C02: price ladder vs targeted substitutes
    keep = ["87632", "87637", "87631", "87636", "87812"]
    lad = pd.concat([t[t.competitive_role == "Study product"],
                     t.set_index("hcpcs_code").loc[keep].reset_index()], ignore_index=True)
    fig, ax = new_figure((0.36, 0.17, 0.56, 0.64))
    clean(ax)
    y = np.arange(len(lad))
    colors = [TEAL] + [ORANGE] * (len(lad) - 1)
    ax.barh(y, lad.index_vs_study_product, color=colors, height=0.62)
    for i, r in lad.iterrows():
        ax.text(r.index_vs_study_product + 0.015, i,
                f"{r.index_vs_study_product:.2f}x   ${r.medicare_national_limit_usd:,.2f}",
                va="center", fontsize=12.5, color=INK)
    ax.set_yticks(y, [ylabel(r) for r in lad.itertuples()], fontsize=11.5)
    ax.invert_yaxis()
    ax.set_xlim(0, 1.3)
    ax.set_xlabel("Medicare payment relative to the study panel (= 1.00)")
    saving = product_rate - lad.loc[lad.hcpcs_code == "87637", "medicare_national_limit_usd"].iloc[0]
    finish(fig, FIG / "C02_targeted_test_price_ladder",
           "Targeted tests cost payers about one-third as much",
           f"Replacing one broad panel with the SARS-CoV-2/flu/RSV PCR saves ${saving:,.2f} (2.9x)",
           SRC + " Teal = broad panel (study product); orange = targeted substitutes.", "C02")
    positioning()
    print(t.to_string(index=False))


if __name__ == "__main__":
    main()
