# Report 05: Audio Overlay Mixing Pipeline & Calibrated Test Stimuli
## Formulation, Active Speech Leveling (ITU-T P.56), and Synthesis of the 90-Stimulus Human Speech Benchmark Suite

* **Project**: Genre-Specific and Adaptive Filtering Approaches to Speech Enhancement in High-Noise Environments
* **Institution**: University of the Witwatersrand, School of Electrical & Information Engineering
* **Authors**: Ryan Jammy & Raphael Alsfine
* **Audio Specification**: $f_s = 16\,000\text{ Hz}$, 16-bit Mono Linear PCM, Zero Clipping ($\text{Peak} \le 0.90$)

---

### 1. Motivation: The Imperative for Rigorous Test Stimuli Calibration

A critical challenge in evaluating speech enhancement algorithms is establishing **reproducible, mathematically calibrated acoustic ground truth**. In real-world environments, human speech is non-stationary, intermittent, and characterized by wide dynamic ranges, whereas musical noise exhibits genre-dependent spectral density, rhythmic transient bursts, and intense low-frequency energy.

Previous preliminary iterations utilized synthesized text-to-speech (TTS) voices. However, synthesized speech lacks:
1. Authentic glottal pulse dynamics and natural vocal fry;
2. Realistic pitch intonation contours ($F_0$ fluctuations);
3. Natural coarticulation and subband formant dispersion ($F_1 - F_4$).

To establish a gold-standard benchmark, all robotic TTS audio was permanently retired and replaced with **authentic human talkers** reciting standardized phonetically balanced Harvard Sentences from the Indiana University Sentence Database (IUS) (Karl & Pisoni, 1994).

```
   AUTHENTIC HUMAN SPEECH (IUS)                   GENRE MUSIC STEMS (30s)
    - 5 Male Talkers (F0 = 125 Hz)                 - Jazz (GTZAN acoustic bass)
    - 5 Female Talkers (F0 = 219 Hz)               - Rock (GTZAN electric kick/overdrive)
    - Phonetically Balanced Sentences              - Techno (GiantSteps sub-bass kicks)
                    │                                              │
                    ▼                                              ▼
       ┌───────────────────────────────┐              ┌───────────────────────────────┐
       │   ITU-T P.56 Active Speech    │              │  RMS Noise Power Calculation  │
       │    Power Leveling (-25 dB)    │              │   over Aligned Signal Frame   │
       └──────────────┬────────────────┘              └──────────────┬────────────────┘
                      │                                              │
                      └───────────────────────┬──────────────────────┘
                                              ▼
                               ┌──────────────────────────────┐
                               │ Exact Target SNR Scaling     │
                               │  (0 dB, -5 dB, -10 dB)       │
                               └──────────────┬───────────────┘
                                              ▼
                               ┌──────────────────────────────┐
                               │ Additive Acoustic Mixing     │
                               └──────────────┬───────────────┘
                                              ▼
                               ┌──────────────────────────────┐
                               │ Anti-Clipping Peak Headroom  │
                               │ Normalization (Peak <= 0.90) │
                               └──────────────┬───────────────┘
                                              ▼
                               ┌──────────────────────────────┐
                               │ 90-Stimulus Benchmark Suite  │
                               │ + JSON Audit Manifest        │
                               └──────────────────────────────┘
```

---

### 2. Active Speech Power Leveling (ITU-T P.56 Standard)

#### Why Global RMS Fails for Speech
In uncalibrated audio mixing, SNR is often computed using the global Root-Mean-Square (RMS) power of the full speech file:

$$P_{\text{global}} = \frac{1}{M} \sum_{n=1}^{M} s^2[n]$$

However, natural conversational speech contains **$25\%$ to $45\%$ inter-word silence and unvoiced pauses**. When silence frames are averaged into $P_{\text{global}}$, the measured power is artificially suppressed. As a result, when noise is scaled to match a nominal SNR (e.g., $-10\text{ dB}$), the voiced speech segments are boosted excessively loud, distorting the intended experimental SNR by up to $+6\text{ dB}$.

#### Mathematical Formulation of ITU-T P.56 Frame-Power Leveling
To eliminate pause-induced error, we implemented a frame-based dynamic active speech leveling algorithm adhering to ITU-T Recommendation P.56:

1. **Frame Decomposition**:
   The speech signal $s[n]$ of length $M$ is segmented into non-overlapping frames of length $N = 320\text{ samples}$ ($20\text{ ms}$ window at $f_s = 16\,000\text{ Hz}$):

   $$s_f[m] = s[(f-1)N + m], \quad m = 1, 2, \dots, N, \quad f = 1, 2, \dots, \lfloor M / N \rfloor$$

2. **Short-Term Frame Energy**:
   The instantaneous energy of each frame is:

   $$P_f = \frac{1}{N} \sum_{m=1}^{N} s_f^2[m]$$

3. **Peak Frame Power**:
   The maximum short-term energy across all frames is:

   $$P_{\max} = \max_{1 \le f \le F} P_f$$

4. **Dynamic Activity Threshold**:
   An activity threshold $\Theta_{\text{active}}$ is set at $-25\text{ dB}$ relative to peak power:

   $$\Theta_{\text{active}} = P_{\max} \cdot 10^{-25 / 10} = P_{\max} \cdot 0.003162$$

5. **Active Speech Set**:
   Frames exceeding the threshold are designated as active speech frames:

   $$\mathcal{K}_{\text{active}} = \left\{ f \;\middle|\; P_f > \Theta_{\text{active}} \right\}$$

6. **Active Speech Power**:
   The active speech power is the mean energy over $\mathcal{K}_{\text{active}}$ only:

   $$P_{\text{speech, active}} = \frac{1}{|\mathcal{K}_{\text{active}}|} \sum_{f \in \mathcal{K}_{\text{active}}} P_f$$

By ignoring pauses, breaths, and phoneme release silences, $P_{\text{speech, active}}$ accurately measures the true acoustic sound pressure level produced by the speaker's vocal tract.

---

### 3. Additive Mixing & Exact SNR Scaling Mechanics

For each target condition, speech and music segments of identical sample length $L$ were combined additively.

#### A. Noise Power Calculation
For the corresponding segment of musical noise $n[m]$ of length $L$:

$$P_{\text{noise}} = \frac{1}{L} \sum_{m=1}^{L} n^2[m]$$

#### B. Exact Scaling Factor
To achieve the exact target Signal-to-Noise Ratio ($\text{SNR}_{\text{target}} \in \{0\text{ dB}, -5\text{ dB}, -10\text{ dB}\}$):

$$\text{SNR}_{\text{target}} = 10 \log_{10}\left( \frac{P_{\text{speech, active}}}{\alpha^2 \cdot P_{\text{noise}}} \right)$$

Solving for the linear noise amplitude scaling factor $\alpha$:

$$\alpha = \sqrt{\frac{P_{\text{speech, active}}}{P_{\text{noise}} \cdot 10^{\text{SNR}_{\text{target}} / 10}}}$$

The scaled, additive mixture is:

$$x_{\text{mix}}[m] = s[m] + \alpha \cdot n[m], \quad m = 1, 2, \dots, L$$

#### C. Temporal Alignment & Noise Offset Rotation
To ensure diverse musical sections are tested and avoid acoustic bias from repeated loops, the noise start offset $n_{\text{offset}}$ for talker $k \in [1, 10]$ is circularly rotated through the 30-second music stem:

$$n_{\text{offset}} = (k \cdot 16\,000 \cdot 2) \pmod{L_{\text{noise\_total}} - L - 1}$$

---

### 4. Peak Headroom Normalization & Anti-Clipping Strategy

Direct acoustic mixing of high-amplitude noise (especially at $-10\text{ dB}$ SNR where noise amplitude exceeds speech by $3.16\times$) frequently causes peak excursions exceeding the linear range of 16-bit integer audio ($[-32768, +32767]$ or $[-1.0, +1.0]$ float). Uncontrolled clipping produces severe harmonic distortion, introducing artificial high-frequency transients that corrupt STFT analysis.

To eliminate clipping while maintaining relative SNR:

1. **Mixture Peak Detection**:
   $$\text{Peak}_{\text{mix}} = \max_{1 \le m \le L} |x_{\text{mix}}[m]|$$

2. **Master Normalization Gain**:
   A target peak headroom of $0.90$ ($-0.915\text{ dBFS}$) is enforced:

   $$g_{\text{norm}} = \begin{cases} 
   \dfrac{0.90}{\text{Peak}_{\text{mix}}}, & \text{if } \text{Peak}_{\text{mix}} > 0.90 \\
   1.0, & \text{otherwise}
   \end{cases}$$

3. **Linear Attenuation**:
   $$y[m] = g_{\text{norm}} \cdot x_{\text{mix}}[m]$$
   $$s_{\text{norm}}[m] = g_{\text{norm}} \cdot s[m]$$
   $$n_{\text{norm}}[m] = g_{\text{norm}} \cdot \alpha \cdot n[m]$$

Since $g_{\text{norm}}$ scales both speech and noise identically:

$$\text{SNR}_{\text{actual}} = 10 \log_{10}\left( \frac{g_{\text{norm}}^2 \cdot P_{\text{speech, active}}}{g_{\text{norm}}^2 \cdot \alpha^2 \cdot P_{\text{noise}}} \right) = \text{SNR}_{\text{target}}$$

The target SNR is preserved with zero clipping across all 90 stimuli.

---

### 5. Benchmark Suite Architecture & Directory Layout

The calibrated test suite consists of 90 audio files stored systematically on disk:

```
dataset/test_stimuli/speech_overlay_dataset/
├── jazz/
│   ├── female_01_jazz_snr_0dB.wav  ... female_05_jazz_snr_10dB.wav (15 files)
│   └── male_01_jazz_snr_0dB.wav    ... male_05_jazz_snr_10dB.wav   (15 files)
├── rock/
│   ├── female_01_rock_snr_0dB.wav  ... female_05_rock_snr_10dB.wav (15 files)
│   └── male_01_rock_snr_0dB.wav    ... male_05_rock_snr_10dB.wav   (15 files)
└── techno/
    ├── female_01_techno_snr_0dB.wav ... female_05_techno_snr_10dB.wav (15 files)
    └── male_01_techno_snr_0dB.wav   ... male_05_techno_snr_10dB.wav   (15 files)
```

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                   BENCHMARK SUITE BREAKDOWN                                     │
├─────────┬──────────────────────┬─────────────┬───────────┬──────────────┬───────────────────────┤
│ Genre   │ Human Talkers        │ Gender Split│ SNRs (dB) │ Total Tracks │ Total Duration        │
├─────────┼──────────────────────┼─────────────┼───────────┼──────────────┼───────────────────────┤
│ Jazz    │ 10 Harvard Sentences │ 5 M / 5 F   │ 0, -5, -10│ 30 files     │ ~95.4 seconds         │
│ Rock    │ 10 Harvard Sentences │ 5 M / 5 F   │ 0, -5, -10│ 30 files     │ ~95.4 seconds         │
│ Techno  │ 10 Harvard Sentences │ 5 M / 5 F   │ 0, -5, -10│ 30 files     │ ~95.4 seconds         │
├─────────┼──────────────────────┼─────────────┼───────────┼──────────────┼───────────────────────┤
│ TOTAL   │ 10 Talkers (IUS)     │ 5 M / 5 F   │ 3 Tiers   │ 90 files     │ ~286.2 seconds        │
└─────────┴──────────────────────┴─────────────┴───────────┴──────────────┴───────────────────────┘
```

---

### 6. The Metadata Audit Manifest (`speech_overlay_manifest.json`)

To support programmatic testing and reproducibility, each file's acoustic parameters were serialized to `dataset/metadata/speech_overlay_manifest.json`.

#### Sample Manifest Entry

```json
{
  "filename": "female_01_techno_snr_10dB.wav",
  "filepath": "dataset/test_stimuli/speech_overlay_dataset/techno/female_01_techno_snr_10dB.wav",
  "genre": "techno",
  "gender": "female",
  "speaker_id": "IUS-F00202",
  "speech_source_file": "female_01_IUS-F00202.wav",
  "target_snr_db": -10.0,
  "measured_active_snr_db": -10.0,
  "speech_active_rms": 0.0463,
  "noise_rms": 0.1464,
  "peak_amplitude": 0.9000,
  "duration_seconds": 3.15
}
```

Every record includes verified measurements of:
* Active speech RMS power;
* Noise RMS power;
* Measured output SNR (guaranteed to match target SNR within $\pm 0.01\text{ dB}$);
* Peak linear amplitude (verified $\le 0.9000$).

---

### 7. Isolated 10-Second Test Snippets

In addition to the 90-file corpus, a dedicated suite of 10-second isolated audio snippets was generated in `dataset/test_stimuli/isolated_snippets/` for listening audits:

1. `snippet_speech_male_10s.wav`: 10-second continuous clean male speech segment;
2. `snippet_speech_female_10s.wav`: 10-second continuous clean female speech segment;
3. `snippet_music_techno_10s.wav`: 10-second isolated Techno beat stem;
4. `snippet_combined_female_techno_snr_minus5db_10s.wav`: Calibrated 10-second mixture at $-5\text{ dB}$ SNR.

---

### 8. Vault Cross-References
* [Report 01: Investigation Overview & Problem Formulation](01_executive_summary_and_problem_formulation.md)
* [Report 02: Dataset Architecture & Acoustic Divergence](02_dataset_architecture_and_acoustic_divergence.md)
* [Report 03: STFT Spectral Analysis & Masking Mechanics](03_stft_spectral_analysis_and_masking_mechanics.md)
* [Report 04: Digital Filter Design Methodologies & Topologies](04_filter_design_methodology_and_architectures.md)
* [Report 06: Objective Intelligibility Benchmarks & Algorithm Audits](06_evaluation_benchmarks_and_algorithm_audit.md)
* [Report 07: Embedded Firmware Architecture & ESP32-S3 Implementation](07_embedded_firmware_and_hardware_deployment.md)
