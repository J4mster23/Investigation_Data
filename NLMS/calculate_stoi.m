function d = calculate_stoi(clean, degraded, fs)
% CALCULATE_STOI Computes a simplified Short-Time Objective Intelligibility (STOI) measure.
%   d = calculate_stoi(clean, degraded, fs) calculates the intelligibility
%   index between a clean speech signal and a degraded (or enhanced) signal.
%   Returns a value between 0 and 1, where higher is more intelligible.

    % Ensure signals are column vectors and equal length
    clean = clean(:);
    degraded = degraded(:);
    L = min(length(clean), length(degraded));
    clean = clean(1:L);
    degraded = degraded(1:L);

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
        d_k_norm = min(d_k * alpha, c_k * 1.5); % simple normalization/clipping
        
        r = corrcoef(c_k, d_k_norm);
        if numel(r) >= 4 && ~isnan(r(1, 2))
            corr_vals(k) = max(0, min(1, r(1, 2)));
        else
            corr_vals(k) = 0.5;
        end
    end
    
    d = mean(corr_vals);
end
