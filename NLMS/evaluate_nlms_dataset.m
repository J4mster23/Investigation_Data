% evaluate_nlms_dataset.m
% Evaluates the NLMS filter over multiple speech samples from the dataset

fs = 16000;
N = 256;
mu = 0.5;
epsilon = 1e-2;
target_snr_dB = 0;  % Target Input SNR

% Paths
script_dir = fileparts(mfilename('fullpath'));
if isempty(script_dir)
    script_dir = pwd;
end
dataset_dir = fullfile(script_dir, '..', 'dataset');
speech_dir = fullfile(dataset_dir, 'speech_corpus', 'combined');

% Load EDM noise source
noise_file = fullfile(dataset_dir, 'wav_16k', 'techno', 'techno_1389887.wav');
[noise_source_full, fs_noise] = audioread(noise_file);
if fs_noise ~= fs
    noise_source_full = resample(noise_source_full, fs, fs_noise);
end

% Get list of speech files
speech_files = dir(fullfile(speech_dir, '*.wav'));
num_files = length(speech_files); % Test on all files

% Create output audio directory
output_dir = fullfile(script_dir, 'output_audio', 'evaluate_dataset');
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

fprintf('\n=== NLMS Dataset Evaluation ===\n');
fprintf('Noise Type: Techno, Target SNR: %d dB\n', target_snr_dB);
fprintf('--------------------------------------------------------------------------------------------------\n');
fprintf('%-25s | %-12s | %-12s | %-16s | %-16s\n', 'Speech File', 'STOI In', 'STOI Out', 'ASL Primary (dB)', 'ASL Enhanced (dB)');
fprintf('--------------------------------------------------------------------------------------------------\n');

for i = 1:num_files
    % Load speech
    s_file_path = fullfile(speech_dir, speech_files(i).name);
    [clean_speech, fs_speech] = audioread(s_file_path);
    if fs_speech ~= fs
        clean_speech = resample(clean_speech, fs, fs_speech);
    end

    L = length(clean_speech);
    noise_source = noise_source_full(1:L);

    % Scale noise using active speech level
    [asl_clean, ~] = calculate_active_speech_level(clean_speech, fs);
    p_s = 10^(asl_clean/10);
    p_n = mean(noise_source.^2);
    scale = sqrt(p_s / (p_n * 10^(target_snr_dB/10)));
    noise_source = noise_source * scale;

    % Peak Headroom Normalization
    d_base = clean_speech + noise_source;
    peak = max(abs(d_base));
    gain = 0.90 / peak;
    clean_speech = clean_speech * gain;
    noise_source = noise_source * gain;

    % Simple acoustic path (1 sample delay)
    ambient_noise = 0.8 * [0; noise_source(1:end-1)];
    d = clean_speech + ambient_noise;
    x = noise_source;

    % Apply NLMS
    [e, ~] = nlms_filter(d, x, N, mu, epsilon);

    % Calculate Metrics
    stoi_in = calculate_stoi(clean_speech, d, fs);
    stoi_out = calculate_stoi(clean_speech, e, fs);

    [asl_d, ~] = calculate_active_speech_level(d, fs);
    [asl_e, ~] = calculate_active_speech_level(e, fs);

    fprintf('%-25s | %.4f       | %.4f       | %-16.2f | %-16.2f\n', ...
        speech_files(i).name(1:min(25, length(speech_files(i).name))), ...
        stoi_in, stoi_out, asl_d, asl_e);

    % Save audio outputs
    [~, name, ~] = fileparts(speech_files(i).name);
    audiowrite(fullfile(output_dir, [name '_primary.wav']), d, fs);
    audiowrite(fullfile(output_dir, [name '_enhanced.wav']), e, fs);
end
fprintf('--------------------------------------------------------------------------------------------------\n');
disp('Evaluation Complete.');
