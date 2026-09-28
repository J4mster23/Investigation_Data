#!/usr/bin/env python3
"""
evaluate_google_stt_intelligibility.py
Evaluates speech intelligibility using Google's Speech-to-Text (STT) API
by comparing recognized words before and after filtering against the
Harvard Sentences ground truth transcripts.

Captures to CSV:
- Actual STT Response string (and [NO_SPEECH_DETECTED] when rejected)
- Google API Confidence score
- Candidate alternative hypotheses
- Merged DSP metrics: STOI, PESQ, Delta SNR
- Word Accuracy / Word Recall Rate (WAcc %)
- Word Error Rate (WER %) via Levenshtein distance
"""

import os
import re
import csv
import json
import glob
import string
import time
import speech_recognition as sr

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
METADATA_DIR = os.path.join(BASE_DIR, "dataset", "metadata")
OUTPUT_DIR = os.path.join(BASE_DIR, "NLMS", "output_audio", "room_experiment")
SAMPLES_DIR = os.path.join(OUTPUT_DIR, "samples")
ROOM_EXP_CSV = os.path.join(OUTPUT_DIR, "room_experiment_results.csv")
RESULTS_CSV = os.path.join(OUTPUT_DIR, "google_stt_evaluation_results.csv")

FILTER_MAP = {
    "primary_noisy": "Unprocessed",
    "fir_bp": "FIR_BP",
    "notch": "Parametric_Notch",
    "base_nlms": "Base_NLMS",
    "soft_vad_leaky": "Soft_VAD_Leaky"
}

def clean_text(text):
    """Normalize text: lowercase, remove punctuation, strip whitespace."""
    if not text:
        return ""
    text = text.lower()
    text = text.translate(str.maketrans("", "", string.punctuation))
    return re.sub(r"\s+", " ", text).strip()

def compute_wer(reference, hypothesis):
    """
    Computes standard Word Error Rate (WER) using Levenshtein distance:
    WER = (Substitutions + Deletions + Insertions) / Total Reference Words
    """
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
                
    wer = (dp[R][H] / float(R)) * 100.0
    return wer

def compute_word_recall(reference, hypothesis):
    """
    Computes the fraction of ground-truth reference words correctly spotted.
    """
    ref_words = clean_text(reference).split()
    hyp_words = clean_text(hypothesis).split()
    
    if not ref_words:
        return 0, 0, 0.0
        
    ref_set = set(ref_words)
    hyp_set = set(hyp_words)
    
    unique_recalled = ref_set.intersection(hyp_set)
    recall_pct = (len(unique_recalled) / float(len(ref_set))) * 100.0
    return len(unique_recalled), len(ref_set), recall_pct

def recognize_audio_google(r, audio_path, retries=2):
    """Transcribes audio file via Google Speech Recognition with show_all=True."""
    for attempt in range(retries):
        try:
            with sr.AudioFile(audio_path) as source:
                audio = r.record(source)
            raw_resp = r.recognize_google(audio, show_all=True)
            if not raw_resp or not isinstance(raw_resp, dict) or "alternative" not in raw_resp:
                return "[NO_SPEECH_DETECTED]", "NO_SPEECH_DETECTED", 0.0, []
            
            alts = raw_resp.get("alternative", [])
            if not alts:
                return "[NO_SPEECH_DETECTED]", "NO_SPEECH_DETECTED", 0.0, []
                
            top_entry = alts[0]
            top_text = clean_text(top_entry.get("transcript", ""))
            confidence = round(float(top_entry.get("confidence", 0.0)), 4)
            alt_transcripts = [clean_text(a.get("transcript", "")) for a in alts if "transcript" in a]
            
            return top_text, "OK", confidence, alt_transcripts
        except sr.UnknownValueError:
            return "[NO_SPEECH_DETECTED]", "NO_SPEECH_DETECTED", 0.0, []
        except sr.RequestError as e:
            if attempt < retries - 1:
                time.sleep(1.0)
                continue
            return f"[API_ERROR: {e}]", f"API_ERROR: {e}", 0.0, []
        except Exception as e:
            return f"[ERROR: {e}]", f"ERROR: {e}", 0.0, []
    return "[UNKNOWN_ERROR]", "UNKNOWN_ERROR", 0.0, []

def load_dsp_metrics():
    """Loads matching STOI, PESQ, and Delta SNR from room_experiment_results.csv."""
    lookup = {}
    if not os.path.exists(ROOM_EXP_CSV):
        return lookup
    with open(ROOM_EXP_CSV, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            key = (row["Venue"], row["Genre"], row["File"], int(row["SNR_dB"]), row["Filter"])
            lookup[key] = {
                "STOI": float(row["STOI"]),
                "PESQ": float(row["PESQ"]),
                "dSNR_dB": float(row["dSNR_dB"]),
                "dASL_dB": float(row["dASL_dB"])
            }
    return lookup

def main():
    print("=" * 80)
    print("  GOOGLE SPEECH-TO-TEXT (STT) INTELLIGIBILITY EVALUATION")
    print("  Auditing Harvard Sentences Recognition: Before vs. After Filtering")
    print("=" * 80)

    ground_truth = "The bill was paid every third week"
    ref_words_total = len(clean_text(ground_truth).split())
    audio_file_name = "female_01_IUS-F00202.wav"
    
    print(f"\nGround Truth Harvard Sentence: \"{ground_truth}\" ({ref_words_total} words)\n")

    r = sr.Recognizer()
    wav_files = sorted(glob.glob(os.path.join(SAMPLES_DIR, "*.wav")))

    if not wav_files:
        print(f"Error: No sample WAV files found in {SAMPLES_DIR}")
        return

    dsp_lookup = load_dsp_metrics()
    print(f"Loaded {len(dsp_lookup)} objective DSP benchmark records.")
    print(f"Found {len(wav_files)} audio evaluation files in {SAMPLES_DIR}.\n")
    print(f"{'Condition / File':<38} | {'Correct':<8} | {'Recall %':<9} | {'WER %':<7} | Actual STT Response")
    print("-" * 105)

    records = []

    for path in wav_files:
        fname = os.path.basename(path)
        rec_text, status, confidence, alternatives = recognize_audio_google(r, path)
        
        if status == "OK":
            correct_cnt, total_ref, recall_pct = compute_word_recall(ground_truth, rec_text)
            wer = compute_wer(ground_truth, rec_text)
            disp_transcript = f'"{rec_text}" (Conf: {confidence:.2f})'
        else:
            correct_cnt = 0
            recall_pct = 0.0
            wer = 100.0
            disp_transcript = f'{rec_text}'
            
        print(f"{fname:<38} | {correct_cnt:>2}/{ref_words_total:<4} | {recall_pct:6.1f}%  | {wer:5.1f}% | {disp_transcript}")
        
        # Parse metadata from filename
        # e.g., club_techno_snr-10_01_primary_noisy.wav
        parts = fname.replace(".wav", "").split("_")
        venue = parts[0]
        genre = parts[1]
        snr = int(parts[2].replace("snr", ""))
        filter_type = "_".join(parts[4:])
        
        dsp_filter_name = FILTER_MAP.get(filter_type, filter_type)
        dsp_key = (venue, genre, audio_file_name, snr, dsp_filter_name)
        dsp_vals = dsp_lookup.get(dsp_key, {"STOI": None, "PESQ": None, "dSNR_dB": None, "dASL_dB": None})
        
        alts_str = " | ".join(alternatives) if alternatives else ""

        records.append({
            "Filename": fname,
            "Venue": venue,
            "Genre": genre,
            "SNR_dB": snr,
            "Filter_Stage": filter_type,
            "STOI": dsp_vals["STOI"],
            "PESQ": dsp_vals["PESQ"],
            "Delta_SNR_dB": dsp_vals["dSNR_dB"],
            "Ground_Truth": ground_truth,
            "Actual_STT_Response": rec_text,
            "Status": status,
            "Confidence_Score": confidence,
            "Alternative_Hypotheses": alts_str,
            "Correct_Words": correct_cnt,
            "Total_Words": ref_words_total,
            "Word_Recall_Pct": f"{recall_pct:.1f}",
            "WER_Pct": f"{wer:.1f}"
        })

    # Save to CSV
    os.makedirs(os.path.dirname(RESULTS_CSV), exist_ok=True)
    with open(RESULTS_CSV, "w", newline="", encoding="utf-8") as f:
        fieldnames = [
            "Filename", "Venue", "Genre", "SNR_dB", "Filter_Stage", "STOI", "PESQ",
            "Delta_SNR_dB", "Ground_Truth", "Actual_STT_Response", "Status",
            "Confidence_Score", "Alternative_Hypotheses", "Correct_Words", "Total_Words",
            "Word_Recall_Pct", "WER_Pct"
        ]
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(records)

    print("\n" + "=" * 80)
    print(f"  Evaluation Complete! Results saved to:\n  {RESULTS_CSV}")
    print("=" * 80)

if __name__ == "__main__":
    main()
