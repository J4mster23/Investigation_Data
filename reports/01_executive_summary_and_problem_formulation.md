# Progress Report 01: Investigation Overview, Problem Formulation & Theoretical Foundations

* **Module**: `01_executive_summary_and_problem_formulation`
* **Authors**: Ryan Jammy & Raphael Alsfine
* **Supervising Institution**: School of Electrical & Information Engineering, University of the Witwatersrand
* **Date**: September 2026

---

## 1. Executive Summary

This investigation addresses the degradation of spoken voice intelligibility and communication clarity in high-sound-pressure-level (SPL) entertainment, musical, and hospitality environments (typically $90 - 110\text{ dBA}$). In such soundscapes, human voice communication is severely compromised by acoustic background music. 

Historically, telecommunication systems applied generic **bandpass filtering** (e.g., standard telephone telephony bandwidth $300 - 3400\text{ Hz}$) to remove sub-audible mechanical rumble and high-frequency noise. However, this investigation demonstrates that generic bandpass filtering fails catastrophically in musical environments for two distinct reasons:
1. **Destruction of Vocal Quality and Intelligibility**: Telecommunication bandpass filtering amputates the fundamental pitch ($F_0$) of human speakers ($100 - 150\text{ Hz}$ for males; $180 - 250\text{ Hz}$ for females), discarding $15 - 26\%$ of total vocal energy and causing voices to sound thin, hollow, and robotic.
2. **In-Band Acoustic Transparency**: Genres with significant mid-range instrumentation (such as Jazz, with $47\%$ of its spectral energy inside $300 - 3400\text{ Hz}$) pass completely unattenuated through static bandpass filters.

To solve this dilemma, this research develops **genre-specific and adaptive parametric digital filter topologies** deployed on an embedded **ESP32-S3** microcontroller. By identifying the acoustic resonance fingerprints of distinct genres (**Techno**, **Rock**, and **Jazz**), we design **parametric notch filter cascades** that surgically attenuate dominant musical resonance peaks (such as electronic kick drums at $62.5\text{ Hz}$ and $125\text{ Hz}$, or acoustic upright bass at $78.1\text{ Hz}$) while preserving the entire speech spectrum ($80 - 8000\text{ Hz}$), maintaining natural human voice quality and maximizing Short-Time Objective Intelligibility (STOI).

---

## 2. Psychoacoustics & The Acoustic Masking Problem

### 2.1 Auditory Physiology and the Basilar Membrane
In the human cochlea, incoming sound waves create traveling waves along the basilar membrane. The basilar membrane is tonotopically organized: high frequencies produce peak displacement near the stiff, narrow base (oval window), whereas low frequencies travel along the entire length to produce peak displacement near the flexible, wide apex (helicotrema).

```
               HIGH FREQUENCIES                       LOW FREQUENCIES
              Base (Stiff/Narrow)                    Apex (Wide/Compliant)
               ┌────────────────────────────────────────────────────────┐
 Oval Window ──►  8000 Hz      4000 Hz      1000 Hz      250 Hz   60 Hz │
               └────────────────────────────────────────────────────────┘
```

Because low-frequency traveling waves must pass through the basal and middle regions of the cochlea before reaching the apex, high-amplitude low-frequency acoustic energy excites nerve fibers across a broad spatial extent of the basilar membrane.

### 2.2 The Upward Spread of Masking
This physiological asymmetry gives rise to the **upward spread of masking**: an intense low-frequency sound (such as a 60–120 Hz kick drum or electric bass note at 100 dB SPL) exerts substantial masking on higher-frequency sounds (such as speech vowel formants at 500–2500 Hz), whereas high-frequency sounds exert minimal downward masking on low-frequency sounds.

Mathematically, the excitation pattern $E(b)$ in the auditory system for a masker at Bark index $b_m$ can be described by an asymmetric filter slope:
$$S(b - b_m) = \begin{cases} +27\text{ dB/Bark}, & b < b_m \quad \text{(downward masking slope)} \\ -(24 + 0.23 \cdot L_m)\text{ dB/Bark}, & b > b_m \quad \text{(upward masking slope)} \end{cases}$$
where $L_m$ is the masker sound pressure level in dB. As sound pressure $L_m$ rises in a concert or club environment ($L_m \ge 95\text{ dB}$), the upward masking slope flattens substantially (dropping to $\approx -12\text{ dB/Bark}$), causing low-frequency musical bass to drown out conversational speech formants up to several octaves above the bass frequency.

### 2.3 The Critical Band Concept & The Cocktail Party Problem
Human hearing groups acoustic energy into **critical bands** (approximated by the Bark scale or Equivalent Rectangular Bandwidth, ERB). Speech intelligibility depends on the Signal-to-Noise Ratio (SNR) within individual critical bands spanning the first three vocal formants ($F_1: 300-800\text{ Hz}$, $F_2: 1000-2500\text{ Hz}$, $F_3: 2500-3500\text{ Hz}$). When intense music energy floods these bands, the auditory system fails to resolve formant trajectories, causing phoneme confusion and total communication collapse.

---

## 3. Core Research Questions & Hypotheses

This investigation evaluates four foundational hypotheses:

* **Hypothesis 1 (Genre Divergence)**: Musical genres exhibit distinct, non-overlapping acoustic power distributions. Electronic dance music (Techno) concentrates power in localized low-frequency sub-bass transients ($<80\text{ Hz}$), amplified Rock concentrates energy in distorted mid-bass ($80-250\text{ Hz}$) and cymbal sizzle ($>4\text{ kHz}$), and acoustic polyphonic music (Jazz) overlaps directly with human speech formants ($300-3400\text{ Hz}$).
* **Hypothesis 2 (Failure of Telephony Bandpass)**: Applying a static 8th-order bandpass filter ($300 - 3400\text{ Hz}$) to human speech removes $>15\%$ of male vocal power and $>25\%$ of female vocal power, amputating $F_0$ and significantly reducing objective speech intelligibility (STOI) relative to clean speech.
* **Hypothesis 3 (Superiority of Parametric Notch Topologies)**: Cascaded high-$Q$ Second-Order Section (SOS) parametric notch filters tuned precisely to genre resonance peaks achieve $>30\text{ dB}$ narrow-band noise rejection while preserving $>98\%$ of human vocal energy, maintaining a near-unity STOI score ($>0.85$ at $-10\text{ dB}$ input SNR) with sub-millisecond group delay ($<0.15\text{ ms}$).
* **Hypothesis 4 (Embedded Feasibility)**: Cascaded biquad notch filters implemented in Transposed Direct Form II on an ESP32-S3 microcontroller require $<0.2\text{ MFLOPS}$ of computation and $<100\text{ bytes}$ of memory, achieving a $15 - 25\times$ computational speedup over 128-tap FIR filtering while eliminating phase-induced latency.

---

## 4. Project Roadmap & Lifecycle Evolution

The project progressed through three distinct developmental phases:

```
┌──────────────────────────────────┐
│ PHASE 1: Baseline Architecture   │
│ - 50 Country, 50 Rock, 50 Techno │
│ - Synthetic TTS speech (macOS)   │
│ - 128-Tap FIR vs 8th-Order IIR   │
└────────────────┬─────────────────┘
                 │ Empirical Finding: Rock and Country share identical spectra (~60% low bass).
                 ▼
┌──────────────────────────────────┐
│ PHASE 2: The Acoustic Triad      │
│ - Swapped Country for Jazz       │
│ - 150 Tracks (Jazz, Rock, Techno)│
│ - STFT analysis & overlays       │
│ - ITU-T P.56 calibrated mixing   │
└────────────────┬─────────────────┘
                 │ User Direction: Replace robotic TTS with diverse human speech; focus on notch filters.
                 ▼
┌──────────────────────────────────┐
│ PHASE 3: Human Vocal Profiling & │
│          Parametric Notch Engine │
│ - Indiana University IUS Corpus  │
│ - Gender stratification (M vs F) │
│ - Parametric Notch Biquads       │
│ - Full STOI & SNR Benchmark      │
│ - FIR Remez bug post-mortem      │
│ - ESP32-S3 firmware headers      │
└──────────────────────────────────┘
```

---

## 5. Architectural & Technical Scope

* **Sampling Rate ($f_s$)**: Standardized at $16\,000\text{ Hz}$ ($16\text{ kHz}$) linear PCM mono, matching the standard sampling rate of embedded I2S MEMS microphones (e.g., INMP441) and telecommunication DSP pipelines.
* **Nyquist Frequency**: $8\,000\text{ Hz}$.
* **Bit Depth**: 16-bit signed integer (`LEI16`), dynamic range $\approx 96.3\text{ dB}$.
* **Target Hardware Profile**: Espressif ESP32-S3, dual-core Xtensa LX7 running at 240 MHz, 512 KB internal SRAM, single-precision 32-bit hardware FPU.
* **Algorithmic Scope**: Short-Time Fourier Transform (STFT), Parks-McClellan (`firpm`), Windowed-Sinc (`fir1`), Chebyshev Type II IIR Biquad Cascades (`cheby2`), Robert Bristow-Johnson (RBJ) Audio EQ Cookbook Parametric Notches, Short-Time Objective Intelligibility (STOI), and ITU-T P.56 Active Speech Leveling.
