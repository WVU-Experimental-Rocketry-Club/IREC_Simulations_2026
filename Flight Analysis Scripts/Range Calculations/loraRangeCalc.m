mw_tx = 500; %transmit power milliwatts
dbm_tx = 10 * log10(mw_tx); %conversion to dBm

P_TX = dbm_tx; %tx power. 100mw = 20, 400mw=26, 500mw = 27, 1w = 30 dBm, 2w = 33 dBm
TX_efficiency = 0.95;

G_TX = 2.1; %tx gain (9.3 dbi triple feed, hpbw 55 deg 6.3 dbi)
G_RX = 2.1; % rx gain (5.8 dbi mx air, 11 dbi maple)

S_RX = -139; %sensitivity dBm (minimum usable RSSI value)

f_MHz = 915; % freq mhz
lambda = 3e8 / (f_MHz * 10^6);
alpha = 3; %free space exponent (2.0 for free space, upwards of 4 for poor environments)

LM = 10; %link margin


r_m_log = ( (S_RX + LM) - (P_TX + 10*log10(TX_efficiency)) + (20 * log10( (4*pi) / lambda) - G_TX - G_RX) ) / (-10 * alpha);
r_m = 10 ^ r_m_log;

R_km = r_m / 1000; % Convert the calculated range from meters to kilometers

R_ft = R_km * 3280.84;
fprintf("\nRange (km): %.2f\n", R_km);
fprintf("\nRange (ft): %.2f\n", R_ft);
fprintf("\nRange (mi): %.2f\n\n", R_ft / 5280);