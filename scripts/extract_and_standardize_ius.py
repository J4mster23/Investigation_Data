#!/usr/bin/env python3
"""
extract_and_standardize_ius.py
Extracts a diverse, statistically balanced sample of 50 Male and 50 Female
spoken Harvard sentence recordings from the Indiana University Sentence Database (IUS)
zip archive, standardizes them from 20 kHz to 16 kHz 16-bit mono linear PCM WAV
using Apple CoreAudio (afconvert), and removes the zip bloat.
"""

import os
import shutil
import subprocess
import wave
import zipfile

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ZIP_PATH = os.path.join(BASE_DIR, "OneDrive_2026-09-08.zip")
CORPUS_DIR = os.path.join(BASE_DIR, "dataset", "speech_corpus")
TEMP_RAW_DIR = os.path.join(BASE_DIR, "dataset", "raw_ius")

MALE_DIR = os.path.join(CORPUS_DIR, "male")
FEMALE_DIR = os.path.join(CORPUS_DIR, "female")
COMBINED_DIR = os.path.join(CORPUS_DIR, "combined")

os.makedirs(MALE_DIR, exist_ok=True)
os.makedirs(FEMALE_DIR, exist_ok=True)
os.makedirs(COMBINED_DIR, exist_ok=True)
os.makedirs(TEMP_RAW_DIR, exist_ok=True)

TARGET_FS = 16000

def convert_to_16k_mono(src_path, dst_path):
    cmd = [
        "/usr/bin/afconvert",
        "-f", "WAVE",
        "-d", "LEI16@16000",
        "-c", "1",
        src_path,
        dst_path
    ]
    subprocess.run(cmd, check=True)

def verify_wav(path, expected_fs=TARGET_FS):
    with wave.open(path, "rb") as wf:
        assert wf.getframerate() == expected_fs
        assert wf.getnchannels() == 1
        assert wf.getsampwidth() == 2
        return wf.getnframes() / float(expected_fs)

def main():
    print("=" * 65)
    print("  EXTRACTING & STANDARDIZING INDIANA UNIVERSITY SENTENCE DATABASE")
    print("  Target: 50 Male + 50 Female Harvard Sentences @ 16 kHz, 16-bit mono")
    print("=" * 65)

    if not os.path.exists(ZIP_PATH):
        raise FileNotFoundError(f"Zip archive not found: {ZIP_PATH}")

    with zipfile.ZipFile(ZIP_PATH, "r") as z:
        namelist = z.namelist()
        
        # Filter male and female wav files
        male_files = [n for n in namelist if "/IUS-M" in n and n.endswith(".wav")]
        female_files = [n for n in namelist if "/IUS-F" in n and n.endswith(".wav")]
        
        # Sort to ensure reproducible selection across distinct speakers
        male_files = sorted(male_files)
        female_files = sorted(female_files)
        
        # Step through speakers to get diverse talkers (e.g. step by 20 to sample 50 distinct talkers)
        step_m = max(1, len(male_files) // 50)
        step_f = max(1, len(female_files) // 50)
        
        selected_male = [male_files[i * step_m] for i in range(50)]
        selected_female = [female_files[i * step_f] for i in range(50)]

        print(f"\nExtracting and converting 50 diverse Male speech recordings:")
        for idx, entry_name in enumerate(selected_male, 1):
            fname = os.path.basename(entry_name)
            raw_tmp = os.path.join(TEMP_RAW_DIR, fname)
            z.extract(entry_name, TEMP_RAW_DIR)
            extracted_file = os.path.join(TEMP_RAW_DIR, entry_name)
            
            dst_male = os.path.join(MALE_DIR, f"male_{idx:02d}_{fname}")
            dst_comb = os.path.join(COMBINED_DIR, f"male_{idx:02d}_{fname}")
            
            convert_to_16k_mono(extracted_file, dst_male)
            shutil.copy2(dst_male, dst_comb)
            dur = verify_wav(dst_male)
            print(f"  [M {idx:02d}/50] Converted: {os.path.basename(dst_male)} ({dur:.2f}s)")

        print(f"\nExtracting and converting 50 diverse Female speech recordings:")
        for idx, entry_name in enumerate(selected_female, 1):
            fname = os.path.basename(entry_name)
            z.extract(entry_name, TEMP_RAW_DIR)
            extracted_file = os.path.join(TEMP_RAW_DIR, entry_name)
            
            dst_female = os.path.join(FEMALE_DIR, f"female_{idx:02d}_{fname}")
            dst_comb = os.path.join(COMBINED_DIR, f"female_{idx:02d}_{fname}")
            
            convert_to_16k_mono(extracted_file, dst_female)
            shutil.copy2(dst_female, dst_comb)
            dur = verify_wav(dst_female)
            print(f"  [F {idx:02d}/50] Converted: {os.path.basename(dst_female)} ({dur:.2f}s)")

    # Clean up temp raw directory
    if os.path.exists(TEMP_RAW_DIR):
        shutil.rmtree(TEMP_RAW_DIR)
        print("\nCleaned up temporary raw extraction directory.")

    print("\nVerification:")
    print(f"  Male files:     {len(os.listdir(MALE_DIR))}")
    print(f"  Female files:   {len(os.listdir(FEMALE_DIR))}")
    print(f"  Combined files: {len(os.listdir(COMBINED_DIR))}")

    # Remove the large zip archive and root single-speaker wav to eliminate bloat
    if os.path.exists(ZIP_PATH):
        os.remove(ZIP_PATH)
        print(f"Removed zip archive: {os.path.basename(ZIP_PATH)} (saved ~178 MB).")
        
    root_wav = os.path.join(BASE_DIR, "Harvard_speech100.wav")
    if os.path.exists(root_wav):
        os.remove(root_wav)
        print(f"Removed single-speaker root wav: {os.path.basename(root_wav)} (saved ~25 MB).")

    print("\nSPEECH CORPUS EXTRACTION & STANDARDIZATION COMPLETE!")

if __name__ == "__main__":
    main()
