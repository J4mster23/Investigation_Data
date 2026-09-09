# Report 06: Objective Intelligibility Benchmarks & Algorithm Audits
## Mathematical Formulation of STOI, Physical Delta SNR, Root-Cause Bug Post-Mortems, and Full Empirical Evaluation

* **Project**: Genre-Specific and Adaptive Filtering Approaches to Speech Enhancement in High-Noise Environments
* **Institution**: University of the Witwatersrand, School of Electrical & Information Engineering
* **Authors**: Ryan Jammy & Raphael Alsfine
* **Audio Evaluation Corpus**: Indiana University Sentence Database (IUS) (Male & Female Human Speech)
* **Test Stimuli**: 90 Calibrated Audio Mixtures across Jazz, Rock, Techno ($0\text{ dB}, -5\text{ dB}, -10\text{ dB}, -15\text{ dB}$)

---

### 1. Objective Evaluation Metrics Formulation

Speech enhancement algorithms require objective metrics that correlate closely with human psychoacoustic perception. In this investigation, two rigorous metrics were implemented:

```
                                  EVALUATION METHODOLOGY
                                            │
                    ┌───────────────────────┴───────────────────────┐
                    ▼                                               ▼
     ┌─────────────────────────────┐                 ┌─────────────────────────────┐
     │   Short-Time Objective      │                 │     Physical Component      │
     │   Intelligibility (STOI)    │                 │    Delta SNR Improvement    │
     │   (Taal et al., 2011)       │                 │      (\Delta\text{SNR})     │
     └──────────────┬──────────────┘                 └──────────────┬──────────────┘
                    ▼                                               ▼
     - 1/3-octave band envelopes                     - Linear filter separation
     - Intermediate correlation d_j                  - Zero phase-cancellation bias
     - Range: [0.0, 1.0]                             - Exact acoustic power ratio
     - Predicts human word recognition               - Measures true noise suppression
```

#### A. Short-Time Objective Intelligibility (STOI)
The STOI metric (Taal et al., 2011) evaluates speech intelligibility based on the correlation of short-time temporal envelopes between clean reference speech $s[n]$ and processed/degraded speech $\hat{s}[n]$ across 15 one-third octave bands:

1. **Short-Time Fourier Decomposition**:
   Signals are framed using an $N = 512$ point periodic Hanning window with $50\%$ overlap ($R = 256$ hop size, $16\text{ ms}$):

   $$S(k, m) = \sum_{n=0}^{N-1} s[mR + n] \cdot w[n] \cdot e^{-j 2\pi k n / N}$$

2. **One-Third Octave Subband Integration**:
   One-third octave band energies are computed across $K = 15$ critical bands spanning $150\text{ Hz}$ to $4000\text{ Hz}$:

   $$X_k(m) = \sqrt{\sum_{l \in \text{Band}_k} |S(l, m)|^2}, \quad Y_k(m) = \sqrt{\sum_{l \in \text{Band}_k} |\hat{S}(l, m)|^2}$$

3. **Short-Time Segment Vectors**:
   For each time frame $m$, a vector of $M = 30$ consecutive frames ($\approx 384\text{ ms}$) is formed:

   $$\mathbf{x}_{k,m} = [X_k(m - M + 1), \dots, X_k(m)]^T$$
   $$\mathbf{y}_{k,m} = [Y_k(m - M + 1), \dots, Y_k(m)]^T$$

4. **Normalization & Dynamic Range Clipping**:
   To prevent high-energy musical noise bursts from dominating the score, $\mathbf{y}_{k,m}$ is normalized and clipped:

   $$\alpha = \sqrt{\frac{\sum_j x_{k,m}^2[j]}{\sum_j y_{k,m}^2[j] + \epsilon}}$$
   $$\bar{y}_{k,m}[j] = \min(\alpha \cdot y_{k,m}[j], \, 1.5 \cdot x_{k,m}[j])$$

5. **Intermediate Correlation Measure**:
   The sample correlation coefficient between clean and normalized processed envelope vectors is:

   $$d_{k,m} = \frac{(\mathbf{x}_{k,m} - \mu_x)^T (\bar{\mathbf{y}}_{k,m} - \mu_{\bar{y}})}{\|\mathbf{x}_{k,m} - \mu_x\|_2 \cdot \|\bar{\mathbf{y}}_{k,m} - \mu_{\bar{y}}\|_2}$$

6. **Final STOI Metric**:
   The overall STOI score is the mean correlation across all bands and frames:

   $$\text{STOI} = \frac{1}{K \cdot M_{\text{total}}} \sum_{k=1}^{K} \sum_{m} \max(0, \min(1, d_{k,m})) \in [0.0, 1.0]$$

#### B. Physical Component $\Delta\text{SNR}$ Formulation
In linear time-invariant (LTI) filtering, the filtered output is the superposition of the filtered speech component and filtered noise component:

$$y[n] = \mathcal{H}\{s[n] + n[n]\} = s_{\text{filt}}[n] + n_{\text{filt}}[n]$$

The true physical Signal-to-Noise Ratio at input and output is:

$$\text{SNR}_{\text{in}} = 10 \log_{10}\left( \frac{\sum_{n} s^2[n]}{\sum_{n} n^2[n] + \epsilon} \right)$$

$$\text{SNR}_{\text{out}} = 10 \log_{10}\left( \frac{\sum_{n} s_{\text{filt}}^2[n]}{\sum_{n} n_{\text{filt}}^2[n] + \epsilon} \right)$$

$$\Delta\text{SNR} = \text{SNR}_{\text{out}} - \text{SNR}_{\text{in}}$$

---

### 2. Root-Cause Algorithm Audits & Bug Post-Mortems

During systematic testing of the speech enhancement pipeline, two major anomalies were detected, audited, and mathematically resolved.

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                   ALGORITHM AUDIT & BUG RESOLUTION                              │
├────────────────────┬──────────────────────────────────────┬─────────────────────────────────────┤
│ Issue Identified   │ Root Cause Mechanism                 │ Engineering Resolution              │
├────────────────────┼──────────────────────────────────────┼─────────────────────────────────────┤
│ 1. +32.18 dB FIR   │ Parks-McClellan Remez exchange diver-│ Replaced `firpm` with windowed-sinc │
│    Resonant Spike  │ gence due to steep transition bands  │ `fir1` (Hamming window); max gain   │
│                    │ & uneven passband/stopband weights   │ bounded strictly to +0.03 dB        │
├────────────────────┼──────────────────────────────────────┼─────────────────────────────────────┤
│ 2. False Negative  │ Residual subtraction formula         │ Separated physical signal components│
│    ΔSNR in Notch   │ (y_filt - s_clean) induced phase-    │ using LTI linearity; confirmed true │
│    Filters         │ cancellation residual errors         │ noise reduction (+0.85 dB Techno)   │
└────────────────────┴──────────────────────────────────────┴─────────────────────────────────────┘
```

#### A. Bug 1 Post-Mortem: The Parks-McClellan +32.18 dB Resonant Spike
* **Observation**: In early audio auditions, FIR-filtered signals emitted an ear-piercing high-frequency whistle with severe digital clipping.
* **Root-Cause Analysis**: In `design_and_compare_filters.m`, the FIR filter was originally designed using the Parks-McClellan algorithm (`firpm(128, f_edges, a_edges, [15, 1, 15])`). Due to the narrow transition width ($80\text{ Hz}$ in Techno/Jazz) and aggressive weighting ($15:1$), the Remez exchange polynomial diverged, creating a violent Chebyshev equiripple overshoot:
  * **Jazz FIR**: $+32.18\text{ dB}$ resonant peak at $3642.1\text{ Hz}$ ($>40\times$ linear amplitude amplification);
  * **Techno FIR**: $+30.92\text{ dB}$ resonant peak at $3707.0\text{ Hz}$;
  * **Rock FIR**: $+0.04\text{ dB}$ (wider transition band avoided divergence).
* **Acoustic Impact**: Amplified mid-high frequencies into extreme saturation, completely obliterating speech consonants and causing severe acoustic distortion.
* **Resolution**: Abandoned polynomial optimization in favor of a 128-tap windowed-sinc design via `fir1` with a Hamming window. Frequency verification confirmed:
  * Maximum passband gain: **$+0.03\text{ dB}$**;
  * Stopband rejection: **$>53\text{ dB}$**;
  * Resonant whistling and distortion completely eliminated.

#### B. Bug 2 Post-Mortem: Phase-Delay Subtraction Residual Error
* **Observation**: Initial benchmark tables reported negative $\Delta\text{SNR}$ ($-3.2\text{ dB}$ to $-6.5\text{ dB}$) for parametric notch filters, falsely suggesting the filters were injecting noise.
* **Root-Cause Analysis**: The script used the standard telecommunications residual formula:
  $$n_{\text{out}}[n] = y[n] - s_{\text{clean}}[n]$$
  While valid for zero-latency, zero-phase operations, when speech passes through an IIR or notch filter, it undergoes frequency-dependent phase shift $\theta(\omega)$ and group delay $\tau_g(\omega)$. Subtracting unshifted clean speech $s[n]$ from delayed filtered speech $s_{\text{filt}}[n]$ creates a massive residual error:
  $$e[n] = s_{\text{filt}}[n] - s[n] \neq 0$$
  The formula counted this phase-delayed speech as "noise", yielding an invalid, artificially depressed SNR.
* **Diagnostic Proof**: Direct component isolation in `test_snr_mechanism.m` proved:
  * Speech Power Change: $-0.06\text{ dB}$ (98.6% preserved);
  * Noise Attenuation: **$-0.91\text{ dB}$**;
  * **True Output SNR**: $\Delta\text{SNR} = \mathbf{+0.85\text{ dB}}$.
* **Resolution**: Replaced residual subtraction with exact physical component filtering ($s_{\text{filt}} = \mathcal{H}\{s\}$, $n_{\text{filt}} = \mathcal{H}\{n\}$), producing verified positive $\Delta\text{SNR}$ values.

---

### 3. Quantitative Benchmark Results

Simulations were executed across 30 distinct talkers (10 Male, 10 Female, 10 Combined) from the IUS corpus across 3 genres and 3 input SNR tiers ($-5\text{ dB}, -10\text{ dB}, -15\text{ dB}$):

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                  SPEECH ENHANCEMENT BENCHMARK: BANDPASS BIQUAD VS. PARAMETRIC NOTCH             │
├────────┬────────┬────────┬──────────────┬──────────────┬─────────────┬─────────────┬────────────┤
│ Gender │ Genre  │ Input  │ ΔSNR Bandpass│ ΔSNR Notch   │ STOI Unproc │ STOI Bandpass│ STOI Notch │
├────────┼────────┼────────┼──────────────┼──────────────┼─────────────┼─────────────┼────────────┤
│ MALE   │ JAZZ   │  -5 dB │    +3.12 dB  │    +0.21 dB  │    0.912    │    0.895    │   0.912    │
│ MALE   │ JAZZ   │ -10 dB │    +3.12 dB  │    +0.21 dB  │    0.810    │    0.788    │   0.810    │
│ MALE   │ JAZZ   │ -15 dB │    +3.12 dB  │    +0.21 dB  │    0.665    │    0.642    │   0.665    │
│ MALE   │ ROCK   │  -5 dB │    +2.48 dB  │    +0.45 dB  │    0.931    │    0.914    │   0.931    │
│ MALE   │ ROCK   │ -10 dB │    +2.48 dB  │    +0.45 dB  │    0.841    │    0.820    │   0.841    │
│ MALE   │ ROCK   │ -15 dB │    +2.48 dB  │    +0.45 dB  │    0.702    │    0.678    │   0.702    │
│ MALE   │ TECHNO │  -5 dB │    +4.65 dB  │    +0.85 dB  │    0.965    │    0.948    │   0.965    │
│ MALE   │ TECHNO │ -10 dB │    +4.65 dB  │    +0.85 dB  │    0.910    │    0.887    │   0.910    │
│ MALE   │ TECHNO │ -15 dB │    +4.65 dB  │    +0.85 dB  │    0.805    │    0.779    │   0.805    │
├────────┼────────┼────────┼──────────────┼──────────────┼─────────────┼─────────────┼────────────┤
│ FEMALE │ JAZZ   │  -5 dB │    +3.45 dB  │    +0.18 dB  │    0.925    │    0.898    │   0.925    │
│ FEMALE │ JAZZ   │ -10 dB │    +3.45 dB  │    +0.18 dB  │    0.835    │    0.805    │   0.835    │
│ FEMALE │ JAZZ   │ -15 dB │    +3.45 dB  │    +0.18 dB  │    0.705    │    0.672    │   0.705    │
│ FEMALE │ ROCK   │  -5 dB │    +2.82 dB  │    +0.42 dB  │    0.942    │    0.921    │   0.942    │
│ FEMALE │ ROCK   │ -10 dB │    +2.82 dB  │    +0.42 dB  │    0.862    │    0.838    │   0.862    │
│ FEMALE │ ROCK   │ -15 dB │    +2.82 dB  │    +0.42 dB  │    0.735    │    0.708    │   0.735    │
│ FEMALE │ TECHNO │  -5 dB │    +5.12 dB  │    +0.79 dB  │    0.972    │    0.949    │   0.972    │
│ FEMALE │ TECHNO │ -10 dB │    +5.12 dB  │    +0.79 dB  │    0.928    │    0.899    │   0.928    │
│ FEMALE │ TECHNO │ -15 dB │    +5.12 dB  │    +0.79 dB  │    0.840    │    0.808    │   0.840    │
├────────┼────────┼────────┼──────────────┼──────────────┼─────────────┼─────────────┼────────────┤
│ COMB.  │ JAZZ   │ -10 dB │    +3.28 dB  │    +0.20 dB  │    0.822    │    0.796    │   0.822    │
│ COMB.  │ ROCK   │ -10 dB │    +2.65 dB  │    +0.44 dB  │    0.851    │    0.829    │   0.851    │
│ COMB.  │ TECHNO │ -10 dB │    +4.88 dB  │    +0.82 dB  │    0.919    │    0.893    │   0.919    │
└────────┴────────┴────────┴──────────────┴──────────────┴─────────────┴─────────────┴────────────┘
```

#### Detailed Empirical Analysis

1. **The Bandpass Paradox (High $\Delta\text{SNR}$ vs. Poor STOI)**:
   * Broadband Bandpass achieves impressive raw $\Delta\text{SNR}$ numbers ($+2.5\text{ dB}$ to $+5.1\text{ dB}$) because it brutally eliminates out-of-band energy ($f < 300\text{ Hz}$ and $f > 3400\text{ Hz}$).
   * However, **its STOI scores consistently decline by $-0.015$ to $-0.028$** across all talkers. Amputating $F_0$ glottal pulses and sibilant fricatives distorts temporal envelope correlation, degrading speech intelligibility despite higher numerical SNR.
2. **Parametric Notch Intelligibility Superiority**:
   * Parametric Notch cascades achieve targeted noise reduction ($+0.20\text{ dB}$ to $+0.85\text{ dB}$ net $\Delta\text{SNR}$ suppression of massive bass lines).
   * Crucially, **Notch filters maintain pristine STOI scores ($0.910 - 0.928$ in Techno @ $-10\text{ dB}$)**, perfectly preserving pitch harmonics and phoneme articulation without acoustic coloration.
3. **Gender Disparity Under Bandpass Filtering**:
   * Female speech suffers a larger STOI penalty under Bandpass filtering ($-0.030$ in Jazz @ $-10\text{ dB}$) than Male speech ($-0.022$). Because female fundamental pitch ($218.8\text{ Hz}$) and $F_1$ formants sit higher, the sharp filter roll-off near $300\text{ Hz}$ causes severe phase distortion in the first vocal formant.

---

### 4. Pre- and Post-Filtered Audit Audio Catalog

For comprehensive experimental verification, a dedicated test set of 12 uncompressed audio files ($16\text{ kHz}$ linear PCM) was generated in `dataset/test_stimuli/audit_filtered_audio/` and mirrored in the knowledge vault:

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                   AUDIT AUDIO FILE CATALOG (-5 dB SNR)                          │
├─────────┬────────────────────────────────────────────┬─────────────┬─────────────┬──────────────┤
│ Genre   │ Audit File Description                     │ Peak Amp    │ RMS Energy  │ Verification │
├─────────┼────────────────────────────────────────────┼─────────────┼─────────────┼──────────────┤
│ JAZZ    │ jazz_pre_filtered_snr5db.wav               │ 0.9000      │ 0.1652      │ Baseline Mix │
│ JAZZ    │ jazz_post_filtered_fir_bp.wav              │ 0.7412      │ 0.1184      │ Monotonic BP │
│ JAZZ    │ jazz_post_filtered_iir_bp.wav              │ 0.7820      │ 0.1215      │ 8th-Ord SOS  │
│ JAZZ    │ jazz_post_filtered_notch.wav               │ 0.8985      │ 0.1631      │ Notch Null   │
├─────────┼────────────────────────────────────────────┼─────────────┼─────────────┼──────────────┤
│ ROCK    │ rock_pre_filtered_snr5db.wav               │ 0.9000      │ 0.1748      │ Baseline Mix │
│ ROCK    │ rock_post_filtered_fir_bp.wav              │ 0.7105      │ 0.1290      │ Monotonic BP │
│ ROCK    │ rock_post_filtered_iir_bp.wav              │ 0.7512      │ 0.1312      │ 8th-Ord SOS  │
│ ROCK    │ rock_post_filtered_notch.wav               │ 0.8841      │ 0.1685      │ Notch+Shelf  │
├─────────┼────────────────────────────────────────────┼─────────────┼─────────────┼──────────────┤
│ TECHNO  │ techno_pre_filtered_snr5db.wav             │ 0.9000      │ 0.1892      │ Baseline Mix │
│ TECHNO  │ techno_post_filtered_fir_bp.wav            │ 0.6845      │ 0.1120      │ Monotonic BP │
│ TECHNO  │ techno_post_filtered_iir_bp.wav            │ 0.7180      │ 0.1165      │ 8th-Ord SOS  │
│ TECHNO  │ techno_post_filtered_notch.wav             │ 0.8650      │ 0.1742      │ 2-Stage Null │
└─────────┴────────────────────────────────────────────┴─────────────┴─────────────┴──────────────┘
```

All 12 audit files pass strict sanity checks:
* $\text{Peak} \le 0.95$ (zero clipping);
* Zero NaN or Inf sample occurrences;
* Complete audible removal of the $+32\text{ dB}$ whistling anomaly.

---

### 5. Architectural Artifacts & Figure References

The following figures illustrate the comparative benchmarks:

1. **Speech Enhancement Performance by Gender**:
   `figures/filter_comparison_speech_enhancement.png`
   *(Bar charts comparing STOI intelligibility and $\Delta\text{SNR}$ across Male, Female, and Combined speech).*
2. **Speech Formants vs. Filter Alignment**:
   `figures/speech_formants_filter_alignment.png`
   *(Overlays vocal formants $F_0 - F_4$ against the attenuation profiles of Bandpass and Notch filters).*
3. **Spectral Masking Differentials**:
   `figures/speech_masking_differentials.png`
   *(Plots subband signal-to-noise differentials showing the severe low-frequency masking caused by Techno sub-bass).*

---

### 6. Vault Cross-References
* [Report 01: Investigation Overview & Problem Formulation](01_executive_summary_and_problem_formulation.md)
* [Report 02: Dataset Architecture & Acoustic Divergence](02_dataset_architecture_and_acoustic_divergence.md)
* [Report 03: STFT Spectral Analysis & Masking Mechanics](03_stft_spectral_analysis_and_masking_mechanics.md)
* [Report 04: Digital Filter Design Methodologies & Topologies](04_filter_design_methodology_and_architectures.md)
* [Report 05: Audio Overlay Mixing Pipeline & Calibrated Test Stimuli](05_controlled_overlay_synthesis_and_mixing.md)
* [Report 07: Embedded Firmware Architecture & ESP32-S3 Implementation](07_embedded_firmware_and_hardware_deployment.md)
