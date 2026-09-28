#!/opt/anaconda3/bin/python3
"""
generate_asr_comparison_matrix.py
Merges Google Speech-to-Text and Faster-Whisper multi-sentence results side-by-side
across 135 experimental conditions (-15 dB, -10 dB, 0 dB SNR in Club Jazz, Rock, Techno).

Outputs:
1. NLMS/output_audio/room_experiment/asr_comparison_google_vs_whisper.csv (135 rows)
2. NLMS/output_audio/room_experiment/asr_comparison_summary.csv (45 aggregated conditions)
"""

import os
import csv

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTPUT_DIR = os.path.join(BASE_DIR, "NLMS", "output_audio", "room_experiment")
GOOGLE_CSV = os.path.join(OUTPUT_DIR, "google_stt_multi_sentence_results.csv")
WHISPER_CSV = os.path.join(OUTPUT_DIR, "faster_whisper_multi_sentence_results.csv")

COMPARISON_CSV = os.path.join(OUTPUT_DIR, "asr_comparison_google_vs_whisper.csv")
SUMMARY_COMP_CSV = os.path.join(OUTPUT_DIR, "asr_comparison_summary.csv")

def main():
    if not os.path.exists(GOOGLE_CSV):
        print(f"Error: Google STT results CSV not found: {GOOGLE_CSV}")
        return
    if not os.path.exists(WHISPER_CSV):
        print(f"Error: Faster-Whisper results CSV not found: {WHISPER_CSV}")
        return

    # Load Google results
    google_data = {}
    with open(GOOGLE_CSV, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for r in reader:
            google_data[r["Filename"]] = r

    # Load Whisper results
    whisper_data = {}
    with open(WHISPER_CSV, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for r in reader:
            whisper_data[r["Filename"]] = r

    print("=" * 115)
    print("  ASR INTELLIGIBILITY BENCHMARK: GOOGLE STT vs. FASTER-WHISPER COMPARISON")
    print(f"  Matched {len(google_data)} Google records with {len(whisper_data)} Whisper records.")
    print("=" * 115)

    comparison_records = []
    summary_map = {}

    for fname, w_row in sorted(whisper_data.items()):
        g_row = google_data.get(fname, None)
        if not g_row:
            continue

        g_resp = g_row["Actual_STT_Response"]
        g_status = g_row["Status"]
        g_conf = float(g_row["Confidence_Score"])
        g_recall = float(g_row["Word_Recall_Pct"])
        g_wer = float(g_row["WER_Pct"])
        g_detected = 1 if g_status == "OK" else 0

        w_resp = w_row["Actual_Whisper_Response"]
        w_status = w_row["Status"]
        w_prob = float(w_row["Mean_Word_Confidence"])
        w_min_prob = float(w_row["Min_Word_Confidence"])
        w_logprob = float(w_row["Avg_Logprob"])
        w_recall = float(w_row["Word_Recall_Pct"])
        w_wer = float(w_row["WER_Pct"])
        w_detected = 1 if w_status == "OK" else 0

        delta_recall = round(w_recall - g_recall, 1)
        delta_wer = round(w_wer - g_wer, 1)

        # Classification
        if g_detected and w_detected:
            det_class = "Both Detected"
        elif not g_detected and w_detected:
            det_class = "Whisper Only (Google Dropped)"
        elif g_detected and not w_detected:
            det_class = "Google Only"
        else:
            det_class = "Neither Detected"

        comp_row = {
            "Filename": fname,
            "Venue": w_row["Venue"],
            "Genre": w_row["Genre"],
            "SNR_dB": int(w_row["SNR_dB"]),
            "Sentence_ID": w_row["Sentence_ID"],
            "Gender": w_row["Gender"],
            "Filter_Stage": w_row["Filter_Stage"],
            "STOI": w_row["STOI"],
            "PESQ": w_row["PESQ"],
            "Delta_SNR_dB": w_row["Delta_SNR_dB"],
            "Ground_Truth": w_row["Ground_Truth"],
            "Google_Response": g_resp,
            "Google_Status": g_status,
            "Google_Confidence": g_conf,
            "Google_Recall_Pct": g_recall,
            "Google_WER_Pct": g_wer,
            "Whisper_Response": w_resp,
            "Whisper_Status": w_status,
            "Whisper_Mean_Prob": w_prob,
            "Whisper_Min_Prob": w_min_prob,
            "Whisper_Avg_Logprob": w_logprob,
            "Whisper_Recall_Pct": w_recall,
            "Whisper_WER_Pct": w_wer,
            "Delta_Recall_Whisper_minus_Google": delta_recall,
            "Delta_WER_Whisper_minus_Google": delta_wer,
            "Detection_Class": det_class
        }
        comparison_records.append(comp_row)

        # Summary accumulation
        sum_key = (w_row["Genre"], int(w_row["SNR_dB"]), w_row["Filter_Stage"])
        if sum_key not in summary_map:
            summary_map[sum_key] = {
                "genre": w_row["Genre"],
                "snr": int(w_row["SNR_dB"]),
                "filter": w_row["Filter_Stage"],
                "google_recalls": [],
                "whisper_recalls": [],
                "google_wers": [],
                "whisper_wers": [],
                "google_confs": [],
                "whisper_probs": [],
                "google_detected": 0,
                "whisper_detected": 0,
                "trials": 0
            }
        sm = summary_map[sum_key]
        sm["trials"] += 1
        sm["google_recalls"].append(g_recall)
        sm["whisper_recalls"].append(w_recall)
        sm["google_wers"].append(g_wer)
        sm["whisper_wers"].append(w_wer)
        if g_detected and g_conf > 0:
            sm["google_confs"].append(g_conf)
        if w_detected and w_prob > 0:
            sm["whisper_probs"].append(w_prob)
        sm["google_detected"] += g_detected
        sm["whisper_detected"] += w_detected

    # Write detailed comparison CSV
    with open(COMPARISON_CSV, "w", newline="", encoding="utf-8") as f:
        fieldnames = [
            "Filename", "Venue", "Genre", "SNR_dB", "Sentence_ID", "Gender", "Filter_Stage",
            "STOI", "PESQ", "Delta_SNR_dB", "Ground_Truth",
            "Google_Response", "Google_Status", "Google_Confidence", "Google_Recall_Pct", "Google_WER_Pct",
            "Whisper_Response", "Whisper_Status", "Whisper_Mean_Prob", "Whisper_Min_Prob",
            "Whisper_Avg_Logprob", "Whisper_Recall_Pct", "Whisper_WER_Pct",
            "Delta_Recall_Whisper_minus_Google", "Delta_WER_Whisper_minus_Google", "Detection_Class"
        ]
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(comparison_records)

    # Write Summary comparison CSV
    filter_order = ["primary_noisy", "fir_bp", "notch", "base_nlms", "soft_vad_leaky"]
    sorted_keys = sorted(summary_map.keys(), key=lambda k: (k[0], k[1], filter_order.index(k[2]) if k[2] in filter_order else 99))

    summary_records = []
    print("\n" + "=" * 125)
    print("  SUMMARY: GOOGLE STT vs. FASTER-WHISPER COMPARISON MATRIX (Aggregated across 3 Harvard Sentences)")
    print("=" * 125)
    print(f"{'Genre':<7} | {'SNR':<6} | {'Filter Stage':<16} | {'Google Rec%':<12} | {'Whisp Rec%':<11} | {'Google WER%':<12} | {'Whisp WER%':<11} | {'Whisp Prob':<11} | Detection (G vs W)")
    print("-" * 125)

    for k in sorted_keys:
        sm = summary_map[k]
        g_mean_rec = sum(sm["google_recalls"]) / float(len(sm["google_recalls"]))
        w_mean_rec = sum(sm["whisper_recalls"]) / float(len(sm["whisper_recalls"]))
        g_mean_wer = sum(sm["google_wers"]) / float(len(sm["google_wers"]))
        w_mean_wer = sum(sm["whisper_wers"]) / float(len(sm["whisper_wers"]))
        g_mean_conf = (sum(sm["google_confs"]) / float(len(sm["google_confs"]))) if sm["google_confs"] else 0.0
        w_mean_prob = (sum(sm["whisper_probs"]) / float(len(sm["whisper_probs"]))) if sm["whisper_probs"] else 0.0
        g_det_pct = (sm["google_detected"] / float(sm["trials"])) * 100.0
        w_det_pct = (sm["whisper_detected"] / float(sm["trials"])) * 100.0

        det_str = f"G:{g_det_pct:4.0f}% vs W:{w_det_pct:4.0f}%"

        print(f"{sm['genre']:<7} | {sm['snr']:>3}dB | {sm['filter']:<16} | {g_mean_rec:10.1f}%  | {w_mean_rec:9.1f}%  | {g_mean_wer:10.1f}%  | {w_mean_wer:9.1f}%  | {w_mean_prob:9.3f}   | {det_str}")

        summary_records.append({
            "Genre": sm["genre"],
            "SNR_dB": sm["snr"],
            "Filter_Stage": sm["filter"],
            "Google_Mean_Recall_Pct": round(g_mean_rec, 1),
            "Whisper_Mean_Recall_Pct": round(w_mean_rec, 1),
            "Google_Mean_WER_Pct": round(g_mean_wer, 1),
            "Whisper_Mean_WER_Pct": round(w_mean_wer, 1),
            "Google_Mean_Confidence": round(g_mean_conf, 3),
            "Whisper_Mean_Word_Prob": round(w_mean_prob, 3),
            "Google_Detection_Rate_Pct": round(g_det_pct, 1),
            "Whisper_Detection_Rate_Pct": round(w_det_pct, 1),
            "Delta_Recall_Whisper_minus_Google": round(w_mean_rec - g_mean_rec, 1),
            "Trials": sm["trials"]
        })

    with open(SUMMARY_COMP_CSV, "w", newline="", encoding="utf-8") as f:
        fieldnames = [
            "Genre", "SNR_dB", "Filter_Stage",
            "Google_Mean_Recall_Pct", "Whisper_Mean_Recall_Pct",
            "Google_Mean_WER_Pct", "Whisper_Mean_WER_Pct",
            "Google_Mean_Confidence", "Whisper_Mean_Word_Prob",
            "Google_Detection_Rate_Pct", "Whisper_Detection_Rate_Pct",
            "Delta_Recall_Whisper_minus_Google", "Trials"
        ]
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(summary_records)

    print("\n" + "=" * 115)
    print(f"  Successfully exported comparison records:")
    print(f"  - Detailed 135-trial matrix: {COMPARISON_CSV}")
    print(f"  - Aggregated 45-condition summary: {SUMMARY_COMP_CSV}")
    print("=" * 115)

if __name__ == "__main__":
    main()
