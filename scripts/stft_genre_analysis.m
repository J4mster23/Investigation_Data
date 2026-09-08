%% STFT_GENRE_ANALYSIS.M
% Performs full STFT analysis across Jazz, Rock, and Techno datasets (150 tracks total, 50 per genre)
% and computes separate and combined active speech spectra for:
% 1. Natural Human Male Speech (50 distinct talkers, Indiana University Sentence Database)
% 2. Natural Human Female Speech (50 distinct talkers, Indiana University Sentence Database)
% 3. Combined Multi-Talker Human Speech (100 distinct talkers)
%
% Generates gender-stratified spectral overlays, masking differentials, and
% filter alignment visualizations.
%
% University of the Witwatersrand
% School of Electrical & Information Engineering

function stft_genre_analysis()
    fprintf('=========================================================================\n');
    fprintf('  FULL STFT RUN ACROSS 3 GENRES (JAZZ, ROCK, TECHNO - 150 TRACKS)\n');
    fprintf('  + MULTI-TALKER HUMAN SPEECH ANALYSIS (MALE, FEMALE, COMBINED - 100 TALKERS)\n');
    fprintf('  Sampling Rate: fs = 16 kHz | FFT: 1024-pt | Window: Hann | Overlap: 50%%\n');
    fprintf('=========================================================================\n\n');

    % 1. Path setup
    current_script_path = mfilename('fullpath');
    [script_dir, ~, ~] = fileparts(current_script_path);
    root_dir = fileparts(script_dir);
    
    wav_dir = fullfile(root_dir, 'dataset', 'wav_16k');
    corpus_dir = fullfile(root_dir, 'dataset', 'speech_corpus');
    metadata_dir = fullfile(root_dir, 'dataset', 'metadata');
    figures_dir = fullfile(root_dir, 'figures');
    
    if ~exist(metadata_dir, 'dir'), mkdir(metadata_dir); end
    if ~exist(figures_dir, 'dir'), mkdir(figures_dir); end

    genres = {'jazz', 'rock', 'techno'};
    genre_display_names = {'Jazz', 'Rock', 'Techno'};
    num_genres = length(genres);

    % 2. STFT Parameters
    fs_target = 16000;
    n_fft = 1024;
    hop_size = 512;        % 50% overlap
    win = hann(n_fft, 'periodic');
    freq_axis = (0:(n_fft/2))' * (fs_target / n_fft); % 513 points: 0 Hz to 8000 Hz
    num_freq_bins = length(freq_axis);
    
    fprintf('Frequency Resolution: %.3f Hz/bin (Total %d bins from 0 to %d Hz)\n', ...
        fs_target/n_fft, num_freq_bins, fs_target/2);

    % 3. Analyze Human Speech Corpus: Male, Female, and Combined
    fprintf('\n--> Computing Active Speech Spectra for Male, Female, and Combined Talkers...\n');
    
    speech_data = struct();
    categories = {'male', 'female', 'combined'};
    
    for c = 1:length(categories)
        cat_key = categories{c};
        cat_dir = fullfile(corpus_dir, cat_key);
        s_files = dir(fullfile(cat_dir, '*.wav'));
        n_files = length(s_files);
        
        if n_files == 0
            error('No WAV files found in %s.', cat_dir);
        end
        
        cat_pwr_matrix = zeros(num_freq_bins, n_files);
        durations = zeros(n_files, 1);
        
        for i = 1:n_files
            f_path = fullfile(cat_dir, s_files(i).name);
            [x_s, fs_s] = audioread(f_path);
            if fs_s ~= fs_target
                error('Sample rate mismatch in %s: expected %d, got %d', s_files(i).name, fs_target, fs_s);
            end
            if size(x_s, 2) > 1, x_s = mean(x_s, 2); end
            durations(i) = length(x_s) / fs_s;
            
            frames = buffer(x_s, n_fft, n_fft - hop_size, 'nodelay');
            windowed_frames = frames .* win;
            X = fft(windowed_frames, n_fft, 1);
            mag_spec = abs(X(1:num_freq_bins, :));
            
            % Active frame detection (> -25 dB of frame peak energy)
            frame_energies = sum(mag_spec .^ 2, 1);
            peak_energy = max(frame_energies);
            active_idx = frame_energies > (peak_energy * 10^(-25/10));
            
            if any(active_idx)
                cat_pwr_matrix(:, i) = mean(mag_spec(:, active_idx) .^ 2, 2);
            else
                cat_pwr_matrix(:, i) = mean(mag_spec .^ 2, 2);
            end
        end
        
        mean_pwr = mean(cat_pwr_matrix, 2);
        total_pwr = sum(mean_pwr);
        norm_pwr = mean_pwr / total_pwr;
        mean_mag = sqrt(mean_pwr);
        norm_mag = mean_mag / max(mean_mag);
        mean_mag_db = 20 * log10(norm_mag + eps);
        
        speech_data.(cat_key).n_files = n_files;
        speech_data.(cat_key).durations = durations;
        speech_data.(cat_key).mean_pwr = mean_pwr;
        speech_data.(cat_key).norm_pwr = norm_pwr;
        speech_data.(cat_key).mean_mag = mean_mag;
        speech_data.(cat_key).mean_mag_db = mean_mag_db;
        
        % Subband distribution
        sub_bass_idx = (freq_axis >= 20 & freq_axis < 80);
        low_f0_idx   = (freq_axis >= 80 & freq_axis <= 250);
        speech_idx   = (freq_axis >= 300 & freq_axis <= 3400);
        high_idx     = (freq_axis > 4000 & freq_axis <= 8000);
        
        speech_data.(cat_key).energy_sub_bass = 100 * sum(mean_pwr(sub_bass_idx)) / total_pwr;
        speech_data.(cat_key).energy_low_f0   = 100 * sum(mean_pwr(low_f0_idx)) / total_pwr;
        speech_data.(cat_key).energy_speech   = 100 * sum(mean_pwr(speech_idx)) / total_pwr;
        speech_data.(cat_key).energy_high     = 100 * sum(mean_pwr(high_idx)) / total_pwr;
        
        % Spectral Centroid and Rolloff
        speech_data.(cat_key).centroid = sum(freq_axis .* mean_pwr) / total_pwr;
        cum_pwr = cumsum(mean_pwr) / total_pwr;
        rolloff_bin = find(cum_pwr >= 0.85, 1, 'first');
        speech_data.(cat_key).rolloff_85 = freq_axis(rolloff_bin);
        
        % Pitch fundamental peak (search in 80 - 300 Hz)
        pitch_search_idx = find(freq_axis >= 80 & freq_axis <= 300);
        [~, p_max_rel] = max(mean_pwr(pitch_search_idx));
        speech_data.(cat_key).f0_peak_hz = freq_axis(pitch_search_idx(p_max_rel));
        
        fprintf('    [%s] N = %d talkers | F0 Pitch Peak = %.1f Hz | Centroid = %.1f Hz | Low F0 Energy (80-250 Hz) = %.2f%%\n', ...
            upper(cat_key), n_files, speech_data.(cat_key).f0_peak_hz, speech_data.(cat_key).centroid, speech_data.(cat_key).energy_low_f0);
    end

    % 4. Process each genre (50 tracks each = 150 tracks)
    genre_data = struct();

    for g = 1:num_genres
        genre_key = genres{g};
        genre_name = genre_display_names{g};
        genre_folder = fullfile(wav_dir, genre_key);
        
        files = dir(fullfile(genre_folder, '*.wav'));
        num_files = min(length(files), 50);
        
        if num_files == 0
            error('No WAV files found in %s.', genre_folder);
        end
        
        fprintf('\n--> Processing Genre [%s]: %d tracks from %s\n', ...
            upper(genre_key), num_files, genre_folder);
        
        track_mean_mag = zeros(num_freq_bins, num_files);
        track_names = cell(num_files, 1);
        durations = zeros(num_files, 1);
        
        tic;
        for i = 1:num_files
            track_path = fullfile(genre_folder, files(i).name);
            track_names{i} = files(i).name;
            
            [x, fs] = audioread(track_path);
            if fs ~= fs_target
                error('Sample rate mismatch for %s: expected %d, got %d', files(i).name, fs_target, fs);
            end
            
            durations(i) = length(x) / fs;
            if size(x, 2) > 1, x = mean(x, 2); end
            
            frames = buffer(x, n_fft, n_fft - hop_size, 'nodelay');
            windowed_frames = frames .* win;
            X = fft(windowed_frames, n_fft, 1);
            mag_spec = abs(X(1:num_freq_bins, :));
            track_mean_mag(:, i) = mean(mag_spec, 2);
        end
        elapsed = toc;
        fprintf('    Processed %d tracks in %.2f seconds (avg %.1f ms/track)\n', ...
            num_files, elapsed, (elapsed/num_files)*1000);
        
        mean_mag = mean(track_mean_mag, 2);
        std_mag = std(track_mean_mag, 0, 2);
        median_mag = median(track_mean_mag, 2);
        
        pwr = mean_mag .^ 2;
        total_pwr = sum(pwr);
        norm_pwr = pwr / total_pwr;
        
        norm_mean_mag = mean_mag / max(mean_mag);
        mean_mag_db = 20 * log10(norm_mean_mag + eps);
        
        genre_data.(genre_key).name = genre_name;
        genre_data.(genre_key).track_names = track_names;
        genre_data.(genre_key).durations = durations;
        genre_data.(genre_key).all_track_mean_mag = track_mean_mag;
        genre_data.(genre_key).mean_mag = mean_mag;
        genre_data.(genre_key).std_mag = std_mag;
        genre_data.(genre_key).median_mag = median_mag;
        genre_data.(genre_key).norm_mean_mag = norm_mean_mag;
        genre_data.(genre_key).mean_mag_db = mean_mag_db;
        genre_data.(genre_key).norm_pwr = norm_pwr;
        
        sub_bass_idx = (freq_axis >= 20 & freq_axis < 80);
        kick_idx = (freq_axis >= 60 & freq_axis <= 150);
        low_bass_idx = (freq_axis >= 20 & freq_axis <= 250);
        speech_idx = (freq_axis >= 300 & freq_axis <= 3400);
        mid_idx = (freq_axis >= 500 & freq_axis <= 2000);
        high_trans_idx = (freq_axis > 4000 & freq_axis <= 8000);
        
        genre_data.(genre_key).energy_sub_bass = 100 * sum(pwr(sub_bass_idx)) / total_pwr;
        genre_data.(genre_key).energy_kick = 100 * sum(pwr(kick_idx)) / total_pwr;
        genre_data.(genre_key).energy_low_bass = 100 * sum(pwr(low_bass_idx)) / total_pwr;
        genre_data.(genre_key).energy_speech = 100 * sum(pwr(speech_idx)) / total_pwr;
        genre_data.(genre_key).energy_mid = 100 * sum(pwr(mid_idx)) / total_pwr;
        genre_data.(genre_key).energy_high_trans = 100 * sum(pwr(high_trans_idx)) / total_pwr;
        
        genre_data.(genre_key).spectral_centroid = sum(freq_axis .* pwr) / total_pwr;
        cum_pwr = cumsum(pwr) / total_pwr;
        rolloff_bin = find(cum_pwr >= 0.85, 1, 'first');
        genre_data.(genre_key).spectral_rolloff_85 = freq_axis(rolloff_bin);
        
        [~, peak_bin] = max(mean_mag);
        genre_data.(genre_key).peak_freq = freq_axis(peak_bin);
        
        % Spectral SNR Differential across genders (0 dB global reference)
        genre_data.(genre_key).ssnr_male_db   = 10 * log10((speech_data.male.norm_pwr + eps) ./ (norm_pwr + eps));
        genre_data.(genre_key).ssnr_female_db = 10 * log10((speech_data.female.norm_pwr + eps) ./ (norm_pwr + eps));
        genre_data.(genre_key).ssnr_comb_db   = 10 * log10((speech_data.combined.norm_pwr + eps) ./ (norm_pwr + eps));
    end

    % 5. Summary Table Output
    fprintf('\n=========================================================================\n');
    fprintf('  SPECTRAL ENERGY DISTRIBUTION TABLE (GENRES & HUMAN SPEECH)\n');
    fprintf('=========================================================================\n');
    fprintf('%-14s | %-10s | %-12s | %-12s | %-12s | %-12s | %-10s\n', ...
        'Source', 'Peak (Hz)', 'Sub-Bass <80', 'Kick 60-150', 'LowBass <250', 'Speech Band', 'High >4kHz');
    fprintf('-----------------------------------------------------------------------------------------\n');
    for g = 1:num_genres
        gk = genres{g};
        d = genre_data.(gk);
        fprintf('%-14s | %8.1f Hz | %10.2f %% | %10.2f %% | %10.2f %% | %10.2f %% | %8.2f %%\n', ...
            d.name, d.peak_freq, d.energy_sub_bass, d.energy_kick, d.energy_low_bass, d.energy_speech, d.energy_high_trans);
    end
    fprintf('-----------------------------------------------------------------------------------------\n');
    fprintf('%-14s | %8.1f Hz | %10.2f %% | %10.2f %% | %10.2f %% | %10.2f %% | %8.2f %%\n', ...
        'Speech (Male)', speech_data.male.f0_peak_hz, speech_data.male.energy_sub_bass, speech_data.male.energy_low_f0, ...
        speech_data.male.energy_low_f0 + speech_data.male.energy_sub_bass, speech_data.male.energy_speech, speech_data.male.energy_high);
    fprintf('%-14s | %8.1f Hz | %10.2f %% | %10.2f %% | %10.2f %% | %10.2f %% | %8.2f %%\n', ...
        'Speech (Female)', speech_data.female.f0_peak_hz, speech_data.female.energy_sub_bass, speech_data.female.energy_low_f0, ...
        speech_data.female.energy_low_f0 + speech_data.female.energy_sub_bass, speech_data.female.energy_speech, speech_data.female.energy_high);
    fprintf('%-14s | %8.1f Hz | %10.2f %% | %10.2f %% | %10.2f %% | %10.2f %% | %8.2f %%\n', ...
        'Speech (Comb)', speech_data.combined.f0_peak_hz, speech_data.combined.energy_sub_bass, speech_data.combined.energy_low_f0, ...
        speech_data.combined.energy_low_f0 + speech_data.combined.energy_sub_bass, speech_data.combined.energy_speech, speech_data.combined.energy_high);
    fprintf('=========================================================================\n\n');

    % 6. Visualization Palette Setup
    fprintf('--> Generating publication-quality figures in %s...\n', figures_dir);
    set(0, 'DefaultAxesFontSize', 11);
    set(0, 'DefaultAxesFontName', 'Helvetica');
    set(0, 'DefaultLineLineWidth', 1.5);

    c_jazz   = [0.8500, 0.5500, 0.0500]; % Gold / Amber
    c_rock   = [0.6500, 0.1500, 0.7000]; % Deep Purple
    c_techno = [0.0000, 0.4500, 0.8500]; % Cobalt Blue
    
    c_male   = [0.0000, 0.4470, 0.7410]; % Blue
    c_female = [0.8500, 0.3250, 0.0980]; % Coral / Red-Orange
    c_comb   = [0.1500, 0.1500, 0.1500]; % Dark Charcoal

    % -------------------------------------------------------------------------
    % FIGURE 1: MALE VS. FEMALE VS. COMBINED NATURAL HUMAN SPEECH PROFILES
    % -------------------------------------------------------------------------
    fig1 = figure('Name', 'Male vs Female Speech Spectra', 'Position', [50, 50, 1100, 750], 'Visible', 'off');
    
    subplot(2, 1, 1);
    hold on; grid on; box on;
    patch([300, 3400, 3400, 300], [-70, -70, 5, 5], [0.93, 0.96, 0.93], 'EdgeColor', 'none', 'DisplayName', 'Formant Passband (300 - 3400 Hz)');
    plot(freq_axis, speech_data.male.mean_mag_db,   'Color', c_male,   'LineWidth', 2.0, 'DisplayName', sprintf('Male Speech (F_0 = %.1f Hz, N=50)', speech_data.male.f0_peak_hz));
    plot(freq_axis, speech_data.female.mean_mag_db, 'Color', c_female, 'LineWidth', 2.0, 'DisplayName', sprintf('Female Speech (F_0 = %.1f Hz, N=50)', speech_data.female.f0_peak_hz));
    plot(freq_axis, speech_data.combined.mean_mag_db, 'Color', c_comb, 'LineWidth', 2.4, 'DisplayName', 'Combined Human Speech (N=100 Talkers)');
    xlim([0, 8000]);
    ylim([-55, 2]);
    xlabel('Frequency (Hz)');
    ylabel('Normalized Magnitude (dB)');
    title('Natural Human Vocal Spectra: Male vs. Female vs. Combined (0 - 8000 Hz)');
    legend('Location', 'northeast');
    
    subplot(2, 1, 2);
    hold on; grid on; box on;
    patch([80, 250, 250, 80], [-55, -55, 5, 5], [0.98, 0.92, 0.92], 'EdgeColor', 'none', 'DisplayName', 'Pitch Fundamental Zone (F_0: 80 - 250 Hz)');
    plot(freq_axis, speech_data.male.mean_mag_db,   'Color', c_male,   'LineWidth', 2.2, 'DisplayName', 'Male Speech');
    plot(freq_axis, speech_data.female.mean_mag_db, 'Color', c_female, 'LineWidth', 2.2, 'DisplayName', 'Female Speech');
    plot(freq_axis, speech_data.combined.mean_mag_db, 'Color', c_comb, 'LineWidth', 2.6, 'DisplayName', 'Combined');
    
    xline(speech_data.male.f0_peak_hz, 'b--', 'LineWidth', 1.4, 'DisplayName', sprintf('Male F_0 (%.1f Hz)', speech_data.male.f0_peak_hz));
    xline(speech_data.female.f0_peak_hz, 'r--', 'LineWidth', 1.4, 'DisplayName', sprintf('Female F_0 (%.1f Hz)', speech_data.female.f0_peak_hz));
    xline(300, 'k:', 'LineWidth', 1.2, 'DisplayName', 'Broadband Bandpass Lower Cutoff (300 Hz)');
    
    text(speech_data.male.f0_peak_hz + 5, -8, sprintf('Male F_0\n%.1f Hz', speech_data.male.f0_peak_hz), 'Color', c_male, 'FontWeight', 'bold', 'FontSize', 9);
    text(speech_data.female.f0_peak_hz + 5, -4, sprintf('Female F_0\n%.1f Hz', speech_data.female.f0_peak_hz), 'Color', c_female, 'FontWeight', 'bold', 'FontSize', 9);
    
    xlim([50, 3500]);
    ylim([-45, 2]);
    xlabel('Frequency (Hz)');
    ylabel('Normalized Magnitude (dB)');
    title('Pitch Fundamental (F_0) & Formants Zoom (50 - 3500 Hz): Notice Bandpass Truncation of Male F_0');
    legend('Location', 'northeast');
    
    fig1_path = fullfile(figures_dir, 'speech_male_vs_female_spectral_profiles.png');
    saveas(fig1, fig1_path);
    close(fig1);
    fprintf('  Saved: %s\n', fig1_path);

    % -------------------------------------------------------------------------
    % FIGURE 2: GENDER-SPECIFIC SPEECH VS. GENRE OVERLAYS
    % -------------------------------------------------------------------------
    fig2 = figure('Name', 'Speech vs Genre Spectral Overlays', 'Position', [50, 50, 1150, 900], 'Visible', 'off');
    
    % Panel 1: Male Speech vs Genres
    subplot(3, 1, 1);
    hold on; grid on; box on;
    patch([300, 3400, 3400, 300], [-55, -55, 5, 5], [0.93, 0.96, 0.93], 'EdgeColor', 'none');
    plot(freq_axis, speech_data.male.mean_mag_db, 'Color', c_male, 'LineWidth', 2.4, 'DisplayName', 'Male Speech (N=50)');
    plot(freq_axis, genre_data.jazz.mean_mag_db,   'Color', c_jazz,   'LineWidth', 1.6, 'DisplayName', 'Jazz Noise');
    plot(freq_axis, genre_data.rock.mean_mag_db,   'Color', c_rock,   'LineWidth', 1.6, 'DisplayName', 'Rock Noise');
    plot(freq_axis, genre_data.techno.mean_mag_db, 'Color', c_techno, 'LineWidth', 1.6, 'DisplayName', 'Techno Noise');
    xline(speech_data.male.f0_peak_hz, 'b--', 'LineWidth', 1.2, 'DisplayName', 'Male F_0 (125 Hz)');
    xlim([0, 4000]); ylim([-50, 2]);
    ylabel('Magnitude (dB)');
    title('Male Speech Spectrum vs. Jazz, Rock, and Techno Noise (0 - 4000 Hz)');
    legend('Location', 'northeast');
    
    % Panel 2: Female Speech vs Genres
    subplot(3, 1, 2);
    hold on; grid on; box on;
    patch([300, 3400, 3400, 300], [-55, -55, 5, 5], [0.93, 0.96, 0.93], 'EdgeColor', 'none');
    plot(freq_axis, speech_data.female.mean_mag_db, 'Color', c_female, 'LineWidth', 2.4, 'DisplayName', 'Female Speech (N=50)');
    plot(freq_axis, genre_data.jazz.mean_mag_db,   'Color', c_jazz,   'LineWidth', 1.6, 'DisplayName', 'Jazz Noise');
    plot(freq_axis, genre_data.rock.mean_mag_db,   'Color', c_rock,   'LineWidth', 1.6, 'DisplayName', 'Rock Noise');
    plot(freq_axis, genre_data.techno.mean_mag_db, 'Color', c_techno, 'LineWidth', 1.6, 'DisplayName', 'Techno Noise');
    xline(speech_data.female.f0_peak_hz, 'r--', 'LineWidth', 1.2, 'DisplayName', 'Female F_0 (218 Hz)');
    xlim([0, 4000]); ylim([-50, 2]);
    ylabel('Magnitude (dB)');
    title('Female Speech Spectrum vs. Jazz, Rock, and Techno Noise (0 - 4000 Hz)');
    legend('Location', 'northeast');
    
    % Panel 3: Combined Human Speech vs Genres
    subplot(3, 1, 3);
    hold on; grid on; box on;
    patch([300, 3400, 3400, 300], [-55, -55, 5, 5], [0.93, 0.96, 0.93], 'EdgeColor', 'none');
    plot(freq_axis, speech_data.combined.mean_mag_db, 'Color', c_comb, 'LineWidth', 2.6, 'DisplayName', 'Combined Human Speech (N=100)');
    plot(freq_axis, genre_data.jazz.mean_mag_db,   'Color', c_jazz,   'LineWidth', 1.6, 'DisplayName', 'Jazz Noise');
    plot(freq_axis, genre_data.rock.mean_mag_db,   'Color', c_rock,   'LineWidth', 1.6, 'DisplayName', 'Rock Noise');
    plot(freq_axis, genre_data.techno.mean_mag_db, 'Color', c_techno, 'LineWidth', 1.6, 'DisplayName', 'Techno Noise');
    xlim([0, 4000]); ylim([-50, 2]);
    xlabel('Frequency (Hz)'); ylabel('Magnitude (dB)');
    title('Combined Multi-Talker Speech Spectrum vs. Jazz, Rock, and Techno Noise');
    legend('Location', 'northeast');
    
    fig2_path = fullfile(figures_dir, 'speech_vs_genre_spectral_overlays.png');
    saveas(fig2, fig2_path);
    close(fig2);
    fprintf('  Saved: %s\n', fig2_path);

    % -------------------------------------------------------------------------
    % FIGURE 3: GENDER-SPECIFIC SPECTRAL MASKING DIFFERENTIALS (SSNR)
    % -------------------------------------------------------------------------
    fig3 = figure('Name', 'Speech Masking Differentials', 'Position', [100, 100, 1100, 800], 'Visible', 'off');
    
    for g = 1:num_genres
        gk = genres{g};
        subplot(3, 1, g);
        hold on; grid on; box on;
        
        ssnr_m = genre_data.(gk).ssnr_male_db;
        ssnr_f = genre_data.(gk).ssnr_female_db;
        ssnr_c = genre_data.(gk).ssnr_comb_db;
        
        % Shading for 0 dB threshold on combined
        f_pos = freq_axis;
        y_pos = max(ssnr_c, 0);
        y_neg = min(ssnr_c, 0);
        area(f_pos, y_pos, 0, 'FaceColor', [0.3, 0.75, 0.3], 'FaceAlpha', 0.25, 'EdgeColor', 'none', 'DisplayName', 'Speech Dominant (>0 dB)');
        area(f_pos, y_neg, 0, 'FaceColor', [0.9, 0.3, 0.3], 'FaceAlpha', 0.25, 'EdgeColor', 'none', 'DisplayName', 'Music Masking (<0 dB)');
        
        plot(freq_axis, ssnr_m, 'Color', c_male,   'LineWidth', 2.0, 'DisplayName', 'Male Speech SSNR');
        plot(freq_axis, ssnr_f, 'Color', c_female, 'LineWidth', 2.0, 'DisplayName', 'Female Speech SSNR');
        plot(freq_axis, ssnr_c, 'Color', c_comb,   'LineWidth', 2.4, 'DisplayName', 'Combined Speech SSNR');
        
        yline(0, 'k-', 'LineWidth', 1.2, 'DisplayName', '0 dB Parity');
        xline(300, 'k--', 'LineWidth', 1.0, 'DisplayName', 'Bandpass Cutoffs');
        xline(3400, 'k--', 'LineWidth', 1.0, 'HandleVisibility', 'off');
        
        xlim([0, 4000]);
        ylim([-35, 25]);
        ylabel('SSNR (dB)');
        title(sprintf('Spectral Signal-to-Noise Ratio (SSNR): Speech vs. %s Noise (0 dB Global SNR)', genre_display_names{g}));
        legend('Location', 'northeast');
    end
    xlabel('Frequency (Hz)');
    
    fig3_path = fullfile(figures_dir, 'speech_masking_differentials.png');
    saveas(fig3, fig3_path);
    close(fig3);
    fprintf('  Saved: %s\n', fig3_path);

    % -------------------------------------------------------------------------
    % FIGURE 4: SPEECH FORMANTS VS. PARAMETRIC NOTCH FILTER ALIGNMENT
    % -------------------------------------------------------------------------
    fig4 = figure('Name', 'Formants and Notch Filter Alignment', 'Position', [150, 150, 1100, 650], 'Visible', 'off');
    hold on; grid on; box on;
    
    % Speech envelopes
    plot(freq_axis, speech_data.male.mean_mag_db,   'Color', c_male,   'LineWidth', 2.2, 'DisplayName', 'Male Speech (F_0 = 125 Hz)');
    plot(freq_axis, speech_data.female.mean_mag_db, 'Color', c_female, 'LineWidth', 2.2, 'DisplayName', 'Female Speech (F_0 = 218 Hz)');
    
    % Genre noise curves
    plot(freq_axis, genre_data.techno.mean_mag_db, 'Color', [0.0, 0.45, 0.85, 0.6], 'LineWidth', 1.5, 'DisplayName', 'Techno Noise (Kick @ 62.5 Hz)');
    plot(freq_axis, genre_data.rock.mean_mag_db,   'Color', [0.65, 0.15, 0.70, 0.6], 'LineWidth', 1.5, 'DisplayName', 'Rock Noise (Bass @ 109 Hz)');
    
    % Traditional Bandpass Mask (demonstrating male F0 truncation)
    f_bp = [0, 200, 300, 3400, 4000, 8000];
    mag_bp = [-40, -40, 0, 0, -40, -40];
    plot(f_bp, mag_bp, 'r--', 'LineWidth', 2.0, 'DisplayName', 'Traditional Bandpass Mask (Kills Male F_0 < 300 Hz)');
    
    % Parametric Notch Mask (Techno Example: 62.5 Hz Notch, Passband 80 - 8000 Hz)
    f_notch = [0, 50, 62.5, 75, 125, 300, 3400, 8000];
    mag_notch = [0, 0, -40, 0, 0, 0, 0, 0];
    plot(f_notch, mag_notch, 'k-', 'LineWidth', 2.5, 'DisplayName', 'Parametric Notch Filter (Preserves F_0, Carves Out Kick @ 62.5 Hz)');
    
    xlim([40, 4000]);
    ylim([-50, 5]);
    xlabel('Frequency (Hz)');
    ylabel('Magnitude (dB)');
    title('Design Comparison: Parametric Notch Biquad Preserves Speech Pitch Fundamentals (F_0) vs. Bandpass Truncation');
    legend('Location', 'northeast');
    
    fig4_path = fullfile(figures_dir, 'speech_formants_filter_alignment.png');
    saveas(fig4, fig4_path);
    close(fig4);
    fprintf('  Saved: %s\n', fig4_path);

    % -------------------------------------------------------------------------
    % STANDARD GENRE FIGURES
    % -------------------------------------------------------------------------
    % Genre Profiles & Variance Envelopes
    fig5 = figure('Name', 'STFT Mean Spectral Profiles', 'Position', [100, 100, 1100, 750], 'Visible', 'off');
    subplot(2, 1, 1);
    hold on; grid on; box on;
    patch([300, 3400, 3400, 300], [-80, -80, 5, 5], [0.94, 0.94, 0.94], 'EdgeColor', 'none', 'DisplayName', 'Speech Passband');
    plot(freq_axis, genre_data.jazz.mean_mag_db,   'Color', c_jazz,   'LineWidth', 1.8, 'DisplayName', 'Jazz (Mean)');
    plot(freq_axis, genre_data.rock.mean_mag_db,   'Color', c_rock,   'LineWidth', 1.8, 'DisplayName', 'Rock (Mean)');
    plot(freq_axis, genre_data.techno.mean_mag_db, 'Color', c_techno, 'LineWidth', 1.8, 'DisplayName', 'Techno (Mean)');
    xlim([0, 4000]); ylim([-50, 2]);
    xlabel('Frequency (Hz)'); ylabel('Normalized Magnitude (dB)');
    title('Mean Spectral Profiles: Jazz vs. Rock vs. Techno (0 - 4000 Hz)');
    legend('Location', 'northeast');
    
    subplot(2, 1, 2);
    hold on; grid on; box on;
    patch([300, 3400, 3400, 300], [-80, -80, 5, 5], [0.94, 0.94, 0.94], 'EdgeColor', 'none');
    semilogx(freq_axis, genre_data.jazz.mean_mag_db,   'Color', c_jazz,   'LineWidth', 1.8, 'DisplayName', 'Jazz');
    semilogx(freq_axis, genre_data.rock.mean_mag_db,   'Color', c_rock,   'LineWidth', 1.8, 'DisplayName', 'Rock');
    semilogx(freq_axis, genre_data.techno.mean_mag_db, 'Color', c_techno, 'LineWidth', 1.8, 'DisplayName', 'Techno');
    xlim([20, 8000]); ylim([-60, 2]);
    xlabel('Frequency (Hz, Log Scale)'); ylabel('Normalized Magnitude (dB)');
    title('Full Mean Magnitude Spectra (20 Hz - 8 kHz Log Scale)');
    legend('Location', 'southwest');
    saveas(fig5, fullfile(figures_dir, 'stft_mean_spectral_profiles.png'));
    close(fig5);

    % Subband Energy Bars
    fig6 = figure('Name', 'Subband Energy Distribution', 'Position', [150, 150, 850, 500], 'Visible', 'off');
    band_categories = {'Sub-Bass (<80Hz)', 'Kick/Bass (60-150Hz)', 'Speech Band (300-3.4kHz)', 'High Freq (>4kHz)'};
    bar_data = [
        genre_data.jazz.energy_sub_bass,   genre_data.jazz.energy_kick,   genre_data.jazz.energy_speech,   genre_data.jazz.energy_high_trans;
        genre_data.rock.energy_sub_bass,   genre_data.rock.energy_kick,   genre_data.rock.energy_speech,   genre_data.rock.energy_high_trans;
        genre_data.techno.energy_sub_bass, genre_data.techno.energy_kick, genre_data.techno.energy_speech, genre_data.techno.energy_high_trans
    ];
    b = bar(bar_data', 'grouped');
    b(1).FaceColor = c_jazz; b(2).FaceColor = c_rock; b(3).FaceColor = c_techno;
    grid on; box on;
    set(gca, 'XTickLabel', band_categories);
    ylabel('Percentage of Total Spectral Energy (%)');
    title('Subband Energy Distribution: Jazz vs. Rock vs. Techno');
    legend({'Jazz', 'Rock', 'Techno'}, 'Location', 'northeast');
    ylim([0, 80]);
    for i = 1:size(bar_data, 2)
        for j = 1:size(bar_data, 1)
            x_pos = b(j).XEndPoints(i); y_pos = b(j).YEndPoints(i);
            text(x_pos, y_pos + 1.5, sprintf('%.1f%%', bar_data(j, i)), 'HorizontalAlignment', 'center', 'FontSize', 9, 'FontWeight', 'bold');
        end
    end
    saveas(fig6, fullfile(figures_dir, 'stft_subband_energy_bars.png'));
    close(fig6);

    % 7. Export Metadata
    mat_export_file = fullfile(metadata_dir, 'genre_spectral_profiles.mat');
    save(mat_export_file, 'freq_axis', 'genre_data', 'speech_data', 'fs_target', 'n_fft', 'hop_size');
    fprintf('\n--> Saved MATLAB MAT file to: %s\n', mat_export_file);

    json_export_file = fullfile(metadata_dir, 'genre_spectral_profiles.json');
    json_export_struct = struct();
    json_export_struct.fs = fs_target;
    json_export_struct.n_fft = n_fft;
    json_export_struct.hop_size = hop_size;
    json_export_struct.freq_axis = freq_axis;
    json_export_struct.speech.male = speech_data.male;
    json_export_struct.speech.female = speech_data.female;
    json_export_struct.speech.combined = speech_data.combined;
    
    for g = 1:num_genres
        gk = genres{g};
        json_export_struct.(gk).name = genre_data.(gk).name;
        json_export_struct.(gk).peak_freq_hz = genre_data.(gk).peak_freq;
        json_export_struct.(gk).spectral_centroid_hz = genre_data.(gk).spectral_centroid;
        json_export_struct.(gk).rolloff_85_hz = genre_data.(gk).spectral_rolloff_85;
        json_export_struct.(gk).energy_sub_bass_pct = genre_data.(gk).energy_sub_bass;
        json_export_struct.(gk).energy_kick_pct = genre_data.(gk).energy_kick;
        json_export_struct.(gk).energy_low_bass_pct = genre_data.(gk).energy_low_bass;
        json_export_struct.(gk).energy_speech_band_pct = genre_data.(gk).energy_speech;
        json_export_struct.(gk).energy_high_trans_pct = genre_data.(gk).energy_high_trans;
        json_export_struct.(gk).mean_mag_db = genre_data.(gk).mean_mag_db;
        json_export_struct.(gk).ssnr_male_db = genre_data.(gk).ssnr_male_db;
        json_export_struct.(gk).ssnr_female_db = genre_data.(gk).ssnr_female_db;
        json_export_struct.(gk).ssnr_comb_db = genre_data.(gk).ssnr_comb_db;
    end
    
    json_str = jsonencode(json_export_struct, 'PrettyPrint', true);
    fid = fopen(json_export_file, 'w');
    if fid ~= -1
        fwrite(fid, json_str, 'char');
        fclose(fid);
        fprintf('--> Saved JSON export to: %s\n', json_export_file);
    end

    csv_file = fullfile(metadata_dir, 'stft_summary_table.csv');
    fid_csv = fopen(csv_file, 'w');
    if fid_csv ~= -1
        fprintf(fid_csv, 'Category,Source,Peak_Hz,SubBass_pct,Kick_pct,LowBass_pct,SpeechBand_pct,HighFreq_pct,Centroid_Hz,Rolloff85_Hz\n');
        for g = 1:num_genres
            gk = genres{g};
            d = genre_data.(gk);
            fprintf(fid_csv, 'Music,%s,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f\n', ...
                d.name, d.peak_freq, d.energy_sub_bass, d.energy_kick, d.energy_low_bass, ...
                d.energy_speech, d.energy_high_trans, d.spectral_centroid, d.spectral_rolloff_85);
        end
        fprintf(fid_csv, 'Speech,Male,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f\n', ...
            speech_data.male.f0_peak_hz, speech_data.male.energy_sub_bass, speech_data.male.energy_low_f0, ...
            speech_data.male.energy_low_f0 + speech_data.male.energy_sub_bass, speech_data.male.energy_speech, ...
            speech_data.male.energy_high, speech_data.male.centroid, speech_data.male.rolloff_85);
        fprintf(fid_csv, 'Speech,Female,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f\n', ...
            speech_data.female.f0_peak_hz, speech_data.female.energy_sub_bass, speech_data.female.energy_low_f0, ...
            speech_data.female.energy_low_f0 + speech_data.female.energy_sub_bass, speech_data.female.energy_speech, ...
            speech_data.female.energy_high, speech_data.female.centroid, speech_data.female.rolloff_85);
        fprintf(fid_csv, 'Speech,Combined,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f\n', ...
            speech_data.combined.f0_peak_hz, speech_data.combined.energy_sub_bass, speech_data.combined.energy_low_f0, ...
            speech_data.combined.energy_low_f0 + speech_data.combined.energy_sub_bass, speech_data.combined.energy_speech, ...
            speech_data.combined.energy_high, speech_data.combined.centroid, speech_data.combined.rolloff_85);
        fclose(fid_csv);
        fprintf('--> Saved CSV summary table to: %s\n', csv_file);
    end

    fprintf('\n=========================================================================\n');
    fprintf('  STFT & MULTI-TALKER HUMAN SPEECH ANALYSIS COMPLETE!\n');
    fprintf('=========================================================================\n');
end
