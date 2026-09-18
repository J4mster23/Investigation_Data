function [e, w] = nlms_leaky_filter(d, x, N, mu, epsilon, gamma, vad_mask)
% nlms_leaky_filter Applies a Leaky NLMS algorithm with optional VAD control
%
% Inputs:
%   d        - Primary microphone signal
%   x        - Reference microphone signal
%   N        - Filter order (number of taps)
%   mu       - Base step size
%   epsilon  - Regularization constant
%   gamma    - Leakage factor (e.g., 0.999). If 1, no leakage.
%   vad_mask - Optional. Continuous mask [0, 1] indicating speech presence.
%              If not provided, the filter acts as a pure Leaky NLMS.
%
% Outputs:
%   e        - Error signal (enhanced speech estimate)
%   w        - Final filter weights

    if nargin < 7
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
        x_vec = flipud(x_padded(n : n+N-1));
        
        % Compute filter output
        y = w' * x_vec;
        
        % Compute error signal
        e(n) = d(n) - y;
        
        % Dynamic step size based on VAD
        % If vad_mask(n) approaches 1 (speech present), mu_eff approaches 0 (freeze)
        mu_eff = mu * (1 - vad_mask(n));
        
        % Update filter weights using Leaky NLMS equation
        norm_x = x_vec' * x_vec;
        w = gamma * w + (mu_eff / (norm_x + epsilon)) * e(n) * x_vec;
    end
end
