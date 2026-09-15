function [vad_hard, vad_soft] = compute_robust_vad(d, x, fs, prm)
% COMPUTE_ROBUST_VAD Computes a Voice Activity Detection (VAD) mask for dual-mic setups.
%
%   [vad_hard, vad_soft] = compute_robust_vad(d, x, fs)
%   [vad_hard, vad_soft] = compute_robust_vad(d, x, fs, prm)
%
% Inputs:
%   d   - Primary microphone signal (Speech + Noise)
%   x   - Reference microphone signal (Noise)
%   fs  - Sampling frequency (Hz)
%   prm - Optional struct with parameters:
%         .frame_len_ms : Frame length in ms (default 20)
%         .alpha_ema    : Exponential Moving Average factor (default 0.9)
%         .zcr_thresh   : Zero-crossing rate lower bound (default 0.05)
%
% Outputs:
%   vad_hard - Binary mask (logical) same length as d (1 = speech, 0 = noise)
%   vad_soft - Continuous mask [0, 1] same length as d (Speech probability)

    if nargin < 4
        prm = struct();
    end
    if ~isfield(prm, 'frame_len_ms'), prm.frame_len_ms = 20; end
    if ~isfield(prm, 'alpha_ema'), prm.alpha_ema = 0.9; end
    if ~isfield(prm, 'zcr_thresh'), prm.zcr_thresh = 0.05; end

    % Ensure column vectors
    d = d(:);
    x = x(:);
    L = length(d);
    
    frame_len = round((prm.frame_len_ms / 1000) * fs);
    num_frames = floor(L / frame_len);
    
    % Pad if needed
    len_padded = num_frames * frame_len;
    d_frames = reshape(d(1:len_padded), frame_len, num_frames);
    x_frames = reshape(x(1:len_padded), frame_len, num_frames);
    
    % 1. Compute Frame Powers
    P_d = mean(d_frames.^2, 1);
    P_x = mean(x_frames.^2, 1);
    
    % 2. Power Ratio
    ratio = P_d ./ (P_x + 1e-8);
    
    % Convert to dB for easier thresholding/mapping
    ratio_db = 10 * log10(ratio + 1e-8);
    
    % 3. Zero-Crossing Rate (Secondary Check)
    zcr = sum(abs(diff(sign(d_frames))) > 0, 1) / (frame_len - 1);
    
    % Initialize smoothed ratio
    smoothed_ratio = zeros(1, num_frames);
    curr_val = ratio_db(1);
    
    for i = 1:num_frames
        % Apply EMA
        curr_val = prm.alpha_ema * curr_val + (1 - prm.alpha_ema) * ratio_db(i);
        smoothed_ratio(i) = curr_val;
        
        % Penalize if ZCR is too low (likely wind or mic bump, not speech)
        if zcr(i) < prm.zcr_thresh
            smoothed_ratio(i) = smoothed_ratio(i) - 10; % drop by 10 dB
        end
    end
    
    % 4. Soft Mapping
    % Map smoothed_ratio (in dB) to [0, 1] using a sigmoid function
    % Speech typically has primary > ref by a few dB. 
    % Let 0 dB be the center point.
    center_db = 2.0; % 2 dB above noise level is 50% probability
    slope = 0.5;
    vad_soft_frames = 1 ./ (1 + exp(-slope * (smoothed_ratio - center_db)));
    
    % 5. Hard Mask
    vad_hard_frames = vad_soft_frames > 0.5;
    
    % Expand frame-level VAD to sample-level VAD (Zero-Order Hold)
    vad_soft = repelem(vad_soft_frames, frame_len)';
    vad_hard = repelem(vad_hard_frames, frame_len)';
    
    % Handle remaining samples
    rem_samples = L - len_padded;
    if rem_samples > 0
        vad_soft = [vad_soft; ones(rem_samples, 1) * vad_soft(end)];
        vad_hard = [vad_hard; ones(rem_samples, 1) * vad_hard(end)];
    end
end
