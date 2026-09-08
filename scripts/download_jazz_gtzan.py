#!/usr/bin/env python3
"""
download_jazz_gtzan.py
Streams the GTZAN Genre Dataset from HuggingFace, extracts 50 Jazz
audio tracks, and converts them into standardized 16 kHz, 16-bit mono linear PCM WAVs
using macOS afconvert.
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

os.makedirs(os.path.join(WAV_DIR, "jazz"), exist_ok=True)
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
    print("  DOWNLOADING & STANDARDIZING JAZZ (GTZAN DATASET)")
    print("  Target: 50 Jazz Tracks @ 16 kHz, 16-bit mono WAV")
    print("=" * 65)

    ctx = ssl._create_unverified_context()
    req = urllib.request.Request(HF_GTZAN_URL, headers={"User-Agent": "Mozilla/5.0"})

    print(f"\nConnecting to HuggingFace GTZAN repository:\n{HF_GTZAN_URL}...")
    resp = urllib.request.urlopen(req, context=ctx, timeout=60)
    tar = tarfile.open(mode="r|gz", fileobj=resp)

    jazz_count = 0
    target_count = 50

    print("\nStreaming and extracting Jazz tracks directly from archive:")
    for member in tar:
        fname = os.path.basename(member.name)
        if fname.startswith("._"):
            continue

        if "genres/jazz/" in member.name and member.name.endswith(".wav") and jazz_count < target_count:
            raw_path = os.path.join(RAW_DIR, fname)
            f_out = tar.extractfile(member)
            with open(raw_path, "wb") as f_dst:
                shutil.copyfileobj(f_out, f_dst)
            
            # Standardize to 16 kHz 16-bit mono
            target_wav = os.path.join(WAV_DIR, "jazz", f"jazz_{jazz_count+1:02d}_{fname}")
            try:
                convert_to_16k_mono(raw_path, target_wav)
                dur = verify_wav(target_wav)
                jazz_count += 1
                print(f"  [{jazz_count:02d}/{target_count:02d}] Converted: {os.path.basename(target_wav)} ({dur:.2f}s)")
            except Exception as e:
                print(f"  [SKIPPED] Corrupt GTZAN file {fname}: {e}")
                if os.path.exists(target_wav):
                    os.remove(target_wav)
            
            # Remove temp raw file to save space
            if os.path.exists(raw_path):
                os.remove(raw_path)

            if jazz_count >= target_count:
                break

    tar.close()
    print(f"\nSuccessfully downloaded and standardized {jazz_count} Jazz tracks into {os.path.join(WAV_DIR, 'jazz')}.")

if __name__ == "__main__":
    main()
