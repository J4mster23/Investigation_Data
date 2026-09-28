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
                                            │ 08. Comparative Testing &     │
                                            │     Findings: Fixed vs. NLMS  │
                                            └───────────────┬───────────────┘
                                                            │
                                ┌───────────────────────────┴───────────────────────────┐
                                ▼                                                       ▼
                ┌───────────────────────────────┐                       ┌───────────────────────────────┐
                │ 09. Experimental Setup:       │                       │ 10. Partner Weekly Progress:  │
                │     Concert Sim & ESP32-S3 HW │                       │     Leaky NLMS & Robust VAD   │
                └───────────────┬───────────────┘                       └───────────────┬───────────────┘
                                │                                                       │
                                └───────────────────────────┬───────────────────────────┘
                                                            ▼
                                            ┌───────────────────────────────┐
                                            │ 11. Advanced Low-Latency      │
                                            │     Architectures on ESP32-S3 │
                                            └───────────────┬───────────────┘
                                                            │
                                                            ▼
                                            ┌───────────────────────────────┐
                                            │ 12. Concert Venue Room        │
                                            │     Acoustic Benchmark (ISM)  │
                                            └───────────────┬───────────────┘
                                                            │
                                                            ▼
                                            ┌───────────────────────────────┐
                                            │ 13. Google STT Intelligibility│
                                            │     Benchmark (ASR Lexicon)   │
                                            └───────────────┬───────────────┘
                                                            │
                                                            ▼
                                            ┌───────────────────────────────┐
                                            │ 14. Faster-Whisper vs Google  │
                                            │     Intelligibility Benchmark │
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
| [**Report 09**](09_experimental_setup_simulation_and_hardware.md) | **Experimental Setup: Concert Simulation & Hardware** | Multi-venue concert simulation models (Club, Arena, Festival), ESP32-S3 hardware wiring (Adafruit MEMS, PCM5102A, NJM4556AD), and 3-stage validation protocol. |
| [**Report 10**](10_partner_weekly_progress_leaky_nlms_and_vad.md) | **Partner Weekly Progress: Leaky NLMS & Robust VAD** | Resolution of the $+10\text{ dB}$ vocal self-cancellation hazard, Leaky NLMS ($\gamma=0.999$), dual-mic ZCR-gated Sigmoid VAD, and 1,500-run multi-noise benchmark. |
| [**Report 11**](11_advanced_low_latency_speech_enhancement_esp32.md) | **Advanced Low-Latency Architectures on ESP32-S3** | Ultra-high AOP front-ends, $<3.5\text{ ms}$ comb-filtering mitigation, RL-supervised Time-Domain GSC, and 4-phase implementation plan. |
| [**Report 12**](12_concert_venue_room_acoustics_and_enhancement_benchmark.md) | **Concert Venue Room Acoustic Benchmark (ISM)** | Image Source Method multi-path simulation of Nightclub, Arena, and Festival venues; STOI, PESQ, $\Delta\text{SNR}$, $\Delta\text{ASL}$ across 1,080 conditions. |
| [**Report 13**](13_google_speech_to_text_intelligibility_benchmark.md) | **Google Speech-to-Text Intelligibility Benchmark** | Commercial ASR evaluation of Harvard sentences before vs. after filtering; Word Recall % and WER % across room conditions and filter topologies. |
| [**Report 14**](14_faster_whisper_vs_google_stt_intelligibility_comparison.md) | **Faster-Whisper vs. Google STT Intelligibility Benchmark** | Comparative dual-ASR benchmark across 135 conditions resolving Google's binary VAD gate with continuous word-level probabilities and log-likelihoods. |

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

5. VOCAL CANCELLATION MITIGATION & ROBUST VAD (Report 10):
   - Speech Leakage Hazard: Standard NLMS collapsed from 0.995 to 0.913 STOI @ +10 dB SNR.
   - Dual-Mic Robust VAD:   Frame power ratio + ZCR shock gate + EMA + Sigmoid soft probability mask.
   - Dynamic Step Size:     μ_eff = μ · (1 - V_soft) freezes adaptation during active vocal frames.
   - Intelligibility Gain:  Soft-VAD restores STOI to 0.979 @ +10 dB and 0.980 @ +5 dB (+0.04 to +0.07 gain).
   - Soft vs. Hard VAD:     Soft sigmoid gating consistently outperforms binary hard thresholding by avoiding switching clicks.

6. CONCERT VENUE ROOM ACOUSTIC BENCHMARK (Report 12):
   - 3 Venue Archetypes:    Nightclub (RT60=0.7s), Arena (RT60=1.4s), Festival (RT60=0.2s).
   - 1,080 Simulation Grid: 20 talkers x 3 genres x 3 venues x 6 SNRs evaluated on STOI, PESQ, ΔSNR, and ΔASL.
   - Multi-Path Immunity:   Dual-mic Soft-VAD maintains vocal protection across all venues (STOI 0.963 @ +10 dB),
                            preventing the -6.48 dBFS vocal cancellation collapse suffered by unconstrained NLMS.
   - Severe Noise (SNR -15):Dual-Mic NLMS delivers +11.6 dB to +12.2 dB true physical noise attenuation across venues.
   - Perceptual Rejection:  Fixed FIR bandpass is rejected on PESQ grounds (depressed to 1.2-1.5 MOS) due to F0 loss.

7. COMMERCIAL ASR & GOOGLE STT MULTI-SENTENCE BENCHMARK (Report 13):
   - Extreme Noise (-15 dB SNR): Dual-Mic NLMS more than doubles Word Recall in Jazz (25.0% -> 57.1%) and triples it
                                in Techno (16.7% -> 57.7%), elevating ASR speech detection from 33% to 100% of sentences.
   - High Noise (-10 dB SNR):    Dual-Mic NLMS delivers 90.5% Word Recall in Jazz (WER 8.3%) and 81.0% in Techno,
                                compared to 0% for FIR bandpass which causes total speech detection collapse.
   - Flaw of Bandpass:          Amputating <300 Hz removes male F0 (125 Hz) and female F0 (219 Hz), causing neural ASR
                                to classify speech as synthetic noise (0% recall across sentences in Jazz -10 dB).
   - Vocal Cancellation Proof:   In Techno 0 dB, Baseline NLMS mutates "Glue the sheet..." to "where the sheet..."
                                due to speech leakage notches, while Soft-VAD Leaky NLMS achieves 100.0% pristine Word Recall.
8. CONTINUOUS ACOUSTIC CONFIDENCE & FASTER-WHISPER COMPARISON (Report 14):
   - Overcoming Binary VAD:     Google Cloud STT drops 100% of severely masked sentences in Rock (-10 and -15 dB)
                                as [NO_SPEECH_DETECTED]. Faster-Whisper provides forced decoding across 100% of trials,
                                revealing fine-grained Word Probabilities (0.41-0.49) and Logprobs (-0.90 to -1.11).
   - Dual-ASR Corroboration:    In Jazz -15 dB, both models prove Base NLMS restores speech: Google Word Recall leaps
                                from 25.0% to 57.2% (100% detection), and Faster-Whisper leaps from 9.5% to 54.2%
                                with Mean Word Probability surging from 0.301 to 0.543 and Logprob rising -1.24 to -0.81.
   - Universal Bandpass Loss:   Whisper confirms FIR Bandpass degrades Word Recall from 72.6% to 38.1% in Techno -10 dB,
                                with confidence dropping from 0.750 to 0.507 due to F0 amputation.
```
