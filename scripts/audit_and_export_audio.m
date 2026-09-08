% scripts/audit_and_export_audio.m
% Generates pre-filtered and post-filtered audio files for auditing
% Compares FIR Bandpass, IIR Bandpass, and Parametric Notch across Jazz, Rock, Techno

cd('/Users/macairm1/Documents/antigravity/blissful-bose');
ws = load('dataset/metadata/filter_comparison_workspace.mat');
filters_fir   = ws.filters_fir;
filters_iir   = ws.filters_iir;
filters_notch = ws.filters_notch;

output_dir = 'dataset/test_stimuli/audit_filtered_audio';
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

% Pick 1 male and 1 female sentence
m_files = dir('dataset/speech_corpus/male/*.wav');
f_files = dir('dataset/speech_corpus/female/*.wav');

% Example speech: female_01 (clear, high articulation)
speech_file = fullfile('dataset/speech_corpus/female', f_files(1).name);
[clean_speech, fs] = audioread(speech_file);
fprintf('Audit Speech File: %s (L = %d samples, %.2f s, fs = %d Hz)\n', ...
    f_files(1).name, length(clean_speech), length(clean_speech)/fs, fs);

genres = {'jazz', 'rock', 'techno'};
target_snr = -5; % -5 dB SNR for clear auditing

fprintf('\n=========================================================================================\n');
fprintf('  AUDITING PRE & POST FILTERED AUDIO (Input SNR = %d dB)\n', target_snr);
fprintf('=========================================================================================\n');

for g = 1:length(genres)
    gk = genres{g};
    noise_file = sprintf('dataset/test_stimuli/music_noise_30s/%s_noise_30s.wav', gk);
    [noise_raw, ~] = audioread(noise_file);
    
    L = length(clean_speech);
    noise_seg = noise_raw(1000 : 1000 + L - 1);
    
    % Active Speech Leveling (ITU-T P.56 frame-based)
    frame_len = 320;
    n_frames = floor(L / frame_len);
    frame_powers = zeros(n_frames, 1);
    for f = 1:n_frames
        frm = clean_speech((f-1)*frame_len + 1 : f*frame_len);
        frame_powers(f) = mean(frm.^2);
    end
    peak_p = max(frame_powers);
    active_idx = frame_powers > (peak_p * 10^(-25/10));
    if any(active_idx)
        p_speech_active = mean(frame_powers(active_idx));
    else
        p_speech_active = mean(clean_speech.^2);
    end
    
    p_noise = mean(noise_seg.^2);
    scale = sqrt(p_speech_active / (p_noise * 10^(target_snr / 10)));
    scaled_noise = noise_seg * scale;
    
    noisy_input = clean_speech + scaled_noise;
    
    % Scale to 0.90 peak headroom to prevent clipping
    max_val = max(abs(noisy_input));
    if max_val > 0.90
        norm_factor = 0.90 / max_val;
        noisy_input  = noisy_input * norm_factor;
        clean_speech_scaled = clean_speech * norm_factor;
        scaled_noise = scaled_noise * norm_factor;
    else
        norm_factor = 1.0;
        clean_speech_scaled = clean_speech;
    end
    
    % 1. Save PRE-FILTERED file
    pre_path = fullfile(output_dir, sprintf('%s_pre_filtered_snr%ddb.wav', gk, abs(target_snr)));
    audiowrite(pre_path, noisy_input, fs);
    
    % 2. Filter with 128-Tap FIR Bandpass
    out_fir = filter(filters_fir.(gk).b, 1, noisy_input);
    % Prevent clipping on filter resonance
    if max(abs(out_fir)) > 0.95
        out_fir = out_fir * (0.95 / max(abs(out_fir)));
    end
    post_fir_path = fullfile(output_dir, sprintf('%s_post_filtered_fir_bp.wav', gk));
    audiowrite(post_fir_path, out_fir, fs);
    
    % 3. Filter with 8th-Order Chebyshev II IIR Bandpass
    out_iir = sosfilt(filters_iir.(gk).sos, noisy_input) * filters_iir.(gk).g;
    if max(abs(out_iir)) > 0.95
        out_iir = out_iir * (0.95 / max(abs(out_iir)));
    end
    post_iir_path = fullfile(output_dir, sprintf('%s_post_filtered_iir_bp.wav', gk));
    audiowrite(post_iir_path, out_iir, fs);
    
    % 4. Filter with Parametric Notch Cascade
    out_notch = sosfilt(filters_notch.(gk).sos, noisy_input);
    if max(abs(out_notch)) > 0.95
        out_notch = out_notch * (0.95 / max(abs(out_notch)));
    end
    post_notch_path = fullfile(output_dir, sprintf('%s_post_filtered_notch.wav', gk));
    audiowrite(post_notch_path, out_notch, fs);
    
    % Verification statistics
    fprintf('--> [%s]\n', upper(gk));
    fprintf('    Pre-filtered:   Peak = %.4f | RMS = %.4f | Saved: %s\n', ...
        max(abs(noisy_input)), sqrt(mean(noisy_input.^2)), pre_path);
    fprintf('    Post-FIR BP:    Peak = %.4f | RMS = %.4f | Saved: %s\n', ...
        max(abs(out_fir)), sqrt(mean(out_fir.^2)), post_fir_path);
    fprintf('    Post-IIR BP:    Peak = %.4f | RMS = %.4f | Saved: %s\n', ...
        max(abs(out_iir)), sqrt(mean(out_iir.^2)), post_iir_path);
    fprintf('    Post-Notch:     Peak = %.4f | RMS = %.4f | Saved: %s\n', ...
        max(abs(out_notch)), sqrt(mean(out_notch.^2)), post_notch_path);
    
    % Check for any NaN or Inf
    assert(~any(isnan(noisy_input)), 'NaN in noisy input!');
    assert(~any(isnan(out_fir)), 'NaN in FIR output!');
    assert(~any(isnan(out_iir)), 'NaN in IIR output!');
    assert(~any(isnan(out_notch)), 'NaN in Notch output!');
end

fprintf('\nAll pre and post filtered audio files generated successfully without error!\n');
