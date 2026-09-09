function [active_level, activity_factor] = calculate_active_speech_level(speech, fs)
% CALCULATE_ACTIVE_SPEECH_LEVEL Computes the active speech level.
%   [active_level, activity_factor] = calculate_active_speech_level(speech, fs)
%   Estimates the active speech level (in dBFS) by using an envelope-based
%   threshold approach (simplified alternative to ITU-T P.56).

    speech = speech(:);
    
    % Use exactly 320 samples (20ms at 16kHz) as per Python script
    frame_len = 320; 
    num_frames = floor(length(speech) / frame_len);
    
    if num_frames == 0
        active_level = -Inf;
        activity_factor = 0;
        return;
    end
    
    % Reshape into frames
    frames = reshape(speech(1:num_frames*frame_len), frame_len, num_frames);
    
    % Compute RMS power per frame
    frame_pwr = mean(frames.^2, 1);
    
    % Peak power for thresholding
    max_pwr = max(frame_pwr);
    if max_pwr == 0
        active_level = -Inf;
        activity_factor = 0;
        return;
    end
    
    % Set threshold to 25 dB below the peak frame power (matching python)
    threshold = max_pwr * (10^(-25/10));
    
    % Find active frames
    active_idx = frame_pwr > threshold;
    activity_factor = sum(active_idx) / num_frames;
    
    if activity_factor > 0
        mean_active_pwr = mean(frame_pwr(active_idx));
        active_level = 10 * log10(mean_active_pwr + eps);
    else
        active_level = -Inf;
    end
end
