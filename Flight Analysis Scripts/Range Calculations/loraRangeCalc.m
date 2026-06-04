% Link budget parameters
mw_tx = 100;
P_TX = 10 * log10(mw_tx);   % dBm
TX_efficiency = 0.95;         % PA efficiency derate
G_TX = 0;                     % dBi, TX antenna
G_RX = 2.1;                   % dBi, RX antenna
S_RX = -124;                  % dBm, receiver sensitivity
LM   = 10;                    % dB, required link margin above sensitivity

f_MHz  = 433;
lambda = 3e8 / (f_MHz * 1e6); % meters
alpha  = 2.1;                  % path loss exponent (2.0 = free space)

% Effective TX power
EIRP = P_TX + 10*log10(TX_efficiency) + G_TX;

% Required received power
P_RX_min = S_RX + LM;

% Path loss budget available
PL_budget = EIRP + G_RX - P_RX_min;

% Solve for range using: PL = 10*alpha*log10(4*pi*r/lambda)
% => r = (lambda / 4*pi) * 10^(PL_budget / (10*alpha))
r_m = (lambda / (4*pi)) * 10^(PL_budget / (10 * alpha));

R_km = r_m / 1000;
fprintf("\nRange (km): %.2f\n",       R_km);
fprintf("Range (ft): %.0f\n",         R_km * 3280.84);
fprintf("Range (mi): %.2f\n\n",       R_km * 3280.84 / 5280);