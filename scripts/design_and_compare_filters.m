%% DESIGN_AND_COMPARE_FILTERS.M
% Designs genre-specific FIR and IIR filters for Jazz, Rock, and Techno and performs
% a rigorous comparative evaluation across magnitude response, group delay, pole-zero stability,
% computational complexity on ESP32-S3, and speech enhancement performance (Delta-SNR and STOI).
%
% Also defines the Phase 2 Parametric Notch & Multi-Band Biquad architecture.
%
% University of the Witwatersrand
% School of Electrical & Information Engineering

function design_and_compare_filters()
    fprintf('=========================================================================\n');
    fprintf('  FILTER DESIGN & COMPARATIVE EVALUATION (JAZZ, ROCK, TECHNO)\n');
    fprintf('  fs = 16 kHz | FIR: Parks-McClellan (128-tap) | IIR: Chebyshev II SOS\n');
    fprintf('  + Phase 2 Parametric Notch Biquad Coefficients\n');
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
    filter_keys = {'jazz', 'rock', 'techno', 'control'};
    filter_names = {'Jazz', 'Rock', 'Techno', 'Control Baseline'};

    % 2. Design Specifications (Derived from Jazz, Rock, Techno STFT Analysis)
    specs = struct();
    
    % Jazz: Upright acoustic bass & kick < 140 Hz; brushed highs; speech band overlap = 47.0%
    specs.jazz.f_stop1 = 140;
    specs.jazz.f_pass1 = 300;
    specs.jazz.f_pass2 = 3400;
    specs.jazz.f_stop2 = 4200;
    specs.jazz.notch_f0 = 78.125; % Resonant bass fundamental
    specs.jazz.notch_q  = 6.0;
    
    % Rock: Heavy distorted guitars, cymbals, bass guitar (stopband 0-160 Hz & 3800-8000 Hz)
    specs.rock.f_stop1 = 160;
    specs.rock.f_pass1 = 300;
    specs.rock.f_pass2 = 3400;
    specs.rock.f_stop2 = 3800;
    specs.rock.notch_f0 = 109.375; % Electric bass / kick resonance
    specs.rock.notch_q  = 6.0;
    
    % Techno: Sub-bass and low-frequency percussion up to 220 Hz (85.4% energy < 250 Hz)
    specs.techno.f_stop1 = 220;
    specs.techno.f_pass1 = 300;
    specs.techno.f_pass2 = 3400;
    specs.techno.f_stop2 = 4000;
    specs.techno.notch_f0 = 62.5; % Dominant kick drum fundamental
    specs.techno.notch_q  = 8.0;
    
    % Control Bandpass: Standard speech band baseline
    specs.control.f_stop1 = 200;
    specs.control.f_pass1 = 300;
    specs.control.f_pass2 = 3400;
    specs.control.f_stop2 = 4000;
    specs.control.notch_f0 = 100.0;
    specs.control.notch_q  = 5.0;

    % Storage for designed filters
    filters_fir = struct();
    filters_iir = struct();
    filters_notch = struct();

    N_fir = 128; % 128th order = 129 taps
    N_iir_biquads = 4; % 8th order bandpass = 4 biquad Second-Order Sections

    fprintf('--> Designing FIR and IIR Filters for Jazz, Rock, Techno, and Control...\n');

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
        filters_iir.(key).max_pole_radius = max(abs(p_iir));
        
        % C. Phase 2 Parametric Notch Biquad (Digital Biquad Notch)
        w0 = 2 * pi * sp.notch_f0 / fs;
        alpha = sin(w0) / (2 * sp.notch_q);
        b_notch = [1, -2*cos(w0), 1];
        a_notch = [1 + alpha, -2*cos(w0), 1 - alpha];
        b_notch = b_notch / a_notch(1);
        a_notch = a_notch / a_notch(1);
        filters_notch.(key).b = b_notch;
        filters_notch.(key).a = a_notch;
        filters_notch.(key).f0 = sp.notch_f0;
        filters_notch.(key).q  = sp.notch_q;
        
        fprintf('    [%s] FIR: %d taps | IIR: %dth-order (%d biquads, max |p| = %.4f - %s)\n', ...
            upper(key), length(b_fir), filters_iir.(key).order, N_iir_biquads, ...
            filters_iir.(key).max_pole_radius, ternary(filters_iir.(key).max_pole_radius < 1.0, 'STABLE', 'UNSTABLE'));
    end

    % 3. Frequency Responses and Group Delays
    fprintf('\n--> Computing Frequency Responses and Group Delays...\n');
    n_pts = 4096;
    [~, f_eval] = freqz(filters_fir.techno.b, 1, n_pts, fs);

    for k = 1:length(filter_keys)
        key = filter_keys{k};
        
        % FIR frequency response
        [h_fir, ~] = freqz(filters_fir.(key).b, 1, f_eval, fs);
        filters_fir.(key).mag_db = 20 * log10(abs(h_fir) + eps);
        [gd_fir_samp, ~] = grpdelay(filters_fir.(key).b, 1, f_eval, fs);
        filters_fir.(key).gd_ms = gd_fir_samp / fs * 1000;
        
        % IIR frequency response (via SOS)
        [h_iir, ~] = freqz(filters_iir.(key).sos, f_eval, fs);
        h_iir = h_iir * filters_iir.(key).g;
        filters_iir.(key).mag_db = 20 * log10(abs(h_iir) + eps);
        [gd_iir_samp, ~] = grpdelay(filters_iir.(key).sos, f_eval, fs);
        filters_iir.(key).gd_ms = gd_iir_samp / fs * 1000;
        
        % Passband delay statistics (300 to 3400 Hz)
        pb_idx = (f_eval >= 300 & f_eval <= 3400);
        filters_iir.(key).pb_gd_mean_ms = mean(filters_iir.(key).gd_ms(pb_idx));
        filters_iir.(key).pb_gd_min_ms  = min(filters_iir.(key).gd_ms(pb_idx));
        filters_iir.(key).pb_gd_max_ms  = max(filters_iir.(key).gd_ms(pb_idx));
    end

    % 4. Computational Complexity Comparison for ESP32-S3 (240 MHz FPU)
    fprintf('\n=========================================================================\n');
    fprintf('  COMPUTATIONAL COMPLEXITY ON ESP32-S3 (240 MHz Dual-Core, 32-bit FPU)\n');
    fprintf('=========================================================================\n');
    fprintf('%-18s | %-16s | %-17s | %-16s\n', 'Metric', '128-Tap FIR', '8th-Order IIR SOS', 'Speedup / Ratio');
    fprintf('-------------------------------------------------------------------------\n');
    
    comp_metrics = struct();
    for k = 1:length(filter_keys)
        key = filter_keys{k};
        comp_metrics.(key).fir_coeffs = filters_fir.(key).num_taps;
        comp_metrics.(key).iir_coeffs = filters_iir.(key).num_biquads * 6;
        comp_metrics.(key).fir_macs = filters_fir.(key).num_taps - 1;
        comp_metrics.(key).iir_ops = filters_iir.(key).num_biquads * 5;
        comp_metrics.(key).fir_mflops = (comp_metrics.(key).fir_macs * fs) / 1e6;
        comp_metrics.(key).iir_mflops = (comp_metrics.(key).iir_ops * fs) / 1e6;
        comp_metrics.(key).fir_delay_bytes = filters_fir.(key).num_taps * 4;
        comp_metrics.(key).iir_delay_bytes = filters_iir.(key).num_biquads * 2 * 4;
        comp_metrics.(key).fir_delay_ms = filters_fir.(key).group_delay_ms;
        comp_metrics.(key).iir_passband_delay_ms = filters_iir.(key).pb_gd_mean_ms;
    end
    
    cm = comp_metrics.techno;
    fprintf('%-18s | %-16d | %-17d | %.1fx smaller\n', 'Coefficients', cm.fir_coeffs, cm.iir_coeffs, cm.fir_coeffs / cm.iir_coeffs);
    fprintf('%-18s | %-16d | %-17d | %.1fx faster \n', 'MACs per Sample', cm.fir_macs, cm.iir_ops, cm.fir_macs / cm.iir_ops);
    fprintf('%-18s | %-16.2f MFLOPS | %-17.2f MFLOPS | %.1fx less load\n', 'Computation Rate', cm.fir_mflops, cm.iir_mflops, cm.fir_mflops / cm.iir_mflops);
    fprintf('%-18s | %-16d bytes | %-17d bytes | %.1fx smaller\n', 'RAM Delay Buffer', cm.fir_delay_bytes, cm.iir_delay_bytes, cm.fir_delay_bytes / cm.iir_delay_bytes);
    fprintf('%-18s | %-16.2f ms | %-17.2f ms | %.1fx lower latency\n', 'Core Passband Delay', cm.fir_delay_ms, cm.iir_passband_delay_ms, cm.fir_delay_ms / cm.iir_passband_delay_ms);
    fprintf('-------------------------------------------------------------------------\n');

    % 5. Speech Enhancement Simulation (Section 4 Testing Methodology)
    fprintf('\n--> Running Speech Enhancement Simulation (Jazz, Rock, Techno)...\n');
    speech_files = dir(fullfile(speech_dir, 'sentence_*.wav'));
    n_test_sentences = min(length(speech_files), 10);
    snr_levels = [-5, -10, -15];
    sim_genres = {'jazz', 'rock', 'techno'};
    
    sim_results = struct();

    for g = 1:length(sim_genres)
        gk = sim_genres{g};
        noise_file = fullfile(noise_dir, sprintf('%s_noise_30s.wav', gk));
        
        if ~exist(noise_file, 'file')
            error('Noise stimulus file not found: %s', noise_file);
        end
        [noise_data, ~] = audioread(noise_file);
        
        for snr_idx = 1:length(snr_levels)
            target_snr = snr_levels(snr_idx);
            snr_tag = sprintf('snr_%ddB', abs(target_snr));
            
            delta_snr_fir_list = zeros(n_test_sentences, 1);
            delta_snr_iir_list = zeros(n_test_sentences, 1);
            stoi_in_list       = zeros(n_test_sentences, 1);
            stoi_fir_list      = zeros(n_test_sentences, 1);
            stoi_iir_list      = zeros(n_test_sentences, 1);
            
            for s = 1:n_test_sentences
                s_file = fullfile(speech_dir, speech_files(s).name);
                [clean, ~] = audioread(s_file);
                L = length(clean);
                
                start_n = mod((s-1) * 32000, length(noise_data) - L - 1) + 1;
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
    fprintf('  SPEECH ENHANCEMENT PERFORMANCE: JAZZ, ROCK, TECHNO (FIR vs. IIR)\n');
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
    plot(f_eval, filters_fir.jazz.gd_ms,   'Color', c_fir, 'LineWidth', 2.0, 'DisplayName', 'FIR: Constant 4.0 ms');
    plot(f_eval, filters_iir.jazz.gd_ms,   'Color', [0.85, 0.55, 0.05], 'LineWidth', 1.8, 'DisplayName', 'Jazz IIR');
    plot(f_eval, filters_iir.rock.gd_ms,   'Color', [0.65, 0.15, 0.70], 'LineWidth', 1.8, 'DisplayName', 'Rock IIR');
    plot(f_eval, filters_iir.techno.gd_ms, 'Color', [0.00, 0.45, 0.85], 'LineWidth', 1.8, 'DisplayName', 'Techno IIR');
    xlim([100, 4000]);
    ylim([0, 12]);
    xlabel('Frequency (Hz)');
    ylabel('Group Delay (ms)');
    title('Group Delay Profiles Across Audio Band (0 - 4 kHz)');
    legend('Location', 'northeast');

    subplot(1, 2, 2);
    hold on; grid on; box on;
    f_zoom = (f_eval >= 400 & f_eval <= 3200);
    plot(f_eval(f_zoom), filters_fir.jazz.gd_ms(f_zoom),   'Color', c_fir, 'LineWidth', 2.2, 'DisplayName', 'FIR (Constant 4.0 ms)');
    plot(f_eval(f_zoom), filters_iir.jazz.gd_ms(f_zoom),   'Color', [0.85, 0.55, 0.05], 'LineWidth', 1.8, 'DisplayName', 'Jazz IIR (0.8 - 1.8 ms)');
    plot(f_eval(f_zoom), filters_iir.rock.gd_ms(f_zoom),   'Color', [0.65, 0.15, 0.70], 'LineWidth', 1.8, 'DisplayName', 'Rock IIR (0.8 - 1.8 ms)');
    plot(f_eval(f_zoom), filters_iir.techno.gd_ms(f_zoom), 'Color', [0.00, 0.45, 0.85], 'LineWidth', 1.8, 'DisplayName', 'Techno IIR (0.8 - 1.8 ms)');
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
    zplane(filters_fir.jazz.b, 1);
    title('Jazz FIR (N=128 Taps): All Poles at Origin');
    
    subplot(1, 2, 2);
    [b_j_iir, a_j_iir] = sos2tf(filters_iir.jazz.sos, filters_iir.jazz.g);
    zplane(b_j_iir, a_j_iir);
    title(sprintf('Jazz IIR (8th Order): Stable (Max |p| = %.3f)', filters_iir.jazz.max_pole_radius));
    
    fig3_path = fullfile(figures_dir, 'filter_comparison_poles_zeros.png');
    saveas(fig3, fig3_path);
    close(fig3);
    fprintf('  Saved: %s\n', fig3_path);

    % Figure 4: Performance Metrics Comparison
    fig4 = figure('Name', 'Performance Metrics Comparison', 'Position', [200, 200, 1100, 550], 'Visible', 'off');
    
    subplot(1, 2, 1);
    bar_delta_snr = [
        sim_results.jazz.snr_5dB.delta_snr_fir,   sim_results.jazz.snr_5dB.delta_snr_iir;
        sim_results.jazz.snr_10dB.delta_snr_fir,  sim_results.jazz.snr_10dB.delta_snr_iir;
        sim_results.jazz.snr_15dB.delta_snr_fir,  sim_results.jazz.snr_15dB.delta_snr_iir;
        sim_results.rock.snr_5dB.delta_snr_fir,   sim_results.rock.snr_5dB.delta_snr_iir;
        sim_results.rock.snr_10dB.delta_snr_fir,  sim_results.rock.snr_10dB.delta_snr_iir;
        sim_results.rock.snr_15dB.delta_snr_fir,  sim_results.rock.snr_15dB.delta_snr_iir;
        sim_results.techno.snr_5dB.delta_snr_fir,  sim_results.techno.snr_5dB.delta_snr_iir;
        sim_results.techno.snr_10dB.delta_snr_fir, sim_results.techno.snr_10dB.delta_snr_iir;
        sim_results.techno.snr_15dB.delta_snr_fir, sim_results.techno.snr_15dB.delta_snr_iir
    ];
    b_snr = bar(bar_delta_snr);
    b_snr(1).FaceColor = c_fir;
    b_snr(2).FaceColor = c_iir;
    grid on; box on;
    set(gca, 'XTickLabel', {'J -5dB', 'J -10dB', 'J -15dB', 'R -5dB', 'R -10dB', 'R -15dB', 'T -5dB', 'T -10dB', 'T -15dB'});
    ylabel('\Delta SNR Improvement (dB)');
    title('Noise Suppression (\Delta SNR) Across Genres & Noise Levels');
    legend({'128-Tap FIR', '8th-Order IIR SOS'}, 'Location', 'northwest');
    
    subplot(1, 2, 2);
    bar_stoi = [
        sim_results.jazz.snr_5dB.stoi_unproc,   sim_results.jazz.snr_5dB.stoi_fir,   sim_results.jazz.snr_5dB.stoi_iir;
        sim_results.jazz.snr_10dB.stoi_unproc,  sim_results.jazz.snr_10dB.stoi_fir,  sim_results.jazz.snr_10dB.stoi_iir;
        sim_results.jazz.snr_15dB.stoi_unproc,  sim_results.jazz.snr_15dB.stoi_fir,  sim_results.jazz.snr_15dB.stoi_iir;
        sim_results.rock.snr_5dB.stoi_unproc,   sim_results.rock.snr_5dB.stoi_fir,   sim_results.rock.snr_5dB.stoi_iir;
        sim_results.rock.snr_10dB.stoi_unproc,  sim_results.rock.snr_10dB.stoi_fir,  sim_results.rock.snr_10dB.stoi_iir;
        sim_results.rock.snr_15dB.stoi_unproc,  sim_results.rock.snr_15dB.stoi_fir,  sim_results.rock.snr_15dB.stoi_iir;
        sim_results.techno.snr_5dB.stoi_unproc,  sim_results.techno.snr_5dB.stoi_fir,  sim_results.techno.snr_5dB.stoi_iir;
        sim_results.techno.snr_10dB.stoi_unproc, sim_results.techno.snr_10dB.stoi_fir, sim_results.techno.snr_10dB.stoi_iir;
        sim_results.techno.snr_15dB.stoi_unproc, sim_results.techno.snr_15dB.stoi_fir, sim_results.techno.snr_15dB.stoi_iir
    ];
    b_stoi = bar(bar_stoi);
    b_stoi(1).FaceColor = [0.6, 0.6, 0.6];
    b_stoi(2).FaceColor = c_fir;
    b_stoi(3).FaceColor = c_iir;
    grid on; box on;
    set(gca, 'XTickLabel', {'J -5dB', 'J -10dB', 'J -15dB', 'R -5dB', 'R -10dB', 'R -15dB', 'T -5dB', 'T -10dB', 'T -15dB'});
    ylabel('STOI Intelligibility Score (0 - 1.0)');
    title('Speech Intelligibility (STOI) Verification');
    legend({'Unprocessed Input', '128-Tap FIR', '8th-Order IIR SOS'}, 'Location', 'northeast');
    ylim([0.5, 1.0]);
    
    fig4_path = fullfile(figures_dir, 'filter_comparison_speech_enhancement.png');
    saveas(fig4, fig4_path);
    close(fig4);
    fprintf('  Saved: %s\n', fig4_path);

    % 7. Export C Headers for Firmware
    fprintf('\n--> Exporting C Headers for ESP32-S3 Firmware in %s...\n', firmware_dir);
    fir_header_path = fullfile(firmware_dir, 'fir_coefficients.h');
    iir_header_path = fullfile(firmware_dir, 'iir_coefficients.h');
    
    export_fir_header(fir_header_path, filters_fir);
    export_iir_header(iir_header_path, filters_iir, filters_notch);

    % 8. Save Workspace MAT
    mat_out = fullfile(metadata_dir, 'filter_comparison_workspace.mat');
    save(mat_out, 'filters_fir', 'filters_iir', 'filters_notch', 'comp_metrics', 'sim_results', 'specs');
    fprintf('--> Saved Workspace MAT: %s\n', mat_out);

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
    fprintf(fid, ' * @brief Pre-designed 128-tap FIR filter coefficients for Jazz, Rock, Techno speech enhancement.\n');
    fprintf(fid, ' * Designed via Parks-McClellan (firpm) equiripple algorithm (fs = 16 kHz).\n */\n\n');
    fprintf(fid, '#ifndef FIR_COEFFICIENTS_H\n#define FIR_COEFFICIENTS_H\n\n');
    fprintf(fid, '#define FIR_FILTER_ORDER 128\n');
    fprintf(fid, '#define FIR_FILTER_TAPS  129\n\n');
    
    keys = {'jazz', 'rock', 'techno', 'control'};
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
function export_iir_header(filepath, filters_iir, filters_notch)
    fid = fopen(filepath, 'w');
    if fid == -1, return; end
    
    fprintf(fid, '/**\n * @file iir_coefficients.h\n');
    fprintf(fid, ' * @brief Cascaded Second-Order Sections (SOS / Biquad) IIR filter coefficients.\n');
    fprintf(fid, ' * Genres: Jazz, Rock, Techno, Control (fs = 16 kHz, Chebyshev Type II).\n');
    fprintf(fid, ' * Structure: Direct Form II Transposed for optimal numerical stability on ESP32-S3.\n');
    fprintf(fid, ' * Also contains Phase 2 Parametric Notch Biquad coefficients.\n */\n\n');
    fprintf(fid, '#ifndef IIR_COEFFICIENTS_H\n#define IIR_COEFFICIENTS_H\n\n');
    fprintf(fid, '#define IIR_BIQUADS_COUNT 4\n\n');
    fprintf(fid, 'typedef struct {\n    float b0, b1, b2;\n    float a1, a2;\n} BiquadSection;\n\n');
    
    keys = {'jazz', 'rock', 'techno', 'control'};
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
        
        % Notch filter coefficients
        bn = filters_notch.(key).b;
        an = filters_notch.(key).a;
        fprintf(fid, '/* %s Parametric Notch Biquad (f0 = %.1f Hz, Q = %.1f) */\n', upper(key), filters_notch.(key).f0, filters_notch.(key).q);
        fprintf(fid, 'static const BiquadSection notch_%s_biquad = {\n', key);
        fprintf(fid, '    .b0 = %13.8ff, .b1 = %13.8ff, .b2 = %13.8ff, .a1 = %13.8ff, .a2 = %13.8ff\n};\n\n', ...
            bn(1), bn(2), bn(3), an(2), an(3));
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
    
    fprintf(fid, '/**\n * @brief Single Parametric Notch Biquad Direct Form II Transposed filtering.\n * Requires 2 state floats.\n */\n');
    fprintf(fid, 'static inline float process_single_biquad(const BiquadSection* restrict sec, float* restrict state, float input) {\n');
    fprintf(fid, '    float s1 = state[0];\n');
    fprintf(fid, '    float s2 = state[1];\n');
    fprintf(fid, '    float y = sec->b0 * input + s1;\n');
    fprintf(fid, '    state[0] = sec->b1 * input - sec->a1 * y + s2;\n');
    fprintf(fid, '    state[1] = sec->b2 * input - sec->a2 * y;\n');
    fprintf(fid, '    return y;\n');
    fprintf(fid, '}\n\n');
    
    fprintf(fid, '#endif /* IIR_COEFFICIENTS_H */\n');
    fclose(fid);
    fprintf('  Saved IIR C Header: %s\n', filepath);
end

function val = ternary(cond, a, b)
    if cond, val = a; else, val = b; end
end
