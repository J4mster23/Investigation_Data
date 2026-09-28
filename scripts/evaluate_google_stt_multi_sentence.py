#!/usr/bin/env python3
"""
evaluate_google_stt_multi_sentence.py
Evaluates speech intelligibility using Google Cloud Speech-to-Text API
across multiple Harvard sentences (Male and Female talkers) at -15 dB, -10 dB, and 0 dB SNR.

Outputs to CSV:
- Actual Speech-to-Text response string (and [NO_SPEECH_DETECTED] when rejected)
- Google API Confidence score
- Alternative hypotheses candidate list from Google's beam search
- Word Recall Rate (% target words spotted)
- Word Error Rate (WER % via Levenshtein distance)
- Merged DSP metrics: STOI, PESQ, Delta SNR from room simulation results.
"""

import os
import re
import csv
import glob
import string
import time
import speech_recognition as sr

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTPUT_DIR = os.path.join(BASE_DIR, "NLMS", "output_audio", "room_experiment")
SAMPLES_DIR = os.path.join(OUTPUT_DIR, "samples_multi_sentence")
ROOM_EXP_CSV = os.path.join(OUTPUT_DIR, "room_experiment_results.csv")
RAW_RESULTS_CSV = os.path.join(OUTPUT_DIR, "google_stt_multi_sentence_results.csv")
SUMMARY_CSV = os.path.join(OUTPUT_DIR, "google_stt_multi_sentence_summary.csv")

GROUND_TRUTHS = {
    "sent01": {
        "text": "The bill was paid every third week",
        "gender": "female",
        "file": "female_01_IUS-F00202.wav",
        "tokens": ["the", "bill", "was", "paid", "every", "third", "week"],
        "count": 7
    },
    "sent02": {
        "text": "Glue the sheet to the dark blue background",
        "gender": "male",
        "file": "male_02_IUS-M02201.wav",
        "tokens": ["glue", "the", "sheet", "to", "the", "dark", "blue", "background"],
        "count": 8
    },
    "sent03": {
        "text": "These days a chicken leg is a rare dish",
        "gender": "female",
        "file": "female_03_IUS-F04202.wav",
        "tokens": ["these", "days", "a", "chicken", "leg", "is", "a", "rare", "dish"],
        "count": 9
    }
}

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
    """
    Transcribes an audio file via Google Speech Recognition with retry logic.
    Returns: (actual_response_str, status, confidence, alternative_list)
    """
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

def parse_filename(fname):
    """
    Filename format: club_{genre}_snr{snr}_{sent_id}_{filter_idx}_{filter_name}.wav
    Example: club_jazz_snr-15_sent01_01_primary_noisy.wav
    """
    clean_name = fname.replace(".wav", "")
    parts = clean_name.split("_")
    venue = parts[0]
    genre = parts[1]
    snr = int(parts[2].replace("snr", ""))
    sent_id = parts[3]
    filter_idx = parts[4]
    filter_stage = "_".join(parts[5:])
    return venue, genre, snr, sent_id, filter_stage

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
    print("=" * 95)
    print("  GOOGLE SPEECH-TO-TEXT (STT) MULTI-SENTENCE INTELLIGIBILITY BENCHMARK")
    print("  Capturing Actual ASR Responses, Confidence, and Alternatives to CSV")
    print("=" * 95)

    r = sr.Recognizer()
    wav_files = sorted(glob.glob(os.path.join(SAMPLES_DIR, "*.wav")))

    if not wav_files:
        print(f"Error: No sample WAV files found in {SAMPLES_DIR}")
        return

    dsp_lookup = load_dsp_metrics()
    print(f"Loaded {len(dsp_lookup)} objective DSP benchmark records from room experiment.\n")
    print(f"Found {len(wav_files)} audio evaluation files in {SAMPLES_DIR}.\n")
    print(f"{'Condition / File':<44} | {'Sentence':<7} | {'Correct':<8} | {'Recall %':<9} | {'WER %':<7} | Actual STT Response")
    print("-" * 115)

    records = []
    summary_map = {}

    for idx, path in enumerate(wav_files, start=1):
        fname = os.path.basename(path)
        venue, genre, snr, sent_id, filter_stage = parse_filename(fname)
        
        gt_info = GROUND_TRUTHS[sent_id]
        ground_truth = gt_info["text"]
        ref_words_total = gt_info["count"]
        gender = gt_info["gender"]
        audio_file = gt_info["file"]
        
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
            
        print(f"{fname:<44} | {sent_id:<7} | {correct_cnt:>2}/{ref_words_total:<4} | {recall_pct:6.1f}%  | {wer:5.1f}% | {disp_transcript}")
        
        # Match DSP metrics
        dsp_filter_name = FILTER_MAP.get(filter_stage, filter_stage)
        dsp_key = (venue, genre, audio_file, snr, dsp_filter_name)
        dsp_vals = dsp_lookup.get(dsp_key, {"STOI": None, "PESQ": None, "dSNR_dB": None, "dASL_dB": None})
        
        alts_str = " | ".join(alternatives) if alternatives else ""
        
        row = {
            "Filename": fname,
            "Venue": venue,
            "Genre": genre,
            "SNR_dB": snr,
            "Sentence_ID": sent_id,
            "Gender": gender,
            "Filter_Stage": filter_stage,
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
            "Word_Recall_Pct": round(recall_pct, 1),
            "WER_Pct": round(wer, 1)
        }
        records.append(row)
        
        # Summary grouping
        sum_key = (genre, snr, filter_stage)
        if sum_key not in summary_map:
            summary_map[sum_key] = {
                "genre": genre,
                "snr": snr,
                "filter": filter_stage,
                "total_words_ref": 0,
                "total_words_correct": 0,
                "recall_list": [],
                "wer_list": [],
                "conf_list": [],
                "detected_count": 0,
                "total_trials": 0,
                "sample_responses": []
            }
        
        s_entry = summary_map[sum_key]
        s_entry["total_words_ref"] += ref_words_total
        s_entry["total_words_correct"] += correct_cnt
        s_entry["recall_list"].append(recall_pct)
        s_entry["wer_list"].append(wer)
        s_entry["total_trials"] += 1
        s_entry["sample_responses"].append(rec_text)
        if status == "OK":
            s_entry["detected_count"] += 1
            if confidence > 0:
                s_entry["conf_list"].append(confidence)

    # Save detailed CSV
    os.makedirs(os.path.dirname(RAW_RESULTS_CSV), exist_ok=True)
    with open(RAW_RESULTS_CSV, "w", newline="", encoding="utf-8") as f:
        fieldnames = [
            "Filename", "Venue", "Genre", "SNR_dB", "Sentence_ID", "Gender", "Filter_Stage",
            "STOI", "PESQ", "Delta_SNR_dB", "Ground_Truth", "Actual_STT_Response", "Status",
            "Confidence_Score", "Alternative_Hypotheses", "Correct_Words", "Total_Words",
            "Word_Recall_Pct", "WER_Pct"
        ]
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(records)

    # Compile Summary
    summary_records = []
    filter_order = ["primary_noisy", "fir_bp", "notch", "base_nlms", "soft_vad_leaky"]
    sorted_keys = sorted(summary_map.keys(), key=lambda k: (k[0], k[1], filter_order.index(k[2]) if k[2] in filter_order else 99))

    print("\n" + "=" * 95)
    print("  MULTI-SENTENCE BENCHMARK SUMMARY (Aggregated across 3 Harvard Sentences)")
    print("=" * 95)
    print(f"{'Genre':<8} | {'SNR':<7} | {'Filter Stage':<16} | {'Words Recalled':<15} | {'Mean Recall %':<14} | {'Mean WER %':<11} | {'Mean Conf':<10} | {'Speech Detected'}")
    print("-" * 105)

    for k in sorted_keys:
        s = summary_map[k]
        mean_recall = sum(s["recall_list"]) / float(len(s["recall_list"]))
        mean_wer = sum(s["wer_list"]) / float(len(s["wer_list"]))
        mean_conf = (sum(s["conf_list"]) / float(len(s["conf_list"]))) if s["conf_list"] else 0.0
        detect_rate = (s["detected_count"] / float(s["total_trials"])) * 100.0
        words_str = f"{s['total_words_correct']}/{s['total_words_ref']}"
        
        print(f"{s['genre']:<8} | {s['snr']:>3} dB  | {s['filter']:<16} | {words_str:^15} | {mean_recall:11.1f}%  | {mean_wer:8.1f}%  | {mean_conf:8.2f}   | {detect_rate:5.1f}% ({s['detected_count']}/{s['total_trials']})")
        
        summary_records.append({
            "Genre": s["genre"],
            "SNR_dB": s["snr"],
            "Filter_Stage": s["filter"],
            "Total_Correct_Words": s["total_words_correct"],
            "Total_Reference_Words": s["total_words_ref"],
            "Mean_Word_Recall_Pct": round(mean_recall, 1),
            "Mean_WER_Pct": round(mean_wer, 1),
            "Mean_Confidence": round(mean_conf, 3),
            "Speech_Detection_Rate_Pct": round(detect_rate, 1),
            "Sentences_Tested": s["total_trials"],
            "Representative_Actual_Responses": " || ".join(s["sample_responses"])
        })

    with open(SUMMARY_CSV, "w", newline="", encoding="utf-8") as f:
        fieldnames = [
            "Genre", "SNR_dB", "Filter_Stage", "Total_Correct_Words", "Total_Reference_Words",
            "Mean_Word_Recall_Pct", "Mean_WER_Pct", "Mean_Confidence", "Speech_Detection_Rate_Pct",
            "Sentences_Tested", "Representative_Actual_Responses"
        ]
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(summary_records)

    print("\n" + "=" * 95)
    print(f"  Complete! Detailed raw CSV saved to: {RAW_RESULTS_CSV}")
    print(f"  Summary CSV saved to:               {SUMMARY_CSV}")
    print("=" * 95)

if __name__ == "__main__":
    main()
