%% STFT_GENRE_ANALYSIS.M
% Performs full STFT analysis across House, Techno, and Drum & Bass datasets (150 tracks total)
% as specified in Section 3.2 of the Investigation Project Plan:
% "The STFT (1024-point FFT, Hanning window, 50% overlap) is computed for each track
%  and the magnitude spectra averaged per genre to produce a mean spectral profile.
%  Dominant energy bands define the stopband regions for the Parks-McClellan filter design."
%
% University of the Witwatersrand
% School of Electrical & Information Engineering

function stft_genre_analysis()
    fprintf('=========================================================================\n');
    fprintf('  FULL STFT RUN ACROSS ALL 3 EDM SUBGENRES (150 TRACKS)\n');
    fprintf('  Sampling Rate: fs = 16 kHz | FFT: 1024-pt | Window: Hann | Overlap: 50%%\n');
    fprintf('=========================================================================\n\n');

    % 1. Path setup
    current_script_path = mfilename('fullpath');
    [script_dir, ~, ~] = fileparts(current_script_path);
    root_dir = fileparts(script_dir);
    
    wav_dir = fullfile(root_dir, 'dataset', 'wav_16k');
    metadata_dir = fullfile(root_dir, 'dataset', 'metadata');
    figures_dir = fullfile(root_dir, 'figures');
    
    if ~exist(metadata_dir, 'dir')
        mkdir(metadata_dir);
    end
    if ~exist(figures_dir, 'dir')
        mkdir(figures_dir);
    end

    genres = {'house', 'techno', 'dnb'};
    genre_display_names = {'House', 'Techno', 'Drum & Bass'};
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

    % Data storage
    genre_data = struct();

    % 3. Process each genre
    for g = 1:num_genres
        genre_key = genres{g};
        genre_name = genre_display_names{g};
        genre_folder = fullfile(wav_dir, genre_key);
        
        files = dir(fullfile(genre_folder, '*.wav'));
        num_files = length(files);
        
        if num_files == 0
            error('No WAV files found in %s. Please run download_and_convert.py first.', genre_folder);
        end
        
        fprintf('\n--> Processing Genre [%s]: %d tracks found in %s\n', ...
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
            
            % Ensure mono
            if size(x, 2) > 1
                x = mean(x, 2);
            end
            
            % Compute STFT via buffered matrix framing
            frames = buffer(x, n_fft, n_fft - hop_size, 'nodelay');
            windowed_frames = frames .* win;
            
            % FFT across columns
            X = fft(windowed_frames, n_fft, 1);
            
            % One-sided magnitude spectrum
            mag_spec = abs(X(1:num_freq_bins, :));
            
            % Mean magnitude spectrum across all time frames for this track
            track_mean_mag(:, i) = mean(mag_spec, 2);
        end
        elapsed = toc;
        fprintf('    Processed %d tracks in %.2f seconds (avg %.1f ms/track)\n', ...
            num_files, elapsed, (elapsed/num_files)*1000);
        
        % Compute genre-level statistics across all 50 tracks
        mean_mag = mean(track_mean_mag, 2);
        std_mag = std(track_mean_mag, 0, 2);
        median_mag = median(track_mean_mag, 2);
        
        % Normalized power spectrum (linear and dB)
        norm_mean_mag = mean_mag / max(mean_mag);
        mean_mag_db = 20 * log10(norm_mean_mag + eps);
        
        % Store in structure
        genre_data.(genre_key).name = genre_name;
        genre_data.(genre_key).track_names = track_names;
        genre_data.(genre_key).durations = durations;
        genre_data.(genre_key).all_track_mean_mag = track_mean_mag;
        genre_data.(genre_key).mean_mag = mean_mag;
        genre_data.(genre_key).std_mag = std_mag;
        genre_data.(genre_key).median_mag = median_mag;
        genre_data.(genre_key).norm_mean_mag = norm_mean_mag;
        genre_data.(genre_key).mean_mag_db = mean_mag_db;
        
        % Energy band distribution
        pwr = mean_mag .^ 2;
        total_pwr = sum(pwr);
        
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
        
        % Spectral Centroid and Rolloff (85%)
        genre_data.(genre_key).spectral_centroid = sum(freq_axis .* pwr) / total_pwr;
        cum_pwr = cumsum(pwr) / total_pwr;
        rolloff_bin = find(cum_pwr >= 0.85, 1, 'first');
        genre_data.(genre_key).spectral_rolloff_85 = freq_axis(rolloff_bin);
        
        % Peak frequency
        [~, peak_bin] = max(mean_mag);
        genre_data.(genre_key).peak_freq = freq_axis(peak_bin);
    end

    % 4. Summary Table Output
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
    fprintf('Spectral Centroids: House = %.1f Hz | Techno = %.1f Hz | Drum & Bass = %.1f Hz\n', ...
        genre_data.house.spectral_centroid, genre_data.techno.spectral_centroid, genre_data.dnb.spectral_centroid);
    fprintf('85%% Rolloff Freq:   House = %.1f Hz | Techno = %.1f Hz | Drum & Bass = %.1f Hz\n\n', ...
        genre_data.house.spectral_rolloff_85, genre_data.techno.spectral_rolloff_85, genre_data.dnb.spectral_rolloff_85);

    % 5. Stopband Recommendations for Section 3.3 FIR Filter Design
    fprintf('=========================================================================\n');
    fprintf('  DERIVED STOPBAND REGIONS FOR PARKS-MCCLELLAN (firpm) FILTER DESIGN\n');
    fprintf('=========================================================================\n');
    
    % House: Four-on-the-floor kick requires strong stopband attenuation in 50-180 Hz
    house_stop_low = 180;
    fprintf('1. HOUSE FIR FILTER:\n');
    fprintf('   - Low Stopband:  0 Hz to %d Hz (Targeting the %.1f Hz kick fundamental)\n', ...
        house_stop_low, genre_data.house.peak_freq);
    fprintf('   - Passband:      300 Hz to 3400 Hz (Speech communication band)\n');
    fprintf('   - High Stopband: 4000 Hz to 8000 Hz\n\n');

    % Techno: Repetitive low-frequency percussion requires broad low stopband 0-220 Hz
    techno_stop_low = 220;
    fprintf('2. TECHNO FIR FILTER:\n');
    fprintf('   - Low Stopband:  0 Hz to %d Hz (Targeting dense sub-bass & percussion energy = %.1f%%)\n', ...
        techno_stop_low, genre_data.techno.energy_low_bass);
    fprintf('   - Passband:      300 Hz to 3400 Hz (Speech communication band)\n');
    fprintf('   - High Stopband: 4000 Hz to 8000 Hz\n\n');

    % Drum & Bass: Sub-bass < 80 Hz plus heavy breakbeat transients > 3800 Hz
    dnb_stop_low = 160;
    dnb_stop_high = 3800;
    fprintf('3. DRUM & BASS FIR FILTER:\n');
    fprintf('   - Low Stopband:  0 Hz to %d Hz (Targeting breakbeat sub-bass & basslines)\n', dnb_stop_low);
    fprintf('   - Passband:      300 Hz to 3400 Hz (Speech communication band)\n');
    fprintf('   - High Stopband: %d Hz to 8000 Hz (Targeting rapid hi-hat/snare transients = %.2f%%)\n\n', ...
        dnb_stop_high, genre_data.dnb.energy_high_trans);

    % 6. Generate Figures
    fprintf('--> Generating publication-quality figures in %s...\n', figures_dir);
    set(0, 'DefaultAxesFontSize', 11);
    set(0, 'DefaultAxesFontName', 'Helvetica');
    set(0, 'DefaultLineLineWidth', 1.5);

    % Colors matching academic conventions
    c_house  = [0.8500, 0.3250, 0.0980]; % Orange/Red
    c_techno = [0.0000, 0.4470, 0.7410]; % Blue
    c_dnb    = [0.4660, 0.6740, 0.1880]; % Green
    c_speech = [0.9290, 0.6940, 0.1250]; % Gold/Yellow

    % Figure 1: Mean Spectral Profiles Comparison (Linear & Log Scales)
    fig1 = figure('Name', 'STFT Mean Spectral Profiles', 'Position', [100, 100, 1100, 750], 'Visible', 'off');
    
    % Subplot 1: Linear Scale (0 - 4000 Hz to inspect bass and speech band)
    subplot(2, 1, 1);
    hold on; grid on; box on;
    % Highlight speech band (300 to 3400 Hz)
    patch([300, 3400, 3400, 300], [-80, -80, 5, 5], [0.94, 0.94, 0.94], ...
        'EdgeColor', 'none', 'DisplayName', 'Speech Passband (300 - 3400 Hz)');
    
    p1 = plot(freq_axis, genre_data.house.mean_mag_db, 'Color', c_house, 'LineWidth', 1.8, 'DisplayName', 'House (Mean)');
    p2 = plot(freq_axis, genre_data.techno.mean_mag_db, 'Color', c_techno, 'LineWidth', 1.8, 'DisplayName', 'Techno (Mean)');
    p3 = plot(freq_axis, genre_data.dnb.mean_mag_db, 'Color', c_dnb, 'LineWidth', 1.8, 'DisplayName', 'Drum & Bass (Mean)');
    
    xlim([0, 4000]);
    ylim([-50, 2]);
    xlabel('Frequency (Hz)');
    ylabel('Normalized Magnitude (dB)');
    title('Mean Spectral Profiles Across Genres (0 - 4000 Hz: Sub-Bass, Kick & Speech Regions)');
    legend([p1, p2, p3], 'Location', 'northeast');
    
    % Subplot 2: Full Spectrum Logarithmic Frequency Scale (20 Hz - 8000 Hz)
    subplot(2, 1, 2);
    hold on; grid on; box on;
    patch([300, 3400, 3400, 300], [-80, -80, 5, 5], [0.94, 0.94, 0.94], ...
        'EdgeColor', 'none', 'DisplayName', 'Speech Passband');
    
    semilogx(freq_axis, genre_data.house.mean_mag_db, 'Color', c_house, 'LineWidth', 1.8, 'DisplayName', 'House');
    semilogx(freq_axis, genre_data.techno.mean_mag_db, 'Color', c_techno, 'LineWidth', 1.8, 'DisplayName', 'Techno');
    semilogx(freq_axis, genre_data.dnb.mean_mag_db, 'Color', c_dnb, 'LineWidth', 1.8, 'DisplayName', 'Drum & Bass');
    
    xlim([20, 8000]);
    ylim([-60, 2]);
    xlabel('Frequency (Hz, Log Scale)');
    ylabel('Normalized Magnitude (dB)');
    title('Full Mean Magnitude Spectra (20 Hz - 8 kHz Log Scale)');
    legend('Location', 'southwest');
    
    fig1_path = fullfile(figures_dir, 'stft_mean_spectral_profiles.png');
    saveas(fig1, fig1_path);
    close(fig1);
    fprintf('  Saved: %s\n', fig1_path);

    % Figure 2: Subband Energy Comparison Bar Chart
    fig2 = figure('Name', 'Subband Energy Distribution', 'Position', [150, 150, 850, 500], 'Visible', 'off');
    band_categories = {'Sub-Bass (<80Hz)', 'Kick (60-150Hz)', 'Speech Band (300-3.4kHz)', 'High Freq (>4kHz)'};
    bar_data = [
        genre_data.house.energy_sub_bass,  genre_data.house.energy_kick,  genre_data.house.energy_speech,  genre_data.house.energy_high_trans;
        genre_data.techno.energy_sub_bass, genre_data.techno.energy_kick, genre_data.techno.energy_speech, genre_data.techno.energy_high_trans;
        genre_data.dnb.energy_sub_bass,    genre_data.dnb.energy_kick,    genre_data.dnb.energy_speech,    genre_data.dnb.energy_high_trans
    ];
    
    b = bar(bar_data', 'grouped');
    b(1).FaceColor = c_house;
    b(2).FaceColor = c_techno;
    b(3).FaceColor = c_dnb;
    grid on; box on;
    set(gca, 'XTickLabel', band_categories);
    ylabel('Percentage of Total Spectral Energy (%)');
    title('Subband Energy Distribution Comparison Across EDM Subgenres');
    legend({'House', 'Techno', 'Drum & Bass'}, 'Location', 'northeast');
    ylim([0, 80]);
    
    % Add value labels on top of bars
    for i = 1:size(bar_data, 2)
        for j = 1:size(bar_data, 1)
            x_pos = b(j).XEndPoints(i);
            y_pos = b(j).YEndPoints(i);
            text(x_pos, y_pos + 1.5, sprintf('%.1f%%', bar_data(j, i)), ...
                'HorizontalAlignment', 'center', 'FontSize', 9, 'FontWeight', 'bold');
        end
    end
    
    fig2_path = fullfile(figures_dir, 'stft_subband_energy_bars.png');
    saveas(fig2, fig2_path);
    close(fig2);
    fprintf('  Saved: %s\n', fig2_path);

    % Figure 3: Individual Genre Profiles with Standard Deviation Envelope
    fig3 = figure('Name', 'Genre Profiles with Variance Envelope', 'Position', [200, 200, 1100, 750], 'Visible', 'off');
    for g = 1:num_genres
        gk = genres{g};
        subplot(3, 1, g);
        hold on; grid on; box on;
        
        m = genre_data.(gk).mean_mag;
        s = genre_data.(gk).std_mag;
        
        % Normalize to 0 dB peak
        max_val = max(m);
        upper_db = 20 * log10((m + s) / max_val + eps);
        lower_db = 20 * log10(max(m - s, eps) / max_val + eps);
        mean_db  = 20 * log10(m / max_val + eps);
        
        % Shaded +/- 1 std dev envelope
        f_poly = [freq_axis; flipud(freq_axis)];
        env_poly = [upper_db; flipud(lower_db)];
        
        if g == 1, col = c_house; elseif g == 2, col = c_techno; else, col = c_dnb; end
        fill(f_poly, env_poly, col, 'FaceAlpha', 0.25, 'EdgeColor', 'none', 'DisplayName', '\pm 1 \sigma Across 50 Tracks');
        plot(freq_axis, mean_db, 'Color', col, 'LineWidth', 2.0, 'DisplayName', 'Mean Spectrum');
        
        % Highlight speech band
        plot([300, 300], [-60, 5], 'k--', 'LineWidth', 1.0, 'DisplayName', 'Speech Cutoffs');
        plot([3400, 3400], [-60, 5], 'k--', 'LineWidth', 1.0, 'HandleVisibility', 'off');
        
        xlim([0, 4000]);
        ylim([-45, 5]);
        ylabel('Normalized dB');
        title(sprintf('%s (N = 50 tracks) - Mean Profile and Within-Genre Variance', genre_display_names{g}));
        legend('Location', 'northeast');
    end
    xlabel('Frequency (Hz)');
    
    fig3_path = fullfile(figures_dir, 'stft_genre_variance_envelopes.png');
    saveas(fig3, fig3_path);
    close(fig3);
    fprintf('  Saved: %s\n', fig3_path);

    % Figure 4: Representative Spectrograms from Test Stimuli (60s continuous noise)
    fig4 = figure('Name', 'Sample Spectrograms', 'Position', [250, 250, 1100, 800], 'Visible', 'off');
    noise_dir = fullfile(root_dir, 'dataset', 'test_stimuli', 'music_noise_60s');
    
    for g = 1:num_genres
        gk = genres{g};
        wav_file = fullfile(noise_dir, sprintf('%s_noise_60s.wav', gk));
        if exist(wav_file, 'file')
            [x_noise, fs_n] = audioread(wav_file);
            % Take first 10 seconds for high-resolution visual inspection
            x_seg = x_noise(1:min(length(x_noise), 10 * fs_n));
            
            subplot(3, 1, g);
            % Compute spectrogram
            [~, F_sp, T_sp, P_sp] = spectrogram(x_seg, hann(512), 256, 512, fs_n);
            surf(T_sp, F_sp, 10*log10(P_sp + eps), 'EdgeColor', 'none');
            axis tight; view(0, 90); colormap('turbo'); colorbar;
            ylim([0, 4000]);
            caxis([-60, 0]);
            ylabel('Freq (Hz)');
            title(sprintf('%s 60s Test Noise Excerpt (First 10s Spectrogram)', genre_display_names{g}));
        end
    end
    xlabel('Time (seconds)');
    
    fig4_path = fullfile(figures_dir, 'stft_sample_spectrograms.png');
    saveas(fig4, fig4_path);
    close(fig4);
    fprintf('  Saved: %s\n', fig4_path);

    % 7. Export Data to .mat and .json
    mat_export_file = fullfile(metadata_dir, 'genre_spectral_profiles.mat');
    save(mat_export_file, 'freq_axis', 'genre_data', 'fs_target', 'n_fft', 'hop_size');
    fprintf('\n--> Saved MATLAB MAT file to: %s\n', mat_export_file);

    % Export lightweight JSON for Python and firmware DSP scripts
    json_export_file = fullfile(metadata_dir, 'genre_spectral_profiles.json');
    json_export_struct = struct();
    json_export_struct.fs = fs_target;
    json_export_struct.n_fft = n_fft;
    json_export_struct.hop_size = hop_size;
    json_export_struct.freq_axis = freq_axis;
    
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
    end
    
    json_str = jsonencode(json_export_struct, 'PrettyPrint', true);
    fid = fopen(json_export_file, 'w');
    if fid ~= -1
        fwrite(fid, json_str, 'char');
        fclose(fid);
        fprintf('--> Saved JSON export to: %s\n', json_export_file);
    end

    % Export CSV Summary Table
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
    fprintf('  STFT ANALYSIS RUN COMPLETED SUCCESSFULLY!\n');
    fprintf('=========================================================================\n');
end
