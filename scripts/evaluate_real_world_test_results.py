#!/opt/anaconda3/bin/python3
"""
evaluate_real_world_test_results.py

Processes and evaluates the real-world acoustic test recordings in
Testing Results 07-10-26/outputs_cropped/ across all 576 conditions:
- 3 Environments: Full_Outside (Open air), Outside (Patio), Inside (Enclosed room)
- 4 Filter Topologies:
    * PASSTHROUGH (Raw microphone input / Unprocessed baseline)
    * CONTROL (Bandpass genre filter / FIR_BP)
    * MIXED (Parametric Notch + Leaky NLMS / Cascade_Notch_NLMS / Mode A)
    * OPTIMAL (Optimal Pre/Post Notch Cascade / Cascade_Hybrid_Optimal / Mode C)
- 4 SNR Tiers: 0 dB, -10 dB, -15 dB, -20 dB
- 6 Musical Stems: techno1, techno2, jazz1, jazz2, rock1, rock2
- 2 Speakers: SP1 (Male talker), SP2 (Female talker)

Computed Metrics:
1. STOI (Standard Objective Speech Intelligibility, fs=16kHz)
2. Delta STOI (STOI_filter - STOI_passthrough)
3. PESQ (Wideband ITU-T P.862.2 Speech Quality)
4. Delta SNR (Physical Noise Reduction vs PASSTHROUGH input)
5. Delta ASL (Active Speech Level shift)
6. Faster-Whisper Word Error Rate (WER %) & Word Recall Rate (% target words)
7. Google Cloud Speech-to-Text WER (%) & Word Recall Rate (% target words on SNR 0 and -10 dB subset)

Outputs:
- NLMS/output_audio/real_world_experiment/real_world_results.csv
- NLMS/output_audio/real_world_experiment/real_world_summary.csv
"""

import os
import re
import glob
import time
import string
import numpy as np
import soundfile as sf
from pystoi import stoi
from pesq import pesq
from faster_whisper import WhisperModel
import speech_recognition as sr

FS = 16000
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA_DIR = os.path.join(BASE_DIR, "Testing Results 07-10-26", "outputs_cropped")
OUTPUT_DIR = os.path.join(BASE_DIR, "NLMS", "output_audio", "real_world_experiment")
os.makedirs(OUTPUT_DIR, exist_ok=True)

GROUND_TRUTH_TEXT = "The bill was paid every third week"
TARGET_TOKENS = ["the", "bill", "was", "paid", "every", "third", "week"]
TOTAL_WORDS = len(TARGET_TOKENS)

def clean_text(text):
    """Normalize text: lowercase, remove punctuation, strip whitespace."""
    if not text:
        return ""
    text = text.lower()
    text = text.translate(str.maketrans("", "", string.punctuation))
    return re.sub(r"\s+", " ", text).strip()

def compute_wer(reference, hypothesis):
    """Standard Levenshtein Word Error Rate (WER %)."""
    ref_words = clean_text(reference).split()
    hyp_words = clean_text(hypothesis).split()
    R = len(ref_words)
    H = len(hyp_words)
    if R == 0:
        return 0.0 if H == 0 else 100.0

    dp = [[0] * (H + 1) for _ in range(R + 1)]
    for i in range(R + 1):
        dp[i][0] = i
    for j in range(H + 1):
        dp[0][j] = j

    for i in range(1, R + 1):
        for j in range(1, H + 1):
            if ref_words[i - 1] == hyp_words[j - 1]:
                dp[i][j] = dp[i - 1][j - 1]
            else:
                sub = dp[i - 1][j - 1] + 1
                ins = dp[i][j - 1] + 1
                delete = dp[i - 1][j] + 1
                dp[i][j] = min(sub, ins, delete)

    return (dp[R][H] / float(R)) * 100.0

def compute_word_recall(reference, hypothesis):
    """Fraction of ground-truth target words recognized."""
    ref_words = clean_text(reference).split()
    hyp_words = clean_text(hypothesis).split()
    if not ref_words:
        return 0.0
    ref_set = set(ref_words)
    hyp_set = set(hyp_words)
    recalled = ref_set.intersection(hyp_set)
    return (len(recalled) / float(len(ref_set))) * 100.0

def calculate_active_speech_level(sig, fs=16000, thresh_db=-25.0):
    """P.56 Active Speech Level approximation."""
    peak = np.max(np.abs(sig))
    if peak < 1e-9:
        return -100.0, 0.0
    thresh = peak * (10.0 ** (thresh_db / 20.0))
    act = sig[np.abs(sig) > thresh]
    if len(act) == 0:
        act = sig
    rms = np.sqrt(np.mean(act**2) + 1e-12)
    asl = 20.0 * np.log10(rms)
    return asl, float(len(act)) / float(len(sig))

def parse_filename(basename):
    """
    Format:
    Full_Outside_Pos1_CONTROL_PreConvON_SNR-10_jazz1_SP1.wav
    or Outside_Pos1_PASSTHROUGH_PreConvON_SNR0_rock2_SP2.wav
    """
    name = basename[:-4]
    parts = name.split("_")
    if parts[0] == "Full" and parts[1] == "Outside":
        venue = "Full_Outside"
        rem = parts[2:]
    else:
        venue = parts[0]
        rem = parts[1:]

    # rem: Pos1, FILTER, PreConvON, SNR-xx, song, SPx
    pos = rem[0]
    flt = rem[1]
    preconv = rem[2]
    snr_str = rem[3]
    snr_db = int(snr_str.replace("SNR", ""))
    song = rem[4]
    spk = rem[5]

    # Map genre from song
    if "techno" in song:
        genre = "techno"
    elif "jazz" in song:
        genre = "jazz"
    elif "rock" in song:
        genre = "rock"
    else:
        genre = "unknown"

    return {
        "venue": venue,
        "filter": flt,
        "snr_db": snr_db,
        "song": song,
        "genre": genre,
        "speaker": spk
    }

print("=" * 80)
print("  STARTING REAL-WORLD TESTING EVALUATION PIPELINE")
print("=" * 80)

# Initialize ASR Engines
print("--> Loading Faster-Whisper (small.en, INT8 CPU)...")
whisper_model = WhisperModel("small.en", device="cpu", compute_type="int8")
google_recognizer = sr.Recognizer()
print("✓ Faster-Whisper loaded successfully.")

# Gather test files
test_files = sorted(glob.glob(os.path.join(DATA_DIR, "*.wav")))
processed_files = [f for f in test_files if not f.endswith("_clean.wav")]
print(f"--> Found {len(processed_files)} processed real-world audio files to evaluate.\n")

# Pass 1: Measure baseline input SNRs and ASL for PASSTHROUGH files
print("--> Pass 1/2: Pre-computing PASSTHROUGH baseline references (SNR_in, STOI_in, ASL_in)...")
passthrough_baselines = {}

for fpath in processed_files:
    fname = os.path.basename(fpath)
    meta = parse_filename(fname)
    if meta["filter"] == "PASSTHROUGH":
        clean_path = fpath[:-4] + "_clean.wav"
        if not os.path.exists(clean_path):
            continue
        sig, _ = sf.read(fpath)
        clean, _ = sf.read(clean_path)
        L = min(len(sig), len(clean))
        sig, clean = sig[:L], clean[:L]

        # Calculate SNR_in
        res = sig - clean
        p_clean = np.mean(clean**2)
        p_noise = np.mean(res**2) + 1e-12
        snr_in = 10.0 * np.log10(p_clean / p_noise)
        stoi_in = stoi(clean, sig, FS, extended=False)
        asl_in, _ = calculate_active_speech_level(sig, FS)

        cond_key = (meta["venue"], meta["snr_db"], meta["song"], meta["speaker"])
        passthrough_baselines[cond_key] = {
            "snr_in": snr_in,
            "stoi_in": stoi_in,
            "asl_in": asl_in
        }

print(f"✓ Calculated baselines for {len(passthrough_baselines)} distinct acoustic conditions.\n")

# Pass 2: Evaluate All 576 Files
print("--> Pass 2/2: Computing STOI, PESQ, Delta SNR, and ASR Intelligibility...")
raw_results = []
summary_map = {}

raw_csv_path = os.path.join(OUTPUT_DIR, "real_world_results.csv")
raw_csv = open(raw_csv_path, "w", encoding="utf-8")
raw_csv.write("Venue,Genre,Song,SNR_dB,Speaker,Filter_Name,STOI,Delta_STOI,PESQ,SNR_out_dB,Delta_SNR_dB,Delta_ASL_dB,Whisper_Transcript,Whisper_WER,Whisper_Recall,Google_Transcript,Google_WER,Google_Recall\n")

total_start = time.time()

for idx, fpath in enumerate(processed_files):
    fname = os.path.basename(fpath)
    meta = parse_filename(fname)
    clean_path = fpath[:-4] + "_clean.wav"

    if not os.path.exists(clean_path):
        print(f"Warning: Clean reference missing for {fname}")
        continue

    sig, _ = sf.read(fpath)
    clean, _ = sf.read(clean_path)
    L = min(len(sig), len(clean))
    sig, clean = sig[:L], clean[:L]

    cond_key = (meta["venue"], meta["snr_db"], meta["song"], meta["speaker"])
    base = passthrough_baselines.get(cond_key, {"snr_in": 0.0, "stoi_in": 0.0, "asl_in": 0.0})

    # 1. STOI
    s_stoi = stoi(clean, sig, FS, extended=False)
    d_stoi = s_stoi - base["stoi_in"] if meta["filter"] != "PASSTHROUGH" else 0.0

    # 2. PESQ (Wideband)
    try:
        p_pesq = pesq(FS, clean, sig, "wb")
    except Exception:
        p_pesq = 1.0

    # 3. Delta SNR
    res_noise = sig - clean
    snr_out = 10.0 * np.log10(np.mean(clean**2) / (np.mean(res_noise**2) + 1e-12))
    d_snr = snr_out - base["snr_in"] if meta["filter"] != "PASSTHROUGH" else 0.0
    d_snr = float(np.clip(d_snr, -15.0, 30.0))

    # 4. Delta ASL
    asl_out, _ = calculate_active_speech_level(sig, FS)
    d_asl = asl_out - base["asl_in"]

    # 5. Faster-Whisper ASR
    w_segs, _ = whisper_model.transcribe(fpath)
    w_text = clean_text(" ".join([s.text for s in w_segs]))
    if not w_text:
        w_text = "[NO_SPEECH_DETECTED]"
        w_wer = 100.0
        w_recall = 0.0
    else:
        w_wer = compute_wer(GROUND_TRUTH_TEXT, w_text)
        w_recall = compute_word_recall(GROUND_TRUTH_TEXT, w_text)

    # 6. Google Cloud STT (Evaluated on SNR 0 and -10 dB subset)
    g_text = "[OMITTED_LOW_SNR]"
    g_wer = -1.0
    g_recall = -1.0

    if meta["snr_db"] in [0, -10]:
        try:
            with sr.AudioFile(fpath) as source:
                audio = google_recognizer.record(source)
            g_raw = google_recognizer.recognize_google(audio)
            g_text = clean_text(g_raw)
            g_wer = compute_wer(GROUND_TRUTH_TEXT, g_text)
            g_recall = compute_word_recall(GROUND_TRUTH_TEXT, g_text)
        except sr.UnknownValueError:
            g_text = "[NO_SPEECH_DETECTED]"
            g_wer = 100.0
            g_recall = 0.0
        except Exception as e:
            g_text = f"[API_ERROR: {e}]"
            g_wer = 100.0
            g_recall = 0.0

    # Write raw record
    g_wer_str = f"{g_wer:.2f}" if g_wer >= 0 else "N/A"
    g_rec_str = f"{g_recall:.2f}" if g_recall >= 0 else "N/A"
    w_clean_text = w_text.replace(",", ";")
    g_clean_text = g_text.replace(",", ";")

    raw_csv.write(f"{meta['venue']},{meta['genre']},{meta['song']},{meta['snr_db']},{meta['speaker']},{meta['filter']},{s_stoi:.4f},{d_stoi:.4f},{p_pesq:.4f},{snr_out:.2f},{d_snr:.2f},{d_asl:.2f},\"{w_clean_text}\",{w_wer:.2f},{w_recall:.2f},\"{g_clean_text}\",{g_wer_str},{g_rec_str}\n")

    # Accumulate for aggregated summary
    sum_key = (meta["venue"], meta["genre"], meta["snr_db"], meta["filter"])
    if sum_key not in summary_map:
        summary_map[sum_key] = {
            "stoi": [], "dstoi": [], "pesq": [], "dsnr": [], "dasl": [],
            "w_wer": [], "w_rec": [], "g_wer": [], "g_rec": []
        }
    summary_map[sum_key]["stoi"].append(s_stoi)
    summary_map[sum_key]["dstoi"].append(d_stoi)
    summary_map[sum_key]["pesq"].append(p_pesq)
    summary_map[sum_key]["dsnr"].append(d_snr)
    summary_map[sum_key]["dasl"].append(d_asl)
    summary_map[sum_key]["w_wer"].append(w_wer)
    summary_map[sum_key]["w_rec"].append(w_recall)
    if g_wer >= 0:
        summary_map[sum_key]["g_wer"].append(g_wer)
        summary_map[sum_key]["g_rec"].append(g_recall)

    if (idx + 1) % 50 == 0 or (idx + 1) == len(processed_files):
        print(f"  Processed {idx + 1} / {len(processed_files)} trials ({time.time() - total_start:.1f}s)...")

raw_csv.close()
print(f"\n✓ Completed all {len(processed_files)} trials in {time.time() - total_start:.2f} seconds.")
print(f"✓ Saved raw trial results to: {raw_csv_path}")

# -------------------------------------------------------------------------
# Build Aggregated Summary CSV
# -------------------------------------------------------------------------
summary_csv_path = os.path.join(OUTPUT_DIR, "real_world_summary.csv")
with open(summary_csv_path, "w", encoding="utf-8") as sf_out:
    sf_out.write("Venue,Genre,SNR_dB,Filter_Name,Mean_STOI,Mean_Delta_STOI,Mean_PESQ,Mean_Delta_SNR_dB,Mean_Delta_ASL_dB,Mean_Whisper_WER,Mean_Whisper_Recall,Mean_Google_WER,Mean_Google_Recall\n")
    for k in sorted(summary_map.keys()):
        v, g, s, f = k
        m_stoi = np.mean(summary_map[k]["stoi"])
        m_dstoi = np.mean(summary_map[k]["dstoi"])
        m_pesq = np.mean(summary_map[k]["pesq"])
        m_dsnr = np.mean(summary_map[k]["dsnr"])
        m_dasl = np.mean(summary_map[k]["dasl"])
        m_wwer = np.mean(summary_map[k]["w_wer"])
        m_wrec = np.mean(summary_map[k]["w_rec"])
        m_gwer = np.mean(summary_map[k]["g_wer"]) if summary_map[k]["g_wer"] else -1.0
        m_grec = np.mean(summary_map[k]["g_rec"]) if summary_map[k]["g_rec"] else -1.0

        gw_str = f"{m_gwer:.2f}" if m_gwer >= 0 else "N/A"
        gr_str = f"{m_grec:.2f}" if m_grec >= 0 else "N/A"

        sf_out.write(f"{v},{g},{s},{f},{m_stoi:.4f},{m_dstoi:.4f},{m_pesq:.4f},{m_dsnr:.2f},{m_dasl:.2f},{m_wwer:.2f},{m_wrec:.2f},{gw_str},{gr_str}\n")

print(f"✓ Saved aggregated summary to: {summary_csv_path}")
print("=" * 80)
