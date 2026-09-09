% Basic Test for NLMS Filter Function
% This script replaces the previous nlms_simulation.m script

% Parameters
fs = 16000;         % Sampling frequency (16 kHz)
N = 256;            % Filter order (number of taps)
mu = 0.5;           % Step size
epsilon = 1e-6;     % Regularisation constant

disp('Generating synthetic test signals...');
t = (0:fs*3-1)' / fs; % 3 seconds of audio

% 1. Create a basic clean signal (a pure 1 kHz sine wave for easy validation)
clean_speech = sin(2*pi*1000*t);

% 2. Create a basic noise source (a 100 Hz sine wave + low amplitude white noise)
noise_source = 0.5 * sin(2*pi*100*t) + 0.1 * randn(length(t), 1);

% 3. Simple acoustic path to primary microphone (scaled and slightly delayed noise)
delay_samples = 1;
ambient_noise_primary = 0.8 * [zeros(delay_samples, 1); noise_source(1:end-delay_samples)];

% Primary mic signal d(n) = Speech + Noise
d = clean_speech + ambient_noise_primary;

% 4. Simple acoustic path to reference microphone (noise as is)
x = noise_source; % Reference mic signal x(n)

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
zoom_start = 2.5;
zoom_end = 2.52; % 20 milliseconds snippet

fig2 = figure('Name', 'NLMS Zoomed View (2.5s - 2.52s)', 'Position', [950, 100, 800, 600]);

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
