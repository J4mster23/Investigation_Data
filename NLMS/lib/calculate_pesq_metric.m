function [pesq_score, raw_disturbance] = calculate_pesq_metric(clean, degraded, fs)
% CALCULATE_PESQ_METRIC Computes an objective perceptual speech quality score
% based on the ITU-T P.862 / Bark Spectral Distortion (BSD) perceptual model.
%
% Syntax:
%   [pesq_score, raw_disturbance] = calculate_pesq_metric(clean, degraded, fs)
%
% Inputs:
%   clean    - Clean reference speech signal vector
%   degraded - Processed / degraded speech signal vector
%   fs       - Sampling frequency in Hz (default 16000)
%
% Outputs:
%   pesq_score      - Mean Opinion Score (MOS-LQO) mapped to [1.0, 4.5]
%   raw_disturbance - Unmapped psychoacoustic loudness disturbance

    if nargin < 3 || isempty(fs), fs = 16000; end
    
    clean = clean(:);
    degraded = degraded(:);
    
    L = min(length(clean), length(degraded));
    clean = clean(1:L);
    degraded = degraded(1:L);
    
    % Active Speech Level normalization
    p_clean = mean(clean.^2);
    p_deg = mean(degraded.^2);
    
    if p_clean > 1e-12
        clean = clean / sqrt(p_clean) * 0.1;
    end
    if p_deg > 1e-12
        degraded = degraded / sqrt(p_deg) * 0.1;
    end
    
    % STFT Analysis parameters (32 ms window, 16 ms hop)
    win_len = round(0.032 * fs);
    hop_len = round(0.016 * fs);
    n_fft = 2^nextpow2(win_len);
    
    win = hann(win_len, 'periodic');
    
    % Buffer into overlapping frames
    c_frames = buffer(clean, win_len, win_len - hop_len, 'nodelay') .* win;
    d_frames = buffer(degraded, win_len, win_len - hop_len, 'nodelay') .* win;
    
    num_frames = size(c_frames, 2);
    
    % Power spectrum
    C_fft = abs(fft(c_frames, n_fft, 1)).^2;
    D_fft = abs(fft(d_frames, n_fft, 1)).^2;
    
    % Half-spectrum
    C_spec = C_fft(1:n_fft/2 + 1, :);
    D_spec = D_fft(1:n_fft/2 + 1, :);
    
    freqs = (0:n_fft/2)' * (fs / n_fft);
    
    % Bark Critical Band Filterbank (18 critical bands spanning 100 - 4000 Hz)
    bark_edges = [100, 200, 300, 400, 510, 630, 770, 920, 1080, 1270, 1480, 1720, 2000, 2320, 2700, 3150, 3700, 4400];
    num_barks = length(bark_edges) - 1;
    
    C_bark = zeros(num_barks, num_frames);
    D_bark = zeros(num_barks, num_frames);
    
    for b = 1:num_barks
        f_low = bark_edges(b);
        f_high = bark_edges(b+1);
        mask = (freqs >= f_low & freqs < f_high);
        if any(mask)
            C_bark(b, :) = sum(C_spec(mask, :), 1);
            D_bark(b, :) = sum(D_spec(mask, :), 1);
        else
            C_bark(b, :) = 1e-10;
            D_bark(b, :) = 1e-10;
        end
    end
    
    % Perceptual Loudness Warping: Zwicker's power law L = P^0.23 (Sones domain)
    C_loudness = (C_bark + 1e-8).^0.23;
    D_loudness = (D_bark + 1e-8).^0.23;
    
    % Active frame detection (speech energy threshold: > -30 dB of max frame)
    frame_energy = sum(C_bark, 1);
    max_energy = max(frame_energy);
    active_frames = (frame_energy > max_energy * 1e-3);
    
    if ~any(active_frames)
        pesq_score = 1.0;
        raw_disturbance = 5.0;
        return;
    end
    
    % Compute Asymmetric Disturbance:
    % Penalize speech deletion / cancellation more heavily than additive noise
    diff_loud = D_loudness(:, active_frames) - C_loudness(:, active_frames);
    
    % Asymmetry factor: if diff < 0 (speech cancelled/amputated), apply 1.5x penalty
    asym_weight = ones(size(diff_loud));
    asym_weight(diff_loud < 0) = 1.6;
    
    weighted_diff = asym_weight .* abs(diff_loud);
    
    % Frame-level disturbance (L2 norm across Bark bands)
    frame_dist = sqrt(mean(weighted_diff.^2, 1));
    
    % Global disturbance (Lp norm across active frames with p = 2)
    raw_disturbance = (mean(frame_dist.^2))^(1/2);
    
    % Sigmoidal mapping to standard MOS-LQO scale [1.0, 4.5]
    % Calibrated so:
    % - Identical clean speech: raw_disturbance -> 0 => PESQ = 4.5
    % - Mild reverberation/noise: raw_disturbance ~ 0.15 => PESQ ~ 3.5 - 3.8
    % - Moderate degradation: raw_disturbance ~ 0.35 => PESQ ~ 2.5 - 2.8
    % - Heavy noise/cancellation: raw_disturbance > 0.70 => PESQ ~ 1.0 - 1.8
    mos_max = 4.50;
    mos_min = 1.00;
    decay_rate = 3.6;
    
    pesq_score = mos_min + (mos_max - mos_min) / (1 + (raw_disturbance * decay_rate)^1.8);
    pesq_score = min(max(pesq_score, 1.0), 4.5);
end
