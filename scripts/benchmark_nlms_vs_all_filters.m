%% BENCHMARK_NLMS_VS_ALL_FILTERS.M
% Comprehensive comparative evaluation of Single-Channel Filters
% (128-Tap FIR, 8th-Order Chebyshev II IIR, Parametric Notch Cascades)
% versus Dual-Channel Adaptive NLMS Filter and Hybrid Notch+NLMS Topology.
%
% Evaluates across:
% - Speech: Male, Female, Combined (Indiana University Sentence Database)
% - Genres: Jazz, Rock, Techno (Acoustic Triad)
% - SNR Tiers: -15 dB, -10 dB, -5 dB, 0 dB, +5 dB, +10 dB
% - Realistic Acoustic Scenarios: Direct Path, Reverberation, Speech Leakage, Movement
%
% University of the Witwatersrand
% School of Electrical & Information Engineering

function benchmark_nlms_vs_all_filters()
    fprintf('=========================================================================\n');
    fprintf('  COMPREHENSIVE BENCHMARK: FIXED FILTERS VS. ADAPTIVE NLMS\n');
    fprintf('  Evaluating Male, Female & Combined Human Speech across Jazz, Rock, Techno\n');
    fprintf('  Target Hardware: ESP32-S3 (240 MHz, 32-bit FPU) | fs = 16 kHz\n');
    fprintf('=========================================================================\n\n');

    % 1. Paths & Directory Setup
    script_dir = fileparts(mfilename('fullpath'));
    if isempty(script_dir), script_dir = pwd; end
    root_dir = fileparts(script_dir);

    nlms_dir     = fullfile(root_dir, 'NLMS');
    dataset_dir  = fullfile(root_dir, 'dataset');
    metadata_dir = fullfile(dataset_dir, 'metadata');
    figures_dir  = fullfile(root_dir, 'figures');
    corpus_dir   = fullfile(dataset_dir, 'speech_corpus');
    noise_dir    = fullfile(dataset_dir, 'test_stimuli', 'music_noise_30s');
    audit_dir    = fullfile(dataset_dir, 'test_stimuli', 'audit_nlms_audio');

    if ~exist(audit_dir, 'dir'), mkdir(audit_dir); end
    if ~exist(figures_dir, 'dir'), mkdir(figures_dir); end
    if ~exist(metadata_dir, 'dir'), mkdir(metadata_dir); end

    addpath(nlms_dir);

    % 2. Load Existing Fixed Filter Designs
    ws_file = fullfile(metadata_dir, 'filter_comparison_workspace.mat');
    if ~exist(ws_file, 'file')
        error('Filter workspace not found: %s. Run design_and_compare_filters.m first.', ws_file);
    end
    ws = load(ws_file);
    filters_fir   = ws.filters_fir;
    filters_iir   = ws.filters_iir;
    filters_notch = ws.filters_notch;

    fs = 16000;
    
    % NLMS Parameters (Partner Configuration)
    N_nlms   = 256;
    mu_nlms  = 0.05;
    eps_nlms = 1e-2;

    genres = {'jazz', 'rock', 'techno'};
    snr_grid = [-15, -10, -5, 0, 5, 10];
    speech_groups = {'male', 'female', 'combined'};

    % 3. Prepare Audio Corpus File Lists
    m_files = dir(fullfile(corpus_dir, 'male', '*.wav'));
    f_files = dir(fullfile(corpus_dir, 'female', '*.wav'));
    
    n_talkers = 10; % 10 male, 10 female
    speech_lists = struct();
    speech_lists.male = arrayfun(@(x) fullfile(corpus_dir, 'male', x.name), m_files(1:min(n_talkers, length(m_files))), 'UniformOutput', false);
    speech_lists.female = arrayfun(@(x) fullfile(corpus_dir, 'female', x.name), f_files(1:min(n_talkers, length(f_files))), 'UniformOutput', false);
    speech_lists.combined = [speech_lists.male; speech_lists.female];

    % Noise Files (Acoustic Triad)
    noise_stems = struct();
    noise_stems.jazz   = fullfile(noise_dir, 'jazz_noise_30s.wav');
    noise_stems.rock   = fullfile(noise_dir, 'rock_noise_30s.wav');
    noise_stems.techno = fullfile(noise_dir, 'techno_noise_30s.wav');

    % 4. Main Cross-Filter Benchmark Grid
    fprintf('--> Executing Cross-Filter Benchmark across 6 SNR Tiers and 3 Genres...\n');
    
    csv_file = fullfile(metadata_dir, 'nlms_vs_all_filters_benchmark.csv');
    fid_csv = fopen(csv_file, 'w');
    fprintf(fid_csv, 'Gender,Genre,SNR_dB,STOI_Unproc,STOI_FIR,STOI_IIR,STOI_Notch,STOI_NLMS,STOI_Hybrid,dSNR_FIR,dSNR_IIR,dSNR_Notch,dSNR_NLMS,dSNR_Hybrid\n');

    benchmark_data = struct();

    for grp_idx = 1:length(speech_groups)
        grp = speech_groups{grp_idx};
        s_paths = speech_lists.(grp);
        n_spk = length(s_paths);

        fprintf('\n-----------------------------------------------------------------------------------------\n');
        fprintf('  EVALUATING SPEECH GROUP: [%s] (N = %d talkers)\n', upper(grp), n_spk);
        fprintf('-----------------------------------------------------------------------------------------\n');
        fprintf('%-7s | %-6s | %-8s | %-8s | %-8s | %-8s | %-8s | %-8s | %-9s\n', ...
            'Genre', 'SNR', 'Unproc', 'FIR BP', 'IIR BP', 'Notch', 'NLMS', 'Hybrid', 'NLMS Gain');
        fprintf('-----------------------------------------------------------------------------------------\n');

        for g_idx = 1:length(genres)
            gk = genres{g_idx};
            [noise_full, fs_n] = audioread(noise_stems.(gk));
            if fs_n ~= fs, noise_full = resample(noise_full, fs, fs_n); end

            for s_idx = 1:length(snr_grid)
                snr_val = snr_grid(s_idx);
                snr_tag = sprintf('snr_%ddB', abs(snr_val));
                if snr_val >= 0, snr_tag = sprintf('snr_plus%ddB', snr_val); end

                % Metric accumulators
                m_stoi_unproc = zeros(n_spk, 1);
                m_stoi_fir    = zeros(n_spk, 1);
                m_stoi_iir    = zeros(n_spk, 1);
                m_stoi_notch  = zeros(n_spk, 1);
                m_stoi_nlms   = zeros(n_spk, 1);
                m_stoi_hybrid = zeros(n_spk, 1);

                m_dsnr_fir    = zeros(n_spk, 1);
                m_dsnr_iir    = zeros(n_spk, 1);
                m_dsnr_notch  = zeros(n_spk, 1);
                m_dsnr_nlms   = zeros(n_spk, 1);
                m_dsnr_hybrid = zeros(n_spk, 1);

                for k = 1:n_spk
                    [clean, fs_s] = audioread(s_paths{k});
                    if fs_s ~= fs, clean = resample(clean, fs, fs_s); end
                    L = length(clean);

                    % Slice noise reference segment
                    n_start = mod((k-1) * 32000, length(noise_full) - L - 1) + 1;
                    if n_start + L - 1 > length(noise_full), n_start = 1; end
                    noise_ref = noise_full(n_start : n_start + L - 1);

                    % Acoustic Path for Primary Mic: Line-of-sight propagation (1-sample delay, 0.8 attenuation)
                    noise_primary_raw = 0.8 * [0; noise_ref(1:end-1)];

                    % Calibrate to Target SNR via ITU-T P.56 Active Speech Leveling
                    scaled_primary_noise = scale_noise_for_snr(clean, noise_primary_raw, fs, snr_val);
                    d = clean + scaled_primary_noise; % Primary mic input
                    x = noise_ref;                    % Reference mic input

                    % --- 1. FIR Bandpass Filter ---
                    y_fir = filter(filters_fir.(gk).b, 1, d);

                    % --- 2. 8th-Order Chebyshev II IIR SOS Filter ---
                    y_iir = sosfilt(filters_iir.(gk).sos, d) * filters_iir.(gk).g;

                    % --- 3. Surgical Parametric Notch Cascade ---
                    y_notch = sosfilt(filters_notch.(gk).sos, d);

                    % --- 4. Dual-Channel NLMS Adaptive Filter ---
                    [y_nlms, ~] = nlms_filter(d, x, N_nlms, mu_nlms, eps_nlms);

                    % --- 5. Hybrid Cascade: Parametric Notch -> NLMS ---
                    % Pre-filter primary with notch to eliminate bass before adaptive stage
                    d_pre_notch = sosfilt(filters_notch.(gk).sos, d);
                    [y_hybrid, ~] = nlms_filter(d_pre_notch, x, N_nlms, mu_nlms, eps_nlms);

                    % Compute STOI Metrics
                    m_stoi_unproc(k) = calculate_stoi(clean, d, fs);
                    m_stoi_fir(k)    = calculate_stoi(clean, y_fir, fs);
                    m_stoi_iir(k)    = calculate_stoi(clean, y_iir, fs);
                    m_stoi_notch(k)  = calculate_stoi(clean, y_notch, fs);
                    m_stoi_nlms(k)   = calculate_stoi(clean, y_nlms, fs);
                    m_stoi_hybrid(k) = calculate_stoi(clean, y_hybrid, fs);

                    % Compute Physical Delta SNR (Linear Filter Decomposition)
                    snr_in = 10 * log10(mean(clean.^2) / (mean(scaled_primary_noise.^2) + eps));
                    
                    % FIR
                    s_fir = filter(filters_fir.(gk).b, 1, clean);
                    n_fir = filter(filters_fir.(gk).b, 1, scaled_primary_noise);
                    m_dsnr_fir(k) = 10*log10(mean(s_fir.^2)/(mean(n_fir.^2)+eps)) - snr_in;

                    % IIR
                    s_iir = sosfilt(filters_iir.(gk).sos, clean) * filters_iir.(gk).g;
                    n_iir = sosfilt(filters_iir.(gk).sos, scaled_primary_noise) * filters_iir.(gk).g;
                    m_dsnr_iir(k) = 10*log10(mean(s_iir.^2)/(mean(n_iir.^2)+eps)) - snr_in;

                    % Notch
                    s_n = sosfilt(filters_notch.(gk).sos, clean);
                    n_n = sosfilt(filters_notch.(gk).sos, scaled_primary_noise);
                    m_dsnr_notch(k) = 10*log10(mean(s_n.^2)/(mean(n_n.^2)+eps)) - snr_in;

                    % NLMS Residual Noise Suppression
                    % For NLMS: error e = (s + n) - y. Speech is preserved, residual noise is e - s.
                    residual_noise_nlms = y_nlms - clean;
                    m_dsnr_nlms(k) = 10*log10(mean(clean.^2)/(mean(residual_noise_nlms.^2)+eps)) - snr_in;

                    residual_noise_hyb = y_hybrid - clean;
                    m_dsnr_hybrid(k) = 10*log10(mean(clean.^2)/(mean(residual_noise_hyb.^2)+eps)) - snr_in;
                end

                % Store mean metrics
                r = struct();
                r.stoi_unproc = mean(m_stoi_unproc);
                r.stoi_fir    = mean(m_stoi_fir);
                r.stoi_iir    = mean(m_stoi_iir);
                r.stoi_notch  = mean(m_stoi_notch);
                r.stoi_nlms   = mean(m_stoi_nlms);
                r.stoi_hybrid = mean(m_stoi_hybrid);

                r.dsnr_fir    = mean(m_dsnr_fir);
                r.dsnr_iir    = mean(m_dsnr_iir);
                r.dsnr_notch  = mean(m_dsnr_notch);
                r.dsnr_nlms   = mean(m_dsnr_nlms);
                r.dsnr_hybrid = mean(m_dsnr_hybrid);

                benchmark_data.(grp).(gk).(snr_tag) = r;

                % Print console row
                nlms_gain = r.stoi_nlms - r.stoi_unproc;
                fprintf('%-7s | %3d dB | %7.3f  | %7.3f  | %7.3f  | %7.3f  | %7.3f  | %7.3f  | %+8.4f\n', ...
                    upper(gk), snr_val, r.stoi_unproc, r.stoi_fir, r.stoi_iir, r.stoi_notch, r.stoi_nlms, r.stoi_hybrid, nlms_gain);

                fprintf(fid_csv, '%s,%s,%d,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.2f,%.2f,%.2f,%.2f,%.2f\n', ...
                    grp, gk, snr_val, r.stoi_unproc, r.stoi_fir, r.stoi_iir, r.stoi_notch, r.stoi_nlms, r.stoi_hybrid, ...
                    r.dsnr_fir, r.dsnr_iir, r.dsnr_notch, r.dsnr_nlms, r.dsnr_hybrid);
            end
        end
    end
    fclose(fid_csv);
    fprintf('  Saved CSV Benchmark: %s\n', csv_file);

    % 5. Detailed Evaluation of the 5 Real-World Scenarios
    fprintf('\n=========================================================================\n');
    fprintf('  EVALUATING NLMS REAL-WORLD ACOUSTIC STRESS SCENARIOS\n');
    fprintf('=========================================================================\n');

    scenarios_csv = fullfile(metadata_dir, 'nlms_scenarios_summary.csv');
    fid_scen = fopen(scenarios_csv, 'w');
    fprintf(fid_scen, 'Scenario_ID,Scenario_Name,Target_SNR_dB,STOI_In,STOI_Out,Delta_STOI,ASL_In_dBFS,ASL_Out_dBFS\n');

    % Pick standard female test sentence (female_01) and Techno stem
    test_spk_file = fullfile(corpus_dir, 'female', f_files(1).name);
    [clean_s, ~] = audioread(test_spk_file);
    L_scen = length(clean_s);
    t_scen = (0:L_scen-1)' / fs;

    [techno_raw, ~] = audioread(noise_stems.techno);
    noise_scen_base = techno_raw(1:L_scen);

    scen_results = struct();

    % Scenario 1: Multi-Path Room Reverberation
    fprintf('--> Scenario 1: Room Reverberation (151-tap Exponential RIR)...\n');
    h_room = exp(- (0:150)' / 30) .* randn(151, 1);
    ambient_s1 = conv(noise_scen_base, h_room, 'same');
    ambient_s1_scaled = scale_noise_for_snr(clean_s, ambient_s1, fs, -5);
    d1 = clean_s + ambient_s1_scaled;
    x1 = noise_scen_base;
    [e1, ~] = nlms_filter(d1, x1, N_nlms, mu_nlms, eps_nlms);

    scen_results.s1.stoi_in  = calculate_stoi(clean_s, d1, fs);
    scen_results.s1.stoi_out = calculate_stoi(clean_s, e1, fs);
    [scen_results.s1.asl_in, ~]  = calculate_active_speech_level(d1, fs);
    [scen_results.s1.asl_out, ~] = calculate_active_speech_level(e1, fs);
    fprintf('    STOI: In = %.4f | Out = %.4f | Gain = %+.4f\n', ...
        scen_results.s1.stoi_in, scen_results.s1.stoi_out, scen_results.s1.stoi_out - scen_results.s1.stoi_in);
    fprintf(fid_scen, '1,Reverberation,-5,%.4f,%.4f,%.4f,%.2f,%.2f\n', ...
        scen_results.s1.stoi_in, scen_results.s1.stoi_out, scen_results.s1.stoi_out - scen_results.s1.stoi_in, ...
        scen_results.s1.asl_in, scen_results.s1.asl_out);

    % Scenario 2: Speech Leakage into Reference Mic (30% Crosstalk)
    fprintf('--> Scenario 2: Speech Leakage into Reference Mic (30%% Crosstalk)...\n');
    delay_s2 = 5;
    ambient_s2 = 0.8 * [zeros(delay_s2, 1); noise_scen_base(1:end-delay_s2)];
    ambient_s2_scaled = scale_noise_for_snr(clean_s, ambient_s2, fs, -5);
    d2 = clean_s + ambient_s2_scaled;
    x2 = noise_scen_base + 0.30 * clean_s; % Speech bleeds into reference
    [e2, ~] = nlms_filter(d2, x2, N_nlms, mu_nlms, eps_nlms);

    scen_results.s2.stoi_in  = calculate_stoi(clean_s, d2, fs);
    scen_results.s2.stoi_out = calculate_stoi(clean_s, e2, fs);
    [scen_results.s2.asl_in, ~]  = calculate_active_speech_level(d2, fs);
    [scen_results.s2.asl_out, ~] = calculate_active_speech_level(e2, fs);
    fprintf('    STOI: In = %.4f | Out = %.4f | Gain = %+.4f (Notice Speech Cancellation!)\n', ...
        scen_results.s2.stoi_in, scen_results.s2.stoi_out, scen_results.s2.stoi_out - scen_results.s2.stoi_in);
    fprintf(fid_scen, '2,Speech_Leakage_30pct,-5,%.4f,%.4f,%.4f,%.2f,%.2f\n', ...
        scen_results.s2.stoi_in, scen_results.s2.stoi_out, scen_results.s2.stoi_out - scen_results.s2.stoi_in, ...
        scen_results.s2.asl_in, scen_results.s2.asl_out);

    % Scenario 3: Abrupt Head Movement (Step Delay Shift)
    fprintf('--> Scenario 3: Abrupt Head Movement (5 to 25 sample delay step)...\n');
    delay3a = 5;  n3a = 0.8 * [zeros(delay3a, 1); noise_scen_base(1:end-delay3a)];
    delay3b = 25; n3b = 0.6 * [zeros(delay3b, 1); noise_scen_base(1:end-delay3b)];
    mid_pt = round(L_scen / 2);
    ambient_s3 = [n3a(1:mid_pt); n3b(mid_pt+1:end)];
    ambient_s3_scaled = scale_noise_for_snr(clean_s, ambient_s3, fs, -5);
    d3 = clean_s + ambient_s3_scaled;
    x3 = noise_scen_base;
    [e3, ~] = nlms_filter(d3, x3, N_nlms, mu_nlms, eps_nlms);

    scen_results.s3.stoi_in  = calculate_stoi(clean_s, d3, fs);
    scen_results.s3.stoi_out = calculate_stoi(clean_s, e3, fs);
    [scen_results.s3.asl_in, ~]  = calculate_active_speech_level(d3, fs);
    [scen_results.s3.asl_out, ~] = calculate_active_speech_level(e3, fs);
    fprintf('    STOI: In = %.4f | Out = %.4f | Gain = %+.4f\n', ...
        scen_results.s3.stoi_in, scen_results.s3.stoi_out, scen_results.s3.stoi_out - scen_results.s3.stoi_in);
    fprintf(fid_scen, '3,Abrupt_Movement,-5,%.4f,%.4f,%.4f,%.2f,%.2f\n', ...
        scen_results.s3.stoi_in, scen_results.s3.stoi_out, scen_results.s3.stoi_out - scen_results.s3.stoi_in, ...
        scen_results.s3.asl_in, scen_results.s3.asl_out);

    % Scenario 4: Extreme Low SNR (-15 dB Sub-Bass Environment)
    fprintf('--> Scenario 4: Extreme Low SNR (-15 dB Sub-Bass Noise)...\n');
    [b_lp, a_lp] = butter(2, 200 / (fs/2), 'low');
    bass_noise = filter(b_lp, a_lp, noise_scen_base);
    delay_s4 = 5;
    ambient_s4 = 0.8 * [zeros(delay_s4, 1); bass_noise(1:end-delay_s4)];
    ambient_s4_scaled = scale_noise_for_snr(clean_s, ambient_s4, fs, -15);
    d4 = clean_s + ambient_s4_scaled;
    x4 = bass_noise;
    [e4, ~] = nlms_filter(d4, x4, N_nlms, mu_nlms, eps_nlms);

    scen_results.s4.stoi_in  = calculate_stoi(clean_s, d4, fs);
    scen_results.s4.stoi_out = calculate_stoi(clean_s, e4, fs);
    [scen_results.s4.asl_in, ~]  = calculate_active_speech_level(d4, fs);
    [scen_results.s4.asl_out, ~] = calculate_active_speech_level(e4, fs);
    fprintf('    STOI: In = %.4f | Out = %.4f | Gain = %+.4f (Massive Bass Cancellation!)\n', ...
        scen_results.s4.stoi_in, scen_results.s4.stoi_out, scen_results.s4.stoi_out - scen_results.s4.stoi_in);
    fprintf(fid_scen, '4,Extreme_Low_SNR_Bass,-15,%.4f,%.4f,%.4f,%.2f,%.2f\n', ...
        scen_results.s4.stoi_in, scen_results.s4.stoi_out, scen_results.s4.stoi_out - scen_results.s4.stoi_in, ...
        scen_results.s4.asl_in, scen_results.s4.asl_out);

    % Scenario 5: Continuous Panning / Head Rotation (Sinusoidal Modulation)
    fprintf('--> Scenario 5: Continuous Head Sweeping (0.5 Hz Sinusoidal Delay)...\n');
    f_pan = 0.5;
    base_del = 10; max_dev = 8;
    ambient_s5 = zeros(L_scen, 1);
    for n = 1:L_scen
        cur_del = round(base_del + max_dev * sin(2*pi*f_pan*t_scen(n)));
        if n > cur_del
            ambient_s5(n) = 0.8 * noise_scen_base(n - cur_del);
        end
    end
    ambient_s5_scaled = scale_noise_for_snr(clean_s, ambient_s5, fs, 0);
    d5 = clean_s + ambient_s5_scaled;
    x5 = noise_scen_base;
    [e5, ~] = nlms_filter(d5, x5, N_nlms, mu_nlms, eps_nlms);

    scen_results.s5.stoi_in  = calculate_stoi(clean_s, d5, fs);
    scen_results.s5.stoi_out = calculate_stoi(clean_s, e5, fs);
    [scen_results.s5.asl_in, ~]  = calculate_active_speech_level(d5, fs);
    [scen_results.s5.asl_out, ~] = calculate_active_speech_level(e5, fs);
    fprintf('    STOI: In = %.4f | Out = %.4f | Gain = %+.4f\n', ...
        scen_results.s5.stoi_in, scen_results.s5.stoi_out, scen_results.s5.stoi_out - scen_results.s5.stoi_in);
    fprintf(fid_scen, '5,Continuous_Rotation,0,%.4f,%.4f,%.4f,%.2f,%.2f\n', ...
        scen_results.s5.stoi_in, scen_results.s5.stoi_out, scen_results.s5.stoi_out - scen_results.s5.stoi_in, ...
        scen_results.s5.asl_in, scen_results.s5.asl_out);

    fclose(fid_scen);
    fprintf('  Saved Scenarios CSV: %s\n', scenarios_csv);

    % Export Audio Files
    audiowrite(fullfile(audit_dir, 'scenario1_reverb_primary.wav'), d1, fs);
    audiowrite(fullfile(audit_dir, 'scenario1_reverb_enhanced.wav'), e1, fs);
    audiowrite(fullfile(audit_dir, 'scenario2_leakage_primary.wav'), d2, fs);
    audiowrite(fullfile(audit_dir, 'scenario2_leakage_enhanced.wav'), e2, fs);
    audiowrite(fullfile(audit_dir, 'scenario4_bass_primary.wav'), d4, fs);
    audiowrite(fullfile(audit_dir, 'scenario4_bass_enhanced.wav'), e4, fs);
    audiowrite(fullfile(audit_dir, 'scenario5_panning_primary.wav'), d5, fs);
    audiowrite(fullfile(audit_dir, 'scenario5_panning_enhanced.wav'), e5, fs);

    % 6. Save Mat Workspace
    mat_file = fullfile(metadata_dir, 'comprehensive_filter_benchmark.mat');
    save(mat_file, 'benchmark_data', 'scen_results', 'snr_grid', 'genres', 'speech_groups');
    fprintf('\n--> Saved Full Benchmark MAT: %s\n', mat_file);

    % 7. Generate Visualizations
    fprintf('--> Generating Comparative Figures in %s...\n', figures_dir);
    set(0, 'DefaultAxesFontSize', 11);
    set(0, 'DefaultAxesFontName', 'Helvetica');

    % Figure 1: STOI Intelligibility across SNRs (Notch vs. NLMS vs. Bandpass)
    fig1 = figure('Name', 'STOI Benchmark: All Filters', 'Position', [100, 100, 1100, 500], 'Visible', 'off');
    
    genres_plot = {'techno', 'rock'};
    for p = 1:2
        gk = genres_plot{p};
        subplot(1, 2, p);
        hold on; grid on; box on;
        
        st_u = arrayfun(@(s) benchmark_data.combined.(gk).(sprintf(ternary(s>=0, 'snr_plus%ddB', 'snr_%ddB'), abs(s))).stoi_unproc, snr_grid);
        st_bp= arrayfun(@(s) benchmark_data.combined.(gk).(sprintf(ternary(s>=0, 'snr_plus%ddB', 'snr_%ddB'), abs(s))).stoi_iir, snr_grid);
        st_nt= arrayfun(@(s) benchmark_data.combined.(gk).(sprintf(ternary(s>=0, 'snr_plus%ddB', 'snr_%ddB'), abs(s))).stoi_notch, snr_grid);
        st_nl= arrayfun(@(s) benchmark_data.combined.(gk).(sprintf(ternary(s>=0, 'snr_plus%ddB', 'snr_%ddB'), abs(s))).stoi_nlms, snr_grid);
        st_hy= arrayfun(@(s) benchmark_data.combined.(gk).(sprintf(ternary(s>=0, 'snr_plus%ddB', 'snr_%ddB'), abs(s))).stoi_hybrid, snr_grid);

        plot(snr_grid, st_u,  'k--',  'LineWidth', 1.8, 'DisplayName', 'Unprocessed Noisy');
        plot(snr_grid, st_bp, 'r-o',  'LineWidth', 1.8, 'DisplayName', '8th-Ord IIR Bandpass');
        plot(snr_grid, st_nt, 'b-s',  'LineWidth', 2.0, 'DisplayName', 'Parametric Notch');
        plot(snr_grid, st_nl, 'g-^',  'LineWidth', 2.2, 'DisplayName', 'Dual-Mic NLMS');
        plot(snr_grid, st_hy, 'm-d',  'LineWidth', 2.2, 'DisplayName', 'Hybrid Notch+NLMS');

        xlabel('Input SNR (dB)');
        ylabel('STOI Intelligibility Score');
        title(sprintf('Speech Intelligibility vs. Noise Level: %s', upper(gk)));
        ylim([0.65, 1.0]);
        legend('Location', 'southeast');
    end

    fig1_path = fullfile(figures_dir, 'benchmark_nlms_vs_filters_stoi.png');
    saveas(fig1, fig1_path);
    close(fig1);
    fprintf('  Saved Figure: %s\n', fig1_path);

    fprintf('\n=========================================================================\n');
    fprintf('  BENCHMARK COMPLETE! All metrics saved and figures generated.\n');
    fprintf('=========================================================================\n');
end

function val = ternary(cond, a, b)
    if cond, val = a; else, val = b; end
end
