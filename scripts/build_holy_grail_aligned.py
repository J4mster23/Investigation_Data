#!/opt/anaconda3/bin/python3
"""
build_holy_grail_aligned.py

Builds the authoritative, 1-to-1 Holy Grail benchmark datasets on branch holy-grail-sim-alignment
by directly integrating the verified legacy experimental datasets:

1. Real-World Experiments:
   - Source: NLMS/output_audio/real_world_experiment/real_world_results.csv
   - Evaluated on cropped speech audio (Testing Results 07-10-26/outputs_cropped/)
   - Metrics: STOI, Delta STOI, PESQ, Delta SNR, Delta ASL, Faster-Whisper WER & Recall, Google STT WER & Recall
2. Theoretical MATLAB Simulation:
   - Source: NLMS/output_audio/room_experiment/room_experiment_results.csv
   - Official MATLAB multi-venue room acoustic simulation
   - Metrics: STOI, Delta STOI, PESQ, ViSQOL, Delta SNR, Delta ASL
3. Simulation Multi-Sentence ASR (Whisper & Google STT):
   - Source: NLMS/output_audio/room_experiment/asr_comparison_google_vs_whisper.csv
             and faster_whisper_multi_sentence_summary.csv
   - Evaluated on samples generated in samples_multi_sentence/
   - Attached:
     * Sim_Whisper_WER_Pct, Sim_Whisper_Recall_Pct, Sim_Whisper_Transcript
       (Exact trial match on sent01/SP2 female and sent02/SP1 male)
     * Sim_Google_WER_Pct, Sim_Google_Recall_Pct, Sim_Google_Transcript
     * Sim_Condition_Mean_WER_Pct, Sim_Condition_Mean_Recall_Pct (condition-level across Harvard sentences)

Outputs:
- NLMS/output_audio/holy_grail_results.csv (288 rows, setup-level)
- NLMS/output_audio/holy_grail_trials.csv (576 rows, trial-level with songs)
"""

import os
import shutil
import pandas as pd
import numpy as np

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTPUT_AUDIO_DIR = os.path.join(BASE_DIR, "NLMS", "output_audio")
REAL_EXP_DIR = os.path.join(OUTPUT_AUDIO_DIR, "real_world_experiment")
ROOM_EXP_DIR = os.path.join(OUTPUT_AUDIO_DIR, "room_experiment")
ARTIFACTS_DIR = "/Users/macairm1/.gemini/antigravity/brain/fa14326e-1c60-480f-a3be-913fac3a8bd5"

REAL_TRIALS_PATH = os.path.join(REAL_EXP_DIR, "real_world_results.csv")
ROOM_RESULTS_PATH = os.path.join(ROOM_EXP_DIR, "room_experiment_results.csv")
ASR_COMP_PATH = os.path.join(ROOM_EXP_DIR, "asr_comparison_google_vs_whisper.csv")
FW_SUMMARY_PATH = os.path.join(ROOM_EXP_DIR, "faster_whisper_multi_sentence_summary.csv")

HOLY_GRAIL_CSV = os.path.join(OUTPUT_AUDIO_DIR, "holy_grail_results.csv")
HOLY_GRAIL_TRIALS_CSV = os.path.join(OUTPUT_AUDIO_DIR, "holy_grail_trials.csv")

print("=" * 80)
print("  BUILDING THE AUTHORITATIVE ALIGNED HOLY GRAIL DATASET")
print("=" * 80)

# -----------------------------------------------------------------------------
# 1. Load Verified Source Data
# -----------------------------------------------------------------------------
df_real_raw = pd.read_csv(REAL_TRIALS_PATH)
df_sim_room = pd.read_csv(ROOM_RESULTS_PATH)
df_sim_asr = pd.read_csv(ASR_COMP_PATH)
df_sim_fw_sum = pd.read_csv(FW_SUMMARY_PATH)

print(f"  ✓ Loaded real trials: {len(df_real_raw)} rows")
print(f"  ✓ Loaded sim room results: {len(df_sim_room)} rows")
print(f"  ✓ Loaded sim ASR comparison: {len(df_sim_asr)} rows")
print(f"  ✓ Loaded sim whisper summary: {len(df_sim_fw_sum)} rows")

# -----------------------------------------------------------------------------
# 2. Harmonize Mappings
# -----------------------------------------------------------------------------
venue_map_sim_to_real = {
    "freefield": "Full_Outside",
    "damped": "Outside",
    "club": "Inside"
}

file_to_speech_corpus = {
    "male_01_IUS-M00201.wav": "SP1",
    "female_01_IUS-F00202.wav": "SP2"
}

filter_map_sim_to_real = {
    "Unprocessed": "PASSTHROUGH",
    "FIR_BP": "CONTROL",
    "Cascade_Notch_NLMS": "MIXED",
    "Cascade_Hybrid_Optimal": "OPTIMAL"
}

fw_stage_map = {
    "primary_noisy": "PASSTHROUGH",
    "fir_bp": "CONTROL",
    "cascade_notch_nlms": "MIXED",
    "hybrid_optimal": "OPTIMAL"
}

sentence_to_corpus = {
    "sent01": "SP2",  # Female talker: "The bill was paid every third week"
    "sent02": "SP1"   # Male talker: "Glue the sheet to the dark blue background"
}

# -----------------------------------------------------------------------------
# 3. Process Simulation DSP Metrics (room_experiment_results.csv)
# -----------------------------------------------------------------------------
sim_sub = df_sim_room[
    (df_sim_room["Venue"].isin(venue_map_sim_to_real.keys())) &
    (df_sim_room["File"].isin(file_to_speech_corpus.keys())) &
    (df_sim_room["SNR_dB"].isin([-20, -15, -10, 0])) &
    (df_sim_room["Filter"].isin(filter_map_sim_to_real.keys()))
].copy()

sim_sub["Venue"] = sim_sub["Venue"].map(venue_map_sim_to_real)
sim_sub["Speech_Corpus"] = sim_sub["File"].map(file_to_speech_corpus)
sim_sub["Filter"] = sim_sub["Filter"].map(filter_map_sim_to_real)

# Compute Sim Delta STOI relative to Sim Unprocessed
unproc_sim = sim_sub[sim_sub["Filter"] == "PASSTHROUGH"][
    ["Venue", "Genre", "SNR_dB", "Speech_Corpus", "STOI"]
].rename(columns={"STOI": "Sim_Unproc_STOI"})

sim_sub = pd.merge(sim_sub, unproc_sim, on=["Venue", "Genre", "SNR_dB", "Speech_Corpus"])
sim_sub["Sim_Delta_STOI"] = np.round(sim_sub["STOI"] - sim_sub["Sim_Unproc_STOI"], 4)

sim_sub = sim_sub.rename(columns={
    "STOI": "Sim_STOI",
    "PESQ": "Sim_PESQ",
    "ViSQOL": "Sim_ViSQOL",
    "dSNR_dB": "Sim_Delta_SNR_dB",
    "dASL_dB": "Sim_Delta_ASL_dB"
})[[
    "Venue", "Genre", "SNR_dB", "Speech_Corpus", "Filter",
    "Sim_STOI", "Sim_Delta_STOI", "Sim_PESQ", "Sim_ViSQOL",
    "Sim_Delta_SNR_dB", "Sim_Delta_ASL_dB"
]]

# -----------------------------------------------------------------------------
# 4. Process Simulation ASR (Whisper & Google STT)
# -----------------------------------------------------------------------------
# A. Exact trial match on sent01 (SP2) and sent02 (SP1)
df_asr_trials = df_sim_asr[df_sim_asr["Sentence_ID"].isin(sentence_to_corpus.keys())].copy()
df_asr_trials["Filter"] = df_asr_trials["Filter_Stage"].map(fw_stage_map)
df_asr_trials = df_asr_trials.dropna(subset=["Filter"])
df_asr_trials["Venue"] = "Inside"
df_asr_trials["Speech_Corpus"] = df_asr_trials["Sentence_ID"].map(sentence_to_corpus)

sim_asr_exact = df_asr_trials[[
    "Venue", "Genre", "SNR_dB", "Speech_Corpus", "Filter",
    "Whisper_WER_Pct", "Whisper_Recall_Pct", "Whisper_Response",
    "Google_WER_Pct", "Google_Recall_Pct", "Google_Response"
]].rename(columns={
    "Whisper_WER_Pct": "Sim_Whisper_WER_Pct",
    "Whisper_Recall_Pct": "Sim_Whisper_Recall_Pct",
    "Whisper_Response": "Sim_Whisper_Transcript",
    "Google_WER_Pct": "Sim_Google_WER_Pct",
    "Google_Recall_Pct": "Sim_Google_Recall_Pct",
    "Google_Response": "Sim_Google_Transcript"
})

# B. Condition-level robust mean WER across all Harvard sentences (from summary)
fw_sum_sub = df_sim_fw_sum.copy()
fw_sum_sub["Filter"] = fw_sum_sub["Filter_Stage"].map(fw_stage_map)
fw_sum_sub = fw_sum_sub.dropna(subset=["Filter"])
fw_sum_sub = fw_sum_sub[[
    "Genre", "SNR_dB", "Filter",
    "Mean_WER_Pct", "Mean_Word_Recall_Pct"
]].rename(columns={
    "Mean_WER_Pct": "Sim_Condition_Mean_WER_Pct",
    "Mean_Word_Recall_Pct": "Sim_Condition_Mean_Recall_Pct"
})

# -----------------------------------------------------------------------------
# 5. Process Real-World Data at Setup Level (288 rows)
# -----------------------------------------------------------------------------
real_setup = df_real_raw.groupby(["Venue", "Genre", "SNR_dB", "Speaker", "Filter_Name"]).agg({
    "STOI": "mean",
    "Delta_STOI": "mean",
    "PESQ": "mean",
    "Delta_SNR_dB": "mean",
    "Delta_ASL_dB": "mean",
    "Whisper_WER": "mean",
    "Whisper_Recall": "mean",
    "Google_WER": "mean",
    "Google_Recall": "mean"
}).reset_index().rename(columns={
    "Speaker": "Speech_Corpus",
    "Filter_Name": "Filter",
    "STOI": "Real_STOI",
    "Delta_STOI": "Real_Delta_STOI",
    "PESQ": "Real_PESQ",
    "Delta_SNR_dB": "Real_Delta_SNR_dB",
    "Delta_ASL_dB": "Real_Delta_ASL_dB",
    "Whisper_WER": "Real_Whisper_WER_Pct",
    "Whisper_Recall": "Real_Whisper_Recall_Pct",
    "Google_WER": "Real_Google_WER_Pct",
    "Google_Recall": "Real_Google_Recall_Pct"
})

# -----------------------------------------------------------------------------
# 6. Build Setup-Level Holy Grail (288 rows)
# -----------------------------------------------------------------------------
holy_grail = pd.merge(real_setup, sim_sub, on=["Venue", "Genre", "SNR_dB", "Speech_Corpus", "Filter"], how="inner")
holy_grail = pd.merge(holy_grail, sim_asr_exact, on=["Venue", "Genre", "SNR_dB", "Speech_Corpus", "Filter"], how="left")
holy_grail = pd.merge(holy_grail, fw_sum_sub, on=["Genre", "SNR_dB", "Filter"], how="left")

ordered_cols = [
    # Setup Keys
    "Venue", "Genre", "SNR_dB", "Speech_Corpus", "Filter",
    # Intelligibility (STOI & Delta STOI)
    "Real_STOI", "Sim_STOI", "Real_Delta_STOI", "Sim_Delta_STOI",
    # Noise Reduction & Quality
    "Real_Delta_SNR_dB", "Sim_Delta_SNR_dB", "Real_PESQ", "Sim_PESQ", "Sim_ViSQOL",
    "Real_Delta_ASL_dB", "Sim_Delta_ASL_dB",
    # Faster-Whisper ASR
    "Real_Whisper_WER_Pct", "Sim_Whisper_WER_Pct",
    "Real_Whisper_Recall_Pct", "Sim_Whisper_Recall_Pct",
    # Google STT
    "Real_Google_WER_Pct", "Sim_Google_WER_Pct",
    "Real_Google_Recall_Pct", "Sim_Google_Recall_Pct",
    # Transcripts & Multi-Sentence Benchmarks
    "Sim_Whisper_Transcript", "Sim_Google_Transcript",
    "Sim_Condition_Mean_WER_Pct", "Sim_Condition_Mean_Recall_Pct"
]
holy_grail = holy_grail[[c for c in ordered_cols if c in holy_grail.columns]]

float_cols = holy_grail.select_dtypes(include=["float64"]).columns
holy_grail[float_cols] = holy_grail[float_cols].round(4)

holy_grail.to_csv(HOLY_GRAIL_CSV, index=False)
print(f"✓ Exported Aligned Setup Holy Grail ({len(holy_grail)} rows, {len(holy_grail.columns)} columns) to:")
print(f"  {HOLY_GRAIL_CSV}")

# -----------------------------------------------------------------------------
# 7. Build Granular Trial-Level Holy Grail (576 rows)
# -----------------------------------------------------------------------------
real_trials = df_real_raw.rename(columns={
    "Speaker": "Speech_Corpus",
    "Filter_Name": "Filter",
    "STOI": "Real_STOI",
    "Delta_STOI": "Real_Delta_STOI",
    "PESQ": "Real_PESQ",
    "Delta_SNR_dB": "Real_Delta_SNR_dB",
    "Delta_ASL_dB": "Real_Delta_ASL_dB",
    "Whisper_WER": "Real_Whisper_WER_Pct",
    "Whisper_Recall": "Real_Whisper_Recall_Pct",
    "Google_WER": "Real_Google_WER_Pct",
    "Google_Recall": "Real_Google_Recall_Pct",
    "Whisper_Transcript": "Real_Whisper_Transcript",
    "Google_Transcript": "Real_Google_Transcript"
})

trial_join = pd.merge(real_trials, sim_sub, on=["Venue", "Genre", "SNR_dB", "Speech_Corpus", "Filter"], how="inner")
trial_join = pd.merge(trial_join, sim_asr_exact, on=["Venue", "Genre", "SNR_dB", "Speech_Corpus", "Filter"], how="left")
trial_join = pd.merge(trial_join, fw_sum_sub, on=["Genre", "SNR_dB", "Filter"], how="left")

trials_order = [
    "Venue", "Genre", "Song", "SNR_dB", "Speech_Corpus", "Filter",
    "Real_STOI", "Sim_STOI", "Real_Delta_STOI", "Sim_Delta_STOI",
    "Real_Delta_SNR_dB", "Sim_Delta_SNR_dB", "Real_PESQ", "Sim_PESQ", "Sim_ViSQOL",
    "Real_Delta_ASL_dB", "Sim_Delta_ASL_dB",
    "Real_Whisper_WER_Pct", "Sim_Whisper_WER_Pct",
    "Real_Whisper_Recall_Pct", "Sim_Whisper_Recall_Pct",
    "Real_Google_WER_Pct", "Sim_Google_WER_Pct",
    "Real_Google_Recall_Pct", "Sim_Google_Recall_Pct",
    "Real_Whisper_Transcript", "Sim_Whisper_Transcript",
    "Real_Google_Transcript", "Sim_Google_Transcript",
    "Sim_Condition_Mean_WER_Pct", "Sim_Condition_Mean_Recall_Pct"
]
trial_join = trial_join[[c for c in trials_order if c in trial_join.columns]]
t_floats = trial_join.select_dtypes(include=["float64"]).columns
trial_join[t_floats] = trial_join[t_floats].round(4)

trial_join.to_csv(HOLY_GRAIL_TRIALS_CSV, index=False)
print(f"✓ Exported Aligned Trials Holy Grail ({len(trial_join)} rows, {len(trial_join.columns)} columns) to:")
print(f"  {HOLY_GRAIL_TRIALS_CSV}")

# Mirror to artifacts directory
if os.path.exists(ARTIFACTS_DIR):
    shutil.copy2(HOLY_GRAIL_CSV, os.path.join(ARTIFACTS_DIR, "holy_grail_results.csv"))
    shutil.copy2(HOLY_GRAIL_TRIALS_CSV, os.path.join(ARTIFACTS_DIR, "holy_grail_trials.csv"))
    print(f"✓ Mirrored to brain artifacts directory: {ARTIFACTS_DIR}")

print("=" * 80)
print("  COMPLETED SUCCESSFULLY!")
print("=" * 80)
