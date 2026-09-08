%% DESIGN_AND_COMPARE_FILTERS.M
% Designs genre-specific Parametric Notch & Multi-Band Biquad filters alongside
% baseline FIR/IIR bandpass filters for Jazz, Rock, and Techno.
% Evaluates comparative performance across Male, Female, and Combined natural human speech
% (Indiana University Sentence Database) across -5 dB, -10 dB, and -15 dB input SNR.
%
% University of the Witwatersrand
% School of Electrical & Information Engineering

function design_and_compare_filters()
    fprintf('=========================================================================\n');
    fprintf('  FILTER DESIGN & COMPARATIVE EVALUATION: PARAMETRIC NOTCH VS. BANDPASS\n');
    fprintf('  Evaluating Male, Female, and Combined Human Speech (IUS Corpus)\n');
    fprintf('  fs = 16 kHz | Target Hardware: ESP32-S3 (240 MHz, 32-bit FPU)\n');
    fprintf('=========================================================================\n\n');

    % 1. Directory Setup
    current_script_path = mfilename('fullpath');
    [script_dir, ~, ~] = fileparts(current_script_path);
    root_dir = fileparts(script_dir);

    metadata_dir = fullfile(root_dir, 'dataset', 'metadata');
    figures_dir  = fullfile(root_dir, 'figures');
    firmware_dir = fullfile(root_dir, 'firmware');
    corpus_dir   = fullfile(root_dir, 'dataset', 'speech_corpus');
    noise_dir    = fullfile(root_dir, 'dataset', 'test_stimuli', 'music_noise_30s');

    if ~exist(figures_dir, 'dir'), mkdir(figures_dir); end
    if ~exist(firmware_dir, 'dir'), mkdir(firmware_dir); end
    if ~exist(metadata_dir, 'dir'), mkdir(metadata_dir); end

    fs = 16000;
    nyq = fs / 2;

    filter_keys = {'jazz', 'rock', 'techno', 'control'};
    filter_names = {'Jazz', 'Rock', 'Techno', 'Control Baseline'};

    % 2. Design Specifications
    specs = struct();
    
    % Jazz: Upright acoustic bass resonance @ 78.1 Hz; wide passband
    specs.jazz.f_stop1 = 140; specs.jazz.f_pass1 = 300; specs.jazz.f_pass2 = 3400; specs.jazz.f_stop2 = 4200;
    specs.jazz.notch_f0 = 78.125; specs.jazz.notch_q = 6.0;
    
    % Rock: Electric bass / kick resonance @ 109.4 Hz
    specs.rock.f_stop1 = 160; specs.rock.f_pass1 = 300; specs.rock.f_pass2 = 3400; specs.rock.f_stop2 = 3800;
    specs.rock.notch_f0 = 109.375; specs.rock.notch_q = 6.0;
    specs.rock.shelf_fc = 4000; specs.rock.shelf_gain_db = -12;
    
    % Techno: Dominant sub-bass kick @ 62.5 Hz + 2nd harmonic @ 125 Hz
    specs.techno.f_stop1 = 220; specs.techno.f_pass1 = 300; specs.techno.f_pass2 = 3400; specs.techno.f_stop2 = 4000;
    specs.techno.notch_f0 = 62.5; specs.techno.notch_q = 8.0;
    specs.techno.notch_f1 = 125.0; specs.techno.notch_q1 = 6.0;
    
    % Control Baseline
    specs.control.f_stop1 = 200; specs.control.f_pass1 = 300; specs.control.f_pass2 = 3400; specs.control.f_stop2 = 4000;
    specs.control.notch_f0 = 100.0; specs.control.notch_q = 5.0;

    filters_fir   = struct();
    filters_iir   = struct();
    filters_notch = struct();

    N_fir = 128;
    N_iir_biquads = 4;

    fprintf('--> Designing Baseline Bandpass and Parametric Notch Filters...\n');

    for k = 1:length(filter_keys)
        key = filter_keys{k};
        sp = specs.(key);

        % A. Baseline 128-Tap FIR Bandpass
        f_edges = [0, sp.f_stop1, sp.f_pass1, sp.f_pass2, sp.f_stop2, nyq] / nyq;
        a_desired = [0, 0, 1, 1, 0, 0];
        weights = [15, 1, 15];
        b_fir = firpm(N_fir, f_edges, a_desired, weights);
        filters_fir.(key).b = b_fir;
        filters_fir.(key).group_delay_ms = (N_fir / 2) / fs * 1000;

        % B. Baseline 8th-Order IIR Bandpass (Chebyshev II SOS)
        W_stop = [sp.f_stop1, sp.f_stop2] / nyq;
        [z_iir, p_iir, k_iir] = cheby2(N_iir_biquads, 40, W_stop, 'bandpass');
        [sos, g] = zp2sos(z_iir, p_iir, k_iir);
        filters_iir.(key).sos = sos;
        filters_iir.(key).g = g;
        filters_iir.(key).max_pole_radius = max(abs(p_iir));

        % C. Parametric Notch Biquad Cascade
        % Digital biquad notch: H(z) = (1 - 2*cos(w0)*z^-1 + z^-2) / (1 + alpha - 2*cos(w0)*z^-1 + (1 - alpha)*z^-2)
        w0 = 2 * pi * sp.notch_f0 / fs;
        alpha = sin(w0) / (2 * sp.notch_q);
        b_n0 = [1, -2*cos(w0), 1] / (1 + alpha);
        a_n0 = [1 + alpha, -2*cos(w0), 1 - alpha] / (1 + alpha);
        
        if strcmp(key, 'techno')
            % Techno: 2-stage notch (62.5 Hz + 125 Hz)
            w1 = 2 * pi * sp.notch_f1 / fs;
            alpha1 = sin(w1) / (2 * sp.notch_q1);
            b_n1 = [1, -2*cos(w1), 1] / (1 + alpha1);
            a_n1 = [1 + alpha1, -2*cos(w1), 1 - alpha1] / (1 + alpha1);
            
            notch_sos = [b_n0, a_n0; b_n1, a_n1];
            filters_notch.(key).sos = notch_sos;
            filters_notch.(key).num_stages = 2;
        elseif strcmp(key, 'rock')
            % Rock: 1 notch (109 Hz) + High Shelf (4 kHz)
            w_sh = 2 * pi * sp.shelf_fc / fs;
            A = 10^(sp.shelf_gain_db / 40);
            alpha_sh = sin(w_sh) / 2 * sqrt(2);
            b_sh = [A*((A+1) + (A-1)*cos(w_sh) + 2*sqrt(A)*alpha_sh), ...
                   -2*A*((A-1) + (A+1)*cos(w_sh)), ...
                    A*((A+1) + (A-1)*cos(w_sh) - 2*sqrt(A)*alpha_sh)];
            a_sh = [(A+1) - (A-1)*cos(w_sh) + 2*sqrt(A)*alpha_sh, ...
                    2*((A-1) - (A+1)*cos(w_sh)), ...
                    (A+1) - (A-1)*cos(w_sh) - 2*sqrt(A)*alpha_sh];
            b_sh = b_sh / a_sh(1);
            a_sh = a_sh / a_sh(1);
            
            notch_sos = [b_n0, a_n0; b_sh, a_sh];
            filters_notch.(key).sos = notch_sos;
            filters_notch.(key).num_stages = 2;
        else
            % Jazz and Control: 1 notch
            notch_sos = [b_n0, a_n0];
            filters_notch.(key).sos = notch_sos;
            filters_notch.(key).num_stages = 1;
        end
        
        filters_notch.(key).f0 = sp.notch_f0;
        filters_notch.(key).q  = sp.notch_q;
        
        fprintf('    [%s] Bandpass IIR: Max |p| = %.4f | Notch Stages: %d (f0 = %.1f Hz, Q = %.1f)\n', ...
            upper(key), filters_iir.(key).max_pole_radius, filters_notch.(key).num_stages, sp.notch_f0, sp.notch_q);
    end

    % 3. Frequency Responses and Group Delays
    fprintf('\n--> Computing Filter Frequency Responses...\n');
    n_pts = 4096;
    [~, f_eval] = freqz(filters_fir.techno.b, 1, n_pts, fs);

    for k = 1:length(filter_keys)
        key = filter_keys{k};
        
        % FIR
        [h_fir, ~] = freqz(filters_fir.(key).b, 1, f_eval, fs);
        filters_fir.(key).mag_db = 20 * log10(abs(h_fir(:)) + eps);
        [gd_fir_samp, ~] = grpdelay(filters_fir.(key).b, 1, f_eval, fs);
        filters_fir.(key).gd_ms = gd_fir_samp(:) / fs * 1000;
        
        % IIR Bandpass
        [b_iir, a_iir] = sos2tf(filters_iir.(key).sos, filters_iir.(key).g);
        [h_iir, ~] = freqz(b_iir, a_iir, f_eval, fs);
        filters_iir.(key).mag_db = 20 * log10(abs(h_iir(:)) + eps);
        [gd_iir_samp, ~] = grpdelay(b_iir, a_iir, f_eval, fs);
        filters_iir.(key).gd_ms = gd_iir_samp(:) / fs * 1000;
        
        % Parametric Notch
        [b_notch, a_notch] = sos2tf(filters_notch.(key).sos);
        [h_notch, ~] = freqz(b_notch, a_notch, f_eval, fs);
        filters_notch.(key).mag_db = 20 * log10(abs(h_notch(:)) + eps);
        [gd_notch_samp, ~] = grpdelay(b_notch, a_notch, f_eval, fs);
        filters_notch.(key).gd_ms = gd_notch_samp(:) / fs * 1000;
    end

    % 4. Multi-Talker Speech Enhancement Simulation (Male, Female, Combined)
    fprintf('\n--> Running Multi-Talker Speech Enhancement Benchmark (Male vs. Female)...\n');
    snr_levels = [-5, -10, -15];
    sim_genres = {'jazz', 'rock', 'techno'};
    speech_subsets = {'male', 'female', 'combined'};
    
    sim_results = struct();

    for sub_idx = 1:length(speech_subsets)
        sub_name = speech_subsets{sub_idx};
        if strcmp(sub_name, 'combined')
            m_dir_files = dir(fullfile(corpus_dir, 'male', '*.wav'));
            f_dir_files = dir(fullfile(corpus_dir, 'female', '*.wav'));
            n_each = min([length(m_dir_files), length(f_dir_files), 10]);
            s_file_paths = [
                arrayfun(@(x) fullfile(corpus_dir, 'male', x.name), m_dir_files(1:n_each), 'UniformOutput', false);
                arrayfun(@(x) fullfile(corpus_dir, 'female', x.name), f_dir_files(1:n_each), 'UniformOutput', false)
            ];
        else
            sub_dir  = fullfile(corpus_dir, sub_name);
            s_files  = dir(fullfile(sub_dir, '*.wav'));
            n_eval   = min(length(s_files), 10);
            s_file_paths = arrayfun(@(x) fullfile(sub_dir, x.name), s_files(1:n_eval), 'UniformOutput', false);
        end
        n_eval = length(s_file_paths);
        
        fprintf('    Evaluating Speech Subset: [%s] (N = %d talkers)...\n', upper(sub_name), n_eval);
        
        for g = 1:length(sim_genres)
            gk = sim_genres{g};
            noise_file = fullfile(noise_dir, sprintf('%s_noise_30s.wav', gk));
            [noise_data, ~] = audioread(noise_file);
            
            for snr_idx = 1:length(snr_levels)
                target_snr = snr_levels(snr_idx);
                snr_tag = sprintf('snr_%ddB', abs(target_snr));
                
                dsnr_bp_list    = zeros(n_eval, 1);
                dsnr_notch_list = zeros(n_eval, 1);
                stoi_unproc_list= zeros(n_eval, 1);
                stoi_bp_list    = zeros(n_eval, 1);
                stoi_notch_list = zeros(n_eval, 1);
                
                for s = 1:n_eval
                    s_file = s_file_paths{s};
                    [clean, ~] = audioread(s_file);
                    L = length(clean);
                    
                    start_n = mod((s-1) * 32000, length(noise_data) - L - 1) + 1;
                    if start_n + L - 1 > length(noise_data), start_n = 1000; end
                    noise_seg = noise_data(start_n : start_n + L - 1);
                    
                    p_clean = mean(clean .^ 2);
                    p_noise = mean(noise_seg .^ 2);
                    scale = sqrt(p_clean / (p_noise * (10 ^ (target_snr / 10))));
                    scaled_noise = noise_seg * scale;
                    noisy_input = clean + scaled_noise;
                    
                    % 1. Bandpass Filtering (Chebyshev II)
                    out_bp = sosfilt(filters_iir.(gk).sos, noisy_input) * filters_iir.(gk).g;
                    out_bp_aligned = out_bp(21 : end);
                    clean_bp_aligned = clean(1 : length(out_bp_aligned));
                    noisy_bp_aligned = noisy_input(1 : length(out_bp_aligned));
                    
                    % 2. Parametric Notch Filtering
                    out_notch = sosfilt(filters_notch.(gk).sos, noisy_input);
                    out_notch_aligned = out_notch(5 : end);
                    clean_notch_aligned = clean(1 : length(out_notch_aligned));
                    noisy_notch_aligned = noisy_input(1 : length(out_notch_aligned));
                    
                    dsnr_bp_list(s)    = compute_delta_snr(clean_bp_aligned, noisy_bp_aligned, out_bp_aligned, fs);
                    dsnr_notch_list(s) = compute_delta_snr(clean_notch_aligned, noisy_notch_aligned, out_notch_aligned, fs);
                    
                    stoi_unproc_list(s)= compute_simplified_stoi(clean_notch_aligned, noisy_notch_aligned, fs);
                    stoi_bp_list(s)    = compute_simplified_stoi(clean_bp_aligned, out_bp_aligned, fs);
                    stoi_notch_list(s) = compute_simplified_stoi(clean_notch_aligned, out_notch_aligned, fs);
                end
                
                sim_results.(sub_name).(gk).(snr_tag).delta_snr_bp    = mean(dsnr_bp_list);
                sim_results.(sub_name).(gk).(snr_tag).delta_snr_notch = mean(dsnr_notch_list);
                sim_results.(sub_name).(gk).(snr_tag).stoi_unproc     = mean(stoi_unproc_list);
                sim_results.(sub_name).(gk).(snr_tag).stoi_bp         = mean(stoi_bp_list);
                sim_results.(sub_name).(gk).(snr_tag).stoi_notch      = mean(stoi_notch_list);
            end
        end
    end

    % 5. Print Comparison Summary
    fprintf('\n=========================================================================================\n');
    fprintf('  BENCHMARK: TRADITIONAL BANDPASS VS. PARAMETRIC NOTCH (MALE VS. FEMALE SPEECH)\n');
    fprintf('=========================================================================================\n');
    fprintf('%-8s | %-7s | %-6s | %-12s | %-12s | %-10s | %-10s | %-10s\n', ...
        'Gender', 'Genre', 'SNR', 'ΔSNR Bandpass', 'ΔSNR Notch', 'STOI Unproc', 'STOI Bandpass', 'STOI Notch');
    fprintf('-----------------------------------------------------------------------------------------\n');
    
    for sub_idx = 1:length(speech_subsets)
        sub_name = speech_subsets{sub_idx};
        for g = 1:length(sim_genres)
            gk = sim_genres{g};
            for snr_idx = 1:length(snr_levels)
                target_snr = snr_levels(snr_idx);
                snr_tag = sprintf('snr_%ddB', abs(target_snr));
                r = sim_results.(sub_name).(gk).(snr_tag);
                fprintf('%-8s | %-7s | %4d dB | %9.2f dB   | %9.2f dB   | %8.3f   | %8.3f    | %8.3f\n', ...
                    upper(sub_name), upper(gk), target_snr, r.delta_snr_bp, r.delta_snr_notch, ...
                    r.stoi_unproc, r.stoi_bp, r.stoi_notch);
            end
            fprintf('-----------------------------------------------------------------------------------------\n');
        end
    end

    % 6. Visualizations
    fprintf('\n--> Generating Filter Comparison Visualizations in %s...\n', figures_dir);
    set(0, 'DefaultAxesFontSize', 11);
    set(0, 'DefaultAxesFontName', 'Helvetica');

    c_bp    = [0.8500, 0.3250, 0.0980]; % Red-Orange
    c_notch = [0.0000, 0.4470, 0.7410]; % Cobalt Blue

    % Figure 1: Magnitude & Group Delay (Notch vs. Bandpass)
    fig1 = figure('Name', 'Notch vs Bandpass Magnitude & Latency', 'Position', [50, 50, 1100, 800], 'Visible', 'off');
    
    for k = 1:3
        key = sim_genres{k};
        subplot(3, 2, (k-1)*2 + 1);
        hold on; grid on; box on;
        
        plot(f_eval, filters_iir.(key).mag_db,   'Color', c_bp,    'LineWidth', 1.8, 'DisplayName', 'Bandpass (300-3400 Hz)');
        plot(f_eval, filters_notch.(key).mag_db, 'Color', c_notch, 'LineWidth', 2.0, 'DisplayName', 'Parametric Notch Cascade');
        yline(-40, 'k:', 'LineWidth', 1.0, 'HandleVisibility', 'off');
        xlim([20, 4000]); ylim([-55, 5]);
        ylabel('Magnitude (dB)');
        title(sprintf('%s: Frequency Response', upper(key)));
        legend('Location', 'southeast');
        
        subplot(3, 2, (k-1)*2 + 2);
        hold on; grid on; box on;
        plot(f_eval, filters_iir.(key).gd_ms,   'Color', c_bp,    'LineWidth', 1.8, 'DisplayName', 'Bandpass Group Delay');
        plot(f_eval, filters_notch.(key).gd_ms, 'Color', c_notch, 'LineWidth', 2.0, 'DisplayName', 'Notch Group Delay');
        xlim([20, 3500]); ylim([0, 10]);
        ylabel('Latency (ms)');
        title(sprintf('%s: Group Delay Profile', upper(key)));
        legend('Location', 'northeast');
    end
    xlabel('Frequency (Hz)');
    
    fig1_path = fullfile(figures_dir, 'filter_comparison_notch_vs_bandpass.png');
    saveas(fig1, fig1_path);
    close(fig1);
    fprintf('  Saved: %s\n', fig1_path);

    % Figure 2: Speech Enhancement Comparison (Male vs. Female vs. Combined)
    fig2 = figure('Name', 'Speech Enhancement Performance by Gender', 'Position', [100, 100, 1150, 600], 'Visible', 'off');
    
    % Panel 1: STOI Intelligibility Score at -10 dB SNR
    subplot(1, 2, 1);
    bar_stoi_10db = [
        sim_results.male.jazz.snr_10dB.stoi_unproc,     sim_results.male.jazz.snr_10dB.stoi_bp,     sim_results.male.jazz.snr_10dB.stoi_notch;
        sim_results.female.jazz.snr_10dB.stoi_unproc,   sim_results.female.jazz.snr_10dB.stoi_bp,   sim_results.female.jazz.snr_10dB.stoi_notch;
        sim_results.male.rock.snr_10dB.stoi_unproc,     sim_results.male.rock.snr_10dB.stoi_bp,     sim_results.male.rock.snr_10dB.stoi_notch;
        sim_results.female.rock.snr_10dB.stoi_unproc,   sim_results.female.rock.snr_10dB.stoi_bp,   sim_results.female.rock.snr_10dB.stoi_notch;
        sim_results.male.techno.snr_10dB.stoi_unproc,   sim_results.male.techno.snr_10dB.stoi_bp,   sim_results.male.techno.snr_10dB.stoi_notch;
        sim_results.female.techno.snr_10dB.stoi_unproc, sim_results.female.techno.snr_10dB.stoi_bp, sim_results.female.techno.snr_10dB.stoi_notch
    ];
    b_st = bar(bar_stoi_10db);
    b_st(1).FaceColor = [0.65, 0.65, 0.65]; % Unproc
    b_st(2).FaceColor = c_bp;               % Bandpass
    b_st(3).FaceColor = c_notch;            % Notch
    grid on; box on;
    set(gca, 'XTickLabel', {'M-Jazz', 'F-Jazz', 'M-Rock', 'F-Rock', 'M-Techno', 'F-Techno'});
    ylabel('STOI Intelligibility (0 - 1.0)');
    title('Speech Intelligibility (STOI @ -10 dB): Male vs. Female');
    legend({'Unprocessed Input', 'Bandpass Biquad', 'Parametric Notch Cascade'}, 'Location', 'northeast');
    ylim([0.6, 1.0]);
    
    % Panel 2: Delta SNR at -10 dB SNR
    subplot(1, 2, 2);
    bar_dsnr_10db = [
        sim_results.male.jazz.snr_10dB.delta_snr_bp,     sim_results.male.jazz.snr_10dB.delta_snr_notch;
        sim_results.female.jazz.snr_10dB.delta_snr_bp,   sim_results.female.jazz.snr_10dB.delta_snr_notch;
        sim_results.male.rock.snr_10dB.delta_snr_bp,     sim_results.male.rock.snr_10dB.delta_snr_notch;
        sim_results.female.rock.snr_10dB.delta_snr_bp,   sim_results.female.rock.snr_10dB.delta_snr_notch;
        sim_results.male.techno.snr_10dB.delta_snr_bp,   sim_results.male.techno.snr_10dB.delta_snr_notch;
        sim_results.female.techno.snr_10dB.delta_snr_bp, sim_results.female.techno.snr_10dB.delta_snr_notch
    ];
    b_ds = bar(bar_dsnr_10db);
    b_ds(1).FaceColor = c_bp;
    b_ds(2).FaceColor = c_notch;
    grid on; box on;
    set(gca, 'XTickLabel', {'M-Jazz', 'F-Jazz', 'M-Rock', 'F-Rock', 'M-Techno', 'F-Techno'});
    ylabel('\Delta SNR Improvement (dB)');
    title('Noise Reduction (\Delta SNR @ -10 dB): Bandpass vs. Notch');
    legend({'Bandpass Filter', 'Parametric Notch Cascade'}, 'Location', 'northwest');
    
    fig2_path = fullfile(figures_dir, 'filter_comparison_speech_enhancement.png');
    saveas(fig2, fig2_path);
    close(fig2);
    fprintf('  Saved: %s\n', fig2_path);

    % 7. Export C Headers for Firmware
    fprintf('\n--> Exporting C Headers for ESP32-S3 Firmware in %s...\n', firmware_dir);
    export_iir_notch_header(fullfile(firmware_dir, 'iir_coefficients.h'), filters_iir, filters_notch);

    % 8. Save Workspace MAT
    mat_out = fullfile(metadata_dir, 'filter_comparison_workspace.mat');
    save(mat_out, 'filters_fir', 'filters_iir', 'filters_notch', 'sim_results', 'specs');
    fprintf('--> Saved Workspace MAT: %s\n', mat_out);

    fprintf('\n=========================================================================\n');
    fprintf('  PARAMETRIC NOTCH FILTER BENCHMARK & DESIGN COMPLETE!\n');
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

%% Helper: Export IIR & Notch Firmware C Header
function export_iir_notch_header(filepath, filters_iir, filters_notch)
    fid = fopen(filepath, 'w');
    if fid == -1, return; end
    
    fprintf(fid, '/**\n * @file iir_coefficients.h\n');
    fprintf(fid, ' * @brief Cascaded Second-Order Sections (SOS) Biquad IIR and Parametric Notch Coefficients.\n');
    fprintf(fid, ' * Target: ESP32-S3 (16 kHz audio processing loop).\n');
    fprintf(fid, ' * Genres: Jazz, Rock, Techno.\n */\n\n');
    fprintf(fid, '#ifndef IIR_COEFFICIENTS_H\n#define IIR_COEFFICIENTS_H\n\n');
    fprintf(fid, 'typedef struct {\n    float b0, b1, b2;\n    float a1, a2;\n} BiquadSection;\n\n');
    
    keys = {'jazz', 'rock', 'techno'};
    for k = 1:length(keys)
        key = keys{k};
        sos = filters_notch.(key).sos;
        n_sec = size(sos, 1);
        
        fprintf(fid, '/* %s Parametric Notch Cascade (%d Biquad Stages, f0 = %.1f Hz) */\n', ...
            upper(key), n_sec, filters_notch.(key).f0);
        fprintf(fid, '#define NOTCH_%s_STAGES %d\n', upper(key), n_sec);
        fprintf(fid, 'static const BiquadSection notch_%s_cascade[%d] = {\n', key, n_sec);
        for s = 1:n_sec
            fprintf(fid, '    { .b0 = %13.8ff, .b1 = %13.8ff, .b2 = %13.8ff, .a1 = %13.8ff, .a2 = %13.8ff }%s\n', ...
                sos(s, 1), sos(s, 2), sos(s, 3), sos(s, 5), sos(s, 6), ternary(s == n_sec, '', ','));
        end
        fprintf(fid, '};\n\n');
    end
    
    fprintf(fid, '/**\n * @brief Executes Parametric Notch Biquad Cascade in Direct Form II Transposed structure.\n');
    fprintf(fid, ' * @param cascade Array of BiquadSection\n');
    fprintf(fid, ' * @param num_stages Number of cascaded biquad stages\n');
    fprintf(fid, ' * @param state State buffer (must have size: 2 * num_stages floats)\n');
    fprintf(fid, ' * @param input Raw audio sample (float)\n');
    fprintf(fid, ' * @return Filtered audio sample (float)\n */\n');
    fprintf(fid, 'static inline float process_parametric_notch_cascade(const BiquadSection* restrict cascade, int num_stages, float* restrict state, float input) {\n');
    fprintf(fid, '    float w = input;\n');
    fprintf(fid, '    for (int s = 0; s < num_stages; s++) {\n');
    fprintf(fid, '        float s1 = state[s * 2];\n');
    fprintf(fid, '        float s2 = state[s * 2 + 1];\n');
    fprintf(fid, '        float y = cascade[s].b0 * w + s1;\n');
    fprintf(fid, '        state[s * 2]     = cascade[s].b1 * w - cascade[s].a1 * y + s2;\n');
    fprintf(fid, '        state[s * 2 + 1] = cascade[s].b2 * w - cascade[s].a2 * y;\n');
    fprintf(fid, '        w = y;\n');
    fprintf(fid, '    }\n');
    fprintf(fid, '    return w;\n');
    fprintf(fid, '}\n\n');
    
    fprintf(fid, '#endif /* IIR_COEFFICIENTS_H */\n');
    fclose(fid);
    fprintf('  Saved IIR Notch C Header: %s\n', filepath);
end

function val = ternary(cond, a, b)
    if cond, val = a; else, val = b; end
end
