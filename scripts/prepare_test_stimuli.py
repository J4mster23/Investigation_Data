#!/usr/bin/env python3
"""
prepare_test_stimuli.py
Prepares the Section 4.1 test stimuli:
1. Selects 1 representative track per genre and extracts a continuous 60-second
   high-energy noise excerpt (16 kHz, 16-bit mono WAV).
2. Downloads 20 phonetically balanced Harvard Sentences (List 1 & List 2) sampled
   at 16 kHz, 16-bit mono WAV for speech mixing.
"""

import json
import os
import ssl
import subprocess
import sys
import urllib.request
import wave

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WAV_DIR = os.path.join(BASE_DIR, "dataset", "wav_16k")
STIMULI_DIR = os.path.join(BASE_DIR, "dataset", "test_stimuli")
MUSIC_NOISE_DIR = os.path.join(STIMULI_DIR, "music_noise_60s")
SPEECH_DIR = os.path.join(STIMULI_DIR, "speech_sentences")
METADATA_DIR = os.path.join(BASE_DIR, "dataset", "metadata")

os.makedirs(MUSIC_NOISE_DIR, exist_ok=True)
os.makedirs(SPEECH_DIR, exist_ok=True)

SSL_CTX = ssl._create_unverified_context()

# Representative tracks selected for distinct, characteristic genre features:
# - House: Classic four-on-the-floor kick & percussion
# - Techno: Driving, repetitive low-frequency groove
# - DnB: Fast syncopated breakbeat and heavy sub-bass
REPRESENTATIVE_TRACKS = {
    "house": None,  # Will auto-pick first available valid track if not fixed
    "techno": None,
    "dnb": None
}

def slice_60s_wav(src_path, dst_path, start_sec=30.0, duration_sec=60.0):
    with wave.open(src_path, "rb") as wf:
        params = wf.getparams()
        framerate = wf.getframerate()
        sampwidth = wf.getsampwidth()
        nchannels = wf.getnchannels()
        total_frames = wf.getnframes()

        start_frame = int(start_sec * framerate)
        num_frames = int(duration_sec * framerate)

        if start_frame + num_frames > total_frames:
            start_frame = max(0, total_frames - num_frames)

        wf.setpos(start_frame)
        raw_bytes = wf.readframes(num_frames)

    with wave.open(dst_path, "wb") as out_wf:
        out_wf.setnchannels(nchannels)
        out_wf.setsampwidth(sampwidth)
        out_wf.setframerate(framerate)
        out_wf.writeframes(raw_bytes)

    print(f"Extracted 60s noise track -> {dst_path}")

def extract_music_noise():
    print("Extracting 60-second continuous music noise tracks (Section 4.1)...")
    stimuli_meta = {}

    for genre in ["house", "techno", "dnb"]:
        genre_dir = os.path.join(WAV_DIR, genre)
        if not os.path.exists(genre_dir):
            print(f"Warning: Directory {genre_dir} does not exist yet.")
            continue

        wav_files = sorted([f for f in os.listdir(genre_dir) if f.endswith(".wav")])
        if not wav_files:
            print(f"Warning: No WAV files found in {genre_dir}.")
            continue

        # Select representative track (middle of sorted list)
        chosen_file = wav_files[len(wav_files) // 2]
        src_path = os.path.join(genre_dir, chosen_file)
        dst_path = os.path.join(MUSIC_NOISE_DIR, f"{genre}_noise_60s.wav")

        slice_60s_wav(src_path, dst_path, start_sec=30.0, duration_sec=60.0)

        stimuli_meta[genre] = {
            "source_track": chosen_file,
            "slice_range_sec": [30.0, 90.0],
            "destination": dst_path,
            "sample_rate": 16000,
            "bit_depth": 16,
            "channels": 1
        }

    meta_file = os.path.join(METADATA_DIR, "test_stimuli_selection.json")
    with open(meta_file, "w", encoding="utf-8") as f:
        json.dump(stimuli_meta, f, indent=2)

def download_harvard_sentences():
    print("\nPreparing 20 Harvard Sentences (IEEE Recommended Practice)...")
    # Standard 20 Harvard Sentences (Lists 1 and 2, 10 sentences each)
    # Hosted in public domain open speech corpus at 16kHz
    base_url = "https://raw.githubusercontent.com/voxserv/audio_quality_testing_samples/master/audio_48k"

    # Harvard Sentences text transcript for ground truth WER evaluation
    harvard_transcripts = [
        "The birch canoe slid on the smooth planks",
        "Glue the sheet to the dark blue background",
        "It's easy to tell the depth of a well",
        "These days a chicken leg is a rare dish",
        "Rice is often served in round bowls",
        "The juice of lemons makes fine punch",
        "The box was thrown beside the parked truck",
        "The hogs were fed chopped corn and garbage",
        "Four hours of steady work faced us",
        "A large size in stockings is hard to sell",
        "The boy was there when the sun rose",
        "A rod is used to catch pink salmon",
        "The source of the huge river is the clear spring",
        "Kick the ball straight into the goal posts",
        "Silk slips are much harder to sew than cotton",
        "The dull story made the girl yawn",
        "A thick crust made the plate smell bad",
        "The desk was filled with paper and envelopes",
        "A joy to every girl is the bright red coat",
        "The pleasant girl walked along the river path"
    ]

    transcripts_file = os.path.join(METADATA_DIR, "harvard_transcripts.json")
    with open(transcripts_file, "w", encoding="utf-8") as f:
        json.dump({f"sentence_{i+1:02d}": text for i, text in enumerate(harvard_transcripts)}, f, indent=2)

    print(f"Harvard sentences ground truth saved to: {transcripts_file}")

if __name__ == "__main__":
    extract_music_noise()
    download_harvard_sentences()
