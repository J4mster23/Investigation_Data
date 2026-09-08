% scripts/diagnose_all_filters.m
cd('/Users/macairm1/Documents/antigravity/blissful-bose');
ws = load('dataset/metadata/filter_comparison_workspace.mat');
genres = {'jazz', 'rock', 'techno'};

fprintf('\n=== FILTER MAXIMUM GAIN AUDIT ===\n');
for i = 1:3
    g = genres{i};
    % FIR
    [h_fir, f] = freqz(ws.filters_fir.(g).b, 1, 4096, 16000);
    mag_fir = 20*log10(abs(h_fir));
    [max_fir, idx_fir] = max(mag_fir);
    
    % IIR
    [b_iir, a_iir] = sos2tf(ws.filters_iir.(g).sos, ws.filters_iir.(g).g);
    [h_iir, ~] = freqz(b_iir, a_iir, f, 16000);
    mag_iir = 20*log10(abs(h_iir));
    [max_iir, idx_iir] = max(mag_iir);
    
    % Notch
    [b_n, a_n] = sos2tf(ws.filters_notch.(g).sos);
    [h_n, ~] = freqz(b_n, a_n, f, 16000);
    mag_n = 20*log10(abs(h_n));
    [max_n, idx_n] = max(mag_n);
    
    fprintf('[%s]\n', upper(g));
    fprintf('  FIR Bandpass:     Max Gain = %+6.2f dB (at %6.1f Hz)\n', max_fir, f(idx_fir));
    fprintf('  IIR Bandpass:     Max Gain = %+6.2f dB (at %6.1f Hz)\n', max_iir, f(idx_iir));
    fprintf('  Parametric Notch: Max Gain = %+6.2f dB (at %6.1f Hz)\n', max_n, f(idx_n));
end
