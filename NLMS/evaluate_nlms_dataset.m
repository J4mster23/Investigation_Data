%% Evaluates the NLMS filter with multiple samples from dataset

fs = 16000;
N = 256;
mu = 0.05;
epsilon = 1e-2;
target_snr_dB = 0;

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

speech_files = dir(fullfile(speech_dir, '*.wav'));
num_files = length(speech_files);

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

    % 1. Create acoustic path first (1 sample delay)
    ambient_noise_raw = 0.8 * [0; noise_source(1:end-1)];

    % 2. Scale primary noise to Target SNR
    ambient_noise_primary = scale_noise_for_snr(clean_speech, ambient_noise_raw, fs, target_snr_dB);

    % 3. Mix Primary
    d = clean_speech + ambient_noise_primary;
    x = noise_source;

    % 4. Apply NLMS
    [e, ~] = nlms_filter(d, x, N, mu, epsilon);

    % 5. Calculate Metrics (Before normalization alters the raw dB level)
    stoi_in = calculate_stoi(clean_speech, d, fs);
    stoi_out = calculate_stoi(clean_speech, e, fs);
    [asl_d, ~] = calculate_active_speech_level(d, fs);
    [asl_e, ~] = calculate_active_speech_level(e, fs);

    fprintf('%-25s | %.4f       | %.4f       | %-16.2f | %-16.2f\n', ...
        speech_files(i).name(1:min(25, length(speech_files(i).name))), ...
        stoi_in, stoi_out, asl_d, asl_e);

    % 6. Normalize to prevent clipping on export
    [~, d_out, e_out] = normalize_for_export(0.90, clean_speech, d, e);

    % Save audio outputs
    [~, name, ~] = fileparts(speech_files(i).name);
    audiowrite(fullfile(output_dir, [name '_primary.wav']), d_out, fs);
    audiowrite(fullfile(output_dir, [name '_enhanced.wav']), e_out, fs);
end
fprintf('--------------------------------------------------------------------------------------------------\n');
disp('Evaluation Complete.');