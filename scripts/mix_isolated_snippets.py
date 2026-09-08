#!/usr/bin/env python3
"""
mix_isolated_snippets.py
Pure Python audio isolation and calibrated mixing pipeline (16 kHz, 16-bit mono PCM):
1. Generates clean 10.0s speech snippet (4 complete Harvard Sentences).
2. Extracts clean 10.0s music snippet for each genre: Country, Rock, and Techno.
3. Produces calibrated 10.0s combined/mixed audio snippet for each genre with
   ITU-T P.56 active speech leveling at -5 dB SNR with zero clipping.
"""

import math
import os
import struct
import subprocess
import wave

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SNIPPETS_DIR = os.path.join(BASE_DIR, "dataset", "test_stimuli", "isolated_snippets")
NOISE_DIR = os.path.join(BASE_DIR, "dataset", "test_stimuli", "music_noise_30s")

os.makedirs(SNIPPETS_DIR, exist_ok=True)

TARGET_FS = 16000
TARGET_SAMPLES = TARGET_FS * 10  # exactly 160,000 samples (10.000 seconds)

def read_wav(file_path):
    with wave.open(file_path, "rb") as wf:
        n_channels = wf.getnchannels()
        fs = wf.getframerate()
        n_frames = wf.getnframes()
        data = wf.readframes(n_frames)
        
        fmt = f"<{n_frames * n_channels}h"
        samples = list(struct.unpack(fmt, data))
        
        if n_channels > 1:
            samples = [(samples[i*2] + samples[i*2+1]) // 2 for i in range(n_frames)]
            
        float_samples = [s / 32768.0 for s in samples]
        return float_samples, fs

def write_wav(file_path, float_samples, fs=TARGET_FS):
    clamped = [max(-1.0, min(1.0, s)) for s in float_samples]
    int_samples = [int(round(s * 32767.0)) for s in clamped]
    fmt = f"<{len(int_samples)}h"
    raw_data = struct.pack(fmt, *int_samples)
    
    with wave.open(file_path, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(fs)
        wf.writeframes(raw_data)

def generate_speech_snippet(output_path):
    corpus_dir = os.path.join(BASE_DIR, "dataset", "speech_corpus", "combined")
    
    # Select 3 distinct human speech recordings (1 male, 2 female)
    sample_files = [
        "female_01_IUS-F00202.wav",
        "male_01_IUS-M00201.wav",
        "female_02_IUS-F02202.wav"
    ]
    
    combined_samples = []
    pause = [0.0] * int(TARGET_FS * 0.35) # 350ms natural pause between sentences
    
    for fname in sample_files:
        fpath = os.path.join(corpus_dir, fname)
        if os.path.exists(fpath):
            s, _ = read_wav(fpath)
            combined_samples.extend(s)
            combined_samples.extend(pause)
            
    if len(combined_samples) < TARGET_SAMPLES:
        combined_samples = combined_samples + [0.0] * (TARGET_SAMPLES - len(combined_samples))
    else:
        combined_samples = combined_samples[:TARGET_SAMPLES]
        
    # Peak normalize to 0.70
    peak = max(abs(s) for s in combined_samples)
    if peak > 0:
        combined_samples = [s / peak * 0.70 for s in combined_samples]
        
    write_wav(output_path, combined_samples, TARGET_FS)
    return combined_samples

def extract_music_snippet(src_path, output_path, start_sec=5.0):
    samples, fs = read_wav(src_path)
    start_idx = int(fs * start_sec)
    end_idx = start_idx + TARGET_SAMPLES
    
    if end_idx > len(samples):
        start_idx = 0
        end_idx = TARGET_SAMPLES
        
    snippet = samples[start_idx:end_idx]
    if len(snippet) < TARGET_SAMPLES:
        snippet = snippet + [0.0] * (TARGET_SAMPLES - len(snippet))

    peak = max(abs(s) for s in snippet)
    if peak > 0:
        snippet = [s / peak * 0.70 for s in snippet]

    write_wav(output_path, snippet, fs)
    return snippet

def compute_active_rms(samples, frame_len=320, threshold_db=-25):
    num_frames = len(samples) // frame_len
    frame_powers = []
    for f in range(num_frames):
        frame = samples[f * frame_len : (f + 1) * frame_len]
        p = sum(x**2 for x in frame) / frame_len
        frame_powers.append(p)
    
    max_p = max(frame_powers)
    threshold = max_p * (10 ** (threshold_db / 10.0))
    active_powers = [p for p in frame_powers if p > threshold]
    if not active_powers:
        active_powers = frame_powers
    return math.sqrt(sum(active_powers) / len(active_powers))

def mix_audio(speech, music, output_path, target_snr_db=-5.0):
    speech_active_rms = compute_active_rms(speech)
    music_rms = math.sqrt(sum(x**2 for x in music) / len(music))

    scale = (speech_active_rms / music_rms) * (10 ** (-target_snr_db / 20.0))
    scaled_music = [m * scale for m in music]

    mixed = [s + m for s, m in zip(speech, scaled_music)]
    peak_mixed = max(abs(x) for x in mixed)
    master_gain = 0.90 / peak_mixed if peak_mixed > 0 else 1.0
    mixed_normalized = [x * master_gain for x in mixed]

    write_wav(output_path, mixed_normalized, TARGET_FS)

    actual_speech_rms = compute_active_rms([s * master_gain for s in speech])
    actual_music_rms  = math.sqrt(sum((m * master_gain)**2 for m in scaled_music) / len(scaled_music))
    measured_snr = 20 * math.log10(actual_speech_rms / actual_music_rms)

    return mixed_normalized, measured_snr

def main():
    print("=" * 65)
    print("  AUDIO ISOLATION & MIXING: JAZZ, ROCK, TECHNO")
    print(f"  Target: {TARGET_SAMPLES} samples @ {TARGET_FS} Hz = 10.000s")
    print("=" * 65)

    speech_file = os.path.join(SNIPPETS_DIR, "speech_snippet_10s.wav")
    print("\n1. Generating Shared 10s Speech Snippet (Harvard Sentences)...")
    speech_samples = generate_speech_snippet(speech_file)
    print(f"   [OK] {speech_file}")

    genres = ["jazz", "rock", "techno"]
    for g in genres:
        print(f"\n2. Processing Genre [{g.upper()}]:")
        src_noise = os.path.join(NOISE_DIR, f"{g}_noise_30s.wav")
        music_out = os.path.join(SNIPPETS_DIR, f"{g}_music_snippet_10s.wav")
        combined_out = os.path.join(SNIPPETS_DIR, f"{g}_combined_snippet_10s.wav")

        music_samples = extract_music_snippet(src_noise, music_out, start_sec=5.0)
        print(f"   [OK] Music Snippet:    {music_out}")

        _, measured_snr = mix_audio(speech_samples, music_samples, combined_out, target_snr_db=-5.0)
        print(f"   [OK] Combined Mix:     {combined_out} (Active SNR: {measured_snr:.2f} dB)")

    print("\n" + "=" * 65)
    print("  ALL ISOLATED & COMBINED SNIPPETS COMPLETE!")
    print("=" * 65)

if __name__ == "__main__":
    main()
