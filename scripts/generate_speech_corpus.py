#!/usr/bin/env python3
"""
generate_speech_corpus.py
Synthesizes the 20 phonetically balanced Harvard Sentences (IEEE Recommended Practice)
using macOS native TTS and CoreAudio afconvert, sampled at 16 kHz, 16-bit mono linear PCM.
"""

import json
import os
import subprocess
import sys

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TRANSCRIPTS_PATH = os.path.join(BASE_DIR, "dataset", "metadata", "harvard_transcripts.json")
SPEECH_DIR = os.path.join(BASE_DIR, "dataset", "test_stimuli", "speech_sentences")

os.makedirs(SPEECH_DIR, exist_ok=True)

def generate_sentences():
    if not os.path.exists(TRANSCRIPTS_PATH):
        print(f"Error: Transcripts not found at {TRANSCRIPTS_PATH}")
        sys.exit(1)

    with open(TRANSCRIPTS_PATH, "r", encoding="utf-8") as f:
        transcripts = json.load(f)

    print(f"Synthesizing {len(transcripts)} Harvard Sentences at 16 kHz, 16-bit mono PCM...")

    for key, text in sorted(transcripts.items()):
        aiff_path = os.path.join(SPEECH_DIR, f"{key}.aiff")
        wav_path = os.path.join(SPEECH_DIR, f"{key}.wav")

        # 1. Synthesize speech using native macOS say (natural voice: Samantha)
        say_cmd = ["/usr/bin/say", "-v", "Samantha", "-r", "175", "-o", aiff_path, text]
        subprocess.run(say_cmd, check=True)

        # 2. Convert to standard 16 kHz, 16-bit Little-Endian Integer mono WAV
        convert_cmd = [
            "/usr/bin/afconvert",
            "-f", "WAVE",
            "-d", "LEI16@16000",
            "-c", "1",
            aiff_path,
            wav_path
        ]
        subprocess.run(convert_cmd, check=True)

        # 3. Clean up intermediate AIFF
        if os.path.exists(aiff_path):
            os.remove(aiff_path)

        wav_size = os.path.getsize(wav_path)
        print(f"  [OK] {key}: \"{text}\" -> {wav_size} bytes")

    print(f"\nAll {len(transcripts)} sentences generated successfully in: {SPEECH_DIR}")

if __name__ == "__main__":
    generate_sentences()
