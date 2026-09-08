#!/usr/bin/env python3
"""
prepare_genre_test_stimuli.py
Extracts standardized 30.0-second continuous music noise stimuli for
Country, Rock, and Techno into dataset/test_stimuli/music_noise_30s/
"""

import os
import shutil
import wave

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WAV_DIR = os.path.join(BASE_DIR, "dataset", "wav_16k")
OUTPUT_DIR = os.path.join(BASE_DIR, "dataset", "test_stimuli", "music_noise_30s")

os.makedirs(OUTPUT_DIR, exist_ok=True)

TARGET_FS = 16000
TARGET_SAMPLES = TARGET_FS * 30  # exactly 30.0s (480,000 samples)

def extract_30s_clip(src_path, dst_path):
    with wave.open(src_path, "rb") as wf_in:
        fs = wf_in.getframerate()
        n_frames = wf_in.getnframes()
        frames_to_read = min(n_frames, TARGET_SAMPLES)
        data = wf_in.readframes(frames_to_read)

    with wave.open(dst_path, "wb") as wf_out:
        wf_out.setnchannels(1)
        wf_out.setsampwidth(2)
        wf_out.setframerate(TARGET_FS)
        wf_out.writeframes(data)
        # Pad with silence if slightly shorter than 30s
        if frames_to_read < TARGET_SAMPLES:
            silence = b"\x00" * 2 * (TARGET_SAMPLES - frames_to_read)
            wf_out.writeframes(silence)

def main():
    print("Preparing 30-second continuous noise stimuli for Jazz, Rock, and Techno...")

    # Jazz
    j_src = os.path.join(WAV_DIR, "jazz", sorted(os.listdir(os.path.join(WAV_DIR, "jazz")))[0])
    j_dst = os.path.join(OUTPUT_DIR, "jazz_noise_30s.wav")
    extract_30s_clip(j_src, j_dst)
    print(f"  [OK] Jazz noise:   {j_dst}")

    # Rock
    r_src = os.path.join(WAV_DIR, "rock", sorted(os.listdir(os.path.join(WAV_DIR, "rock")))[0])
    r_dst = os.path.join(OUTPUT_DIR, "rock_noise_30s.wav")
    extract_30s_clip(r_src, r_dst)
    print(f"  [OK] Rock noise:    {r_dst}")

    # Techno
    t_src = os.path.join(WAV_DIR, "techno", sorted(os.listdir(os.path.join(WAV_DIR, "techno")))[0])
    t_dst = os.path.join(OUTPUT_DIR, "techno_noise_30s.wav")
    extract_30s_clip(t_src, t_dst)
    print(f"  [OK] Techno noise:  {t_dst}")

    print("Noise stimuli extraction complete.")

if __name__ == "__main__":
    main()
