%% Motor Thrust Curve Back-Calculation Program
% This script reads telemetry data from a CSV file,
% back-calculates the net force, and then uses the principles of physics
% to determine the motor's thrust curve over time.

% =========================================================================
% USER INPUTS - EDIT THESE VALUES TO MATCH YOUR FLIGHT DATA AND ROCKET
% =========================================================================

% 1. Filename of your telemetry CSV file.
%    Assumes the file is in the same directory as this script.
filename = 'onboard flight data.csv';
%filename = 'sSunset_telemega_03292025_1.csv';
%filename = 'AppSunset6674FullTelem.csv';


% 2. Assumed column headers in your CSV file.
%    Edit these to match the exact headers in your data.
column_headers = {'time', 'altitude', 'speed', 'accel_x', 'pressure'};

% 3. Rocket parameters.
%    You need to provide these to accurately model mass and drag.
initial_mass_kg = 54.88;   % Mass of the rocket at launch (including motor)
final_mass_kg = 38.147;     % Mass of the rocket at motor burnout
rocket_diameter_m = 0.158242; % Diameter of the rocket (for drag calculation)

% 4. Drag coefficient lookup table.
%    Define a table of [Velocity (m/s), Drag Coefficient (Cd)] pairs.
%    The program will interpolate between these points.
%    Example data is provided below. You should replace it with your
%    motor's known or estimated Cd values for different velocities.
drag_data_table = [
    0.0 * 343, 0.6;
    0.1 * 343, 0.55;
    0.2 * 343, 0.46;
    0.3 * 343, 0.42;
    0.4 * 343, 0.4;
    0.5 * 343, 0.36;
    0.6 * 343, 0.354;
    0.7 * 343, 0.361;
    0.8 * 343, 0.365;
    0.9 * 343, 0.37;
    0.97 * 343, 0.42;
    0.993 * 343, 0.47;
    1.0 * 343, 0.5;
    1.02 * 343, 0.59
    1.1 * 343, 0.57;
    1.2 * 343, 0.55;
    1.3 * 343, 0.52;
    1.4 * 343, 0.5;
    1.5 * 343, 0.48;
    1.6 * 343, 0.44;
    1.7 * 343, 0.44;
    1.8 * 343, 0.44;
    1.9 * 343, 0.44;
];

% 5. Motor burn time.
%    Enter the duration of the motor burn in seconds. This is a more
%    reliable way to define the burn period than relying on acceleration
%    alone, as drag can exceed thrust.
motor_burn_time_s = 9.3;


% =========================================================================
% PROGRAM EXECUTION - DO NOT EDIT BELOW THIS LINE
% =========================================================================

% Physical constants
g = -9.84; % Acceleration due to gravity (m/s^2)

try
    % Read the telemetry data from the CSV file.
    data = readtable(filename);
    
    % Check if the required columns exist.
    if ~all(ismember(column_headers, data.Properties.VariableNames))
        error('One or more of the specified column headers were not found in the CSV file.');
    end
    
    % Extract the required data columns.
    raw_time = data.(column_headers{1});
    altitude = data.(column_headers{2});
    velocity = data.(column_headers{3});
    acceleration = data.(column_headers{4});
    pressure = data.(column_headers{5});
    
    % Find the motor burn period based on the user-defined burn time.
    % We assume the burn starts at the first significant acceleration spike.
    burn_start_index = find(acceleration > 15, 1, 'first');
    time_burn_start = raw_time(burn_start_index);
    time = raw_time - time_burn_start;
    
    if isempty(burn_start_index)
        error('Could not determine the motor burn start from the acceleration data. Check your acceleration values or adjust the threshold.');
    end
    
    % Find the index corresponding to the user-defined burn time.
    burn_end_index = find(time >= time(burn_start_index) + motor_burn_time_s, 1, 'first');
    
    if isempty(burn_end_index)
        error('The specified motor burn time exceeds the duration of the telemetry data. Please check your input.');
    end
    
    burn_indices = burn_start_index:burn_end_index;
    time_burn = time(burn_indices);
    
    % =====================================================================
    % 1. MODELING ROCKET MASS
    % =====================================================================
    % Assumption: The mass decreases linearly from the initial mass to the
    % final mass over the motor's burn time.
    
    burn_time_total = time_burn(end) - time_burn(1);
    mass_lost = initial_mass_kg - final_mass_kg;
    mass_rate_kg_s = mass_lost / burn_time_total;
    
    current_mass = initial_mass_kg - (time_burn - time_burn(1)) * mass_rate_kg_s;
    
    % =====================================================================
    % 2. MODELING DRAG FORCE
    % =====================================================================
    rho = pressure(burn_indices) / (287.058 * 310.15);

    A = pi * (rocket_diameter_m / 2)^2;
    
    % 'pchip' is used for a smooth, monotonic interpolation. 'linear' is another option.
    cd_interpolated = interp1(drag_data_table(:, 1), drag_data_table(:, 2), velocity(burn_indices), 'pchip', 'extrap');
    

    drag_force = 0.5 * rho .* (velocity(burn_indices)).^2 * A .* cd_interpolated;
    figure;
    plot(time_burn, drag_force);
    
    % =====================================================================
    % 3. BACK-CALCULATING THRUST
    % =====================================================================
    % The net force ($F_{net}$) is what the telemetry measures ($m \cdot a$).
    % $F_{net} = T - F_{drag} - F_{gravity}$
    % Therefore, $T = F_{net} + F_{drag} + F_{gravity}$
    
    net_force = current_mass .* acceleration(burn_indices);
    gravity_force = current_mass * g;
    
    thrust = net_force + drag_force + gravity_force;
    
    % =====================================================================
    % 4. PLOTTING THE THRUST CURVE
    % =====================================================================
    
    figure; % Create a new figure window for the plot.
    plot(time_burn, thrust, 'LineWidth', 4);
    
    title('Back-Calculated Motor Thrust Curve');
    xlabel('Time (s)');
    ylabel('Thrust (N)');
    grid on;

    % =====================================================================
    % 5. CALCULATING MOTOR IMPULSE
    % =====================================================================
    % Impulse is the integral of Thrust over time. We can approximate this
    % using numerical integration (the trapezoidal rule).
    % The units will be Newton-seconds (N-s).
    
    impulse = trapz(time_burn, thrust);
    
    fprintf('\nTotal Motor Impulse: %.2f N-s\n', impulse);


    % =====================================================================
    % 6. EXPORTING TO .ENG FILE
    % =====================================================================
    % This section exports the time and thrust data in a format compatible
    % with common rocket simulation software (.eng format).
    
    output_filename = 'irecBackCalculated2.eng';
    
    % Open the file for writing.
    fid = fopen(output_filename, 'w');
    if fid == -1
        error('Could not open file for writing: %s', output_filename);
    end
    
    % Write the header information.
    % Note: Motor length is not available from telemetry, so we use a placeholder.
    motor_name = 'IREC25_Calculated';
    motor_manufacturer = 'MATLAB-WVUER';
    
    % Convert units for the header.
    diameter_mm = 152;
    initial_mass_g = initial_mass_kg * 1000;
    propellant_mass_g = (initial_mass_kg - final_mass_kg) * 1000;
    avg_thrust_N = impulse / burn_time_total;
    motor_length_mm = 1067;
    
    fprintf(fid, 'O3500-Y64-S25a-Calculated 152 1067 0 16.939 30.702 WVUER2025-MATLAB\n');

    
    % Write the time and thrust data points.
    for i = 1:length(time_burn)
        fprintf(fid, '%.4f %.4f\n', time_burn(i) - time_burn(1), thrust(i));
    end
    
    % Close the file.
    fclose(fid);
    
    fprintf('Data successfully exported to %s\n', output_filename);
    
catch ME
    % Display any errors that occurred.
    fprintf('An error occurred:\n');
    fprintf('%s\n', ME.message);
    fprintf('Please ensure your CSV file is correctly formatted and the user inputs are accurate.\n');
end