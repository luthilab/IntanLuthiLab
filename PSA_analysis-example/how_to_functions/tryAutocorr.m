function tryAutocorr

close all % close all open figures

fs = 100; % sampling rate at 100               
v_time = 0:1/fs:175; % duration of the bout and each points (175 sec)
signal = sin((2*pi.*v_time)/50); % signal generation
x = linspace(0,length(signal)/100,length(signal)); % X axis corresponding to the signal... same as v_time actually...

a = 0:0.0001:0.1; % values of a

rat = zeros(length(a),2); % allocation of variable rat for ratio. Will contain in column 1 (:,1) the first trough peak difference and in column 2 (:,2) the second.
lo = zeros(length(a),2); % will contain the x location of the first peak in (:,1) and of the second peak in (:,2)

figure

for i = 1:length(a)
    % modify the signal according to a
    bup = (1+a(i).*v_time); % bup is build up
    sig = signal.*bup; % signal is multipied of added to bup (change here * or +)
    
    [acf,lags] = autocorr(sig,length(sig)-1); % autocorrelation in matlab

    [pk,locp] = findpeaks(acf,'MinPeakProminence',.01, 'minpeakdistance', 300); % detection of the peaks. pk = peak values and locp = location in x of the peaks
    [tr,~] = findpeaks(-acf,'MinPeakProminence',.01, 'minpeakdistance', 300); % same for the trough detected in the inverted signal
    
    tr = -tr; % get the real values for troughs
    rat(i,:) = [pk(1)-tr(1),pk(2)-tr(2)]; % store the trough-peak difference in the rat variable
    lo(i,:) = [locp(1),locp(2)]/100; % store the peak location in lo
    
    %% Here choose 3 values of a when you want to plot the signal and autocorrelation
    
    p1 = 0;
    p2 = 0.025;
    p3 = 0.1;    
    
    %%
    
    if a(i) == p1
        subplot(4,2,1)
        plot(x,sig)
        title(['a = ',num2str(p1)])
        %ylim([-1,4]) % modify the ylim here if you want all the plot with the same ylim
        subplot(4,2,2)
        plot(lags./100,acf)
       
    elseif a(i) == p2
        subplot(4,2,3)
        plot(x,sig)
        title(['a = ',num2str(p2)])
        %ylim([-1,4]) % modify the ylim here if you want all the plot with the same ylim
        subplot(4,2,4)
        plot(lags./100,acf)
    
    elseif a(i) == p3
        subplot(4,2,5)
        plot(x,sig)
        title(['a = ',num2str(p3)])
        %ylim([-1,4]) % modify the ylim here if you want all the plot with the same ylim
        subplot(4,2,6)
        plot(lags./100,acf)
        
    end
end

%% final plot of peak-trough diff against values of a
subplot(4,2,7:8)
plot(a,rat(:,1))
xlabel('a')
ylabel('first trough-peak difference')
title('(1 + ax) * sin(2*pi*x)/50)') % modify the title acording to the function used

end


