% plot_room_experiment_results.m
% Generates publication-quality comparative figures from the Concert Venue Room Experiment.

clear; clc;
script_dir = fileparts(mfilename('fullpath'));
if isempty(script_dir), script_dir = pwd; end

output_dir = fullfile(script_dir, '..', 'output_audio', 'room_experiment');
summary_csv = fullfile(output_dir, 'room_experiment_summary.csv');
figures_dir = fullfile(script_dir, '..', 'figures');
if ~exist(figures_dir, 'dir'), mkdir(figures_dir); end

if ~exist(summary_csv, 'file')
    error('Summary CSV not found: %s. Run run_concert_venue_room_experiment.m first.', summary_csv);
end

% Read summary CSV
opts = detectImportOptions(summary_csv);
T = readtable(summary_csv, opts);

venues = {'club', 'arena', 'festival'};
venue_titles = {'Nightclub (RT60 ~ 0.70s)', 'Concert Arena (RT60 ~ 1.40s)', 'Open-Air Festival (RT60 ~ 0.20s)'};
snr_grid = [-15, -10, -5, 0, 5, 10];
filters = {'Unprocessed', 'FIR_BP', 'Parametric_Notch', 'Base_NLMS', 'Leaky_NLMS', 'Soft_VAD_Leaky'};
filter_labels = {'Unprocessed Primary', 'Fixed FIR Bandpass', 'Parametric Notch', 'Baseline NLMS', 'Leaky NLMS', 'Soft-VAD Leaky NLMS'};

% Visual Styling Palette
colors = [
    0.45, 0.45, 0.45; % Gray (Unprocessed)
    0.85, 0.35, 0.25; % Red/Orange (FIR)
    0.20, 0.70, 0.30; % Green (Notch)
    0.25, 0.50, 0.90; % Blue (Base NLMS)
    0.60, 0.30, 0.85; % Purple (Leaky NLMS)
    0.95, 0.65, 0.05  % Gold/Amber (Soft-VAD Leaky)
];
markers = {'s', '^', 'd', 'v', 'p', 'o'};
line_styles = {':', '--', '-.', '-', '--', '-'};
line_widths = [1.5, 1.5, 1.8, 1.8, 1.8, 2.5];

fprintf('--> Plotting Figure 1: STOI Intelligibility across Venues...\n');
fig1 = figure('Visible', 'off', 'Position', [100, 100, 1400, 480]);

for v = 1:length(venues)
    v_key = venues{v};
    subplot(1, 3, v);
    hold on; box on; grid on;
    
    for f = 1:length(filters)
        f_name = filters{f};
        stoi_means = zeros(length(snr_grid), 1);
        
        for s = 1:length(snr_grid)
            snr_val = snr_grid(s);
            rows = strcmp(T.Venue, v_key) & strcmp(T.Filter, f_name) & (T.SNR_dB == snr_val);
            stoi_means(s) = mean(T.Mean_STOI(rows));
        end
        
        plot(snr_grid, stoi_means, 'LineStyle', line_styles{f}, 'LineWidth', line_widths(f), ...
            'Color', colors(f, :), 'Marker', markers{f}, 'MarkerSize', 6, 'MarkerFaceColor', colors(f, :), ...
            'DisplayName', filter_labels{f});
    end
    
    title(venue_titles{v}, 'FontSize', 12, 'FontWeight', 'bold');
    xlabel('Target SNR (dB)', 'FontSize', 11);
    ylabel('STOI (Intelligibility Index)', 'FontSize', 11);
    ylim([0.65, 1.02]);
    xlim([-16, 11]);
    set(gca, 'XTick', snr_grid);
    if v == 1
        legend('Location', 'southeast', 'FontSize', 8);
    end
end
sgtitle('Speech Intelligibility (STOI) across Live Concert Venues & SNR Tiers', 'FontSize', 14, 'FontWeight', 'bold');
saveas(fig1, fullfile(figures_dir, 'room_experiment_stoi_vs_snr.png'));
close(fig1);

fprintf('--> Plotting Figure 2: PESQ Speech Quality across Venues...\n');
fig2 = figure('Visible', 'off', 'Position', [100, 100, 1400, 480]);

for v = 1:length(venues)
    v_key = venues{v};
    subplot(1, 3, v);
    hold on; box on; grid on;
    
    for f = 1:length(filters)
        f_name = filters{f};
        pesq_means = zeros(length(snr_grid), 1);
        
        for s = 1:length(snr_grid)
            snr_val = snr_grid(s);
            rows = strcmp(T.Venue, v_key) & strcmp(T.Filter, f_name) & (T.SNR_dB == snr_val);
            pesq_means(s) = mean(T.Mean_PESQ(rows));
        end
        
        plot(snr_grid, pesq_means, 'LineStyle', line_styles{f}, 'LineWidth', line_widths(f), ...
            'Color', colors(f, :), 'Marker', markers{f}, 'MarkerSize', 6, 'MarkerFaceColor', colors(f, :), ...
            'DisplayName', filter_labels{f});
    end
    
    title(venue_titles{v}, 'FontSize', 12, 'FontWeight', 'bold');
    xlabel('Target SNR (dB)', 'FontSize', 11);
    ylabel('PESQ Quality (MOS-LQO)', 'FontSize', 11);
    ylim([1.0, 4.6]);
    xlim([-16, 11]);
    set(gca, 'XTick', snr_grid);
    if v == 1
        legend('Location', 'southeast', 'FontSize', 8);
    end
end
sgtitle('Perceptual Speech Quality (PESQ) across Live Concert Venues & SNR Tiers', 'FontSize', 14, 'FontWeight', 'bold');
saveas(fig2, fullfile(figures_dir, 'room_experiment_pesq_vs_snr.png'));
close(fig2);

fprintf('--> Plotting Figure 3: Physical Delta SNR at Extreme Noise (-15 dB)...\n');
fig3 = figure('Visible', 'off', 'Position', [100, 100, 900, 500]);
hold on; box on; grid on;

active_filters = {'FIR_BP', 'Parametric_Notch', 'Base_NLMS', 'Leaky_NLMS', 'Soft_VAD_Leaky'};
active_labels = {'Fixed FIR Bandpass', 'Parametric Notch', 'Baseline NLMS', 'Leaky NLMS', 'Soft-VAD Leaky'};
bar_data = zeros(length(venues), length(active_filters));

for v = 1:length(venues)
    v_key = venues{v};
    for f = 1:length(active_filters)
        f_name = active_filters{f};
        rows = strcmp(T.Venue, v_key) & strcmp(T.Filter, f_name) & (T.SNR_dB == -15);
        bar_data(v, f) = mean(T.Mean_dSNR_dB(rows));
    end
end

b = bar(bar_data, 'grouped');
for f = 1:length(active_filters)
    b(f).FaceColor = colors(f+1, :);
end
set(gca, 'XTickLabel', {'Nightclub (RT60=0.7s)', 'Concert Arena (RT60=1.4s)', 'Festival Stage (RT60=0.2s)'}, 'FontSize', 11);
ylabel('Physical Noise Reduction \DeltaSNR (dB)', 'FontSize', 12);
title('Broadband Noise Attenuation Depth (\DeltaSNR) in Severe High Noise (SNR = -15 dB)', 'FontSize', 13, 'FontWeight', 'bold');
legend(active_labels, 'Location', 'northwest', 'FontSize', 10);
ylim([0, max(bar_data(:)) * 1.25]);

saveas(fig3, fullfile(figures_dir, 'room_experiment_delta_snr.png'));
close(fig3);

fprintf('--> Plotting Figure 4: Room Impulse Responses and Energy Decay Curves...\n');
fig4 = figure('Visible', 'off', 'Position', [100, 100, 1200, 600]);

addpath(fullfile(script_dir, '..', 'lib'));
fs = 16000;
v_dims = {[12, 15, 4], [25, 30, 8], [40, 50, 15]};
v_srcs = {[6, 8.65, 1.6], [12.5, 17.65, 1.6], [20, 14.65, 1.6]};
v_recs = {[6, 9, 1.6], [12.5, 18, 1.6], [20, 15, 1.6]};
v_rt60s = [0.70, 1.40, 0.20];

for v = 1:3
    [rir, t] = simulate_room_impulse_response(v_dims{v}, v_srcs{v}, v_recs{v}, v_rt60s(v), fs, 0.45);
    
    % Time domain waveform
    subplot(2, 3, v);
    plot(t * 1000, rir, 'Color', [0.2, 0.4, 0.8], 'LineWidth', 1.0);
    grid on; box on;
    title(sprintf('%s (RIR)', venue_titles{v}), 'FontSize', 11, 'FontWeight', 'bold');
    xlabel('Time (ms)', 'FontSize', 10);
    ylabel('Normalized Amplitude', 'FontSize', 10);
    xlim([0, 450]);
    ylim([-1.05, 1.05]);
    
    % Schroeder Energy Decay Curve (EDC) in dB
    edc = flipud(cumsum(flipud(rir.^2)));
    edc_db = 10 * log10(edc / (max(edc) + 1e-12) + 1e-12);
    
    subplot(2, 3, v + 3);
    plot(t * 1000, edc_db, 'Color', [0.85, 0.25, 0.2], 'LineWidth', 1.5);
    grid on; box on;
    title(sprintf('Energy Decay Curve (Target RT60 = %.2fs)', v_rt60s(v)), 'FontSize', 10);
    xlabel('Time (ms)', 'FontSize', 10);
    ylabel('Schroeder Decay (dB)', 'FontSize', 10);
    xlim([0, 450]);
    ylim([-60, 5]);
end
sgtitle('Acoustic Venue Characterization: Multi-Path RIRs & Schroeder Reverberant Decay', 'FontSize', 14, 'FontWeight', 'bold');
saveas(fig4, fullfile(figures_dir, 'room_experiment_rir_profiles.png'));
close(fig4);

fprintf('--> All figures saved successfully in: %s\n', figures_dir);
