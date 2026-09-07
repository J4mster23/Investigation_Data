# Dataset References & Data Provenance

This document provides formal academic citations, data provenance, technical specifications, and licensing information for all sound sources and corpora used in this investigation.

---

## 1. Primary Music Noise Corpus: GiantSteps EDM Dataset

The 150 music tracks (50 House, 50 Techno, and 50 Drum & Bass) and the three 60-second continuous test stimuli are sourced from the **GiantSteps EDM Dataset**, created as a collaborative academic Music Information Retrieval (MIR) research initiative between the **Music Technology Group (MTG) at Universitat Pompeu Fabra (Barcelona)** and the **Department of Computational Perception at Johannes Kepler University (Linz)**.

### Academic Citations

If reporting results derived from these audio sources, cite the primary ISMIR 2015 publication and the associated doctoral thesis:

#### Primary Conference Paper (ISMIR 2015)
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

#### Associated Doctoral Thesis (UPF Barcelona)
> Á. Faraldo, *Tonality Estimation in Electronic Dance Music: A Computational and Musically Informed Examination*, Ph.D. dissertation, Universitat Pompeu Fabra, Barcelona, Spain, 2017.

```bibtex
@phdthesis{faraldo2017tonality,
  author = {{\'A}ngel Faraldo},
  title  = {Tonality Estimation in Electronic Dance Music: A Computational and Musically Informed Examination},
  school = {Universitat Pompeu Fabra},
  year   = {2017},
  address= {Barcelona, Spain}
}
```

#### Zenodo Digital Object Identifier (DOI)
> GiantSteps+ EDM Key Dataset: **[10.5281/zenodo.1101082](https://doi.org/10.5281/zenodo.1101082)**

```bibtex
@dataset{giantsteps_edm_dataset,
  author    = {Ángel Faraldo and Peter Knees and Richard Vogl and Perfecto Herrera},
  title     = {GiantSteps+ EDM Key Dataset},
  month     = nov,
  year      = 2017,
  publisher = {Zenodo},
  doi       = {10.5281/zenodo.1101082},
  url       = {https://doi.org/10.5281/zenodo.1101082}
}
```

---

## 2. Upstream Repositories and Mirrors

* **Project Homepage**: [http://www.cp.jku.at/datasets/giantsteps/](http://www.cp.jku.at/datasets/giantsteps/)
* **Official GitHub Repositories**:
  * GiantSteps Key Dataset: [https://github.com/GiantSteps/giantsteps-key-dataset](https://github.com/GiantSteps/giantsteps-key-dataset)
  * GiantSteps Tempo Dataset: [https://github.com/GiantSteps/giantsteps-tempo-dataset](https://github.com/GiantSteps/giantsteps-tempo-dataset)
* **Primary Audio Download Mirror**:
  * JKU Linz Academic Mirror: `https://www.cp.jku.at/datasets/giantsteps/backup/<track_id>.LOFI.mp3`
  * Beatport Preview CDN Fallback: `http://geo-samples.beatport.com/lofi/<track_id>.LOFI.mp3`

---

## 3. Speech Corpus: Harvard Sentence List (IEEE 1969)

The speech component used for mixing test stimuli (Section 4.1) comprises 20 phonetically balanced sentences from the **Harvard Sentence List** (Lists 1 and 2), maintained under IEEE standards for speech quality and intelligibility assessment.

### Academic Citation
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

* **Transcripts Reference**: Stored locally in [`dataset/metadata/harvard_transcripts.json`](file:///Users/macairm1/Documents/antigravity/blissful-bose/dataset/metadata/harvard_transcripts.json) for automated Word Error Rate (WER) scoring.
* **Licensing**: Public Domain.

---

## 4. Objective Metric Evaluation References

The speech enhancement evaluation pipeline in this project measures performance against these standard benchmarks:

* **PESQ (ITU-T P.862)**:
  > International Telecommunication Union, "Perceptual evaluation of speech quality (PESQ): An objective method for end-to-end speech quality assessment of narrow-band telephone networks and speech codecs," *ITU-T Recommendation P.862*, Feb. 2001.
* **STOI (Short-Time Objective Intelligibility)**:
  > C. H. Taal, R. C. Hendriks, R. Heusdens, and J. Jensen, "An algorithm for intelligibility prediction of time--frequency weighted noisy speech," *IEEE Transactions on Audio, Speech, and Language Processing*, vol. 19, no. 7, pp. 2125–2136, Sep. 2011.

---

## 5. Technical Audio Specifications

All processed audio files in `dataset/wav_16k/` and `dataset/test_stimuli/` conform strictly to the embedded platform requirements (Section 3.1 & 3.3):

| Parameter | Specification | Notes |
| :--- | :--- | :--- |
| **Sampling Rate ($f_s$)** | `16 000 Hz` (16 kHz) | Matches ESP32-S3 I2S microphone sampling rate |
| **Bit Depth** | `16-bit` linear PCM | `LEI16` (Little-Endian Signed 16-bit Integer) |
| **Channel Count** | `1` (Mono) | Transcoded from stereo MP3 via channel downmixing |
| **Duration (FIR tracks)** | `120.0 seconds` | Continuous Beatport preview excerpts |
| **Duration (Test stimuli)** | `60.0 seconds` | Core groove slice (seconds 30.0–90.0) |
| **Conversion Tool** | `/usr/bin/afconvert` | Native Apple CoreAudio conversion utility |

---

## 6. Associated Local Files

* **Curated 150-Track Manifest**: [`dataset/metadata/selected_tracks.json`](file:///Users/macairm1/Documents/antigravity/blissful-bose/dataset/metadata/selected_tracks.json)
* **60 s Stimuli Metadata**: [`dataset/metadata/test_stimuli_selection.json`](file:///Users/macairm1/Documents/antigravity/blissful-bose/dataset/metadata/test_stimuli_selection.json)
* **Download & Conversion Log**: [`dataset/metadata/acquisition_summary.json`](file:///Users/macairm1/Documents/antigravity/blissful-bose/dataset/metadata/acquisition_summary.json)
* **Harvesting Script**: [`scripts/build_dataset_manifest.py`](file:///Users/macairm1/Documents/antigravity/blissful-bose/scripts/build_dataset_manifest.py)
* **Conversion Script**: [`scripts/download_and_convert.py`](file:///Users/macairm1/Documents/antigravity/blissful-bose/scripts/download_and_convert.py)
* **Verification Script**: [`scripts/verify_spectral_profiles.py`](file:///Users/macairm1/Documents/antigravity/blissful-bose/scripts/verify_spectral_profiles.py)
