% tryCrossCorr is an example on how to use the cross correlation function
% of matlab on two sinusoidal generated at 0.02 Hz.
% Romain Cardis 2019

close all
%clear all

%% generate signals

fs = 10;  % Sampling rate at 10 Hz

% Vector time for sinusoidal wave (100 seconds)
v_time = 0:1/fs:100; 

% Vector time for sinusoidal wave (100 seconds shifted by 25 sec) you can
% change the value of the shift to play with the cross corr result.
% Try with 10, 25, 40
shift = 40;
time2 = shift:1/fs:shift+100; 

% Create sinusoidal waves (0.02 Hz)
a = 2*sin(0.02*2*pi*v_time); 
b = sin(0.02*2*pi*time2);                       

% plot the signals
figure
subplot(1,3,1)
plot(v_time, a)
hold on
plot(v_time, b)
title('Original signals')
xlabel('Time (s)')
ylabel('Amplitude')
box off
set(gca,'tickdir','out')
legend('signal A','signal B')

%% amplitude normalisation of the signals

% Recentre signal around zero
an = a - mean(a);
bn = b - mean(b);

% Normalize amplitude by dividing by SD
an = an./std(an);
bn = bn./std(bn);

% Normalize by length of signals
bn = bn./(length(bn)-1);
an = an./(length(an)-1);

% Plot normalized signals
subplot(1,3,2)
plot(v_time, an)
hold on
plot(v_time, bn)
title('Normalized signals')
xlabel('Time (s)')
ylabel('Amplitude normalized')
box off
set(gca,'tickdir','out')

%% actual cross-correlation

% xcorr matlab function. Here the signal B slides on the A.
[acor,lag] = xcorr(an,bn);

% Correct correlation values to have them between -1 to 1
acor = acor*(length(an)-1);

% Correct lag with the sampling rate
lag = lag./fs;

% Plot the cross-correlation
subplot(1,3,3)
plot(lag,acor)
xlabel('Time lag (s)')
ylabel('Correlation (R)')
box off
set(gca,'tickdir','out')

%% Supplement with location of lag between the two signal
[~,loc] = max(abs(acor));
maxCorr = acor(loc);
signalLag = lag(loc);

% give title to plot with the result
title(['Cross-Correlation R = ', num2str(maxCorr),' lag of ', num2str(signalLag), ' sec'])

% Give infos in console
if maxCorr > 0
    disp('The two signal are positively correlated')
else
    disp('The two signal are negatively correlated')
end

if signalLag > 0
    disp(['With the signal B showing ', num2str(signalLag),' seconds of delay on the signal A'])
else
    disp(['With the signal B showing ', num2str(abs(signalLag)),' seconds of advance on the signal A'])
end
