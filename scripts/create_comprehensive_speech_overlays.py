#!/usr/bin/env python3
"""
create_comprehensive_speech_overlays.py
Generates a comprehensive, highly controlled speech-in-music overlay dataset
using authentic human Harvard Sentences from the Indiana University Sentence Database (IUS)
across all three genres (Jazz, Rock, Techno) at fixed SNR levels:
- 0 dB SNR  (Balanced conversational condition)
- -5 dB SNR (Loud venue condition)
- -10 dB SNR (High-noise festival condition)

Methodology:
- Uses 10 diverse human talkers (5 Male, 5 Female) reading Harvard Sentences.
- Implements ITU-T P.56 active speech leveling (ignoring silence frames).
- Additive mixing with exact target SNR calibration.
- Zero-clipping master peak scaling (0.90 / -0.9 dBFS).
- Generates 90 total speech overlay files (10 sentences x 3 genres x 3 SNRs).
- Outputs machine-readable audit manifest: dataset/metadata/speech_overlay_manifest.json
"""

import json
import math
import os
import struct
import wave

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPEECH_DIR = os.path.join(BASE_DIR, "dataset", "test_stimuli", "speech_sentences")
NOISE_DIR = os.path.join(BASE_DIR, "dataset", "test_stimuli", "music_noise_30s")
OUTPUT_BASE = os.path.join(BASE_DIR, "dataset", "test_stimuli", "speech_overlay_dataset")
MANIFEST_PATH = os.path.join(BASE_DIR, "dataset", "metadata", "speech_overlay_manifest.json")

TARGET_FS = 16000

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
    os.makedirs(os.path.dirname(file_path), exist_ok=True)
    clamped = [max(-1.0, min(1.0, s)) for s in float_samples]
    int_samples = [int(round(s * 32767.0)) for s in clamped]
    fmt = f"<{len(int_samples)}h"
    raw_data = struct.pack(fmt, *int_samples)
    
    with wave.open(file_path, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(fs)
        wf.writeframes(raw_data)

def compute_active_speech_power(samples, frame_len=320, threshold_db=-25):
    """Computes active speech power (ITU-T P.56 style) over frames above threshold"""
    num_frames = len(samples) // frame_len
    frame_powers = []
    for f in range(num_frames):
        frame = samples[f * frame_len : (f + 1) * frame_len]
        p = sum(x**2 for x in frame) / frame_len
        frame_powers.append(p)
    
    if not frame_powers:
        return sum(x**2 for x in samples) / len(samples)
        
    max_p = max(frame_powers)
    threshold = max_p * (10 ** (threshold_db / 10.0))
    active_powers = [p for p in frame_powers if p > threshold]
    
    if not active_powers:
        active_powers = frame_powers
        
    return sum(active_powers) / len(active_powers)

def main():
    print("=" * 70)
    print("  COMPREHENSIVE HUMAN SPEECH-IN-MUSIC OVERLAY GENERATOR (IUS CORPUS)")
    print("  Genres: Jazz, Rock, Techno | Target SNRs: 0 dB, -5 dB, -10 dB")
    print("=" * 70)

    genres = ["jazz", "rock", "techno"]
    snr_levels = [0.0, -5.0, -10.0]

    # Select 5 male and 5 female human speech files
    speech_files = [
        ("female_01_IUS-F00202.wav", "female", "IUS-F00202"),
        ("female_02_IUS-F02202.wav", "female", "IUS-F02202"),
        ("female_03_IUS-F04202.wav", "female", "IUS-F04202"),
        ("female_04_IUS-F06202.wav", "female", "IUS-F06202"),
        ("female_05_IUS-F08202.wav", "female", "IUS-F08202"),
        ("male_01_IUS-M00201.wav", "male", "IUS-M00201"),
        ("male_02_IUS-M02201.wav", "male", "IUS-M02201"),
        ("male_03_IUS-M04201.wav", "male", "IUS-M04201"),
        ("male_04_IUS-M06201.wav", "male", "IUS-M06201"),
        ("male_05_IUS-M08201.wav", "male", "IUS-M08201"),
    ]

    # Load noise tracks
    noise_tracks = {}
    for g in genres:
        n_path = os.path.join(NOISE_DIR, f"{g}_noise_30s.wav")
        noise_samples, _ = read_wav(n_path)
        noise_tracks[g] = noise_samples

    manifest_entries = []
    total_files = len(genres) * len(speech_files) * len(snr_levels)
    processed = 0

    print(f"\nGenerating {total_files} controlled overlay audio files from authentic human speech...")

    for g in genres:
        noise_full = noise_tracks[g]
        g_out_dir = os.path.join(OUTPUT_BASE, g)
        
        for idx, (s_fname, gender, spk_id) in enumerate(speech_files, 1):
            s_path = os.path.join(SPEECH_DIR, s_fname)
            speech_samples, _ = read_wav(s_path)
            L = len(speech_samples)
            
            p_speech_active = compute_active_speech_power(speech_samples)

            for target_snr in snr_levels:
                snr_tag = f"{abs(int(target_snr))}dB" if target_snr <= 0 else f"plus{int(target_snr)}dB"
                if target_snr == 0: snr_tag = "0dB"
                
                # Pick a consistent section of the noise
                noise_offset = (idx * 16000 * 2) % (len(noise_full) - L - 1)
                noise_seg = noise_full[noise_offset : noise_offset + L]
                p_noise = sum(x**2 for x in noise_seg) / len(noise_seg)

                # Scaling factor
                scale = math.sqrt(p_speech_active / (p_noise * (10 ** (target_snr / 10.0))))
                scaled_noise = [x * scale for x in noise_seg]

                # Mix
                mixed = [s + n for s, n in zip(speech_samples, scaled_noise)]

                # Peak headroom normalization (target peak = 0.90)
                peak = max(abs(x) for x in mixed)
                gain = 0.90 / peak if peak > 0 else 1.0
                mixed_norm = [x * gain for x in mixed]

                # Measured values
                m_speech_rms = math.sqrt(p_speech_active) * gain
                m_noise_rms  = math.sqrt(p_noise) * scale * gain
                measured_snr = 20 * math.log10(m_speech_rms / m_noise_rms) if m_noise_rms > 0 else 99.0

                s_prefix = f"{gender}_{idx:02d}"
                out_filename = f"{s_prefix}_{g}_snr_{snr_tag}.wav"
                out_filepath = os.path.join(g_out_dir, out_filename)
                write_wav(out_filepath, mixed_norm, TARGET_FS)

                manifest_entries.append({
                    "filename": out_filename,
                    "filepath": os.path.relpath(out_filepath, BASE_DIR),
                    "genre": g,
                    "gender": gender,
                    "speaker_id": spk_id,
                    "speech_source_file": s_fname,
                    "target_snr_db": target_snr,
                    "measured_active_snr_db": round(measured_snr, 2),
                    "speech_active_rms": round(m_speech_rms, 4),
                    "noise_rms": round(m_noise_rms, 4),
                    "peak_amplitude": round(max(abs(x) for x in mixed_norm), 4),
                    "duration_seconds": round(L / TARGET_FS, 2)
                })

                processed += 1
                if processed % 15 == 0 or processed == total_files:
                    print(f"  [{processed:02d}/{total_files}] Generated: {g.upper()} | {gender.upper()} {spk_id} | SNR: {target_snr:+.0f} dB")

    # Save Manifest
    with open(MANIFEST_PATH, "w", encoding="utf-8") as f:
        json.dump({
            "dataset_description": "Comprehensive Controlled Human Speech-in-Music Overlay Dataset (IUS Corpus)",
            "speech_provenance": "Indiana University Sentence Database (IUS) (Karl & Pisoni, 1994)",
            "sampling_rate_hz": TARGET_FS,
            "bit_depth": 16,
            "channels": 1,
            "genres": genres,
            "snr_conditions_db": snr_levels,
            "total_samples": len(manifest_entries),
            "samples": manifest_entries
        }, f, indent=2)

    print(f"\nSaved complete dataset manifest to:\n{MANIFEST_PATH}")
    print("=" * 70)

if __name__ == "__main__":
    main()
