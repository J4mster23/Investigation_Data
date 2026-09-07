#!/usr/bin/env python3
"""
download_and_convert.py
Downloads the 150 curated GiantSteps tracks (50 House, 50 Techno, 50 DnB)
and converts each to 16 kHz, 16-bit mono PCM WAV using macOS afconvert.
"""

import concurrent.futures
import json
import os
import subprocess
import sys
import time
import urllib.request
import wave
import ssl

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
METADATA_PATH = os.path.join(BASE_DIR, "dataset", "metadata", "selected_tracks.json")
RAW_DIR = os.path.join(BASE_DIR, "dataset", "raw_mp3")
WAV_DIR = os.path.join(BASE_DIR, "dataset", "wav_16k")

MAX_WORKERS = 8
USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko)"

SSL_CONTEXT = ssl._create_unverified_context()

def download_file(urls, destination):
    if os.path.exists(destination) and os.path.getsize(destination) > 10000:
        return True, "already_exists"

    os.makedirs(os.path.dirname(destination), exist_ok=True)
    last_err = None

    for url in urls:
        try:
            req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(req, context=SSL_CONTEXT, timeout=20) as resp:
                if resp.status == 200:
                    data = resp.read()
                    if len(data) > 10000:
                        with open(destination, "wb") as f:
                            f.write(data)
                        return True, "downloaded"
        except Exception as e:
            last_err = e
            time.sleep(0.5)

    return False, str(last_err)

def convert_to_16k_wav(mp3_path, wav_path):
    if os.path.exists(wav_path) and os.path.getsize(wav_path) > 10000:
        return True, "already_converted"

    os.makedirs(os.path.dirname(wav_path), exist_ok=True)

    # Use macOS native afconvert to convert MP3 to 16kHz, 16-bit Little-Endian Integer PCM, 1 channel (mono)
    cmd = [
        "/usr/bin/afconvert",
        "-f", "WAVE",
        "-d", "LEI16@16000",
        "-c", "1",
        mp3_path,
        wav_path
    ]

    try:
        res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
        return True, "converted"
    except subprocess.CalledProcessError as e:
        return False, e.stderr.decode("utf-8", errors="replace")

def validate_wav(wav_path):
    try:
        with wave.open(wav_path, "rb") as wf:
            channels = wf.getnchannels()
            sample_width = wf.getsampwidth()
            framerate = wf.getframerate()
            frames = wf.getnframes()
            duration = frames / float(framerate)

            is_valid = (channels == 1 and sample_width == 2 and framerate == 16000 and duration > 10.0)
            return is_valid, {
                "channels": channels,
                "bit_depth": sample_width * 8,
                "sample_rate": framerate,
                "duration_sec": round(duration, 2)
            }
    except Exception as e:
        return False, str(e)

def process_track(track_info, genre):
    mp3_dest = os.path.join(RAW_DIR, genre, track_info["filename_mp3"])
    wav_dest = os.path.join(WAV_DIR, genre, track_info["filename_wav"])

    # 1. Download MP3
    dl_ok, dl_msg = download_file(track_info["urls"], mp3_dest)
    if not dl_ok:
        return {
            "track_id": track_info["track_id"],
            "genre": genre,
            "status": "download_failed",
            "error": dl_msg
        }

    # 2. Convert to 16k WAV
    cv_ok, cv_msg = convert_to_16k_wav(mp3_dest, wav_dest)
    if not cv_ok:
        return {
            "track_id": track_info["track_id"],
            "genre": genre,
            "status": "conversion_failed",
            "error": cv_msg
        }

    # 3. Validate WAV
    val_ok, val_meta = validate_wav(wav_dest)
    if not val_ok:
        return {
            "track_id": track_info["track_id"],
            "genre": genre,
            "status": "validation_failed",
            "error": str(val_meta)
        }

    return {
        "track_id": track_info["track_id"],
        "genre": genre,
        "status": "success",
        "mp3_size_bytes": os.path.getsize(mp3_dest),
        "wav_size_bytes": os.path.getsize(wav_dest),
        "wav_metadata": val_meta
    }

def main():
    if not os.path.exists(METADATA_PATH):
        print(f"Error: Manifest not found at {METADATA_PATH}. Run build_dataset_manifest.py first.")
        sys.exit(1)

    with open(METADATA_PATH, "r", encoding="utf-8") as f:
        manifest = json.load(f)

    tasks = []
    for genre, track_list in manifest["genres"].items():
        for t in track_list:
            tasks.append((t, genre))

    total = len(tasks)
    print(f"Starting acquisition & conversion of {total} tracks using {MAX_WORKERS} threads...")

    completed = 0
    failures = []
    results = []

    start_time = time.time()
    with concurrent.futures.ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
        future_to_task = {executor.submit(process_track, t, g): (t, g) for t, g in tasks}
        for future in concurrent.futures.as_completed(future_to_task):
            completed += 1
            res = future.result()
            results.append(res)

            status = res["status"]
            tid = res["track_id"]
            genre = res["genre"]

            if status == "success":
                dur = res["wav_metadata"]["duration_sec"]
                print(f"[{completed}/{total}] [OK] {genre.upper()}: Track {tid} ({dur}s, 16kHz/16-bit mono)")
            else:
                failures.append(res)
                print(f"[{completed}/{total}] [FAIL] {genre.upper()}: Track {tid} - {res['error']}")

    elapsed = round(time.time() - start_time, 1)
    print(f"\nCompleted in {elapsed}s.")
    print(f"Successes: {total - len(failures)} / {total}")
    print(f"Failures: {len(failures)}")

    summary_path = os.path.join(BASE_DIR, "dataset", "metadata", "acquisition_summary.json")
    with open(summary_path, "w", encoding="utf-8") as f:
        json.dump({
            "total": total,
            "success_count": total - len(failures),
            "failure_count": len(failures),
            "elapsed_seconds": elapsed,
            "results": results
        }, f, indent=2)

    if failures:
        sys.exit(1)

if __name__ == "__main__":
    main()
