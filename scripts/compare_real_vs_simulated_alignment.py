#!/opt/anaconda3/bin/python3
"""
compare_real_vs_simulated_alignment.py

Performs cross-domain acoustic room matching and quantitative alignment analysis
between empirical real-world testing results and theoretical simulation models:

Real-World Environments:
1. Full_Outside (Open field/yard)
2. Outside (Patio / semi-enclosed exterior)
3. Inside (Enclosed interior room)

Simulated Acoustic Venues:
1. freefield (Free-Field Stage, RT60 = 0.00s)
2. damped (Acoustically Damped Stage, RT60 = 0.08s)
3. festival (Open-Air Festival Stage, RT60 = 0.20s)
4. club (Nightclub, RT60 = 0.70s)
5. arena (Concert Arena, RT60 = 1.40s)

Filter Mapping (as confirmed by user):
- PASSTHROUGH <---> Unprocessed
- CONTROL     <---> FIR_BP (Genre Bandpass Filter)
- MIXED       <---> Cascade_Notch_NLMS (Firmware Mode A)
- OPTIMAL     <---> Cascade_Hybrid_Optimal (Firmware Mode C)

Generates:
- Statistical correlation matrices (Pearson r, R², RMSE, MAE)
- Empirical Room Matching Rankings
- Publication Figures:
    1. NLMS/figures/real_vs_sim_comprehensive_stoi_alignment.png
    2. NLMS/figures/real_vs_sim_delta_snr_alignment.png
    3. NLMS/figures/real_world_asr_wer_comparison.png
    4. NLMS/figures/room_matching_correlation_matrix.png
- NLMS/output_audio/real_world_experiment/real_vs_sim_alignment_matrix.csv
"""

import os
import shutil
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTPUT_DIR = os.path.join(BASE_DIR, "NLMS", "output_audio", "real_world_experiment")
FIGURES_DIR = os.path.join(BASE_DIR, "NLMS", "figures")
BRAIN_FIGURES_DIR = "/Users/macairm1/.gemini/antigravity/brain/fa14326e-1c60-480f-a3be-913fac3a8bd5/figures"

os.makedirs(OUTPUT_DIR, exist_ok=True)
os.makedirs(FIGURES_DIR, exist_ok=True)
if os.path.exists(os.path.dirname(BRAIN_FIGURES_DIR)):
    os.makedirs(BRAIN_FIGURES_DIR, exist_ok=True)

SIM_CSV = os.path.join(BASE_DIR, "NLMS", "output_audio", "room_experiment", "room_experiment_summary.csv")
REAL_CSV = os.path.join(OUTPUT_DIR, "real_world_summary.csv")

if not os.path.exists(SIM_CSV):
    raise FileNotFoundError(f"Simulation summary CSV not found: {SIM_CSV}")
if not os.path.exists(REAL_CSV):
    raise FileNotFoundError(f"Real-world summary CSV not found: {REAL_CSV}")

# -------------------------------------------------------------------------
# 1. Load Data
# -------------------------------------------------------------------------
df_sim = pd.read_csv(SIM_CSV)
df_real = pd.read_csv(REAL_CSV)

# Filter mapping dictionary
filter_map = {
    "PASSTHROUGH": "Unprocessed",
    "CONTROL": "FIR_BP",
    "MIXED": "Cascade_Notch_NLMS",
    "OPTIMAL": "Cascade_Hybrid_Optimal"
}

# Standardize column naming
df_real["Filter_Sim_Mapped"] = df_real["Filter_Name"].map(filter_map)

real_venues = ["Full_Outside", "Outside", "Inside"]
sim_venues = ["freefield", "damped", "festival", "club", "arena"]
sim_venue_labels = {
    "freefield": "Free-Field (0.00s)",
    "damped": "Damped Shell (0.08s)",
    "festival": "Festival (0.20s)",
    "club": "Nightclub (0.70s)",
    "arena": "Arena (1.40s)"
}

genres = ["techno", "jazz", "rock"]
shared_snrs = [0, -10, -15, -20]
mapped_filters = ["PASSTHROUGH", "CONTROL", "MIXED", "OPTIMAL"]

print("=" * 80)
print("  COMPUTING SIMULATION-TO-REALITY ROOM MATCHING ALIGNMENT")
print("=" * 80)

# -------------------------------------------------------------------------
# 2. Compute Correlation Matrices & RMSE across all (Genre, SNR, Filter)
# -------------------------------------------------------------------------
alignment_records = []
correlation_table = {}

for r_ven in real_venues:
    correlation_table[r_ven] = {}
    sub_real = df_real[(df_real["Venue"] == r_ven) & (df_real["SNR_dB"].isin(shared_snrs))].copy()

    for s_ven in sim_venues:
        sub_sim = df_sim[(df_sim["Venue"] == s_ven) & (df_sim["SNR_dB"].isin(shared_snrs))].copy()

        # Merge on (Genre, SNR_dB, Filter)
        merged = pd.merge(
            sub_real,
            sub_sim,
            left_on=["Genre", "SNR_dB", "Filter_Sim_Mapped"],
            right_on=["Genre", "SNR_dB", "Filter"],
            suffixes=("_real", "_sim")
        )

        if len(merged) == 0:
            continue

        # STOI Metrics
        stoi_r = merged["Mean_STOI_real"].values
        stoi_s = merged["Mean_STOI_sim"].values
        r_stoi = float(np.corrcoef(stoi_r, stoi_s)[0, 1])
        rmse_stoi = float(np.sqrt(np.mean((stoi_r - stoi_s)**2)))
        mae_stoi = float(np.mean(np.abs(stoi_r - stoi_s)))

        # Delta SNR Metrics
        dsnr_r = merged["Mean_Delta_SNR_dB"].values
        dsnr_s = merged["Mean_dSNR_dB"].values
        r_dsnr = float(np.corrcoef(dsnr_r, dsnr_s)[0, 1]) if np.std(dsnr_r) > 1e-6 and np.std(dsnr_s) > 1e-6 else 0.0
        rmse_dsnr = float(np.sqrt(np.mean((dsnr_r - dsnr_s)**2)))
        mae_dsnr = float(np.mean(np.abs(dsnr_r - dsnr_s)))

        # Composite Alignment Score (normalized composite index)
        # Higher r, lower RMSE is better
        composite_score = (r_stoi * 0.6) + (max(0.0, 1.0 - rmse_stoi / 0.5) * 0.4)

        alignment_records.append({
            "Real_Environment": r_ven,
            "Simulated_Venue": s_ven,
            "Sim_Label": sim_venue_labels[s_ven],
            "Pearson_r_STOI": r_stoi,
            "R2_STOI": r_stoi**2,
            "RMSE_STOI": rmse_stoi,
            "MAE_STOI": mae_stoi,
            "Pearson_r_Delta_SNR": r_dsnr,
            "RMSE_Delta_SNR_dB": rmse_dsnr,
            "MAE_Delta_SNR_dB": mae_dsnr,
            "Composite_Alignment_Score": composite_score
        })

        correlation_table[r_ven][s_ven] = {
            "r_stoi": r_stoi,
            "rmse_stoi": rmse_stoi,
            "rmse_dsnr": rmse_dsnr,
            "composite": composite_score
        }

df_align = pd.DataFrame(alignment_records)
align_csv_path = os.path.join(OUTPUT_DIR, "real_vs_sim_alignment_matrix.csv")
df_align.to_csv(align_csv_path, index=False)
print(f"✓ Saved alignment matrix to: {align_csv_path}\n")

# Print Room Matching Rankings
print("--- EMPIRICAL ROOM MATCHING RANKINGS ---")
best_matches = {}
for r_ven in real_venues:
    sub = df_align[df_align["Real_Environment"] == r_ven].sort_values(by="Composite_Alignment_Score", ascending=False)
    best = sub.iloc[0]
    best_matches[r_ven] = best["Simulated_Venue"]
    print(f"[{r_ven:12s}] ---> Best Match: [{best['Sim_Label']}] (r_STOI = {best['Pearson_r_STOI']:.4f}, RMSE_STOI = {best['RMSE_STOI']:.4f})")
    for _, row in sub.iterrows():
        print(f"    • vs {row['Sim_Label']:22s}: r = {row['Pearson_r_STOI']:+.4f} | RMSE = {row['RMSE_STOI']:.4f} | Score = {row['Composite_Alignment_Score']:.4f}")
    print("")

# -------------------------------------------------------------------------
# 3. Figure 1: STOI vs SNR Alignment Curves (Real vs Matched Sim)
# -------------------------------------------------------------------------
print("--> Generating Figure 1: STOI Speech Intelligibility Alignment Curves...")
fig, axes = plt.subplots(1, 3, figsize=(18, 5.5), sharey=True)
fig.suptitle("Speech Intelligibility (STOI): Real-World Results vs. Best-Matched Simulation Venues", fontsize=14, fontweight="bold")

filter_colors = {
    "PASSTHROUGH": "#7f7f7f",  # Grey
    "CONTROL": "#1f77b4",      # Blue
    "MIXED": "#2ca02c",        # Green
    "OPTIMAL": "#d62728"       # Red
}

filter_markers = {
    "PASSTHROUGH": "o",
    "CONTROL": "s",
    "MIXED": "D",
    "OPTIMAL": "^"
}

for idx, r_ven in enumerate(real_venues):
    ax = axes[idx]
    s_matched = best_matches[r_ven]
    ax.set_title(f"{r_ven}  vs.  Sim [{sim_venue_labels[s_matched]}]", fontsize=11, fontweight="bold")
    ax.set_xlabel("Input SNR (dB)", fontsize=10, fontweight="bold")
    if idx == 0:
        ax.set_ylabel("Mean STOI", fontsize=11, fontweight="bold")
    ax.grid(True, linestyle="--", alpha=0.6)
    ax.set_xticks(shared_snrs)
    ax.set_ylim(0.2, 0.95)

    sub_r = df_real[df_real["Venue"] == r_ven]
    sub_s = df_sim[df_sim["Venue"] == s_matched]

    for flt in mapped_filters:
        sim_flt = filter_map[flt]
        
        # Real-world curves (Solid line)
        r_vals = []
        for snr in shared_snrs:
            val = sub_r[(sub_r["SNR_dB"] == snr) & (sub_r["Filter_Name"] == flt)]["Mean_STOI"].mean()
            r_vals.append(val)
        ax.plot(shared_snrs, r_vals, label=f"Real: {flt}", color=filter_colors[flt], marker=filter_markers[flt], linewidth=2.2, linestyle="-")

        # Sim curves (Dashed line)
        s_vals = []
        for snr in shared_snrs:
            val = sub_s[(sub_s["SNR_dB"] == snr) & (sub_s["Filter"] == sim_flt)]["Mean_STOI"].mean()
            s_vals.append(val)
        ax.plot(shared_snrs, s_vals, label=f"Sim: {sim_flt}", color=filter_colors[flt], marker=filter_markers[flt], linewidth=1.5, linestyle="--", alpha=0.65)

axes[0].legend(loc="lower right", fontsize=7.5, ncol=2)
plt.tight_layout()
fig_stoi_path = os.path.join(FIGURES_DIR, "real_vs_sim_comprehensive_stoi_alignment.png")
plt.savefig(fig_stoi_path, dpi=300)
plt.close()
print(f"✓ Saved: {fig_stoi_path}")

# -------------------------------------------------------------------------
# 4. Figure 2: Delta SNR vs SNR Alignment Curves
# -------------------------------------------------------------------------
print("--> Generating Figure 2: Physical Noise Reduction (ΔSNR dB) Alignment Curves...")
fig, axes = plt.subplots(1, 3, figsize=(18, 5.5), sharey=True)
fig.suptitle("Physical Noise Reduction (ΔSNR dB): Real-World Results vs. Simulation", fontsize=14, fontweight="bold")

for idx, r_ven in enumerate(real_venues):
    ax = axes[idx]
    s_matched = best_matches[r_ven]
    ax.set_title(f"{r_ven}  vs.  Sim [{sim_venue_labels[s_matched]}]", fontsize=11, fontweight="bold")
    ax.set_xlabel("Input SNR (dB)", fontsize=10, fontweight="bold")
    if idx == 0:
        ax.set_ylabel("Mean ΔSNR (dB)", fontsize=11, fontweight="bold")
    ax.grid(True, linestyle="--", alpha=0.6)
    ax.set_xticks(shared_snrs)
    ax.set_ylim(-4.0, 16.0)

    sub_r = df_real[df_real["Venue"] == r_ven]
    sub_s = df_sim[df_sim["Venue"] == s_matched]

    for flt in mapped_filters:
        sim_flt = filter_map[flt]
        
        # Real-world
        r_vals = []
        for snr in shared_snrs:
            val = sub_r[(sub_r["SNR_dB"] == snr) & (sub_r["Filter_Name"] == flt)]["Mean_Delta_SNR_dB"].mean()
            r_vals.append(val)
        ax.plot(shared_snrs, r_vals, label=f"Real: {flt}", color=filter_colors[flt], marker=filter_markers[flt], linewidth=2.2, linestyle="-")

        # Sim
        s_vals = []
        for snr in shared_snrs:
            val = sub_s[(sub_s["SNR_dB"] == snr) & (sub_s["Filter"] == sim_flt)]["Mean_dSNR_dB"].mean()
            s_vals.append(val)
        ax.plot(shared_snrs, s_vals, label=f"Sim: {sim_flt}", color=filter_colors[flt], marker=filter_markers[flt], linewidth=1.5, linestyle="--", alpha=0.65)

axes[0].legend(loc="upper left", fontsize=7.5, ncol=2)
plt.tight_layout()
fig_dsnr_path = os.path.join(FIGURES_DIR, "real_vs_sim_delta_snr_alignment.png")
plt.savefig(fig_dsnr_path, dpi=300)
plt.close()
print(f"✓ Saved: {fig_dsnr_path}")

# -------------------------------------------------------------------------
# 5. Figure 3: Real-World ASR Word Error Rate (Faster-Whisper & Google STT)
# -------------------------------------------------------------------------
print("--> Generating Figure 3: ASR Speech Recognition Intelligibility (WER & Recall)...")
fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(15, 5.5))
fig.suptitle("Real-World Speech Recognition Performance: Faster-Whisper & Google STT", fontsize=14, fontweight="bold")

# Aggregate WER across real environments per filter & SNR
x_snrs = [0, -10, -15, -20]
for flt in mapped_filters:
    wer_vals = []
    for snr in x_snrs:
        val = df_real[(df_real["SNR_dB"] == snr) & (df_real["Filter_Name"] == flt)]["Mean_Whisper_WER"].mean()
        wer_vals.append(val)
    ax1.plot(x_snrs, wer_vals, label=f"{flt}", color=filter_colors[flt], marker=filter_markers[flt], linewidth=2.2)

ax1.set_title("Faster-Whisper Word Error Rate (WER %)", fontsize=11, fontweight="bold")
ax1.set_xlabel("Input SNR (dB)", fontsize=10, fontweight="bold")
ax1.set_ylabel("Mean WER (%)  [Lower is Better]", fontsize=10, fontweight="bold")
ax1.grid(True, linestyle="--", alpha=0.6)
ax1.set_xticks(x_snrs)
ax1.set_ylim(-5.0, 105.0)
ax1.legend(loc="upper right", fontsize=9)

# Subplot 2: Google STT Comparison on 0 and -10 dB subset
g_snrs = [0, -10]
bar_width = 0.20
x_indices = np.arange(len(g_snrs))

for i, flt in enumerate(mapped_filters):
    g_vals = []
    for snr in g_snrs:
        sub = df_real[(df_real["SNR_dB"] == snr) & (df_real["Filter_Name"] == flt)]
        valid = sub[sub["Mean_Google_WER"] >= 0]
        g_vals.append(valid["Mean_Google_WER"].mean() if len(valid) > 0 else 100.0)
    ax2.bar(x_indices + (i - 1.5) * bar_width, g_vals, width=bar_width, label=flt, color=filter_colors[flt], alpha=0.85, edgecolor="black")

ax2.set_title("Google Cloud STT Word Error Rate at Higher SNRs", fontsize=11, fontweight="bold")
ax2.set_xlabel("Input SNR (dB)", fontsize=10, fontweight="bold")
ax2.set_ylabel("Mean Google WER (%)", fontsize=10, fontweight="bold")
ax2.set_xticks(x_indices)
ax2.set_xticklabels(["0 dB", "-10 dB"], fontweight="bold")
ax2.grid(True, linestyle="--", alpha=0.6)
ax2.set_ylim(0.0, 110.0)
ax2.legend(loc="upper right", fontsize=9)

plt.tight_layout()
fig_wer_path = os.path.join(FIGURES_DIR, "real_world_asr_wer_comparison.png")
plt.savefig(fig_wer_path, dpi=300)
plt.close()
print(f"✓ Saved: {fig_wer_path}")

# -------------------------------------------------------------------------
# 6. Figure 4: Room Matching Correlation Matrix Heatmap
# -------------------------------------------------------------------------
print("--> Generating Figure 4: Acoustic Room Matching Correlation Heatmap...")
corr_matrix_r = np.zeros((len(real_venues), len(sim_venues)))
rmse_matrix = np.zeros((len(real_venues), len(sim_venues)))

for i, r_ven in enumerate(real_venues):
    for j, s_ven in enumerate(sim_venues):
        corr_matrix_r[i, j] = correlation_table[r_ven][s_ven]["r_stoi"]
        rmse_matrix[i, j] = correlation_table[r_ven][s_ven]["rmse_stoi"]

fig, (ax_r, ax_rmse) = plt.subplots(1, 2, figsize=(14, 5.0))
fig.suptitle("Empirical-to-Simulated Acoustic Room Matching Matrices", fontsize=14, fontweight="bold")

# Heatmap 1: Pearson r
im1 = ax_r.imshow(corr_matrix_r, cmap="YlGnBu", vmin=0.5, vmax=1.0)
ax_r.set_title("STOI Pearson Correlation (r)  [Higher is Better]", fontsize=11, fontweight="bold")
ax_r.set_xticks(range(len(sim_venues)))
ax_r.set_xticklabels([sim_venue_labels[s] for s in sim_venues], rotation=25, ha="right", fontsize=9)
ax_r.set_yticks(range(len(real_venues)))
ax_r.set_yticklabels(real_venues, fontsize=10, fontweight="bold")
for i in range(len(real_venues)):
    for j in range(len(sim_venues)):
        ax_r.text(j, i, f"{corr_matrix_r[i, j]:.3f}", ha="center", va="center", color="black" if corr_matrix_r[i, j] < 0.85 else "white", fontweight="bold")
fig.colorbar(im1, ax=ax_r, fraction=0.046, pad=0.04)

# Heatmap 2: RMSE
im2 = ax_rmse.imshow(rmse_matrix, cmap="YlOrRd_r", vmin=0.05, vmax=0.30)
ax_rmse.set_title("STOI Root Mean Square Error (RMSE)  [Lower is Better]", fontsize=11, fontweight="bold")
ax_rmse.set_xticks(range(len(sim_venues)))
ax_rmse.set_xticklabels([sim_venue_labels[s] for s in sim_venues], rotation=25, ha="right", fontsize=9)
ax_rmse.set_yticks(range(len(real_venues)))
ax_rmse.set_yticklabels(real_venues, fontsize=10, fontweight="bold")
for i in range(len(real_venues)):
    for j in range(len(sim_venues)):
        ax_rmse.text(j, i, f"{rmse_matrix[i, j]:.3f}", ha="center", va="center", color="black" if rmse_matrix[i, j] > 0.15 else "white", fontweight="bold")
fig.colorbar(im2, ax=ax_rmse, fraction=0.046, pad=0.04)

plt.tight_layout()
fig_heatmap_path = os.path.join(FIGURES_DIR, "room_matching_correlation_matrix.png")
plt.savefig(fig_heatmap_path, dpi=300)
plt.close()
print(f"✓ Saved: {fig_heatmap_path}")

# Sync all figures to Brain directory
if os.path.exists(BRAIN_FIGURES_DIR):
    for fp in [fig_stoi_path, fig_dsnr_path, fig_wer_path, fig_heatmap_path]:
        shutil.copy(fp, os.path.join(BRAIN_FIGURES_DIR, os.path.basename(fp)))
    print("✓ Synced all publication figures to brain artifact directory.")

print("\n" + "=" * 80)
print("  CROSS-DOMAIN ALIGNMENT AND ROOM MATCHING ANALYSIS COMPLETE!")
print("=" * 80)
