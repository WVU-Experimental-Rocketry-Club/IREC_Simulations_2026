P_TX = 14; %tx power. 25mW = 14, 100mw = 20, 400mw=26, 500mw = 27, 1w = 30 dBm, 2w = 33 dBm
TX_efficiency = 0.95;
G_TX = 2.8; %tx gain (9.3 dbi triple feed, hpbw 55 deg 6.3 dbi)
G_RX = 2.8; % rx gain (5.8 dbi mx air, 11 dbi maple, 
S_RX = -90; %sensitivity dBm

f_MHz = 5800; % freq mhz
LM = 3; %link margin


RF_HW = (P_TX * TX_efficiency) + G_TX + G_RX - S_RX;

R_km = 10 ^ ( ( RF_HW - LM - 32.44 - 20*log10(f_MHz) ) / 20 );

apogee = 10; %km
PATH_LOSS = 32.44 + 20*log10(f_MHz) + 20*log10(apogee) - G_TX - G_RX
RSSI = RF_HW - LM - PATH_LOSS

R_ft = R_km * 3280.84;
fprintf("\nRange (km): %.2f\n", R_km);
fprintf("\nRange (ft): %.2f\n", R_ft);
fprintf("\nRange (mi): %.2f\n\n", R_ft / 5280);

 