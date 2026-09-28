% run_concert_venue_room_experiment.m
% Comprehensive Concert Venue Room Acoustic Simulation & Enhancement Benchmark
% Simulates Club, Arena, and Festival acoustic transfer paths using ISM RIRs.
% Evaluates STOI, PESQ, Delta SNR, and Delta ASL across 6 SNR tiers and 3 genres.

clear; clc;
fprintf('========================================================================\n');
fprintf('  CONCERT VENUE ROOM ACOUSTIC SIMULATION & SPEECH ENHANCEMENT BENCHMARK \n');
fprintf('========================================================================\n\n');

fs = 16000;
N_nlms = 256;
mu_nlms = 0.05;
eps_nlms = 1e-2;
gamma_leaky = 0.999;
vad_prm = struct('frame_len_ms', 20, 'alpha_ema', 0.9, 'zcr_thresh', 0.05);

% 1. Set up directory paths
script_dir = fileparts(mfilename('fullpath'));
if isempty(script_dir), script_dir = pwd; end
addpath(fullfile(script_dir, '..', 'lib'));

repo_root = fullfile(script_dir, '..', '..');
dataset_dir = fullfile(repo_root, 'dataset');
speech_corpus_dir = fullfile(dataset_dir, 'speech_corpus');
metadata_dir = fullfile(dataset_dir, 'metadata');

output_dir = fullfile(script_dir, '..', 'output_audio', 'room_experiment');
sample_dir = fullfile(output_dir, 'samples');
if ~exist(output_dir, 'dir'), mkdir(output_dir); end
if ~exist(sample_dir, 'dir'), mkdir(sample_dir); end

% 2. Load Filter Workspace
ws_file = fullfile(metadata_dir, 'filter_comparison_workspace.mat');
if ~exist(ws_file, 'file')
    error('Filter workspace not found: %s', ws_file);
end
ws = load(ws_file);
filters_fir = ws.filters_fir;
filters_notch = ws.filters_notch;

% 3. Venue Geometries (Report 09 specifications)
venues = struct();

% 3.1 Nightclub (Indoor, dense early reflections)
venues.club.name = 'Nightclub';
venues.club.dim  = [12.0, 15.0, 4.0];
venues.club.rt60 = 0.70;
venues.club.speech_pos = [6.0, 8.65, 1.6]; % Near-field talker (0.35m from Mic 1)
venues.club.mic1_pos   = [6.0, 9.00, 1.6]; % Primary mic (front)
venues.club.mic2_pos   = [6.0, 9.04, 1.6]; % Reference mic (rear, 4cm spacing)
venues.club.pa_left    = [2.0, 1.00, 2.5]; % Stage PA Left
venues.club.pa_right   = [10.0, 1.00, 2.5];% Stage PA Right

% 3.2 Concert Arena (Cavernous hall, heavy diffuse reverberation)
venues.arena.name = 'Concert Arena';
venues.arena.dim  = [25.0, 30.0, 8.0];
venues.arena.rt60 = 1.40;
venues.arena.speech_pos = [12.5, 17.65, 1.6];
venues.arena.mic1_pos   = [12.5, 18.00, 1.6];
venues.arena.mic2_pos   = [12.5, 18.04, 1.6];
venues.arena.pa_left    = [4.0, 2.00, 5.0];
venues.arena.pa_right   = [21.0, 2.00, 5.0];

% 3.3 Open-Air Festival (Direct PA + ground reflection, low RT60)
venues.festival.name = 'Open-Air Festival';
venues.festival.dim  = [40.0, 50.0, 15.0];
venues.festival.rt60 = 0.20;
venues.festival.speech_pos = [20.0, 14.65, 1.6];
venues.festival.mic1_pos   = [20.0, 15.00, 1.6];
venues.festival.mic2_pos   = [20.0, 15.04, 1.6];
venues.festival.pa_left    = [8.0, 3.00, 4.0];
venues.festival.pa_right   = [32.0, 3.00, 4.0];

venue_keys = {'club', 'arena', 'festival'};

% 4. Precompute & Cache Multi-Path RIRs for Each Venue
fprintf('--> Precomputing Image Source Method (ISM) Room Impulse Responses...\n');
rirs = struct();
max_rir_sec = 0.45; % 450 ms capture length

for v_idx = 1:length(venue_keys)
    v_key = venue_keys{v_idx};
    v = venues.(v_key);
    
    fprintf('    Synthesizing RIRs for [%s] (RT60 = %.2fs, Room = %dx%dx%dm)...\n', ...
        v.name, v.rt60, v.dim(1), v.dim(2), v.dim(3));
    
    % Speech RIRs (Near-field talker to mics)
    [h_s1, ~] = simulate_room_impulse_response(v.dim, v.speech_pos, v.mic1_pos, v.rt60, fs, max_rir_sec);
    [h_s2, ~] = simulate_room_impulse_response(v.dim, v.speech_pos, v.mic2_pos, v.rt60, fs, max_rir_sec);
    
    % Music RIRs (Stereo Stage PA to mics)
    [h_paL1, ~] = simulate_room_impulse_response(v.dim, v.pa_left, v.mic1_pos, v.rt60, fs, max_rir_sec);
    [h_paR1, ~] = simulate_room_impulse_response(v.dim, v.pa_right, v.mic1_pos, v.rt60, fs, max_rir_sec);
    [h_paL2, ~] = simulate_room_impulse_response(v.dim, v.pa_left, v.mic2_pos, v.rt60, fs, max_rir_sec);
    [h_paR2, ~] = simulate_room_impulse_response(v.dim, v.pa_right, v.mic2_pos, v.rt60, fs, max_rir_sec);
    
    % Store in struct
    rirs.(v_key).h_s1 = h_s1;
    rirs.(v_key).h_s2 = h_s2;
    rirs.(v_key).h_n1 = 0.5 * (h_paL1 + h_paR1);
    rirs.(v_key).h_n2 = 0.5 * (h_paL2 + h_paR2);
end
fprintf('    All Room Impulse Responses generated successfully.\n\n');

% 5. Load Speech Corpus (10 Male, 10 Female Harvard Sentences)
m_files = dir(fullfile(speech_corpus_dir, 'male', 'male_*.wav'));
f_files = dir(fullfile(speech_corpus_dir, 'female', 'female_*.wav'));

n_spk = 10;
speech_manifest = {};
for i = 1:min(n_spk, length(m_files))
    speech_manifest{end+1} = struct('path', fullfile(speech_corpus_dir, 'male', m_files(i).name), ...
        'name', m_files(i).name, 'gender', 'male');
end
for i = 1:min(n_spk, length(f_files))
    speech_manifest{end+1} = struct('path', fullfile(speech_corpus_dir, 'female', f_files(i).name), ...
        'name', f_files(i).name, 'gender', 'female');
end

% 6. Load Noise Stems (Acoustic Triad)
noise_files = struct();
noise_files.techno = fullfile(dataset_dir, 'wav_16k', 'techno', 'techno_1389887.wav');
noise_files.jazz   = fullfile(dataset_dir, 'wav_16k', 'jazz', 'jazz_01_jazz.00016.wav');
noise_files.rock   = fullfile(dataset_dir, 'wav_16k', 'rock', 'rock_01_rock.00011.wav');

genres = {'techno', 'jazz', 'rock'};
snr_levels = [-15, -10, -5, 0, 5, 10];
filter_names = {'Unprocessed', 'FIR_BP', 'Parametric_Notch', 'Base_NLMS', 'Leaky_NLMS', 'Soft_VAD_Leaky'};

% 7. Initialize Results Files
results_csv = fullfile(output_dir, 'room_experiment_results.csv');
summary_csv = fullfile(output_dir, 'room_experiment_summary.csv');

fid_res = fopen(results_csv, 'w');
fprintf(fid_res, 'Venue,Genre,File,Gender,SNR_dB,Filter,STOI,PESQ,dSNR_dB,dASL_dB\n');

fid_sum = fopen(summary_csv, 'w');
fprintf(fid_sum, 'Venue,Genre,SNR_dB,Filter,Mean_STOI,Mean_PESQ,Mean_dSNR_dB,Mean_dASL_dB\n');

% Container for aggregated summary statistics
summary_map = containers.Map();

fprintf('--> Executing Grid Simulation across 3 Venues x 3 Genres x 6 SNRs x 20 Talkers...\n');
fprintf('    Total simulation passes: %d\n\n', length(venue_keys) * length(genres) * length(snr_levels) * length(speech_manifest));

sample_export_count = 0;

for v_idx = 1:length(venue_keys)
    v_key = venue_keys{v_idx};
    v_name = venues.(v_key).name;
    h_s1 = rirs.(v_key).h_s1;
    h_s2 = rirs.(v_key).h_s2;
    h_n1 = rirs.(v_key).h_n1;
    h_n2 = rirs.(v_key).h_n2;
    
    fprintf('========================================================================\n');
    fprintf('  VENUE: %s (RT60 = %.2fs)\n', upper(v_name), venues.(v_key).rt60);
    fprintf('========================================================================\n');
    
    for g_idx = 1:length(genres)
        genre = genres{g_idx};
        
        % Load raw music stem
        [raw_noise, fs_n] = audioread(noise_files.(genre));
        if fs_n ~= fs, raw_noise = resample(raw_noise, fs, fs_n); end
        
        % Convolve noise through Stage PA RIRs once
        music_mic1_full = filter(h_n1, 1, raw_noise);
        music_mic2_full = filter(h_n2, 1, raw_noise);
        
        % Get genre-specific fixed filters
        b_fir = filters_fir.(genre).b;
        sos_notch = filters_notch.(genre).sos;
        
        for snr_idx = 1:length(snr_levels)
            target_snr = snr_levels(snr_idx);
            
            % Accumulator for summary [STOI, PESQ, dSNR, dASL] across 20 talkers for 6 filters
            % Dimensions: 6 filters x 4 metrics
            cond_metrics = zeros(6, 4);
            
            for s_idx = 1:length(speech_manifest)
                spk = speech_manifest{s_idx};
                
                % Load speech
                [clean_speech, fs_s] = audioread(spk.path);
                if fs_s ~= fs, clean_speech = resample(clean_speech, fs, fs_s); end
                
                L = length(clean_speech);
                if L > 16000 * 5 % Cap to 5 seconds for simulation throughput
                    L = 16000 * 5;
                    clean_speech = clean_speech(1:L);
                end
                
                % Convolve speech through near-field vocal RIRs
                % Primary mic: forward direct sound + early reflections
                s1_rev = filter(h_s1, 1, clean_speech);
                
                % Reference mic: rear-facing, incorporates 12 dB head shadowing attenuation
                % modeled as 0.25 amplitude factor + RIR path
                s2_rev = 0.25 * filter(h_s2, 1, clean_speech);
                
                % Loop/slice music to match speech length
                if length(music_mic1_full) < L
                    reps = ceil(L / length(music_mic1_full));
                    n1_seg = repmat(music_mic1_full, reps, 1);
                    n2_seg = repmat(music_mic2_full, reps, 1);
                else
                    n1_seg = music_mic1_full(1:L);
                    n2_seg = music_mic2_full(1:L);
                end
                n1_seg = n1_seg(1:L);
                n2_seg = n2_seg(1:L);
                
                % Power leveling to Target SNR based on active speech level of primary
                [asl_s1, ~] = calculate_active_speech_level(s1_rev, fs);
                p_s1 = 10^(asl_s1 / 10);
                p_n1 = mean(n1_seg.^2);
                
                if p_n1 < 1e-12, p_n1 = 1e-12; end
                scale = sqrt(p_s1 / (p_n1 * 10^(target_snr / 10)));
                
                scaled_n1 = n1_seg * scale;
                scaled_n2 = n2_seg * scale;
                
                % Microphone Signals
                d_raw = s1_rev + scaled_n1;
                x_raw = s2_rev + scaled_n2;
                
                % Headroom peak normalization (0.90 max peak)
                peak_val = max(abs(d_raw));
                if peak_val < 1e-6, peak_val = 1.0; end
                norm_gain = 0.90 / peak_val;
                
                d = d_raw * norm_gain;
                x = x_raw * norm_gain;
                s_ref = s1_rev * norm_gain;
                n_ref = scaled_n1 * norm_gain;
                
                % Active Speech Level of primary input
                [asl_d, ~] = calculate_active_speech_level(d, fs);
                
                % ----------------- FILTER PROCESSING -----------------
                % Filter 1: Unprocessed Primary
                e{1} = d;
                
                % Filter 2: Fixed 128-Tap Windowed-Sinc FIR Bandpass
                e{2} = filter(b_fir, 1, d);
                
                % Filter 3: Parametric Notch Cascade
                e{3} = sosfilt(sos_notch, d);
                
                % Filter 4: Baseline Dual-Mic NLMS
                [e{4}, ~] = nlms_filter(d, x, N_nlms, mu_nlms, eps_nlms);
                
                % Filter 5: Leaky NLMS (gamma = 0.999)
                [e{5}, ~] = nlms_leaky_filter(d, x, N_nlms, mu_nlms, eps_nlms, gamma_leaky, zeros(L, 1));
                
                % Filter 6: Soft-VAD Leaky NLMS
                [~, vad_soft] = compute_robust_vad(d, x, fs, vad_prm);
                [e{6}, ~] = nlms_leaky_filter(d, x, N_nlms, mu_nlms, eps_nlms, gamma_leaky, vad_soft);
                
                % ----------------- METRIC EVALUATION -----------------
                snr_in_linear = mean(s_ref.^2) / (mean(n_ref.^2) + 1e-12);
                snr_in_dB = 10 * log10(snr_in_linear + 1e-12);
                
                for f = 1:6
                    filt_name = filter_names{f};
                    out_sig = e{f};
                    
                    % 1. STOI
                    stoi_val = calculate_stoi(s_ref, out_sig, fs);
                    
                    % 2. PESQ / PSQS
                    pesq_val = calculate_pesq_metric(s_ref, out_sig, fs);
                    
                    % 3. Active Speech Level Delta
                    [asl_out, ~] = calculate_active_speech_level(out_sig, fs);
                    d_asl = asl_out - asl_d;
                    
                    % 4. Physical Delta SNR
                    % For linear/adaptive output, estimate residual noise during inactive speech
                    noise_res = out_sig - s_ref;
                    snr_out_linear = mean(s_ref.^2) / (mean(noise_res.^2) + 1e-12);
                    d_snr = 10 * log10(snr_out_linear + 1e-12) - snr_in_dB;
                    
                    % Bounded delta SNR
                    d_snr = max(min(d_snr, 30.0), -10.0);
                    
                    % Accumulate
                    cond_metrics(f, 1) = cond_metrics(f, 1) + stoi_val;
                    cond_metrics(f, 2) = cond_metrics(f, 2) + pesq_val;
                    cond_metrics(f, 3) = cond_metrics(f, 3) + d_snr;
                    cond_metrics(f, 4) = cond_metrics(f, 4) + d_asl;
                    
                    % Write individual file row to CSV
                    fprintf(fid_res, '%s,%s,%s,%s,%d,%s,%.4f,%.3f,%.2f,%.2f\n', ...
                        v_key, genre, spk.name, spk.gender, target_snr, filt_name, stoi_val, pesq_val, d_snr, d_asl);
                end
                
                % Save audio demonstration files for select representative conditions
                if s_idx == 1 && (target_snr == -10 || target_snr == 0) && sample_export_count < 6
                    sample_export_count = sample_export_count + 1;
                    sub_prefix = sprintf('%s_%s_snr%d', v_key, genre, target_snr);
                    audiowrite(fullfile(sample_dir, [sub_prefix '_01_primary_noisy.wav']), d / max(abs(d)+1e-4) * 0.9, fs);
                    audiowrite(fullfile(sample_dir, [sub_prefix '_02_fir_bp.wav']), e{2} / max(abs(e{2})+1e-4) * 0.9, fs);
                    audiowrite(fullfile(sample_dir, [sub_prefix '_03_notch.wav']), e{3} / max(abs(e{3})+1e-4) * 0.9, fs);
                    audiowrite(fullfile(sample_dir, [sub_prefix '_04_base_nlms.wav']), e{4} / max(abs(e{4})+1e-4) * 0.9, fs);
                    audiowrite(fullfile(sample_dir, [sub_prefix '_05_soft_vad_leaky.wav']), e{6} / max(abs(e{6})+1e-4) * 0.9, fs);
                end
            end
            
            % Average across talkers
            cond_metrics = cond_metrics / length(speech_manifest);
            
            % Write to summary CSV and print to terminal
            for f = 1:6
                fprintf(fid_sum, '%s,%s,%d,%s,%.4f,%.3f,%.2f,%.2f\n', ...
                    v_key, genre, target_snr, filter_names{f}, ...
                    cond_metrics(f, 1), cond_metrics(f, 2), cond_metrics(f, 3), cond_metrics(f, 4));
            end
            
            fprintf('  [%s | %-6s | SNR: %3d dB]  STOI: Unproc=%.3f | FIR=%.3f | Notch=%.3f | Base=%.3f | Leaky=%.3f | SoftVAD=%.3f\n', ...
                v_key(1:min(4,length(v_key))), genre, target_snr, ...
                cond_metrics(1, 1), cond_metrics(2, 1), cond_metrics(3, 1), ...
                cond_metrics(4, 1), cond_metrics(5, 1), cond_metrics(6, 1));
            fprintf('                               PESQ: Unproc=%.2f | FIR=%.2f | Notch=%.2f | Base=%.2f | Leaky=%.2f | SoftVAD=%.2f\n', ...
                cond_metrics(1, 2), cond_metrics(2, 2), cond_metrics(3, 2), ...
                cond_metrics(4, 2), cond_metrics(5, 2), cond_metrics(6, 2));
        end
    end
end

fclose(fid_res);
fclose(fid_sum);

fprintf('\n========================================================================\n');
fprintf('  CONCERT VENUE ROOM EXPERIMENT COMPLETE!\n');
fprintf('  Results saved to: %s\n', results_csv);
fprintf('  Summary saved to: %s\n', summary_csv);
fprintf('  Audio snippets exported to: %s\n', sample_dir);
fprintf('========================================================================\n');
