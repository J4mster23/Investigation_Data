# Electronic Dance Music (EDM) Noise & Speech Dataset

This folder contains the standardized audio dataset and test stimuli for the investigation:
> **"An Evaluation of Genre-Specific and Adaptive Filtering Approaches to Speech Enhancement in High-Noise Environments"**  
> Ryan Jammy & Raphael Alsfine, School of Electrical & Information Engineering, University of the Witwatersrand.

---

## Quick Links
- **Academic Citations, DOIs, and BibTeX**: See [REFERENCES.md](file:///Users/macairm1/Documents/antigravity/blissful-bose/dataset/REFERENCES.md)
- **Track Selection Manifest**: [selected_tracks.json](file:///Users/macairm1/Documents/antigravity/blissful-bose/dataset/metadata/selected_tracks.json)
- **Stimuli Selection Metadata**: [test_stimuli_selection.json](file:///Users/macairm1/Documents/antigravity/blissful-bose/dataset/metadata/test_stimuli_selection.json)
- **Harvard Transcripts**: [harvard_transcripts.json](file:///Users/macairm1/Documents/antigravity/blissful-bose/dataset/metadata/harvard_transcripts.json)

---

## Directory Overview

```text
dataset/
├── REFERENCES.md                 # Full academic citations, BibTeX, DOIs, and data provenance
├── README.md                     # This file
├── metadata/                     # Machine-readable manifests and audit records
│   ├── selected_tracks.json      # 150 selected tracks with IDs, subgenres, and mirror URLs
│   ├── test_stimuli_selection.json # 60-second noise excerpt parameters
│   ├── harvard_transcripts.json  # Ground-truth sentences for WER computation
│   └── acquisition_summary.json  # Complete download & conversion audit log
├── raw_mp3/                      # Original 2-minute 44.1 kHz MP3 excerpts (150 files, ~225 MB)
│   ├── house/                    # 50 House tracks
│   ├── techno/                   # 50 Techno tracks
│   └── dnb/                      # 50 Drum & Bass tracks
├── wav_16k/                      # Calibrated 16 kHz 16-bit mono WAVs for FIR stopband design
│   ├── house/                    # 50 converted WAV files
│   ├── techno/                   # 50 converted WAV files
│   └── dnb/                      # 50 converted WAV files
└── test_stimuli/                 # Section 4.1 Evaluation stimuli
    ├── music_noise_60s/          # 3 continuous 60-second noise files (1 per genre)
    │   ├── house_noise_60s.wav
    │   ├── techno_noise_60s.wav
    │   └── dnb_noise_60s.wav
    └── speech_sentences/         # Directory for clean Harvard Sentences recordings
```

---

## Summary of Dataset Specifications

* **Tracks for FIR Stopband Derivation**: 50 House, 50 Techno, 50 Drum & Bass (Total: 150 tracks).
* **Audio Format**: 16 kHz, 16-bit Mono linear PCM WAV.
* **Track Duration**: 120.0 seconds each (FIR tracks), 60.0 seconds each (Test stimuli noise).
* **Source Corpus**: GiantSteps EDM Dataset (ISMIR 2015 / MTG UPF / JKU Linz).
