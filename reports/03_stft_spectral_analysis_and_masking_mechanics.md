# Progress Report 03: STFT Spectral Analysis, Vocal Formants & Masking Mechanics

* **Module**: `03_stft_spectral_analysis_and_masking_mechanics`
* **Authors**: Ryan Jammy & Raphael Alsfine
* **Supervising Institution**: School of Electrical & Information Engineering, University of the Witwatersrand
* **Date**: September 2026

---

## 1. Short-Time Fourier Transform (STFT) Mathematical Formulation

Because music and conversational speech signals are non-stationary, their frequency content evolves continuously over time. Spectral analysis was performed using the discrete **Short-Time Fourier Transform (STFT)**.

For a discrete-time signal $x[n]$ sampled at $f_s = 16\,000\text{ Hz}$, the STFT is defined as:
$$X[m, k] = \sum_{n=0}^{N-1} x[m \cdot R + n] \cdot w[n] \cdot e^{-j \frac{2\pi k n}{N}}$$
where:
* $m \in \mathbb{Z}$ is the discrete time frame index.
* $k \in \{0, 1, \dots, N/2\}$ is the discrete frequency bin index ($k = 0$ corresponds to DC, $k = N/2 = 512$ corresponds to Nyquist, $8\,000\text{ Hz}$).
* $N = 1024$ is the FFT window length ($T_{\text{win}} = N / f_s = 64.0\text{ ms}$).
* $R = 512$ is the frame hop size ($T_{\text{hop}} = R / f_s = 32.0\text{ ms}$, representing a $50\%$ overlap).
* $w[n]$ is the periodic Hann analysis window:
  $$w[n] = 0.5 \left(1 - \cos\left(\frac{2\pi n}{N}\right)\right), \quad 0 \le n < N$$

### Frequency and Time Resolution
The analysis window provides an optimal balance for audio signal processing:
$$\Delta f = \frac{f_s}{N} = \frac{16\,000\text{ Hz}}{1024} = 15.625\text{ Hz per bin}$$
$$\Delta t = \frac{R}{f_s} = \frac{512}{16\,000} = 32.0\text{ ms frame update}$$

A frequency resolution of $\Delta f = 15.625\text{ Hz}$ is critical because it cleanly resolves low-frequency pitch fundamentals ($F_0 \approx 100-250\text{ Hz}$) and narrow bass resonance peaks (e.g., separating a $62.5\text{ Hz}$ kick drum from a $78.1\text{ Hz}$ upright bass note).

---

## 2. Quantitative Subband Energy Distribution Across 150 Tracks

The STFT was computed across all 150 standardized tracks (50 Jazz, 50 Rock, 50 Techno) using [`scripts/stft_genre_analysis.m`](file:///Users/macairm1/Documents/antigravity/blissful-bose/scripts/stft_genre_analysis.m). The time-averaged power spectral density (PSD) $P_{\text{genre}}(f)$ was calculated by averaging frame energies across all 50 tracks within each genre:
$$P_{\text{genre}}[k] = \frac{1}{M \cdot T} \sum_{t=1}^{T} \sum_{m=1}^{M_t} |X_t[m, k]|^2$$

### Empirical Acoustic Subband Table

| Musical Genre | Peak Resonant Freq | Sub-Bass ($<80\text{ Hz}$) | Kick Band ($60-150\text{ Hz}$) | Low Bass ($<250\text{ Hz}$) | Speech Band ($300-3400\text{ Hz}$) | High Sizzle ($>4\text{ kHz}$) | Spectral Centroid | 85% Rolloff |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Techno** | **$62.5\text{ Hz}$** | **$65.28\%$** | **$51.86\%$** | **$85.37\%$** | $10.62\%$ | $1.40\%$ | $270.6\text{ Hz}$ | $234.4\text{ Hz}$ |
| **Rock** | **$109.4\text{ Hz}$** | $13.67\%$ | $33.68\%$ | $60.66\%$ | $31.74\%$ | **$1.86\%$** | $557.5\text{ Hz}$ | $984.4\text{ Hz}$ |
| **Jazz** | **$78.1\text{ Hz}$** | $14.42\%$ | $30.00\%$ | $45.78\%$ | **$46.97\%$** | $0.77\%$ | $504.2\text{ Hz}$ | $781.2\text{ Hz}$ |

### Analysis of Genre Spectral Signatures
1. **Techno Signature**: Shows an extreme low-frequency tilt. Over **$85.37\%$ of its total acoustic energy is concentrated below $250\text{ Hz}$**, dominated by the synthetic $62.5\text{ Hz}$ sub-bass kick fundamental and its $125.0\text{ Hz}$ second harmonic. In contrast, only $10.62\%$ of Techno energy enters the speech intelligibility band ($300-3400\text{ Hz}$).
2. **Rock Signature**: Shows an amplified broadband structure. Energy peaks at $109.4\text{ Hz}$ (kick drum punch and bass guitar root), but heavily populates the mid-range ($31.74\%$) through distorted electric guitars and features the highest high-frequency energy ($1.86\%$ above $4\text{ kHz}$) from cymbal crashes.
3. **Jazz Signature**: Exhibits the highest vocal-band overlap. While upright acoustic bass creates a resonance peak at $78.1\text{ Hz}$, **$46.97\%$ of Jazz acoustic energy lies directly inside the $300-3400\text{ Hz}$ vocal band**, driven by acoustic brass (saxophones, trumpets) and grand piano harmonics.

---

## 3. Human Vocal Profiling: Methodology & Formant Analysis

### 3.1 Active Speech Energy Leveling (ITU-T P.56)
Standard long-term RMS power measurements underestimate speech power by $4 - 9\text{ dB}$ because conversational speech contains $30 - 50\%$ unvoiced pauses, glottal stops, and inter-word silence. To establish true vocal power, we implemented **ITU-T Recommendation P.56** frame energy thresholding:
1. Frame energy $p_f = \frac{1}{L_f} \sum_{n=0}^{L_f-1} s^2[f \cdot L_f + n]$ is computed in $20\text{ ms}$ windows ($L_f = 320$).
2. The peak frame power $p_{\max} = \max_f(p_f)$ is determined.
3. Active frames are identified via a $-25\text{ dB}$ relative threshold:
   $$\mathcal{A} = \{f \mid 10 \log_{10}(p_f / p_{\max}) \ge -25\text{ dB}\}$$
4. The active speech spectrum is computed strictly over frames $f \in \mathcal{A}$.

### 3.2 Multi-Talker Gender Metrics (Male vs. Female vs. Combined)

Analysis across 100 spoken Harvard sentences from the IUS corpus reveals dramatic gender differences in vocal energy distribution:

| Vocal Parameter | Male Talkers ($N=50$) | Female Talkers ($N=50$) | Combined Cohort ($N=100$) | Physiological / DSP Impact |
| :--- | :---: | :---: | :---: | :--- |
| **Pitch Fundamental ($F_0$)** | **$125.0\text{ Hz}$** | **$218.8\text{ Hz}$** | $125.0 / 218.8\text{ Hz}$ | Vocal fold vibration rate |
| **Harmonic Peak 1** | $250.0\text{ Hz}$ | $437.5\text{ Hz}$ | $250.0\text{ Hz}$ | First pitch harmonic ($2 F_0$) |
| **First Formant ($F_1$)** | $500.0\text{ Hz}$ | $593.8\text{ Hz}$ | $500.0\text{ Hz}$ | Pharyngeal cavity resonance (vowel height) |
| **Second Formant ($F_2$)** | $1531.2\text{ Hz}$ | $1656.2\text{ Hz}$ | $1562.5\text{ Hz}$ | Oral cavity resonance (vowel backness) |
| **Third Formant ($F_3$)** | $2625.0\text{ Hz}$ | $2750.0\text{ Hz}$ | $2687.5\text{ Hz}$ | Dental/alveolar resonance |
| **Spectral Centroid** | $674.5\text{ Hz}$ | $773.1\text{ Hz}$ | $724.0\text{ Hz}$ | Female vocal centroid is **$+98.6\text{ Hz}$ higher** |
| **Sub-Bass ($<80\text{ Hz}$)** | $0.21\%$ | $0.22\%$ | $0.22\%$ | Sub-audible vocal tract rumble |
| **Kick Band ($60-150\text{ Hz}$)** | **$5.99\%$** | **$0.57\%$** | $3.27\%$ | **Male speech has $10.5\times$ more kick-band power** |
| **Low Band ($<250\text{ Hz}$)** | **$15.66\%$** | **$26.09\%$** | **$20.90\%$** | Highpass filtering at 250 Hz strips 15-26% speech |
| **Speech Band ($300-3400\text{ Hz}$)**| $75.73\%$ | $67.99\%$ | $71.84\%$ | Standard telecommunication bandwidth |
| **Highs ($>4\text{ kHz}$)** | $1.97\%$ | $1.70\%$ | $1.83\%$ | Unvoiced fricatives (/s/, /sh/, /f/) |

### 3.3 Critical Psychoacoustic Insights
1. **Male Vocal Vulnerability to Kick Drums**: Male speech contains **$5.99\%$ of its energy in the $60-150\text{ Hz}$ band** (coinciding with $F_0 = 125\text{ Hz}$). Because Techno ($51.86\%$) and Rock ($33.68\%$) deliver massive acoustic energy in this exact band, male speakers suffer immediate masking of their pitch fundamental, destroying voice recognition and timbre.
2. **Female Vocal Energy in Lower Harmonics**: Female talkers exhibit a fundamental at $F_0 = 218.8\text{ Hz}$, meaning **$26.09\%$ of total female vocal power is located below $250\text{ Hz}$**.
3. **The Bandpass Paradox**: Applying a traditional $300 - 3400\text{ Hz}$ bandpass filter removes $15.7\%$ of male vocal power and $26.1\%$ of female vocal power. While it removes sub-bass music rumble, it completely severs the speaker's vocal pitch fundamental ($F_0$), causing the speech to sound harsh, tinny, and robotic.

---

## 4. Spectral Signal-to-Noise Ratio & Masking Differentials

To identify exact frequency regions where speech dominates or is drowned out by music, we computed the **Spectral Signal-to-Noise Ratio ($\text{SSNR}$)**:
$$\text{SSNR}(f) = 10 \log_{10} \frac{P_{\text{speech}}(f)}{P_{\text{genre}}(f)}$$
where $P_{\text{speech}}(f)$ is normalized to match the active speech level of the musical genre ($0\text{ dB}$ nominal active SNR).

```
   SSNR (dB)
     +15 ───┐               [SPEECH DOMINANT REGION]
            │              (Formants F1, F2: 500 - 2500 Hz)
       0 ───┼─────────────────────────────────────────────────────────── 0 dB Threshold
            │   /---\                                     \---/
     -15 ───┼──/     \───────────────────────────────────/     \────────
            │ [MASKED BY BASS]                        [MASKED BY CYMBALS]
     -30 ───┴─────────────────────────────────────────────────────────── Frequency (Hz)
            20       100       300       1000      3000      8000
```

### Masking Profiles by Genre
* **Techno**: In the sub-bass region ($40 - 150\text{ Hz}$), $\text{SSNR}$ drops to **$-25\text{ dB}$ to $-32\text{ dB}$**. In this region, Techno completely overwhelms speech. However, between $600\text{ Hz}$ and $3500\text{ Hz}$, Techno drops off rapidly, resulting in a positive masking margin ($\text{SSNR} = +5\text{ dB}$ to $+12\text{ dB}$).
* **Rock**: In the kick/bass region ($80 - 200\text{ Hz}$), $\text{SSNR} \approx -18\text{ dB}$. Between $1\text{ kHz}$ and $3\text{ kHz}$, electric guitars depress $\text{SSNR}$ to near $0\text{ dB}$. Above $4\text{ kHz}$, cymbal splash drops $\text{SSNR}$ to $-12\text{ dB}$.
* **Jazz**: Acoustic upright bass creates a localized masking dip at $60 - 90\text{ Hz}$ ($\text{SSNR} \approx -16\text{ dB}$). Crucially, throughout the entire vocal range ($300 - 3000\text{ Hz}$), $\text{SSNR}$ hovers between $-3\text{ dB}$ and $+3\text{ dB}$ due to acoustic brass and piano.

These empirical profiles prove that **a single static filter cannot optimize speech enhancement across different genres**. Filter cutoffs and notch frequencies must be tailored to the specific acoustic profile of each genre.
