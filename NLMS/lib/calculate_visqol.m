function p = calculate_visqol(clean, degraded, fs)
% CALCULATE_VISQOL Computes the ViSQOL metric score.
%   p = calculate_visqol(clean, degraded, fs) calculates the ViSQOL
%   score between a clean speech signal and a degraded (or enhanced) signal.
%   This function wraps the MATLAB Audio Toolbox's built-in `visqol` function.
%   Returns a Mean Opinion Score (MOS) between 1 and 5.

% Ensure signals are column vectors and equal length
clean = clean(:);
degraded = degraded(:);
L = min(length(clean), length(degraded));
clean = clean(1:L);
degraded = degraded(1:L);

% Use the built-in visqol function from the Audio Toolbox
% Note: visqol requires fs to be 8000 or 16000.
if fs ~= 8000 && fs ~= 16000
    error('visqol requires the sample rate (fs) to be either 8000 Hz or 16000 Hz.');
end

try
    p = visqol(degraded, clean, fs, 'Mode', 'speech');
catch ME
    warning('calculate_visqol:visqolFailed', 'visqol function failed: %s', ME.message);
    p = NaN; % Return NaN if ViSQOL calculation fails
end
end
