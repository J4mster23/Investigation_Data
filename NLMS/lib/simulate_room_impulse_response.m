function [rir, t_axis] = simulate_room_impulse_response(room_dim, src_pos, rec_pos, rt60, fs, max_time, ear_axis)
% SIMULATE_ROOM_IMPULSE_RESPONSE Computes multi-path Room Impulse Response (RIR)
% Vectorized Image Source Method (ISM) with optional Mannequin Head Shadowing.
%
% Syntax:
%   [rir, t_axis] = simulate_room_impulse_response(room_dim, src_pos, rec_pos, rt60, fs, max_time, ear_axis)
%
% Inputs:
%   room_dim - [Lx, Ly, Lz] Room dimensions in meters
%   src_pos - [xs, ys, zs] Acoustic source coordinates in meters
%   rec_pos - [xr, yr, zr] Microphone receiver coordinates in meters
%   rt60 - Target reverberation time in seconds
%   fs - Sampling frequency in Hz (default 16000)
%   max_time - Maximum RIR length in seconds
%   ear_axis - (Optional) [x, y, z] vector pointing outward from the ear.
%              If provided, applies a frequency-dependent acoustic shadow.
%
% Outputs:
%   rir - Column vector of impulse response samples normalized to peak
%   t_axis - Time vector in seconds

    if nargin < 5 || isempty(fs), fs = 16000; end
    if nargin < 6 || isempty(max_time), max_time = min(rt60 * 1.1, 0.8); end
    apply_shadow = (nargin >= 7 && ~isempty(ear_axis));

    if apply_shadow
        % Normalize the look vector just in case
        ear_axis = ear_axis / norm(ear_axis);
    end

    c = 343.0; % Speed of sound in air (m/s)
    Lx = room_dim(1); Ly = room_dim(2); Lz = room_dim(3);
    
    V = Lx * Ly * Lz; 
    S = 2 * (Lx*Ly + Lx*Lz + Ly*Lz); 
    
    % Norris-Eyring average absorption and wall reflection coefficient
    alpha = 1 - exp(-0.161 * V / (S * max(rt60, 0.05)));
    alpha = min(max(alpha, 0.01), 0.95); 
    beta = sqrt(1 - alpha);
    
    % Determine maximum image order based on strict max_time
    max_dist = c * max_time;
    Nx = ceil(max_dist / (2 * Lx));
    Ny = ceil(max_dist / (2 * Ly));
    Nz = ceil(max_dist / (2 * Lz));
    
    L_samples = round(max_time * fs);
    
    % Initialize RIR arrays
    if apply_shadow
        rir_direct = zeros(L_samples, 1);
        rir_shadow = zeros(L_samples, 1);
    else
        rir = zeros(L_samples, 1);
    end
    
    % Vectorized image grid mapping
    [MX, MY, MZ] = ndgrid(-Nx:Nx, -Ny:Ny, -Nz:Nz);

    % Loop over the 8 room permutations (much faster than looping all combos)
    for qx = 0:1
        for qy = 0:1
            for qz = 0:1
                % 1. Compute virtual coordinates for this permutation
                xi = 2 * MX * Lx + (1 - 2*qx) * src_pos(1);
                yi = 2 * MY * Ly + (1 - 2*qy) * src_pos(2);
                zi = 2 * MZ * Lz + (1 - 2*qz) * src_pos(3);

                % 2. Distances from receiver
                dist = sqrt((xi - rec_pos(1)).^2 + (yi - rec_pos(2)).^2 + (zi - rec_pos(3)).^2);

                % 3. Filter valid paths within time boundary
                valid = dist > 0.05 & dist <= max_dist;
                dist_v = dist(valid);

                % 4. Correct reflection order calculation: | 2m - q |
                order_x = abs(2 * MX(valid) - qx);
                order_y = abs(2 * MY(valid) - qy);
                order_z = abs(2 * MZ(valid) - qz);
                total_order = order_x + order_y + order_z;

                % 5. Compute acoustic attenuation
                gain_v = (beta.^total_order) ./ (4 * pi * dist_v);

                % 6. Map to time indices
                idx_v = round((dist_v / c) * fs) + 1;
                in_bounds = idx_v <= L_samples;

                if ~any(in_bounds)
                    continue;
                end

                % 7. Accumulate into RIR
                if apply_shadow
                    % Calculate Angle of Arrival relative to ear outward vector
                    vec_x = xi(valid) - rec_pos(1);
                    vec_y = yi(valid) - rec_pos(2);
                    vec_z = zi(valid) - rec_pos(3);
                    
                    cos_theta = (vec_x.*ear_axis(1) + vec_y.*ear_axis(2) + vec_z.*ear_axis(3)) ./ dist_v;
                    
                    % Split rays: Front hemisphere (direct) vs Back hemisphere (shadowed)
                    is_direct = cos_theta > 0;
                    is_shadow = cos_theta <= 0;
                    
                    idx_dir = in_bounds & is_direct;
                    idx_shad = in_bounds & is_shadow;
                    
                    if any(idx_dir)
                        rir_direct = rir_direct + accumarray(idx_v(idx_dir), gain_v(idx_dir), [L_samples, 1]);
                    end
                    if any(idx_shad)
                        rir_shadow = rir_shadow + accumarray(idx_v(idx_shad), gain_v(idx_shad), [L_samples, 1]);
                    end
                else
                    % Standard Omnidirectional Accumulation
                    rir = rir + accumarray(idx_v(in_bounds), gain_v(in_bounds), [L_samples, 1]);
                end
            end
        end
    end

    % 8. Apply Physical Head Diffraction Filter
    if apply_shadow
        % ~1500 Hz cutoff mimics the diffraction limit of an 18cm human head
        [b_head, a_head] = butter(1, 1500/(fs/2), 'low');
        rir_shadow_filtered = filter(b_head, a_head, rir_shadow);
        
        rir = rir_direct + rir_shadow_filtered;
    end

    % 9. Peak Normalization
    max_val = max(abs(rir));
    if max_val > 0
        rir = rir / max_val;
    end
    
    t_axis = (0:L_samples-1)' / fs;
end
