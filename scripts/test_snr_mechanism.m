% Diagnostic script to audit filter outputs
cd('/Users/macairm1/Documents/antigravity/blissful-bose');
load('dataset/metadata/filter_comparison_workspace.mat');
disp('=== TESTING FILTER OUTPUTS ON TECHNO NOISE ===');

% Load 1 speech and 1 techno noise
s_file = dir('dataset/speech_corpus/combined/*.wav');
[speech, fs] = audioread(fullfile('dataset/speech_corpus/combined', s_file(1).name));
[noise, ~] = audioread('dataset/test_stimuli/music_noise_30s/techno_noise_30s.wav');

L = length(speech);
noise_seg = noise(1:L);

% Scale noise to -10 dB SNR
p_s = mean(speech.^2);
p_n = mean(noise_seg.^2);
scale = sqrt(p_s / (p_n * 10^(-10/10)));
scaled_noise = noise_seg * scale;
noisy_mix = speech + scaled_noise;

% Filter with Techno Notch
filt_speech_notch = sosfilt(filters_notch.techno.sos, speech);
filt_noise_notch  = sosfilt(filters_notch.techno.sos, scaled_noise);
filt_mix_notch    = sosfilt(filters_notch.techno.sos, noisy_mix);

% Filter with Techno Bandpass
filt_speech_bp = sosfilt(filters_iir.techno.sos, speech) * filters_iir.techno.g;
filt_noise_bp  = sosfilt(filters_iir.techno.sos, scaled_noise) * filters_iir.techno.g;
filt_mix_bp    = sosfilt(filters_iir.techno.sos, noisy_mix) * filters_iir.techno.g;

fprintf('Input SNR: %.2f dB\n', 10*log10(mean(speech.^2) / mean(scaled_noise.^2)));

% True SNR out
snr_out_notch = 10*log10(mean(filt_speech_notch.^2) / mean(filt_noise_notch.^2));
snr_out_bp    = 10*log10(mean(filt_speech_bp.^2) / mean(filt_noise_bp.^2));

fprintf('NOTCH: Speech Power: %.6f -> %.6f (Speech Change: %+.2f dB)\n', ...
    mean(speech.^2), mean(filt_speech_notch.^2), 10*log10(mean(filt_speech_notch.^2)/mean(speech.^2)));
fprintf('NOTCH: Noise Power:  %.6f -> %.6f (Noise Attenuation: %+.2f dB)\n', ...
    mean(scaled_noise.^2), mean(filt_noise_notch.^2), 10*log10(mean(scaled_noise.^2)/mean(filt_noise_notch.^2)));
fprintf('NOTCH: Output SNR: %.2f dB -> True Delta SNR: %+.2f dB\n', snr_out_notch, snr_out_notch - (-10));

fprintf('\nBANDPASS: Speech Power: %.6f -> %.6f (Speech Change: %+.2f dB)\n', ...
    mean(speech.^2), mean(filt_speech_bp.^2), 10*log10(mean(filt_speech_bp.^2)/mean(speech.^2)));
fprintf('BANDPASS: Noise Power:  %.6f -> %.6f (Noise Attenuation: %+.2f dB)\n', ...
    mean(scaled_noise.^2), mean(filt_noise_bp.^2), 10*log10(mean(scaled_noise.^2)/mean(filt_noise_bp.^2)));
fprintf('BANDPASS: Output SNR: %.2f dB -> True Delta SNR: %+.2f dB\n', snr_out_bp, snr_out_bp - (-10));

% Compare with flawed residual subtraction formula
flawed_noise_notch = filt_mix_notch - speech;
fprintf('\nFLAWED subtraction formula (filt_mix - clean_speech):\n');
fprintf('  Flawed Noise Power: %.6f (Orig Noise was: %.6f)\n', mean(flawed_noise_notch.^2), mean(scaled_noise.^2));
fprintf('  Flawed Delta SNR:   %+.2f dB\n', ...
    10*log10(mean(speech.^2)/mean(flawed_noise_notch.^2)) - (-10));
