% compare_nlms_scenarios.m
% Tests the 4 filter approaches (Baseline, Leaky, Hard-VAD, Soft-VAD) in a complex scenario
% Loops over a few files and varying SNRs, saving audio outputs

fs = 16000;
N = 1024;
mu = 0.05;
epsilon = 1e-2;
gamma = 0.999;
snr_levels = [-15, -10, -5, 0, 5];
prm = struct('frame_len_ms', 20, 'alpha_ema', 0.9, 'zcr_thresh', 0.05);

% Ensure correct paths
script_dir = fileparts(mfilename('fullpath'));
if isempty(script_dir)
    script_dir = pwd;
end
addpath(fullfile(script_dir, '..', 'lib'));
dataset_dir = fullfile(script_dir, '..', '..', 'dataset');
speech_dir = fullfile(dataset_dir, 'speech_corpus', 'combined');

output_dir = fullfile(script_dir, '..', 'output_audio', 'compare_nlms_scenarios');
if ~exist(output_dir, 'dir'), mkdir(output_dir); end

% Load Noise
noise_file = fullfile(dataset_dir, 'wav_16k', 'techno', 'techno_1389887.wav');
[noise_source_full, fs_noise] = audioread(noise_file);
if fs_noise ~= fs, noise_source_full = resample(noise_source_full, fs, fs_noise); end

% Get 3 speech files for comparison
speech_files = dir(fullfile(speech_dir, '*.wav'));
num_files = min(3, length(speech_files));

fprintf('\n=== Running Complex Scenarios Comparison ===\n');

for i = 1:num_files
    % Load Signals
    s_file_path = fullfile(speech_dir, speech_files(i).name);
    [~, s_name, ~] = fileparts(speech_files(i).name);
    [clean_speech, fs_speech] = audioread(s_file_path);
    if fs_speech ~= fs, clean_speech = resample(clean_speech, fs, fs_speech); end

    L = length(clean_speech);
    noise_source = noise_source_full(1:L);

    % Active Speech Power
    [asl_clean, ~] = calculate_active_speech_level(clean_speech, fs);
    p_s = 10^(asl_clean/10);
    p_n = mean(noise_source.^2);

    for s = 1:length(snr_levels)
        target_snr_dB = snr_levels(s);

        scale = sqrt(p_s / (p_n * 10^(target_snr_dB/10)));
        scaled_noise = noise_source * scale;

        % Peak Normalization
        d_base = clean_speech + scaled_noise;
        peak = max(abs(d_base));
        gain = 0.90 / peak;
        s_clean_norm = clean_speech * gain;
        s_noise_norm = scaled_noise * gain;

        t = (0:L-1)' / fs;

        %% Complex Scenario Construction
        % 1. Speech Leakage: The reference mic picks up 20% of the user's speech
        x = s_noise_norm + 0.2 * s_clean_norm;

        % 2. Transient Mic Bump: A low frequency thump at t = 1.0s in primary mic
        bump = zeros(L, 1);
        bump_idx = round(1.0 * fs);
        if bump_idx + 1000 < L
            bump_pulse = sin(2 * pi * 10 * (0:1000)' / fs) .* hamming(1001); % 10 Hz pulse
            bump(bump_idx:bump_idx+1000) = bump_pulse * 0.5;
        end
        d = s_clean_norm + s_noise_norm + bump;

        %% Compute VAD
        [vad_hard, vad_soft] = compute_robust_vad(d, x, fs, prm);

        %% Run Filters
        [e_base, ~] = nlms_filter(d, x, N, mu, epsilon);
        [e_base_vad, ~] = nlms_filter(d, x, N, mu, epsilon, vad_hard);
        vad_none = zeros(L, 1);
        [e_leaky, ~] = nlms_leaky_filter(d, x, N, mu, epsilon, gamma, vad_none);
        [e_hard, ~] = nlms_leaky_filter(d, x, N, mu, epsilon, gamma, vad_hard);
        [e_soft, ~] = nlms_leaky_filter(d, x, N, mu, epsilon, gamma, vad_soft);

        %% Evaluate STOI
        stoi_in = calculate_stoi(s_clean_norm, d, fs);
        stoi_base = calculate_stoi(s_clean_norm, e_base, fs);
        stoi_base_vad = calculate_stoi(s_clean_norm, e_base_vad, fs);
        stoi_leaky = calculate_stoi(s_clean_norm, e_leaky, fs);
        stoi_hard = calculate_stoi(s_clean_norm, e_hard, fs);
        stoi_soft = calculate_stoi(s_clean_norm, e_soft, fs);

        %% Evaluate visqol
        visqol_in = calculate_visqol(s_clean_norm, d, fs);
        visqol_base = calculate_visqol(s_clean_norm, e_base, fs);
        visqol_base_vad = calculate_visqol(s_clean_norm, e_base_vad, fs);
        visqol_leaky = calculate_visqol(s_clean_norm, e_leaky, fs);
        visqol_hard = calculate_visqol(s_clean_norm, e_hard, fs);
        visqol_soft = calculate_visqol(s_clean_norm, e_soft, fs);

        fprintf('File: %s | SNR: %2d dB | STOI In: %.3f | Base: %.3f | BaseVAD: %.3f | Leaky: %.3f | Hard: %.3f | Soft: %.3f\n', ...
            s_name(1:15), target_snr_dB, stoi_in, stoi_base, stoi_base_vad, stoi_leaky, stoi_hard, stoi_soft);
        fprintf('File: %s | SNR: %2d dB | visqol In: %.3f | Base: %.3f | BaseVAD: %.3f | Leaky: %.3f | Hard: %.3f | Soft: %.3f\n', ...
            s_name(1:15), target_snr_dB, visqol_in, visqol_base, visqol_base_vad, visqol_leaky, visqol_hard, visqol_soft);

        %% Save Audio
        [d_exp, e_base_exp, e_base_vad_exp, e_leaky_exp, e_hard_exp, e_soft_exp] = normalize_for_export(0.9, d, e_base, e_base_vad, e_leaky, e_hard, e_soft);
        audiowrite(fullfile(output_dir, sprintf('%s_snr%d_01_primary.wav', s_name, target_snr_dB)), d_exp, fs);
        audiowrite(fullfile(output_dir, sprintf('%s_snr%d_02_base.wav', s_name, target_snr_dB)), e_base_exp, fs);
        audiowrite(fullfile(output_dir, sprintf('%s_snr%d_03_basevad.wav', s_name, target_snr_dB)), e_base_vad_exp, fs);
        audiowrite(fullfile(output_dir, sprintf('%s_snr%d_04_leaky.wav', s_name, target_snr_dB)), e_leaky_exp, fs);
        audiowrite(fullfile(output_dir, sprintf('%s_snr%d_05_hard.wav', s_name, target_snr_dB)), e_hard_exp, fs);
        audiowrite(fullfile(output_dir, sprintf('%s_snr%d_06_soft.wav', s_name, target_snr_dB)), e_soft_exp, fs);
    end
end
disp('--- Saved all comparison audio files to output_audio/compare_nlms_scenarios/ ---');
