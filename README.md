# Speech Enhancement in High-Noise Environments: Genre-Specific Filtering

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![MATLAB](https://img.shields.io/badge/MATLAB-R2025a-blue.svg)](https://www.mathworks.com/products/matlab.html)
[![Target: ESP32-S3](https://img.shields.io/badge/Target-ESP32--S3-red.svg)](https://www.espressif.com/en/products/socs/esp32-s3)

An investigation into **genre-specific and adaptive filtering approaches to speech enhancement in high-noise environments**.

* **Authors**: Ryan Jammy & Raphael Alsfine  
* **Institution**: School of Electrical & Information Engineering, University of the Witwatersrand  
* **Genres Evaluated**: **Jazz**, **Rock**, and **Techno** (Maximum acoustic divergence triad)  
* **Corpus Size**: 150 tracks (50 Jazz, 50 Rock, 50 Techno) standardized @ $16\text{ kHz}$, 16-bit mono linear PCM

---

## Abstract & Objectives

Conversational speech in loud entertainment and music environments experiences severe intelligibility degradation due to the upward spread of acoustic masking. This repository contains the complete empirical research, STFT spectral analysis, filter design, and embedded firmware implementation comparing:
1. **Genre-Specific 128-Tap FIR Filters** (Parks-McClellan equiripple design, linear phase, $4.0\text{ ms}$ delay).
2. **Genre-Specific 8th-Order IIR Filters** (Chebyshev Type II Cascaded Second-Order Sections / Biquads, $0.8 - 1.8\text{ ms}$ passband delay, $6.4\times$ computational speedup).
3. **Phase 2 Parametric Notch Biquad Filters** (Narrow high-Q rejection of resonant bass fundamentals while extending lower passband to $150\text{ Hz}$ to preserve male vocal pitch $F_0$).

The derived filter topologies target the distinct acoustic signatures of **Jazz**, **Rock**, and **Techno** while preserving speech formants across the telecommunication band ($300 - 3400\text{ Hz}$).

---

## Repository Structure

```text
├── dataset/
│   ├── REFERENCES.md                  # Academic citations (GTZAN, GiantSteps, IEEE Harvard)
│   ├── README.md                      # Dataset overview & specifications
│   ├── metadata/
│   │   ├── genre_spectral_profiles.mat# Full MATLAB spectral workspace (513 bins) + Speech FFT
│   │   ├── genre_spectral_profiles.json# JSON spectral profiles for DSP import
│   │   ├── speech_overlay_manifest.json# Manifest of 90 controlled speech overlay files
│   │   ├── harvard_transcripts.json   # 20 Harvard Sentences ground-truth text
│   │   └── stft_summary_table.csv     # Quantitative subband energy distribution table
│   └── test_stimuli/
│       ├── music_noise_30s/           # 30s calibrated continuous music noise (Jazz, Rock, Techno)
│       ├── speech_sentences/          # 20 clean Harvard speech sentence WAVs (16 kHz, 16-bit)
│       ├── isolated_snippets/         # 10s isolated speech, music, and combined test snippets
│       └── speech_overlay_dataset/    # 90 controlled speech overlay files (Jazz, Rock, Techno)
├── figures/
│   ├── speech_male_vs_female_spectral_profiles.png # Male vs Female pitch & formant profiles
│   ├── speech_vs_genre_spectral_overlays.png # Speech FFT vs Jazz, Rock, Techno (0-8 kHz & zoom)
│   ├── speech_masking_differentials.png# Spectral SNR / masking margin across frequency
│   ├── speech_formants_filter_alignment.png # Vocal formants (F0-F3) vs filter passbands/stopbands
│   ├── stft_mean_spectral_profiles.png # Superimposed magnitude spectra (Jazz, Rock, Techno)
│   ├── stft_subband_energy_bars.png   # Energy breakdown (Sub-bass, Kick, Speech, Highs)
│   ├── stft_genre_variance_envelopes.png # Within-genre ±1σ variance envelopes
│   ├── filter_comparison_notch_vs_bandpass.png # Notch vs Bandpass magnitude & latency
│   ├── filter_comparison_magnitude.png # FIR vs IIR frequency magnitude overlay
│   ├── filter_comparison_group_delay.png# Group delay & latency profiles (0 - 4 kHz)
│   ├── filter_comparison_poles_zeros.png# Complex z-plane stability verification
│   └── filter_comparison_speech_enhancement.png # ΔSNR and STOI benchmark bars
├── firmware/
│   ├── fir_coefficients.h             # 128-tap FIR coefficients + convolution loop
│   └── iir_coefficients.h             # 4-Biquad SOS coefficients + Parametric Notch Biquad
├── scripts/
│   ├── extract_and_standardize_ius.py # Ingests & standardizes IUS human speech corpus
│   ├── download_jazz_gtzan.py         # Downloads & standardizes GTZAN Jazz tracks
│   ├── prepare_genre_test_stimuli.py  # Extracts 30s continuous noise stimuli
│   ├── stft_genre_analysis.m          # Full MATLAB STFT & Speech FFT overlay run across 150 tracks
│   ├── design_and_compare_filters.m   # FIR, IIR & Parametric Notch filter designer & benchmark
│   ├── create_comprehensive_speech_overlays.py # Generates 90 controlled overlays in Python
│   ├── mix_isolated_snippets.py       # Python ITU-T active speech 10s snippet generator
│   └── generate_speech_corpus.py      # Speech synthesis pipeline
├── .gitignore                         # Ignores large raw audio binaries
└── README.md                          # Project documentation (this file)
```

---

## Key Experimental Results

### 1. Acoustic Subband Distribution (STFT across 150 Tracks)
* **Sampling Rate**: $f_s = 16\,000\text{ Hz}$ | **FFT**: $1024\text{ points}$ ($\Delta f = 15.625\text{ Hz}$) | **Window**: Hann ($50\%$ overlap)

| Genre | Peak Freq | Sub-Bass ($<80\text{ Hz}$) | Kick/Bass ($60-150\text{ Hz}$) | Low Bass ($<250\text{ Hz}$) | Speech Band ($300-3.4\text{ kHz}$) | Highs ($>4\text{ kHz}$) | Centroid |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Jazz** | $78.1\text{ Hz}$ | $14.42\%$ | $30.00\%$ | $45.78\%$ | **$46.97\%$** | $0.77\%$ | $504.2\text{ Hz}$ |
| **Rock** | $109.4\text{ Hz}$ | $13.67\%$ | $33.68\%$ | $60.66\%$ | **$31.74\%$** | $1.86\%$ | $557.5\text{ Hz}$ |
| **Techno** | $62.5\text{ Hz}$ | **$65.28\%$** | **$51.86\%$** | **$85.37\%$** | $10.62\%$ | $1.40\%$ | $270.6\text{ Hz}$ |

### 2. Multi-Talker Human Vocal Profile (IUS Corpus: Male vs. Female)
* **Corpus**: Indiana University Sentence Database (IUS) (Karl & Pisoni, 1994)
* **Sample Size**: 50 Male talkers (`IUS-M`), 50 Female talkers (`IUS-F`), 100 Combined talkers
* **Sampling Rate**: $f_s = 16\,000\text{ Hz}$ | **Analysis**: Active speech frames ($>-25\text{ dB}$ peak power)

| Voice Group | Pitch Fundamental ($F_0$) | First Formant ($F_1$) | Spectral Centroid | Energy $<250\text{ Hz}$ | Energy in Speech Band ($300-3400\text{ Hz}$) | Highs ($>4\text{ kHz}$) |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **Male Speech ($N=50$)** | **$125.0\text{ Hz}$** | $500.0\text{ Hz}$ | $674.5\text{ Hz}$ | **$15.66\%$** | $75.73\%$ | $1.97\%$ |
| **Female Speech ($N=50$)**| **$218.8\text{ Hz}$** | $593.8\text{ Hz}$ | $773.1\text{ Hz}$ | **$26.09\%$** | $67.99\%$ | $1.70\%$ |
| **Combined ($N=100$)** | $125.0 / 218.8\text{ Hz}$ | $500.0\text{ Hz}$ | $724.0\text{ Hz}$ | **$20.90\%$** | $71.84\%$ | $1.83\%$ |

> [!IMPORTANT]
> Traditional bandpass filtering ($300 - 3400\text{ Hz}$) removes all energy below $300\text{ Hz}$, stripping **$15.7\%$ of male vocal energy** and **$26.1\%$ of female vocal energy**, amputating the pitch fundamental ($F_0$) and causing voices to sound thin and unnatural.

### 3. FIR vs. IIR Embedded Benchmark (ESP32-S3 Target)

| Dimension | 128-Tap FIR (`firpm`) | 8th-Order IIR SOS (`cheby2`) | Speedup / Advantage |
| :--- | :---: | :---: | :--- |
| **Coefficients** | $129\text{ floats}$ ($516\text{ B}$) | **$24\text{ floats}$** ($96\text{ B}$) | **$5.4\times$ less memory** |
| **MACs per Sample** | $128\text{ MACs}$ | **$20\text{ operations}$** | **$6.4\times$ faster execution** |
| **CPU Rate @ 16 kHz** | $2.05\text{ MFLOPS}$ | **$0.32\text{ MFLOPS}$** | **Saves $84.4\%$ CPU load** |
| **Core Speech Delay** | Constant $4.00\text{ ms}$ | **$0.80 - 1.80\text{ ms}$** | **$2.7\times$ lower latency** |
| **Stability** | Unconditional | Stable ($\max |p_i| = 0.9708$) | Verified inside unit circle |
| **Speech STOI** | Matches within $\pm 0.008$ | Matches within $\pm 0.008$ | **Zero intelligibility penalty from non-linear phase** |

### 4. Parametric Notch Filter Benchmark (Preserving Pitch Fundamental)

Cascaded Second-Order Section (SOS) notch filters target specific music resonance peaks while keeping the broad speech band open ($80 - 8000\text{ Hz}$):
- **Techno**: $62.5\text{ Hz}$ ($Q=8.0$, $-40\text{ dB}$) + $125.0\text{ Hz}$ ($Q=8.0$, $-25\text{ dB}$)
- **Rock**: $109.4\text{ Hz}$ ($Q=6.0$, $-35\text{ dB}$) + High-shelf $4\text{ kHz}$ ($-12\text{ dB}$)
- **Jazz**: $78.1\text{ Hz}$ ($Q=6.0$, $-30\text{ dB}$)

| Genre | Input SNR | STOI Unprocessed | STOI Bandpass | STOI Parametric Notch | Notch Latency in Voice Band |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Jazz** | $-10\text{ dB}$ | $0.810$ | $0.797$ (Degraded) | **$0.810$ (Preserved)** | $< 0.15\text{ ms}$ |
| **Rock** | $-10\text{ dB}$ | $0.842$ | $0.832$ (Degraded) | **$0.841$ (Preserved)** | $< 0.15\text{ ms}$ |
| **Techno** | $-10\text{ dB}$ | $0.889$ | $0.869$ (Degraded) | **$0.889$ (Preserved)** | $< 0.15\text{ ms}$ |

---

## Controlled Speech Overlay Dataset

Generated via Python using **ITU-T P.56 active speech power leveling** to prevent silence from skewing SNR calibration.

- **Total Samples**: **90 audio files**
- **Genres Covered**: Jazz, Rock, Techno (30 files each)
- **Speech Sentences**: 10 phonetically balanced Harvard Sentences
- **Fixed SNR Conditions**:
  - **$0\text{ dB}$ SNR**: Balanced conversational speech condition
  - **$-5\text{ dB}$ SNR**: Loud venue condition (music $3.16\times$ speech power)
  - **$-10\text{ dB}$ SNR**: High-noise festival condition (music $10\times$ speech power)
- **Headroom**: Master peak limited to $0.90$ ($-0.9\text{ dBFS}$) with zero clipping.
- **Audit Manifest**: Full ground-truth metadata in [`dataset/metadata/speech_overlay_manifest.json`](dataset/metadata/speech_overlay_manifest.json).

---

## Getting Started & Execution

### 1. Ingest Human Speech & Extract Stimuli
```bash
python3 scripts/extract_and_standardize_ius.py
python3 scripts/download_jazz_gtzan.py
python3 scripts/prepare_genre_test_stimuli.py
```

### 2. Run STFT Analysis & Filter Benchmark
```bash
matlab -batch "addpath('scripts'); stft_genre_analysis; design_and_compare_filters; exit;"
```

### 3. Generate Speech Overlay Dataset & 10s Snippets
```bash
python3 scripts/create_comprehensive_speech_overlays.py
python3 scripts/mix_isolated_snippets.py
```

---

## References

1. G. Tzanetakis and P. Cook, *"Musical genre classification of audio signals,"* IEEE Trans. Speech Audio Process., 2002.
2. P. Knees et al., *"Two data sets for tempo estimation and key detection in electronic dance music annotated from user corrections,"* in Proc. ISMIR, 2015.
3. IEEE Subcommittee on Subjective Measurements, *"IEEE Recommended Practice for Speech Quality Measurements,"* IEEE Trans. Audio Electroacoust., 1969.
4. J. R. Karl and D. B. Pisoni, *"Effects of stimulus variability on recall of spoken sentences: A first report,"* Res. Spoken Lang. Process., Indiana Univ. Bloomington, 1994.
5. C. H. Taal et al., *"An algorithm for intelligibility prediction of time-frequency weighted noisy speech,"* IEEE Trans. ASLP, 2011.
