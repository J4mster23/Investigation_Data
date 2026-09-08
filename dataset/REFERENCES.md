# Dataset References & Data Provenance

This document provides formal academic citations, data provenance, technical specifications, and licensing information for all sound sources and speech corpora used in this investigation.

---

## 1. Genre Datasets

### A. Jazz & Rock Genres: GTZAN Genre Collection
The 50 Jazz tracks and 50 Rock tracks are sourced from the landmark **GTZAN Genre Collection**, the most widely cited benchmark dataset in Music Information Retrieval (MIR) research, developed by George Tzanetakis and Perry Cook.

#### Primary Academic Citation
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

* **Upstream Source**: Hugging Face datasets: [`marsyas/gtzan`](https://huggingface.co/datasets/marsyas/gtzan) / Marsyas Audio Research Repository.
* **Standardization**: Transcoded from 22.05 kHz to $16\,000\text{ Hz}$, 16-bit mono linear PCM WAV using Apple CoreAudio (`afconvert`).

---

### B. Techno Genre: GiantSteps EDM Dataset
The 50 Techno tracks are sourced from the **GiantSteps EDM Dataset**, created as a collaborative academic MIR research initiative between the Music Technology Group (MTG) at Universitat Pompeu Fabra (Barcelona) and Johannes Kepler University (Linz).

#### Primary Academic Citation
> P. Knees, Á. Faraldo, P. Herrera, R. Vogl, S. Böck, F. Hörschläger, and M. Le Goff, "Two data sets for tempo estimation and key detection in electronic dance music annotated from user corrections," in *Proceedings of the 16th International Society for Music Information Retrieval Conference (ISMIR 2015)*, Málaga, Spain, Oct. 2015, pp. 364–370.

```bibtex
@inproceedings{knees2015two,
  author    = {Peter Knees and {\'A}ngel Faraldo and Perfecto Herrera and Richard Vogl and Sebastian B{\"o}ck and Florian H{\"o}rschl{\"a}ger and Mickael Le Goff},
  title     = {Two Datasets for Tempo Estimation and Key Detection in Electronic Dance Music Annotated from User Corrections},
  booktitle = {Proceedings of the 16th International Society for Music Information Retrieval Conference (ISMIR 2015)},
  pages     = {364--370},
  year      = {2015},
  address   = {M{\'a}laga, Spain}
}
```

* **Zenodo DOI**: [10.5281/zenodo.1101082](https://doi.org/10.5281/zenodo.1101082)
* **Standardization**: Transcoded from 44.1 kHz to $16\,000\text{ Hz}$, 16-bit mono linear PCM WAV.

---

## 2. Speech Corpus: Harvard Sentence List (IEEE 1969)

The speech stimuli comprise phonetically balanced sentences from the **Harvard Sentence List** (IEEE Recommended Practice for Speech Quality Measurements).

#### Primary Academic Citation
> IEEE Subcommittee on Subjective Measurements, "IEEE Recommended Practice for Speech Quality Measurements," *IEEE Transactions on Audio and Electroacoustics*, vol. 17, no. 3, pp. 225–246, Sep. 1969, doi: [10.1109/TAU.1969.1162058](https://doi.org/10.1109/TAU.1969.1162058).

```bibtex
@article{ieee1969harvard,
  author  = {{IEEE Subcommittee on Subjective Measurements}},
  journal = {IEEE Transactions on Audio and Electroacoustics}, 
  title   = {IEEE Recommended Practice for Speech Quality Measurements}, 
  year    = {1969},
  volume  = {17},
  number  = {3},
  pages   = {225--246},
  doi     = {10.1109/TAU.1969.1162058}
}
```

* **Transcripts Reference**: Stored locally in [`dataset/metadata/harvard_transcripts.json`](file:///Users/macairm1/Documents/antigravity/blissful-bose/dataset/metadata/harvard_transcripts.json).
* **Licensing**: Public Domain.

---

## 3. Objective Speech Intelligibility & Evaluation Metrics

* **STOI (Short-Time Objective Intelligibility)**:
  > C. H. Taal, R. C. Hendriks, R. Heusdens, and J. Jensen, "An algorithm for intelligibility prediction of time--frequency weighted noisy speech," *IEEE Transactions on Audio, Speech, and Language Processing*, vol. 19, no. 7, pp. 2125–2136, Sep. 2011.
* **ITU-T P.56 Active Speech Leveling**:
  > International Telecommunication Union, "Objective measurement of active speech level," *ITU-T Recommendation P.56*, May 2011.

---

## 4. Technical Audio Specifications

| Parameter | Specification | Notes |
| :--- | :--- | :--- |
| **Sampling Rate ($f_s$)** | `16 000 Hz` (16 kHz) | Matches ESP32-S3 I2S microphone hardware |
| **Bit Depth** | `16-bit` linear PCM | `LEI16` (Little-Endian Signed 16-bit Integer) |
| **Channels** | `1` (Mono) | Channel downmixed |
| **Dataset Size** | `150 tracks total` | 50 Country + 50 Rock + 50 Techno |
| **Speech Overlays** | `90 audio files` | 10 sentences $\times$ 3 genres $\times$ 3 SNRs (0, -5, -10 dB) |
