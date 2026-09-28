% generate_multi_sentence_stt_samples.m
% Generates room-acoustic audition audio files for multi-sentence Google STT evaluation
% Evaluates across 3 Genres (Jazz, Rock, Techno) at -15 dB, -10 dB, and 0 dB SNR
% for 3 distinct Harvard sentences across Male and Female talkers.

clear; clc;
fprintf('========================================================================\n');
fprintf('  GENERATING MULTI-SENTENCE ROOM ACOUSTIC SAMPLES FOR GOOGLE STT EVAL   \n');
fprintf('========================================================================\n\n');

fs = 16000;
N_nlms = 256;
mu_nlms = 0.05;
eps_nlms = 1e-2;
gamma_leaky = 0.999;
vad_prm = struct('frame_len_ms', 20, 'alpha_ema', 0.9, 'zcr_thresh', 0.05);

% Paths
script_dir = fileparts(mfilename('fullpath'));
if isempty(script_dir), script_dir = pwd; end
addpath(fullfile(script_dir, '..', 'lib'));

repo_root = fullfile(script_dir, '..', '..');
dataset_dir = fullfile(repo_root, 'dataset');
metadata_dir = fullfile(dataset_dir, 'metadata');
speech_corpus_dir = fullfile(dataset_dir, 'speech_corpus');
test_stimuli_dir = fullfile(dataset_dir, 'test_stimuli', 'speech_sentences');

output_dir = fullfile(script_dir, '..', 'output_audio', 'room_experiment');
sample_dir = fullfile(output_dir, 'samples_multi_sentence');
if ~exist(output_dir, 'dir'), mkdir(output_dir); end
if ~exist(sample_dir, 'dir'), mkdir(sample_dir); end

% Load Filter Workspace
ws_file = fullfile(metadata_dir, 'filter_comparison_workspace.mat');
ws = load(ws_file);
filters_fir = ws.filters_fir;
filters_notch = ws.filters_notch;

% Club Venue Acoustic Geometry
venue_dim  = [12.0, 15.0, 4.0];
rt60       = 0.70;
speech_pos = [6.0, 8.65, 1.6]; % Near-field talker (0.35m from Mic 1)
mic1_pos   = [6.0, 9.00, 1.6]; % Primary mic (front)
mic2_pos   = [6.0, 9.04, 1.6]; % Reference mic (rear, 4cm spacing)
pa_left    = [2.0, 1.00, 2.5]; % Stage PA Left
pa_right   = [10.0, 1.00, 2.5];% Stage PA Right

max_rir_sec = 0.45;
fprintf('--> Precomputing Club Room Impulse Responses (RT60 = 0.70s)...\n');
[h_s1, ~] = simulate_room_impulse_response(venue_dim, speech_pos, mic1_pos, rt60, fs, max_rir_sec);
[h_s2, ~] = simulate_room_impulse_response(venue_dim, speech_pos, mic2_pos, rt60, fs, max_rir_sec);
[h_paL1, ~] = simulate_room_impulse_response(venue_dim, pa_left, mic1_pos, rt60, fs, max_rir_sec);
[h_paR1, ~] = simulate_room_impulse_response(venue_dim, pa_right, mic1_pos, rt60, fs, max_rir_sec);
[h_paL2, ~] = simulate_room_impulse_response(venue_dim, pa_left, mic2_pos, rt60, fs, max_rir_sec);
[h_paR2, ~] = simulate_room_impulse_response(venue_dim, pa_right, mic2_pos, rt60, fs, max_rir_sec);

h_n1 = 0.5 * (h_paL1 + h_paR1);
h_n2 = 0.5 * (h_paL2 + h_paR2);

% Sentences Definition (3 diverse sentences across Male & Female)
sentences = { ...
    struct('id', 'sent01', 'file', fullfile(speech_corpus_dir, 'female', 'female_01_IUS-F00202.wav'), ...
           'gender', 'female', 'text', 'The bill was paid every third week'), ...
    struct('id', 'sent02', 'file', fullfile(speech_corpus_dir, 'male', 'male_02_IUS-M02201.wav'), ...
           'gender', 'male', 'text', 'Glue the sheet to the dark blue background'), ...
    struct('id', 'sent03', 'file', fullfile(speech_corpus_dir, 'female', 'female_03_IUS-F04202.wav'), ...
           'gender', 'female', 'text', 'These days a chicken leg is a rare dish') ...
};

% Noise Files
noise_files = struct();
noise_files.techno = fullfile(dataset_dir, 'wav_16k', 'techno', 'techno_1389887.wav');
noise_files.jazz   = fullfile(dataset_dir, 'wav_16k', 'jazz', 'jazz_01_jazz.00016.wav');
noise_files.rock   = fullfile(dataset_dir, 'wav_16k', 'rock', 'rock_01_rock.00011.wav');

genres = {'jazz', 'rock', 'techno'};
snr_levels = [-15, -10, 0]; % Including -15 dB as requested!

manifest_file = fullfile(sample_dir, 'manifest.json');
manifest_items = {};

total_exported = 0;

for g_idx = 1:length(genres)
    genre = genres{g_idx};
    
    [raw_noise, fs_n] = audioread(noise_files.(genre));
    if fs_n ~= fs, raw_noise = resample(raw_noise, fs, fs_n); end
    
    music_mic1_full = filter(h_n1, 1, raw_noise);
    music_mic2_full = filter(h_n2, 1, raw_noise);
    
    b_fir = filters_fir.(genre).b;
    sos_notch = filters_notch.(genre).sos;
    
    for snr_idx = 1:length(snr_levels)
        target_snr = snr_levels(snr_idx);
        
        for s_idx = 1:length(sentences)
            sent = sentences{s_idx};
            
            [clean_speech, fs_s] = audioread(sent.file);
            if fs_s ~= fs, clean_speech = resample(clean_speech, fs, fs_s); end
            
            L = length(clean_speech);
            if L > 16000 * 5, L = 16000 * 5; clean_speech = clean_speech(1:L); end
            
            s1_rev = filter(h_s1, 1, clean_speech);
            s2_rev = 0.25 * filter(h_s2, 1, clean_speech);
            
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
            
            [asl_s1, ~] = calculate_active_speech_level(s1_rev, fs);
            p_s1 = 10^(asl_s1 / 10);
            p_n1 = mean(n1_seg.^2);
            if p_n1 < 1e-12, p_n1 = 1e-12; end
            scale = sqrt(p_s1 / (p_n1 * 10^(target_snr / 10)));
            
            scaled_n1 = n1_seg * scale;
            scaled_n2 = n2_seg * scale;
            
            d_raw = s1_rev + scaled_n1;
            x_raw = s2_rev + scaled_n2;
            
            peak_val = max(abs(d_raw));
            if peak_val < 1e-6, peak_val = 1.0; end
            norm_gain = 0.90 / peak_val;
            
            d = d_raw * norm_gain;
            x = x_raw * norm_gain;
            
            % Filters
            e1 = d;
            e2 = filter(b_fir, 1, d);
            e3 = sosfilt(sos_notch, d);
            [e4, ~] = nlms_filter(d, x, N_nlms, mu_nlms, eps_nlms);
            [~, vad_soft] = compute_robust_vad(d, x, fs, vad_prm);
            [e5, ~] = nlms_leaky_filter(d, x, N_nlms, mu_nlms, eps_nlms, gamma_leaky, vad_soft);
            
            % Normalize audio before writing
            e_list = {e1, e2, e3, e4, e5};
            suffix_list = {'01_primary_noisy.wav', '02_fir_bp.wav', '03_notch.wav', '04_base_nlms.wav', '05_soft_vad_leaky.wav'};
            filter_labels = {'primary_noisy', 'fir_bp', 'notch', 'base_nlms', 'soft_vad_leaky'};
            
            base_fname = sprintf('club_%s_snr%d_%s', genre, target_snr, sent.id);
            
            for k = 1:5
                out_wav = fullfile(sample_dir, [base_fname '_' suffix_list{k}]);
                wav_sig = e_list{k};
                max_p = max(abs(wav_sig));
                if max_p > 1e-4, wav_sig = wav_sig / max_p * 0.90; end
                audiowrite(out_wav, wav_sig, fs);
                total_exported = total_exported + 1;
            end
            
            fprintf('  Exported 5 audio files for [%s | %s | SNR %3d dB | %s]\n', ...
                genre, sent.id, target_snr, sent.text);
        end
    end
end

fprintf('\nDone! Successfully generated %d audio files in:\n%s\n', total_exported, sample_dir);
