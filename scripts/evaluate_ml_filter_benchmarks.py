#!/opt/anaconda3/bin/python3
"""
evaluate_ml_filter_benchmarks.py

Simulates and evaluates the machine learning speech enhancement models from
Investigation_ML operating BOTH as standalone filters and as cooperative single
pipelines (Joint Neural VAD + Neural Filter, and Hybrid Neural VAD + Adaptive Filter)
across the standardized 5-venue concert acoustic benchmark:

- 5 Venues: Free-Field (RT60=0s), Damped Stage (0.08s), Festival (0.20s), Nightclub (0.70s), Arena (1.40s)
- 3 Genres: Techno, Jazz, Rock
- 5 SNRs: -20, -15, -10, -5, 0 dB
- Harvard Speech Sentences (Male and Female)
- Multi-path ISM RIRs with 12 dB Head Shadowing Parity

Evaluated Filters & Pipelines:
1. Unprocessed Primary (Baseline)
2. Base_NLMS (Classical Dual-Mic Adaptive Cancellation, N=64)
3. Cascade_Notch_NLMS (Firmware Mode A Winning Cascaded Filter)
4. ML_Spatial_Wave_UNet (Partner's Standalone Dual-Mic 1D Wave-U-Net)
5. ML_Joint_VAD_Spatial_UNet (Cooperative Pipeline: Neural VAD + 1D Wave-U-Net Gating)
6. ML_VAD_Leaky_NLMS (Hybrid ML-DSP: Neural VAD Modulating Dual-Mic Leaky NLMS)
7. ML_VAD_Cascade_Notch_NLMS (Hybrid ML-DSP: Neural VAD Modulating Cascade Notch NLMS)

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
if os.path.exists(os.path.dirname(BRAIN_FIGURES_DIR)):
    os.makedirs(BRAIN_FIGURES_DIR, exist_ok=True)

# -------------------------------------------------------------------------
# 1. Load ONNX Models
# -------------------------------------------------------------------------
print("=" * 80)
print("  LOADING TRAINED ML SPEECH ENHANCEMENT MODELS (ONNX RUNTIME)")
print("=" * 80)

sess_vad     = ort.InferenceSession(os.path.join(MODELS_DIR, "hybrid_cnn.onnx"))
sess_spatial = ort.InferenceSession(os.path.join(MODELS_DIR, "spatial_wave_unet.onnx"))
sess_time    = ort.InferenceSession(os.path.join(MODELS_DIR, "time_mini_wave_unet.onnx"))
sess_se      = ort.InferenceSession(os.path.join(MODELS_DIR, "se_fcn_masker.onnx"))

print("✓ Loaded hybrid_cnn.onnx (Voice Activity Detector VAD)")
print("✓ Loaded spatial_wave_unet.onnx (Dual-Mic 1D Wave-U-Net Music Filter)")
print("✓ Loaded time_mini_wave_unet.onnx (Single-Mic 1D Wave-U-Net Music Filter)")
print("✓ Loaded se_fcn_masker.onnx (Dual-Mic SE Spectral Masker)\n")

# STFT & Mel settings for VAD and Maskers
N_FFT = 512
HOP_LEN = 320
CONTEXT_FRAMES = 15
mel_scale = torchaudio.transforms.MelScale(n_mels=40, sample_rate=FS, n_stft=N_FFT // 2 + 1)
stft_window = torch.hann_window(N_FFT)
fb_matrix = mel_scale.fb.numpy()  # (257, 40)
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

# Precompute Genre Notch Biquads
def apply_genre_notch(sig, genre, fs=16000):
    """Applies surgical parametric notch cascade matching MATLAB benchmark exactly."""
    if genre == "techno":
        b0, a0 = signal.iirnotch(62.5, 4.0, fs)
        b1, a1 = signal.iirnotch(125.0, 6.0, fs)
        return signal.lfilter(b1, a1, signal.lfilter(b0, a0, sig))
    elif genre == "rock":
        b0, a0 = signal.iirnotch(109.0, 5.0, fs)
        return signal.lfilter(b0, a0, sig)
    elif genre == "jazz":
        b0, a0 = signal.iirnotch(40.0, 3.0, fs)
        return signal.lfilter(b0, a0, sig)
    return sig

# -------------------------------------------------------------------------
# 3. Filter and Pipeline Implementation
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

def run_cascade_notch_nlms(d, x, genre, N=64, mu=0.08, eps=1e-4):
    """Cascade Notch -> NLMS."""
    d_notched = apply_genre_notch(d, genre)
    return run_base_nlms(d_notched, x, N=N, mu=mu, eps=eps)

def extract_neural_vad(d, x):
    """Runs HybridCNN Neural VAD on dual-mic log-mel + IPD features."""
    s_l = torch.tensor(d, dtype=torch.float32)
    s_r = torch.tensor(x, dtype=torch.float32)

    stft_L = torch.stft(s_l, n_fft=N_FFT, hop_length=HOP_LEN, window=stft_window, center=False, return_complex=True)
    stft_R = torch.stft(s_r, n_fft=N_FFT, hop_length=HOP_LEN, window=stft_window, center=False, return_complex=True)

    mag_L_sq = torch.abs(stft_L)**2
    mel_L = mel_scale(mag_L_sq)
    log_mel_L = torch.log10(mel_L + 1e-9)

    phase_L = torch.angle(stft_L)
    phase_R = torch.angle(stft_R)
    cos_ipd = torch.cos(phase_L - phase_R)
    mel_ipd = mel_scale(cos_ipd)

    feats = torch.stack([log_mel_L, mel_ipd], dim=0).numpy()
    num_frames = feats.shape[2]

    vad_probs = []
    for i in range(num_frames):
        if i < CONTEXT_FRAMES - 1:
            pad_w = CONTEXT_FRAMES - 1 - i
            win = np.pad(feats[:, :, :i+1], ((0, 0), (0, 0), (pad_w, 0)), mode="edge")
        else:
            win = feats[:, :, i - CONTEXT_FRAMES + 1 : i + 1]
        p = sess_vad.run(None, {"input": win[np.newaxis, ...].astype(np.float32)})[0][0, 0]
        vad_probs.append(p)

    vad_probs = np.array(vad_probs, dtype=np.float32)
    vad_samples = np.repeat(vad_probs, HOP_LEN)[:len(d)]
    if len(vad_samples) < len(d):
        vad_samples = np.pad(vad_samples, (0, len(d) - len(vad_samples)), mode="edge")
    return vad_probs, vad_samples

def run_ml_vad_leaky_nlms(d, x, vad_samples, N=64, mu0=0.08, gamma=1.0 - 2**(-15), eps=1e-4):
    """
    Hybrid ML-DSP Cooperative Pipeline:
    Neural VAD dynamically halts adaptive step-size during active speech to eliminate
    speech cancellation distortion, while adapting aggressively during pauses.
    """
    w = np.zeros(N, dtype=np.float32)
    e = np.zeros(len(d), dtype=np.float32)
    x_padded = np.pad(x, (N - 1, 0), mode="constant")
    for n in range(len(d)):
        x_vec = x_padded[n : n + N][::-1]
        y = np.dot(w, x_vec)
        e[n] = d[n] - y
        norm_x = np.dot(x_vec, x_vec)
        # Suppress adaptation during active voice bursts
        mu_eff = mu0 * max(0.0, 1.0 - 1.2 * vad_samples[n])
        w = gamma * w + (mu_eff / (norm_x + eps)) * e[n] * x_vec
    return e

def run_ml_vad_cascade_notch_nlms(d, x, genre, vad_samples, N=64, mu0=0.08, gamma=1.0 - 2**(-15), eps=1e-4):
    """Combines Notch Pre-filter + Neural VAD Leaky NLMS."""
    d_notched = apply_genre_notch(d, genre)
    return run_ml_vad_leaky_nlms(d_notched, x, vad_samples, N=N, mu0=mu0, gamma=gamma, eps=eps)

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

def run_joint_vad_spatial_unet(d, x, vad_samples, out_spatial_precomputed=None):
    """
    Cooperative End-to-End Pure ML Pipeline:
    The Neural Filter (Spatial Wave-U-Net) separates speech from music, and the
    Neural VAD (HybridCNN) dynamically gates residual reverb and background music
    leakage during non-speech intervals.
    """
    if out_spatial_precomputed is not None:
        y_spatial = out_spatial_precomputed
    else:
        y_spatial = run_ml_spatial_wave_unet(d, x)
    
    # Dynamic expansion curve: preserves active speech phonemes while attenuating pause leaks
    gate_gain = np.clip((vad_samples - 0.25) / (0.75 - 0.25), 0.08, 1.0)
    return y_spatial * gate_gain

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

                # Standard 4.0s trial with 0.5s silence pre-roll
                L_target = int(FS * 4.0)
                speech_padded = np.zeros(L_target, dtype=np.float32)
                s_part = speech_raw[:min(len(speech_raw), int(FS * 3.5))]
                speech_padded[int(FS * 0.5) : int(FS * 0.5) + len(s_part)] = s_part

                # Convolve speech with vocal RIRs
                s1_rev = signal.fftconvolve(speech_padded, h_s1, mode="full")[:L_target]
                s2_rev = 0.25 * signal.fftconvolve(speech_padded, h_s2, mode="full")[:L_target]

                # Slice noise to length
                if len(music_mic1) < L_target:
                    reps = int(np.ceil(L_target / len(music_mic1)))
                    n1_seg = np.tile(music_mic1, reps)[:L_target]
                    n2_seg = np.tile(music_mic2, reps)[:L_target]
                else:
                    n1_seg = music_mic1[:L_target]
                    n2_seg = music_mic2[:L_target]

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

                # Extract Neural VAD probabilities
                vad_probs, vad_samples = extract_neural_vad(d, x)

                # Precompute spatial wave unet
                spatial_out = run_ml_spatial_wave_unet(d, x)

                # ----------------- EXECUTE ALL 7 FILTERS -----------------
                filters_to_run = {}

                # 1. Unprocessed
                filters_to_run["Unprocessed"] = d

                # 2. Base_NLMS (Classical Dual-Mic Baseline)
                filters_to_run["Base_NLMS"] = run_base_nlms(d, x, N=64, mu=0.08)

                # 3. Cascade_Notch_NLMS (DSP Winner)
                filters_to_run["Cascade_Notch_NLMS"] = run_cascade_notch_nlms(d, x, genre, N=64, mu=0.08)

                # 4. ML_Spatial_Wave_UNet (Partner's Standalone Neural Filter)
                filters_to_run["ML_Spatial_Wave_UNet"] = spatial_out

                # 5. ML_Joint_VAD_Spatial_UNet (Partner's Neural VAD + Neural Filter Pipeline)
                filters_to_run["ML_Joint_VAD_Spatial_UNet"] = run_joint_vad_spatial_unet(d, x, vad_samples, out_spatial_precomputed=spatial_out)

                # 6. ML_VAD_Leaky_NLMS (Neural VAD + Leaky NLMS)
                filters_to_run["ML_VAD_Leaky_NLMS"] = run_ml_vad_leaky_nlms(d, x, vad_samples, N=64, mu0=0.08)

                # 7. ML_VAD_Cascade_Notch_NLMS (Neural VAD + Cascade Notch NLMS)
                filters_to_run["ML_VAD_Cascade_Notch_NLMS"] = run_ml_vad_cascade_notch_nlms(d, x, genre, vad_samples, N=64, mu0=0.08)

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
# 5. Build Aggregated Summary CSV & Comparison Matrix
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

matrix_csv = os.path.join(OUTPUT_DIR, "ml_vs_dsp_full_comparison_matrix.csv")
with open(matrix_csv, "w", encoding="utf-8") as mf_out:
    mf_out.write("Venue,Filter_Name,Mean_STOI,Mean_PESQ,Mean_Delta_SNR_dB\n")
    for v_key in venue_keys:
        for f_name in ["Unprocessed", "Base_NLMS", "Cascade_Notch_NLMS", "ML_Spatial_Wave_UNet", "ML_Joint_VAD_Spatial_UNet", "ML_VAD_Leaky_NLMS", "ML_VAD_Cascade_Notch_NLMS"]:
            st_list, pq_list, ds_list = [], [], []
            for g in genres:
                for s_db in snr_levels:
                    st_list.extend(summary_map[(v_key, g, s_db, f_name)]["stoi"])
                    pq_list.extend(summary_map[(v_key, g, s_db, f_name)]["pesq"])
                    ds_list.extend(summary_map[(v_key, g, s_db, f_name)]["dsnr"])
            mf_out.write(f"{v_key},{f_name},{np.mean(st_list):.4f},{np.mean(pq_list):.4f},{np.mean(ds_list):.2f}\n")

print(f"✓ Saved full comparison matrix to: {matrix_csv}")

# -------------------------------------------------------------------------
# 6. Generate Publication Figures
# -------------------------------------------------------------------------
print("\n--> Generating Publication Figures...")

plot_venues = ["freefield", "damped", "festival", "club", "arena"]
filters_to_plot = [
    "Unprocessed",
    "Base_NLMS",
    "Cascade_Notch_NLMS",
    "ML_Spatial_Wave_UNet",
    "ML_Joint_VAD_Spatial_UNet",
    "ML_VAD_Leaky_NLMS",
    "ML_VAD_Cascade_Notch_NLMS"
]

colors = {
    "Unprocessed": "#7f7f7f",                 # Grey
    "Base_NLMS": "#1f77b4",                   # Blue
    "Cascade_Notch_NLMS": "#2ca02c",          # Green
    "ML_Spatial_Wave_UNet": "#d62728",        # Red
    "ML_Joint_VAD_Spatial_UNet": "#ff7f0e",   # Orange
    "ML_VAD_Leaky_NLMS": "#9467bd",           # Purple
    "ML_VAD_Cascade_Notch_NLMS": "#8c564b"    # Brown
}

linestyles = {
    "Unprocessed": "--",
    "Base_NLMS": "-",
    "Cascade_Notch_NLMS": "-",
    "ML_Spatial_Wave_UNet": ":",
    "ML_Joint_VAD_Spatial_UNet": "-",
    "ML_VAD_Leaky_NLMS": "-.",
    "ML_VAD_Cascade_Notch_NLMS": "-"
}

markers = {
    "Unprocessed": "o",
    "Base_NLMS": "s",
    "Cascade_Notch_NLMS": "D",
    "ML_Spatial_Wave_UNet": "^",
    "ML_Joint_VAD_Spatial_UNet": "v",
    "ML_VAD_Leaky_NLMS": "P",
    "ML_VAD_Cascade_Notch_NLMS": "*"
}

# --- Plot 1: STOI vs SNR across 5 Venues ---
fig, axes = plt.subplots(1, 5, figsize=(22, 5.5), sharey=True)
fig.suptitle("Objective Speech Intelligibility (STOI): Cooperative ML Pipelines vs. Classical Baselines", fontsize=14, fontweight="bold")

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
            vals = [np.mean(summary_map[(v_key, g, s_db, f_name)]["stoi"]) for g in genres]
            y_vals.append(np.mean(vals))
        ax.plot(snr_levels, y_vals, label=f_name, color=colors[f_name], linestyle=linestyles[f_name], marker=markers[f_name], linewidth=2.0)

axes[0].legend(loc="lower right", fontsize=8)
plt.tight_layout()
fig_stoi_path = os.path.join(FIGURES_DIR, "ml_vs_dsp_comprehensive_stoi_comparison.png")
plt.savefig(fig_stoi_path, dpi=300)
plt.close()
print(f"✓ Saved figure: {fig_stoi_path}")

# --- Plot 2: Delta SNR vs SNR across 5 Venues ---
fig, axes = plt.subplots(1, 5, figsize=(22, 5.5), sharey=True)
fig.suptitle("Physical Noise Reduction (ΔSNR dB): Cooperative ML Pipelines vs. Classical Baselines", fontsize=14, fontweight="bold")

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
        ax.plot(snr_levels, y_vals, label=f_name, color=colors[f_name], linestyle=linestyles[f_name], marker=markers[f_name], linewidth=2.0)

axes[0].legend(loc="upper left", fontsize=8)
plt.tight_layout()
fig_dsnr_path = os.path.join(FIGURES_DIR, "ml_vs_dsp_delta_snr_comparison.png")
plt.savefig(fig_dsnr_path, dpi=300)
plt.close()
print(f"✓ Saved figure: {fig_dsnr_path}")

# Copy to brain artifacts
if os.path.exists(BRAIN_FIGURES_DIR):
    import shutil
    shutil.copy(fig_stoi_path, os.path.join(BRAIN_FIGURES_DIR, "ml_vs_dsp_comprehensive_stoi_comparison.png"))
    shutil.copy(fig_dsnr_path, os.path.join(BRAIN_FIGURES_DIR, "ml_vs_dsp_delta_snr_comparison.png"))
    print("✓ Synced publication figures to brain artifact directory.")

print("\n" + "=" * 80)
print("  ML COOPERATIVE PIPELINES BENCHMARK SUITE COMPLETE!")
print("=" * 80)
