function [res] = f_HeartRate_nrem(b,t)
%% To extract heart rate in bpm from NREMS + newstate bouts

% [b,t] = cut_Traces(b,traces,5,Infos);

fs = 1000; %1000 Hz INTAN system
index_t = epochToPoints(1:length(b), 4, fs);
% eeg = t(1,index_t(:));
%emg = t(2,index_t(:)); % AL: for a test, I directly calculated the EMG
%from the traces

emg = t %added by Anita

%filter to remove everything above 90Hz
[fa,fb] = cheby2(5, 40, 90/500,'high'); %5:filter order , 40:attenuation factor, 90Hz/(Fs/2)
emg = filtfilt(fa,fb, emg);

%% Extraction heart rate in NREMS epoch
%b_nrem = strfind(b,'nnn')+1 ;  
%NREMS + New state 
b_nf = [];
start = 1;
while true
    matchIndex = regexp(b(start:end), '[nf]{3}', 'once');
    if isempty(matchIndex)
        break;
    end
    b_nf = [b_nf, start + matchIndex - 1+1]; %add +1 to have index of the middle 
    start = start + matchIndex;
end
b_allnrem = b_nf;
heart = zeros(2,length(b_allnrem)); %will contain bpm per epoch of NREMS 
k=1;
for i = b_allnrem
    index_epoch = epochToPoints(i, 4, fs);
    emg_epoch = emg(index_epoch(:));
    [up,down] = envelope(emg_epoch,3,'peak'); %3: filter length
    env = up+abs(down);
    sd_env = std(env);
    [pks, locs] = findpeaks(env,linspace(0,4,4*fs),'MinPeakProminence',3*sd_env,'MinPeakDistance',0.06);
    med_diff_locs = median(diff(locs));
    %MinPeakProminence = to have findpeaks return only those peaks that have a relative importance of at least sd
    %MinPeakDistance = ignoring peaks that are very close to each other      
    
    % plot(emg_epoch)
    % hold on
    % plot(env)
    % findpeaks(env,'MinPeakProminence',3*sd_env,'MinPeakDistance',0.06*fs)

    %range()>... to remove amplitude max = to discard epoch where big diff
    %length(locs)<... to discard where they don't detect enough heart beats
    if (length(locs)<12) || (range(pks) > 1.5e-4) || (max(diff(locs))>med_diff_locs*2.5) || (locs(1)>1)
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

    %title([num2str(bpm),'  ',num2str(range(pks)),'  ',num2str(length(locs))],YESORNO)  
    %hold off
           
end

res = heart;

%% PLOT
% figure('color','w');
% h=5;
% %HYPNOGRAM
% pos1 = [0.1 0.85 0.8 0.1];
% subplot('Position',pos1)
% hyp = bToHyp(b);
% hyp( :, ~any(hyp,1) ) = 3.1;
% plot(hyp)
% ylim([0.5,3.5])
% yticklabels({'REMS','NREMS','WAKE'})
% xlim([0,length(hyp)])
% set(gca, 'XColor','None', 'YColor','None')
% tickout
% 
% %Heart rate bpm every epoqu (4s) of NREMS triplet
% pos2 = [0.1,0.5,0.8,0.3];
% subplot('position',pos2)
% x = res(2,:); %time in hour
% y = res(1,:); %value in bpm
% plot(x,y,'k')
% xlabel('Time after i.p. injection (h)')
% ylabel('heart rate in nrems (bpm)')
% ylim([200,700])
% xlim([0,5])
% tickout
% 
% %BIN (mean) every .. min from injection point
% pos3 = [0.1,0.1,0.8,0.3];
% subplot('position',pos3)
% per = 1; %bin every 30min
% res_bin = zeros(1,h/per);
% q=1;
% for i = 0:per:h-per
%     pos_bin = find(res(2,:)>= i & res(2,:)<(i+per)); %index of heart values [i,i+per]
%     res_bin(q) = nanmean(res(1,pos_bin)); %mean of heart rate values every 30min (number of points changes)
%     q = q+1;
% end
% x_bin = 0+per:per:h;
% plot(x_bin,res_bin)
% tick_x = linspace(0.5,h+0.5,h+1);
% xticks(tick_x)
% lab_x = linspace(0,h,h+1);
% xticklabels({lab_x})
% xlim([0.5,h+0.5])
% ylim([200,700])
% xlabel('Time after i.p. injection (h)')
% ylabel('heart rate mean (bpm)')
% tickout

end