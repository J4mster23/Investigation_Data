#!/usr/bin/env python3
"""
plot_spectral_overlap_difficulty.py

Generates a poster-sized, high-contrast, minimalist scientific figure showing the
frequency-domain spectral curves of human speech and concert music.
Features extra-large typography, thick curves, and prominent axes for legibility
from 1-2 metres away on an A0/A1 landscape open day poster.
"""

import os
import shutil
import numpy as np
import soundfile as sf
import scipy.signal as signal
import matplotlib.pyplot as plt

# Set directory paths
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FIG_DIR = os.path.join(BASE_DIR, "NLMS", "figures")
ARTIFACTS_DIR = "/Users/macairm1/.gemini/antigravity/brain/fa14326e-1c60-480f-a3be-913fac3a8bd5"
ARTIFACTS_FIG_DIR = os.path.join(ARTIFACTS_DIR, "figures")

os.makedirs(FIG_DIR, exist_ok=True)
os.makedirs(ARTIFACTS_FIG_DIR, exist_ok=True)

# Audio paths
SPEECH_PATH = os.path.join(BASE_DIR, "dataset", "speech_corpus", "male", "male_01_IUS-M00201.wav")
TECHNO_PATH = os.path.join(BASE_DIR, "dataset", "wav_16k", "techno", "techno_1389887.wav")
ROCK_PATH   = os.path.join(BASE_DIR, "dataset", "wav_16k", "rock", "rock_01_rock.00011.wav")

speech, fs = sf.read(SPEECH_PATH)
techno, _  = sf.read(TECHNO_PATH)
rock, _    = sf.read(ROCK_PATH)

# Combine music representation
min_len = min(len(speech), len(techno), len(rock))
speech = speech[:min_len]
music  = 0.6 * techno[:min_len] + 0.4 * rock[:min_len]

# Compute smoothed Welch PSD
nperseg = 2048
f_sp, psd_sp = signal.welch(speech, fs, nperseg=nperseg, noverlap=nperseg//2)
f_mu, psd_mu = signal.welch(music, fs, nperseg=nperseg, noverlap=nperseg//2)

# Convert to dB
psd_sp_db = 10 * np.log10(psd_sp + 1e-12)
psd_mu_db = 10 * np.log10(psd_mu + 1e-12)

# Normalize relative levels: Concert music has dominant bass over speech at ~0 dB nominal SNR
psd_sp_db -= np.max(psd_sp_db)
psd_mu_db -= np.max(psd_mu_db)
psd_mu_db += 6.0  # Music is louder in bass in concert soundscapes

# Apply Savitzky-Golay smoothing for bold, clean curves
smooth_sp = signal.savgol_filter(psd_sp_db, window_length=31, polyorder=3)
smooth_mu = signal.savgol_filter(psd_mu_db, window_length=31, polyorder=3)

# Filter range to plot (40 Hz to 8000 Hz)
idx_valid = (f_sp >= 40) & (f_sp <= 8000)
f_plot = f_sp[idx_valid]
sp_plot = smooth_sp[idx_valid]
mu_plot = smooth_mu[idx_valid]

# -----------------------------------------------------------------------------
# POSTER-SCALE PLOT CONFIGURATION (Extra Large for 1-2m Legibility)
# -----------------------------------------------------------------------------
plt.rcParams['font.sans-serif'] = 'Helvetica, Arial, DejaVu Sans, sans-serif'
plt.rcParams['font.family'] = 'sans-serif'
plt.rcParams['axes.edgecolor'] = '#64748B'
plt.rcParams['axes.linewidth'] = 2.2

fig, ax = plt.subplots(figsize=(12.0, 7.5), dpi=300)

# Overlap region shading
overlap_curve = np.minimum(sp_plot, mu_plot)
ax.fill_between(f_plot, -55, overlap_curve, color='#F59E0B', alpha=0.28, hatch='///',
                label='Spectral Overlap Region', zorder=2)

# Human Speech Curve (Extra thick bold stroke)
ax.plot(f_plot, sp_plot, color='#1D4ED8', linewidth=4.8, label='Human Speech', zorder=4)
ax.fill_between(f_plot, -55, sp_plot, color='#3B82F6', alpha=0.15, zorder=3)

# Concert Music Curve (Extra thick bold stroke)
ax.plot(f_plot, mu_plot, color='#DC2626', linewidth=4.8, label='Concert Music', zorder=4)
ax.fill_between(f_plot, -55, mu_plot, color='#EF4444', alpha=0.12, zorder=3)

# Axis configuration
ax.set_xscale('log')
ax.set_xlim(40, 8000)
ax.set_ylim(-55, 20)
ax.set_xticks([60, 125, 250, 500, 1000, 2000, 4000, 8000])
ax.get_xaxis().set_major_formatter(plt.ScalarFormatter())

# Extra-large, bold axis labels
ax.set_xlabel('Frequency (Hz)', fontsize=22, fontweight='bold', labelpad=14, color='#0F172A')
ax.set_ylabel('Magnitude (dB)', fontsize=22, fontweight='bold', labelpad=14, color='#0F172A')

# Extra-large, bold tick parameters
ax.tick_params(axis='both', which='major', labelsize=17, length=9, width=2.2, colors='#0F172A')
ax.tick_params(axis='both', which='minor', length=5, width=1.4, colors='#64748B')
for label in ax.get_xticklabels() + ax.get_yticklabels():
    label.set_fontweight('bold')

ax.grid(True, which='both', linestyle='--', linewidth=1.1, color='#CBD5E1', alpha=0.8)

# Extra-large, high-contrast poster legend
ax.legend(loc='upper right', fontsize=19, framealpha=0.96, edgecolor='#94A3B8',
          facecolor='#FFFFFF', borderpad=0.9, handlelength=2.5, handletextpad=0.8)

plt.tight_layout(pad=2.0)

# Save figures
out_path_main = os.path.join(FIG_DIR, "spectral_overlap_speech_vs_music.png")
plt.savefig(out_path_main, dpi=300, bbox_inches='tight')
print(f"✓ Saved poster-scale figure to: {out_path_main}")

# Copy to brain artifact directory
shutil.copy2(out_path_main, os.path.join(ARTIFACTS_FIG_DIR, "spectral_overlap_speech_vs_music.png"))
shutil.copy2(out_path_main, os.path.join(ARTIFACTS_DIR, "spectral_overlap_speech_vs_music.png"))
print(f"✓ Mirrored to brain artifact directory: {ARTIFACTS_DIR}")

plt.close()
print("Figure generation complete!")
