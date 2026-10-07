% export_venue_rirs.m
% Precomputes and exports ISM Room Impulse Responses for all 5 concert venues
% into dataset/metadata/venue_rirs.mat for use in Python ML simulation benchmarks.

clear; clc;
fprintf('========================================================================\n');
fprintf('  EXPORTING VENUE ROOM IMPULSE RESPONSES FOR PYTHON ML BENCHMARK        \n');
fprintf('========================================================================\n\n');

fs = 16000;
max_rir_sec = 0.45;

script_dir = fileparts(mfilename('fullpath'));
if isempty(script_dir), script_dir = pwd; end
addpath(script_dir);

repo_root = fullfile(script_dir, '..', '..');
metadata_dir = fullfile(repo_root, 'dataset', 'metadata');
if ~exist(metadata_dir, 'dir'), mkdir(metadata_dir); end

venues = struct();

% 1. Free-Field Stage
venues.freefield.name = 'Free-Field Stage';
venues.freefield.dim  = [12.0, 15.0, 4.0];
venues.freefield.rt60 = 0.00;
venues.freefield.speech_pos = [6.0, 8.65, 1.6];
venues.freefield.mic1_pos   = [6.0, 9.00, 1.6];
venues.freefield.mic2_pos   = [6.0, 9.04, 1.6];
venues.freefield.pa_left    = [2.0, 1.00, 2.5];
venues.freefield.pa_right   = [10.0, 1.00, 2.5];

% 2. Acoustically Damped Stage
venues.damped.name = 'Acoustically Damped Stage';
venues.damped.dim  = [12.0, 15.0, 4.0];
venues.damped.rt60 = 0.08;
venues.damped.speech_pos = [6.0, 8.65, 1.6];
venues.damped.mic1_pos   = [6.0, 9.00, 1.6];
venues.damped.mic2_pos   = [6.0, 9.04, 1.6];
venues.damped.pa_left    = [2.0, 1.00, 2.5];
venues.damped.pa_right   = [10.0, 1.00, 2.5];

% 3. Open-Air Festival
venues.festival.name = 'Open-Air Festival';
venues.festival.dim  = [40.0, 50.0, 15.0];
venues.festival.rt60 = 0.20;
venues.festival.speech_pos = [20.0, 14.65, 1.6];
venues.festival.mic1_pos   = [20.0, 15.00, 1.6];
venues.festival.mic2_pos   = [20.0, 15.04, 1.6];
venues.festival.pa_left    = [8.0, 3.00, 4.0];
venues.festival.pa_right   = [32.0, 3.00, 4.0];

% 4. Nightclub
venues.club.name = 'Nightclub';
venues.club.dim  = [12.0, 15.0, 4.0];
venues.club.rt60 = 0.70;
venues.club.speech_pos = [6.0, 8.65, 1.6];
venues.club.mic1_pos   = [6.0, 9.00, 1.6];
venues.club.mic2_pos   = [6.0, 9.04, 1.6];
venues.club.pa_left    = [2.0, 1.00, 2.5];
venues.club.pa_right   = [10.0, 1.00, 2.5];

% 5. Concert Arena
venues.arena.name = 'Concert Arena';
venues.arena.dim  = [25.0, 30.0, 8.0];
venues.arena.rt60 = 1.40;
venues.arena.speech_pos = [12.5, 17.65, 1.6];
venues.arena.mic1_pos   = [12.5, 18.00, 1.6];
venues.arena.mic2_pos   = [12.5, 18.04, 1.6];
venues.arena.pa_left    = [4.0, 2.00, 5.0];
venues.arena.pa_right   = [21.0, 2.00, 5.0];

venue_keys = {'freefield', 'damped', 'festival', 'club', 'arena'};
rirs = struct();

ear_axis_1 = [0, -1, 0];
ear_axis_2 = [0,  1, 0];

for v_idx = 1:length(venue_keys)
    v_key = venue_keys{v_idx};
    v = venues.(v_key);
    
    fprintf('--> Synthesizing ISM RIRs for [%s] (RT60 = %.2fs)...\n', v.name, v.rt60);
    
    [h_s1, ~] = simulate_room_impulse_response(v.dim, v.speech_pos, v.mic1_pos, v.rt60, fs, max_rir_sec, ear_axis_1);
    [h_s2, ~] = simulate_room_impulse_response(v.dim, v.speech_pos, v.mic2_pos, v.rt60, fs, max_rir_sec, ear_axis_2);
    
    [h_paL1, ~] = simulate_room_impulse_response(v.dim, v.pa_left, v.mic1_pos, v.rt60, fs, max_rir_sec, ear_axis_1);
    [h_paR1, ~] = simulate_room_impulse_response(v.dim, v.pa_right, v.mic1_pos, v.rt60, fs, max_rir_sec, ear_axis_1);
    [h_paL2, ~] = simulate_room_impulse_response(v.dim, v.pa_left, v.mic2_pos, v.rt60, fs, max_rir_sec, ear_axis_2);
    [h_paR2, ~] = simulate_room_impulse_response(v.dim, v.pa_right, v.mic2_pos, v.rt60, fs, max_rir_sec, ear_axis_2);
    
    rirs.(v_key).h_s1 = h_s1;
    rirs.(v_key).h_s2 = h_s2;
    rirs.(v_key).h_n1 = 0.5 * (h_paL1 + h_paR1);
    rirs.(v_key).h_n2 = 0.5 * (h_paL2 + h_paR2);
    rirs.(v_key).name = v.name;
    rirs.(v_key).rt60 = v.rt60;
end

out_mat = fullfile(metadata_dir, 'venue_rirs.mat');
save(out_mat, 'rirs', 'fs', 'venue_keys');
fprintf('\nAll 5 Venue RIR profiles successfully saved to:\n  %s\n', out_mat);
