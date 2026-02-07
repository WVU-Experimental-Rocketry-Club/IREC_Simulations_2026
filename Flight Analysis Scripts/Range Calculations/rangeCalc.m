P_TX = 27; %tx power. 100mw = 20, 400mw=26, 500mw = 27, 1w = 30 dBm, 2w = 33 dBm
TX_efficiency = 0.95;
G_TX = 2.5; %tx gain (9.3 dbi triple feed, hpbw 55 deg 6.3 dbi)
G_RX = 8; % rx gain (5.8 dbi mx air, 11 dbi maple, 
S_RX = -95; %sensitivity dBm

f_MHz = 5800; % freq mhz
LM = 3; %link margin


RF_HW = (P_TX + 10*log10(TX_efficiency)) + G_TX + G_RX - S_RX;

R_km = 10 ^ ( ( RF_HW - LM - 32.44 - 20*log10(f_MHz) ) / 20 );

R_ft = R_km * 3280.84;
fprintf("\nRange (km): %.2f\n", R_km);
fprintf("\nRange (ft): %.2f\n", R_ft);
fprintf("\nRange (mi): %.2f\n\n", R_ft / 5280);