dP = 23; % ejection pressure psi
R = 22.16 * 12; % combustion gas const, x12 convert ft to in
T = 3307; % combustion gas temp R

length = 24; % inches of tube length
dia = 6; % inches tube diameter

bulkheadSurfaceArea = pi * ((dia / 2) ^ 2);
poundForceOnBulkhead = bulkheadSurfaceArea * dP

vol = pi * (dia / 2)^2 * length; % tube volume

chargeLbs = dP * (vol / (R * T)); % bp mass lbs
chargeG = chargeLbs * 454 % convert lbs to g