function varargout = normalize_for_export(target_peak, varargin)
% NORMALIZE_FOR_EXPORT Jointly normalizes multiple audio signals to a target peak.
%
%   [sig1, sig2, sig3] = normalize_for_export(0.9, sig1, sig2, sig3)
%
%   This ensures no signals clip when saving via audiowrite, while preserving
%   the relative amplitude differences between the signals.

% Find the global maximum absolute peak across all provided signals
global_max = 0;
for i = 1:nargin-1
    current_max = max(abs(varargin{i}(:)));
    if current_max > global_max
        global_max = current_max;
    end
end

% Calculate safety gain
if global_max > 0
    gain = target_peak / global_max;
else
    gain = 1;
end

% Apply gain to all signals and assign to outputs
varargout = cell(1, nargin-1);
for i = 1:nargin-1
    varargout{i} = varargin{i} * gain;
end
end