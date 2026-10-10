#!/opt/anaconda3/bin/python3
"""
build_holy_grail_results.py

Constructs the streamlined, 1-to-1 "Holy Grail" benchmark dataset directly joining
empirical real-world test results with their corresponding simulation runs:

Setup in each row:
- Venue: Unified single venue label:
    * Full_Outside <---> freefield (Free-field / Open air)
    * Outside      <---> damped (Patio / Semi-enclosed)
    * Inside       <---> club (Indoor room / Reverberant enclosure)
- Genre: jazz, rock, techno
- SNR_dB: -20, -15, -10, 0 dB
- Speech_Corpus:
    * SP1 (Male talker / male_01_IUS-M00201.wav)
    * SP2 (Female talker / female_01_IUS-F00202.wav)
- Filter:
    * PASSTHROUGH <---> Unprocessed
    * CONTROL     <---> FIR_BP
    * MIXED       <---> Cascade_Notch_NLMS
    * OPTIMAL     <---> Cascade_Hybrid_Optimal

Outputs:
1. NLMS/output_audio/holy_grail_results.csv:
   Clean, unified 288-row setup table (3 venues x 3 genres x 4 SNRs x 2 speech corpuses x 4 filters)
   with Real and Simulated metrics side-by-side.
2. NLMS/output_audio/holy_grail_trials.csv:
   Granular 576-row trial table preserving individual music stems (rock1, rock2, etc.).
"""

import os
import shutil
import numpy as np
import pandas as pd

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTPUT_AUDIO_DIR = os.path.join(BASE_DIR, "NLMS", "output_audio")
REAL_EXP_DIR = os.path.join(OUTPUT_AUDIO_DIR, "real_world_experiment")
ROOM_EXP_DIR = os.path.join(OUTPUT_AUDIO_DIR, "room_experiment")
ARTIFACTS_DIR = "/Users/macairm1/.gemini/antigravity/brain/fa14326e-1c60-480f-a3be-913fac3a8bd5"

# Input paths
REAL_TRIALS_PATH = os.path.join(REAL_EXP_DIR, "real_world_results.csv")
ROOM_RESULTS_PATH = os.path.join(ROOM_EXP_DIR, "room_experiment_results.csv")
FW_RESULTS_PATH = os.path.join(ROOM_EXP_DIR, "faster_whisper_multi_sentence_results.csv")

# Output paths
HOLY_GRAIL_CSV = os.path.join(OUTPUT_AUDIO_DIR, "holy_grail_results.csv")
HOLY_GRAIL_TRIALS_CSV = os.path.join(OUTPUT_AUDIO_DIR, "holy_grail_trials.csv")

print("=" * 80)
print("  BUILDING THE STREAMLINED HOLY GRAIL DATASET")
print("=" * 80)

# -----------------------------------------------------------------------------
# 1. Load Data
# -----------------------------------------------------------------------------
df_real = pd.read_csv(REAL_TRIALS_PATH)
df_sim = pd.read_csv(ROOM_RESULTS_PATH)
df_fw = pd.read_csv(FW_RESULTS_PATH)

# Mappings
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

# -----------------------------------------------------------------------------
# 2. Process Simulation Data (Exact 1-to-1 Subset)
# -----------------------------------------------------------------------------
sim_sub = df_sim[
    (df_sim["Venue"].isin(venue_map_sim_to_real.keys())) &
    (df_sim["File"].isin(file_to_speech_corpus.keys())) &
    (df_sim["SNR_dB"].isin([-20, -15, -10, 0])) &
    (df_sim["Filter"].isin(filter_map_sim_to_real.keys()))
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

# Simulation Whisper WER (measured for Inside / sent01 = SP2)
fw_sent01 = df_fw[df_fw["Sentence_ID"] == "sent01"].copy()
fw_stage_map = {
    "primary_noisy": "PASSTHROUGH",
    "fir_bp": "CONTROL",
    "cascade_notch_nlms": "MIXED",
    "hybrid_optimal": "OPTIMAL"
}
fw_sent01["Filter"] = fw_sent01["Filter_Stage"].map(fw_stage_map)
fw_sent01 = fw_sent01.dropna(subset=["Filter"])
fw_sent01["Venue"] = "Inside"
fw_sent01["Speech_Corpus"] = "SP2"
fw_sub = fw_sent01[["Venue", "Genre", "SNR_dB", "Speech_Corpus", "Filter", "WER_Pct"]].rename(
    columns={"WER_Pct": "Sim_Whisper_WER_Pct"}
)

sim_sub = pd.merge(sim_sub, fw_sub, on=["Venue", "Genre", "SNR_dB", "Speech_Corpus", "Filter"], how="left")

# -----------------------------------------------------------------------------
# 3. Process Real-World Data at Setup Level (288 rows)
# -----------------------------------------------------------------------------
# Group across the 2 song stems (e.g. rock1, rock2) for each setup
real_setup = df_real.groupby(["Venue", "Genre", "SNR_dB", "Speaker", "Filter_Name"]).agg({
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
# 4. Join Real and Sim (Setup Table: 288 rows)
# -----------------------------------------------------------------------------
holy_grail = pd.merge(real_setup, sim_sub, on=["Venue", "Genre", "SNR_dB", "Speech_Corpus", "Filter"], how="inner")

ordered_cols = [
    # Setup Keys
    "Venue", "Genre", "SNR_dB", "Speech_Corpus", "Filter",
    # Intelligibility (STOI & Delta STOI)
    "Real_STOI", "Sim_STOI", "Real_Delta_STOI", "Sim_Delta_STOI",
    # Noise Reduction & Quality
    "Real_Delta_SNR_dB", "Sim_Delta_SNR_dB", "Real_PESQ", "Sim_PESQ", "Sim_ViSQOL",
    "Real_Delta_ASL_dB", "Sim_Delta_ASL_dB",
    # Speech Recognition (WER)
    "Real_Whisper_WER_Pct", "Sim_Whisper_WER_Pct", "Real_Whisper_Recall_Pct",
    "Real_Google_WER_Pct", "Real_Google_Recall_Pct"
]
holy_grail = holy_grail[ordered_cols]

float_cols = holy_grail.select_dtypes(include=["float64"]).columns
holy_grail[float_cols] = holy_grail[float_cols].round(4)

holy_grail.to_csv(HOLY_GRAIL_CSV, index=False)
print(f"✓ Exported Unified Setup Holy Grail ({len(holy_grail)} rows, {len(holy_grail.columns)} columns) to:")
print(f"  {HOLY_GRAIL_CSV}")

# -----------------------------------------------------------------------------
# 5. Granular Trial Level (576 rows, preserving Song)
# -----------------------------------------------------------------------------
real_trials = df_real.rename(columns={
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

trial_join = pd.merge(
    real_trials,
    sim_sub,
    on=["Venue", "Genre", "SNR_dB", "Speech_Corpus", "Filter"],
    how="inner"
)

trial_cols = [
    "Venue", "Genre", "Song", "SNR_dB", "Speech_Corpus", "Filter",
    "Real_STOI", "Sim_STOI", "Real_Delta_STOI", "Sim_Delta_STOI",
    "Real_Delta_SNR_dB", "Sim_Delta_SNR_dB", "Real_PESQ", "Sim_PESQ", "Sim_ViSQOL",
    "Real_Delta_ASL_dB", "Sim_Delta_ASL_dB",
    "Real_Whisper_WER_Pct", "Sim_Whisper_WER_Pct", "Real_Whisper_Recall_Pct",
    "Real_Google_WER_Pct", "Real_Google_Recall_Pct",
    "Whisper_Transcript", "Google_Transcript"
]
trial_join = trial_join[[c for c in trial_cols if c in trial_join.columns]]
trial_float_cols = trial_join.select_dtypes(include=["float64"]).columns
trial_join[trial_float_cols] = trial_join[trial_float_cols].round(4)

trial_join.to_csv(HOLY_GRAIL_TRIALS_CSV, index=False)
print(f"✓ Exported Trial-Level Holy Grail ({len(trial_join)} rows, {len(trial_join.columns)} columns) to:")
print(f"  {HOLY_GRAIL_TRIALS_CSV}")

# Copy to artifacts directory
if os.path.exists(ARTIFACTS_DIR):
    shutil.copy2(HOLY_GRAIL_CSV, os.path.join(ARTIFACTS_DIR, "holy_grail_results.csv"))
    shutil.copy2(HOLY_GRAIL_TRIALS_CSV, os.path.join(ARTIFACTS_DIR, "holy_grail_trials.csv"))
    print(f"✓ Mirrored to brain artifacts directory: {ARTIFACTS_DIR}")

print("=" * 80)
print("  COMPLETED!")
print("=" * 80)
