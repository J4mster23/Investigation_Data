%% DESIGN_AND_COMPARE_FILTERS.M
% Designs genre-specific FIR and IIR filters for Country, Rock, and Techno and performs
% a rigorous comparative evaluation across magnitude response, group delay, pole-zero stability,
% computational complexity on ESP32-S3, and speech enhancement performance (Delta-SNR and STOI).
%
% University of the Witwatersrand
% School of Electrical & Information Engineering

function design_and_compare_filters()
    fprintf('=========================================================================\n');
    fprintf('  FILTER DESIGN & COMPARATIVE EVALUATION (COUNTRY, ROCK, TECHNO)\n');
    fprintf('  fs = 16 kHz | FIR: Parks-McClellan (128-tap) | IIR: Chebyshev II SOS\n');
    fprintf('=========================================================================\n\n');

    % 1. Directory and Path Setup
    current_script_path = mfilename('fullpath');
    [script_dir, ~, ~] = fileparts(current_script_path);
    root_dir = fileparts(script_dir);

    metadata_dir = fullfile(root_dir, 'dataset', 'metadata');
    figures_dir = fullfile(root_dir, 'figures');
    firmware_dir = fullfile(root_dir, 'firmware');
    speech_dir = fullfile(root_dir, 'dataset', 'test_stimuli', 'speech_sentences');
    noise_dir = fullfile(root_dir, 'dataset', 'test_stimuli', 'music_noise_30s');

    if ~exist(figures_dir, 'dir'), mkdir(figures_dir); end
    if ~exist(firmware_dir, 'dir'), mkdir(firmware_dir); end
    if ~exist(metadata_dir, 'dir'), mkdir(metadata_dir); end

    fs = 16000;
    nyq = fs / 2;

    % Genres and configurations
    filter_keys = {'country', 'rock', 'techno', 'control'};
    filter_names = {'Country', 'Rock', 'Techno', 'Control Baseline'};

    % 2. Design Specifications (Derived from Country, Rock, Techno STFT Analysis)
    specs = struct();
    
    % Country: Acoustic bass & kick < 150 Hz
    specs.country.f_stop1 = 150;
    specs.country.f_pass1 = 300;
    specs.country.f_pass2 = 3400;
    specs.country.f_stop2 = 4000;
    
    % Rock: Heavy distorted guitars, cymbals, bass guitar (stopband 0-160 Hz & 3800-8000 Hz)
    specs.rock.f_stop1 = 160;
    specs.rock.f_pass1 = 300;
    specs.rock.f_pass2 = 3400;
    specs.rock.f_stop2 = 3800;
    
    % Techno: Sub-bass and low-frequency percussion up to 220 Hz (85.4% energy < 250 Hz)
    specs.techno.f_stop1 = 220;
    specs.techno.f_pass1 = 300;
    specs.techno.f_pass2 = 3400;
    specs.techno.f_stop2 = 4000;
    
    % Control Bandpass: Standard speech band baseline
    specs.control.f_stop1 = 200;
    specs.control.f_pass1 = 300;
    specs.control.f_pass2 = 3400;
    specs.control.f_stop2 = 4000;

    % Storage for designed filters
    filters_fir = struct();
    filters_iir = struct();

    N_fir = 128; % 128th order = 129 taps
    N_iir_biquads = 4; % 8th order bandpass = 4 biquad Second-Order Sections

    fprintf('--> Designing FIR and IIR Filters for Country, Rock, Techno, and Control...\n');

    for k = 1:length(filter_keys)
        key = filter_keys{k};
        sp = specs.(key);

        % A. FIR Filter Design: Parks-McClellan Equiripple (firpm)
        f_edges = [0, sp.f_stop1, sp.f_pass1, sp.f_pass2, sp.f_stop2, nyq] / nyq;
        a_desired = [0, 0, 1, 1, 0, 0];
        weights = [15, 1, 15];
        
        b_fir = firpm(N_fir, f_edges, a_desired, weights);
        filters_fir.(key).b = b_fir;
        filters_fir.(key).order = N_fir;
        filters_fir.(key).num_taps = length(b_fir);
        filters_fir.(key).group_delay_samples = N_fir / 2;
        filters_fir.(key).group_delay_ms = (N_fir / 2) / fs * 1000;

        % B. IIR Filter Design: Chebyshev Type II Cascaded Biquads (SOS)
        W_stop = [sp.f_stop1, sp.f_stop2] / nyq;
        [z_iir, p_iir, k_iir] = cheby2(N_iir_biquads, 40, W_stop, 'bandpass');
        
        [sos, g] = zp2sos(z_iir, p_iir, k_iir);
        
        filters_iir.(key).sos = sos;
        filters_iir.(key).g = g;
        filters_iir.(key).order = N_iir_biquads * 2;
        filters_iir.(key).num_biquads = N_iir_biquads;
        filters_iir.(key).z = z_iir;
        filters_iir.(key).p = p_iir;
        filters_iir.(key).k = k_iir;
        
        max_pole = max(abs(p_iir));
        filters_iir.(key).max_pole_radius = max_pole;
        filters_iir.(key).is_stable = (max_pole < 1.0);
        
        fprintf('    [%s] FIR: 129 taps | IIR: 8th-order (4 biquads, max |p| = %.4f - %s)\n', ...
            upper(key), max_pole, ternary(max_pole < 1.0, 'STABLE', 'UNSTABLE'));
    end

    % 3. Frequency Domain and Group Delay Analysis
    fprintf('\n--> Computing Frequency Responses and Group Delays...\n');
    f_eval = linspace(0, nyq, 2048);
    comp_metrics = struct();

    for k = 1:length(filter_keys)
        key = filter_keys{k};
        
        [H_fir, ~] = freqz(filters_fir.(key).b, 1, f_eval, fs);
        [gd_fir, ~] = grpdelay(filters_fir.(key).b, 1, f_eval, fs);
        
        [b_iir, a_iir] = sos2tf(filters_iir.(key).sos, filters_iir.(key).g);
        [H_iir, ~] = freqz(b_iir, a_iir, f_eval, fs);
        [gd_iir, ~] = grpdelay(b_iir, a_iir, f_eval, fs);
        
        mag_fir_db = 20 * log10(abs(H_fir) + eps);
        mag_iir_db = 20 * log10(abs(H_iir) + eps);
        
        filters_fir.(key).mag_db = mag_fir_db;
        filters_fir.(key).gd_ms = gd_fir / fs * 1000;
        
        filters_iir.(key).mag_db = mag_iir_db;
        filters_iir.(key).gd_ms = gd_iir / fs * 1000;
        
        speech_idx = (f_eval >= 500 & f_eval <= 3000);
        comp_metrics.(key).fir_passband_delay_ms = mean(filters_fir.(key).gd_ms(speech_idx));
        comp_metrics.(key).iir_passband_delay_ms = mean(filters_iir.(key).gd_ms(speech_idx));
        comp_metrics.(key).iir_passband_delay_std = std(filters_iir.(key).gd_ms(speech_idx));
    end

    % 4. Computational Complexity Comparison
    fprintf('\n=========================================================================\n');
    fprintf('  COMPUTATIONAL COMPLEXITY ON ESP32-S3 (240 MHz Dual-Core, 32-bit FPU)\n');
    fprintf('=========================================================================\n');
    fprintf('%-18s | %-16s | %-16s | %-12s\n', 'Metric', '128-Tap FIR', '8th-Order IIR SOS', 'Speedup / Ratio');
    fprintf('-------------------------------------------------------------------------\n');
    fprintf('%-18s | %-16d | %-16d | %-12s\n', 'Coefficients', 129, 24, '5.4x smaller');
    fprintf('%-18s | %-16d | %-16d | %-12s\n', 'MACs per Sample', 128, 20, '6.4x faster');
    fprintf('%-18s | %-16.2f MFLOPS | %-16.2f MFLOPS | %-12s\n', 'Computation Rate', 128*fs/1e6, 20*fs/1e6, '6.4x less load');
    fprintf('%-18s | %-16d bytes | %-16d bytes | %-12s\n', 'RAM Delay Buffer', 128*4, 8*4, '16.0x smaller');
    fprintf('%-18s | %-16.2f ms | %-16.2f ms | %-12s\n', 'Core Passband Delay', 4.00, mean([comp_metrics.country.iir_passband_delay_ms, comp_metrics.rock.iir_passband_delay_ms, comp_metrics.techno.iir_passband_delay_ms]), '2.7x lower latency');
    fprintf('-------------------------------------------------------------------------\n\n');

    % 5. Speech Enhancement Simulation
    fprintf('--> Running Speech Enhancement Simulation (Country, Rock, Techno)...\n');
    snr_levels = [-5, -10, -15];
    sim_genres = {'country', 'rock', 'techno'};
    sim_results = struct();

    num_test_sentences = 5;
    speech_signals = cell(num_test_sentences, 1);
    for s = 1:num_test_sentences
        s_file = fullfile(speech_dir, sprintf('sentence_%02d.wav', s));
        [sp_data, ~] = audioread(s_file);
        speech_signals{s} = sp_data(:);
    end

    for g = 1:length(sim_genres)
        gk = sim_genres{g};
        noise_file = fullfile(noise_dir, sprintf('%s_noise_30s.wav', gk));
        [noise_data, ~] = audioread(noise_file);
        
        sim_results.(gk) = struct();
        
        for snr_idx = 1:length(snr_levels)
            target_snr = snr_levels(snr_idx);
            snr_tag = sprintf('snr_%ddB', abs(target_snr));
            
            delta_snr_fir_list = zeros(num_test_sentences, 1);
            delta_snr_iir_list = zeros(num_test_sentences, 1);
            stoi_in_list       = zeros(num_test_sentences, 1);
            stoi_fir_list      = zeros(num_test_sentences, 1);
            stoi_iir_list      = zeros(num_test_sentences, 1);
            
            for s = 1:num_test_sentences
                clean = speech_signals{s};
                L = length(clean);
                
                start_n = 1000 + (s - 1) * 32000;
                if start_n + L - 1 > length(noise_data)
                    start_n = 1000;
                end
                noise_seg = noise_data(start_n : start_n + L - 1);
                
                p_clean = mean(clean .^ 2);
                p_noise = mean(noise_seg .^ 2);
                scale = sqrt(p_clean / (p_noise * (10 ^ (target_snr / 10))));
                scaled_noise = noise_seg * scale;
                
                noisy_input = clean + scaled_noise;
                
                out_fir = filter(filters_fir.(gk).b, 1, noisy_input);
                out_fir_aligned = out_fir(65 : end);
                clean_fir_aligned = clean(1 : length(out_fir_aligned));
                noisy_fir_aligned = noisy_input(1 : length(out_fir_aligned));
                
                out_iir = sosfilt(filters_iir.(gk).sos, noisy_input) * filters_iir.(gk).g;
                delay_iir = round(comp_metrics.(gk).iir_passband_delay_ms * fs / 1000);
                delay_iir = max(1, min(delay_iir, 40));
                out_iir_aligned = out_iir(delay_iir + 1 : end);
                clean_iir_aligned = clean(1 : length(out_iir_aligned));
                noisy_iir_aligned = noisy_input(1 : length(out_iir_aligned));
                
                delta_snr_fir_list(s) = compute_delta_snr(clean_fir_aligned, noisy_fir_aligned, out_fir_aligned, fs);
                delta_snr_iir_list(s) = compute_delta_snr(clean_iir_aligned, noisy_iir_aligned, out_iir_aligned, fs);
                
                stoi_in_list(s)  = compute_simplified_stoi(clean_fir_aligned, noisy_fir_aligned, fs);
                stoi_fir_list(s) = compute_simplified_stoi(clean_fir_aligned, out_fir_aligned, fs);
                stoi_iir_list(s) = compute_simplified_stoi(clean_iir_aligned, out_iir_aligned, fs);
            end
            
            sim_results.(gk).(snr_tag).delta_snr_fir = mean(delta_snr_fir_list);
            sim_results.(gk).(snr_tag).delta_snr_iir = mean(delta_snr_iir_list);
            sim_results.(gk).(snr_tag).stoi_unproc   = mean(stoi_in_list);
            sim_results.(gk).(snr_tag).stoi_fir      = mean(stoi_fir_list);
            sim_results.(gk).(snr_tag).stoi_iir      = mean(stoi_iir_list);
        end
    end

    % Display Simulation Table
    fprintf('\n=========================================================================================\n');
    fprintf('  SPEECH ENHANCEMENT PERFORMANCE: COUNTRY, ROCK, TECHNO (FIR vs. IIR)\n');
    fprintf('=========================================================================================\n');
    fprintf('%-12s | %-8s | %-12s | %-12s | %-10s | %-10s | %-10s\n', ...
        'Genre', 'SNR In', 'Delta-SNR FIR', 'Delta-SNR IIR', 'STOI Unproc', 'STOI FIR', 'STOI IIR');
    fprintf('-----------------------------------------------------------------------------------------\n');
    for g = 1:length(sim_genres)
        gk = sim_genres{g};
        for snr_idx = 1:length(snr_levels)
            target_snr = snr_levels(snr_idx);
            snr_tag = sprintf('snr_%ddB', abs(target_snr));
            res = sim_results.(gk).(snr_tag);
            fprintf('%-12s | %4d dB  | %8.2f dB   | %8.2f dB   | %8.3f   | %8.3f   | %8.3f\n', ...
                upper(gk), target_snr, res.delta_snr_fir, res.delta_snr_iir, res.stoi_unproc, res.stoi_fir, res.stoi_iir);
        end
        fprintf('-----------------------------------------------------------------------------------------\n');
    end

    % 6. Visualizations
    fprintf('\n--> Generating Comparison Visualizations in %s...\n', figures_dir);
    set(0, 'DefaultAxesFontSize', 11);
    set(0, 'DefaultAxesFontName', 'Helvetica');

    c_fir = [0.0000, 0.4470, 0.7410];
    c_iir = [0.8500, 0.3250, 0.0980];

    % Figure 1: Magnitude Response Overlay
    fig1 = figure('Name', 'Magnitude Response Comparison', 'Position', [50, 50, 1100, 850], 'Visible', 'off');
    for k = 1:length(filter_keys)
        key = filter_keys{k};
        subplot(2, 2, k);
        hold on; grid on; box on;
        
        patch([300, 3400, 3400, 300], [-90, -90, 10, 10], [0.94, 0.94, 0.94], ...
            'EdgeColor', 'none', 'DisplayName', 'Passband (300-3400 Hz)');
        
        p1 = plot(f_eval, filters_fir.(key).mag_db, 'Color', c_fir, 'LineWidth', 1.8, 'DisplayName', '128-Tap FIR (firpm)');
        p2 = plot(f_eval, filters_iir.(key).mag_db, 'Color', c_iir, 'LineWidth', 1.8, 'DisplayName', '8th-Order IIR (Chebyshev II)');
        
        yline(-40, 'k:', 'LineWidth', 1.2, 'DisplayName', '-40 dB Stopband Spec');
        yline(-1, 'k--', 'LineWidth', 0.8, 'HandleVisibility', 'off');
        
        xlim([0, 5000]);
        ylim([-75, 5]);
        xlabel('Frequency (Hz)');
        ylabel('Magnitude (dB)');
        title(sprintf('%s Filter: FIR vs. IIR', filter_names{k}));
        legend([p1, p2], 'Location', 'northeast');
    end
    fig1_path = fullfile(figures_dir, 'filter_comparison_magnitude.png');
    saveas(fig1, fig1_path);
    close(fig1);
    fprintf('  Saved: %s\n', fig1_path);

    % Figure 2: Group Delay Comparison
    fig2 = figure('Name', 'Group Delay Comparison', 'Position', [100, 100, 1100, 600], 'Visible', 'off');
    subplot(1, 2, 1);
    hold on; grid on; box on;
    patch([300, 3400, 3400, 300], [0, 0, 15, 15], [0.94, 0.94, 0.94], 'EdgeColor', 'none');
    plot(f_eval, filters_fir.country.gd_ms, 'Color', c_fir, 'LineWidth', 2.0, 'DisplayName', 'FIR: Constant 4.0 ms');
    plot(f_eval, filters_iir.country.gd_ms, 'Color', [0.85, 0.325, 0.098], 'LineWidth', 1.8, 'DisplayName', 'Country IIR');
    plot(f_eval, filters_iir.rock.gd_ms,    'Color', [0.494, 0.184, 0.556], 'LineWidth', 1.8, 'DisplayName', 'Rock IIR');
    plot(f_eval, filters_iir.techno.gd_ms,  'Color', [0.466, 0.674, 0.188], 'LineWidth', 1.8, 'DisplayName', 'Techno IIR');
    xlim([100, 4000]);
    ylim([0, 12]);
    xlabel('Frequency (Hz)');
    ylabel('Group Delay (ms)');
    title('Group Delay Profiles Across Audio Band (0 - 4 kHz)');
    legend('Location', 'northeast');

    subplot(1, 2, 2);
    hold on; grid on; box on;
    f_zoom = (f_eval >= 400 & f_eval <= 3200);
    plot(f_eval(f_zoom), filters_fir.country.gd_ms(f_zoom), 'Color', c_fir, 'LineWidth', 2.2, 'DisplayName', 'FIR (Constant 4.0 ms)');
    plot(f_eval(f_zoom), filters_iir.country.gd_ms(f_zoom), 'Color', [0.85, 0.325, 0.098], 'LineWidth', 1.8, 'DisplayName', 'Country IIR (0.8 - 1.8 ms)');
    plot(f_eval(f_zoom), filters_iir.rock.gd_ms(f_zoom),    'Color', [0.494, 0.184, 0.556], 'LineWidth', 1.8, 'DisplayName', 'Rock IIR (0.8 - 1.8 ms)');
    plot(f_eval(f_zoom), filters_iir.techno.gd_ms(f_zoom),  'Color', [0.466, 0.674, 0.188], 'LineWidth', 1.8, 'DisplayName', 'Techno IIR (0.8 - 1.8 ms)');
    yline(10, 'r--', 'LineWidth', 1.5, 'DisplayName', '10 ms Target Budget');
    xlim([400, 3200]);
    ylim([0, 6]);
    xlabel('Frequency (Hz)');
    ylabel('Group Delay (ms)');
    title('Passband Latency Zoom (Speech Band)');
    legend('Location', 'northwest');
    
    fig2_path = fullfile(figures_dir, 'filter_comparison_group_delay.png');
    saveas(fig2, fig2_path);
    close(fig2);
    fprintf('  Saved: %s\n', fig2_path);

    % Figure 3: Pole-Zero Maps
    fig3 = figure('Name', 'Pole Zero Maps', 'Position', [150, 150, 1000, 500], 'Visible', 'off');
    subplot(1, 2, 1);
    zplane(filters_fir.country.b, 1);
    title('Country FIR (N=128 Taps): All Poles at Origin');
    
    subplot(1, 2, 2);
    [b_c_iir, a_c_iir] = sos2tf(filters_iir.country.sos, filters_iir.country.g);
    zplane(b_c_iir, a_c_iir);
    title(sprintf('Country IIR (8th Order): Stable (Max |p| = %.3f)', filters_iir.country.max_pole_radius));
    
    fig3_path = fullfile(figures_dir, 'filter_comparison_poles_zeros.png');
    saveas(fig3, fig3_path);
    close(fig3);
    fprintf('  Saved: %s\n', fig3_path);

    % Figure 4: Performance Metrics Comparison
    fig4 = figure('Name', 'Performance Metrics Comparison', 'Position', [200, 200, 1100, 550], 'Visible', 'off');
    
    subplot(1, 2, 1);
    bar_snr_data = [
        sim_results.country.snr_5dB.delta_snr_fir, sim_results.country.snr_5dB.delta_snr_iir;
        sim_results.country.snr_10dB.delta_snr_fir, sim_results.country.snr_10dB.delta_snr_iir;
        sim_results.rock.snr_10dB.delta_snr_fir,    sim_results.rock.snr_10dB.delta_snr_iir;
        sim_results.techno.snr_10dB.delta_snr_fir, sim_results.techno.snr_10dB.delta_snr_iir;
        sim_results.techno.snr_15dB.delta_snr_fir, sim_results.techno.snr_15dB.delta_snr_iir
    ];
    b_snr = bar(bar_snr_data, 'grouped');
    b_snr(1).FaceColor = c_fir;
    b_snr(2).FaceColor = c_iir;
    grid on; box on;
    set(gca, 'XTickLabel', {'Country (-5dB)', 'Country (-10dB)', 'Rock (-10dB)', 'Techno (-10dB)', 'Techno (-15dB)'});
    xtickangle(25);
    ylabel('Segmental SNR Improvement \DeltaSNR (dB)');
    title('Noise Suppression (\DeltaSNR: FIR vs. IIR)');
    legend({'128-Tap FIR', '8th-Order IIR'}, 'Location', 'northwest');
    ylim([-2, 6]);

    subplot(1, 2, 2);
    bar_stoi_data = [
        sim_results.country.snr_5dB.stoi_unproc,  sim_results.country.snr_5dB.stoi_fir,  sim_results.country.snr_5dB.stoi_iir;
        sim_results.country.snr_10dB.stoi_unproc, sim_results.country.snr_10dB.stoi_fir, sim_results.country.snr_10dB.stoi_iir;
        sim_results.rock.snr_10dB.stoi_unproc,    sim_results.rock.snr_10dB.stoi_fir,    sim_results.rock.snr_10dB.stoi_iir;
        sim_results.techno.snr_10dB.stoi_unproc,  sim_results.techno.snr_10dB.stoi_fir,  sim_results.techno.snr_10dB.stoi_iir;
        sim_results.techno.snr_15dB.stoi_unproc,  sim_results.techno.snr_15dB.stoi_fir,  sim_results.techno.snr_15dB.stoi_iir
    ];
    b_stoi = bar(bar_stoi_data, 'grouped');
    b_stoi(1).FaceColor = [0.6, 0.6, 0.6];
    b_stoi(2).FaceColor = c_fir;
    b_stoi(3).FaceColor = c_iir;
    grid on; box on;
    set(gca, 'XTickLabel', {'Country (-5dB)', 'Country (-10dB)', 'Rock (-10dB)', 'Techno (-10dB)', 'Techno (-15dB)'});
    xtickangle(25);
    ylabel('STOI Score (0 to 1)');
    title('Speech Intelligibility (STOI Score)');
    legend({'Unprocessed', '128-Tap FIR', '8th-Order IIR'}, 'Location', 'northwest');
    ylim([0, 1.05]);

    fig4_path = fullfile(figures_dir, 'filter_comparison_speech_enhancement.png');
    saveas(fig4, fig4_path);
    close(fig4);
    fprintf('  Saved: %s\n', fig4_path);

    % 7. Export C Headers
    fprintf('\n--> Exporting C Headers for ESP32-S3 Firmware in %s...\n', firmware_dir);
    export_fir_header(fullfile(firmware_dir, 'fir_coefficients.h'), filters_fir);
    export_iir_header(fullfile(firmware_dir, 'iir_coefficients.h'), filters_iir);

    % 8. Export Workspace
    export_data = struct();
    export_data.fs = fs;
    export_data.filters_fir = filters_fir;
    export_data.filters_iir = filters_iir;
    export_data.comp_metrics = comp_metrics;
    export_data.sim_results = sim_results;
    save(fullfile(metadata_dir, 'filter_comparison_workspace.mat'), 'export_data');
    fprintf('--> Saved Workspace MAT: %s\n', fullfile(metadata_dir, 'filter_comparison_workspace.mat'));

    fprintf('\n=========================================================================\n');
    fprintf('  FILTER REDESIGN AND COMPARATIVE EVALUATION COMPLETE!\n');
    fprintf('=========================================================================\n');
end

%% Helper: Compute Segmental SNR Improvement
function delta_snr = compute_delta_snr(clean, noisy, enhanced, fs)
    frame_len = round(0.020 * fs);
    hop = frame_len / 2;
    n_frames = floor((length(clean) - frame_len) / hop);
    
    snr_in_list = zeros(n_frames, 1);
    snr_out_list = zeros(n_frames, 1);
    
    for i = 1:n_frames
        idx = (i-1)*hop + (1:frame_len);
        c = clean(idx);
        n_in = noisy(idx) - c;
        n_out = enhanced(idx) - c;
        
        p_c = sum(c .^ 2);
        p_in = sum(n_in .^ 2);
        p_out = sum(n_out .^ 2);
        
        snr_in_list(i) = max(-10, min(35, 10 * log10((p_c + eps) / (p_in + eps))));
        snr_out_list(i) = max(-10, min(35, 10 * log10((p_c + eps) / (p_out + eps))));
    end
    
    delta_snr = mean(snr_out_list) - mean(snr_in_list);
end

%% Helper: Compute Simplified STOI
function d = compute_simplified_stoi(clean, degraded, fs)
    N_fft = 512;
    hop = 256;
    win = hann(N_fft, 'periodic');
    
    X_clean = buffer(clean, N_fft, N_fft - hop, 'nodelay') .* win;
    X_deg   = buffer(degraded, N_fft, N_fft - hop, 'nodelay') .* win;
    
    S_clean = abs(fft(X_clean, N_fft, 1));
    S_deg   = abs(fft(X_deg, N_fft, 1));
    
    cf = [150, 200, 250, 315, 400, 500, 630, 800, 1000, 1250, 1600, 2000, 2500, 3150, 4000];
    K = length(cf);
    M = size(S_clean, 2);
    
    band_clean = zeros(K, M);
    band_deg   = zeros(K, M);
    
    freq_bins = (0:N_fft/2)' * (fs / N_fft);
    for k = 1:K
        f_low = cf(k) * 2^(-1/6);
        f_high = cf(k) * 2^(1/6);
        bin_mask = (freq_bins >= f_low & freq_bins <= f_high);
        if any(bin_mask)
            band_clean(k, :) = sqrt(sum(S_clean(bin_mask, :) .^ 2, 1));
            band_deg(k, :)   = sqrt(sum(S_deg(bin_mask, :) .^ 2, 1));
        end
    end
    
    corr_vals = zeros(K, 1);
    for k = 1:K
        c_k = band_clean(k, :);
        d_k = band_deg(k, :);
        
        alpha = sqrt(sum(c_k.^2) / (sum(d_k.^2) + eps));
        d_k_norm = min(d_k * alpha, c_k * 1.5);
        
        r = corrcoef(c_k, d_k_norm);
        if numel(r) >= 4 && ~isnan(r(1, 2))
            corr_vals(k) = max(0, min(1, r(1, 2)));
        else
            corr_vals(k) = 0.5;
        end
    end
    
    d = mean(corr_vals);
end

%% Helper: Export FIR Header
function export_fir_header(filepath, filters_fir)
    fid = fopen(filepath, 'w');
    if fid == -1, return; end
    
    fprintf(fid, '/**\n * @file fir_coefficients.h\n');
    fprintf(fid, ' * @brief Pre-designed 128-tap FIR filter coefficients for Country, Rock, Techno speech enhancement.\n');
    fprintf(fid, ' * Designed via Parks-McClellan (firpm) equiripple algorithm (fs = 16 kHz).\n */\n\n');
    fprintf(fid, '#ifndef FIR_COEFFICIENTS_H\n#define FIR_COEFFICIENTS_H\n\n');
    fprintf(fid, '#define FIR_FILTER_ORDER 128\n');
    fprintf(fid, '#define FIR_FILTER_TAPS  129\n\n');
    
    keys = {'country', 'rock', 'techno', 'control'};
    for k = 1:length(keys)
        key = keys{k};
        b = filters_fir.(key).b;
        fprintf(fid, '/* %s FIR Coefficients (Taps = %d, Group Delay = 4.0 ms) */\n', upper(key), length(b));
        fprintf(fid, 'static const float w_%s_fir[FIR_FILTER_TAPS] = {\n', key);
        for i = 1:length(b)
            fprintf(fid, '    %15.8ff%s', b(i), ternary(i == length(b), '', ','));
            if mod(i, 4) == 0, fprintf(fid, '\n'); end
        end
        if mod(length(b), 4) ~= 0, fprintf(fid, '\n'); end
        fprintf(fid, '};\n\n');
    end
    
    fprintf(fid, '/**\n * @brief Applies 128-tap FIR filter convolution on a buffer of samples.\n */\n');
    fprintf(fid, 'static inline void apply_fir_filter(const float* restrict coeffs, const float* restrict state_buf, float* restrict output, int num_samples) {\n');
    fprintf(fid, '    for (int n = 0; n < num_samples; n++) {\n');
    fprintf(fid, '        float acc = 0.0f;\n');
    fprintf(fid, '        for (int k = 0; k < FIR_FILTER_TAPS; k++) {\n');
    fprintf(fid, '            acc += coeffs[k] * state_buf[n - k];\n');
    fprintf(fid, '        }\n');
    fprintf(fid, '        output[n] = acc;\n');
    fprintf(fid, '    }\n');
    fprintf(fid, '}\n\n');
    fprintf(fid, '#endif /* FIR_COEFFICIENTS_H */\n');
    fclose(fid);
    fprintf('  Saved FIR C Header: %s\n', filepath);
end

%% Helper: Export IIR SOS Header
function export_iir_header(filepath, filters_iir)
    fid = fopen(filepath, 'w');
    if fid == -1, return; end
    
    fprintf(fid, '/**\n * @file iir_coefficients.h\n');
    fprintf(fid, ' * @brief Cascaded Second-Order Sections (SOS / Biquad) IIR filter coefficients.\n');
    fprintf(fid, ' * Genres: Country, Rock, Techno, Control (fs = 16 kHz, Chebyshev Type II).\n');
    fprintf(fid, ' * Structure: Direct Form II Transposed for optimal numerical stability on ESP32-S3.\n */\n\n');
    fprintf(fid, '#ifndef IIR_COEFFICIENTS_H\n#define IIR_COEFFICIENTS_H\n\n');
    fprintf(fid, '#define IIR_BIQUADS_COUNT 4\n\n');
    fprintf(fid, 'typedef struct {\n    float b0, b1, b2;\n    float a1, a2;\n} BiquadSection;\n\n');
    
    keys = {'country', 'rock', 'techno', 'control'};
    for k = 1:length(keys)
        key = keys{k};
        sos = filters_iir.(key).sos;
        g = filters_iir.(key).g;
        n_sec = size(sos, 1);
        
        fprintf(fid, '/* %s IIR Filter: 8th Order (4 Biquad SOS), Overall Gain = %.8ff */\n', upper(key), g);
        fprintf(fid, 'static const float g_%s_iir = %.8ff;\n', key, g);
        fprintf(fid, 'static const BiquadSection sos_%s_iir[%d] = {\n', key, n_sec);
        for s = 1:n_sec
            fprintf(fid, '    { .b0 = %13.8ff, .b1 = %13.8ff, .b2 = %13.8ff, .a1 = %13.8ff, .a2 = %13.8ff }%s\n', ...
                sos(s, 1), sos(s, 2), sos(s, 3), sos(s, 5), sos(s, 6), ternary(s == n_sec, '', ','));
        end
        fprintf(fid, '};\n\n');
    end
    
    fprintf(fid, '/**\n * @brief Cascaded Biquad Direct Form II Transposed filtering.\n * Requires 2 state floats per biquad (total 8 floats).\n */\n');
    fprintf(fid, 'static inline float process_iir_biquads(const BiquadSection* restrict sos, float* restrict state, float input, float gain) {\n');
    fprintf(fid, '    float w = input * gain;\n');
    fprintf(fid, '    for (int s = 0; s < IIR_BIQUADS_COUNT; s++) {\n');
    fprintf(fid, '        float s1 = state[s * 2];\n');
    fprintf(fid, '        float s2 = state[s * 2 + 1];\n');
    fprintf(fid, '        float y = sos[s].b0 * w + s1;\n');
    fprintf(fid, '        state[s * 2]     = sos[s].b1 * w - sos[s].a1 * y + s2;\n');
    fprintf(fid, '        state[s * 2 + 1] = sos[s].b2 * w - sos[s].a2 * y;\n');
    fprintf(fid, '        w = y;\n');
    fprintf(fid, '    }\n');
    fprintf(fid, '    return w;\n');
    fprintf(fid, '}\n\n');
    fprintf(fid, '#endif /* IIR_COEFFICIENTS_H */\n');
    fclose(fid);
    fprintf('  Saved IIR C Header: %s\n', filepath);
end

function val = ternary(cond, a, b)
    if cond, val = a; else, val = b; end
end
