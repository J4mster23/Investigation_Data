function scaled_noise = scale_noise_for_snr(speech, noise, fs, target_snr_dB)
% SCALE_NOISE_FOR_SNR Scales a noise signal to hit a precise target SNR relative to a speech signal.
%
%   scaled_noise = scale_noise_for_snr(speech, noise, fs, target_snr_dB)
%
%   Note: Apply any room impulse responses or path attenuations to the
%   noise BEFORE passing it into this function to guarantee exact SNR.

% Ensure column vectors
speech = speech(:);
noise = noise(:);

% 1. Get active speech power using your existing function
[asl_speech, ~] = calculate_active_speech_level(speech, fs);
if asl_speech == -Inf
    error('Speech signal has no active power.');
end
P_speech = 10^(asl_speech / 10);

% 2. Get robust noise power (ignoring deep silence)
frame_len = floor(0.02 * fs); % 20ms frames
num_frames = floor(length(noise) / frame_len);
frames = reshape(noise(1:num_frames*frame_len), frame_len, num_frames);

frame_pwr = mean(frames.^2, 1);
% Only measure power of frames within 30dB of the loudest frame
active_noise_frames = frame_pwr(frame_pwr > (max(frame_pwr) * 1e-3));

if isempty(active_noise_frames)
    P_noise = var(noise); % Fallback to standard variance
else
    P_noise = mean(active_noise_frames);
end

% 3. Calculate and apply scale
snr_linear = 10^(target_snr_dB / 10);
scale_factor = sqrt(P_speech / (P_noise * snr_linear));
scaled_noise = noise * scale_factor;
end