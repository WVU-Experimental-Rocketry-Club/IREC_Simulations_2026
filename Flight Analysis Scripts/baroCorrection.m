% baro_gps_offset.m
% Answers: "When my baro reads exactly N ft AGL, what does GPS read?"
%
% Uses a high-res radiosonde CSV (Iowa State format) to account for real
% atmospheric conditions rather than assuming ISA.
%
% CSV columns:
%   time, lon, lat, pressure_hPa, geopotential_height_m,
%   temperature_C, dew_point_C, ice_point_C, RH%, RH_ice%,
%   mixing_ratio, wind_dir_deg, wind_speed_m/s

clc; clear;

%% ── USER INPUTS ──────────────────────────────────────────────────────────────
csv_file           = '2026052500-72265.csv';  % sounding CSV
target_baro_agl_ft = 30000;                   % baro reading you want (ft AGL)
launch_site_msl_ft = 2930;                    % pad elevation (ft MSL)

% Measured at the pad on launch day. Leave empty [] to interpolate from sounding.
launch_pres_hPa = [];   % e.g. 912.5. [] = interpolate from sounding
launch_temp_C   = [];   % e.g. 28.0.  [] = interpolate from sounding (display only)

%% ── CONSTANTS ────────────────────────────────────────────────────────────────
g      = 9.80665;    % m/s^2
R      = 287.05;     % J/(kg·K)
L      = 0.0065;     % K/m, ISA lapse rate
T0_std = 288.15;     % K,   ISA sea-level temp
P0_std = 101325.0;   % Pa,  ISA sea-level pressure

%% ── LOAD CSV ─────────────────────────────────────────────────────────────────
opts = detectImportOptions(csv_file, 'NumHeaderLines', 1);
opts.MissingRule = 'omitrow';
T = readtable(csv_file, opts);
T.Properties.VariableNames = { ...
    'time','lon','lat','pres_hPa','height_m', ...
    'temp_C','dewp_C','icep_C','RH','RH_ice', ...
    'mixr','wdir','wspd_ms' };

pres_Pa  = T.pres_hPa * 100;   % Pa, decreasing with altitude
height_m = T.height_m;          % m MSL, increasing with altitude

%% ── LAUNCH SITE CONDITIONS ───────────────────────────────────────────────────
launch_site_msl_m = launch_site_msl_ft * 0.3048;

% Surface pressure: interpolate sounding at launch site elevation if not given
if isempty(launch_pres_hPa)
    idx = find(height_m >= launch_site_msl_m, 1, 'first');
    if isempty(idx) || idx == 1
        error('Launch site elevation is outside sounding range.');
    end
    h0 = height_m(idx-1); h1 = height_m(idx);
    p0 = pres_Pa(idx-1);  p1 = pres_Pa(idx);
    launch_pres_Pa = p0 + (launch_site_msl_m - h0)/(h1 - h0) * (p1 - p0);
else
    launch_pres_Pa = launch_pres_hPa * 100;
end

% Surface temp (display only)
if isempty(launch_temp_C)
    idx = find(height_m >= launch_site_msl_m, 1, 'first');
    if ~isempty(idx) && idx > 1
        h0 = height_m(idx-1); h1 = height_m(idx);
        t0 = T.temp_C(idx-1); t1 = T.temp_C(idx);
        launch_temp_display = t0 + (launch_site_msl_m - h0)/(h1 - h0) * (t1 - t0);
    else
        launch_temp_display = T.temp_C(1);
    end
else
    launch_temp_display = launch_temp_C;
end

%% ── CORE CALCULATION ─────────────────────────────────────────────────────────
% Step 1: ISA altitude the baro assigns to the launch surface pressure
h_isa_launch_m = (T0_std / L) * (1 - (launch_pres_Pa / P0_std)^(R*L/g));

% Step 2: ISA altitude the baro must reach to read target AGL (after zeroing)
h_isa_target_m = h_isa_launch_m + target_baro_agl_ft * 0.3048;

% Step 3: What real pressure does ISA assign to that altitude?
P_required_Pa = P0_std * (1 - L * h_isa_target_m / T0_std)^(g/(R*L));

% Step 4: Find where that pressure actually occurs in the real atmosphere
idx = find(pres_Pa <= P_required_Pa, 1, 'first');
if isempty(idx) || idx == 1
    error('Required pressure %.2f hPa is outside sounding range.', P_required_Pa/100);
end
h0 = height_m(idx-1); h1 = height_m(idx);
p0 = pres_Pa(idx-1);  p1 = pres_Pa(idx);
true_msl_m = h0 + (P_required_Pa - p0)/(p1 - p0) * (h1 - h0);

% Step 5: Express as AGL and MSL
gps_msl_ft = true_msl_m / 0.3048;
gps_agl_ft = gps_msl_ft - launch_site_msl_ft;

%% ── RESULTS ──────────────────────────────────────────────────────────────────
fprintf('\n======================================================\n');
fprintf('  Sounding:         %s\n',       csv_file);
fprintf('  Launch site MSL:  %.0f ft\n',  launch_site_msl_ft);
fprintf('  Launch pressure:  %.1f hPa\n', launch_pres_Pa/100);
fprintf('  Launch temp:      %.1f C  (%.1f F)\n', ...
        launch_temp_display, launch_temp_display*9/5+32);
fprintf('======================================================\n');
fprintf('\n  When baro reads %.0f ft AGL:\n', target_baro_agl_ft);
fprintf('    GPS AGL:  %.0f ft\n', gps_agl_ft);
fprintf('    GPS MSL:  %.0f ft\n', gps_msl_ft);
fprintf('\n  Baro is reading %.0f ft LOW\n', gps_agl_ft - target_baro_agl_ft);
fprintf('  (warm/dense air vs ISA standard atmosphere)\n');
fprintf('======================================================\n\n');