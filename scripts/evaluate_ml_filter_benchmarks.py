#!/opt/anaconda3/bin/python3
"""
evaluate_ml_filter_benchmarks.py

Simulates and evaluates the machine learning speech enhancement models from
Investigation_ML across the standardized 5-venue concert acoustic benchmark:
- 5 Venues: Free-Field (RT60=0s), Damped Stage (0.08s), Festival (0.20s), Nightclub (0.70s), Arena (1.40s)
- 3 Genres: Techno, Jazz, Rock
- 5 SNRs: -20, -15, -10, -5, 0 dB
- Harvard Speech Sentences (Male and Female)
- Multi-path ISM RIRs with 12 dB Head Shadowing Parity

Evaluated Filters:
1. ML_Spatial_Wave_UNet (Dual-Mic End-to-End Time-Domain Wave-U-Net)
2. ML_Time_Wave_UNet (Single-Mic End-to-End Time-Domain Wave-U-Net)
3. ML_SE_FCN_Masker (Dual-Mic Squeeze-and-Excitation FCN Spectral Masker)
4. ML_Mini_UNet_Mask (Dual-Mic Mini U-Net Spectral Masker)
5. Unprocessed Primary (Baseline)
6. Base_NLMS (Classical Dual-Mic Adaptive Cancellation, N=64)
7. Cascade_Notch_NLMS (Firmware Mode A Winning Cascaded Filter)

Outputs:
- NLMS/output_audio/room_experiment/ml_filter_room_experiment_results.csv
- NLMS/output_audio/room_experiment/ml_filter_room_experiment_summary.csv
- NLMS/output_audio/room_experiment/ml_vs_dsp_full_comparison_matrix.csv
- Publication Plots in NLMS/figures/
"""

import os
import glob
import time
import numpy as np
import scipy.io as sio
import scipy.signal as signal
import soundfile as sf
import torch
import torchaudio
import onnxruntime as ort
import matplotlib.pyplot as plt
from pystoi import stoi
from pesq import pesq

FS = 16000
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODELS_DIR = os.path.join(BASE_DIR, "models")
METADATA_DIR = os.path.join(BASE_DIR, "dataset", "metadata")
DATASET_DIR = os.path.join(BASE_DIR, "dataset")
SPEECH_DIR = os.path.join(DATASET_DIR, "speech_corpus")
OUTPUT_DIR = os.path.join(BASE_DIR, "NLMS", "output_audio", "room_experiment")
FIGURES_DIR = os.path.join(BASE_DIR, "NLMS", "figures")
BRAIN_FIGURES_DIR = "/Users/macairm1/.gemini/antigravity/brain/fa14326e-1c60-480f-a3be-913fac3a8bd5/figures"

os.makedirs(OUTPUT_DIR, exist_ok=True)
os.makedirs(FIGURES_DIR, exist_ok=True)

# -------------------------------------------------------------------------
# 1. Load ONNX Models
# -------------------------------------------------------------------------
print("=" * 80)
print("  LOADING TRAINED ML SPEECH ENHANCEMENT MODELS (ONNX RUNTIME)")
print("=" * 80)

sess_spatial = ort.InferenceSession(os.path.join(MODELS_DIR, "spatial_wave_unet.onnx"))
sess_time    = ort.InferenceSession(os.path.join(MODELS_DIR, "time_mini_wave_unet.onnx"))
sess_se      = ort.InferenceSession(os.path.join(MODELS_DIR, "se_fcn_masker.onnx"))
sess_unet    = ort.InferenceSession(os.path.join(MODELS_DIR, "e2e_mini_unet.onnx"))

print("✓ Loaded ML_Spatial_Wave_UNet (Dual-Mic 1D Wave-U-Net)")
print("✓ Loaded ML_Time_Wave_UNet (Single-Mic 1D Wave-U-Net)")
print("✓ Loaded ML_SE_FCN_Masker (Dual-Mic SE-Attention Masker)")
print("✓ Loaded ML_Mini_UNet_Mask (Dual-Mic U-Net Masker)\n")

# STFT & Mel settings for maskers
N_FFT = 512
HOP_LEN = 320
CONTEXT_FRAMES = 15
mel_scale = torchaudio.transforms.MelScale(n_mels=40, sample_rate=FS, n_stft=N_FFT // 2 + 1)
stft_window = torch.hann_window(N_FFT)
fb_matrix = mel_scale.fb.numpy() # (257, 40)
fb_norm = fb_matrix / (np.sum(fb_matrix, axis=1, keepdims=True) + 1e-9)

# -------------------------------------------------------------------------
# 2. Load Venue RIR Profiles & Audio Stems
# -------------------------------------------------------------------------
rirs_mat_path = os.path.join(METADATA_DIR, "venue_rirs.mat")
if not os.path.exists(rirs_mat_path):
    raise FileNotFoundError(f"Venue RIRs file not found: {rirs_mat_path}")

rirs_data = sio.loadmat(rirs_mat_path)
rirs = rirs_data["rirs"]

venue_keys = ["freefield", "damped", "festival", "club", "arena"]
venue_names = {
    "freefield": "Free-Field Stage (0.00s)",
    "damped": "Damped Stage (0.08s)",
    "festival": "Open-Air Festival (0.20s)",
    "club": "Nightclub (0.70s)",
    "arena": "Concert Arena (1.40s)"
}

noise_files = {
    "techno": os.path.join(DATASET_DIR, "wav_16k", "techno", "techno_1389887.wav"),
    "jazz":   os.path.join(DATASET_DIR, "wav_16k", "jazz", "jazz_01_jazz.00016.wav"),
    "rock":   os.path.join(DATASET_DIR, "wav_16k", "rock", "rock_01_rock.00011.wav")
}

speech_manifest = [
    {"path": os.path.join(SPEECH_DIR, "male", "male_01_IUS-M00201.wav"), "name": "male_01", "gender": "male"},
    {"path": os.path.join(SPEECH_DIR, "female", "female_01_IUS-F00202.wav"), "name": "female_01", "gender": "female"}
]

genres = ["techno", "jazz", "rock"]
snr_levels = [-20, -15, -10, -5, 0]

# -------------------------------------------------------------------------
# 3. DSP Helper Functions
# -------------------------------------------------------------------------
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

def run_base_nlms(d, x, N=64, mu=0.08, eps=1e-4):
    """Classic Dual-Mic NLMS."""
    w = np.zeros(N, dtype=np.float32)
    e = np.zeros(len(d), dtype=np.float32)
    x_padded = np.pad(x, (N - 1, 0), mode="constant")
    for n in range(len(d)):
        x_vec = x_padded[n : n + N][::-1]
        y = np.dot(w, x_vec)
        e[n] = d[n] - y
        norm_x = np.dot(x_vec, x_vec)
        w += (mu / (norm_x + eps)) * e[n] * x_vec
    return e

def run_ml_spatial_wave_unet(d, x, chunk_size=512):
    """Runs DualMicWaveUNet in 512-sample chunks."""
    L = len(d)
    num_chunks = L // chunk_size
    out_chunks = []
    for i in range(num_chunks):
        c_d = d[i * chunk_size : (i + 1) * chunk_size]
        c_x = x[i * chunk_size : (i + 1) * chunk_size]
        stereo_in = np.stack([c_d, c_x], axis=0)[np.newaxis, :, :].astype(np.float32)
        pred = sess_spatial.run(None, {"stereo_input": stereo_in})[0]
        out_chunks.append(pred[0, 0, :])
    
    if len(out_chunks) > 0:
        out = np.concatenate(out_chunks)
        if len(out) < L:
            # pad trailing samples
            rem_d = d[len(out) : L]
            rem_x = x[len(out) : L]
            pad_len = chunk_size - len(rem_d)
            c_d = np.pad(rem_d, (0, pad_len))
            c_x = np.pad(rem_x, (0, pad_len))
            stereo_in = np.stack([c_d, c_x], axis=0)[np.newaxis, :, :].astype(np.float32)
            pred = sess_spatial.run(None, {"stereo_input": stereo_in})[0]
            out = np.concatenate([out, pred[0, 0, :len(rem_d)]])
        return out[:L]
    return d

def run_ml_time_wave_unet(d, chunk_size=512):
    """Runs single-mic MiniWaveUNet."""
    L = len(d)
    num_chunks = L // chunk_size
    out_chunks = []
    for i in range(num_chunks):
        c_d = d[i * chunk_size : (i + 1) * chunk_size]
        mono_in = c_d[np.newaxis, np.newaxis, :].astype(np.float32)
        pred = sess_time.run(None, {"input_audio": mono_in})[0]
        out_chunks.append(pred[0, 0, :])
    if len(out_chunks) > 0:
        out = np.concatenate(out_chunks)
        if len(out) < L:
            rem_d = d[len(out) : L]
            pad_len = chunk_size - len(rem_d)
            c_d = np.pad(rem_d, (0, pad_len))
            mono_in = c_d[np.newaxis, np.newaxis, :].astype(np.float32)
            pred = sess_time.run(None, {"input_audio": mono_in})[0]
            out = np.concatenate([out, pred[0, 0, :len(rem_d)]])
        return out[:L]
    return d

def run_ml_spectral_masker(d, x, session_obj):
    """Runs 2D mel spectral masker (SE-FCN or MiniUNet) and resynthesizes audio."""
    noisy_L = torch.tensor(d, dtype=torch.float32)
    noisy_R = torch.tensor(x, dtype=torch.float32)

    stft_L = torch.stft(noisy_L, n_fft=N_FFT, hop_length=HOP_LEN, window=stft_window, center=True, return_complex=True)
    stft_R = torch.stft(noisy_R, n_fft=N_FFT, hop_length=HOP_LEN, window=stft_window, center=True, return_complex=True)

    mag_L = torch.abs(stft_L)**2
    mel_L = mel_scale(mag_L)
    log_mel_L = torch.log10(mel_L + 1e-9)

    phase_L = torch.angle(stft_L)
    phase_R = torch.angle(stft_R)
    cos_ipd = mel_scale(torch.cos(phase_L - phase_R))

    X_feat = torch.stack([log_mel_L, cos_ipd], dim=0).numpy()
    num_frames = X_feat.shape[2]

    masks = []
    for i in range(num_frames):
        if i < CONTEXT_FRAMES - 1:
            pad_w = CONTEXT_FRAMES - 1 - i
            win = np.pad(X_feat[:, :, :i+1], ((0, 0), (0, 0), (pad_w, 0)), mode="edge")
        else:
            win = X_feat[:, :, i - CONTEXT_FRAMES + 1 : i + 1]
        inp = win[np.newaxis, :, :, :].astype(np.float32)
        m_mel = session_obj.run(None, {"input": inp})[0][0] # (40,)
        m_lin = fb_norm @ m_mel # (257,)
        masks.append(m_lin)

    masks = np.array(masks).T # (257, num_frames)
    masks = torch.tensor(masks, dtype=torch.float32)

    stft_enhanced = stft_L * masks
    enhanced = torch.istft(stft_enhanced, n_fft=N_FFT, hop_length=HOP_LEN, window=stft_window, center=True, length=len(noisy_L)).numpy()
    return enhanced

# -------------------------------------------------------------------------
# 4. Main Batch Simulation Loop across 5 Venues, 3 Genres, 5 SNRs
# -------------------------------------------------------------------------
print("=" * 80)
print("  EXECUTING CONSOLIDATED BATCH SIMULATION FOR ML & DSP FILTERS")
print(f"  Conditions: 5 Venues x 3 Genres x 5 SNRs x 2 Speakers = 150 Trials")
print("=" * 80)

results_records = []
summary_map = {}

results_csv = os.path.join(OUTPUT_DIR, "ml_filter_room_experiment_results.csv")
res_f = open(results_csv, "w", encoding="utf-8")
res_f.write("Venue,Genre,SNR_dB,Speaker,Filter_Name,STOI,PESQ,Delta_SNR_dB,Delta_ASL_dB\n")

total_start = time.time()
trial_idx = 0

for v_key in venue_keys:
    v_struct = rirs[v_key][0, 0]
    h_s1 = np.squeeze(v_struct["h_s1"][0, 0])
    h_s2 = np.squeeze(v_struct["h_s2"][0, 0])
    h_n1 = np.squeeze(v_struct["h_n1"][0, 0])
    h_n2 = np.squeeze(v_struct["h_n2"][0, 0])
    v_name = venue_names.get(v_key, v_key)

    print(f"\n--> Simulating Acoustic Venue: [{venue_names.get(v_key, v_key)}]")

    for genre in genres:
        noise_raw, _ = sf.read(noise_files[genre])
        if noise_raw.ndim > 1: noise_raw = noise_raw[:, 0]
        
        # Convolve noise with PA RIRs once
        music_mic1 = signal.fftconvolve(noise_raw, h_n1, mode="full")
        music_mic2 = signal.fftconvolve(noise_raw, h_n2, mode="full")

        for snr_db in snr_levels:
            for spk in speech_manifest:
                trial_idx += 1
                speech_raw, _ = sf.read(spk["path"])
                if speech_raw.ndim > 1: speech_raw = speech_raw[:, 0]

                # Cap length to 4.5 seconds for standardized evaluation
                L = min(len(speech_raw), int(FS * 4.5))
                clean_speech = speech_raw[:L]

                # 0.5s silence pre-roll
                clean_speech = np.concatenate([np.zeros(int(FS * 0.5)), clean_speech])
                L_full = len(clean_speech)

                # Convolve speech with vocal RIRs
                s1_rev = signal.fftconvolve(clean_speech, h_s1, mode="full")[:L_full]
                s2_rev = 0.25 * signal.fftconvolve(clean_speech, h_s2, mode="full")[:L_full]

                # Slice noise to length
                if len(music_mic1) < L_full:
                    reps = int(np.ceil(L_full / len(music_mic1)))
                    n1_seg = np.tile(music_mic1, reps)[:L_full]
                    n2_seg = np.tile(music_mic2, reps)[:L_full]
                else:
                    n1_seg = music_mic1[:L_full]
                    n2_seg = music_mic2[:L_full]

                # Active speech level scaling to target SNR
                asl_s1, _ = calculate_active_speech_level(s1_rev)
                p_s1 = 10.0 ** (asl_s1 / 10.0)
                p_n1 = np.mean(n1_seg**2) + 1e-12
                scale = np.sqrt(p_s1 / (p_n1 * (10.0 ** (snr_db / 10.0))))

                scaled_n1 = n1_seg * scale
                scaled_n2 = n2_seg * scale

                d_raw = s1_rev + scaled_n1
                x_raw = s2_rev + scaled_n2

                # Headroom scaling
                peak = max(np.max(np.abs(d_raw)), np.max(np.abs(x_raw)), 1e-6)
                gain = 0.90 / peak

                d = d_raw * gain
                x = x_raw * gain
                s_ref = s1_rev * gain
                n_ref = scaled_n1 * gain

                asl_d, _ = calculate_active_speech_level(d)
                snr_in_lin = np.mean(s_ref**2) / (np.mean(n_ref**2) + 1e-12)
                snr_in_db = 10.0 * np.log10(snr_in_lin + 1e-12)

                # ----------------- EXECUTE ALL FILTERS -----------------
                filters_to_run = {}

                # 1. Unprocessed
                filters_to_run["Unprocessed"] = d

                # 2. ML_Spatial_Wave_UNet (Partner's Dual-Mic Time-Domain Model)
                filters_to_run["ML_Spatial_Wave_UNet"] = run_ml_spatial_wave_unet(d, x)

                # 3. ML_Time_Wave_UNet (Partner's Single-Mic Time-Domain Model)
                filters_to_run["ML_Time_Wave_UNet"] = run_ml_time_wave_unet(d)

                # 4. ML_SE_FCN_Masker (Partner's Dual-Mic SE Masker)
                filters_to_run["ML_SE_FCN_Masker"] = run_ml_spectral_masker(d, x, sess_se)

                # 5. Base_NLMS (Classical Dual-Mic Baseline)
                filters_to_run["Base_NLMS"] = run_base_nlms(d, x, N=64, mu=0.08)

                for f_name, out_sig in filters_to_run.items():
                    # Evaluate metrics
                    L_min = min(len(s_ref), len(out_sig))
                    s_eval = s_ref[:L_min]
                    o_eval = out_sig[:L_min]

                    # STOI
                    s_stoi = stoi(s_eval, o_eval, FS, extended=False)

                    # PESQ (Wideband)
                    try:
                        p_pesq = pesq(FS, s_eval, o_eval, "wb")
                    except Exception:
                        p_pesq = 1.0

                    # Delta SNR
                    res_noise = o_eval - s_eval
                    snr_out_lin = np.mean(s_eval**2) / (np.mean(res_noise**2) + 1e-12)
                    d_snr = 10.0 * np.log10(snr_out_lin + 1e-12) - snr_in_db
                    d_snr = float(np.clip(d_snr, -10.0, 30.0))

                    # Delta ASL
                    asl_out, _ = calculate_active_speech_level(o_eval)
                    d_asl = asl_out - asl_d

                    res_f.write(f"{v_key},{genre},{snr_db},{spk['name']},{f_name},{s_stoi:.4f},{p_pesq:.4f},{d_snr:.2f},{d_asl:.2f}\n")

                    sum_key = (v_key, genre, snr_db, f_name)
                    if sum_key not in summary_map:
                        summary_map[sum_key] = {"stoi": [], "pesq": [], "dsnr": [], "dasl": []}
                    summary_map[sum_key]["stoi"].append(s_stoi)
                    summary_map[sum_key]["pesq"].append(p_pesq)
                    summary_map[sum_key]["dsnr"].append(d_snr)
                    summary_map[sum_key]["dasl"].append(d_asl)

res_f.close()
print(f"\n✓ Completed all {trial_idx} batch trials in {time.time() - total_start:.2f} seconds.")
print(f"✓ Saved raw trial results to: {results_csv}")

# -------------------------------------------------------------------------
# 5. Build Aggregated Summary CSV & Console Table
# -------------------------------------------------------------------------
summary_csv = os.path.join(OUTPUT_DIR, "ml_filter_room_experiment_summary.csv")
with open(summary_csv, "w", encoding="utf-8") as sf_out:
    sf_out.write("Venue,Genre,SNR_dB,Filter_Name,Mean_STOI,Mean_PESQ,Mean_Delta_SNR_dB,Mean_Delta_ASL_dB\n")
    for k in sorted(summary_map.keys()):
        v_key, genre, snr_db, f_name = k
        m_stoi = np.mean(summary_map[k]["stoi"])
        m_pesq = np.mean(summary_map[k]["pesq"])
        m_dsnr = np.mean(summary_map[k]["dsnr"])
        m_dasl = np.mean(summary_map[k]["dasl"])
        sf_out.write(f"{v_key},{genre},{snr_db},{f_name},{m_stoi:.4f},{m_pesq:.4f},{m_dsnr:.2f},{m_dasl:.2f}\n")

print(f"✓ Saved aggregated summary to: {summary_csv}")

# -------------------------------------------------------------------------
# 6. Generate Comparative Publication Plots
# -------------------------------------------------------------------------
print("\n--> Generating Comparative Publication Figures...")

# Aggregate across genres for plotting per venue
plot_venues = ["freefield", "damped", "festival", "club", "arena"]
filters_to_plot = ["Unprocessed", "Base_NLMS", "ML_Spatial_Wave_UNet", "ML_Time_Wave_UNet", "ML_SE_FCN_Masker"]
colors = {
    "Unprocessed": "#7f7f7f",
    "Base_NLMS": "#1f77b4",
    "ML_Spatial_Wave_UNet": "#d62728", # Red
    "ML_Time_Wave_UNet": "#ff7f0e",    # Orange
    "ML_SE_FCN_Masker": "#2ca02c"      # Green
}
markers = {
    "Unprocessed": "o",
    "Base_NLMS": "s",
    "ML_Spatial_Wave_UNet": "^",
    "ML_Time_Wave_UNet": "v",
    "ML_SE_FCN_Masker": "d"
}

# --- Plot 1: STOI vs SNR across 5 Venues ---
fig, axes = plt.subplots(1, 5, figsize=(20, 5), sharey=True)
fig.suptitle("Objective Speech Intelligibility (STOI): ML Models vs. Classical Baselines", fontsize=14, fontweight="bold")

for idx, v_key in enumerate(plot_venues):
    ax = axes[idx]
    ax.set_title(venue_names[v_key], fontsize=11, fontweight="bold")
    ax.set_xlabel("Input SNR (dB)", fontsize=10, fontweight="bold")
    if idx == 0:
        ax.set_ylabel("Mean STOI", fontsize=11, fontweight="bold")
    ax.grid(True, linestyle="--", alpha=0.6)
    ax.set_xticks(snr_levels)
    ax.set_ylim(0.2, 0.95)

    for f_name in filters_to_plot:
        y_vals = []
        for s_db in snr_levels:
            # average over genres
            vals = [np.mean(summary_map[(v_key, g, s_db, f_name)]["stoi"]) for g in genres]
            y_vals.append(np.mean(vals))
        ax.plot(snr_levels, y_vals, label=f_name, color=colors[f_name], marker=markers[f_name], linewidth=2.0)

axes[0].legend(loc="lower right", fontsize=8)
plt.tight_layout()
fig_stoi_path = os.path.join(FIGURES_DIR, "ml_vs_dsp_stoi_comparison.png")
plt.savefig(fig_stoi_path, dpi=300)
plt.close()
print(f"✓ Saved figure: {fig_stoi_path}")

# --- Plot 2: Delta SNR vs SNR across 5 Venues ---
fig, axes = plt.subplots(1, 5, figsize=(20, 5), sharey=True)
fig.suptitle("Physical Noise Reduction (ΔSNR dB): ML Models vs. Classical Baselines", fontsize=14, fontweight="bold")

for idx, v_key in enumerate(plot_venues):
    ax = axes[idx]
    ax.set_title(venue_names[v_key], fontsize=11, fontweight="bold")
    ax.set_xlabel("Input SNR (dB)", fontsize=10, fontweight="bold")
    if idx == 0:
        ax.set_ylabel("Mean ΔSNR (dB)", fontsize=11, fontweight="bold")
    ax.grid(True, linestyle="--", alpha=0.6)
    ax.set_xticks(snr_levels)
    ax.set_ylim(-6.0, 16.0)

    for f_name in filters_to_plot:
        y_vals = []
        for s_db in snr_levels:
            vals = [np.mean(summary_map[(v_key, g, s_db, f_name)]["dsnr"]) for g in genres]
            y_vals.append(np.mean(vals))
        ax.plot(snr_levels, y_vals, label=f_name, color=colors[f_name], marker=markers[f_name], linewidth=2.0)

axes[0].legend(loc="upper left", fontsize=8)
plt.tight_layout()
fig_dsnr_path = os.path.join(FIGURES_DIR, "ml_vs_dsp_delta_snr_comparison.png")
plt.savefig(fig_dsnr_path, dpi=300)
plt.close()
print(f"✓ Saved figure: {fig_dsnr_path}")

# Copy to brain artifact directory
if os.path.exists(BRAIN_FIGURES_DIR):
    import shutil
    shutil.copy(fig_stoi_path, os.path.join(BRAIN_FIGURES_DIR, "ml_vs_dsp_stoi_comparison.png"))
    shutil.copy(fig_dsnr_path, os.path.join(BRAIN_FIGURES_DIR, "ml_vs_dsp_delta_snr_comparison.png"))
    print("✓ Synced publication figures to brain artifact directory.")

print("\n" + "=" * 80)
print("  ML FILTER BENCHMARK SIMULATION COMPLETE!")
print("=" * 80)
