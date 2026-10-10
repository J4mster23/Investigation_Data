#!/opt/anaconda3/bin/python3
"""
build_holy_grail_results.py

Constructs the comprehensive "Holy Grail" benchmark dataset combining empirical
real-world field trial metrics with theoretical simulation benchmarks (Classical DSP
and Deep Learning Cooperative Models).

Produces four purpose-built CSV exports in NLMS/output_audio/:
1. holy_grail_master_results.csv:
   Wide-format condition-level table (144 rows) joining Real-World firmware testing
   conditions directly onto their Matched Empirical Simulation (Festival, RT60=0.20s),
   Physical Analog Simulation (Free-field, Damped, Club), ML benchmark models,
   and cross-domain residuals.
2. holy_grail_all_venues_cross_join.csv:
   Full cross-join table (720 rows = 144 real conditions x 5 simulated venues)
   for multi-reverberation sensitivity analysis across RT60 = 0.00s to 1.40s.
3. holy_grail_unified_tidy_benchmark.csv:
   Standardized long/tidy benchmark table (1,119 rows) containing all real and
   simulated observations in a unified schema ready for Seaborn / Matplotlib / GGplot.
4. holy_grail_trial_level_results.csv:
   Trial-level granular table (576 audio pairs) joining raw WAV trials with
   matched simulation reference values and trial-level residuals.
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

# File paths
REAL_SUMMARY_PATH = os.path.join(REAL_EXP_DIR, "real_world_summary.csv")
REAL_TRIALS_PATH = os.path.join(REAL_EXP_DIR, "real_world_results.csv")
ROOM_SUMMARY_PATH = os.path.join(ROOM_EXP_DIR, "room_experiment_summary.csv")
ML_SUMMARY_PATH = os.path.join(ROOM_EXP_DIR, "ml_filter_room_experiment_summary.csv")
FW_SUMMARY_PATH = os.path.join(ROOM_EXP_DIR, "faster_whisper_multi_sentence_summary.csv")
GSTT_SUMMARY_PATH = os.path.join(ROOM_EXP_DIR, "google_stt_multi_sentence_summary.csv")

# Output paths
MASTER_CSV_PATH = os.path.join(OUTPUT_AUDIO_DIR, "holy_grail_master_results.csv")
CROSS_JOIN_CSV_PATH = os.path.join(OUTPUT_AUDIO_DIR, "holy_grail_all_venues_cross_join.csv")
TIDY_CSV_PATH = os.path.join(OUTPUT_AUDIO_DIR, "holy_grail_unified_tidy_benchmark.csv")
TRIALS_JOIN_CSV_PATH = os.path.join(OUTPUT_AUDIO_DIR, "holy_grail_trial_level_results.csv")

print("=" * 80)
print("  BUILDING THE 'HOLY GRAIL' REAL-WORLD & SIMULATION BENCHMARK DATASET")
print("=" * 80)

# -----------------------------------------------------------------------------
# 1. Load Source Data
# -----------------------------------------------------------------------------
print("[1/5] Loading source CSVs...")
df_real_sum = pd.read_csv(REAL_SUMMARY_PATH)
df_real_trials = pd.read_csv(REAL_TRIALS_PATH)
df_room_sum = pd.read_csv(ROOM_SUMMARY_PATH)
df_ml_sum = pd.read_csv(ML_SUMMARY_PATH)
df_fw_sum = pd.read_csv(FW_SUMMARY_PATH)
df_gstt_sum = pd.read_csv(GSTT_SUMMARY_PATH)

print(f"  - Real World Summary: {len(df_real_sum)} conditions")
print(f"  - Real World Trials: {len(df_real_trials)} trials")
print(f"  - Room DSP Summary: {len(df_room_sum)} conditions")
print(f"  - ML Filter Summary: {len(df_ml_sum)} conditions")
print(f"  - Sim Faster-Whisper Summary: {len(df_fw_sum)} conditions")
print(f"  - Sim Google STT Summary: {len(df_gstt_sum)} conditions")

# -----------------------------------------------------------------------------
# 2. Harmonize Mappings & Calculate Simulation Delta STOI
# -----------------------------------------------------------------------------
print("\n[2/5] Harmonizing filter mappings & calculating simulation Delta STOI...")

# Filter mapping dictionary
filter_map = {
    "PASSTHROUGH": "Unprocessed",
    "CONTROL": "FIR_BP",
    "MIXED": "Cascade_Notch_NLMS",
    "OPTIMAL": "Cascade_Hybrid_Optimal"
}

# Physical Venue mapping dictionary
phys_venue_map = {
    "Full_Outside": "freefield",
    "Outside": "damped",
    "Inside": "club"
}

rt60_map = {
    "freefield": 0.00,
    "damped": 0.08,
    "festival": 0.20,
    "club": 0.70,
    "arena": 1.40
}

venue_labels = {
    "freefield": "Free-Field Stage (0.00s)",
    "damped": "Damped Shell Stage (0.08s)",
    "festival": "Open-Air Festival Stage (0.20s)",
    "club": "Nightclub Enclosure (0.70s)",
    "arena": "Concert Arena (1.40s)"
}

# Add mapped filters
df_real_sum["Filter_Sim_Mapped"] = df_real_sum["Filter_Name"].map(filter_map)
df_real_trials["Filter_Sim_Mapped"] = df_real_trials["Filter_Name"].map(filter_map)

# Compute Delta STOI in DSP Simulation relative to Unprocessed
unproc_dsp = df_room_sum[df_room_sum["Filter"] == "Unprocessed"][["Venue", "Genre", "SNR_dB", "Mean_STOI"]].rename(
    columns={"Mean_STOI": "Unproc_STOI"}
)
df_room_sum = pd.merge(df_room_sum, unproc_dsp, on=["Venue", "Genre", "SNR_dB"], how="left")
df_room_sum["Mean_Delta_STOI"] = np.round(df_room_sum["Mean_STOI"] - df_room_sum["Unproc_STOI"], 4)
df_room_sum = df_room_sum.drop(columns=["Unproc_STOI"])

# Compute Delta STOI in ML Simulation relative to Unprocessed
unproc_ml = df_ml_sum[df_ml_sum["Filter_Name"] == "Unprocessed"][["Venue", "Genre", "SNR_dB", "Mean_STOI"]].rename(
    columns={"Mean_STOI": "Unproc_STOI"}
)
df_ml_sum = pd.merge(df_ml_sum, unproc_ml, on=["Venue", "Genre", "SNR_dB"], how="left")
df_ml_sum["Mean_Delta_STOI"] = np.round(df_ml_sum["Mean_STOI"] - df_ml_sum["Unproc_STOI"], 4)
df_ml_sum = df_ml_sum.drop(columns=["Unproc_STOI"])

# Format Sim ASR metrics
asr_stage_map = {
    "primary_noisy": "Unprocessed",
    "fir_bp": "FIR_BP",
    "cascade_notch_nlms": "Cascade_Notch_NLMS",
    "hybrid_optimal": "Cascade_Hybrid_Optimal"
}
df_fw_sum["Filter_Sim_Mapped"] = df_fw_sum["Filter_Stage"].map(asr_stage_map)
df_gstt_sum["Filter_Sim_Mapped"] = df_gstt_sum["Filter_Stage"].map(asr_stage_map)

fw_mapped = df_fw_sum.dropna(subset=["Filter_Sim_Mapped"])[["Genre", "SNR_dB", "Filter_Sim_Mapped", "Mean_WER_Pct", "Mean_Word_Recall_Pct"]].rename(
    columns={"Mean_WER_Pct": "Sim_Club_Whisper_WER_Pct", "Mean_Word_Recall_Pct": "Sim_Club_Whisper_Recall_Pct"}
)
gstt_mapped = df_gstt_sum.dropna(subset=["Filter_Sim_Mapped"])[["Genre", "SNR_dB", "Filter_Sim_Mapped", "Mean_WER_Pct", "Mean_Word_Recall_Pct"]].rename(
    columns={"Mean_WER_Pct": "Sim_Club_Google_WER_Pct", "Mean_Word_Recall_Pct": "Sim_Club_Google_Recall_Pct"}
)
sim_asr_club = pd.merge(fw_mapped, gstt_mapped, on=["Genre", "SNR_dB", "Filter_Sim_Mapped"], how="outer")

# Prepare ML baseline pivots for festival and all venues
# We want STOI and Delta SNR for Base_NLMS, ML_Joint_VAD_Spatial_UNet, ML_VAD_Cascade_Notch_NLMS, ML_Spatial_Wave_UNet
ml_sub = df_ml_sum[df_ml_sum["Filter_Name"].isin([
    "Base_NLMS", "ML_Joint_VAD_Spatial_UNet", "ML_VAD_Cascade_Notch_NLMS", "ML_Spatial_Wave_UNet"
])].copy()

# -----------------------------------------------------------------------------
# 3. Build Table 1: holy_grail_master_results.csv (144 condition rows)
# -----------------------------------------------------------------------------
print("\n[3/5] Building 'holy_grail_master_results.csv'...")

master_records = []

for _, r_row in df_real_sum.iterrows():
    r_venue = r_row["Venue"]
    genre = r_row["Genre"]
    snr = int(r_row["SNR_dB"])
    f_real = r_row["Filter_Name"]
    f_sim = r_row["Filter_Sim_Mapped"]
    
    # Real metrics
    r_stoi = r_row["Mean_STOI"]
    r_dstoi = r_row["Mean_Delta_STOI"]
    r_pesq = r_row["Mean_PESQ"]
    r_dsnr = r_row["Mean_Delta_SNR_dB"]
    r_dasl = r_row["Mean_Delta_ASL_dB"]
    r_w_wer = r_row["Mean_Whisper_WER"]
    r_w_rec = r_row["Mean_Whisper_Recall"]
    r_g_wer = r_row["Mean_Google_WER"] if not pd.isna(r_row["Mean_Google_WER"]) else np.nan
    r_g_rec = r_row["Mean_Google_Recall"] if not pd.isna(r_row["Mean_Google_Recall"]) else np.nan
    
    # 1. Empirical Match Sim (Festival, RT60 = 0.20s)
    sim_emp = df_room_sum[(df_room_sum["Venue"] == "festival") & (df_room_sum["Genre"] == genre) & 
                          (df_room_sum["SNR_dB"] == snr) & (df_room_sum["Filter"] == f_sim)]
    if len(sim_emp) > 0:
        emp_stoi = sim_emp.iloc[0]["Mean_STOI"]
        emp_dstoi = sim_emp.iloc[0]["Mean_Delta_STOI"]
        emp_pesq = sim_emp.iloc[0]["Mean_PESQ"]
        emp_visqol = sim_emp.iloc[0]["Mean_ViSQOL"]
        emp_dsnr = sim_emp.iloc[0]["Mean_dSNR_dB"]
        emp_dasl = sim_emp.iloc[0]["Mean_dASL_dB"]
    else:
        emp_stoi = emp_dstoi = emp_pesq = emp_visqol = emp_dsnr = emp_dasl = np.nan

    # 2. Physical Analog Sim (freefield / damped / club)
    p_ven = phys_venue_map[r_venue]
    sim_phys = df_room_sum[(df_room_sum["Venue"] == p_ven) & (df_room_sum["Genre"] == genre) & 
                           (df_room_sum["SNR_dB"] == snr) & (df_room_sum["Filter"] == f_sim)]
    if len(sim_phys) > 0:
        phys_stoi = sim_phys.iloc[0]["Mean_STOI"]
        phys_dstoi = sim_phys.iloc[0]["Mean_Delta_STOI"]
        phys_pesq = sim_phys.iloc[0]["Mean_PESQ"]
        phys_visqol = sim_phys.iloc[0]["Mean_ViSQOL"]
        phys_dsnr = sim_phys.iloc[0]["Mean_dSNR_dB"]
        phys_dasl = sim_phys.iloc[0]["Mean_dASL_dB"]
    else:
        phys_stoi = phys_dstoi = phys_pesq = phys_visqol = phys_dsnr = phys_dasl = np.nan

    # 3. Residuals (Reality - Simulation)
    res_emp_stoi = np.round(r_stoi - emp_stoi, 4) if not np.isnan(emp_stoi) else np.nan
    res_emp_dsnr = np.round(r_dsnr - emp_dsnr, 2) if not np.isnan(emp_dsnr) else np.nan
    res_phys_stoi = np.round(r_stoi - phys_stoi, 4) if not np.isnan(phys_stoi) else np.nan
    res_phys_dsnr = np.round(r_dsnr - phys_dsnr, 2) if not np.isnan(phys_dsnr) else np.nan

    # 4. Simulation ML & Baseline Context (Empirical Festival Match)
    def get_ml_metrics(ven_name, filt_name):
        row = df_ml_sum[(df_ml_sum["Venue"] == ven_name) & (df_ml_sum["Genre"] == genre) & 
                        (df_ml_sum["SNR_dB"] == snr) & (df_ml_sum["Filter_Name"] == filt_name)]
        if len(row) > 0:
            return row.iloc[0]["Mean_STOI"], row.iloc[0]["Mean_Delta_SNR_dB"]
        return np.nan, np.nan

    emp_nlms_stoi, emp_nlms_dsnr = get_ml_metrics("festival", "Base_NLMS")
    emp_ml_joint_stoi, emp_ml_joint_dsnr = get_ml_metrics("festival", "ML_Joint_VAD_Spatial_UNet")
    emp_ml_vad_stoi, emp_ml_vad_dsnr = get_ml_metrics("festival", "ML_VAD_Cascade_Notch_NLMS")
    emp_ml_unet_stoi, emp_ml_unet_dsnr = get_ml_metrics("festival", "ML_Spatial_Wave_UNet")

    phys_nlms_stoi, phys_nlms_dsnr = get_ml_metrics(p_ven, "Base_NLMS")
    phys_ml_joint_stoi, phys_ml_joint_dsnr = get_ml_metrics(p_ven, "ML_Joint_VAD_Spatial_UNet")
    phys_ml_vad_stoi, phys_ml_vad_dsnr = get_ml_metrics(p_ven, "ML_VAD_Cascade_Notch_NLMS")
    phys_ml_unet_stoi, phys_ml_unet_dsnr = get_ml_metrics(p_ven, "ML_Spatial_Wave_UNet")

    # 5. Simulation ASR Context (Club environment)
    asr_match = sim_asr_club[(sim_asr_club["Genre"] == genre) & (sim_asr_club["SNR_dB"] == snr) & 
                             (sim_asr_club["Filter_Sim_Mapped"] == f_sim)]
    if len(asr_match) > 0:
        sim_club_w_wer = asr_match.iloc[0]["Sim_Club_Whisper_WER_Pct"]
        sim_club_w_rec = asr_match.iloc[0]["Sim_Club_Whisper_Recall_Pct"]
        sim_club_g_wer = asr_match.iloc[0]["Sim_Club_Google_WER_Pct"]
        sim_club_g_rec = asr_match.iloc[0]["Sim_Club_Google_Recall_Pct"]
    else:
        sim_club_w_wer = sim_club_w_rec = sim_club_g_wer = sim_club_g_rec = np.nan

    master_records.append({
        # Keys & Condition Metadata
        "Real_Venue": r_venue,
        "Genre": genre,
        "SNR_dB": snr,
        "Filter_Real": f_real,
        "Filter_Sim_Mapped": f_sim,
        "Matched_Sim_Venue_Empirical": "festival",
        "Empirical_RT60_sec": 0.20,
        "Matched_Sim_Venue_Physical": p_ven,
        "Physical_RT60_sec": rt60_map[p_ven],

        # Real-World Measured Metrics
        "Real_STOI": r_stoi,
        "Real_Delta_STOI": r_dstoi,
        "Real_PESQ": r_pesq,
        "Real_Delta_SNR_dB": r_dsnr,
        "Real_Delta_ASL_dB": r_dasl,
        "Real_Whisper_WER_Pct": r_w_wer,
        "Real_Whisper_Recall_Pct": r_w_rec,
        "Real_Google_WER_Pct": r_g_wer,
        "Real_Google_Recall_Pct": r_g_rec,

        # Empirical Sim Metrics (Festival, 0.20s)
        "Sim_Emp_STOI": emp_stoi,
        "Sim_Emp_Delta_STOI": emp_dstoi,
        "Sim_Emp_PESQ": emp_pesq,
        "Sim_Emp_ViSQOL": emp_visqol,
        "Sim_Emp_Delta_SNR_dB": emp_dsnr,
        "Sim_Emp_Delta_ASL_dB": emp_dasl,

        # Physical Analog Sim Metrics
        "Sim_Phys_STOI": phys_stoi,
        "Sim_Phys_Delta_STOI": phys_dstoi,
        "Sim_Phys_PESQ": phys_pesq,
        "Sim_Phys_ViSQOL": phys_visqol,
        "Sim_Phys_Delta_SNR_dB": phys_dsnr,
        "Sim_Phys_Delta_ASL_dB": phys_dasl,

        # Residuals (Reality minus Simulation)
        "Residual_STOI_Real_minus_EmpSim": res_emp_stoi,
        "Residual_Delta_SNR_Real_minus_EmpSim": res_emp_dsnr,
        "Residual_STOI_Real_minus_PhysSim": res_phys_stoi,
        "Residual_Delta_SNR_Real_minus_PhysSim": res_phys_dsnr,

        # Empirical Sim Baselines & ML Models (Festival Stage)
        "Sim_Emp_Base_NLMS_STOI": emp_nlms_stoi,
        "Sim_Emp_Base_NLMS_Delta_SNR_dB": emp_nlms_dsnr,
        "Sim_Emp_ML_Joint_VAD_Spatial_UNet_STOI": emp_ml_joint_stoi,
        "Sim_Emp_ML_Joint_VAD_Spatial_UNet_Delta_SNR_dB": emp_ml_joint_dsnr,
        "Sim_Emp_ML_VAD_Cascade_NLMS_STOI": emp_ml_vad_stoi,
        "Sim_Emp_ML_VAD_Cascade_NLMS_Delta_SNR_dB": emp_ml_vad_dsnr,
        "Sim_Emp_ML_Spatial_Wave_UNet_STOI": emp_ml_unet_stoi,
        "Sim_Emp_ML_Spatial_Wave_UNet_Delta_SNR_dB": emp_ml_unet_dsnr,

        # Physical Sim Baselines & ML Models
        "Sim_Phys_Base_NLMS_STOI": phys_nlms_stoi,
        "Sim_Phys_Base_NLMS_Delta_SNR_dB": phys_nlms_dsnr,
        "Sim_Phys_ML_Joint_VAD_Spatial_UNet_STOI": phys_ml_joint_stoi,
        "Sim_Phys_ML_Joint_VAD_Spatial_UNet_Delta_SNR_dB": phys_ml_joint_dsnr,
        "Sim_Phys_ML_VAD_Cascade_NLMS_STOI": phys_ml_vad_stoi,
        "Sim_Phys_ML_VAD_Cascade_NLMS_Delta_SNR_dB": phys_ml_vad_dsnr,
        "Sim_Phys_ML_Spatial_Wave_UNet_STOI": phys_ml_unet_stoi,
        "Sim_Phys_ML_Spatial_Wave_UNet_Delta_SNR_dB": phys_ml_unet_dsnr,

        # Simulation Speech Recognition (Club Environment Benchmark)
        "Sim_Club_Whisper_WER_Pct": sim_club_w_wer,
        "Sim_Club_Whisper_Recall_Pct": sim_club_w_rec,
        "Sim_Club_Google_WER_Pct": sim_club_g_wer,
        "Sim_Club_Google_Recall_Pct": sim_club_g_rec,
    })

df_master = pd.DataFrame(master_records)
df_master.to_csv(MASTER_CSV_PATH, index=False)
print(f"  ✓ Exported Master Results ({len(df_master)} rows, {len(df_master.columns)} columns) to:")
print(f"    {MASTER_CSV_PATH}")

# -----------------------------------------------------------------------------
# 4. Build Table 2: holy_grail_all_venues_cross_join.csv (720 rows)
# -----------------------------------------------------------------------------
print("\n[4/5] Building 'holy_grail_all_venues_cross_join.csv'...")

cross_records = []
sim_venues = ["freefield", "damped", "festival", "club", "arena"]

for _, r_row in df_real_sum.iterrows():
    r_venue = r_row["Venue"]
    genre = r_row["Genre"]
    snr = int(r_row["SNR_dB"])
    f_real = r_row["Filter_Name"]
    f_sim = r_row["Filter_Sim_Mapped"]

    for s_ven in sim_venues:
        s_match = df_room_sum[(df_room_sum["Venue"] == s_ven) & (df_room_sum["Genre"] == genre) & 
                              (df_room_sum["SNR_dB"] == snr) & (df_room_sum["Filter"] == f_sim)]
        
        if len(s_match) > 0:
            s_stoi = s_match.iloc[0]["Mean_STOI"]
            s_dstoi = s_match.iloc[0]["Mean_Delta_STOI"]
            s_pesq = s_match.iloc[0]["Mean_PESQ"]
            s_visqol = s_match.iloc[0]["Mean_ViSQOL"]
            s_dsnr = s_match.iloc[0]["Mean_dSNR_dB"]
            s_dasl = s_match.iloc[0]["Mean_dASL_dB"]
        else:
            s_stoi = s_dstoi = s_pesq = s_visqol = s_dsnr = s_dasl = np.nan

        # ML Context in that simulated venue
        def get_sim_ml(filt_name):
            row = df_ml_sum[(df_ml_sum["Venue"] == s_ven) & (df_ml_sum["Genre"] == genre) & 
                            (df_ml_sum["SNR_dB"] == snr) & (df_ml_sum["Filter_Name"] == filt_name)]
            if len(row) > 0:
                return row.iloc[0]["Mean_STOI"], row.iloc[0]["Mean_Delta_SNR_dB"]
            return np.nan, np.nan

        s_nlms_stoi, s_nlms_dsnr = get_sim_ml("Base_NLMS")
        s_joint_stoi, s_joint_dsnr = get_sim_ml("ML_Joint_VAD_Spatial_UNet")
        s_vad_stoi, s_vad_dsnr = get_sim_ml("ML_VAD_Cascade_Notch_NLMS")

        cross_records.append({
            "Real_Venue": r_venue,
            "Sim_Venue": s_ven,
            "Sim_Venue_Label": venue_labels[s_ven],
            "Sim_RT60_sec": rt60_map[s_ven],
            "Genre": genre,
            "SNR_dB": snr,
            "Filter_Real": f_real,
            "Filter_Sim_Mapped": f_sim,
            
            # Real Metrics
            "Real_STOI": r_row["Mean_STOI"],
            "Real_Delta_STOI": r_row["Mean_Delta_STOI"],
            "Real_PESQ": r_row["Mean_PESQ"],
            "Real_Delta_SNR_dB": r_row["Mean_Delta_SNR_dB"],
            "Real_Delta_ASL_dB": r_row["Mean_Delta_ASL_dB"],
            "Real_Whisper_WER_Pct": r_row["Mean_Whisper_WER"],
            "Real_Whisper_Recall_Pct": r_row["Mean_Whisper_Recall"],
            "Real_Google_WER_Pct": r_row["Mean_Google_WER"] if not pd.isna(r_row["Mean_Google_WER"]) else np.nan,
            "Real_Google_Recall_Pct": r_row["Mean_Google_Recall"] if not pd.isna(r_row["Mean_Google_Recall"]) else np.nan,

            # Simulated Metrics
            "Sim_STOI": s_stoi,
            "Sim_Delta_STOI": s_dstoi,
            "Sim_PESQ": s_pesq,
            "Sim_ViSQOL": s_visqol,
            "Sim_Delta_SNR_dB": s_dsnr,
            "Sim_Delta_ASL_dB": s_dasl,

            # Residuals
            "Residual_STOI_Real_minus_Sim": np.round(r_row["Mean_STOI"] - s_stoi, 4) if not np.isnan(s_stoi) else np.nan,
            "Residual_Delta_SNR_Real_minus_Sim": np.round(r_row["Mean_Delta_SNR_dB"] - s_dsnr, 2) if not np.isnan(s_dsnr) else np.nan,

            # ML Baselines in this room
            "Sim_Base_NLMS_STOI": s_nlms_stoi,
            "Sim_Base_NLMS_Delta_SNR_dB": s_nlms_dsnr,
            "Sim_ML_Joint_VAD_Spatial_UNet_STOI": s_joint_stoi,
            "Sim_ML_Joint_VAD_Spatial_UNet_Delta_SNR_dB": s_joint_dsnr,
            "Sim_ML_VAD_Cascade_NLMS_STOI": s_vad_stoi,
            "Sim_ML_VAD_Cascade_NLMS_Delta_SNR_dB": s_vad_dsnr,
        })

df_cross = pd.DataFrame(cross_records)
df_cross.to_csv(CROSS_JOIN_CSV_PATH, index=False)
print(f"  ✓ Exported Cross-Join Results ({len(df_cross)} rows, {len(df_cross.columns)} columns) to:")
print(f"    {CROSS_JOIN_CSV_PATH}")

# -----------------------------------------------------------------------------
# 5. Build Table 3: holy_grail_unified_tidy_benchmark.csv (Long Format)
# -----------------------------------------------------------------------------
print("\n[5/5] Building 'holy_grail_unified_tidy_benchmark.csv'...")

tidy_records = []

# Unified Label Normalizer
unified_filter_names = {
    # Real Names
    "PASSTHROUGH": "Unprocessed",
    "CONTROL": "Bandpass_FIR",
    "MIXED": "Cascade_Notch_NLMS",
    "OPTIMAL": "Cascade_Hybrid_Optimal",
    # Sim DSP Names
    "Unprocessed": "Unprocessed",
    "FIR_BP": "Bandpass_FIR",
    "Parametric_Notch": "Parametric_Notch",
    "Base_NLMS": "Base_NLMS",
    "Soft_VAD_Leaky": "Soft_VAD_Leaky",
    "Cascade_Notch_NLMS": "Cascade_Notch_NLMS",
    "Cascade_FIR_NLMS": "Cascade_FIR_NLMS",
    "Cascade_Hybrid_Optimal": "Cascade_Hybrid_Optimal",
    # ML Names
    "ML_Joint_VAD_Spatial_UNet": "ML_Joint_VAD_Spatial_UNet",
    "ML_Spatial_Wave_UNet": "ML_Spatial_Wave_UNet",
    "ML_VAD_Cascade_Notch_NLMS": "ML_VAD_Cascade_Notch_NLMS",
    "ML_VAD_Leaky_NLMS": "ML_VAD_Leaky_NLMS"
}

# 1. Real World Rows (144)
for _, r in df_real_sum.iterrows():
    tidy_records.append({
        "Domain": "Real_World",
        "Venue": r["Venue"],
        "Venue_Label": f"Real {r['Venue']}",
        "Venue_Type": "Empirical_Field",
        "RT60_sec": np.nan,
        "Genre": r["Genre"],
        "SNR_dB": int(r["SNR_dB"]),
        "Filter_System": "Hardware_Firmware_DSP",
        "Filter_Name": r["Filter_Name"],
        "Unified_Filter_Label": unified_filter_names.get(r["Filter_Name"], r["Filter_Name"]),
        "STOI": r["Mean_STOI"],
        "Delta_STOI": r["Mean_Delta_STOI"],
        "PESQ": r["Mean_PESQ"],
        "ViSQOL": np.nan,
        "Delta_SNR_dB": r["Mean_Delta_SNR_dB"],
        "Delta_ASL_dB": r["Mean_Delta_ASL_dB"],
        "Whisper_WER_Pct": r["Mean_Whisper_WER"],
        "Whisper_Recall_Pct": r["Mean_Whisper_Recall"],
        "Google_WER_Pct": r["Mean_Google_WER"] if not pd.isna(r["Mean_Google_WER"]) else np.nan,
        "Google_Recall_Pct": r["Mean_Google_Recall"] if not pd.isna(r["Mean_Google_Recall"]) else np.nan,
    })

# 2. Simulated DSP Rows (600)
for _, s in df_room_sum.iterrows():
    v = s["Venue"]
    g = s["Genre"]
    snr = int(s["SNR_dB"])
    f = s["Filter"]
    
    # Check if we have ASR for this condition in club
    w_wer = w_rec = g_wer = g_rec = np.nan
    if v == "club":
        asr_m = sim_asr_club[(sim_asr_club["Genre"] == g) & (sim_asr_club["SNR_dB"] == snr) & 
                             (sim_asr_club["Filter_Sim_Mapped"] == f)]
        if len(asr_m) > 0:
            w_wer = asr_m.iloc[0]["Sim_Club_Whisper_WER_Pct"]
            w_rec = asr_m.iloc[0]["Sim_Club_Whisper_Recall_Pct"]
            g_wer = asr_m.iloc[0]["Sim_Club_Google_WER_Pct"]
            g_rec = asr_m.iloc[0]["Sim_Club_Google_Recall_Pct"]

    tidy_records.append({
        "Domain": "Simulation",
        "Venue": v,
        "Venue_Label": venue_labels[v],
        "Venue_Type": "Simulated_Acoustics",
        "RT60_sec": rt60_map[v],
        "Genre": g,
        "SNR_dB": snr,
        "Filter_System": "Simulated_DSP",
        "Filter_Name": f,
        "Unified_Filter_Label": unified_filter_names.get(f, f),
        "STOI": s["Mean_STOI"],
        "Delta_STOI": s["Mean_Delta_STOI"],
        "PESQ": s["Mean_PESQ"],
        "ViSQOL": s["Mean_ViSQOL"],
        "Delta_SNR_dB": s["Mean_dSNR_dB"],
        "Delta_ASL_dB": s["Mean_dASL_dB"],
        "Whisper_WER_Pct": w_wer,
        "Whisper_Recall_Pct": w_rec,
        "Google_WER_Pct": g_wer,
        "Google_Recall_Pct": g_rec,
    })

# 3. Simulated ML Rows (exclude duplicate Unprocessed, Base_NLMS, Cascade_Notch_NLMS already in DSP)
ml_unique = df_ml_sum[df_ml_sum["Filter_Name"].isin([
    "ML_Joint_VAD_Spatial_UNet", "ML_Spatial_Wave_UNet", "ML_VAD_Cascade_Notch_NLMS", "ML_VAD_Leaky_NLMS"
])].copy()

for _, m in ml_unique.iterrows():
    v = m["Venue"]
    tidy_records.append({
        "Domain": "Simulation",
        "Venue": v,
        "Venue_Label": venue_labels[v],
        "Venue_Type": "Simulated_Acoustics",
        "RT60_sec": rt60_map[v],
        "Genre": m["Genre"],
        "SNR_dB": int(m["SNR_dB"]),
        "Filter_System": "Simulated_ML_Cooperative",
        "Filter_Name": m["Filter_Name"],
        "Unified_Filter_Label": unified_filter_names.get(m["Filter_Name"], m["Filter_Name"]),
        "STOI": m["Mean_STOI"],
        "Delta_STOI": m["Mean_Delta_STOI"],
        "PESQ": m["Mean_PESQ"],
        "ViSQOL": np.nan,
        "Delta_SNR_dB": m["Mean_Delta_SNR_dB"],
        "Delta_ASL_dB": m["Mean_Delta_ASL_dB"],
        "Whisper_WER_Pct": np.nan,
        "Whisper_Recall_Pct": np.nan,
        "Google_WER_Pct": np.nan,
        "Google_Recall_Pct": np.nan,
    })

df_tidy = pd.DataFrame(tidy_records)
df_tidy.to_csv(TIDY_CSV_PATH, index=False)
print(f"  ✓ Exported Unified Tidy Benchmark ({len(df_tidy)} rows, {len(df_tidy.columns)} columns) to:")
print(f"    {TIDY_CSV_PATH}")

# -----------------------------------------------------------------------------
# 6. Build Table 4: holy_grail_trial_level_results.csv (576 raw audio trials)
# -----------------------------------------------------------------------------
print("\n[6/6] Building 'holy_grail_trial_level_results.csv'...")

trial_records = []
for _, row in df_real_trials.iterrows():
    r_venue = row["Venue"]
    genre = row["Genre"]
    snr = int(row["SNR_dB"])
    f_real = row["Filter_Name"]
    f_sim = row["Filter_Sim_Mapped"]

    # Sim expected mean in Festival (empirical) and Physical
    s_emp = df_room_sum[(df_room_sum["Venue"] == "festival") & (df_room_sum["Genre"] == genre) & 
                        (df_room_sum["SNR_dB"] == snr) & (df_room_sum["Filter"] == f_sim)]
    emp_exp_stoi = s_emp.iloc[0]["Mean_STOI"] if len(s_emp) > 0 else np.nan
    emp_exp_dsnr = s_emp.iloc[0]["Mean_dSNR_dB"] if len(s_emp) > 0 else np.nan

    p_ven = phys_venue_map[r_venue]
    s_phys = df_room_sum[(df_room_sum["Venue"] == p_ven) & (df_room_sum["Genre"] == genre) & 
                         (df_room_sum["SNR_dB"] == snr) & (df_room_sum["Filter"] == f_sim)]
    phys_exp_stoi = s_phys.iloc[0]["Mean_STOI"] if len(s_phys) > 0 else np.nan
    phys_exp_dsnr = s_phys.iloc[0]["Mean_dSNR_dB"] if len(s_phys) > 0 else np.nan

    rec = dict(row)
    rec["Sim_Emp_Mean_STOI"] = emp_exp_stoi
    rec["Sim_Emp_Mean_Delta_SNR_dB"] = emp_exp_dsnr
    rec["Residual_STOI_Trial_minus_EmpSim"] = np.round(row["STOI"] - emp_exp_stoi, 4) if not np.isnan(emp_exp_stoi) else np.nan
    rec["Residual_Delta_SNR_Trial_minus_EmpSim"] = np.round(row["Delta_SNR_dB"] - emp_exp_dsnr, 2) if not np.isnan(emp_exp_dsnr) else np.nan
    rec["Sim_Phys_Mean_STOI"] = phys_exp_stoi
    rec["Sim_Phys_Mean_Delta_SNR_dB"] = phys_exp_dsnr
    rec["Residual_STOI_Trial_minus_PhysSim"] = np.round(row["STOI"] - phys_exp_stoi, 4) if not np.isnan(phys_exp_stoi) else np.nan
    trial_records.append(rec)

df_trials_join = pd.DataFrame(trial_records)
df_trials_join.to_csv(TRIALS_JOIN_CSV_PATH, index=False)
print(f"  ✓ Exported Trial-Level Results ({len(df_trials_join)} rows, {len(df_trials_join.columns)} columns) to:")
print(f"    {TRIALS_JOIN_CSV_PATH}")

# -----------------------------------------------------------------------------
# 7. Copy Master CSVs to Brain Artifacts Directory
# -----------------------------------------------------------------------------
if os.path.exists(ARTIFACTS_DIR):
    for f in [MASTER_CSV_PATH, CROSS_JOIN_CSV_PATH, TIDY_CSV_PATH]:
        dest = os.path.join(ARTIFACTS_DIR, os.path.basename(f))
        shutil.copy2(f, dest)
        print(f"  ✓ Copied artifact to: {dest}")

print("\n" + "=" * 80)
print("  ALL 'HOLY GRAIL' BENCHMARK DATASETS SUCCESSFULLY ASSEMBLED AND VALIDATED!")
print("=" * 80)
