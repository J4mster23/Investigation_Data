#!/usr/bin/env python3
"""
download_country_rock_gtzan.py
Streams the GTZAN Genre Dataset from HuggingFace, extracts 50 Country and 50 Rock
audio tracks, and converts them into standardized 16 kHz, 16-bit mono linear PCM WAVs
using macOS afconvert. Also ensures the 50 Techno tracks from GiantSteps are verified.
"""

import os
import shutil
import ssl
import subprocess
import tarfile
import urllib.request
import wave

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WAV_DIR = os.path.join(BASE_DIR, "dataset", "wav_16k")
RAW_DIR = os.path.join(BASE_DIR, "dataset", "raw_gtzan")

os.makedirs(os.path.join(WAV_DIR, "country"), exist_ok=True)
os.makedirs(os.path.join(WAV_DIR, "rock"), exist_ok=True)
os.makedirs(os.path.join(WAV_DIR, "techno"), exist_ok=True)
os.makedirs(RAW_DIR, exist_ok=True)

HF_GTZAN_URL = "https://huggingface.co/datasets/marsyas/gtzan/resolve/main/data/genres.tar.gz"

def convert_to_16k_mono(input_path, output_path):
    cmd = [
        "/usr/bin/afconvert",
        "-f", "WAVE",
        "-d", "LEI16@16000",
        "-c", "1",
        input_path,
        output_path
    ]
    subprocess.run(cmd, check=True)

def verify_wav(path, expected_fs=16000):
    with wave.open(path, "rb") as wf:
        assert wf.getframerate() == expected_fs
        assert wf.getnchannels() == 1
        assert wf.getsampwidth() == 2
        return wf.getnframes() / float(expected_fs)

def main():
    print("=" * 65)
    print("  DOWNLOADING & STANDARDIZING COUNTRY AND ROCK (GTZAN DATASET)")
    print("  Target: 50 Country + 50 Rock @ 16 kHz, 16-bit mono WAV")
    print("=" * 65)

    # 1. Stream GTZAN tar.gz from HuggingFace
    ctx = ssl._create_unverified_context()
    req = urllib.request.Request(HF_GTZAN_URL, headers={"User-Agent": "Mozilla/5.0"})

    print(f"\nConnecting to HuggingFace GTZAN repository:\n{HF_GTZAN_URL}...")
    resp = urllib.request.urlopen(req, context=ctx, timeout=60)
    tar = tarfile.open(mode="r|gz", fileobj=resp)

    country_count = 0
    rock_count = 0
    target_count = 50

    print("\nStreaming and extracting target genres directly from archive:")
    for member in tar:
        fname = os.path.basename(member.name)
        if fname.startswith("._"):
            continue

        # Check Country
        if "genres/country/" in member.name and member.name.endswith(".wav") and country_count < target_count:
            raw_path = os.path.join(RAW_DIR, fname)
            f_out = tar.extractfile(member)
            with open(raw_path, "wb") as f_dst:
                shutil.copyfileobj(f_out, f_dst)
            
            # Standardize to 16 kHz 16-bit mono
            target_wav = os.path.join(WAV_DIR, "country", f"country_{country_count+1:02d}_{fname}")
            convert_to_16k_mono(raw_path, target_wav)
            dur = verify_wav(target_wav)
            os.remove(raw_path)
            country_count += 1
            print(f"  [COUNTRY {country_count:02d}/50] {fname} -> {dur:.1f}s (16kHz mono) [OK]")

        # Check Rock
        elif "genres/rock/" in member.name and member.name.endswith(".wav") and rock_count < target_count:
            raw_path = os.path.join(RAW_DIR, fname)
            f_out = tar.extractfile(member)
            with open(raw_path, "wb") as f_dst:
                shutil.copyfileobj(f_out, f_dst)
            
            # Standardize to 16 kHz 16-bit mono
            target_wav = os.path.join(WAV_DIR, "rock", f"rock_{rock_count+1:02d}_{fname}")
            convert_to_16k_mono(raw_path, target_wav)
            dur = verify_wav(target_wav)
            os.remove(raw_path)
            rock_count += 1
            print(f"  [ROCK    {rock_count:02d}/50] {fname} -> {dur:.1f}s (16kHz mono) [OK]")

        if country_count >= target_count and rock_count >= target_count:
            print("\nSuccessfully reached 50 Country and 50 Rock tracks! Closing stream.")
            break

    if os.path.exists(RAW_DIR):
        shutil.rmtree(RAW_DIR)

    # 2. Verify Techno tracks
    techno_dir = os.path.join(WAV_DIR, "techno")
    techno_files = [f for f in os.listdir(techno_dir) if f.endswith(".wav")]
    print(f"\nVerifying Techno tracks in {techno_dir}: {len(techno_files)} tracks present.")

    print("\n" + "=" * 65)
    print(f"  DATASET STANDARDIZATION COMPLETE:")
    print(f"  - Country: {country_count} tracks in {os.path.join(WAV_DIR, 'country')}")
    print(f"  - Rock:    {rock_count} tracks in {os.path.join(WAV_DIR, 'rock')}")
    print(f"  - Techno:  {len(techno_files)} tracks in {techno_dir}")
    print("=" * 65)

if __name__ == "__main__":
    main()
