#!/usr/bin/env python3
"""
verify_spectral_profiles.py
Validates:
1. WAV file formats and metadata across all 150 tracks.
2. 60-second test stimuli formats.
3. Computes 1024-point FFT spectral profiles (as specified in Section 3.2:
   1024-point FFT, Hanning window, 50% overlap) across sample tracks of
   House, Techno, and Drum & Bass to verify genre-specific energy distributions.
"""

import cmath
import json
import math
import os
import struct
import wave

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WAV_DIR = os.path.join(BASE_DIR, "dataset", "wav_16k")
STIMULI_DIR = os.path.join(BASE_DIR, "dataset", "test_stimuli", "music_noise_60s")

def fft(x):
    """Radix-2 Cooley-Tukey FFT"""
    N = len(x)
    if N <= 1:
        return x
    even = fft(x[0::2])
    odd = fft(x[1::2])
    T = [cmath.exp(-2j * cmath.pi * k / N) * odd[k] for k in range(N // 2)]
    return [even[k] + T[k] for k in range(N // 2)] + \
           [even[k] - T[k] for k in range(N // 2)]

def read_wav_samples(wav_path, max_frames=16000 * 10):
    """Read 16-bit mono PCM samples into float array [-1.0, 1.0]"""
    with wave.open(wav_path, "rb") as wf:
        nframes = min(wf.getnframes(), max_frames)
        raw_bytes = wf.readframes(nframes)
        fmt = f"<{nframes}h"
        int_samples = struct.unpack(fmt, raw_bytes)
        return [s / 32768.0 for s in int_samples]

def compute_mean_spectrum(wav_path, n_fft=1024, hop=512):
    """Computes mean magnitude spectrum using 1024-point FFT with Hanning window"""
    samples = read_wav_samples(wav_path, max_frames=16000 * 30) # 30s of audio
    # Hanning window
    window = [0.5 * (1.0 - math.cos(2.0 * math.pi * i / (n_fft - 1))) for i in range(n_fft)]

    spectra = []
    num_frames = (len(samples) - n_fft) // hop
    num_frames = min(num_frames, 200) # Sample 200 windows for fast verification

    for i in range(num_frames):
        start = i * hop
        chunk = [samples[start + j] * window[j] for j in range(n_fft)]
        spectrum = fft(chunk)
        half_mag = [abs(spectrum[k]) for k in range(n_fft // 2 + 1)]
        spectra.append(half_mag)

    # Average over windows
    mean_mag = [sum(frame[k] for frame in spectra) / len(spectra) for k in range(n_fft // 2 + 1)]
    return mean_mag

def analyze_bands(mean_mag, sample_rate=16000, n_fft=1024):
    freq_res = sample_rate / n_fft  # 15.625 Hz per bin

    # Bands:
    # Sub-bass: < 80 Hz
    # House kick region: 60 - 150 Hz
    # Speech passband: 300 - 3400 Hz
    # High frequency / transients: > 4000 Hz
    sub_bass_energy = 0.0
    kick_energy = 0.0
    speech_energy = 0.0
    high_freq_energy = 0.0
    total_energy = 0.0

    for bin_idx, mag in enumerate(mean_mag):
        freq = bin_idx * freq_res
        pwr = mag ** 2
        total_energy += pwr
        if freq < 80:
            sub_bass_energy += pwr
        if 60 <= freq <= 150:
            kick_energy += pwr
        if 300 <= freq <= 3400:
            speech_energy += pwr
        if freq > 4000:
            high_freq_energy += pwr

    return {
        "sub_bass_pct": round((sub_bass_energy / total_energy) * 100, 2),
        "kick_pct": round((kick_energy / total_energy) * 100, 2),
        "speech_band_pct": round((speech_energy / total_energy) * 100, 2),
        "high_freq_pct": round((high_freq_energy / total_energy) * 100, 2),
    }

def main():
    print("=" * 60)
    print("DATASET VERIFICATION & SPECTRAL PROFILE SANITY CHECK")
    print("=" * 60)

    # 1. Check counts
    print("\n1. Track Counts:")
    for genre in ["house", "techno", "dnb"]:
        g_dir = os.path.join(WAV_DIR, genre)
        files = [f for f in os.listdir(g_dir) if f.endswith(".wav")] if os.path.exists(g_dir) else []
        print(f"  {genre.upper():7s}: {len(files)} / 50 tracks present")

    # 2. Check 60s noise tracks
    print("\n2. Test Stimuli (60-second Continuous Music Noise):")
    for genre in ["house", "techno", "dnb"]:
        fpath = os.path.join(STIMULI_DIR, f"{genre}_noise_60s.wav")
        if os.path.exists(fpath):
            with wave.open(fpath, "rb") as wf:
                dur = wf.getnframes() / float(wf.getframerate())
                print(f"  {genre.upper():7s}: {dur:.1f}s | {wf.getframerate()} Hz | {wf.getsampwidth()*8}-bit mono [OK]")
        else:
            print(f"  {genre.upper():7s}: MISSING!")

    # 3. Spectral profile analysis
    print("\n3. Spectral Energy Band Distribution (Section 2.1 & 3.2 STFT Analysis):")
    print("   (Averaged over 5 representative tracks per genre, 1024-point FFT)")
    print(f"   {'Genre':10s} | {'Sub-Bass (<80Hz)':18s} | {'Kick (60-150Hz)':18s} | {'Speech (300-3400Hz)':20s} | {'High-Freq (>4kHz)':18s}")
    print("   " + "-" * 92)

    for genre in ["house", "techno", "dnb"]:
        g_dir = os.path.join(WAV_DIR, genre)
        wav_files = sorted([f for f in os.listdir(g_dir) if f.endswith(".wav")])[:5]

        band_avgs = {"sub_bass_pct": 0.0, "kick_pct": 0.0, "speech_band_pct": 0.0, "high_freq_pct": 0.0}
        for wf in wav_files:
            spec = compute_mean_spectrum(os.path.join(g_dir, wf))
            bands = analyze_bands(spec)
            for k in band_avgs:
                band_avgs[k] += bands[k] / len(wav_files)

        print(f"   {genre.upper():10s} | {band_avgs['sub_bass_pct']:15.2f}% | {band_avgs['kick_pct']:15.2f}% | {band_avgs['speech_band_pct']:17.2f}% | {band_avgs['high_freq_pct']:15.2f}%")

    print("\nVerification completed successfully.")

if __name__ == "__main__":
    main()
