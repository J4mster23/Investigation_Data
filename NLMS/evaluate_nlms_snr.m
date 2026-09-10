%% Cycle varying NLMS SNR and music configs output STOI for set and average STOI

fs = 16000;
N = 256;
mu = 0.05;
epsilon = 1e-2;

% Define the grid of SNRs to test
target_snrs_dB = [-15, -10, -5, 0, 5, 10];

% Paths
script_dir = fileparts(mfilename('fullpath'));
if isempty(script_dir)
    script_dir = pwd;
end
dataset_dir = fullfile(script_dir, '..', 'dataset');
speech_dir = fullfile(dataset_dir, 'speech_corpus', 'combined');

noise_files = {
    fullfile(dataset_dir, 'wav_16k', 'techno', 'techno_1389887.wav');
    fullfile(dataset_dir, 'wav_16k', 'jazz', 'jazz_01_jazz.00016.wav');
    fullfile(dataset_dir, 'wav_16k', 'rock', 'rock_01_rock.00011.wav')
    };

speech_files = dir(fullfile(speech_dir, '*.wav'));
num_speech_files = length(speech_files);

if num_speech_files == 0
    error('No speech files found in %s', speech_dir);
end

% Set up CSV output directory and file
output_dir = fullfile(script_dir, 'output_audio', 'grid_results');
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end
csv_filename = fullfile(output_dir, 'nlms_grid_results.csv');

% Open CSV file and write header
fid = fopen(csv_filename, 'w');
if fid == -1
    error('Cannot open CSV file for writing: %s', csv_filename);
end
fprintf(fid, 'Noise_Type,SNR_dB,Avg_STOI_In,Avg_STOI_Out,Improvement\n');

fprintf('\n=== NLMS Grid Evaluation (Multi-Noise / Multi-SNR) ===\n');
fprintf('Filter Taps (N): %d | Step Size (mu): %.3f\n', N, mu);
fprintf('----------------------------------------------------------------------\n');
fprintf('%-15s | %-8s | %-10s | %-10s | %-10s\n', 'Noise Type', 'SNR (dB)', 'Avg STOI In', 'Avg STOI Out', 'Improvement');
fprintf('----------------------------------------------------------------------\n');

for n_idx = 1:length(noise_files)
    % Load current noise file
    [noise_source_full, fs_noise] = audioread(noise_files{n_idx});
    if fs_noise ~= fs
        noise_source_full = resample(noise_source_full, fs, fs_noise);
    end

    % Get a clean name for printing
    [~, noise_name, ~] = fileparts(noise_files{n_idx});

    for snr_idx = 1:length(target_snrs_dB)
        current_snr = target_snrs_dB(snr_idx);

        stoi_in_total = 0;
        stoi_out_total = 0;

        for s_idx = 1:num_speech_files
            % Load speech
            s_file_path = fullfile(speech_dir, speech_files(s_idx).name);
            [clean_speech, fs_speech] = audioread(s_file_path);
            if fs_speech ~= fs
                clean_speech = resample(clean_speech, fs, fs_speech);
            end

            L = length(clean_speech);

            % Ensure noise is long enough, loop if necessary
            if length(noise_source_full) < L
                reps = ceil(L / length(noise_source_full));
                noise_source = repmat(noise_source_full, reps, 1);
            else
                noise_source = noise_source_full;
            end
            noise_source = noise_source(1:L);

            % 1. Acoustic Path (1 sample delay)
            ambient_noise_raw = 0.8 * [0; noise_source(1:end-1)];

            % 2. Scale Noise
            ambient_noise_primary = scale_noise_for_snr(clean_speech, ambient_noise_raw, fs, current_snr);

            % 3. Mix
            d = clean_speech + ambient_noise_primary;
            x = noise_source;

            % 4. Apply NLMS
            [e, ~] = nlms_filter(d, x, N, mu, epsilon);

            % 5. Accumulate STOI Metrics
            stoi_in_total = stoi_in_total + calculate_stoi(clean_speech, d, fs);
            stoi_out_total = stoi_out_total + calculate_stoi(clean_speech, e, fs);
        end

        % Averages for this condition
        avg_stoi_in = stoi_in_total / num_speech_files;
        avg_stoi_out = stoi_out_total / num_speech_files;
        improvement = avg_stoi_out - avg_stoi_in;

        fprintf('%-15s | %-8d | %.4f     | %.4f     | %+.4f\n', ...
            noise_name(1:min(15, length(noise_name))), current_snr, avg_stoi_in, avg_stoi_out, improvement);
        fprintf(fid, '%s,%d,%.4f,%.4f,%.4f\n', noise_name, current_snr, avg_stoi_in, avg_stoi_out, improvement);
    end
end

fclose(fid);
fprintf('----------------------------------------------------------------------\n');
disp('Grid Evaluation Complete.');