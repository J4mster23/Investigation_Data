%% STFT_GENRE_ANALYSIS.M
% Performs full STFT analysis across Jazz, Rock, and Techno datasets (150 tracks total, 50 per genre)
% and computes the average speech spectrum across all 20 Harvard Sentences.
% Generates speech-vs-genre spectral overlays, masking differential profiles,
% and stopband derivation graphs for filter design.
%
% University of the Witwatersrand
% School of Electrical & Information Engineering

function stft_genre_analysis()
    fprintf('=========================================================================\n');
    fprintf('  FULL STFT RUN ACROSS ALL 3 GENRES: JAZZ, ROCK, TECHNO (150 TRACKS)\n');
    fprintf('  + AVERAGE SPEECH FFT ANALYSIS ACROSS 20 HARVARD SENTENCES\n');
    fprintf('  Sampling Rate: fs = 16 kHz | FFT: 1024-pt | Window: Hann | Overlap: 50%%\n');
    fprintf('=========================================================================\n\n');

    % 1. Path setup
    current_script_path = mfilename('fullpath');
    [script_dir, ~, ~] = fileparts(current_script_path);
    root_dir = fileparts(script_dir);
    
    wav_dir = fullfile(root_dir, 'dataset', 'wav_16k');
    speech_dir = fullfile(root_dir, 'dataset', 'test_stimuli', 'speech_sentences');
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

    % 3. Analyze Average Speech Spectrum (20 Harvard Sentences)
    fprintf('\n--> Computing Average Active Speech Spectrum across Harvard Sentences...\n');
    speech_files = dir(fullfile(speech_dir, 'sentence_*.wav'));
    num_speech_files = length(speech_files);
    
    if num_speech_files == 0
        error('No speech sentence WAV files found in %s.', speech_dir);
    end
    
    all_speech_pwr = zeros(num_freq_bins, num_speech_files);
    for s = 1:num_speech_files
        s_path = fullfile(speech_dir, speech_files(s).name);
        [s_x, s_fs] = audioread(s_path);
        if s_fs ~= fs_target
            error('Speech sample rate mismatch: %s', speech_files(s).name);
        end
        if size(s_x, 2) > 1, s_x = mean(s_x, 2); end
        
        s_frames = buffer(s_x, n_fft, n_fft - hop_size, 'nodelay');
        s_windowed = s_frames .* win;
        s_X = fft(s_windowed, n_fft, 1);
        s_mag = abs(s_X(1:num_freq_bins, :));
        
        % Frame energy thresholding: only include active speech frames (> -25 dB of peak frame)
        frame_energies = sum(s_mag .^ 2, 1);
        peak_energy = max(frame_energies);
        active_frames = frame_energies > (peak_energy * 10^(-25/10));
        
        if any(active_frames)
            all_speech_pwr(:, s) = mean(s_mag(:, active_frames) .^ 2, 2);
        else
            all_speech_pwr(:, s) = mean(s_mag .^ 2, 2);
        end
    end
    
    % Average speech power spectrum across sentences
    speech_mean_pwr = mean(all_speech_pwr, 2);
    speech_total_pwr = sum(speech_mean_pwr);
    speech_norm_pwr = speech_mean_pwr / speech_total_pwr;
    speech_mean_mag = sqrt(speech_mean_pwr);
    speech_mean_mag_db = 10 * log10(speech_norm_pwr / max(speech_norm_pwr) + eps);
    
    fprintf('    Processed %d Harvard sentences. Active Speech Formants computed.\n', num_speech_files);

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
        
        % Subband energy distribution
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
        
        % Spectral SNR Differential (0 dB global reference):
        % SSNR(f) = 10 * log10( P_speech(f) / P_genre(f) )
        genre_data.(genre_key).ssnr_db = 10 * log10((speech_norm_pwr + eps) ./ (norm_pwr + eps));
    end

    % 5. Summary Table Output
    fprintf('\n=========================================================================\n');
    fprintf('  SPECTRAL ENERGY DISTRIBUTION TABLE (ACROSS 50 TRACKS PER GENRE)\n');
    fprintf('=========================================================================\n');
    fprintf('%-12s | %-10s | %-12s | %-12s | %-12s | %-12s | %-10s\n', ...
        'Genre', 'Peak (Hz)', 'Sub-Bass <80', 'Kick 60-150', 'LowBass <250', 'Speech Band', 'High >4kHz');
    fprintf('-----------------------------------------------------------------------------------------\n');
    for g = 1:num_genres
        gk = genres{g};
        d = genre_data.(gk);
        fprintf('%-12s | %8.1f Hz | %10.2f %% | %10.2f %% | %10.2f %% | %10.2f %% | %8.2f %%\n', ...
            d.name, d.peak_freq, d.energy_sub_bass, d.energy_kick, d.energy_low_bass, d.energy_speech, d.energy_high_trans);
    end
    fprintf('-----------------------------------------------------------------------------------------\n');
    fprintf('Spectral Centroids: Jazz = %.1f Hz | Rock = %.1f Hz | Techno = %.1f Hz\n', ...
        genre_data.jazz.spectral_centroid, genre_data.rock.spectral_centroid, genre_data.techno.spectral_centroid);
    fprintf('85%% Rolloff Freq:   Jazz = %.1f Hz | Rock = %.1f Hz | Techno = %.1f Hz\n\n', ...
        genre_data.jazz.spectral_rolloff_85, genre_data.rock.spectral_rolloff_85, genre_data.techno.spectral_rolloff_85);

    % 6. Visualization Palette Setup
    fprintf('--> Generating publication-quality figures in %s...\n', figures_dir);
    set(0, 'DefaultAxesFontSize', 11);
    set(0, 'DefaultAxesFontName', 'Helvetica');
    set(0, 'DefaultLineLineWidth', 1.5);

    c_jazz   = [0.8500, 0.5500, 0.0500]; % Gold / Amber
    c_rock   = [0.6500, 0.1500, 0.7000]; % Deep Purple
    c_techno = [0.0000, 0.4500, 0.8500]; % Cobalt Blue
    c_speech = [0.1000, 0.1000, 0.1000]; % Bold Charcoal / Black

    % -------------------------------------------------------------------------
    % FIGURE 1: SPEECH FFT VS. GENRES OVERLAY (Primary Request)
    % -------------------------------------------------------------------------
    fig1 = figure('Name', 'Speech vs Genre Spectral Overlays', 'Position', [50, 50, 1150, 800], 'Visible', 'off');
    
    subplot(2, 1, 1);
    hold on; grid on; box on;
    patch([300, 3400, 3400, 300], [-70, -70, 5, 5], [0.93, 0.96, 0.93], ...
        'EdgeColor', 'none', 'DisplayName', 'Speech Intelligibility Band (300 - 3400 Hz)');
    
    p_sp = plot(freq_axis, speech_mean_mag_db, 'Color', c_speech, 'LineWidth', 2.4, 'DisplayName', 'Clean Speech (20 Harvard Sentences)');
    p_j  = plot(freq_axis, genre_data.jazz.mean_mag_db, 'Color', c_jazz, 'LineWidth', 1.8, 'DisplayName', 'Jazz Mean Spectrum');
    p_r  = plot(freq_axis, genre_data.rock.mean_mag_db, 'Color', c_rock, 'LineWidth', 1.8, 'DisplayName', 'Rock Mean Spectrum');
    p_t  = plot(freq_axis, genre_data.techno.mean_mag_db, 'Color', c_techno, 'LineWidth', 1.8, 'DisplayName', 'Techno Mean Spectrum');
    
    xlim([0, 8000]);
    ylim([-55, 2]);
    xlabel('Frequency (Hz)');
    ylabel('Normalized Magnitude (dB)');
    title('Full-Band Spectrum: Clean Speech vs. Jazz, Rock, and Techno (0 - 8000 Hz)');
    legend([p_sp, p_j, p_r, p_t], 'Location', 'northeast');
    
    subplot(2, 1, 2);
    hold on; grid on; box on;
    patch([300, 3400, 3400, 300], [-55, -55, 5, 5], [0.93, 0.96, 0.93], ...
        'EdgeColor', 'none', 'DisplayName', 'Speech Formant Passband (300 - 3400 Hz)');
    
    plot(freq_axis, speech_mean_mag_db, 'Color', c_speech, 'LineWidth', 2.6, 'DisplayName', 'Clean Speech (Formants)');
    plot(freq_axis, genre_data.jazz.mean_mag_db, 'Color', c_jazz, 'LineWidth', 1.8, 'DisplayName', 'Jazz');
    plot(freq_axis, genre_data.rock.mean_mag_db, 'Color', c_rock, 'LineWidth', 1.8, 'DisplayName', 'Rock');
    plot(freq_axis, genre_data.techno.mean_mag_db, 'Color', c_techno, 'LineWidth', 1.8, 'DisplayName', 'Techno');
    
    % Annotate Formant regions
    text(150, -12, 'Pitch F_0', 'FontSize', 9, 'FontWeight', 'bold', 'Color', [0.2, 0.2, 0.2]);
    text(500, -2, 'Formant F_1', 'FontSize', 9, 'FontWeight', 'bold', 'Color', [0.1, 0.5, 0.1]);
    text(1500, -10, 'Formant F_2', 'FontSize', 9, 'FontWeight', 'bold', 'Color', [0.1, 0.5, 0.1]);
    text(2800, -22, 'Formant F_3', 'FontSize', 9, 'FontWeight', 'bold', 'Color', [0.1, 0.5, 0.1]);
    
    % Stopband boundary lines
    xline(300, 'k--', 'LineWidth', 1.2, 'DisplayName', 'Passband Edges');
    xline(3400, 'k--', 'LineWidth', 1.2, 'HandleVisibility', 'off');
    
    xlim([0, 4000]);
    ylim([-50, 2]);
    xlabel('Frequency (Hz)');
    ylabel('Normalized Magnitude (dB)');
    title('Passband & Bass Zoom: Vocal Formants vs. Dominant Noise Maskers (0 - 4000 Hz)');
    legend('Location', 'northeast');
    
    fig1_path = fullfile(figures_dir, 'speech_vs_genre_spectral_overlays.png');
    saveas(fig1, fig1_path);
    close(fig1);
    fprintf('  Saved: %s\n', fig1_path);

    % -------------------------------------------------------------------------
    % FIGURE 2: SPECTRAL SIGNAL-TO-NOISE RATIO (MASKING DIFFERENTIAL)
    % -------------------------------------------------------------------------
    fig2 = figure('Name', 'Speech Masking Differentials', 'Position', [100, 100, 1100, 750], 'Visible', 'off');
    genre_colors = {c_jazz, c_rock, c_techno};
    
    for g = 1:num_genres
        gk = genres{g};
        subplot(3, 1, g);
        hold on; grid on; box on;
        
        diff_curve = genre_data.(gk).ssnr_db;
        
        % Color zones: Green where Speech > Noise (> 0 dB), Red where Noise > Speech (< 0 dB)
        f_pos = freq_axis;
        y_pos = max(diff_curve, 0);
        y_neg = min(diff_curve, 0);
        
        area(f_pos, y_pos, 0, 'FaceColor', [0.3, 0.75, 0.3], 'FaceAlpha', 0.4, 'EdgeColor', 'none', 'DisplayName', 'Speech Dominant (>0 dB)');
        area(f_pos, y_neg, 0, 'FaceColor', [0.9, 0.3, 0.3], 'FaceAlpha', 0.4, 'EdgeColor', 'none', 'DisplayName', 'Music Masking (<0 dB)');
        
        plot(freq_axis, diff_curve, 'Color', genre_colors{g}, 'LineWidth', 2.0, 'DisplayName', sprintf('SSNR: Speech - %s', genre_display_names{g}));
        yline(0, 'k-', 'LineWidth', 1.2, 'DisplayName', '0 dB Parity');
        
        xline(300, 'k--', 'LineWidth', 1.0, 'DisplayName', 'Filter Cutoffs (300 - 3400 Hz)');
        xline(3400, 'k--', 'LineWidth', 1.0, 'HandleVisibility', 'off');
        
        xlim([0, 4000]);
        ylim([-30, 25]);
        ylabel('SSNR (dB)');
        title(sprintf('Spectral Masking Profile: Speech vs. %s (0 dB Global SNR)', genre_display_names{g}));
        legend('Location', 'northeast');
    end
    xlabel('Frequency (Hz)');
    
    fig2_path = fullfile(figures_dir, 'speech_masking_differentials.png');
    saveas(fig2, fig2_path);
    close(fig2);
    fprintf('  Saved: %s\n', fig2_path);

    % -------------------------------------------------------------------------
    % FIGURE 3: SPEECH FORMANTS VS. FILTER ALIGNMENT (Design Justification)
    % -------------------------------------------------------------------------
    fig3 = figure('Name', 'Speech Formants and Filter Alignment', 'Position', [150, 150, 1100, 600], 'Visible', 'off');
    hold on; grid on; box on;
    
    % Shaded zones
    patch([0, 300, 300, 0], [-60, -60, 5, 5], [1.0, 0.9, 0.9], 'EdgeColor', 'none', 'DisplayName', 'Low Stopband (Bass & Kick Rejection)');
    patch([300, 3400, 3400, 300], [-60, -60, 5, 5], [0.9, 0.98, 0.9], 'EdgeColor', 'none', 'DisplayName', 'Passband (F1, F2, F3 Formant Preservation)');
    patch([3800, 8000, 8000, 3800], [-60, -60, 5, 5], [0.9, 0.9, 1.0], 'EdgeColor', 'none', 'DisplayName', 'High Stopband (Cymbal / Sizzle Rejection)');
    
    plot(freq_axis, speech_mean_mag_db, 'Color', [0.1, 0.1, 0.1], 'LineWidth', 2.8, 'DisplayName', 'Clean Speech Spectrum');
    plot(freq_axis, genre_data.jazz.mean_mag_db, 'Color', c_jazz, 'LineWidth', 1.6, 'DisplayName', 'Jazz Noise');
    plot(freq_axis, genre_data.rock.mean_mag_db, 'Color', c_rock, 'LineWidth', 1.6, 'DisplayName', 'Rock Noise');
    plot(freq_axis, genre_data.techno.mean_mag_db, 'Color', c_techno, 'LineWidth', 1.6, 'DisplayName', 'Techno Noise');
    
    % Ideal Filter Template
    f_filt = [0, 180, 300, 3400, 3900, 8000];
    mag_filt = [-40, -40, 0, 0, -40, -40];
    plot(f_filt, mag_filt, 'k-', 'LineWidth', 2.5, 'LineStyle', '-.', 'DisplayName', 'Target Filter Mask (|H(f)| >= 40 dB Rejection)');
    
    xlim([0, 5000]);
    ylim([-50, 5]);
    xlabel('Frequency (Hz)');
    ylabel('Magnitude (dB)');
    title('Filter Design Rationale: Aligning Passband with Speech Formants and Stopbands with Genre Interference');
    legend('Location', 'northeast');
    
    fig3_path = fullfile(figures_dir, 'speech_formants_filter_alignment.png');
    saveas(fig3, fig3_path);
    close(fig3);
    fprintf('  Saved: %s\n', fig3_path);

    % -------------------------------------------------------------------------
    % FIGURE 4: STANDARD GENRE MEAN SPECTRAL PROFILES
    % -------------------------------------------------------------------------
    fig4 = figure('Name', 'STFT Mean Spectral Profiles', 'Position', [100, 100, 1100, 750], 'Visible', 'off');
    
    subplot(2, 1, 1);
    hold on; grid on; box on;
    patch([300, 3400, 3400, 300], [-80, -80, 5, 5], [0.94, 0.94, 0.94], ...
        'EdgeColor', 'none', 'DisplayName', 'Speech Passband (300 - 3400 Hz)');
    
    p1 = plot(freq_axis, genre_data.jazz.mean_mag_db, 'Color', c_jazz, 'LineWidth', 1.8, 'DisplayName', 'Jazz (Mean)');
    p2 = plot(freq_axis, genre_data.rock.mean_mag_db, 'Color', c_rock, 'LineWidth', 1.8, 'DisplayName', 'Rock (Mean)');
    p3 = plot(freq_axis, genre_data.techno.mean_mag_db, 'Color', c_techno, 'LineWidth', 1.8, 'DisplayName', 'Techno (Mean)');
    
    xlim([0, 4000]);
    ylim([-50, 2]);
    xlabel('Frequency (Hz)');
    ylabel('Normalized Magnitude (dB)');
    title('Mean Spectral Profiles: Jazz vs. Rock vs. Techno (0 - 4000 Hz)');
    legend([p1, p2, p3], 'Location', 'northeast');
    
    subplot(2, 1, 2);
    hold on; grid on; box on;
    patch([300, 3400, 3400, 300], [-80, -80, 5, 5], [0.94, 0.94, 0.94], ...
        'EdgeColor', 'none', 'DisplayName', 'Speech Passband');
    
    semilogx(freq_axis, genre_data.jazz.mean_mag_db, 'Color', c_jazz, 'LineWidth', 1.8, 'DisplayName', 'Jazz');
    semilogx(freq_axis, genre_data.rock.mean_mag_db, 'Color', c_rock, 'LineWidth', 1.8, 'DisplayName', 'Rock');
    semilogx(freq_axis, genre_data.techno.mean_mag_db, 'Color', c_techno, 'LineWidth', 1.8, 'DisplayName', 'Techno');
    
    xlim([20, 8000]);
    ylim([-60, 2]);
    xlabel('Frequency (Hz, Log Scale)');
    ylabel('Normalized Magnitude (dB)');
    title('Full Mean Magnitude Spectra (20 Hz - 8 kHz Log Scale)');
    legend('Location', 'southwest');
    
    fig4_path = fullfile(figures_dir, 'stft_mean_spectral_profiles.png');
    saveas(fig4, fig4_path);
    close(fig4);
    fprintf('  Saved: %s\n', fig4_path);

    % -------------------------------------------------------------------------
    % FIGURE 5: SUBBAND ENERGY COMPARISON BAR CHART
    % -------------------------------------------------------------------------
    fig5 = figure('Name', 'Subband Energy Distribution', 'Position', [150, 150, 850, 500], 'Visible', 'off');
    band_categories = {'Sub-Bass (<80Hz)', 'Kick/Bass (60-150Hz)', 'Speech Band (300-3.4kHz)', 'High Freq (>4kHz)'};
    bar_data = [
        genre_data.jazz.energy_sub_bass,   genre_data.jazz.energy_kick,   genre_data.jazz.energy_speech,   genre_data.jazz.energy_high_trans;
        genre_data.rock.energy_sub_bass,   genre_data.rock.energy_kick,   genre_data.rock.energy_speech,   genre_data.rock.energy_high_trans;
        genre_data.techno.energy_sub_bass, genre_data.techno.energy_kick, genre_data.techno.energy_speech, genre_data.techno.energy_high_trans
    ];
    
    b = bar(bar_data', 'grouped');
    b(1).FaceColor = c_jazz;
    b(2).FaceColor = c_rock;
    b(3).FaceColor = c_techno;
    grid on; box on;
    set(gca, 'XTickLabel', band_categories);
    ylabel('Percentage of Total Spectral Energy (%)');
    title('Subband Energy Distribution: Jazz vs. Rock vs. Techno');
    legend({'Jazz', 'Rock', 'Techno'}, 'Location', 'northeast');
    ylim([0, 80]);
    
    for i = 1:size(bar_data, 2)
        for j = 1:size(bar_data, 1)
            x_pos = b(j).XEndPoints(i);
            y_pos = b(j).YEndPoints(i);
            text(x_pos, y_pos + 1.5, sprintf('%.1f%%', bar_data(j, i)), ...
                'HorizontalAlignment', 'center', 'FontSize', 9, 'FontWeight', 'bold');
        end
    end
    
    fig5_path = fullfile(figures_dir, 'stft_subband_energy_bars.png');
    saveas(fig5, fig5_path);
    close(fig5);
    fprintf('  Saved: %s\n', fig5_path);

    % -------------------------------------------------------------------------
    % FIGURE 6: INDIVIDUAL GENRE PROFILES WITH VARIANCE ENVELOPES
    % -------------------------------------------------------------------------
    fig6 = figure('Name', 'Genre Profiles with Variance Envelope', 'Position', [200, 200, 1100, 750], 'Visible', 'off');
    cols = {c_jazz, c_rock, c_techno};
    for g = 1:num_genres
        gk = genres{g};
        subplot(3, 1, g);
        hold on; grid on; box on;
        
        m = genre_data.(gk).mean_mag;
        s = genre_data.(gk).std_mag;
        
        max_val = max(m);
        upper_db = 20 * log10((m + s) / max_val + eps);
        lower_db = 20 * log10(max(m - s, eps) / max_val + eps);
        mean_db  = 20 * log10(m / max_val + eps);
        
        f_poly = [freq_axis; flipud(freq_axis)];
        env_poly = [upper_db; flipud(lower_db)];
        
        fill(f_poly, env_poly, cols{g}, 'FaceAlpha', 0.25, 'EdgeColor', 'none', 'DisplayName', '\pm 1 \sigma Across 50 Tracks');
        plot(freq_axis, mean_db, 'Color', cols{g}, 'LineWidth', 2.0, 'DisplayName', 'Mean Spectrum');
        
        plot([300, 300], [-60, 5], 'k--', 'LineWidth', 1.0, 'DisplayName', 'Speech Cutoffs');
        plot([3400, 3400], [-60, 5], 'k--', 'LineWidth', 1.0, 'HandleVisibility', 'off');
        
        xlim([0, 4000]);
        ylim([-45, 5]);
        ylabel('Normalized dB');
        title(sprintf('%s (N = 50 tracks) - Mean Spectral Profile & Variance', genre_display_names{g}));
        legend('Location', 'northeast');
    end
    xlabel('Frequency (Hz)');
    
    fig6_path = fullfile(figures_dir, 'stft_genre_variance_envelopes.png');
    saveas(fig6, fig6_path);
    close(fig6);
    fprintf('  Saved: %s\n', fig6_path);

    % -------------------------------------------------------------------------
    % FIGURE 7: SAMPLE SPECTROGRAMS (30s continuous noise)
    % -------------------------------------------------------------------------
    fig7 = figure('Name', 'Sample Spectrograms', 'Position', [250, 250, 1100, 800], 'Visible', 'off');
    noise_dir = fullfile(root_dir, 'dataset', 'test_stimuli', 'music_noise_30s');
    
    for g = 1:num_genres
        gk = genres{g};
        wav_file = fullfile(noise_dir, sprintf('%s_noise_30s.wav', gk));
        if exist(wav_file, 'file')
            [x_noise, fs_n] = audioread(wav_file);
            x_seg = x_noise(1:min(length(x_noise), 10 * fs_n));
            
            subplot(3, 1, g);
            [~, F_sp, T_sp, P_sp] = spectrogram(x_seg, hann(512), 256, 512, fs_n);
            surf(T_sp, F_sp, 10*log10(P_sp + eps), 'EdgeColor', 'none');
            axis tight; view(0, 90); colormap('turbo'); colorbar;
            ylim([0, 4000]);
            caxis([-60, 0]);
            ylabel('Freq (Hz)');
            title(sprintf('%s Noise Stimulus (First 10s Spectrogram)', genre_display_names{g}));
        end
    end
    xlabel('Time (seconds)');
    
    fig7_path = fullfile(figures_dir, 'stft_sample_spectrograms.png');
    saveas(fig7, fig7_path);
    close(fig7);
    fprintf('  Saved: %s\n', fig7_path);

    % 7. Export Data to .mat, .json, and .csv
    mat_export_file = fullfile(metadata_dir, 'genre_spectral_profiles.mat');
    save(mat_export_file, 'freq_axis', 'genre_data', 'speech_mean_mag', 'speech_mean_mag_db', 'fs_target', 'n_fft', 'hop_size');
    fprintf('\n--> Saved MATLAB MAT file to: %s\n', mat_export_file);

    json_export_file = fullfile(metadata_dir, 'genre_spectral_profiles.json');
    json_export_struct = struct();
    json_export_struct.fs = fs_target;
    json_export_struct.n_fft = n_fft;
    json_export_struct.hop_size = hop_size;
    json_export_struct.freq_axis = freq_axis;
    json_export_struct.speech_mean_mag_db = speech_mean_mag_db;
    
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
        json_export_struct.(gk).ssnr_db = genre_data.(gk).ssnr_db;
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
        fprintf(fid_csv, 'Genre,Peak_Hz,SubBass_pct,Kick_pct,LowBass_pct,SpeechBand_pct,HighFreq_pct,Centroid_Hz,Rolloff85_Hz\n');
        for g = 1:num_genres
            gk = genres{g};
            d = genre_data.(gk);
            fprintf(fid_csv, '%s,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f\n', ...
                d.name, d.peak_freq, d.energy_sub_bass, d.energy_kick, d.energy_low_bass, ...
                d.energy_speech, d.energy_high_trans, d.spectral_centroid, d.spectral_rolloff_85);
        end
        fclose(fid_csv);
        fprintf('--> Saved CSV summary table to: %s\n', csv_file);
    end

    fprintf('\n=========================================================================\n');
    fprintf('  STFT ANALYSIS RUN COMPLETED SUCCESSFULLY ACROSS JAZZ, ROCK, TECHNO!\n');
    fprintf('=========================================================================\n');
end
