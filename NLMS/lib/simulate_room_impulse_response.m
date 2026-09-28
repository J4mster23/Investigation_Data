function [rir, t_axis] = simulate_room_impulse_response(room_dim, src_pos, rec_pos, rt60, fs, max_time)
% SIMULATE_ROOM_IMPULSE_RESPONSE Computes multi-path Room Impulse Response (RIR)
% using the Image Source Method (ISM) for rectangular concert enclosures.
%
% Syntax:
%   [rir, t_axis] = simulate_room_impulse_response(room_dim, src_pos, rec_pos, rt60, fs, max_time)
%
% Inputs:
%   room_dim - [Lx, Ly, Lz] Room dimensions in meters (e.g., [12, 15, 4.0])
%   src_pos  - [xs, ys, zs] Acoustic source coordinates in meters
%   rec_pos  - [xr, yr, zr] Microphone receiver coordinates in meters
%   rt60     - Target reverberation time in seconds (e.g., 0.70 for club, 1.40 for arena)
%   fs       - Sampling frequency in Hz (default 16000)
%   max_time - Maximum RIR length in seconds (default min(rt60 * 1.1, 1.0))
%
% Outputs:
%   rir      - Column vector of impulse response samples normalized to peak
%   t_axis   - Time vector in seconds

    if nargin < 5 || isempty(fs), fs = 16000; end
    if nargin < 6 || isempty(max_time), max_time = min(rt60 * 1.1, 0.8); end

    c = 343.0; % Speed of sound in air (m/s)
    
    Lx = room_dim(1);
    Ly = room_dim(2);
    Lz = room_dim(3);
    
    V = Lx * Ly * Lz; % Room volume
    S = 2 * (Lx * Ly + Lx * Lz + Ly * Lz); % Total surface area
    
    % Norris-Eyring formula for average absorption coefficient alpha
    % RT60 = -0.161 * V / (S * ln(1 - alpha))
    % ln(1 - alpha) = -0.161 * V / (S * RT60)
    % alpha = 1 - exp(-0.161 * V / (S * max(rt60, 0.05)))
    alpha = 1 - exp(-0.161 * V / (S * max(rt60, 0.05)));
    alpha = min(max(alpha, 0.01), 0.95); % Bounded
    
    % Average wall reflection coefficient beta = sqrt(1 - alpha)
    beta = sqrt(1 - alpha);
    
    % Determine maximum image order based on max_time
    max_dist = c * max_time;
    Nx = ceil(max_dist / (2 * Lx));
    Ny = ceil(max_dist / (2 * Ly));
    Nz = ceil(max_dist / (2 * Lz));
    
    % Cap orders for computational efficiency while preserving early & late reflections
    Nx = min(Nx, 12);
    Ny = min(Ny, 12);
    Nz = min(Nz, 8);
    
    L_samples = round(max_time * fs);
    rir = zeros(L_samples, 1);
    
    xs = src_pos(1); ys = src_pos(2); zs = src_pos(3);
    xr = rec_pos(1); yr = rec_pos(2); zr = rec_pos(3);
    
    % Vectorized / structured loop over image sources
    for mx = -Nx:Nx
        for my = -Ny:Ny
            for mz = -Nz:Nz
                % 8 possible sign permutations for rectangular reflections
                for qx = [0, 1]
                    for qy = [0, 1]
                        for qz = [0, 1]
                            % Virtual image coordinate
                            if qx == 0, xi = 2*mx*Lx + xs; else, xi = 2*mx*Lx - xs; end
                            if qy == 0, yi = 2*my*Ly + ys; else, yi = 2*my*Ly - ys; end
                            if qz == 0, zi = 2*mz*Lz + zs; else, zi = 2*mz*Lz - zs; end
                            
                            dist = sqrt((xi - xr)^2 + (yi - yr)^2 + (zi - zr)^2);
                            
                            if dist > 0.05 && dist <= max_dist
                                delay_s = dist / c;
                                n_idx = round(delay_s * fs) + 1;
                                
                                if n_idx <= L_samples
                                    order = abs(2*mx + qx) + abs(2*my + qy) + abs(2*mz + qz);
                                    % Attenuation: 1 / (4*pi*dist) scaled by reflection decay
                                    gain = (beta ^ order) / (4 * pi * dist);
                                    
                                    % Direct path or reflection sign
                                    phase_sign = (-1) ^ order;
                                    rir(n_idx) = rir(n_idx) + phase_sign * gain;
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    % Apply mild high-frequency air damping (lowpass filter)
    % Acoustic absorption in air increases with frequency squared
    b_air = [0.85, 0.15];
    rir = filter(b_air, 1, rir);
    
    % Peak normalization
    max_val = max(abs(rir));
    if max_val > 0
        rir = rir / max_val;
    end
    
    t_axis = (0:L_samples-1)' / fs;
end
