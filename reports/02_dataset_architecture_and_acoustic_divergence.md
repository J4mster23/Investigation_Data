# Progress Report 02: Dataset Architecture, Acoustic Divergence & Multi-Talker Vocal Profiling

* **Module**: `02_dataset_architecture_and_acoustic_divergence`
* **Authors**: Ryan Jammy & Raphael Alsfine
* **Supervising Institution**: School of Electrical & Information Engineering, University of the Witwatersrand
* **Date**: September 2026

---

## 1. Overview & Architectural Motivation

To rigorously evaluate speech enhancement algorithms under realistic conditions, the acoustic dataset must satisfy three strict empirical criteria:
1. **Statistical Validity**: Sufficient sample size ($N = 50$ distinct tracks per genre; $N = 100$ distinct human talkers) to prevent sample-specific biases or single-recording anomalies from skewing spectral estimates.
2. **Acoustic Divergence**: Selected genres must span orthogonal dimensions in the musical timbre, instrumentation, and frequency-domain feature space.
3. **Rigorous Signal Standardization**: All audio assets must be standardized to a uniform sampling rate ($16\,000\text{ Hz}$), channel geometry (1-channel mono), and encoding (16-bit signed integer linear PCM) matching embedded DSP hardware.

---

## 2. The Acoustic Triad: Musical Genres & Data Provenance

```
                              [1. SYNTHETIC / ELECTRONIC]
                                        TECHNO
                               (85.4% energy <250 Hz;
                                sub-bass kicks @ 62.5 Hz;
                                speech-band energy: 10.6%)
                                           ▲
                                          / \
                                         /   \
                                        /     \
                                       /       \
                                      /_________\
              [2. ELECTRIC / AMPLIFIED]         [3. ACOUSTIC / POLYPHONIC]
                        ROCK                              JAZZ
             (60.7% energy <250 Hz;            (45.8% energy <250 Hz;
              mid-bass @ 109.4 Hz;              upright bass @ 78.1 Hz;
              broadband guitar distortion;      acoustic brass & piano;
              speech-band energy: 31.7%)        speech-band energy: 47.0%)
```

### 2.1 The Transition from Country to Jazz
In early research iterations, the evaluated genres were **Country**, **Rock**, and **Techno**. However, empirical STFT cross-correlation revealed that Country and Rock were acoustically redundant:
* **Rock Low Bass ($<250\text{ Hz}$)**: $60.66\%$ | **Speech Band Overlap**: $31.74\%$ | **Spectral Centroid**: $557.5\text{ Hz}$
* **Country Low Bass ($<250\text{ Hz}$)**: $59.82\%$ | **Speech Band Overlap**: $33.85\%$ | **Spectral Centroid**: $542.1\text{ Hz}$

Because both genres rely on rhythm acoustic/electric guitars and standard drum kits (kick at $90-110\text{ Hz}$, snare at $200-250\text{ Hz}$), keeping both genres failed to test the boundaries of digital filtering.

**Country was therefore replaced with Jazz**, establishing the **Acoustic Triad**:
1. **Techno (Synthetic / Machine Grid)**: Maximum energy concentration in sub-bass ($<80\text{ Hz}: 65.28\%$), minimal energy in the speech band ($10.62\%$). Represents the simplest scenario for low-cut filtering.
2. **Rock (Amplified / Broadband Noise)**: Prominent kick and bass guitar ($60-150\text{ Hz}: 33.68\%$), moderate vocal band overlap ($31.74\%$), and significant high-frequency cymbal sizzle ($>4\text{ kHz}: 1.86\%$).
3. **Jazz (Acoustic / Formant Overlap)**: Dominated by acoustic instruments (saxophone, trumpet, trombone, piano) whose natural harmonics directly occupy the human formant band ($300-3400\text{ Hz}: 46.97\%$). Represents the most challenging scenario for noise reduction.

### 2.2 Formal Academic Citations & Data Provenance

#### A. Jazz & Rock: GTZAN Genre Collection
Sourced from the landmark benchmark corpus created by George Tzanetakis and Perry Cook at Princeton University:
> G. Tzanetakis and P. Cook, "Musical genre classification of audio signals," *IEEE Transactions on Speech and Audio Processing*, vol. 10, no. 5, pp. 293–302, Jul. 2002, doi: [10.1109/TSA.2002.800560](https://doi.org/10.1109/TSA.2002.800560).

```bibtex
@article{tzanetakis2002musical,
  author  = {George Tzanetakis and Perry Cook},
  journal = {IEEE Transactions on Speech and Audio Processing},
  title   = {Musical Genre Classification of Audio Signals},
  year    = {2002},
  volume  = {10},
  number  = {5},
  pages   = {293--302},
  doi     = {10.1109/TSA.2002.800560}
}
```

#### B. Techno: GiantSteps EDM Dataset
Sourced from the collaborative research dataset created by the Music Technology Group (MTG) at Universitat Pompeu Fabra and Johannes Kepler University Linz:
> P. Knees, Á. Faraldo, P. Herrera, R. Vogl, S. Böck, F. Hörschläger, and M. Le Goff, "Two data sets for tempo estimation and key detection in electronic dance music annotated from user corrections," in *Proc. 16th ISMIR Conference*, Málaga, Spain, 2015, pp. 364–370.

```bibtex
@inproceedings{knees2015two,
  author    = {Peter Knees and {\'A}ngel Faraldo and Perfecto Herrera and Richard Vogl and Sebastian B{\"o}ck and Florian H{\"o}rschl{\"a}ger and Mickael Le Goff},
  title     = {Two Datasets for Tempo Estimation and Key Detection in Electronic Dance Music Annotated from User Corrections},
  booktitle = {Proceedings of the 16th International Society for Music Information Retrieval Conference (ISMIR 2015)},
  pages     = {364--370},
  year      = {2015}
}
```

---

## 3. The Human Speech Corpus: Indiana University Sentence Database (IUS)

### 3.1 Background & Replacement of Synthetic TTS
In Phase 1, speech stimuli were generated using macOS synthetic text-to-speech (`say -v Samantha`). While convenient, synthetic speech produces perfectly flat pitch contours, unnatural harmonic decaying, and uniform formant bandwidths that do not reflect human vocal tract acoustics.

In Phase 3, we ingested authentic spoken Harvard Sentences from the **Indiana University Sentence Database (IUS)**.

### 3.2 Formal Academic Citation & Provenance
> J. R. Karl and D. B. Pisoni, "Effects of stimulus variability on recall of spoken sentences: A first report," *Research on Spoken Language Processing*, Progress Report No. 19, Indiana University Bloomington, pp. 145–194, 1994.

```bibtex
@article{karl1994effects,
  author      = {J. R. Karl and David B. Pisoni},
  journal     = {Research on Spoken Language Processing},
  title       = {Effects of stimulus variability on recall of spoken sentences: A first report},
  year        = {1994},
  volume      = {19},
  pages       = {145--194},
  institution = {Speech Research Laboratory, Indiana University Bloomington}
}
```
* **Support**: Supported by NIH-NIDCD Research Grant R01 DC-00111 and Training Grant DC-00012.
* **Stimuli Standard**: Phonetically balanced Harvard Sentences conforming to the **IEEE Recommended Practice for Speech Quality Measurements** (*IEEE Trans. Audio Electroacoust.*, 1969).

### 3.3 Gender Partitioning & Corpus Ingestion Pipeline
The ingestion script [`scripts/extract_and_standardize_ius.py`](file:///Users/macairm1/Documents/antigravity/blissful-bose/scripts/extract_and_standardize_ius.py) extracted 100 recordings from the archive, resampled them from their original $20\,000\text{ Hz}$ capture rate to $16\,000\text{ Hz}$ using high-order sinc interpolation, and partitioned them into gender cohorts:

```
dataset/speech_corpus/
├── male/      # 50 recordings: IUS-M01 through IUS-M50 (F0 ≈ 125 Hz)
├── female/    # 50 recordings: IUS-F01 through IUS-F50 (F0 ≈ 219 Hz)
└── combined/  # 100 recordings: Balanced multi-talker cohort
```

A calibrated subset of 20 recordings (10 Male, 10 Female) is preserved in [`dataset/test_stimuli/speech_sentences/`](file:///Users/macairm1/Documents/antigravity/blissful-bose/dataset/test_stimuli/speech_sentences/) for reproducible bench testing.

---

## 4. Audio Standardization Specifications

Every audio file in this project strictly complies with the following linear PCM specification:

| Parameter | Value | Specification Notes |
| :--- | :--- | :--- |
| **Sampling Rate ($f_s$)** | $16\,000\text{ Hz}$ | $16\text{ kHz}$ linear sampling; $\Delta t = 62.5\ \mu\text{s}$ per sample |
| **Nyquist Frequency** | $8\,000\text{ Hz}$ | Anti-aliasing low-pass cutoff at $7.6\text{ kHz}$ |
| **Channels** | $1$ | Monophonic (stereo files downmixed via $(L + R)/2$) |
| **Bit Depth** | $16\text{-bit}$ | Signed integer linear PCM (`LEI16`: Little-Endian Signed 16-bit) |
| **Dynamic Range** | $96.33\text{ dB}$ | Theoretical maximum for 16-bit uniform quantization |
| **Quantization Step ($\Delta$)**| $1 / 32768 \approx 3.05 \times 10^{-5}$ | Normalized floating-point mapping $[-1.0, +1.0]$ |
| **Peak Amplitude Policy** | $\le 0.90\text{ FS}$ ($-0.9\text{ dBFS}$) | Mandatory headroom margin preventing inter-sample clipping |

---

## 5. Storage Architecture & Git Hygiene

Because the full raw audio assets exceed 400 MB, a strict `.gitignore` policy prevents binary audio bloat from degrading Git repository performance while preserving metadata, analysis scripts, C firmware headers, and high-resolution analytical figures:

```
.gitignore rules:
├── dataset/raw_mp3/               # IGNORED (Raw uncompressed audio)
├── dataset/wav_16k/               # IGNORED (Standardized genre corpus)
├── dataset/speech_corpus/         # IGNORED (100 IUS speech recordings)
├── dataset/test_stimuli/          # IGNORED (All generated test WAVs)
├── *.wav, *.zip                   # IGNORED (All audio and archive binaries)
├── !dataset/metadata/             # TRACKED (JSON, MAT, and CSV metadata)
├── firmware/                      # TRACKED (Embedded C headers)
├── figures/                       # TRACKED (High-resolution analytical plots)
├── scripts/                       # TRACKED (MATLAB & Python processing code)
└── reports/                       # TRACKED (Comprehensive Markdown knowledge base)
```
