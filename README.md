# Speech Enhancement in High-Noise Environments: Genre-Specific Filtering

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![MATLAB](https://img.shields.io/badge/MATLAB-R2025a-blue.svg)](https://www.mathworks.com/products/matlab.html)
[![Target: ESP32-S3](https://img.shields.io/badge/Target-ESP32--S3-red.svg)](https://www.espressif.com/en/products/socs/esp32-s3)

An investigation into **genre-specific and adaptive filtering approaches to speech enhancement in high-noise environments (EDM music festivals and clubs)**.

* **Authors**: Ryan Jammy & Raphael Alsfine  
* **Institution**: School of Electrical & Information Engineering, University of the Witwatersrand  
* **Academic Supervisor**: Dr. Ryan Jammy / Project Committee  
* **Investigation Plan**: *"An Evaluation of Genre-Specific and Adaptive Filtering Approaches to Speech Enhancement in High-Noise Environments"*

---

## Abstract & Objectives

Conversational speech in loud electronic dance music (EDM) venues ($>100\text{ dB SPL}$) experiences severe intelligibility degradation due to the upward spread of low-frequency acoustic masking. This repository contains the complete offline research, STFT spectral analysis, filter design, and embedded firmware implementation comparing:
1. **Genre-Specific 128-Tap FIR Filters** (Parks-McClellan equiripple design, linear phase, $4.0\text{ ms}$ delay).
2. **Genre-Specific 8th-Order IIR Filters** (Chebyshev Type II Cascaded Second-Order Sections / Biquads, $1.3\text{ ms}$ passband delay, $6.4\times$ computational speedup).

The derived filter topologies target the distinct acoustic signatures of **House**, **Techno**, and **Drum & Bass** while preserving speech formants across the telecommunication band ($300 - 3400\text{ Hz}$).

---

## Repository Structure

```text
├── dataset/
│   ├── REFERENCES.md                  # Complete academic citations (ISMIR, UPF, IEEE Harvard)
│   ├── README.md                      # Dataset guide & documentation
│   ├── metadata/
│   │   ├── selected_tracks.json       # 150-track curated manifest (50 House, 50 Techno, 50 DnB)
│   │   ├── genre_spectral_profiles.mat# Full MATLAB spectral workspace
│   │   ├── genre_spectral_profiles.json# JSON spectral profiles for DSP import
│   │   ├── harvard_transcripts.json   # 20 Harvard Sentences ground-truth text
│   │   └── stft_summary_table.csv     # Quantitative subband energy distribution table
│   └── test_stimuli/
│       ├── music_noise_60s/           # 60s calibrated continuous music noise (1 per genre)
│       ├── speech_sentences/          # 20 clean Harvard speech sentence WAVs (16 kHz, 16-bit)
│       └── isolated_snippets/         # 10s isolated speech, music, and combined test snippets
├── figures/
│   ├── stft_mean_spectral_profiles.png # Superimposed magnitude spectra (0 - 8 kHz)
│   ├── stft_subband_energy_bars.png   # Energy breakdown (Sub-bass, Kick, Speech, Highs)
│   ├── stft_genre_variance_envelopes.png # Within-genre ±1σ variance envelopes
│   ├── filter_comparison_magnitude.png # FIR vs IIR frequency magnitude overlay
│   ├── filter_comparison_group_delay.png# Group delay & latency profiles (0 - 4 kHz)
│   ├── filter_comparison_poles_zeros.png# Complex z-plane stability verification
│   └── filter_comparison_speech_enhancement.png # ΔSNR and STOI benchmark bars
├── firmware/
│   ├── fir_coefficients.h             # 128-tap FIR coefficients + convolution loop
│   └── iir_coefficients.h             # 4-Biquad SOS coefficients + Direct Form II Transposed loop
├── scripts/
│   ├── build_dataset_manifest.py      # Curates 150 balanced EDM tracks from GiantSteps
│   ├── download_and_convert.py        # Asynchronous multi-threaded downloader & 16 kHz converter
│   ├── prepare_test_stimuli.py        # Extracts 60s continuous noise stimuli
│   ├── verify_spectral_profiles.py    # Python STFT sanity check
│   ├── stft_genre_analysis.m          # Full MATLAB STFT run across 150 tracks
│   ├── design_and_compare_filters.m   # FIR & IIR filter designer and STOI/SNR benchmark
│   ├── generate_speech_corpus.py      # Speech synthesis pipeline
│   └── mix_isolated_snippets.py       # Pure Python ITU-T active speech mixing pipeline
├── .gitignore                         # Ignores large raw audio binaries (~225 MB)
└── README.md                          # Project documentation (this file)
```

---

## Key Experimental Results

### 1. Acoustic Subband Distribution (STFT across 150 Tracks)
* **Sampling Rate**: $f_s = 16\,000\text{ Hz}$ | **FFT**: $1024\text{ points}$ ($\Delta f = 15.625\text{ Hz}$) | **Window**: Hann ($50\%$ overlap)

| Subgenre | Peak Freq | Sub-Bass ($<80\text{ Hz}$) | Kick ($60-150\text{ Hz}$) | Low Bass ($<250\text{ Hz}$) | Speech Band ($300-3.4\text{ kHz}$) | Highs ($>4\text{ kHz}$) | Centroid |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **House** | $46.9\text{ Hz}$ | $55.96\%$ | **$42.72\%$** | $78.03\%$ | $16.76\%$ | $1.85\%$ | $361.2\text{ Hz}$ |
| **Techno** | $62.5\text{ Hz}$ | **$65.28\%$** | **$51.86\%$** | **$85.37\%$** | **$10.62\%$** | $1.40\%$ | $270.6\text{ Hz}$ |
| **Drum & Bass** | $46.9\text{ Hz}$ | $49.85\%$ | $35.63\%$ | $69.12\%$ | $22.98\%$ | **$4.35\%$** | **$612.6\text{ Hz}$** |

### 2. FIR vs. IIR Embedded Benchmark (ESP32-S3 Target)

| Dimension | 128-Tap FIR (`firpm`) | 8th-Order IIR SOS (`cheby2`) | Speedup / Advantage |
| :--- | :---: | :---: | :--- |
| **Coefficients** | $129\text{ floats}$ ($516\text{ B}$) | **$24\text{ floats}$** ($96\text{ B}$) | **$5.4\times$ less memory** |
| **MACs per Sample** | $128\text{ MACs}$ | **$20\text{ operations}$** | **$6.4\times$ faster execution** |
| **CPU Rate @ 16 kHz** | $2.05\text{ MFLOPS}$ | **$0.32\text{ MFLOPS}$** | **Saves $84.4\%$ CPU load** |
| **Core Speech Delay** | Constant $4.00\text{ ms}$ | **$0.80 - 1.80\text{ ms}$** | **$2.7\times$ lower latency** |
| **Stability** | Unconditional | Stable ($\max |p_i| = 0.9688$) | Verified inside unit circle |
| **Speech STOI** | $0.752$ (@ -10 dB) | **$0.752$** (@ -10 dB) | **Zero intelligibility loss from non-linear phase** |

---

## Getting Started & Execution

### 1. MATLAB Filter Design & Benchmark
To run the full STFT analysis and filter comparison:
```bash
matlab -batch "addpath('scripts'); stft_genre_analysis; design_and_compare_filters; exit;"
```

### 2. Audio Isolation & Python Mixing
To generate the 10-second isolated speech, music, and mixed snippets:
```bash
python3 scripts/mix_isolated_snippets.py
```

### 3. ESP32-S3 Firmware Compilation
Include the pre-generated C headers in your ESP-IDF or Arduino firmware:
```c
#include "firmware/iir_coefficients.h"

// In your audio processing loop (16 kHz):
float state[8] = {0};
float enhanced_sample = process_iir_biquads(sos_techno_iir, state, raw_mic_sample, g_techno_iir);
```

---

## References

1. P. Knees et al., *"Two data sets for tempo estimation and key detection in electronic dance music annotated from user corrections,"* in Proc. ISMIR, 2015.
2. IEEE Subcommittee on Subjective Measurements, *"IEEE Recommended Practice for Speech Quality Measurements,"* IEEE Trans. Audio Electroacoust., 1969.
3. C. H. Taal et al., *"An algorithm for intelligibility prediction of time-frequency weighted noisy speech,"* IEEE Trans. ASLP, 2011.
