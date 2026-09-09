% NLMS Scenarios Consolidated Script
% This script runs all four scenarios and saves the figures automatically

fs = 16000;         
N = 256;            
mu = 0.5;           
epsilon = 1e-6;     

t = (0:fs*3-1)' / fs; 
clean_speech = sin(2*pi*1000*t); 
noise_source_base = 0.5 * sin(2*pi*100*t) + 0.1 * randn(length(t), 1); 

% Ensure figures directory exists
script_dir = fileparts(mfilename('fullpath'));
if isempty(script_dir)
    script_dir = pwd;
end
figures_dir = fullfile(script_dir, 'figures');
if ~exist(figures_dir, 'dir')
    mkdir(figures_dir);
end

%% Scenario 1: Complex Acoustic Path (Reverberation)
disp('--- Running Scenario 1: Reverberation ---');
% Simulate complex room reverberation (151 tap impulse response)
h_room = exp(- (0:150)' / 30) .* randn(151, 1);
ambient_noise_primary1 = conv(noise_source_base, h_room, 'same');

d1 = clean_speech + ambient_noise_primary1;
x1 = noise_source_base; 

[e1, ~] = nlms_filter(d1, x1, N, mu, epsilon);

fig_scen1 = figure('Name', 'Scenario 1: Reverberation', 'Position', [100, 100, 800, 600]);
subplot(3, 1, 1); plot(t, d1); title('Primary Mic (Speech + Reverb Noise)'); xlabel('Time (s)'); grid on;
subplot(3, 1, 2); plot(t, clean_speech); title('Original Clean Speech'); xlabel('Time (s)'); grid on;
subplot(3, 1, 3); plot(t, e1); title('Enhanced Speech'); xlabel('Time (s)'); grid on;
saveas(fig_scen1, fullfile(figures_dir, 'scenario1_reverb.png'));

zoom_start = 2.5; zoom_end = 2.52; 
fig_scen1_zoom = figure('Name', 'Scenario 1: Zoomed View', 'Position', [950, 100, 800, 600]);
subplot(3, 1, 1); plot(t, d1); title('Zoomed Primary Mic'); xlim([zoom_start, zoom_end]); grid on;
subplot(3, 1, 2); plot(t, clean_speech); title('Zoomed Clean Speech'); xlim([zoom_start, zoom_end]); grid on;
subplot(3, 1, 3); plot(t, e1); title('Zoomed Enhanced Speech'); xlim([zoom_start, zoom_end]); grid on;
saveas(fig_scen1_zoom, fullfile(figures_dir, 'scenario1_reverb_zoomed.png'));


%% Scenario 2: Speech Leakage into Reference Mic
disp('--- Running Scenario 2: Speech Leakage ---');
delay_samples2 = 5;
ambient_noise_primary2 = 0.8 * [zeros(delay_samples2, 1); noise_source_base(1:end-delay_samples2)];
d2 = clean_speech + ambient_noise_primary2;

% Leakage: The reference mic picks up 30% of the clean speech signal
x2 = noise_source_base + 0.3 * clean_speech; 

[e2, ~] = nlms_filter(d2, x2, N, mu, epsilon);

fig_scen2 = figure('Name', 'Scenario 2: Speech Leakage', 'Position', [100, 100, 800, 600]);
subplot(3, 1, 1); plot(t, d2); title('Primary Mic (Speech + Noise)'); xlabel('Time (s)'); grid on;
subplot(3, 1, 2); plot(t, clean_speech); title('Original Clean Speech'); xlabel('Time (s)'); grid on;
subplot(3, 1, 3); plot(t, e2); title('Enhanced Speech (Note the attenuation of the speech!)'); xlabel('Time (s)'); grid on;
saveas(fig_scen2, fullfile(figures_dir, 'scenario2_leakage.png'));

fig_scen2_zoom = figure('Name', 'Scenario 2: Zoomed View', 'Position', [950, 100, 800, 600]);
subplot(3, 1, 1); plot(t, d2); title('Zoomed Primary Mic'); xlim([zoom_start, zoom_end]); grid on;
subplot(3, 1, 2); plot(t, clean_speech); title('Zoomed Clean Speech'); xlim([zoom_start, zoom_end]); grid on;
subplot(3, 1, 3); plot(t, e2); title('Zoomed Enhanced Speech (Speech is partially cancelled)'); xlim([zoom_start, zoom_end]); grid on;
saveas(fig_scen2_zoom, fullfile(figures_dir, 'scenario2_leakage_zoomed.png'));


%% Scenario 3: Non-Stationary Acoustic Path (Head Movement)
disp('--- Running Scenario 3: Head Movement ---');
delay1 = 5;
noise1 = 0.8 * [zeros(delay1, 1); noise_source_base(1:end-delay1)];
delay2 = 25;
noise2 = 0.6 * [zeros(delay2, 1); noise_source_base(1:end-delay2)];

% Abrupt switch at exactly t = 1.5 seconds
mid_point = round(length(t)/2);
ambient_noise_primary3 = [noise1(1:mid_point); noise2(mid_point+1:end)];

d3 = clean_speech + ambient_noise_primary3;
x3 = noise_source_base; 

[e3, ~] = nlms_filter(d3, x3, N, mu, epsilon);

fig_scen3 = figure('Name', 'Scenario 3: Head Movement', 'Position', [100, 100, 800, 600]);
subplot(3, 1, 1); plot(t, d3); title('Primary Mic (Abrupt change at 1.5s)'); xlabel('Time (s)'); grid on;
subplot(3, 1, 2); plot(t, clean_speech); title('Original Clean Speech'); xlabel('Time (s)'); grid on;
subplot(3, 1, 3); plot(t, e3); title('Enhanced Speech (Watch re-convergence after 1.5s)'); xlabel('Time (s)'); grid on;
saveas(fig_scen3, fullfile(figures_dir, 'scenario3_movement.png'));

% Zoom around the transition
zoom_start3 = 1.45; zoom_end3 = 1.55; 
fig_scen3_zoom = figure('Name', 'Scenario 3: Zoomed View at Transition', 'Position', [950, 100, 800, 600]);
subplot(3, 1, 1); plot(t, d3); title('Zoomed Primary Mic (Transition)'); xlim([zoom_start3, zoom_end3]); grid on;
subplot(3, 1, 2); plot(t, clean_speech); title('Zoomed Clean Speech'); xlim([zoom_start3, zoom_end3]); grid on;
subplot(3, 1, 3); plot(t, e3); title('Zoomed Enhanced Speech (Filter adapting)'); xlim([zoom_start3, zoom_end3]); grid on;
saveas(fig_scen3_zoom, fullfile(figures_dir, 'scenario3_movement_zoomed.png'));


%% Scenario 4: Extreme Low SNR (-15 dB) with Bass Noise
disp('--- Running Scenario 4: Extreme Low SNR ---');
speech_var = var(clean_speech);

% Create "Bass Heavy" noise using a lowpass filter
noise_source_raw = randn(length(t), 1);
[b, a] = butter(2, 200/(fs/2), 'low'); % Lowpass at 200 Hz
rave_noise = filter(b, a, noise_source_raw);

% Scale noise to achieve exactly -15 dB SNR
target_noise_var = speech_var * 10^(15/10);
rave_noise = rave_noise * sqrt(target_noise_var / var(rave_noise));

delay_samples4 = 5;
ambient_noise_primary4 = 0.8 * [zeros(delay_samples4, 1); rave_noise(1:end-delay_samples4)];

d4 = clean_speech + ambient_noise_primary4;
x4 = rave_noise;

[e4, ~] = nlms_filter(d4, x4, N, mu, epsilon);

fig_scen4 = figure('Name', 'Scenario 4: Extreme Low SNR (-15dB)', 'Position', [100, 100, 800, 600]);
subplot(3, 1, 1); plot(t, d4); title('Primary Mic (Speech completely buried in bass noise)'); xlabel('Time (s)'); grid on;
subplot(3, 1, 2); plot(t, clean_speech); title('Original Clean Speech'); xlabel('Time (s)'); grid on;
subplot(3, 1, 3); plot(t, e4); title('Enhanced Speech (Speech recovered)'); xlabel('Time (s)'); grid on;
saveas(fig_scen4, fullfile(figures_dir, 'scenario4_low_snr.png'));

fig_scen4_zoom = figure('Name', 'Scenario 4: Zoomed View', 'Position', [950, 100, 800, 600]);
subplot(3, 1, 1); plot(t, d4); title('Zoomed Primary Mic (Low SNR)'); xlim([zoom_start, zoom_end]); grid on;
subplot(3, 1, 2); plot(t, clean_speech); title('Zoomed Clean Speech'); xlim([zoom_start, zoom_end]); grid on;
subplot(3, 1, 3); plot(t, e4); title('Zoomed Enhanced Speech (Restored wave)'); xlim([zoom_start, zoom_end]); grid on;
saveas(fig_scen4_zoom, fullfile(figures_dir, 'scenario4_low_snr_zoomed.png'));

disp('--- All scenarios completed. Figures saved in figures/ folder. ---');
