% -------------------------------------------------------------------------
% TeleMega Rocket Drag Coefficient (Cd) Analyzer
% -------------------------------------------------------------------------
%
% Description:
% This script analyzes flight data from a TeleMega flight computer's CSV
% output to determine the coefficient of drag (Cd) of a rocket during its
% coasting phase (from motor burnout to apogee).
%
% Instructions:
% 1. Run this script in MATLAB.
% 2. A file selection dialog will appear. Choose your TeleMega .csv file.
% 3. An input dialog will ask for your rocket's specific parameters.
% 4. The script will process the data and output:
%    - A command window summary with the average Cd.
%    - Plots showing the flight profile and the calculated Cd vs. Mach number.
%
% Required Rocket Parameters:
%   - Coast Mass (kg): The mass of the rocket after the motor has burned out.
%   - Rocket Diameter (m): The outer diameter of the rocket's main airframe.
%
% How it Works:
% 1.  It loads flight data (Time, Altitude, Velocity, Acceleration).
% 2.  It identifies the coasting phase of the flight.
% 3.  It smooths the noisy acceleration data using a moving average filter.
% 4.  For each data point in the coasting phase, it calculates:
%     a. Air density, temperature, and speed of sound using the
%        International Standard Atmosphere (ISA) model.
%     b. The total drag force using Newton's second law (F_drag = -m*(a+g)).
%     c. The coefficient of drag using the drag equation
%        (Cd = 2*F_drag / (rho * v^2 * A)).
% 5.  It averages the Cd values and plots Cd against the Mach number.
%
% -------------------------------------------------------------------------

%% --- Cleanup and Initialization ---
clear;
clc;
close all;

fprintf('Starting Rocket Drag Coefficient Analysis...\n');

%% --- User Inputs ---

% Step 1: Get the data file from the user
[fileName, pathName] = uigetfile('*.csv', 'Select the TeleMega CSV Data File');
if isequal(fileName, 0)
    disp('User selected Cancel. Exiting script.');
    return;
end
fullFilePath = fullfile(pathName, fileName);
fprintf('Loading data from: %s\n', fullFilePath);

[fileNameBalloon, pathNameBalloon] = uigetfile('*.csv', 'Select the Weather Balloon CSV Data File');
if isequal(fileNameBalloon, 0)
    disp('User selected Cancel. Exiting script.');
    return;
end
balloonFilePath = fullfile(pathNameBalloon, fileNameBalloon);
fprintf('Loading data from: %s\n', balloonFilePath);

% Step 2: Ask user for the units of the data in the CSV file
unit_choice = questdlg('Are the units in the CSV file in Meters or Feet?', ...
    'Select Data Units', ...
    'Meters (m, m/s, m/s^2)', 'Feet (ft, ft/s, ft/s^2)', 'Meters (m, m/s, m/s^2)');

unit_conversion_factor = 1.0; % Default to meters
if strcmp(unit_choice, 'Feet (ft, ft/s, ft/s^2)')
    unit_conversion_factor = 0.3048; % Conversion factor from feet to meters
    fprintf('Data will be converted from Feet to Meters for analysis.\n');
end

% Step 3: Get rocket parameters from the user via a dialog box
prompt = {'Enter Coast Mass (kg):', 'Enter Rocket Diameter (m):'};
dlgtitle = 'Rocket Parameters';
dims = [1 50];
definput = {'38.14712', '0.158242'};
answer = inputdlg(prompt, dlgtitle, dims, definput);

if isempty(answer)
    disp('User selected Cancel. Exiting script.');
    return;
end

% Convert string inputs to numbers
m = str2double(answer{1}); % Rocket coast mass in kg
d = str2double(answer{2}); % Rocket diameter in m
A = pi * (d/2)^2;          % Cross-sectional area in m^2

% --- ADVANCED PARAMETER ---
% Delay after max velocity before starting coast analysis (seconds).
% This helps to avoid the "thrust tailing" phase of the motor burn,
% where residual thrust can make the calculated Cd artificially low.
prompt = {'Enter Motor Burn time (s):', 'Enter Coast Early End Amount (s):'};
dlgtitle = 'Analysis Time Window';
dims = [1 50];
definput = {'9.25', '3'};
answer = inputdlg(prompt, dlgtitle, dims, definput);

if isempty(answer)
    disp('User selected Cancel. Exiting script.');
    return;
end
motorBurnTime = str2double(answer{1}); 
coast_end_early = str2double(answer{2}); % how many seconds to remove before apogee to eliminate unusable data


%% --- Data Loading and Preparation ---

% Load the CSV data into a table
try
    telemegaData = readtable(fullFilePath);
    balloonData = readtable(balloonFilePath);
    
    % Find all required columns. The script will now look for pressure
    % and temperature to calculate air density directly from flight data.
    timeVar = find(strcmpi(telemegaData.Properties.VariableNames, 'time'));
    altVar = find(strcmpi(telemegaData.Properties.VariableNames, 'altitude_gps'));
    velVar = find(strcmpi(telemegaData.Properties.VariableNames, 'speed'));
    accelVar = find(strcmpi(telemegaData.Properties.VariableNames, 'accel_x')); % Prioritize accel_x
    pressureVar = find(contains(telemegaData.Properties.VariableNames, 'pressure', 'IgnoreCase', true), 1);
    tempVar = find(contains(telemegaData.Properties.VariableNames, 'Temperature', 'IgnoreCase', true), 1);

    balloonHeight_m = find(strcmpi(balloonData.Properties.VariableNames, "geopotentialHeight_m"));
    balloonPressure_hPa = find(strcmpi(balloonData.Properties.VariableNames, 'pressure_hPa'));
    balloonTemp_C = find(strcmpi(balloonData.Properties.VariableNames, 'temperature_C'));
    
    % Check for the new required columns as well
    if any([isempty(timeVar), isempty(altVar), isempty(velVar), isempty(accelVar), isempty(pressureVar), isempty(tempVar), isempty(balloonHeight_m), ...
            isempty(balloonPressure_hPa), isempty(balloonTemp_C)] )
        error('Could not automatically detect required columns in the CSV file(s). Please check column headers.');
    end
    
    time = telemegaData{:, timeVar};
    altitude = telemegaData{:, altVar};
    velocity = telemegaData{:, velVar};
    acceleration = telemegaData{:, accelVar};

    balloonAltitude = balloonData{:, balloonHeight_m}; %load balloon geopotential height (m)
    balloonPressure = balloonData{:, balloonPressure_hPa}; % Load pressure data (hPa)
    balloonTemperature = balloonData{:, balloonTemp_C}; % Load temperature data (C)
    
    % --- Apply unit conversion if necessary ---
    % This is a critical step. If data is in feet and not converted, the
    % v^2 term in the drag equation will be ~10.7x too large, making the
    % calculated Cd ~10.7x too small.
    if unit_conversion_factor ~= 1.0
        altitude = altitude * unit_conversion_factor;
        velocity = velocity * unit_conversion_factor;
        acceleration = acceleration * unit_conversion_factor;
    end
    
catch ME
    fprintf('Error reading or processing the file: %s\n', ME.message);
    return;
end

% Remove any NaN or non-finite values to prevent errors
validIdx = isfinite(time) & isfinite(altitude) & isfinite(velocity) & isfinite(acceleration);
time = time(validIdx);
altitude = altitude(validIdx);
velocity = velocity(validIdx);
acceleration = acceleration(validIdx);


%% --- Flight Phase Identification ---

% Find motor burnout (approximated as max velocity)
[~, burnoutIdx] = max(velocity);

burnoutTime = find(time >= motorBurnTime, 1, "first"); % find the index of motor burnout time

% If delay pushes us past apogee, handle the error
if isempty(burnoutTime)
    error('coast_start_delay is too large and pushes the analysis window beyond apogee.');
end

% Find apogee (max altitude)
[~, apogeeIdx] = max(altitude);
apogeeTime = time(apogeeIdx);

% Find the actual end of the coast phase by adding the delay
coastEndTime = apogeeTime - coast_end_early;
coastEndIdx = find(time >= coastEndTime, 1, "first");

% Define the coast phase data range
coastIdx = burnoutTime:coastEndIdx;

if isempty(coastIdx) || length(coastIdx) < 10
    error('Could not identify a valid coasting phase. Check flight data.');
end

fprintf('Flight Phase Identification Complete:\n');
fprintf(' - Motor Burnout at %.2f seconds (Max Velocity)\n', motorBurnTime);
fprintf(' - Apogee at %.2f seconds (Max Altitude)\n', apogeeTime);
fprintf(' - Coast analysis ends at %.2f seconds (%.2fs before apogee).\n', coastEndTime, coast_end_early);

%% --- Data Processing and Cd Calculation ---

% Constants
R = 287.058;      % Specific gas constant for dry air (J/kg·K)
gamma = 1.4;      % Ratio of specific heats for air

% Extract coasting phase data
time_coast = time(coastIdx);
alt_coast = altitude(coastIdx);
vel_coast = velocity(coastIdx);
accel_coast = acceleration(coastIdx); 

% --- Data Smoothing ---
% The raw accelerometer data is often noisy. A moving average filter helps to
% smooth it out to get a more stable basis for calculation.
% The window size may need adjustment for different data logging rates.
windowSize = 15; 
accel_coast_smoothed = movmean(accel_coast, windowSize);


% Initialize arrays for calculated values
DragForce = [];
Cd_values = [];
mach_values = [];

% Loop through each data point in the coast phase
for i = 1:length(time_coast)
    % Get instantaneous values
    h = alt_coast(i);
    v = vel_coast(i);
    a = accel_coast(i); % Use the smoothed accelerometer value
    

    balloonIndex = find(balloonAltitude >= h, 1, "first"); %finds the location where the balloon data lines up with rocket data
    p = balloonPressure(balloonIndex) * 100;
    % Avoid calculations when velocity is near zero (at apogee) to prevent
    % division by zero and nonsensical Cd values.
    if v < 10 % m/s threshold
        continue;
    end
    
    % --- METHOD IMPROVEMENT ---
    % Step A: Calculate atmospheric properties using a HYBRID model.
    % We use the accurate ONBOARD PRESSURE sensor data, but calculate
    % TEMPERATURE using the International Standard Atmosphere (ISA) model
    % as onboard temperature sensors can be unreliable.
    %T_k = calculate_isa_temperature(h); % Calculate temp from altitude
    T_k = balloonTemperature(balloonIndex) + 273.15;
    rho = p / (R * T_k); % Calculate density using Ideal Gas Law (P = rho*R*T)
    speed_of_sound = sqrt(gamma * R * T_k);
    
    % Step B: Calculate drag force from Newton's 2nd Law
    % Based on user feedback, the 'accel_x' column from the flight
    % computer represents the non-gravitational acceleration (proper
    % acceleration), primarily due to drag during the coast phase.
    % Therefore, F_drag = m * a_proper.
    % Since drag opposes motion (v is positive, a is negative), the
    % magnitude of the drag force is -m*a.
    F_drag = -m * (a);
    DragForce = [DragForce; F_drag / 4.448]; % not plotted, just saved as drag force in lbf
    % We only care about positive drag force values
    if F_drag <= 0
        continue;
    end
    
    % Step C: Calculate the Coefficient of Drag (Cd)
    % F_drag = 0.5 * rho * v^2 * A * Cd
    Cd = (2 * F_drag) / (rho * v^2 * A);

    % Store valid results
    
    Cd_values = [Cd_values; Cd];
    mach_values = [mach_values; v / speed_of_sound];
end

% Calculate the average Cd, ignoring outliers for a more robust result
% Using prctile to remove the top/bottom 5% of calculated values
lower_bound = prctile(Cd_values, 5);
upper_bound = prctile(Cd_values, 95);
valid_Cd_idx = Cd_values > lower_bound & Cd_values < upper_bound;
avg_Cd = mean(Cd_values(valid_Cd_idx));

%% --- Results and Visualization ---

fprintf('\n--- Analysis Complete ---\n');
fprintf('Average Coefficient of Drag (Cd): %.3f\n', avg_Cd);
fprintf('This was calculated using data between Mach %.2f and Mach %.2f.\n', min(mach_values), max(mach_values));

% Plotting
figure('Name', 'Flight Profile Analysis', 'NumberTitle', 'off', 'Position', [100, 100, 1200, 800]);

% Plot 1: Altitude vs. Time
subplot(3, 2, 1);
plot(time, altitude, 'b-', 'LineWidth', 1.5);
hold on;
xline(burnoutTime, 'r--', {'Burnout'});
xline(apogeeTime, 'g--', {'Apogee'});
title('Altitude vs. Time');
xlabel('Time (s)');
ylabel('Altitude (m)');
grid on;
legend('Altitude', 'Location', 'northwest');

% Plot 2: Velocity vs. Time
subplot(3, 2, 2);
plot(time, velocity, 'b-', 'LineWidth', 1.5);
hold on;
xline(burnoutTime, 'r--', {'Burnout'});
xline(apogeeTime, 'g--', {'Apogee'});
title('Vertical Velocity vs. Time');
xlabel('Time (s)');
ylabel('Velocity (m/s)');
grid on;
legend('Velocity', 'Location', 'northeast');

% Plot 3: Acceleration vs. Time (Raw and Smoothed)
subplot(3, 2, 3);
plot(time_coast, accel_coast, 'Color', [0.7 0.7 0.7], 'DisplayName', 'Raw Accelerometer');
hold on;
plot(time_coast, accel_coast_smoothed, 'r-', 'LineWidth', 1.5, 'DisplayName', 'Smoothed Acceleration');
title('Acceleration during Coast');
xlabel('Time (s)');
ylabel('Acceleration (m/s^2)');
grid on;
legend('show');

% Plot 4: Cd vs. Mach Number
subplot(3, 2, 4);
scatter(mach_values, Cd_values, 20, 'b', 'filled', 'DisplayName', 'Calculated Cd');
hold on;
yline(avg_Cd, 'r-', 'LineWidth', 2, 'DisplayName', sprintf('Average Cd = %.3f', avg_Cd));
title('Coefficient of Drag vs. Mach Number');
xlabel('Mach Number');
ylabel('Coefficient of Drag (Cd)');
grid on;
legend('show');
ylim([0, 0.7]); % Set a reasonable y-axis limit

% subplot(3, 2, 5);
% plot(time_coast, DragForce, 'LineWidth', 1.5);
% hold on;
% xline(burnoutTime, 'r--', {'Burnout'});
% xline(apogeeTime, 'g--', {'Apogee'});
% title('Drag Force (lbf) vs. Time');
% xlabel('Time (s)');
% ylabel('Drag Force (lbf)');
% grid on;
% legend('Drag Force', 'Location', 'northwest');


function T_k = calculate_isa_temperature(altitude)
    % Calculates temperature (in Kelvin) based on the International 
    % Standard Atmosphere model for a given altitude (in meters).
    
    T0 = 288.15;  % Sea level standard temperature (Kelvin)
    L = -0.0065;  % Temperature lapse rate (K/m) in the troposphere
    
    % ISA formula for temperature in the troposphere (up to 11km)
    T_k = T0 + L * altitude;
end
