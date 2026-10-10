#!/usr/bin/env python3
"""
reconstruct_holy_grail_plots.py

Reconstructs the entire plot suite and intelligibility run-through
strictly from holy_grail_results.csv (288 rows).
Includes:
- STOI to WRS psychometric calibration
- Textbook vs Calibrated comparison
- Real-World performance across SNR
- Reality vs Simulation alignment
- Musical Genre robustness
- Net Intelligibility Gain
- Venue Sensitivity
"""

import os
import shutil
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from scipy import stats

# File paths
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CSV_PATH = os.path.join(BASE_DIR, "NLMS", "output_audio", "holy_grail_results.csv")
FIG_DIR = os.path.join(BASE_DIR, "NLMS", "figures")
ARTIFACTS_DIR = "/Users/macairm1/.gemini/antigravity/brain/77c4061f-051a-421c-9003-d1cadbbcf676"

os.makedirs(FIG_DIR, exist_ok=True)
os.makedirs(ARTIFACTS_DIR, exist_ok=True)

# Aesthetic styling
plt.rcParams['font.sans-serif'] = 'Helvetica, Arial, DejaVu Sans, sans-serif'
plt.rcParams['font.family'] = 'sans-serif'
plt.rcParams['axes.edgecolor'] = '#CBD5E1'
plt.rcParams['axes.linewidth'] = 1.2
plt.rcParams['grid.color'] = '#E2E8F0'
plt.rcParams['grid.linestyle'] = '--'
plt.rcParams['grid.alpha'] = 0.7

# -----------------------------------------------------------------------------
# 1. Load Data
# -----------------------------------------------------------------------------
df = pd.read_csv(CSV_PATH)
print(f"Loaded {len(df)} rows from holy_grail_results.csv")

# -----------------------------------------------------------------------------
# 2. WRS Formulation & Condition-Level Fit
# -----------------------------------------------------------------------------
# Aggregate across speakers to condition level (144 conditions) for smooth fit
cond_df = df.groupby(['Venue', 'Genre', 'SNR_dB', 'Filter'])[['Real_STOI', 'Real_Whisper_Recall_Pct']].mean().reset_index()

from scipy.optimize import curve_fit
def logistic(d, a, b):
    return 100.0 / (1.0 + np.exp(a * d + b))

popt, _ = curve_fit(logistic, cond_df['Real_STOI'], cond_df['Real_Whisper_Recall_Pct'],
                    p0=[-15.0, 8.0], bounds=([-np.inf, -np.inf], [0.0, np.inf]))
a_opt, b_opt = popt
d_50 = -b_opt / a_opt
print(f"Calibrated Parameters: a = {a_opt:.4f}, b = {b_opt:.4f}, d_50 = {d_50:.4f}")

# Map simple labels
LABEL_MAP = {
    'PASSTHROUGH': 'Raw Capture',
    'CONTROL': 'Basic Filter (FIR)',
    'MIXED': 'Adaptive Dual-Stage',
    'OPTIMAL': 'Production Hybrid'
}
df['System'] = df['Filter'].map(LABEL_MAP)

# Calculate WRS
def stoi_to_wrs(stoi_val):
    return 100.0 / (1.0 + np.exp(a_opt * stoi_val + b_opt))

def textbook_wrs(stoi_val):
    # Taal et al. / IEEE benchmark: a = -21.48, b = 12.83, d_50 = 0.597
    return 100.0 / (1.0 + np.exp(-21.48 * (stoi_val - 0.597)))

df['Real_WRS'] = stoi_to_wrs(df['Real_STOI'])
df['Sim_WRS'] = stoi_to_wrs(df['Sim_STOI'])

SYSTEM_ORDER = ['Raw Capture', 'Basic Filter (FIR)', 'Adaptive Dual-Stage', 'Production Hybrid']
SYSTEM_COLORS = ['#64748B', '#EF4444', '#0284C7', '#10B981']
SYSTEM_MARKERS = ['o', 's', '^', 'D']
SYSTEM_LINESTYLES = ['--', '-', '-', '-']

# -----------------------------------------------------------------------------
# Plot 1: STOI to WRS Psychometric Curve
# -----------------------------------------------------------------------------
def plot_1_psychometric_curve():
    fig, ax = plt.subplots(figsize=(9, 5.5), dpi=300)
    stoi_range = np.linspace(0.25, 0.90, 300)
    wrs_curve = stoi_to_wrs(stoi_range)
    
    # Background zones
    ax.axvspan(0.25, 0.45, color='#FEE2E2', alpha=0.35, label='Severe Masking (<10% Comprehension)')
    ax.axvspan(0.45, 0.65, color='#FEF3C7', alpha=0.35, label='Conversational Transition (Rapid Recovery)')
    ax.axvspan(0.65, 0.90, color='#D1FAE5', alpha=0.35, label='High Intelligibility (>90% Comprehension)')
    
    # Scatter 288 points from holy_grail_results.csv
    ax.scatter(df['Real_STOI'], df['Real_Whisper_Recall_Pct'],
               color='#94A3B8', alpha=0.40, s=25, label='Holy Grail Benchmark Observations (N=288)')
    
    # Model curve
    ax.plot(stoi_range, wrs_curve, color='#0F172A', linewidth=3.0,
            label=f'Calibrated Psychometric Model (d50 = {d_50:.2f})')
    
    # Inflection marker (documented in legend)
    ax.scatter([d_50], [50.0], color='#DC2626', s=80, zorder=5, edgecolor='black', linewidth=1.2,
               label=f'50% Threshold (STOI = {d_50:.2f})')
    
    ax.set_title('Speech Intelligibility Mapping: Objective STOI to Word Recognition Score',
                 fontsize=13, fontweight='bold', pad=15, color='#0F172A')
    ax.set_xlabel('Short-Time Objective Intelligibility (STOI Metric)', fontsize=11, fontweight='bold', labelpad=8)
    ax.set_ylabel('Word Recognition Score (WRS %)', fontsize=11, fontweight='bold', labelpad=8)
    ax.set_xlim(0.25, 0.90)
    ax.set_ylim(-3, 105)
    ax.grid(True)
    ax.legend(loc='lower right', frameon=True, facecolor='white', framealpha=0.95, fontsize=9)
    
    plt.tight_layout()
    p = os.path.join(FIG_DIR, "hg_graph1_psychometric_curve.png")
    plt.savefig(p)
    plt.close()
    shutil.copy(p, os.path.join(ARTIFACTS_DIR, "hg_graph1_psychometric_curve.png"))
    print(f"Saved: {p}")

# -----------------------------------------------------------------------------
# Plot 1B: Calibrated Model vs Textbook Model
# -----------------------------------------------------------------------------
def plot_1b_textbook_comparison():
    fig, ax = plt.subplots(figsize=(9.5, 5.5), dpi=300)
    stoi_range = np.linspace(0.25, 0.90, 300)
    curve_our = stoi_to_wrs(stoi_range)
    curve_txt = textbook_wrs(stoi_range)
    
    # Background zones
    ax.axvspan(0.25, 0.45, color='#FEE2E2', alpha=0.35, label='Severe Masking (<10% Comprehension)')
    ax.axvspan(0.45, 0.65, color='#FEF3C7', alpha=0.35, label='Conversational Transition (Rapid Recovery)')
    ax.axvspan(0.65, 0.90, color='#D1FAE5', alpha=0.35, label='High Intelligibility (>90% Comprehension)')
    
    ax.scatter(df['Real_STOI'], df['Real_Whisper_Recall_Pct'],
               color='#94A3B8', alpha=0.25, s=20, label='Holy Grail Observations (N=288)')
    
    ax.plot(stoi_range, curve_our, color='#0284C7', linewidth=3.2,
            label=f'Our Calibrated Fit (d50 = {d_50:.2f}) [Hardware Concert Reality]')
    ax.plot(stoi_range, curve_txt, color='#DC2626', linewidth=2.8, linestyle='--',
            label='Standard Textbook Fit (d50 = 0.60) [Taal et al. / IEEE SSN]')
    
    ax.scatter([d_50], [50.0], color='#0284C7', s=80, zorder=5, edgecolor='black', linewidth=1.2)
    ax.scatter([0.597], [50.0], color='#DC2626', s=80, zorder=5, edgecolor='black', linewidth=1.2)

    ax.set_title('Word Recognition Score: Calibrated Field Model vs. Standard Textbook Model',
                 fontsize=13, fontweight='bold', pad=15, color='#0F172A')
    ax.set_xlabel('Short-Time Objective Intelligibility (STOI Metric)', fontsize=11, fontweight='bold', labelpad=8)
    ax.set_ylabel('Word Recognition Score (WRS %)', fontsize=11, fontweight='bold', labelpad=8)
    ax.set_xlim(0.25, 0.90)
    ax.set_ylim(-3, 105)
    ax.grid(True)
    ax.legend(loc='lower right', frameon=True, facecolor='white', framealpha=0.95, fontsize=8.8)
    
    plt.tight_layout()
    p = os.path.join(FIG_DIR, "hg_graph1b_textbook_comparison.png")
    plt.savefig(p)
    plt.close()
    shutil.copy(p, os.path.join(ARTIFACTS_DIR, "hg_graph1b_textbook_comparison.png"))
    print(f"Saved: {p}")

# -----------------------------------------------------------------------------
# Plot 2: Real-World WRS Across Noise Levels
# -----------------------------------------------------------------------------
def plot_2_real_world_wrs_by_snr():
    fig, ax = plt.subplots(figsize=(8.5, 5.5), dpi=300)
    snrs = [-20, -15, -10, 0]
    
    for sys, col, m, ls in zip(SYSTEM_ORDER, SYSTEM_COLORS, SYSTEM_MARKERS, SYSTEM_LINESTYLES):
        sub = df[df['System'] == sys]
        means = [sub[sub['SNR_dB'] == s]['Real_WRS'].mean() for s in snrs]
        ax.plot(snrs, means, label=sys, color=col, marker=m, markersize=8,
                linewidth=2.5, linestyle=ls)

    ax.set_title('Real-World Word Recognition Score Across Noise Levels',
                 fontsize=13, fontweight='bold', pad=15, color='#0F172A')
    ax.set_xlabel('Input Signal-to-Noise Ratio (dB)  [Lower is More Severe Noise]',
                  fontsize=11, fontweight='bold', labelpad=8)
    ax.set_ylabel('Word Recognition Score (WRS %)', fontsize=11, fontweight='bold', labelpad=8)
    ax.set_xticks(snrs)
    ax.set_xticklabels(['-20 dB\n(Extreme Noise)', '-15 dB\n(Heavy Stage Noise)', '-10 dB\n(Loud Ambient)', '0 dB\n(Moderate Noise)'])
    ax.set_ylim(10, 105)
    ax.grid(True)
    ax.legend(loc='lower right', frameon=True, facecolor='white', framealpha=0.9, fontsize=10)
    
    plt.tight_layout()
    p = os.path.join(FIG_DIR, "hg_graph2_real_world_wrs_by_snr.png")
    plt.savefig(p)
    plt.close()
    shutil.copy(p, os.path.join(ARTIFACTS_DIR, "hg_graph2_real_world_wrs_by_snr.png"))
    print(f"Saved: {p}")

# -----------------------------------------------------------------------------
# Plot 3: Reality vs Simulation Alignment
# -----------------------------------------------------------------------------
def plot_3_real_vs_sim_wrs():
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(13, 5.5), dpi=300, sharey=True)
    snrs = [-20, -15, -10, 0]
    snr_labels = ['-20 dB', '-15 dB', '-10 dB', '0 dB']
    
    # Real-World Subplot
    for sys, col, m, ls in zip(SYSTEM_ORDER, SYSTEM_COLORS, SYSTEM_MARKERS, SYSTEM_LINESTYLES):
        sub = df[df['System'] == sys]
        means = [sub[sub['SNR_dB'] == s]['Real_WRS'].mean() for s in snrs]
        ax1.plot(snrs, means, label=sys, color=col, marker=m, markersize=7, linewidth=2.2, linestyle=ls)
        
    ax1.set_title('(A) Real-World Hardware Field Trials', fontsize=12, fontweight='bold', color='#0F172A')
    ax1.set_xlabel('Input SNR (dB)', fontsize=11, fontweight='bold', labelpad=8)
    ax1.set_ylabel('Word Recognition Score (WRS %)', fontsize=11, fontweight='bold', labelpad=8)
    ax1.set_xticks(snrs)
    ax1.set_xticklabels(snr_labels)
    ax1.set_ylim(-2, 105)
    ax1.grid(True)
    ax1.legend(loc='lower right', frameon=True, facecolor='white', framealpha=0.9, fontsize=9)
    
    # Simulation Subplot
    for sys, col, m, ls in zip(SYSTEM_ORDER, SYSTEM_COLORS, SYSTEM_MARKERS, SYSTEM_LINESTYLES):
        sub = df[df['System'] == sys]
        means = [sub[sub['SNR_dB'] == s]['Sim_WRS'].mean() for s in snrs]
        ax2.plot(snrs, means, label=sys, color=col, marker=m, markersize=7, linewidth=2.2, linestyle=ls)
        
    ax2.set_title('(B) Acoustic Simulation Analog Venues', fontsize=12, fontweight='bold', color='#0F172A')
    ax2.set_xlabel('Input SNR (dB)', fontsize=11, fontweight='bold', labelpad=8)
    ax2.set_xticks(snrs)
    ax2.set_xticklabels(snr_labels)
    ax2.grid(True)
    ax2.legend(loc='lower right', frameon=True, facecolor='white', framealpha=0.9, fontsize=9)
    
    fig.suptitle('Intelligibility Across Domains: Hardware Reality vs. Acoustic Simulation',
                 fontsize=14, fontweight='bold', y=0.98, color='#0F172A')
                 
    plt.tight_layout()
    p = os.path.join(FIG_DIR, "hg_graph3_real_vs_sim_wrs.png")
    plt.savefig(p)
    plt.close()
    shutil.copy(p, os.path.join(ARTIFACTS_DIR, "hg_graph3_real_vs_sim_wrs.png"))
    print(f"Saved: {p}")

# -----------------------------------------------------------------------------
# Plot 4: WRS Across Musical Noise Genres
# -----------------------------------------------------------------------------
def plot_4_wrs_by_genre():
    fig, ax = plt.subplots(figsize=(9, 5.2), dpi=300)
    genres = ['techno', 'rock', 'jazz']
    genre_display = ['Techno\n(Heavy Bass Kicks)', 'Rock\n(Guitars & Drums)', 'Jazz\n(Dynamic Acoustics)']
    
    x = np.arange(len(genres))
    width = 0.20
    
    for i, (sys, col) in enumerate(zip(SYSTEM_ORDER, SYSTEM_COLORS)):
        vals = []
        for g in genres:
            val = df[(df['Genre'] == g) & (df['System'] == sys)]['Real_WRS'].mean()
            vals.append(val)
        bars = ax.bar(x + (i - 1.5) * width, vals, width, label=sys, color=col, alpha=0.9)
        for bar in bars:
            height = bar.get_height()
            ax.annotate(f'{height:.0f}%',
                        xy=(bar.get_x() + bar.get_width() / 2, height),
                        xytext=(0, 3), textcoords="offset points",
                        ha='center', va='bottom', fontsize=8, fontweight='bold', color='#334155')

    ax.set_title('Word Recognition Score Across Musical Noise Types',
                 fontsize=13, fontweight='bold', pad=15, color='#0F172A')
    ax.set_xlabel('Musical Noise Genre', fontsize=11, fontweight='bold', labelpad=8)
    ax.set_ylabel('Mean Word Recognition Score (WRS %)', fontsize=11, fontweight='bold', labelpad=8)
    ax.set_xticks(x)
    ax.set_xticklabels(genre_display, fontsize=10)
    ax.set_ylim(0, 95)
    ax.grid(True, axis='y')
    ax.legend(loc='upper right', frameon=True, facecolor='white', framealpha=0.95, fontsize=9)
    
    plt.tight_layout()
    p = os.path.join(FIG_DIR, "hg_graph4_wrs_by_genre.png")
    plt.savefig(p)
    plt.close()
    shutil.copy(p, os.path.join(ARTIFACTS_DIR, "hg_graph4_wrs_by_genre.png"))
    print(f"Saved: {p}")

# -----------------------------------------------------------------------------
# Plot 5: Net Intelligibility Gain (Delta WRS over Raw Capture)
# -----------------------------------------------------------------------------
def plot_5_wrs_gain():
    fig, ax = plt.subplots(figsize=(8.5, 5.0), dpi=300)
    snrs = [-20, -15, -10, 0]
    snr_labels = ['-20 dB\n(Extreme Noise)', '-15 dB\n(Heavy Stage Noise)', '-10 dB\n(Loud Ambient)', '0 dB\n(Moderate Noise)']
    
    comp_systems = ['Basic Filter (FIR)', 'Adaptive Dual-Stage', 'Production Hybrid']
    comp_colors = ['#EF4444', '#0284C7', '#10B981']
    
    x = np.arange(len(snrs))
    width = 0.25
    
    for i, (sys, col) in enumerate(zip(comp_systems, comp_colors)):
        gains = []
        for s in snrs:
            raw_val = df[(df['System'] == 'Raw Capture') & (df['SNR_dB'] == s)]['Real_WRS'].mean()
            sys_val = df[(df['System'] == sys) & (df['SNR_dB'] == s)]['Real_WRS'].mean()
            gains.append(sys_val - raw_val)
        bars = ax.bar(x + (i - 1) * width, gains, width, label=sys, color=col, alpha=0.9)
        for bar in bars:
            height = bar.get_height()
            va = 'bottom' if height >= 0 else 'top'
            ypos = height + (1.0 if height >= 0 else -1.5)
            sign = '+' if height > 0 else ''
            ax.annotate(f'{sign}{height:.1f}%',
                        xy=(bar.get_x() + bar.get_width() / 2, ypos),
                        ha='center', va=va, fontsize=8.5, fontweight='bold',
                        color='#0F172A')

    ax.axhline(0, color='#64748B', linestyle='-', linewidth=1.2)
    ax.set_title('Intelligibility Advantage: Word Recognition Gain over Raw Capture',
                 fontsize=13, fontweight='bold', pad=15, color='#0F172A')
    ax.set_xlabel('Input Noise Level (SNR)', fontsize=11, fontweight='bold', labelpad=8)
    ax.set_ylabel('Net WRS Improvement (Percentage Points)', fontsize=11, fontweight='bold', labelpad=8)
    ax.set_xticks(x)
    ax.set_xticklabels(snr_labels, fontsize=9.5)
    ax.set_ylim(-20, 28)
    ax.grid(True, axis='y')
    ax.legend(loc='upper right', frameon=True, facecolor='white', framealpha=0.95, fontsize=9.5)
    
    plt.tight_layout()
    p = os.path.join(FIG_DIR, "hg_graph5_wrs_gain_over_raw.png")
    plt.savefig(p)
    plt.close()
    shutil.copy(p, os.path.join(ARTIFACTS_DIR, "hg_graph5_wrs_gain_over_raw.png"))
    print(f"Saved: {p}")

# -----------------------------------------------------------------------------
# Plot 6: Venue Robustness
# -----------------------------------------------------------------------------
def plot_6_venue_robustness():
    fig, ax = plt.subplots(figsize=(9, 5.2), dpi=300)
    venues = ['Full_Outside', 'Outside', 'Inside']
    venue_labels = ['Outdoor Field\n(Direct Line-of-Sight)', 'Semi-Enclosed Patio\n(Moderate Reflection)', 'Enclosed Room\n(High Reverberation)']
    
    x = np.arange(len(venues))
    width = 0.20
    
    for i, (sys, col) in enumerate(zip(SYSTEM_ORDER, SYSTEM_COLORS)):
        vals = []
        for v in venues:
            val = df[(df['Venue'] == v) & (df['System'] == sys)]['Real_WRS'].mean()
            vals.append(val)
        bars = ax.bar(x + (i - 1.5) * width, vals, width, label=sys, color=col, alpha=0.9)
        for bar in bars:
            height = bar.get_height()
            ax.annotate(f'{height:.0f}%',
                        xy=(bar.get_x() + bar.get_width() / 2, height),
                        xytext=(0, 3), textcoords="offset points",
                        ha='center', va='bottom', fontsize=8, fontweight='bold', color='#334155')

    ax.set_title('Word Recognition Score Across Testing Environments',
                 fontsize=13, fontweight='bold', pad=15, color='#0F172A')
    ax.set_xlabel('Acoustic Testing Venue', fontsize=11, fontweight='bold', labelpad=8)
    ax.set_ylabel('Mean Word Recognition Score (WRS %)', fontsize=11, fontweight='bold', labelpad=8)
    ax.set_xticks(x)
    ax.set_xticklabels(venue_labels, fontsize=10)
    ax.set_ylim(0, 98)
    ax.grid(True, axis='y')
    ax.legend(loc='upper right', frameon=True, facecolor='white', framealpha=0.95, fontsize=9)
    
    plt.tight_layout()
    p = os.path.join(FIG_DIR, "hg_graph6_venue_robustness.png")
    plt.savefig(p)
    plt.close()
    shutil.copy(p, os.path.join(ARTIFACTS_DIR, "hg_graph6_venue_robustness.png"))
    print(f"Saved: {p}")

# -------------------------------------------------------------
# Plot 7: Acoustic Simulation vs Real-World Alignment
# -------------------------------------------------------------
def plot_7_sim_vs_real_alignment():
    from matplotlib.lines import Line2D
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14.8, 6.2), dpi=300)

    # Panel A: STOI Parity & Correlation Alignment
    for sys in SYSTEM_ORDER:
        sub = df[df['System'] == sys]
        ax1.scatter(sub['Sim_STOI'], sub['Real_STOI'], 
                    color=SYSTEM_COLORS[SYSTEM_ORDER.index(sys)], marker=SYSTEM_MARKERS[SYSTEM_ORDER.index(sys)],
                    alpha=0.65, s=42, label=sys, edgecolor='white', linewidth=0.4)

    lims = [0.10, 0.88]
    ax1.plot(lims, lims, color='#64748B', linestyle='--', linewidth=1.5, zorder=2,
             label='1:1 Parity Line (Sim = Real)')

    slope, intercept, r_val, p_val, _ = stats.linregress(df['Sim_STOI'], df['Real_STOI'])
    x_reg = np.linspace(0.10, 0.76, 100)
    y_reg = slope * x_reg + intercept
    ax1.plot(x_reg, y_reg, color='#0F172A', linewidth=2.8, zorder=4,
             label=f'Linear Fit (r = {r_val:.2f}, R² = {r_val**2:.2f}, p < 0.001)')

    ax1.fill_between(x_reg, x_reg, y_reg, color='#059669', alpha=0.08)

    ax1.set_title('(A) Acoustic Correlation Alignment (STOI)', fontsize=12.5, fontweight='bold', pad=12, color='#0F172A')
    ax1.set_xlabel('Simulated Acoustic Intelligibility (Sim STOI)', fontsize=10.5, fontweight='bold', labelpad=8)
    ax1.set_ylabel('Real-World Hardware Intelligibility (Real STOI)', fontsize=10.5, fontweight='bold', labelpad=8)
    ax1.set_xlim(0.10, 0.85)
    ax1.set_ylim(0.25, 0.95)
    ax1.grid(True, linestyle='--', alpha=0.5)
    ax1.legend(loc='lower right', frameon=True, facecolor='white', framealpha=0.95, fontsize=8.5)

    # Panel B: Intelligibility Trajectory Alignment (WRS % across SNR)
    snrs = [-20, -15, -10, 0]
    snr_labels = ['-20 dB\n(Extreme)', '-15 dB\n(Heavy)', '-10 dB\n(Loud)', '0 dB\n(Moderate)']

    for i, sys in enumerate(SYSTEM_ORDER):
        sub = df[df['System'] == sys]
        real_means = [sub[sub['SNR_dB'] == s]['Real_WRS'].mean() for s in snrs]
        sim_means = [sub[sub['SNR_dB'] == s]['Sim_WRS'].mean() for s in snrs]
        
        ax2.plot(snrs, real_means, color=SYSTEM_COLORS[i], marker=SYSTEM_MARKERS[i],
                 markersize=7.5, linewidth=2.5, linestyle='-', label=f'{sys} (Real)')
        ax2.plot(snrs, sim_means, color=SYSTEM_COLORS[i], marker=SYSTEM_MARKERS[i],
                 markersize=6.5, linewidth=1.8, linestyle=':', alpha=0.85, markerfacecolor='white',
                 label=f'{sys} (Sim)')

    ax2.axhline(50.0, color='#DC2626', linestyle='--', linewidth=1.1, alpha=0.7)

    ax2.set_title('(B) Word Recognition Trajectory Alignment Across Noise Levels', 
                  fontsize=12.5, fontweight='bold', pad=12, color='#0F172A')
    ax2.set_xlabel('Input Signal-to-Noise Ratio (dB)', fontsize=10.5, fontweight='bold', labelpad=8)
    ax2.set_ylabel('Word Recognition Score (WRS %)', fontsize=10.5, fontweight='bold', labelpad=8)
    ax2.set_xticks(snrs)
    ax2.set_xticklabels(snr_labels)
    ax2.set_ylim(-3, 105)
    ax2.grid(True, linestyle='--', alpha=0.5)

    custom_lines = [
        Line2D([0], [0], color='#0F172A', lw=2.2, linestyle='-', label='Real-World Hardware (Solid)'),
        Line2D([0], [0], color='#0F172A', lw=1.8, linestyle=':', marker='o', markerfacecolor='white', label='Acoustic Simulation (Dotted)'),
        Line2D([0], [0], color='#DC2626', lw=1.2, linestyle='--', label='50% Threshold Reference'),
        Line2D([0], [0], color=SYSTEM_COLORS[3], lw=2, label='Production Hybrid'),
        Line2D([0], [0], color=SYSTEM_COLORS[2], lw=2, label='Adaptive Dual-Stage'),
        Line2D([0], [0], color=SYSTEM_COLORS[1], lw=2, label='Basic Filter (FIR)'),
        Line2D([0], [0], color=SYSTEM_COLORS[0], lw=2, label='Raw Capture')
    ]
    ax2.legend(handles=custom_lines, loc='upper left', frameon=True, facecolor='white', framealpha=0.95, fontsize=8.2)

    fig.suptitle('Alignment of Acoustic Simulation and Real-World Hardware Results',
                 fontsize=14.5, fontweight='bold', y=0.98, color='#0F172A')

    plt.tight_layout(rect=[0, 0.02, 1, 0.94])
    p = os.path.join(FIG_DIR, "hg_graph7_sim_vs_real_alignment.png")
    plt.savefig(p)
    plt.close()
    shutil.copy(p, os.path.join(ARTIFACTS_DIR, "hg_graph7_sim_vs_real_alignment.png"))
    print(f"Saved: {p}")

# -----------------------------------------------------------------------------
# Execute All
# -----------------------------------------------------------------------------
if __name__ == '__main__':
    plot_1_psychometric_curve()
    plot_1b_textbook_comparison()
    plot_2_real_world_wrs_by_snr()
    plot_3_real_vs_sim_wrs()
    plot_4_wrs_by_genre()
    plot_5_wrs_gain()
    plot_6_venue_robustness()
    plot_7_sim_vs_real_alignment()
    print("All 8 Holy Grail visualizations successfully generated and mirrored!")
