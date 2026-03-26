% calculator to figure out what pressure you need to hit in order to have the
% altimeter read your desired altitude agl
launchSiteMSL_baro = 365.76; % meters MSL that the baro will read at launchpad. 864m baro s.sunrise, 894 gps
desiredAGL = 9144; % 9144m = 30,000 ft
desiredHeight = desiredAGL + launchSiteMSL_baro;

P = 24909; % 25000 s.sunrise apogee

P0 = 101325; %standad pressure at sea level
t0 = 288.15; %standard temp kelvin at sea level, 15C = 288.15K
L = 0.0065; %temp lapse rate in kelvin/meter

R = 8.31432; % gas constant Mol*K
M = 0.0289644; % molar mass of atmosphere, kg/mol
g = 9.80665; % standard gravity acceleration

exponent =  (g * M)/(R * L); % constant value

neededApoPressure = P0 * (1 - ( (L * desiredHeight) / t0) ) ^ exponent;

fprintf('Pressure for 30k AGL: %.2f Pa\n', neededApoPressure);
fprintf('Pressure for 30k AGL: %.2f hPa\n', neededApoPressure / 100);


launchSiteMSL_gps = 894;
neededGPSalt = 10481; %10481
fprintf('Simulation apogee needed to read 30k AGL baro: %.2f ft\n', (neededGPSalt - launchSiteMSL_gps) * 3.281);