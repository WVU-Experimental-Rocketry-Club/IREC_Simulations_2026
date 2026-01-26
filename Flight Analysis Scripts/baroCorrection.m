clc 
clear

actual_apogee_ft = 30994;
launch_pressure_hPa = 1015;
launch_temp_F = 81;
launch_temp_C = (launch_temp_F - 32) * (5/9);

% Constants
g = 9.80665;       % m/s^2
R = 287.05;        % J/(kg·K)
L = 0.0065;        % K/m
P0_actual = launch_pressure_hPa * 100;   % Actual surface pressure (Pa)
T0_actual = (launch_temp_F - 32) * 5/9 + 273.15;  % Actual temp in K

% Convert apogee to meters
h_true_m = actual_apogee_ft * 0.3048;

% Step 1: Compute pressure at true apogee based on actual conditions
P_apogee = P0_actual * (1 - (L * h_true_m) / T0_actual)^(g / (R * L));

% Step 2: Use standard atmosphere assumptions (what the barometer uses)
T0_std = 288.15;              % Standard temp (15°C)
P0_std = 101325;              % Standard sea level pressure (Pa)

% Step 3: Compute what altitude the barometer would report for P_apogee
h_baro_m = (T0_std / L) * (1 - (P_apogee / P0_std)^(R * L / g));
baro_reading_ft = h_baro_m / 0.3048;

% Display result
fprintf('True apogee: %.1f ft\n', actual_apogee_ft);
fprintf('Expected barometer reading: %.1f ft\n', baro_reading_ft);
fprintf('Offset due to atmospheric conditions: %.1f ft lower\n', actual_apogee_ft - baro_reading_ft);
