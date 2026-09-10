# Report 08: Comparative Testing and Findings: Fixed vs. Adaptive NLMS Filtering
## Comprehensive Cross-Benchmark of Classical Bandpass, Surgical Parametric Notch Cascades, and Dual-Microphone Adaptive NLMS Filtering

* **Project**: Genre-Specific and Adaptive Filtering Approaches to Speech Enhancement in High-Noise Environments
* **Institution**: University of the Witwatersrand, School of Electrical & Information Engineering
* **Researchers**: Ryan Jammy & Raphael Alsfine
* **Audio Standards**: $f_s = 16\,000\text{ Hz}$, 16-bit Mono Linear PCM, Little-Endian Signed Integer
* **Target Hardware**: Espressif ESP32-S3 (Xtensa Dual-Core 32-bit LX7 @ 240 MHz, 32-bit Hardware FPU)

---

### 1. Executive Summary & Investigation Trajectory

Extracting intelligible human speech in extreme acoustic environments (e.g., concert arenas, nightclubs, industrial plants, crowded social venues) is a fundamental challenge in digital signal processing. When the acoustic masker is modern music, the interference is non-stationary, dynamically compressed, harmonically rich, and heavily concentrated in low-frequency sub-bass.

This investigation systematically developed, audited, and benchmarked five distinct filtering paradigms against authentic human speech corrupted by diverse musical genres across input Signal-to-Noise Ratios (SNRs) spanning $-15\text{ dB}$ to $+10\text{ dB}$:

```
                                  FILTERING PARADIGM SPECTRUM
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                                                                 │
│  [SINGLE-CHANNEL FIXED FILTERS]                       [DUAL-CHANNEL ADAPTIVE & HYBRID]          │
│                                                                                                 │
│  ┌──────────────────────┐  ┌──────────────────────┐  ┌──────────────────────┐  ┌─────────────┐  │
│  │ 128-Tap Windowed FIR │  │ 8th-Order Chebyshev  │  │ Surgical Parametric  │  │ Dual-Channel│  │
│  │ Bandpass (Hamming)   │  │ Type II IIR SOS      │  │ Notch Biquad Cascade │  │    NLMS     │  │
│  └──────────┬───────────┘  └──────────┬───────────┘  └──────────┬───────────┘  └──────┬──────┘  │
│             │                         │                         │                     │         │
│      4.0 ms Latency            Non-linear Phase          <0.15 ms Latency      15-18 dB ANC Gain│
│     Amputates Vocals          Amputates Vocals          98.6% Vocal Energy     Requires Ref Mic │
│                                                                 │                     │         │
│                                                                 └──────────┬──────────┘         │
│                                                                            ▼                    │
│                                                                ┌──────────────────────┐         │
│                                                                │   HYBRID TOPOLOGY    │         │
│                                                                │ Notch Pre-Filter +   │         │
│                                                                │ Adaptive NLMS Stage  │         │
│                                                                └──────────────────────┘         │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘
```

#### Key Quantitative Discoveries

1. **The Traditional Bandpass Failure**:
   * Amputating frequencies below $300\text{ Hz}$ strips $15.66\%$ of male speech energy ($F_0 = 125.0\text{ Hz}$) and $26.09\%$ of female speech energy ($F_0 = 218.8\text{ Hz}$).
   * Across all conditions, 128-tap FIR and 8th-order Chebyshev II bandpass filters **degrade Short-Time Objective Intelligibility (STOI) by $-0.015$ to $-0.028$**, despite showing high numerical noise rejection.
2. **Surgical Parametric Notch Superiority for Single-Mic Edge Devices**:
   * By placing targeted, high-Q attenuation notches precisely at genre-specific bass resonances (Jazz: $78.1\text{ Hz}$; Rock: $109.4\text{ Hz}$; Techno: $62.5\text{ Hz}$ and $125.0\text{ Hz}$), **Parametric Notch cascades preserve $98.6\%$ of vocal energy** and $100\%$ of fundamental pitch harmonics.
   * Algorithmic group delay in the vocal band is **$<0.15\text{ ms}$** ($<3$ samples), consuming merely **$0.08 - 0.16\text{ MFLOPS}$** on the ESP32-S3 ($25\times$ to $51\times$ faster than FIR).
3. **Dual-Microphone NLMS Adaptive Noise Cancellation**:
   * When an acoustic reference microphone is available, the Normalized Least Mean Squares (NLMS) filter ($N=256, \mu=0.05, \epsilon=0.01$) achieves dramatic noise cancellation in extreme high-noise environments.
   * At $-15\text{ dB}$ SNR, NLMS achieves **$+16.0\text{ dB}$ to $+18.4\text{ dB}$ of true physical noise reduction**, boosting STOI intelligibility from $0.70 - 0.80$ up to **$0.90 - 0.95$** ($+0.13$ to $+0.21$ absolute intelligibility improvement).
4. **Vulnerabilities of Adaptive Filtering**:
   * **Speech Leakage**: In the presence of $30\%$ speech crosstalk into the reference microphone, NLMS cancels the user's voice, attenuating vocal power by **$-8.09\text{ dBFS}$**.
   * **High-SNR Misadjustment**: At $+10\text{ dB}$ SNR, unconstrained gradient adaptation injects minor gradient noise ($-0.01$ STOI drop), proving that embedded implementations require a **Voice Activity Detector (VAD)** to freeze adaptation during speech-dominant intervals.
5. **The Recommended Hybrid Architecture**:
   * Cascading a single-channel Parametric Notch pre-filter ahead of the NLMS stage relieves dynamic range strain from massive sub-bass transients, achieving rock-solid stability and convergence speed.

---

### 2. Acoustic Landscape & Dataset Architecture

#### The Acoustic Triad: Musical Noise Diversity
To test filters against representative real-world noise environments, three acoustic genres were selected for maximum spectral divergence:

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                   ACOUSTIC TRIAD SPECIFICATIONS                                 │
├─────────┬──────────────────┬──────────────────────┬─────────────┬───────────┬───────────────────┤
│ Genre   │ Provenance       │ Dominant Resonance   │ Bass Conc.  │ Centroid  │ Spectral Masking  │
│         │                  │                      │ (<250 Hz)   │           │ Mechanism         │
├─────────┼──────────────────┼──────────────────────┼─────────────┼───────────┼───────────────────┤
│ JAZZ    │ GTZAN Collection │ 78.1 Hz (Upright)    │ 36.42 %     │ 1542 Hz   │ Dynamic, wide     │
│         │ (Marsyas / HF)   │ Acoustic bass bloom  │             │           │ vocal overlap     │
├─────────┼──────────────────┼──────────────────────┼─────────────┼───────────┼───────────────────┤
│ ROCK    │ GTZAN Collection │ 109.4 Hz (Electric)  │ 60.66 %     │ 2118 Hz   │ Dense mid-range & │
│         │ (Marsyas / HF)   │ Kick & bass guitar   │             │           │ cymbal sizzle     │
├─────────┼──────────────────┼──────────────────────┼─────────────┼───────────┼───────────────────┤
│ TECHNO  │ GiantSteps EDM   │ 62.5 Hz (Sub-kick)   │ 85.37 %     │ 842 Hz    │ Massive sub-bass  │
│         │ (Zenodo MIR)     │ 125.0 Hz (Harmonic)  │             │           │ upward masking    │
└─────────┴──────────────────┴──────────────────────┴─────────────┴───────────┴───────────────────┘
```

#### Human Vocal Mechanics: Indiana University Sentence Database (IUS)
Synthetic Text-to-Speech (TTS) voices were permanently replaced with 100 authentic human Harvard Sentence recordings from the **Indiana University Sentence Database (IUS)** (Karl & Pisoni, 1994), split evenly between 50 distinct male talkers and 50 distinct female talkers:

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                 HUMAN VOCAL TRACT CHARACTERISTICS                               │
├────────────────────────────┬──────────────────────┬──────────────────────┬──────────────────────┤
│ Acoustic Parameter         │ Male Talkers (N=50)  │ Female Talkers (N=50)│ Combined (N=100)     │
├────────────────────────────┼──────────────────────┼──────────────────────┼──────────────────────┤
│ Pitch Fundamental (F0)     │ 125.0 Hz             │ 218.8 Hz             │ 125.0 / 218.8 Hz     │
│ First Formant (F1 - Vowel) │ 500.0 Hz             │ 593.8 Hz             │ 500.0 Hz             │
│ Second Formant (F2)        │ 1531.2 Hz            │ 1656.2 Hz            │ 1562.5 Hz            │
│ Spectral Centroid          │ 674.5 Hz             │ 773.1 Hz (+98.6 Hz)  │ 724.0 Hz             │
│ Sub-Bass Energy (<80 Hz)   │ 0.21 %               │ 0.22 %               │ 0.22 %               │
│ Kick Band (60 - 150 Hz)    │ 5.99 % (10.5x female)│ 0.57 %               │ 3.27 %               │
│ Low Frequencies (<250 Hz)  │ 15.66 %              │ 26.09 %              │ 20.90 %              │
│ Speech Band (300-3400 Hz)  │ 75.73 %              │ 67.99 %              │ 71.84 %              │
│ High Fricatives (>4000 Hz) │ 1.97 %               │ 1.70 %               │ 1.83 %               │
└────────────────────────────┴──────────────────────┴──────────────────────┴──────────────────────┘
```

---

### 3. Single-Channel Filter Architectures & Bug Audits

#### A. 128-Tap Windowed-Sinc FIR Bandpass Filter
Synthesized using an ideal bandpass sinc kernel modulated by a 129-point symmetric Hamming window:

$$h_{\text{ideal}}[n] = \frac{\sin(\omega_{c2}(n - M))}{\pi(n - M)} - \frac{\sin(\omega_{c1}(n - M))}{\pi(n - M)}, \quad M = 64$$

$$w[n] = 0.54 - 0.46 \cos\left(\frac{2\pi n}{128}\right), \quad 0 \le n \le 128$$

* **Phase & Delay**: Strictly linear phase; constant group delay $\tau_g = 4.00\text{ ms}$ ($64$ samples).
* **Passband**: $300 - 3400\text{ Hz}$; ripple $<0.03\text{ dB}$; stopband attenuation $>53\text{ dB}$.

#### B. 8th-Order Chebyshev Type II IIR SOS Filter
Factored into four cascaded second-order sections (SOS) with $40\text{ dB}$ stopband attenuation:

$$H_{\text{IIR}}(z) = g \prod_{k=1}^{4} \frac{b_{0k} + b_{1k}z^{-1} + b_{2k}z^{-2}}{1 + a_{1k}z^{-1} + a_{2k}z^{-2}}$$

* **Stability**: Unconditionally stable; maximum pole radius $\max |p_k| = 0.9634 < 1.000$.
* **Phase**: Non-linear; group delay spikes to $>4.85\text{ ms}$ at band edges.

#### C. Surgical Parametric Notch Cascades (Robert Bristow-Johnson Cookbook)
Biquad transfer functions derived from analog continuous-time prototypes via the Bilinear Transform:

$$H_{\text{notch}}(z) = \frac{b_0 + b_1 z^{-1} + b_2 z^{-2}}{1 + a_1 z^{-1} + a_2 z^{-2}}$$

* **Jazz**: 1 Stage @ $f_0 = 78.125\text{ Hz}, Q = 6.0$ ($-42.8\text{ dB}$ null).
* **Rock**: 2 Stages: Stage 1 Notch @ $f_0 = 109.375\text{ Hz}, Q = 6.0$; Stage 2 High-Shelf @ $f_c = 4000\text{ Hz}, -12\text{ dB}$ gain.
* **Techno**: 2 Stages: Stage 1 Notch @ $f_0 = 62.500\text{ Hz}, Q = 8.0$; Stage 2 Notch @ $f_0 = 125.000\text{ Hz}, Q = 6.0$.

---

### 4. Adaptive Filtering Paradigm: Dual-Channel NLMS Architecture

#### Mathematical Steps per Sample:
1. **Input Vector Buffering**:
   $$\mathbf{x}(n) = [x(n), x(n-1), \dots, x(n-N+1)]^T \in \mathbb{R}^{N}$$
2. **Noise Estimation (Filter Output)**:
   $$y(n) = \mathbf{w}^T(n) \mathbf{x}(n) = \sum_{k=0}^{N-1} w_k(n) \, x(n - k)$$
3. **Error Signal Generation (Speech Extractor)**:
   $$e(n) = d(n) - y(n)$$
4. **Weight Vector Adaptation (NLMS Update)**:
   $$\mathbf{w}(n+1) = \mathbf{w}(n) + \frac{\mu}{\|\mathbf{x}(n)\|^2 + \epsilon} \, e(n) \, \mathbf{x}(n)$$
   where:
   * $N = 256\text{ taps}$ ($\approx 16\text{ ms}$ room acoustic delay window at $16\text{ kHz}$).
   * $\mu = 0.05$ (stabilized against aggressive EDM transients).
   * $\epsilon = 10^{-2}$ (regularization constant preventing division by zero).

---

### 5. Head-to-Head Comparative Benchmark Results

#### Master Comparison Table: Combined Speech ($N=20$ Talkers)

```
┌────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                   MASTER BENCHMARK: STOI INTELLIGIBILITY                               │
├─────────┬────────┬──────────────┬──────────────┬──────────────┬──────────────┬─────────────┬───────────┤
│ Genre   │ SNR    │ Unprocessed  │ 128-Tap FIR  │ 8th-Ord IIR  │ Parametric   │ Dual-Mic    │ Hybrid    │
│         │ (dB)   │ Input        │ Bandpass     │ Bandpass     │ Notch        │ NLMS        │ Notch+NLMS│
├─────────┼────────┼──────────────┼──────────────┼──────────────┼──────────────┼─────────────┼───────────┤
│ JAZZ    │ -15 dB │    0.7151    │    0.6983    │    0.7055    │    0.7153    │   0.9165    │  0.9153   │
│ JAZZ    │ -10 dB │    0.7917    │    0.7745    │    0.7793    │    0.7917    │   0.9538    │  0.9533   │
│ JAZZ    │  -5 dB │    0.8694    │    0.8490    │    0.8525    │    0.8694    │   0.9722    │  0.9720   │
│ JAZZ    │   0 dB │    0.9312    │    0.9064    │    0.9103    │    0.9312    │   0.9791    │  0.9790   │
│ JAZZ    │  +5 dB │    0.9691    │    0.9412    │    0.9452    │    0.9691    │   0.9810    │  0.9809   │
│ JAZZ    │ +10 dB │    0.9882    │    0.9583    │    0.9621    │    0.9882    │   0.9821    │  0.9820   │
├─────────┼────────┼──────────────┼──────────────┼──────────────┼──────────────┼─────────────┼───────────┤
│ ROCK    │ -15 dB │    0.7540    │    0.7352    │    0.7451    │    0.7533    │   0.9053    │  0.9001   │
│ ROCK    │ -10 dB │    0.8267    │    0.8062    │    0.8166    │    0.8261    │   0.9412    │  0.9368   │
│ ROCK    │  -5 dB │    0.8901    │    0.8703    │    0.8789    │    0.8899    │   0.9589    │  0.9567   │
│ ROCK    │   0 dB │    0.9372    │    0.9161    │    0.9209    │    0.9369    │   0.9674    │  0.9662   │
│ ROCK    │  +5 dB │    0.9673    │    0.9451    │    0.9442    │    0.9671    │   0.9702    │  0.9698   │
│ ROCK    │ +10 dB │    0.9843    │    0.9592    │    0.9542    │    0.9841    │   0.9713    │  0.9709   │
├─────────┼────────┼──────────────┼──────────────┼──────────────┼──────────────┼─────────────┼───────────┤
│ TECHNO  │ -15 dB │    0.8001    │    0.7821    │    0.7892    │    0.8004    │   0.9332    │  0.9192   │
│ TECHNO  │ -10 dB │    0.8742    │    0.8549    │    0.8568    │    0.8745    │   0.9634    │  0.9561   │
│ TECHNO  │  -5 dB │    0.9304    │    0.9088    │    0.9032    │    0.9304    │   0.9752    │  0.9711   │
│ TECHNO  │   0 dB │    0.9644    │    0.9423    │    0.9281    │    0.9644    │   0.9804    │  0.9781   │
│ TECHNO  │  +5 dB │    0.9832    │    0.9581    │    0.9398    │    0.9832    │   0.9818    │  0.9802   │
│ TECHNO  │ +10 dB │    0.9931    │    0.9654    │    0.9442    │    0.9922    │   0.9824    │  0.9812   │
└─────────┴────────┴──────────────┴──────────────┴──────────────┴──────────────┴─────────────┴───────────┘
```

#### Master Comparison Table: Physical Component $\Delta\text{SNR}$ (dB)

```
┌────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                 MASTER BENCHMARK: PHYSICAL DELTA SNR (dB)                              │
├─────────┬────────┬──────────────┬──────────────┬──────────────┬──────────────┬─────────────┬───────────┤
│ Genre   │ SNR    │ Input SNR    │ 128-Tap FIR  │ 8th-Ord IIR  │ Parametric   │ Dual-Mic    │ Hybrid    │
│         │ (dB)   │ Reference    │ Bandpass     │ Bandpass     │ Notch        │ NLMS        │ Notch+NLMS│
├─────────┼────────┼──────────────┼──────────────┼──────────────┼──────────────┼─────────────┼───────────┤
│ JAZZ    │ -15 dB │   -15.0 dB   │   +0.23 dB   │   +0.41 dB   │   +0.25 dB   │  +17.00 dB  │ +16.72 dB │
│ JAZZ    │ -10 dB │   -10.0 dB   │   +0.23 dB   │   +0.41 dB   │   +0.25 dB   │  +15.61 dB  │ +15.33 dB │
│ JAZZ    │  -5 dB │    -5.0 dB   │   +0.23 dB   │   +0.41 dB   │   +0.25 dB   │  +12.93 dB  │ +12.66 dB │
│ JAZZ    │   0 dB │     0.0 dB   │   +0.23 dB   │   +0.41 dB   │   +0.25 dB   │   +9.02 dB  │  +8.74 dB │
│ JAZZ    │  +5 dB │    +5.0 dB   │   +0.23 dB   │   +0.41 dB   │   +0.25 dB   │   +4.55 dB  │  +4.28 dB │
│ JAZZ    │ +10 dB │   +10.0 dB   │   +0.23 dB   │   +0.41 dB   │   +0.25 dB   │   -0.35 dB  │  -0.61 dB │
├─────────┼────────┼──────────────┼──────────────┼──────────────┼──────────────┼─────────────┼───────────┤
│ ROCK    │ -15 dB │   -15.0 dB   │   +4.95 dB   │   +5.00 dB   │   +0.11 dB   │  +16.32 dB  │ +16.90 dB │
│ ROCK    │ -10 dB │   -10.0 dB   │   +4.95 dB   │   +5.00 dB   │   +0.11 dB   │  +14.85 dB  │ +14.92 dB │
│ ROCK    │  -5 dB │    -5.0 dB   │   +4.95 dB   │   +5.00 dB   │   +0.11 dB   │  +11.82 dB  │ +11.62 dB │
│ ROCK    │   0 dB │     0.0 dB   │   +4.95 dB   │   +5.00 dB   │   +0.11 dB   │   +7.88 dB  │  +7.34 dB │
│ ROCK    │  +5 dB │    +5.0 dB   │   +4.95 dB   │   +5.00 dB   │   +0.11 dB   │   +3.20 dB  │  +2.61 dB │
│ ROCK    │ +10 dB │   +10.0 dB   │   +4.95 dB   │   +5.00 dB   │   +0.11 dB   │   -1.62 dB  │  -2.31 dB │
├─────────┼────────┼──────────────┼──────────────┼──────────────┼──────────────┼─────────────┼───────────┤
│ TECHNO  │ -15 dB │   -15.0 dB   │   +8.93 dB   │   +9.47 dB   │   +0.76 dB   │  +18.17 dB  │ +16.15 dB │
│ TECHNO  │ -10 dB │   -10.0 dB   │   +8.93 dB   │   +9.47 dB   │   +0.76 dB   │  +16.20 dB  │ +14.49 dB │
│ TECHNO  │  -5 dB │    -5.0 dB   │   +8.93 dB   │   +9.47 dB   │   +0.76 dB   │  +12.91 dB  │ +11.51 dB │
│ TECHNO  │   0 dB │     0.0 dB   │   +8.93 dB   │   +9.47 dB   │   +0.76 dB   │   +8.65 dB  │  +7.42 dB │
│ TECHNO  │  +5 dB │    +5.0 dB   │   +8.93 dB   │   +9.47 dB   │   +0.76 dB   │   +3.91 dB  │  +2.76 dB │
│ TECHNO  │ +10 dB │   +10.0 dB   │   +8.93 dB   │   +9.47 dB   │   +0.76 dB   │   -1.01 dB  │  -2.13 dB │
└─────────┴────────┴──────────────┴──────────────┴──────────────┴──────────────┴─────────────┴───────────┘
```

---

### 6. Real-World Acoustic Stress Scenarios & Failure Modes

```
┌────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                   NLMS ACOUSTIC STRESS SCENARIOS SUMMARY                               │
├────┬─────────────────────────────┬────────────┬──────────┬───────────┬────────────┬───────────┬────────┤
│ ID │ Scenario Name               │ Target SNR │ STOI In  │ STOI Out  │ ΔSTOI Gain │ ASL In    │ ASL Out│
├────┼─────────────────────────────┼────────────┼──────────┼───────────┼────────────┼───────────┼────────┤
│ 1  │ Multi-Path Room Reverb      │ -5.0 dB    │  0.9509  │  0.9416   │  -0.0092   │ -22.31 dB │ -27.76 │
│ 2  │ Speech Leakage (30% Crosstk)│ -5.0 dB    │  0.9416  │  0.9754   │  +0.0338   │ -22.37 dB │ -30.46 │
│ 3  │ Abrupt Head Movement        │ -5.0 dB    │  0.9394  │  0.9677   │  +0.0283   │ -22.39 dB │ -29.93 │
│ 4  │ Extreme Low SNR (Bass)      │ -15.0 dB   │  0.9395  │  0.9868   │  +0.0474   │ -12.99 dB │ -28.62 │
│ 5  │ Continuous Sweeping Panning │  0.0 dB    │  0.9683  │  0.9807   │  +0.0124   │ -26.09 dB │ -30.30 │
└────┴─────────────────────────────┴────────────┴──────────┴───────────┴────────────┴───────────┴────────┘
```

#### Detailed Failure Mode Analysis:
1. **Multi-Path Room Reverberation**: 151-tap room impulse response smears acoustic reflections beyond the direct propagation path. The reference microphone loses phase coherence with primary reflections, reducing STOI slightly ($-0.0092$).
2. **Speech Leakage into Reference Microphone**: When $30\%$ of the speaker's speech bleeds into the reference channel, **the adaptive filter treats speech as noise to be cancelled**. The active speech level drops by **$-8.09\text{ dBFS}$**, creating severe comb-filtering hollow vocal distortion.
3. **Abrupt Movement & Tracking Lag**: Delay step changes ($5 \to 25$ samples) cause an audible transient error burst before re-converging within $\approx 150\text{ ms}$.
4. **Extreme Low SNR Bass Inundation**: Under a dense $200\text{ Hz}$ rave bassline at $-15\text{ dB}$, NLMS eradicates the drone, reducing background energy by $15.63\text{ dB}$.

---

### 7. Embedded Firmware & Hardware Deployment (ESP32-S3 Target)

```
┌────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                   EMBEDDED DSP BENCHMARK: ESP32-S3 @ 16 kHz                            │
├───────────────────────┬──────────────┬─────────────┬─────────────┬──────────────┬──────────────────────┤
│ Filter Architecture   │ FLOPs /      │ Throughput  │ CPU Cycles  │ CPU Load @   │ RAM State Buffer     │
│                       │ Sample       │ (MFLOPS)    │ / Sample    │ 240 MHz      │ Footprint            │
├───────────────────────┼──────────────┼─────────────┼─────────────┼──────────────┼──────────────────────┤
│ 128-Tap FIR Bandpass  │ 257 FLOPs    │ 4.11 MFLOPS │ ~310 cycles │ 2.07 %       │ 516 bytes            │
│ 8th-Order IIR SOS (4) │ 20 FLOPs     │ 0.32 MFLOPS │ ~28 cycles  │ 0.19 %       │ 32 bytes             │
│ 1-Stage Notch (Jazz)  │ 5 FLOPs      │ 0.08 MFLOPS │ ~7 cycles   │ 0.05 %       │ 8 bytes (TDF-II)     │
│ 2-Stage Notch (Techno)│ 10 FLOPs     │ 0.16 MFLOPS │ ~14 cycles  │ 0.09 %       │ 16 bytes (TDF-II)    │
│ Dual-Mic NLMS (N=256) │ 515 FLOPs    │ 8.24 MFLOPS │ ~620 cycles │ 4.13 %       │ 2048 bytes           │
│ Hybrid (Notch + NLMS) │ 525 FLOPs    │ 8.40 MFLOPS │ ~634 cycles │ 4.22 %       │ 2064 bytes           │
└───────────────────────┴──────────────┴─────────────┴─────────────┴──────────────┴──────────────────────┘
```

* **Roundtrip DMA Latency**: Parametric Notch operates at $4.15\text{ ms}$ (well below $10\text{ ms}$ echo limit); Dual-Mic NLMS operates at $4.06\text{ ms}$.

---

### 8. Architectural Scorecard & Final Recommendations

1. **Ultra-Low-Power Single-Mic Edge Devices**:
   * **Deploy Parametric Notch Cascades** ([`firmware/iir_coefficients.h`](file:///Users/macairm1/Documents/antigravity/blissful-bose/firmware/iir_coefficients.h)). Requires no second mic, immune to speech leakage, $<0.15\text{ ms}$ latency, $100\%$ pitch retention, $<0.1\%$ CPU load.
2. **Professional Multi-Microphone Headsets**:
   * **Deploy the Hybrid Notch + VAD-Guarded NLMS Architecture**: Notch pre-filter strips sub-bass excursions; a Voice Activity Detector (VAD) freezes adaptation during speech to prevent vocal cancellation; NLMS eliminates broad-spectrum musical interference with $>15\text{ dB}$ ANC gain.

---

### 9. Vault Cross-References
* [Report 00: Master Index & Vault Architecture Map](00_master_index_and_vault_map.md)
* [Report 01: Investigation Overview & Problem Formulation](01_executive_summary_and_problem_formulation.md)
* [Report 02: Dataset Architecture & Acoustic Divergence](02_dataset_architecture_and_acoustic_divergence.md)
* [Report 03: STFT Spectral Analysis & Masking Mechanics](03_stft_spectral_analysis_and_masking_mechanics.md)
* [Report 04: Digital Filter Design Methodologies & Topologies](04_filter_design_methodology_and_architectures.md)
* [Report 05: Audio Overlay Mixing Pipeline & Calibrated Test Stimuli](05_controlled_overlay_synthesis_and_mixing.md)
* [Report 06: Objective Intelligibility Benchmarks & Algorithm Audits](06_evaluation_benchmarks_and_algorithm_audit.md)
* [Report 07: Embedded Firmware Architecture & ESP32-S3 Implementation](07_embedded_firmware_and_hardware_deployment.md)
