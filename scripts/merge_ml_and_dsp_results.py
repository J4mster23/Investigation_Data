#!/opt/anaconda3/bin/python3
"""
merge_ml_and_dsp_results.py

Merges the ML filter simulation results with the official DSP concert benchmark results
into a unified comparison matrix across all 5 venues and generates side-by-side
publication figures.
"""

import os
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTPUT_DIR = os.path.join(BASE_DIR, "NLMS", "output_audio", "room_experiment")
FIGURES_DIR = os.path.join(BASE_DIR, "NLMS", "figures")
BRAIN_FIGURES_DIR = "/Users/macairm1/.gemini/antigravity/brain/fa14326e-1c60-480f-a3be-913fac3a8bd5/figures"

ML_CSV = os.path.join(OUTPUT_DIR, "ml_filter_room_experiment_summary.csv")
DSP_CSV = os.path.join(OUTPUT_DIR, "room_experiment_summary.csv")
MERGED_CSV = os.path.join(OUTPUT_DIR, "ml_vs_dsp_full_comparison_matrix.csv")

# 1. Load CSVs
df_ml = pd.read_csv(ML_CSV)
df_dsp = pd.read_csv(DSP_CSV)

# Standardize columns
# ML CSV: Venue,Genre,SNR_dB,Filter_Name,Mean_STOI,Mean_PESQ,Mean_Delta_SNR_dB,Mean_Delta_ASL_dB
# DSP CSV: Venue,Genre,SNR_dB,Filter,Mean_STOI,Mean_PESQ,Mean_ViSQOL,Mean_dSNR_dB,Mean_dASL_dB
df_dsp = df_dsp.rename(columns={"Filter": "Filter_Name", "Mean_dSNR_dB": "Mean_Delta_SNR_dB", "Mean_dASL_dB": "Mean_Delta_ASL_dB"})

# Keep relevant DSP filters to avoid clobbering:
dsp_selected = df_dsp[df_dsp["Filter_Name"].isin(["Unprocessed", "FIR_BP", "Parametric_Notch", "Base_NLMS", "Soft_VAD_Leaky", "Cascade_Notch_NLMS", "Cascade_Hybrid_Optimal"])].copy()

# Filter ML models (exclude duplicate Unprocessed and Base_NLMS from ML run)
ml_selected = df_ml[df_ml["Filter_Name"].isin(["ML_Spatial_Wave_UNet", "ML_Time_Wave_UNet", "ML_SE_FCN_Masker"])].copy()
ml_selected["Mean_ViSQOL"] = np.nan

# Combine
combined = pd.concat([dsp_selected, ml_selected], ignore_index=True)
combined.to_csv(MERGED_CSV, index=False)
print(f"✓ Successfully exported merged comparison matrix ({len(combined)} rows) to: {MERGED_CSV}")

# 2. Generate Publication Plot comparing ML vs Winning DSP Filter across 5 Venues
venue_keys = ["freefield", "damped", "festival", "club", "arena"]
venue_titles = {
    "freefield": "Free-Field (0.00s)",
    "damped": "Damped Stage (0.08s)",
    "festival": "Festival (0.20s)",
    "club": "Nightclub (0.70s)",
    "arena": "Arena (1.40s)"
}

compare_filters = [
    "Cascade_Notch_NLMS",
    "Base_NLMS",
    "ML_SE_FCN_Masker",
    "ML_Time_Wave_UNet",
    "ML_Spatial_Wave_UNet",
    "Unprocessed"
]

color_map = {
    "Cascade_Notch_NLMS": "#2ca02c",  # Green
    "Base_NLMS": "#1f77b4",           # Blue
    "ML_SE_FCN_Masker": "#9467bd",     # Purple
    "ML_Time_Wave_UNet": "#ff7f0e",    # Orange
    "ML_Spatial_Wave_UNet": "#d62728", # Red
    "Unprocessed": "#7f7f7f"           # Gray
}

style_map = {
    "Cascade_Notch_NLMS": ("-", "*", 2.5),
    "Base_NLMS": ("--", "s", 1.8),
    "ML_SE_FCN_Masker": ("-.", "d", 1.8),
    "ML_Time_Wave_UNet": (":", "v", 1.8),
    "ML_Spatial_Wave_UNet": ("-", "^", 2.0),
    "Unprocessed": (":", "o", 1.5)
}

# --- Plot: STOI Benchmark Comparison ---
fig, axes = plt.subplots(1, 5, figsize=(22, 5.2), sharey=True)
fig.suptitle("Speech Intelligibility (STOI): ML Models vs. Winning DSP Cascade (Cascade_Notch_NLMS)", fontsize=14, fontweight="bold")

snrs = [-20, -15, -10, -5, 0]

for idx, v in enumerate(venue_keys):
    ax = axes[idx]
    ax.set_title(venue_titles[v], fontsize=12, fontweight="bold")
    ax.set_xlabel("Input SNR (dB)", fontsize=11, fontweight="bold")
    if idx == 0:
        ax.set_ylabel("Mean STOI Intelligibility", fontsize=11, fontweight="bold")
    ax.grid(True, linestyle="--", alpha=0.5)
    ax.set_xticks(snrs)
    ax.set_ylim(0.20, 0.95)

    v_df = combined[combined["Venue"] == v]

    for f in compare_filters:
        sub = v_df[v_df["Filter_Name"] == f]
        y_vals = []
        for s in snrs:
            val = sub[sub["SNR_dB"] == s]["Mean_STOI"].mean()
            y_vals.append(val)
        
        ls, mkr, lw = style_map[f]
        ax.plot(snrs, y_vals, label=f, color=color_map[f], linestyle=ls, marker=mkr, linewidth=lw, markersize=6)

axes[0].legend(loc="lower right", fontsize=8.5)
plt.tight_layout()
fig_path = os.path.join(FIGURES_DIR, "ml_vs_dsp_comprehensive_stoi_comparison.png")
plt.savefig(fig_path, dpi=300)
plt.close()
print(f"✓ Saved plot: {fig_path}")

if os.path.exists(BRAIN_FIGURES_DIR):
    import shutil
    shutil.copy(fig_path, os.path.join(BRAIN_FIGURES_DIR, "ml_vs_dsp_comprehensive_stoi_comparison.png"))
    print("✓ Copied plot to brain artifact directory.")

print("All merge and plotting tasks complete.")
