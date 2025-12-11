function [res] = f_HeartRate_rem(b,t)
%% To extract heart rate in bpm from REMS bouts

% [b,t] = cut_Traces(b,traces,5,Infos);

fs = 1000; %1000 Hz INTAN system
index_t = epochToPoints(1:length(b), 4, fs);
% eeg = t(1,index_t(:));
emg = t(2,index_t(:));

%filter to remove everything above 90Hz
[fa,fb] = cheby2(5, 40, 90/500,'high'); %5:filter order , 40:attenuation factor, 90Hz/(Fs/2)
emg = filtfilt(fa,fb, emg);

%% Extraction heart rate in REMS epoch
eeg_rem = strfind(b,'rrr')+1 ; 
heart = zeros(2,length(eeg_rem)); %will contain bpm per epoch of NREMS 
k=1;
for i = eeg_rem
    index_epoch = epochToPoints(i, 4, fs);
    emg_epoch = emg(index_epoch(:));
    [up,down] = envelope(emg_epoch,3,'peak'); %3: filter length
    env = up+abs(down);
    sd = std(env);
    [pks, locs] = findpeaks(env,linspace(0,4,4*fs),'MinPeakProminence',3*sd,'MinPeakDistance',0.066);
    med_diff_locs = median(diff(locs));
    %MinPeakProminence = to have findpeaks return only those peaks that have a relative importance of at least sd
    %MinPeakDistance = ignoring peaks that are very close to each other      
    
    %range()>... to remove amplitude max = to discard epoch where big diff
    %length(locs)<... to discard where they don't detect enough heart beats
    if (length(locs)<12) || (range(pks) > 1e-4)  || (max(diff(locs))>med_diff_locs*2.5) || (locs(1)>1)
        bpm = NaN;
        heart(1,k) = bpm;
        heart(2,k) = i*4/3600; %position index of nrem
        YESORNO = 'NO';
    else
        di = diff(locs); %peaks positions (differences between adjacent elements of locs)
        bpm = 1/nanmean(di)*60; %to have battement par minute
        heart(1,k) = bpm;
        heart(2,k) = i*4/3600; %in hours
        YESORNO = 'YES';
    end
    
    k = k+1;

    % plot(emg_epoch)
    % hold on
    % plot(env)
    % findpeaks(env,'MinPeakProminence',3*sd,'MinPeakDistance',0.066*fs)
    % title([num2str(bpm),'  ',num2str(range(pks)),'  ',num2str(length(locs))],YESORNO)  
    % hold off
           
end

res = heart;

%% PLOT
% figure('color','w');
% %HYPNOGRAM
% pos1 = [0.1 0.85 0.8 0.1];
% subplot('Position',pos1)
% hyp = bToHyp(b);
% hyp( :, ~any(hyp,1) ) = 3.1;
% plot(hyp)
% ylim([0.5,3.5])
% yticklabels({'REMS','NREMS','WAKE'})
% xlim([0,length(hyp)])
% set(gca, 'XColor','None') %, 'YColor','None')
% tickout
% 
% %Heart rate bpm every epoqu (4s) of NREMS triplet
% pos2 = [0.1,0.5,0.8,0.3];
% subplot('position',pos2)
% x = res(2,:); %time in hour
% y = res(1,:); %value in bpm
% plot(x,y,'k*','MarkerSize',2)
% xlabel('Time after i.p. injection (h)')
% ylabel('heart rate in rems (bpm)')
% xlim([0,7])
% ylim([200,700])
% tickout
% 
% %BIN (mean) every .. min from injection point
% pos3 = [0.1,0.1,0.8,0.3];
% subplot('position',pos3)
% per = 0.1; %bin every 30min
% res_bin = zeros(1,h/per);
% q=1;
% for i = 0:per:h-per
%     pos_bin = find(res(2,:)>= i & res(2,:)<(i+per)); %index of heart values [i,i+per]
%     res_bin(q) = nanmean(res(1,pos_bin)); %mean of heart rate values every 30min (number of points changes)
%     q = q+1;
% end
% x_bin = 0+per:per:h;
% plot(x_bin,res_bin,'*')
% xlim([0,7])
% ylim([200,700])
% xlabel('Time after i.p. injection (h)')
% ylabel('heart rate mean (bpm)')
% tickout

end