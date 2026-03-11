mw_tx = 25;
dbm_tx = 10 * log10(mw_tx);
P_TX = dbm_tx; %tx power. 100mw = 20, 400mw=26, 500mw = 27, 1w = 30 dBm, 2w = 33 dBm
TX_efficiency = 0.95;
G_TX = 2.8; %tx gain (9.3 dbi triple feed, hpbw 55 deg 6.3 dbi)
G_RX = 2.8; % rx gain (5.8 dbi mx air, 11 dbi maple, 
S_RX = -90; %sensitivity dBm

f_MHz = 5800; % freq mhz
lambda = 3e8 / (f_MHz * 10^6);
alpha = 2; %free space exponent, 2 is perfect, 3-4 for urban & indoor

LM = 3; %link margin


r_m_log = ( (S_RX + LM) - (P_TX + 10*log10(TX_efficiency)) + (20 * log10( (4*pi) / lambda) - G_TX - G_RX) ) / (-10 * alpha);
r_m = 10 ^ r_m_log;

R_km = r_m / 1000; % Convert the calculated range from meters to kilometers

R_ft = R_km * 3280.84;
fprintf("\nRange (km): %.2f\n", R_km);
fprintf("\nRange (ft): %.2f\n", R_ft);
fprintf("\nRange (mi): %.2f\n\n", R_ft / 5280);