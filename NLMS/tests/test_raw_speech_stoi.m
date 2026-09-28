script_dir = fileparts(mfilename('fullpath'));
repo_root = fullfile(script_dir, '..', '..');
addpath(fullfile(script_dir, '..', 'lib'));
speech_dir = fullfile(repo_root, 'dataset', 'speech_corpus', 'combined');
files = dir(fullfile(speech_dir, '*.wav'));

% 1. Clean anechoic speech compared to itself
scores_self = zeros(min(20, length(files)), 1);
for i = 1:length(scores_self)
    [s, fs] = audioread(fullfile(speech_dir, files(i).name));
    scores_self(i) = stoi(s, s, fs);
end
fprintf('1. Clean Anechoic Speech vs Itself:\n   Mean STOI = %.4f (Min = %.4f, Max = %.4f)\n\n', ...
    mean(scores_self), min(scores_self), max(scores_self));

% 2. Room reverberation alone (s * h_s1 vs anechoic clean speech s)
venues = {'Nightclub (RT60=0.70s)', 'Concert Arena (RT60=1.40s)', 'Festival (RT60=0.20s)'};
dims = {[12, 15, 4], [25, 30, 8], [40, 50, 15]};
rt60s = [0.70, 1.40, 0.20];
s_pos = {[6, 8.65, 1.6], [12.5, 17.65, 1.6], [20, 14.65, 1.6]};
m1_pos = {[6, 9.00, 1.6], [12.5, 18.00, 1.6], [20, 15.00, 1.6]};

for v = 1:3
    [h, ~] = simulate_room_impulse_response(dims{v}, s_pos{v}, m1_pos{v}, rt60s(v), fs, 0.45);
    rev_scores = zeros(min(20, length(files)), 1);
    for i = 1:length(rev_scores)
        [s, fs] = audioread(fullfile(speech_dir, files(i).name));
        s_rev = conv(s, h);
        s_rev = s_rev(1:length(s));
        % align direct path delay
        [~, max_idx] = max(abs(h));
        s_rev_aligned = [s_rev(max_idx:end); zeros(max_idx-1, 1)];
        rev_scores(i) = stoi(s_rev_aligned, s, fs);
    end
    fprintf('2. Reverberated Speech alone in %s vs Anechoic Clean:\n   Mean STOI = %.4f\n\n', ...
        venues{v}, mean(rev_scores));
end

% 3. Raw Noisy Microphone Input (Unprocessed d[n]) across SNRs and Genres
summary_csv = fullfile(script_dir, '..', 'output_audio', 'room_experiment', 'room_experiment_summary.csv');
opts = detectImportOptions(summary_csv);
T = readtable(summary_csv, opts);
fprintf('3. Unprocessed Raw Microphone Input (Speech + Background Noise) across SNRs:\n');
snrs = [-15, -10, -5, 0, 5, 10];
for s = snrs
    rows = (T.SNR_dB == s) & strcmp(T.Filter, 'Unprocessed');
    fprintf('   SNR %3d dB: Unprocessed Mean STOI = %.4f (Club: %.4f | Arena: %.4f | Fest: %.4f)\n', ...
        s, mean(T.Mean_STOI(rows)), ...
        mean(T.Mean_STOI(rows & strcmp(T.Venue, 'club'))), ...
        mean(T.Mean_STOI(rows & strcmp(T.Venue, 'arena'))), ...
        mean(T.Mean_STOI(rows & strcmp(T.Venue, 'festival'))));
end
