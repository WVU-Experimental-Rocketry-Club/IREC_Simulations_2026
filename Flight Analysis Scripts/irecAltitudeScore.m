targetApo = 30000;
baroApo = linspace(21000, 39000, 1000);
gpsApo = baroApo + 1200;


pointsLost = ( 350 / (0.3 * targetApo) ) * (abs(targetApo - baroApo));

points = 350 - pointsLost;

figure;
plot(baroApo, points);
hold on;
plot(gpsApo, points);
xlabel('Actual Apogee (ft)');
ylabel('Altitude Score');
title('Points vs Actual Apogee');
legend("Barometric Altitude", "GPS Altitude");
xaxis([20000, 40000])
grid on;

