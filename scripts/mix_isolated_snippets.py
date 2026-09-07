#!/usr/bin/env python3
"""
mix_isolated_snippets.py
Pure Python audio isolation and calibrated mixing pipeline (16 kHz, 16-bit mono PCM):
1. Generates a clean 10.0s speech snippet (4 complete Harvard Sentences).
2. Extracts a clean 10.0s music snippet from the high-energy Techno groove (seconds 10-20).
3. Produces a calibrated 10.0s combined/mixed audio snippet with active speech leveling
   at a realistic loud festival SNR (-4 dB) with zero clipping.
"""

import math
import os
import struct
import subprocess
import wave

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SNIPPETS_DIR = os.path.join(BASE_DIR, "dataset", "test_stimuli", "isolated_snippets")
TECHNO_FILE = os.path.join(BASE_DIR, "dataset", "test_stimuli", "music_noise_60s", "techno_noise_60s.wav")

os.makedirs(SNIPPETS_DIR, exist_ok=True)

TARGET_FS = 16000
TARGET_SAMPLES = TARGET_FS * 10  # exactly 160,000 samples (10.000 seconds)

def read_wav(file_path):
    with wave.open(file_path, "rb") as wf:
        n_channels = wf.getnchannels()
        sampwidth = wf.getsampwidth()
        fs = wf.getframerate()
        n_frames = wf.getnframes()
        data = wf.readframes(n_frames)
        
        fmt = f"<{n_frames * n_channels}h"
        samples = list(struct.unpack(fmt, data))
        
        # Downmix to mono if stereo
        if n_channels > 1:
            samples = [(samples[i*2] + samples[i*2+1]) // 2 for i in range(n_frames)]
            
        # Float normalized [-1.0, 1.0]
        float_samples = [s / 32768.0 for s in samples]
        return float_samples, fs

def write_wav(file_path, float_samples, fs=TARGET_FS):
    # Clamp to [-1.0, 1.0]
    clamped = [max(-1.0, min(1.0, s)) for s in float_samples]
    int_samples = [int(round(s * 32767.0)) for s in clamped]
    fmt = f"<{len(int_samples)}h"
    raw_data = struct.pack(fmt, *int_samples)
    
    with wave.open(file_path, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)  # 16-bit
        wf.setframerate(fs)
        wf.writeframes(raw_data)

def generate_speech_snippet(output_path):
    """Synthesizes 4 Harvard sentences timed to finish cleanly at ~9.9s and padded to exactly 10.0s"""
    text = (
        "The birch canoe slid on the smooth planks. "
        "Glue the sheet to the dark blue background. "
        "It is easy to tell the depth of a well. "
        "Four hours of steady work faced us."
    )
    temp_aiff = os.path.join(SNIPPETS_DIR, "temp_speech.aiff")
    temp_wav  = os.path.join(SNIPPETS_DIR, "temp_speech.wav")

    # Samantha natural rate
    subprocess.run(["/usr/bin/say", "-v", "Samantha", "-r", "150", "-o", temp_aiff, text], check=True)
    subprocess.run(["/usr/bin/afconvert", "-f", "WAVE", "-d", "LEI16@16000", "-c", "1", temp_aiff, temp_wav], check=True)

    samples, fs = read_wav(temp_wav)
    if os.path.exists(temp_aiff): os.remove(temp_aiff)
    if os.path.exists(temp_wav): os.remove(temp_wav)

    # Adjust to exactly 160,000 samples
    if len(samples) < TARGET_SAMPLES:
        samples = samples + [0.0] * (TARGET_SAMPLES - len(samples))
    else:
        samples = samples[:TARGET_SAMPLES]

    # Normalize speech peak to 0.70 (-3 dBFS)
    peak = max(abs(s) for s in samples)
    if peak > 0:
        samples = [s / peak * 0.70 for s in samples]

    write_wav(output_path, samples, fs)
    return samples

def extract_music_snippet(output_path):
    """Extracts exactly 10.0s of driving Techno kick & sub-bass (seconds 10.0 to 20.0)"""
    samples, fs = read_wav(TECHNO_FILE)
    
    start_idx = fs * 10  # 10.0 seconds in (full energetic groove)
    end_idx   = start_idx + TARGET_SAMPLES
    snippet   = samples[start_idx:end_idx]

    # Normalize music peak to 0.70 (-3 dBFS)
    peak = max(abs(s) for s in snippet)
    if peak > 0:
        snippet = [s / peak * 0.70 for s in snippet]

    write_wav(output_path, snippet, fs)
    return snippet

def compute_active_rms(samples, frame_len=320, threshold_db=-25):
    """Computes RMS over active speech frames (> -25 dB of peak frame) per ITU-T P.56"""
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

def mix_audio(speech, music, output_path, target_snr_db=-4.0):
    """Mixes speech and music at a calibrated target SNR with master peak limiting"""
    speech_active_rms = compute_active_rms(speech)
    music_rms = math.sqrt(sum(x**2 for x in music) / len(music))

    # Calculate noise scaling factor
    # SNR_db = 20 * log10(speech_active_rms / (scale * music_rms))
    # => scale = (speech_active_rms / music_rms) * 10^(-SNR_db / 20)
    scale = (speech_active_rms / music_rms) * (10 ** (-target_snr_db / 20.0))
    scaled_music = [m * scale for m in music]

    # Additive mixing
    mixed = [s + m for s, m in zip(speech, scaled_music)]

    # Master gain: scale so combined peak is at 0.90 (-0.9 dBFS) with zero clipping
    peak_mixed = max(abs(x) for x in mixed)
    master_gain = 0.90 / peak_mixed
    mixed_normalized = [x * master_gain for x in mixed]

    write_wav(output_path, mixed_normalized, TARGET_FS)

    # Actual measurements
    actual_speech_rms = compute_active_rms([s * master_gain for s in speech])
    actual_music_rms  = math.sqrt(sum((m * master_gain)**2 for m in scaled_music) / len(scaled_music))
    measured_snr = 20 * math.log10(actual_speech_rms / actual_music_rms)

    return mixed_normalized, measured_snr

def main():
    print("=" * 65)
    print("  AUDIO ISOLATION & CALIBRATED MIXING PIPELINE (PURE PYTHON)")
    print(f"  Target: {TARGET_SAMPLES} samples @ {TARGET_FS} Hz = 10.000 seconds")
    print("=" * 65)

    speech_file   = os.path.join(SNIPPETS_DIR, "speech_snippet_10s.wav")
    music_file    = os.path.join(SNIPPETS_DIR, "music_snippet_10s.wav")
    combined_file = os.path.join(SNIPPETS_DIR, "combined_snippet_10s.wav")

    # 1. Speech snippet
    print("\n1. Generating 10s Speech Snippet (Harvard Sentences)...")
    speech_samples = generate_speech_snippet(speech_file)
    dur_sp = len(speech_samples) / TARGET_FS
    peak_sp = max(abs(x) for x in speech_samples)
    rms_sp = compute_active_rms(speech_samples)
    print(f"   Saved: {speech_file}")
    print(f"   Duration: {dur_sp:.3f}s | Peak: {peak_sp:.3f} | Active RMS: {rms_sp:.3f}")

    # 2. Music snippet
    print("\n2. Extracting 10s Music Snippet (Techno seconds 10-20)...")
    music_samples = extract_music_snippet(music_file)
    dur_mu = len(music_samples) / TARGET_FS
    peak_mu = max(abs(x) for x in music_samples)
    rms_mu = math.sqrt(sum(x**2 for x in music_samples) / len(music_samples))
    print(f"   Saved: {music_file}")
    print(f"   Duration: {dur_mu:.3f}s | Peak: {peak_mu:.3f} | Full RMS: {rms_mu:.3f}")

    # 3. Combined mix
    print("\n3. Mixing Combined 10s Snippet (Calibrated Festival Level: -4 dB SNR)...")
    combined_samples, actual_snr = mix_audio(speech_samples, music_samples, combined_file, target_snr_db=-4.0)
    dur_comb = len(combined_samples) / TARGET_FS
    peak_comb = max(abs(x) for x in combined_samples)
    print(f"   Saved: {combined_file}")
    print(f"   Duration: {dur_comb:.3f}s | Peak: {peak_comb:.3f} | Measured Active SNR: {actual_snr:.2f} dB")

    print("\n" + "=" * 65)
    print("  ALL 3 AUDIO SNIPPETS READY FOR VERIFICATION!")
    print("=" * 65)

if __name__ == "__main__":
    main()
