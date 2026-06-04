% baro_gps_offset.m
% Given a Wyoming/Iowa State high-res radiosonde CSV, finds:
%   1. The GPS MSL altitude (ft) corresponding to exactly N ft AGL true altitude
%   2. What a barometric altimeter (zeroed at launch) would read at that point
%   3. The baro error vs true AGL
%
% CSV format expected (Iowa State high-res):
%   time, longitude, latitude, pressure_hPa, geopotential_height_m,
%   temperature_C, dew_point_C, ice_point_C, RH_%, RH_ice_%, mixing_ratio,
%   wind_dir_deg, wind_speed_m/s

clc; clear;

%% ── USER INPUTS ──────────────────────────────────────────────────────────────
csv_file       = '2026052500-72265.csv';   % path to sounding CSV
target_agl_ft  = 30000;                    % desired true AGL altitude (ft)
% Launch site conditions (use actual pad readings, not sounding surface)
% Leave empty [] to use sounding surface row automatically
launch_pres_hPa = [];   % e.g. 912.0 — measured at pad. [] = use sounding
launch_temp_C   = [];   % e.g. 31.0  — measured at pad. [] = use sounding

%% ── CONSTANTS ────────────────────────────────────────────────────────────────
g      = 9.80665;    % m/s^2
R      = 287.05;     % J/(kg·K)
L      = 0.0065;     % K/m  lapse rate
T0_std = 288.15;     % K    ISA sea-level temp
P0_std = 101325.0;   % Pa   ISA sea-level pressure

%% ── LOAD CSV ─────────────────────────────────────────────────────────────────
opts = detectImportOptions(csv_file, 'NumHeaderLines', 1);
opts.MissingRule = 'omitrow';            % drop rows with missing sensor data
T = readtable(csv_file, opts);

% Column indices (0-based in file, MATLAB table uses names)
% Rename for clarity regardless of original header strings
T.Properties.VariableNames = { ...
    'time', 'lon', 'lat', 'pres_hPa', 'height_m', ...
    'temp_C', 'dewp_C', 'icep_C', 'RH', 'RH_ice', ...
    'mixr', 'wdir', 'wspd_ms' };

pres_Pa   = T.pres_hPa * 100;
height_m  = T.height_m;

%% ── SURFACE CONDITIONS ───────────────────────────────────────────────────────
surface_height_msl_m = height_m(1);

if isempty(launch_pres_hPa)
    launch_pres_Pa = pres_Pa(1);
    fprintf('Using sounding surface pressure: %.1f hPa\n', pres_Pa(1)/100);
else
    launch_pres_Pa = launch_pres_hPa * 100;
end

if isempty(launch_temp_C)
    launch_temp_K = T.temp_C(1) + 273.15;
    fprintf('Using sounding surface temp:     %.1f °C\n', T.temp_C(1));
else
    launch_temp_K = launch_temp_C + 273.15;
end

%% ── TARGET ALTITUDE ──────────────────────────────────────────────────────────
target_agl_m  = target_agl_ft * 0.3048;
target_msl_m  = surface_height_msl_m + target_agl_m;

%% ── INTERPOLATE PRESSURE AT TARGET HEIGHT ────────────────────────────────────
% Find bracketing rows
idx = find(height_m >= target_msl_m, 1, 'first');
if isempty(idx) || idx == 1
    error('Target altitude %.0f m MSL is outside sounding range (%.0f–%.0f m)', ...
          target_msl_m, height_m(1), height_m(end));
end

h0 = height_m(idx-1);  h1 = height_m(idx);
p0 = pres_Pa(idx-1);   p1 = pres_Pa(idx);
frac = (target_msl_m - h0) / (h1 - h0);
P_target_Pa = p0 + frac * (p1 - p0);

%% ── BAROMETRIC ALTIMETER CALCULATION ────────────────────────────────────────
% Standard atmosphere: what MSL altitude does the baro report for P_target?
h_baro_target_m = (T0_std / L) * (1 - (P_target_Pa / P0_std)^(R*L/g));

% What does the baro read at the launch surface? (used to zero it)
h_baro_surface_m = (T0_std / L) * (1 - (launch_pres_Pa / P0_std)^(R*L/g));

% Baro AGL (zeroed at launch)
baro_agl_m  = h_baro_target_m - h_baro_surface_m;
baro_agl_ft = baro_agl_m / 0.3048;

%% ── GPS ALTITUDE ─────────────────────────────────────────────────────────────
% GPS reports MSL (WGS84 ellipsoid, close enough for this purpose)
gps_msl_m  = target_msl_m;
gps_msl_ft = gps_msl_m / 0.3048;

%% ── RESULTS ──────────────────────────────────────────────────────────────────
fprintf('\n======================================================\n');
fprintf('  Sounding file:  %s\n', csv_file);
fprintf('  Launch elev MSL: %.0f m  (%.0f ft)\n', ...
        surface_height_msl_m, surface_height_msl_m/0.3048);
fprintf('  Launch pressure: %.1f hPa\n', launch_pres_Pa/100);
fprintf('======================================================\n');
fprintf('\n  True target AGL:           %8.0f ft\n', target_agl_ft);
fprintf('  Pressure at target:        %8.2f hPa\n', P_target_Pa/100);
fprintf('\n  GPS will read (MSL):       %8.0f ft  ← set FC apogee target here\n', gps_msl_ft);
fprintf('  Baro reads (AGL, zeroed):  %8.0f ft\n', baro_agl_ft);
fprintf('  Baro error vs true AGL:    %+8.0f ft\n', baro_agl_ft - target_agl_ft);
fprintf('\n  In plain English:\n');
fprintf('  At true 30k ft AGL, your GPS will read %.0f ft MSL.\n', gps_msl_ft);
fprintf('  Your baro will UNDER-read by %.0f ft due to high surface\n', ...
        target_agl_ft - baro_agl_ft);
fprintf('  pressure and warm temperatures vs standard atmosphere.\n');
fprintf('======================================================\n\n');