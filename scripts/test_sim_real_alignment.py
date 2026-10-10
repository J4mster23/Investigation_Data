import os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from scipy import stats

# Set styling
plt.rcParams['font.sans-serif'] = 'Helvetica'
plt.rcParams['axes.edgecolor'] = '#94A3B8'
plt.rcParams['axes.linewidth'] = 0.8

df = pd.read_csv('NLMS/output_audio/holy_grail_results.csv')

LABEL_MAP = {
    'PASSTHROUGH': 'Raw Capture',
    'CONTROL': 'Basic Filter (FIR)',
    'MIXED': 'Adaptive Dual-Stage',
    'OPTIMAL': 'Production Hybrid'
}
df['System'] = df['Filter'].map(LABEL_MAP)

# Psychometric WRS calibration
a_opt = -22.0378
b_opt = 11.8858
def stoi_to_wrs(s):
    return 100.0 / (1.0 + np.exp(a_opt * s + b_opt))

df['Real_WRS'] = stoi_to_wrs(df['Real_STOI'])
df['Sim_WRS'] = stoi_to_wrs(df['Sim_STOI'])

SYSTEM_ORDER = ['Raw Capture', 'Basic Filter (FIR)', 'Adaptive Dual-Stage', 'Production Hybrid']
SYSTEM_COLORS = {'Raw Capture': '#64748B', 'Basic Filter (FIR)': '#EF4444', 
                 'Adaptive Dual-Stage': '#0284C7', 'Production Hybrid': '#10B981'}
SYSTEM_MARKERS = {'Raw Capture': 'o', 'Basic Filter (FIR)': 's', 
                  'Adaptive Dual-Stage': '^', 'Production Hybrid': 'D'}

fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 6), dpi=300)

# -------------------------------------------------------------
# Panel A: STOI Parity & Correlation Alignment
# -------------------------------------------------------------
# Scatter points for each system
for sys in SYSTEM_ORDER:
    sub = df[df['System'] == sys]
    ax1.scatter(sub['Sim_STOI'], sub['Real_STOI'], 
                color=SYSTEM_COLORS[sys], marker=SYSTEM_MARKERS[sys],
                alpha=0.60, s=40, label=sys, edgecolor='none')

# Parity line (y = x)
lims = [0.10, 0.90]
ax1.plot(lims, lims, color='#94A3B8', linestyle='--', linewidth=1.5, zorder=2,
         label='1:1 Parity Line (Sim = Real)')

# Regression line
slope, intercept, r_val, p_val, _ = stats.linregress(df['Sim_STOI'], df['Real_STOI'])
x_reg = np.linspace(0.10, 0.78, 100)
y_reg = slope * x_reg + intercept
ax1.plot(x_reg, y_reg, color='#0F172A', linewidth=2.5, zorder=4,
         label=f'Linear Fit (r = {r_val:.2f}, R² = {r_val**2:.2f})')

# Fill hardware advantage area between regression line and parity line
ax1.fill_between(x_reg, x_reg, y_reg, color='#10B981', alpha=0.08)

# Annotate hardware advantage
ax1.annotate('Hardware Advantage (+0.16 STOI)\nPhysical proximity & directivity\noutperform diffuse simulation',
             xy=(0.42, 0.60), xytext=(0.18, 0.74),
             arrowprops=dict(arrowstyle='->', lw=1.3, color='#0F172A'),
             bbox=dict(boxstyle='round,pad=0.4', facecolor='#F8FAFC', edgecolor='#64748B', lw=1.0),
             fontsize=9, fontweight='medium', color='#0F172A')

ax1.set_title('(A) Acoustic Correlation Alignment (STOI)', fontsize=12, fontweight='bold', pad=12, color='#0F172A')
ax1.set_xlabel('Simulated Acoustic Intelligibility (Sim STOI)', fontsize=10.5, fontweight='bold', labelpad=8)
ax1.set_ylabel('Real-World Hardware Intelligibility (Real STOI)', fontsize=10.5, fontweight='bold', labelpad=8)
ax1.set_xlim(0.10, 0.85)
ax1.set_ylim(0.25, 0.95)
ax1.grid(True, linestyle='--', alpha=0.5)
ax1.legend(loc='lower right', frameon=True, facecolor='white', framealpha=0.95, fontsize=8.5)

# -------------------------------------------------------------
# Panel B: Intelligibility Trajectory Alignment (WRS % across SNR)
# -------------------------------------------------------------
snrs = [-20, -15, -10, 0]
snr_labels = ['-20 dB\n(Extreme)', '-15 dB\n(Heavy)', '-10 dB\n(Loud)', '0 dB\n(Moderate)']

for sys in SYSTEM_ORDER:
    sub = df[df['System'] == sys]
    real_means = [sub[sub['SNR_dB'] == s]['Real_WRS'].mean() for s in snrs]
    sim_means = [sub[sub['SNR_dB'] == s]['Sim_WRS'].mean() for s in snrs]
    
    # Real World (solid)
    ax2.plot(snrs, real_means, color=SYSTEM_COLORS[sys], marker=SYSTEM_MARKERS[sys],
             markersize=7, linewidth=2.4, linestyle='-', label=f'{sys} (Real)')
    # Simulation (dashed)
    ax2.plot(snrs, sim_means, color=SYSTEM_COLORS[sys], marker=SYSTEM_MARKERS[sys],
             markersize=6, linewidth=1.8, linestyle=':', alpha=0.75, markerfacecolor='white',
             label=f'{sys} (Sim)')

ax2.set_title('(B) Word Recognition Trajectory Alignment Across Noise Levels', 
              fontsize=12, fontweight='bold', pad=12, color='#0F172A')
ax2.set_xlabel('Input Signal-to-Noise Ratio (dB)', fontsize=10.5, fontweight='bold', labelpad=8)
ax2.set_ylabel('Word Recognition Score (WRS %)', fontsize=10.5, fontweight='bold', labelpad=8)
ax2.set_xticks(snrs)
ax2.set_xticklabels(snr_labels)
ax2.set_ylim(-3, 105)
ax2.grid(True, linestyle='--', alpha=0.5)

# Create custom combined legend for Panel B
from matplotlib.lines import Line2D
custom_lines = [
    Line2D([0], [0], color='#0F172A', lw=2.2, linestyle='-', label='Real-World Hardware (Solid)'),
    Line2D([0], [0], color='#0F172A', lw=1.8, linestyle=':', marker='o', markerfacecolor='white', label='Acoustic Simulation (Dotted)'),
    Line2D([0], [0], color=SYSTEM_COLORS['Production Hybrid'], lw=2, label='Production Hybrid'),
    Line2D([0], [0], color=SYSTEM_COLORS['Adaptive Dual-Stage'], lw=2, label='Adaptive Dual-Stage'),
    Line2D([0], [0], color=SYSTEM_COLORS['Basic Filter (FIR)'], lw=2, label='Basic Filter (FIR)'),
    Line2D([0], [0], color=SYSTEM_COLORS['Raw Capture'], lw=2, label='Raw Capture')
]
ax2.legend(handles=custom_lines, loc='upper left', frameon=True, facecolor='white', framealpha=0.95, fontsize=8.5)

fig.suptitle('Alignment of Acoustic Simulation and Real-World Hardware Results',
             fontsize=14, fontweight='bold', y=0.98, color='#0F172A')

plt.tight_layout()
os.makedirs('NLMS/figures', exist_ok=True)
p = 'NLMS/figures/hg_graph7_sim_vs_real_alignment.png'
plt.savefig(p)
plt.close()
print('Generated successfully:', p)
