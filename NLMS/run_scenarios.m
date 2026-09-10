%% NLMS Scenarios Consolidated Script

fs = 16000;
N = 256;
mu = 0.05;         % Stabilized for EDM
epsilon = 1e-2;

% Ensure correct paths
script_dir = fileparts(mfilename('fullpath'));
if isempty(script_dir), script_dir = pwd; end
dataset_dir = fullfile(script_dir, '..', 'dataset');
figures_dir = fullfile(script_dir, 'figures');
if ~exist(figures_dir, 'dir'), mkdir(figures_dir); end
output_dir = fullfile(script_dir, 'output_audio', 'run_all_scenarios');
if ~exist(output_dir, 'dir'), mkdir(output_dir); end

% Load Audio
speech_file = fullfile(dataset_dir, 'speech_corpus', 'combined', 'male_01_IUS-M00201.wav');
[clean_speech, fs_speech] = audioread(speech_file);
if fs_speech ~= fs, clean_speech = resample(clean_speech, fs, fs_speech); end

noise_file = fullfile(dataset_dir, 'wav_16k', 'techno', 'techno_1389887.wav');
[noise_source_full, fs_noise] = audioread(noise_file);
if fs_noise ~= fs, noise_source_full = resample(noise_source_full, fs, fs_noise); end

L = length(clean_speech);
noise_source_base = noise_source_full(1:L);
t = (0:L-1)' / fs;
zoom_start = min(1.5, t(end)-0.1); zoom_end = zoom_start + 0.05;

%% Scenario 1: Complex Acoustic Path (Reverberation)
disp('--- Running Scenario 1: Reverberation ---');
h_room = exp(- (0:150)' / 30) .* randn(151, 1);
ambient_noise_raw = conv(noise_source_base, h_room, 'same');

% Scale after convolution
ambient_noise_primary1 = scale_noise_for_snr(clean_speech, ambient_noise_raw, fs, -5);
d1 = clean_speech + ambient_noise_primary1;
x1 = noise_source_base;

[e1, ~] = nlms_filter(d1, x1, N, mu, epsilon);
[clean1, d1, e1] = normalize_for_export(0.9, clean_speech, d1, e1);

fig_scen1 = figure('Name', 'Scenario 1: Reverberation', 'Position', [100, 100, 800, 600]);
subplot(3, 1, 1); plot(t, d1); title('Primary Mic'); xlabel('Time (s)'); grid on;
subplot(3, 1, 2); plot(t, clean1); title('Original Clean Speech'); xlabel('Time (s)'); grid on;
subplot(3, 1, 3); plot(t, e1); title('Enhanced Speech'); xlabel('Time (s)'); grid on;
saveas(fig_scen1, fullfile(figures_dir, 'scenario1_reverb.png'));
audiowrite(fullfile(output_dir, 'scenario1_primary.wav'), d1, fs);
audiowrite(fullfile(output_dir, 'scenario1_enhanced.wav'), e1, fs);


%% Scenario 2: Speech Leakage into Reference Mic
disp('--- Running Scenario 2: Speech Leakage ---');
delay_samples2 = 5;
ambient_noise_raw = 0.8 * [zeros(delay_samples2, 1); noise_source_base(1:end-delay_samples2)];

ambient_noise_primary2 = scale_noise_for_snr(clean_speech, ambient_noise_raw, fs, -5);
d2 = clean_speech + ambient_noise_primary2;

% Leakage: The reference mic picks up 30% of the clean speech signal
x2 = noise_source_base + 0.3 * clean_speech;

[e2, ~] = nlms_filter(d2, x2, N, mu, epsilon);
[clean2, d2, e2] = normalize_for_export(0.9, clean_speech, d2, e2);

fig_scen2 = figure('Name', 'Scenario 2: Speech Leakage', 'Position', [100, 100, 800, 600]);
subplot(3, 1, 1); plot(t, d2); title('Primary Mic'); xlabel('Time (s)'); grid on;
subplot(3, 1, 2); plot(t, clean2); title('Original Clean Speech'); xlabel('Time (s)'); grid on;
subplot(3, 1, 3); plot(t, e2); title('Enhanced Speech (Note Attenuation)'); xlabel('Time (s)'); grid on;
saveas(fig_scen2, fullfile(figures_dir, 'scenario2_leakage.png'));
audiowrite(fullfile(output_dir, 'scenario2_primary.wav'), d2, fs);
audiowrite(fullfile(output_dir, 'scenario2_enhanced.wav'), e2, fs);


%% Scenario 3: Non-Stationary Acoustic Path (Head Movement)
disp('--- Running Scenario 3: Head Movement ---');
delay1 = 5;  noise1 = 0.8 * [zeros(delay1, 1); noise_source_base(1:end-delay1)];
delay2 = 25; noise2 = 0.6 * [zeros(delay2, 1); noise_source_base(1:end-delay2)];

mid_point = round(length(t)/2);
ambient_noise_raw = [noise1(1:mid_point); noise2(mid_point+1:end)];

ambient_noise_primary3 = scale_noise_for_snr(clean_speech, ambient_noise_raw, fs, -5);
d3 = clean_speech + ambient_noise_primary3;
x3 = noise_source_base;

[e3, ~] = nlms_filter(d3, x3, N, mu, epsilon);
[clean3, d3, e3] = normalize_for_export(0.9, clean_speech, d3, e3);

fig_scen3 = figure('Name', 'Scenario 3: Head Movement', 'Position', [100, 100, 800, 600]);
subplot(3, 1, 1); plot(t, d3); title('Primary Mic (Change at 1.5s)'); xlabel('Time (s)'); grid on;
subplot(3, 1, 2); plot(t, clean3); title('Original Clean Speech'); xlabel('Time (s)'); grid on;
subplot(3, 1, 3); plot(t, e3); title('Enhanced Speech'); xlabel('Time (s)'); grid on;
saveas(fig_scen3, fullfile(figures_dir, 'scenario3_movement.png'));
audiowrite(fullfile(output_dir, 'scenario3_primary.wav'), d3, fs);
audiowrite(fullfile(output_dir, 'scenario3_enhanced.wav'), e3, fs);


%% Scenario 4: Extreme Low SNR (-15 dB) with Bass Noise
disp('--- Running Scenario 4: Extreme Low SNR ---');
[b, a] = butter(2, 200/(fs/2), 'low'); % Lowpass at 200 Hz
rave_noise = filter(b, a, noise_source_base);

delay_samples4 = 5;
ambient_noise_raw = 0.8 * [zeros(delay_samples4, 1); rave_noise(1:end-delay_samples4)];

ambient_noise_primary4 = scale_noise_for_snr(clean_speech, ambient_noise_raw, fs, -15);
d4 = clean_speech + ambient_noise_primary4;
x4 = rave_noise;

[e4, ~] = nlms_filter(d4, x4, N, mu, epsilon);
[clean4, d4, e4] = normalize_for_export(0.9, clean_speech, d4, e4);

fig_scen4 = figure('Name', 'Scenario 4: Extreme Low SNR (-15dB)', 'Position', [100, 100, 800, 600]);
subplot(3, 1, 1); plot(t, d4); title('Primary Mic (Buried in bass)'); xlabel('Time (s)'); grid on;
subplot(3, 1, 2); plot(t, clean4); title('Original Clean Speech'); xlabel('Time (s)'); grid on;
subplot(3, 1, 3); plot(t, e4); title('Enhanced Speech'); xlabel('Time (s)'); grid on;
saveas(fig_scen4, fullfile(figures_dir, 'scenario4_low_snr.png'));
audiowrite(fullfile(output_dir, 'scenario4_primary.wav'), d4, fs);
audiowrite(fullfile(output_dir, 'scenario4_enhanced.wav'), e4, fs);

%% Scenario 5: Continuous Movement (Head Sweeping Left and Right)
disp('--- Running Scenario 5: Continuous Movement ---');

% 1. Create a time-varying delay to simulate head rotation at 0.5 Hz (one sweep every 2 seconds)
f_pan = 0.5;
base_delay = 10;     % Base delay in samples
max_deviation = 8;   % Sweeps between 2 and 18 samples of delay

ambient_noise_raw = zeros(L, 1);

% Apply the continuously shifting delay sample-by-sample
for n = 1:L
    % Calculate the instantaneous integer delay for this exact sample
    current_delay = round(base_delay + max_deviation * sin(2*pi*f_pan*t(n)));

    % Fetch the delayed noise sample (with boundary protection)
    if n > current_delay
        ambient_noise_raw(n) = 0.8 * noise_source_base(n - current_delay);
    end
end

% 2. Scale precisely to 0 dB SNR
ambient_noise_primary5 = scale_noise_for_snr(clean_speech, ambient_noise_raw, fs, 0);
d5 = clean_speech + ambient_noise_primary5;
x5 = noise_source_base;

% 3. Apply NLMS
[e5, ~] = nlms_filter(d5, x5, N, mu, epsilon);

% 4. Normalize for export
[clean5, d5, e5] = normalize_for_export(0.9, clean_speech, d5, e5);

% 5. Plotting
fig_scen5 = figure('Name', 'Scenario 5: Continuous Movement', 'Position', [100, 100, 800, 600]);
subplot(3, 1, 1); plot(t, d5); title('Primary Mic (Continuously Shifting Delay)'); xlabel('Time (s)'); grid on;
subplot(3, 1, 2); plot(t, clean5); title('Original Clean Speech'); xlabel('Time (s)'); grid on;
subplot(3, 1, 3); plot(t, e5); title('Enhanced Speech (Note the residual tracking error)'); xlabel('Time (s)'); grid on;
saveas(fig_scen5, fullfile(figures_dir, 'scenario5_continuous_movement.png'));

% Save Audio
audiowrite(fullfile(output_dir, 'scenario5_primary.wav'), d5, fs);
audiowrite(fullfile(output_dir, 'scenario5_enhanced.wav'), e5, fs);

disp('--- All scenarios completed and exported successfully. ---');