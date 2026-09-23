function [e, w] = nlms_filter(d, x, N, mu, epsilon, vad_mask)
% nlms_filter applies the Normalized Least Mean Squares (NLMS) algorithm
%
% Inputs:
%   d        - Primary microphone signal (desired signal + noise)
%   x        - Reference microphone signal (noise source)
%   N        - Filter order (number of taps)
%   mu       - Step size
%   epsilon  - Regularization constant
%   vad_mask - Optional. Continuous mask [0, 1] indicating speech presence.
%              If not provided, the filter acts as a normal NLMS.
%
% Outputs:
%   e        - Error signal (enhanced speech estimate)
%   w        - Final filter weights

    if nargin < 6
        vad_mask = zeros(length(d), 1);
    end

    % Initialize variables
    w = zeros(N, 1);
    e = zeros(length(d), 1);
    
    % Pad reference signal with zeros to handle the first N samples easily
    x_padded = [zeros(N-1, 1); x];
    
    % NLMS Iteration
    for n = 1:length(d)
        % Extract current input vector of length N
        % x_vec = [x(n); x(n-1); ...; x(n-N+1)]
        x_vec = flipud(x_padded(n : n+N-1));
        
        % Compute filter output
        y = w' * x_vec;
        
        % Compute error signal (Enhanced speech estimate)
        e(n) = d(n) - y;
        
        % Dynamic step size based on VAD
        mu_eff = mu * (1 - vad_mask(n));
        
        % Update filter weights using NLMS equation
        norm_x = x_vec' * x_vec; % ||x(n)||^2
        w = w + (mu_eff / (norm_x + epsilon)) * e(n) * x_vec;
    end
end
