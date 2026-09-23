% evaluate_advanced_filters.m
% Evaluates the Advanced NLMS filters across the dataset, multiple noise types, and multiple SNRs

fs = 16000;
N = 1024;
mu = 0.05;
epsilon = 1e-2;
gamma = 0.999;
snr_levels = [-15, -10, -5, 0, 5];
prm = struct('frame_len_ms', 20, 'alpha_ema', 0.9, 'zcr_thresh', 0.05);

% Paths
script_dir = fileparts(mfilename('fullpath'));
if isempty(script_dir)
    script_dir = pwd;
end
addpath(fullfile(script_dir, '..', 'lib'));
dataset_dir = fullfile(script_dir, '..', '..', 'dataset');
speech_dir = fullfile(dataset_dir, 'speech_corpus', 'combined');

% Noise files
noise_files = {
    fullfile(dataset_dir, 'wav_16k', 'techno', 'techno_1389887.wav');
    fullfile(dataset_dir, 'wav_16k', 'jazz', 'jazz_01_jazz.00016.wav');
    fullfile(dataset_dir, 'wav_16k', 'rock', 'rock_01_rock.00011.wav')
    };

% Get list of speech files
speech_files = dir(fullfile(speech_dir, '*.wav'));
num_speech_files = length(speech_files);

if num_speech_files == 0
    error('No speech files found in %s', speech_dir);
end

% Set up CSV output directory and file
output_dir = fullfile(script_dir, '..', 'output_audio', 'grid_results');
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end
csv_filename = fullfile(output_dir, 'advanced_evaluation_results.csv');

% Open CSV file and write header
fid = fopen(csv_filename, 'w');
if fid == -1
    error('Cannot open CSV file for writing: %s', csv_filename);
end
fprintf(fid, 'Noise_Type,SNR_dB,Avg_STOI_In,Avg_STOI_Base,Avg_STOI_BaseVAD,Avg_STOI_Leaky,Avg_STOI_HardVAD,Avg_STOI_SoftVAD,Avg_visqol_In,Avg_visqol_Base,Avg_visqol_BaseVAD,Avg_visqol_Leaky,Avg_visqol_HardVAD,Avg_visqol_SoftVAD\n');

fprintf('\n=== Advanced NLMS Dataset Grid Evaluation ===\n');
fprintf('%-15s | %-8s | %-8s | %-8s | %-8s | %-8s | %-8s | %-8s | %-8s | %-8s | %-8s | %-8s | %-8s | %-8s\n', ...
    'Noise Type', 'SNR (dB)', 'STOI In', 'Base', 'Base-VAD', 'Leaky', 'Hard-VAD', 'Soft-VAD', 'visqol In', 'P-Base', 'P-BaseV', 'P-Leaky', 'P-HardV', 'P-SoftV');
fprintf('------------------------------------------------------------------------------------------------------------------------------------------------------\n');

for n_idx = 1:length(noise_files)
    % Load current noise file
    [noise_source_full, fs_noise] = audioread(noise_files{n_idx});
    if fs_noise ~= fs
        noise_source_full = resample(noise_source_full, fs, fs_noise);
    end

    % Get a clean name for printing
    [~, noise_name, ~] = fileparts(noise_files{n_idx});

    for snr_idx = 1:length(snr_levels)
        target_snr_dB = snr_levels(snr_idx);
        
        avg_stoi = zeros(1, 6); % [In, Base, BaseVAD, Leaky, Hard, Soft]
        avg_visqol = zeros(1, 6); % [In, Base, BaseVAD, Leaky, Hard, Soft]

        for s_idx = 1:num_speech_files
            % Load speech
            s_file_path = fullfile(speech_dir, speech_files(s_idx).name);
            [clean_speech, fs_speech] = audioread(s_file_path);
            if fs_speech ~= fs, clean_speech = resample(clean_speech, fs, fs_speech); end

            L = length(clean_speech);

            % Ensure noise is long enough, loop if necessary
            if length(noise_source_full) < L
                reps = ceil(L / length(noise_source_full));
                noise_source = repmat(noise_source_full, reps, 1);
            else
                noise_source = noise_source_full;
            end
            noise_source = noise_source(1:L);

            % Active Speech Power
            [asl_clean, ~] = calculate_active_speech_level(clean_speech, fs);
            p_s = 10^(asl_clean/10);
            p_n = mean(noise_source.^2);

            % Scale noise
            scale = sqrt(p_s / (p_n * 10^(target_snr_dB/10)));
            scaled_noise = noise_source * scale;

            % Peak Headroom Normalization
            d_base = clean_speech + scaled_noise;
            peak = max(abs(d_base));
            gain = 0.90 / peak;
            s_clean_norm = clean_speech * gain;
            s_noise_norm = scaled_noise * gain;

            % Simple acoustic path (1 sample delay)
            ambient_noise = 0.8 * [0; s_noise_norm(1:end-1)];
            d = s_clean_norm + ambient_noise;

            % Leakage into reference mic (20%)
            x = s_noise_norm + 0.2 * s_clean_norm;

            % Compute VAD
            [vad_hard, vad_soft] = compute_robust_vad(d, x, fs, prm);

            % Run Filters
            [e_base, ~] = nlms_filter(d, x, N, mu, epsilon);
            [e_base_vad, ~] = nlms_filter(d, x, N, mu, epsilon, vad_hard);
            [e_leaky, ~] = nlms_leaky_filter(d, x, N, mu, epsilon, gamma, zeros(L, 1));
            [e_hard, ~] = nlms_leaky_filter(d, x, N, mu, epsilon, gamma, vad_hard);
            [e_soft, ~] = nlms_leaky_filter(d, x, N, mu, epsilon, gamma, vad_soft);
            
            % Compute and accumulate STOI
            avg_stoi(1) = avg_stoi(1) + calculate_stoi(s_clean_norm, d, fs);
            avg_stoi(2) = avg_stoi(2) + calculate_stoi(s_clean_norm, e_base, fs);
            avg_stoi(3) = avg_stoi(3) + calculate_stoi(s_clean_norm, e_base_vad, fs);
            avg_stoi(4) = avg_stoi(4) + calculate_stoi(s_clean_norm, e_leaky, fs);
            avg_stoi(5) = avg_stoi(5) + calculate_stoi(s_clean_norm, e_hard, fs);
            avg_stoi(6) = avg_stoi(6) + calculate_stoi(s_clean_norm, e_soft, fs);

            avg_visqol(1) = avg_visqol(1) + calculate_visqol(s_clean_norm, d, fs);
            avg_visqol(2) = avg_visqol(2) + calculate_visqol(s_clean_norm, e_base, fs);
            avg_visqol(3) = avg_visqol(3) + calculate_visqol(s_clean_norm, e_base_vad, fs);
            avg_visqol(4) = avg_visqol(4) + calculate_visqol(s_clean_norm, e_leaky, fs);
            avg_visqol(5) = avg_visqol(5) + calculate_visqol(s_clean_norm, e_hard, fs);
            avg_visqol(6) = avg_visqol(6) + calculate_visqol(s_clean_norm, e_soft, fs);
        end
        
        % Average across speech files
        avg_stoi = avg_stoi / num_speech_files;
        avg_visqol = avg_visqol / num_speech_files;
        
        fprintf('%-15s | %-8d | %.4f   | %.4f   | %.4f   | %.4f   | %.4f   | %.4f   | %.4f   | %.4f   | %.4f   | %.4f   | %.4f   | %.4f\n', ...
            noise_name(1:min(15, length(noise_name))), target_snr_dB, ...
            avg_stoi(1), avg_stoi(2), avg_stoi(3), avg_stoi(4), avg_stoi(5), avg_stoi(6), ...
            avg_visqol(1), avg_visqol(2), avg_visqol(3), avg_visqol(4), avg_visqol(5), avg_visqol(6));
            
        fprintf(fid, '%s,%d,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f\n', ...
            noise_name, target_snr_dB, avg_stoi(1), avg_stoi(2), avg_stoi(3), avg_stoi(4), avg_stoi(5), avg_stoi(6), ...
            avg_visqol(1), avg_visqol(2), avg_visqol(3), avg_visqol(4), avg_visqol(5), avg_visqol(6));
    end
end

fclose(fid);
fprintf('------------------------------------------------------------------------------------------------------------------------------------------------------\n');
fprintf('Grid Evaluation Complete! Results saved to %s\n', csv_filename);
