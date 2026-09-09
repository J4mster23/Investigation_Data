% Basic Test for NLMS Filter Function
% This script replaces the previous nlms_simulation.m script

% Parameters
fs = 16000;         % Sampling frequency (16 kHz)
N = 256;           % Filter order (number of taps)
mu = 0.5;          % Step size
epsilon = 1e-2;     % Regularisation constant

% Ensure correct paths
script_dir = fileparts(mfilename('fullpath'));
if isempty(script_dir)
    script_dir = pwd;
end
dataset_dir = fullfile(script_dir, '..', 'dataset');

% 1. Load actual clean speech from dataset
speech_file = fullfile(dataset_dir, 'speech_corpus', 'combined', 'female_01_IUS-F00202.wav');
[clean_speech, fs_speech] = audioread(speech_file);
if fs_speech ~= fs
    clean_speech = resample(clean_speech, fs, fs_speech);
end

% 2. Load actual EDM noise source
noise_file = fullfile(dataset_dir, 'wav_16k', 'techno', 'techno_1389887.wav');
[noise_source_full, fs_noise] = audioread(noise_file);
if fs_noise ~= fs
    noise_source_full = resample(noise_source_full, fs, fs_noise);
end

% Truncate noise to match speech length
L = length(clean_speech);
noise_source = noise_source_full(1:L);

% Scale noise to target SNR (e.g., 0 dB) using active speech level
target_snr_dB = 0;
[asl_clean, ~] = calculate_active_speech_level(clean_speech, fs);
p_s = 10^(asl_clean/10);
p_n = mean(noise_source.^2);
scale = sqrt(p_s / (p_n * 10^(target_snr_dB/10)));
noise_source = noise_source * scale;

t = (0:L-1)' / fs; % Update time vector based on real signal length

% 3. Simple acoustic path to primary microphone (scaled and slightly delayed noise)
delay_samples = 1;
ambient_noise_primary = 0.8 * [zeros(delay_samples, 1); noise_source(1:end-delay_samples)];

% Primary mic signal d(n) = Speech + Noise
d = clean_speech + ambient_noise_primary;

% 4. Simple acoustic path to reference microphone (noise as is)
x = noise_source; % Reference mic signal x(n)

% 5. Peak Headroom Normalization (Target Peak = 0.90) to ensure audio is loud
peak = max(abs(d));
gain = 0.90 / peak;
d = d * gain;
x = x * gain;
clean_speech = clean_speech * gain;

disp('Starting NLMS Simulation using nlms_filter...');
[e, w] = nlms_filter(d, x, N, mu, epsilon);
disp('Simulation Complete.');

% Ensure figures directory exists
script_dir = fileparts(mfilename('fullpath'));
if isempty(script_dir)
    script_dir = pwd;
end
figures_dir = fullfile(script_dir, 'figures');
if ~exist(figures_dir, 'dir')
    mkdir(figures_dir);
end

% Plot the results
fig1 = figure('Name', 'NLMS Adaptive Filtering Simulation', 'Position', [100, 100, 800, 600]);

subplot(3, 1, 1);
plot(t, d);
title('Primary Mic Signal d(n) (Speech + Noise)');
xlabel('Time (s)');
ylabel('Amplitude');
grid on;

subplot(3, 1, 2);
plot(t, clean_speech);
title('Original Clean Speech (Ground Truth)');
xlabel('Time (s)');
ylabel('Amplitude');
grid on;

subplot(3, 1, 3);
plot(t, e);
title('Enhanced Speech e(n) (NLMS Error Signal)');
xlabel('Time (s)');
ylabel('Amplitude');
grid on;

saveas(fig1, fullfile(figures_dir, 'test_nlms_simulation.png'));

% Plot a zoomed-in section to better view the signal shapes (after convergence)
zoom_start = min(1.5, t(end)-0.1);
zoom_end = zoom_start + 0.05; % 50 milliseconds snippet

fig2 = figure('Name', 'NLMS Zoomed View', 'Position', [950, 100, 800, 600]);

subplot(3, 1, 1);
plot(t, d);
title('Zoomed Primary Mic Signal (Speech + Noise)');
xlabel('Time (s)');
ylabel('Amplitude');
xlim([zoom_start, zoom_end]);
grid on;

subplot(3, 1, 2);
plot(t, clean_speech);
title('Zoomed Clean Speech');
xlabel('Time (s)');
ylabel('Amplitude');
xlim([zoom_start, zoom_end]);
grid on;

subplot(3, 1, 3);
plot(t, e);
title('Zoomed Enhanced Speech');
xlabel('Time (s)');
ylabel('Amplitude');
xlim([zoom_start, zoom_end]);
grid on;

saveas(fig2, fullfile(figures_dir, 'test_nlms_zoomed.png'));

disp('--- Metrics ---');
% STOI
stoi_before = calculate_stoi(clean_speech, d, fs);
stoi_after = calculate_stoi(clean_speech, e, fs);
fprintf('STOI Before: %.4f\n', stoi_before);
fprintf('STOI After:  %.4f\n', stoi_after);

% Active Speech Level
[asl_clean, act_clean] = calculate_active_speech_level(clean_speech, fs);
[asl_d, act_d] = calculate_active_speech_level(d, fs);
[asl_e, act_e] = calculate_active_speech_level(e, fs);
fprintf('Active Speech Level (Clean):   %.2f dB (Activity: %.2f%%)\n', asl_clean, act_clean*100);
fprintf('Active Speech Level (Primary): %.2f dB (Activity: %.2f%%)\n', asl_d, act_d*100);
fprintf('Active Speech Level (Enhanced):%.2f dB (Activity: %.2f%%)\n', asl_e, act_e*100);

% Save audio outputs
output_dir = fullfile(script_dir, 'output_audio', 'test_nlms');
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

audiowrite(fullfile(output_dir, 'test_nlms_clean.wav'), clean_speech, fs);
audiowrite(fullfile(output_dir, 'test_nlms_primary.wav'), d, fs);
audiowrite(fullfile(output_dir, 'test_nlms_enhanced.wav'), e, fs);
disp('Audio outputs saved to output_audio/ folder.');


