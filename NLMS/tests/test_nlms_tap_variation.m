% test_nlms_tap_variation.m
% Investigates the effect of varying NLMS filter tap length (N) on STOI, PESQ,
% Delta SNR, and ESP32-S3 computational complexity across reverberant and anechoic environments.

clear; clc;
fprintf('========================================================================\n');
fprintf('  NLMS TAP VARIATION SIMULATION: EFFECT OF FILTER ORDER (N) ON STOI     \n');
fprintf('========================================================================\n\n');

fs = 16000;
mu_nlms = 0.05;
eps_nlms = 1e-2;
gamma_leaky = 1 - 2^-15; % 0.999969
vad_prm = struct('frame_len_ms', 20, 'alpha_ema', 0.9, 'zcr_thresh', 0.01);

% Tap counts to evaluate
tap_list = [16, 32, 48, 64, 96, 128, 192, 256, 384, 512, 1024];

% Paths
script_dir = fileparts(mfilename('fullpath'));
if isempty(script_dir), script_dir = pwd; end
addpath(fullfile(script_dir, '..', 'lib'));

repo_root = fullfile(script_dir, '..', '..');
dataset_dir = fullfile(repo_root, 'dataset');
speech_corpus_dir = fullfile(dataset_dir, 'speech_corpus');
output_dir = fullfile(script_dir, '..', 'output_audio', 'room_experiment');
figures_dir = fullfile(script_dir, '..', 'figures');
if ~exist(output_dir, 'dir'), mkdir(output_dir); end
if ~exist(figures_dir, 'dir'), mkdir(figures_dir); end

% Load speech files (1 male, 1 female)
m_files = dir(fullfile(speech_corpus_dir, 'male', 'male_*.wav'));
f_files = dir(fullfile(speech_corpus_dir, 'female', 'female_*.wav'));
if isempty(m_files) || isempty(f_files)
    error('Speech files not found in %s', speech_corpus_dir);
end

speech_files = {
    fullfile(speech_corpus_dir, 'male', m_files(1).name), 'Male Harvard Sentence';
    fullfile(speech_corpus_dir, 'female', f_files(1).name), 'Female Harvard Sentence'
};

% Load noise stems
noise_stems = struct();
noise_stems.techno = fullfile(dataset_dir, 'wav_16k', 'techno', 'techno_1389887.wav');
noise_stems.jazz   = fullfile(dataset_dir, 'wav_16k', 'jazz', 'jazz_01_jazz.00016.wav');

genres = {'techno', 'jazz'};
snr_levels = [-10, 0]; % Severe concert (-10 dB) and Moderate concert (0 dB)

% Scenarios to evaluate:
% 1. Nightclub (RT60 = 0.70s, dense early reflections, head shadow)
% 2. Free-Field (RT60 = 0.00s, direct path only, head shadow)
% 3. Ideal Reference (Direct path, zero speech leakage into reference)
scenarios = {'nightclub', 'freefield', 'ideal_ref'};

% Precompute RIRs
fprintf('--> Precomputing Acoustic Impulse Responses...\n');
rirs = struct();
max_rir_sec = 0.45;
ear_axis_1 = [0, -1, 0];
ear_axis_2 = [0,  1, 0];

% 1. Nightclub
dim_club = [12.0, 15.0, 4.0];
spk_club = [6.0, 8.65, 1.6];
m1_club  = [6.0, 9.00, 1.6];
m2_club  = [6.0, 9.04, 1.6];
paL_club = [2.0, 1.00, 2.5];
paR_club = [10.0, 1.00, 2.5];

[rirs.club.hs1, ~] = simulate_room_impulse_response(dim_club, spk_club, m1_club, 0.70, fs, max_rir_sec, ear_axis_1);
[rirs.club.hs2, ~] = simulate_room_impulse_response(dim_club, spk_club, m2_club, 0.70, fs, max_rir_sec, ear_axis_2);
[rirs.club.hnL1, ~] = simulate_room_impulse_response(dim_club, paL_club, m1_club, 0.70, fs, max_rir_sec, ear_axis_1);
[rirs.club.hnR1, ~] = simulate_room_impulse_response(dim_club, paR_club, m1_club, 0.70, fs, max_rir_sec, ear_axis_1);
[rirs.club.hnL2, ~] = simulate_room_impulse_response(dim_club, paL_club, m2_club, 0.70, fs, max_rir_sec, ear_axis_2);
[rirs.club.hnR2, ~] = simulate_room_impulse_response(dim_club, paR_club, m2_club, 0.70, fs, max_rir_sec, ear_axis_2);
rirs.club.hn1 = 0.5 * (rirs.club.hnL1 + rirs.club.hnR1);
rirs.club.hn2 = 0.5 * (rirs.club.hnL2 + rirs.club.hnR2);

% 2. Free-Field
dim_ff = [12.0, 15.0, 4.0];
[rirs.ff.hs1, ~] = simulate_room_impulse_response(dim_ff, spk_club, m1_club, 0.00, fs, max_rir_sec, ear_axis_1);
[rirs.ff.hs2, ~] = simulate_room_impulse_response(dim_ff, spk_club, m2_club, 0.00, fs, max_rir_sec, ear_axis_2);
[rirs.ff.hnL1, ~] = simulate_room_impulse_response(dim_ff, paL_club, m1_club, 0.00, fs, max_rir_sec, ear_axis_1);
[rirs.ff.hnR1, ~] = simulate_room_impulse_response(dim_ff, paR_club, m1_club, 0.00, fs, max_rir_sec, ear_axis_1);
[rirs.ff.hnL2, ~] = simulate_room_impulse_response(dim_ff, paL_club, m2_club, 0.00, fs, max_rir_sec, ear_axis_2);
[rirs.ff.hnR2, ~] = simulate_room_impulse_response(dim_ff, paR_club, m2_club, 0.00, fs, max_rir_sec, ear_axis_2);
rirs.ff.hn1 = 0.5 * (rirs.ff.hnL1 + rirs.ff.hnR1);
rirs.ff.hn2 = 0.5 * (rirs.ff.hnL2 + rirs.ff.hnR2);

fprintf('    Impulse responses ready.\n\n');

% Initialize Accumulators
% Keys: (scenario, filter_type, tap)
results_table = [];

total_trials = length(scenarios) * length(genres) * length(snr_levels) * size(speech_files, 1) * length(tap_list) * 2;
trial_counter = 0;
fprintf('--> Running Simulation across %d Filter Tap configurations...\n', length(tap_list));
fprintf('    Tap list: %s\n\n', mat2str(tap_list));

csv_res_file = fullfile(output_dir, 'nlms_tap_variation_results.csv');
fid = fopen(csv_res_file, 'w');
fprintf(fid, 'Scenario,Genre,SNR_dB,Speaker,Taps,Filter_Type,STOI_In,STOI_Out,Delta_STOI,PESQ_In,PESQ_Out,Delta_SNR_dB,MACs_per_sec,ESP32_CPU_Pct\n');

for sc_idx = 1:length(scenarios)
    sc_name = scenarios{sc_idx};
    
    for g_idx = 1:length(genres)
        genre = genres{g_idx};
        [raw_noise, fs_n] = audioread(noise_stems.(genre));
        if fs_n ~= fs, raw_noise = resample(raw_noise, fs, fs_n); end
        
        % Filter noise through RIRs
        if strcmp(sc_name, 'nightclub')
            n1_full = filter(rirs.club.hn1, 1, raw_noise);
            n2_full = filter(rirs.club.hn2, 1, raw_noise);
            hs1 = rirs.club.hs1;
            hs2 = rirs.club.hs2;
        elseif strcmp(sc_name, 'freefield')
            n1_full = filter(rirs.ff.hn1, 1, raw_noise);
            n2_full = filter(rirs.ff.hn2, 1, raw_noise);
            hs1 = rirs.ff.hs1;
            hs2 = rirs.ff.hs2;
        else % ideal_ref
            n1_full = filter(rirs.ff.hn1, 1, raw_noise);
            n2_full = filter(rirs.ff.hn2, 1, raw_noise);
            hs1 = rirs.ff.hs1;
            hs2 = zeros(size(hs1)); % zero speech leakage!
        end
        
        for snr_idx = 1:length(snr_levels)
            target_snr = snr_levels(snr_idx);
            
            for spk_idx = 1:size(speech_files, 1)
                spk_path = speech_files{spk_idx, 1};
                spk_desc = speech_files{spk_idx, 2};
                
                [clean_speech, fs_s] = audioread(spk_path);
                if fs_s ~= fs, clean_speech = resample(clean_speech, fs, fs_s); end
                
                % Limit to 4.5 seconds for rapid benchmark
                L_speech = min(length(clean_speech), round(fs * 4.5));
                clean_speech = clean_speech(1:L_speech);
                
                % Add 0.5s pre-roll for initial NLMS convergence
                clean_speech = [zeros(round(fs * 0.5), 1); clean_speech];
                L = length(clean_speech);
                
                % Convolve speech
                s1_rev = filter(hs1, 1, clean_speech);
                if strcmp(sc_name, 'ideal_ref')
                    s2_rev = zeros(L, 1); % No speech leakage in ideal reference
                else
                    s2_rev = 0.25 * filter(hs2, 1, clean_speech); % 12 dB head shadow
                end
                
                % Slice noise
                if length(n1_full) < L
                    reps = ceil(L / length(n1_full));
                    n1_seg = repmat(n1_full, reps, 1);
                    n2_seg = repmat(n2_full, reps, 1);
                else
                    n1_seg = n1_full(1:L);
                    n2_seg = n2_full(1:L);
                end
                n1_seg = n1_seg(1:L);
                n2_seg = n2_seg(1:L);
                
                % Scale noise to target SNR
                [asl_s1, ~] = calculate_active_speech_level(s1_rev, fs);
                p_s1 = 10^(asl_s1 / 10);
                p_n1 = mean(n1_seg.^2);
                if p_n1 < 1e-12, p_n1 = 1e-12; end
                scale = sqrt(p_s1 / (p_n1 * 10^(target_snr / 10)));
                
                scaled_n1 = n1_seg * scale;
                scaled_n2 = n2_seg * scale;
                
                d_raw = s1_rev + scaled_n1;
                x_raw = s2_rev + scaled_n2;
                
                % Headroom normalization
                peak_val = max(abs(d_raw));
                if peak_val < 1e-6, peak_val = 1.0; end
                norm_gain = 0.90 / peak_val;
                
                d = d_raw * norm_gain;
                x = x_raw * norm_gain;
                s_ref = s1_rev * norm_gain;
                n_ref = scaled_n1 * norm_gain;
                
                % Calculate input metrics
                stoi_in = calculate_stoi(s_ref, d, fs);
                pesq_in = calculate_pesq_metric(s_ref, d, fs);
                snr_in_lin = mean(s_ref.^2) / (mean(n_ref.^2) + 1e-12);
                snr_in_dB = 10 * log10(snr_in_lin + 1e-12);
                
                % Precalculate VAD for Soft-VAD Leaky
                [~, vad_soft] = compute_robust_vad(d, x, fs, vad_prm);
                
                % Test each tap count
                for t_idx = 1:length(tap_list)
                    N_taps = tap_list(t_idx);
                    
                    % 1. Base NLMS
                    [e_base, ~] = nlms_filter(d, x, N_taps, mu_nlms, eps_nlms);
                    stoi_base = calculate_stoi(s_ref, e_base, fs);
                    pesq_base = calculate_pesq_metric(s_ref, e_base, fs);
                    res_noise_b = e_base - s_ref;
                    snr_out_b = 10 * log10(mean(s_ref.^2) / (mean(res_noise_b.^2) + 1e-12));
                    dsnr_base = max(min(snr_out_b - snr_in_dB, 30.0), -10.0);
                    
                    % 2. Soft-VAD Leaky NLMS
                    [e_vad, ~] = nlms_leaky_filter(d, x, N_taps, mu_nlms, eps_nlms, gamma_leaky, vad_soft);
                    stoi_vad = calculate_stoi(s_ref, e_vad, fs);
                    pesq_vad = calculate_pesq_metric(s_ref, e_vad, fs);
                    res_noise_v = e_vad - s_ref;
                    snr_out_v = 10 * log10(mean(s_ref.^2) / (mean(res_noise_v.^2) + 1e-12));
                    dsnr_vad = max(min(snr_out_v - snr_in_dB, 30.0), -10.0);
                    
                    % Complexity metrics:
                    % 2 * N MAC operations per sample (dot product + weight update)
                    macs_per_sec = 2 * N_taps * fs;
                    % On ESP32-S3 (240 MHz dual-core, ~2 clock cycles per MAC in assembly loop):
                    % CPU load % = (macs_per_sec * 2 / 240e6) * 100%
                    esp32_cpu_pct = (macs_per_sec * 2 / 240e6) * 100;
                    
                    % Record Base NLMS
                    fprintf(fid, '%s,%s,%d,%s,%d,Base_NLMS,%.4f,%.4f,%.4f,%.4f,%.4f,%.2f,%d,%.2f\n', ...
                        sc_name, genre, target_snr, spk_desc(1:4), N_taps, stoi_in, stoi_base, stoi_base - stoi_in, ...
                        pesq_in, pesq_base, dsnr_base, macs_per_sec, esp32_cpu_pct);
                    
                    % Record Soft-VAD Leaky
                    fprintf(fid, '%s,%s,%d,%s,%d,Soft_VAD_Leaky,%.4f,%.4f,%.4f,%.4f,%.4f,%.2f,%d,%.2f\n', ...
                        sc_name, genre, target_snr, spk_desc(1:4), N_taps, stoi_in, stoi_vad, stoi_vad - stoi_in, ...
                        pesq_in, pesq_vad, dsnr_vad, macs_per_sec, esp32_cpu_pct);
                end
            end
        end
    end
    fprintf('    Completed scenario: [%s]\n', sc_name);
end

fclose(fid);
fprintf('\n--> Raw results saved to %s\n', csv_res_file);

% =========================================================================
% Aggregate Summary & Console Table Generation
% =========================================================================
fprintf('\n===================================================================================================\n');
fprintf('  AGGREGATED RESULTS: MEAN STOI & DELTA SNR vs FILTER TAPS (Across Genres & SNRs)\n');
fprintf('===================================================================================================\n');
fprintf('%-14s | %-15s | %-5s | %-10s | %-10s | %-9s | %-9s | %-9s\n', ...
    'Scenario', 'Filter Type', 'Taps', 'Mean STOI', 'Delta STOI', 'Mean PESQ', 'Delta SNR', 'ESP32 CPU');
fprintf('---------------------------------------------------------------------------------------------------\n');

% Load results into MATLAB table for aggregation
opts = detectImportOptions(csv_res_file);
T = readtable(csv_res_file, opts);

summary_records = [];
for sc_idx = 1:length(scenarios)
    sc = scenarios{sc_idx};
    for filt_type = {'Base_NLMS', 'Soft_VAD_Leaky'}
        ft = filt_type{1};
        for t_idx = 1:length(tap_list)
            tp = tap_list(t_idx);
            
            sub = T(strcmp(T.Scenario, sc) & strcmp(T.Filter_Type, ft) & (T.Taps == tp), :);
            if ~isempty(sub)
                mean_stoi_out = mean(sub.STOI_Out);
                mean_dstoi    = mean(sub.Delta_STOI);
                mean_pesq_out = mean(sub.PESQ_Out);
                mean_dsnr     = mean(sub.Delta_SNR_dB);
                cpu_load      = mean(sub.ESP32_CPU_Pct);
                
                fprintf('%-14s | %-15s | %5d | %10.4f | %+10.4f | %9.3f | %+8.2f dB | %7.2f%%\n', ...
                    sc, ft, tp, mean_stoi_out, mean_dstoi, mean_pesq_out, mean_dsnr, cpu_load);
                
                summary_records = [summary_records; {sc, ft, tp, mean_stoi_out, mean_dstoi, mean_pesq_out, mean_dsnr, cpu_load}];
            end
        end
        fprintf('---------------------------------------------------------------------------------------------------\n');
    end
end

% Save summary CSV
sum_tbl = cell2table(summary_records, 'VariableNames', ...
    {'Scenario', 'Filter_Type', 'Taps', 'Mean_STOI_Out', 'Mean_Delta_STOI', 'Mean_PESQ_Out', 'Mean_Delta_SNR_dB', 'ESP32_CPU_Pct'});
csv_sum_file = fullfile(output_dir, 'nlms_tap_variation_summary.csv');
writetable(sum_tbl, csv_sum_file);
fprintf('Summary CSV saved to %s\n\n', csv_sum_file);

% =========================================================================
% Publication Plot Generation
% =========================================================================
fprintf('--> Generating Publication Figure...\n');
fig = figure('Visible', 'off', 'Position', [100, 100, 1300, 850], 'Color', 'w');

colors = struct();
colors.nightclub_base = [0.85, 0.33, 0.10]; % Reddish
colors.nightclub_vad  = [0.00, 0.45, 0.74]; % Blue
colors.freefield_base = [0.93, 0.69, 0.13]; % Gold
colors.freefield_vad  = [0.47, 0.67, 0.19]; % Green
colors.ideal_base     = [0.49, 0.18, 0.56]; % Purple
colors.ideal_vad      = [0.30, 0.75, 0.93]; % Cyan

% 1. Subplot 1: STOI vs Taps
subplot(2, 2, 1);
hold on; box on; grid on;

% Extract curves
plot_curves = @(sc_name, ft_name, col, ls, mkr) ...
    plot(tap_list, sum_tbl.Mean_STOI_Out(strcmp(sum_tbl.Scenario, sc_name) & strcmp(sum_tbl.Filter_Type, ft_name)), ...
    'LineWidth', 2.0, 'Color', col, 'LineStyle', ls, 'Marker', mkr, 'MarkerSize', 6);

h1 = plot_curves('nightclub', 'Base_NLMS', [0.85, 0.20, 0.20], '-', 'o');
h2 = plot_curves('nightclub', 'Soft_VAD_Leaky', [0.10, 0.40, 0.85], '-', 's');
h3 = plot_curves('freefield', 'Base_NLMS', [0.85, 0.60, 0.10], '--', '^');
h4 = plot_curves('freefield', 'Soft_VAD_Leaky', [0.20, 0.70, 0.20], '--', 'd');
h5 = plot_curves('ideal_ref', 'Base_NLMS', [0.50, 0.20, 0.60], ':', 'x');

set(gca, 'XScale', 'log');
xticks([16, 32, 64, 128, 256, 512, 1024]);
xticklabels({'16', '32', '64', '128', '256', '512', '1024'});
xlabel('Filter Order / Taps (N)', 'FontSize', 11, 'FontWeight', 'bold');
ylabel('Mean STOI Intelligibility', 'FontSize', 11, 'FontWeight', 'bold');
title('STOI vs. Filter Taps (N)', 'FontSize', 12, 'FontWeight', 'bold');
legend([h1, h2, h3, h4, h5], ...
    {'Club: Base NLMS', 'Club: Soft-VAD Leaky', 'FreeField: Base NLMS', 'FreeField: Soft-VAD', 'Ideal Ref: Base NLMS'}, ...
    'Location', 'best', 'FontSize', 8);
ylim([0.45, 0.95]);

% 2. Subplot 2: Delta STOI Improvement
subplot(2, 2, 2);
hold on; box on; grid on;
plot_dstoi = @(sc_name, ft_name, col, ls, mkr) ...
    plot(tap_list, sum_tbl.Mean_Delta_STOI(strcmp(sum_tbl.Scenario, sc_name) & strcmp(sum_tbl.Filter_Type, ft_name)), ...
    'LineWidth', 2.0, 'Color', col, 'LineStyle', ls, 'Marker', mkr, 'MarkerSize', 6);

plot_dstoi('nightclub', 'Base_NLMS', [0.85, 0.20, 0.20], '-', 'o');
plot_dstoi('nightclub', 'Soft_VAD_Leaky', [0.10, 0.40, 0.85], '-', 's');
plot_dstoi('freefield', 'Base_NLMS', [0.85, 0.60, 0.10], '--', '^');
plot_dstoi('freefield', 'Soft_VAD_Leaky', [0.20, 0.70, 0.20], '--', 'd');
plot_dstoi('ideal_ref', 'Base_NLMS', [0.50, 0.20, 0.60], ':', 'x');
yline(0, 'k--', 'LineWidth', 1.0);

set(gca, 'XScale', 'log');
xticks([16, 32, 64, 128, 256, 512, 1024]);
xticklabels({'16', '32', '64', '128', '256', '512', '1024'});
xlabel('Filter Order / Taps (N)', 'FontSize', 11, 'FontWeight', 'bold');
ylabel('STOI Improvement (\DeltaSTOI)', 'FontSize', 11, 'FontWeight', 'bold');
title('\DeltaSTOI vs. Filter Taps (N)', 'FontSize', 12, 'FontWeight', 'bold');

% 3. Subplot 3: Delta SNR (dB) vs Taps
subplot(2, 2, 3);
hold on; box on; grid on;
plot_dsnr = @(sc_name, ft_name, col, ls, mkr) ...
    plot(tap_list, sum_tbl.Mean_Delta_SNR_dB(strcmp(sum_tbl.Scenario, sc_name) & strcmp(sum_tbl.Filter_Type, ft_name)), ...
    'LineWidth', 2.0, 'Color', col, 'LineStyle', ls, 'Marker', mkr, 'MarkerSize', 6);

plot_dsnr('nightclub', 'Base_NLMS', [0.85, 0.20, 0.20], '-', 'o');
plot_dsnr('nightclub', 'Soft_VAD_Leaky', [0.10, 0.40, 0.85], '-', 's');
plot_dsnr('freefield', 'Base_NLMS', [0.85, 0.60, 0.10], '--', '^');
plot_dsnr('freefield', 'Soft_VAD_Leaky', [0.20, 0.70, 0.20], '--', 'd');
plot_dsnr('ideal_ref', 'Base_NLMS', [0.50, 0.20, 0.60], ':', 'x');

set(gca, 'XScale', 'log');
xticks([16, 32, 64, 128, 256, 512, 1024]);
xticklabels({'16', '32', '64', '128', '256', '512', '1024'});
xlabel('Filter Order / Taps (N)', 'FontSize', 11, 'FontWeight', 'bold');
ylabel('Noise Reduction (\DeltaSNR dB)', 'FontSize', 11, 'FontWeight', 'bold');
title('\DeltaSNR (dB) vs. Filter Taps (N)', 'FontSize', 12, 'FontWeight', 'bold');

% 4. Subplot 4: Computational Complexity & Embedded Budget
subplot(2, 2, 4);
hold on; box on; grid on;
yyaxis left;
plot(tap_list, tap_list * 2 * fs / 1e6, 'b-o', 'LineWidth', 2.0, 'MarkerSize', 6);
ylabel('Mega MACs / sec', 'FontSize', 11, 'FontWeight', 'bold', 'Color', 'b');
set(gca, 'YColor', 'b');

yyaxis right;
plot(tap_list, tap_list * 4 / 1024, 'r-s', 'LineWidth', 2.0, 'MarkerSize', 6);
ylabel('Weight Memory (KB)', 'FontSize', 11, 'FontWeight', 'bold', 'Color', 'r');
set(gca, 'YColor', 'r');

yline(4.0, 'k--', 'ESP32 Internal L1 RAM Comfort Threshold', 'LabelHorizontalAlignment', 'left', 'FontSize', 8);

set(gca, 'XScale', 'log');
xticks([16, 32, 64, 128, 256, 512, 1024]);
xticklabels({'16', '32', '64', '128', '256', '512', '1024'});
xlabel('Filter Order / Taps (N)', 'FontSize', 11, 'FontWeight', 'bold');
title('Computational Complexity on ESP32-S3', 'FontSize', 12, 'FontWeight', 'bold');

% Super title
sgtitle('Impact of Adaptive Filter Tap Length (N) on Acoustic Performance & Intelligibility', ...
    'FontSize', 14, 'FontWeight', 'bold');

fig_path = fullfile(figures_dir, 'nlms_tap_variation_analysis.png');
exportgraphics(fig, fig_path, 'Resolution', 300);
close(fig);
fprintf('Publication figure exported to: %s\n', fig_path);

% Copy to brain artifact directory if exists
brain_fig_dir = '/Users/macairm1/.gemini/antigravity/brain/fa14326e-1c60-480f-a3be-913fac3a8bd5/figures';
if exist(brain_fig_dir, 'dir')
    copyfile(fig_path, fullfile(brain_fig_dir, 'nlms_tap_variation_analysis.png'));
    fprintf('Figure copied to brain artifacts directory.\n');
end

fprintf('\n=== TAP VARIATION SIMULATION FINISHED SUCCESSFULLY ===\n');
