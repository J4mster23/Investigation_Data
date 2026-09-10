%% Basic Test Script for NLMS
% Parameters
fs = 16000;
N = 256;
mu = 0.05;
epsilon = 1e-2;

% Ensure correct paths
script_dir = fileparts(mfilename('fullpath'));
if isempty(script_dir)
    script_dir = pwd;
end
dataset_dir = fullfile(script_dir, '..', 'dataset');

% 1. Load clean speech
speech_file = fullfile(dataset_dir, 'speech_corpus', 'combined', 'female_01_IUS-F00202.wav');
[clean_speech, fs_speech] = audioread(speech_file);
if fs_speech ~= fs
    clean_speech = resample(clean_speech, fs, fs_speech);
end

% 2. Load EDM noise source
noise_file = fullfile(dataset_dir, 'wav_16k', 'techno', 'techno_1389887.wav');
[noise_source_full, fs_noise] = audioread(noise_file);
if fs_noise ~= fs
    noise_source_full = resample(noise_source_full, fs, fs_noise);
end

% Truncate noise to match speech length
L = length(clean_speech);
noise_source = noise_source_full(1:L);
t = (0:L-1)' / fs;

% 3. Apply Acoustic Path BEFORE scaling
delay_samples = 1;
ambient_noise_raw = 0.8 * [zeros(delay_samples, 1); noise_source(1:end-delay_samples)];

% 4. Scale exactly to Target SNR
target_snr_dB = 0;
ambient_noise_primary = scale_noise_for_snr(clean_speech, ambient_noise_raw, fs, target_snr_dB);

% 5. Mix Primary Mic
d = clean_speech + ambient_noise_primary;
x = noise_source;

% 6. Apply NLMS
disp('Starting NLMS Simulation using nlms_filter...');
[e, w] = nlms_filter(d, x, N, mu, epsilon);
disp('Simulation Complete.');

% 7. Normalize for Export/Plotting (prevents clipping, preserves relative volume)
[clean_speech, d, e] = normalize_for_export(0.90, clean_speech, d, e);

% Metrics
stoi_before = calculate_stoi(clean_speech, d, fs);
stoi_after = calculate_stoi(clean_speech, e, fs);
fprintf('STOI Before: %.4f\n', stoi_before);
fprintf('STOI After:  %.4f\n', stoi_after);

% Ensure directories exist
figures_dir = fullfile(script_dir, 'figures');
if ~exist(figures_dir, 'dir'), mkdir(figures_dir); end
output_dir = fullfile(script_dir, 'output_audio', 'test_nlms');
if ~exist(output_dir, 'dir'), mkdir(output_dir); end

% Save audio outputs
audiowrite(fullfile(output_dir, 'test_nlms_clean.wav'), clean_speech, fs);
audiowrite(fullfile(output_dir, 'test_nlms_primary.wav'), d, fs);
audiowrite(fullfile(output_dir, 'test_nlms_enhanced.wav'), e, fs);
disp('Audio outputs saved.');

% (Plotting code remains exactly the same below)
fig1 = figure('Name', 'NLMS Adaptive Filtering Simulation', 'Position', [100, 100, 800, 600]);
subplot(3, 1, 1); plot(t, d); title('Primary Mic Signal'); xlabel('Time (s)'); grid on;
subplot(3, 1, 2); plot(t, clean_speech); title('Original Clean Speech'); xlabel('Time (s)'); grid on;
subplot(3, 1, 3); plot(t, e); title('Enhanced Speech e(n)'); xlabel('Time (s)'); grid on;
saveas(fig1, fullfile(figures_dir, 'test_nlms_simulation.png'));