fs = 1000;    % Sampling rate
figure

for i = 1:3
    
    v_time = 0:1/fs:i;    % Vector time for sinusoidal wave (1 seconds)
%     d = cos(2*pi*60*v_time)+0.5*cos(2*pi*120*v_time);
    d = 10*cos(2*pi*10*v_time);
    subplot(3,2,((i-1)*2)+1)
    plot(v_time, d)
    
    Hz = linspace(0, 1, ((1000*i)/2)+1)*500;
    lafft = abs(fft(d-mean(d)));
    lafft = lafft(1:length(Hz)); % take only half the fft because we don't need the mirror image
    lafft = lafft./((fs*i)/2); % first normalization by the sampling rate * time in second (1000points*1sec) divided by 2
    lafft = lafft.^2; % then PSD
   
    subplot(3,2,((i-1)*2)+2)
    
    plot(Hz,lafft)   
    xlim([0,30])
end

