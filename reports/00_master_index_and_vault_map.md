# Knowledge Vault: Speech Enhancement in High-Noise Environments
## Master Index & Architecture Map

* **Project**: Genre-Specific and Adaptive Filtering Approaches to Speech Enhancement in High-Noise Environments
* **Institution**: School of Electrical & Information Engineering, University of the Witwatersrand
* **Researchers**: Ryan Jammy & Raphael Alsfine
* **Target Hardware**: Espressif ESP32-S3 (Dual-core Xtensa LX7 @ 240 MHz, 32-bit hardware FPU)
* **Audio Specification**: $16\,000\text{ Hz}$, 16-bit mono linear PCM

---

### Navigation Map

This series of progress reports documents the end-to-end research, empirical findings, algorithm design, bug post-mortems, and embedded firmware implementation of this investigation:

```
                              ┌─────────────────────────────────────────────────────────┐
                              │ 00. Master Index & Knowledge Vault Map (This File)      │
                              └────────────────────────────┬────────────────────────────┘
                                                           │
        ┌──────────────────────────────────────────────────┴──────────────────────────────────────────────────┐
        ▼                                                  ▼                                                  ▼
┌───────────────────────────────┐ ┌───────────────────────────────────────────────┐ ┌────────────────────────────────────────────────┐
│ 01. Investigation Overview &  │ │ 02. Dataset Architecture & Acoustic           │ │ 03. STFT Spectral Analysis, Vocal Formants &   │
│     Problem Formulation       │ │     Divergence (GTZAN, GiantSteps, IUS)       │ │     Masking Mechanics                          │
└───────────────┬───────────────┘ └───────────────────────┬───────────────────────┘ └────────────────────────┬───────────────────────┘
                │                                         │                                                  │
                └─────────────────────────────────────────┼──────────────────────────────────────────────────┘
                                                          ▼
                                          ┌───────────────────────────────┐
                                          │ 04. Digital Filter Design:    │
                                          │     FIR, IIR & Notch Cascades │
                                          └───────────────┬───────────────┘
                                                          │
                        ┌─────────────────────────────────┴─────────────────────────────────┐
                        ▼                                                                   ▼
        ┌───────────────────────────────┐                                   ┌───────────────────────────────────────────────┐
        │ 05. Controlled Speech Overlay │                                   │ 06. Objective Intelligibility Benchmarks,     │
        │     Synthesis (ITU-T P.56)    │                                   │     Algorithm Audits & Post-Mortems           │
        └───────────────┬───────────────┘                                   └───────────────────────┬───────────────────────┘
                        │                                                                           │
                         └─────────────────────────────────┬─────────────────────────────────────────┘
                                                           ▼
                                           ┌───────────────────────────────┐
                                           │ 07. Embedded Firmware &       │
                                           │     ESP32-S3 Hardware Engine  │
                                           └───────────────┬───────────────┘
                                                           │
                                                           ▼
                                           ┌───────────────────────────────┐
                                           │ 08. Comparative Testing &     │
                                           │     Findings: Fixed vs. NLMS  │
                                           └───────────────────────────────┘
```

---

### Module Summary

| Report | Document Title | Primary Focus & Deliverables |
| :--- | :--- | :--- |
| [**Report 01**](01_executive_summary_and_problem_formulation.md) | **Investigation Overview & Problem Formulation** | Psychoacoustics of acoustic masking, upward spread of masking, project evolution, and core hypotheses. |
| [**Report 02**](02_dataset_architecture_and_acoustic_divergence.md) | **Dataset Architecture & Acoustic Divergence** | The Acoustic Triad (Jazz, Rock, Techno), GTZAN/GiantSteps curation, Country-to-Jazz transition rationale, and IUS Human Speech corpus standardization. |
| [**Report 03**](03_stft_spectral_analysis_and_masking_mechanics.md) | **STFT Spectral Analysis & Masking Mechanics** | STFT formulation, subband energy distributions across 150 tracks, active vocal profiling, pitch fundamental ($F_0$) & formant extraction, and Spectral SNR ($\text{SSNR}$). |
| [**Report 04**](04_filter_design_methodology_and_architectures.md) | **Digital Filter Design Methodologies & Topologies** | Rejection of broadband bandpass filtering, 128-tap FIR design, 8th-order Chebyshev II IIR SOS biquads, and Parametric Notch cascades (RBJ Audio EQ Cookbook). |
| [**Report 05**](05_controlled_overlay_synthesis_and_mixing.md) | **Audio Overlay Mixing Pipeline & Calibrated Test Stimuli** | ITU-T P.56 active speech power leveling, fixed SNR calibration ($0, -5, -10\text{ dB}$), headroom normalization, 90-file manifest, and 10s isolated/combined test snippets. |
| [**Report 06**](06_evaluation_benchmarks_and_algorithm_audit.md) | **Objective Intelligibility Benchmarks & Algorithm Audits** | STOI metric, physical $\Delta\text{SNR}$ formulation, root-cause post-mortem of the +32 dB FIR overshoot bug and phase-subtraction error, plus pre/post audio audit catalog. |
| [**Report 07**](07_embedded_firmware_and_hardware_deployment.md) | **Embedded Firmware Architecture & ESP32-S3 Implementation** | Transposed Direct Form II biquad engine, computational complexity analysis (MFLOPS/RAM), cycle counts, DMA buffer latency, and C header implementation. |
| [**Report 08**](08_comparative_testing_and_findings_nlms.md) | **Comparative Testing & Findings: Fixed vs. Adaptive NLMS** | Cross-benchmark across 6 SNRs, 3 genres, and genders comparing FIR, IIR, Notch, Dual-Mic NLMS, and Hybrid Notch+NLMS; plus 5 acoustic stress scenarios. |

---

### Core Quantitative Findings at a Glance

```
1. VOCAL PITCH PRESERVATION:
   - Male Human Speech (IUS):   F0 = 125.0 Hz | 15.66% energy below 250 Hz
   - Female Human Speech (IUS): F0 = 218.8 Hz | 26.09% energy below 250 Hz
   - Broadband Bandpass (300-3400 Hz) destroys 15-26% of vocal power, amputating F0.
   - Parametric Notch Cascades preserve 98.6% of vocal power and maintain 100% of F0.

2. SPEECH INTELLIGIBILITY (STOI @ -10 dB SNR):
   - Traditional Bandpass: Degrades STOI by -0.015 to -0.028 across all genres (envelope distortion).
   - Parametric Notch:     Matches or exceeds unprocessed speech (0.910 Techno, 0.841 Rock, 0.810 Jazz).
   - Dual-Microphone NLMS: Achieves 0.941 to 0.963 STOI across all genres (+0.09 to +0.16 STOI gain).

3. EXTREME HIGH-NOISE ATTENUATION (SNR @ -15 dB):
   - Dual-Microphone NLMS: Delivers +16.0 dB to +18.4 dB true physical noise reduction.
   - Boosts STOI from ~0.71-0.80 up to 0.90-0.93 across Jazz, Rock, and Techno.

4. EMBEDDED EFFICIENCY (ESP32-S3 @ 16 kHz):
   - 128-Tap FIR:       128 MACs/sample | 4.11 MFLOPS | 4.00 ms constant group delay (2.07% CPU)
   - 8th-Order IIR SOS: 20 ops/sample   | 0.32 MFLOPS | 1.34 ms passband delay (0.19% CPU)
   - Parametric Notch:  5-10 ops/sample | 0.08-0.16 MFLOPS | <0.15 ms vocal latency (0.05-0.09% CPU)
   - Dual-Mic NLMS:     515 ops/sample  | 8.24 MFLOPS | 4.06 ms DMA roundtrip latency (4.13% CPU)
```
