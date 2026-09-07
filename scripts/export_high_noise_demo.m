%% EXPORT_HIGH_NOISE_DEMO.M (REVISED WITH PROPER ACTIVE SPEECH MIXING & UNIFIED GAIN)
% 1. Uses Active Speech Power (frames > -25 dB of peak) to prevent silence from
%    artificially inflating the noise power (ITU-T P.56 standard practice).
% 2. Uses a UNIFIED digital gain reference:
%    Does NOT independently boost the filtered audio by +25 dB!
%    Keeps unity passband gain so the voice remains at a steady, natural level
%    while the overwhelming bass noise drops by ~40 dB.
% 3. Exports both -10 dB (realistic loud club) and -15 dB (extreme noise) for listening.

function export_high_noise_demo()
    fprintf('=========================================================================\n');
    fprintf('  CALIBRATED ACTIVE-SPEECH MIXING & UNIFIED GAIN FILTERING EXPERIMENT\n');
    fprintf('=========================================================================\n\n');

    current_script_path = mfilename('fullpath');
    [script_dir, ~, ~] = fileparts(current_script_path);
    root_dir = fileparts(script_dir);

    speech_file = fullfile(root_dir, 'dataset', 'test_stimuli', 'speech_sentences', 'sentence_01.wav');
    noise_file  = fullfile(root_dir, 'dataset', 'test_stimuli', 'music_noise_60s', 'techno_noise_60s.wav');
    output_dir  = fullfile(root_dir, 'dataset', 'test_stimuli', 'high_noise_experiment');
    workspace_mat = fullfile(root_dir, 'dataset', 'metadata', 'filter_comparison_workspace.mat');

    if ~exist(output_dir, 'dir'), mkdir(output_dir); end

    % 1. Load Audio
    [clean_speech, fs] = audioread(speech_file);
    [noise_raw, fs_n]  = audioread(noise_file);

    clean_speech = clean_speech(:);
    noise_raw    = noise_raw(:);
    L            = length(clean_speech);

    % Segment of Techno noise (driving kick groove)
    start_sample = 16000 * 5;
    noise_seg    = noise_raw(start_sample : start_sample + L - 1);

    % 2. Compute Active Speech Power (ITU-T P.56 style)
    % Break speech into 20 ms frames (320 samples at 16 kHz)
    frame_len = 320;
    n_frames = floor(L / frame_len);
    frame_powers = zeros(n_frames, 1);
    for f = 1:n_frames
        idx = (f-1)*frame_len + (1:frame_len);
        frame_powers(f) = mean(clean_speech(idx).^2);
    end
    max_p = max(frame_powers);
    % Active frames: energy within 25 dB of peak frame
    active_mask = (frame_powers > max_p * 10^(-25/10));
    p_speech_active = mean(frame_powers(active_mask));
    p_noise_total   = mean(noise_seg .^ 2);

    fprintf('Active Speech Power vs Total Mean: Active is +%.2f dB higher than naive RMS\n', ...
        10*log10(p_speech_active / mean(clean_speech.^2)));

    % 3. Load Filters
    loaded = load(workspace_mat);
    tech_iir = loaded.export_data.filters_iir.techno;
    tech_fir = loaded.export_data.filters_fir.techno;

    % Set speech reference to -20 dBFS peak headroom
    speech_scale = 0.5 / max(abs(clean_speech));
    clean_scaled = clean_speech * speech_scale;
    p_speech_active_scaled = p_speech_active * (speech_scale^2);

    % Test conditions: -10 dB (realistic loud club) and -15 dB (extreme noise)
    target_snrs = [-10, -15];

    for t = 1:length(target_snrs)
        snr_val = target_snrs(t);
        tag = sprintf('%ddB', abs(snr_val));
        
        % Scale noise based on ACTIVE speech power
        noise_scale = sqrt(p_speech_active_scaled / (p_noise_total * 10^(snr_val / 10)));
        scaled_noise = noise_seg * noise_scale;

        % Mix audio
        mixed = clean_scaled + scaled_noise;

        % Apply 8th-Order IIR Filter
        filtered_iir = sosfilt(tech_iir.sos, mixed) * tech_iir.g;

        % Apply 128-Tap FIR Filter
        filtered_fir = filter(tech_fir.b, 1, mixed);
        filtered_fir = [filtered_fir(65:end); zeros(64, 1)];

        % CRUCIAL FIX: UNIFIED GAIN REFERENCE
        % Both mixed and filtered audio share the EXACT SAME scaling factor
        % so the speech volume stays constant and the user actually hears the ~40 dB noise reduction!
        max_peak = max(abs(mixed));
        gain_master = 0.90 / max_peak;

        mixed_out = mixed * gain_master;
        iir_out   = filtered_iir * gain_master;
        fir_out   = filtered_fir * gain_master;

        f_mix = fullfile(output_dir, sprintf('calibrated_mixed_neg%s.wav', tag));
        f_iir = fullfile(output_dir, sprintf('calibrated_filtered_iir_neg%s.wav', tag));
        f_fir = fullfile(output_dir, sprintf('calibrated_filtered_fir_neg%s.wav', tag));

        audiowrite(f_mix, mixed_out, fs, 'BitsPerSample', 16);
        audiowrite(f_iir, iir_out,   fs, 'BitsPerSample', 16);
        audiowrite(f_fir, fir_out,   fs, 'BitsPerSample', 16);

        fprintf('\n--> Generated Condition [-%s SNR]:\n', tag);
        fprintf('    Mixed Audio:    %s\n', f_mix);
        fprintf('    IIR Filtered:   %s\n', f_iir);
        fprintf('    FIR Filtered:   %s\n', f_fir);
    end

    fprintf('\n=========================================================================\n');
    fprintf('  CALIBRATION COMPLETE!\n');
    fprintf('=========================================================================\n');
end
