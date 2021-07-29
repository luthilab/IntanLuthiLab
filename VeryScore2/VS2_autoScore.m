function [ b ] = VS2_autoScore( eeg,emg, b )
%The autoScoring part. (exactly the same as VeryScore1, just adapted a bit.

w = waitbar(0, 'Much ongoing scoring');

%% ask what kind of arousal detection is best fitted

respo = questdlg('What kind of arousal detection is fitted for these traces ?',...
    'what should I use?',...
    'EMG based',...
    'EEG based','Both','EMG based');

%% get the interesting part of the file structure.

s = struct();
s.eeg = eeg;
s.emg = emg;

%% calculate the median (or mean) value for each epoch and already mark artifacts as '1'

s.eegMeans = zeros(1,length(b));
s.emgMeans = zeros(1,length(b));
s.eegVar = zeros(1,length(b));
j = 1;

for i = 1:800:length(eeg)-800
    if max(abs(s.eeg(i:i+799))) > 1/1000
        if i == 1
            b([j,j+1]) = '11';
        elseif i == max(1:800:length(b)*800)
            b([j-1,j]) = '11';
        else
            b([j-1,j,j+1]) = '111';
        end
    else
        if i ~= 1 && i ~= length(eeg)-800 && i+1599 < length(eeg)     
            [up, down] = envelope(s.eeg(i-800:i+1599), 80, 'peak');
            if std(up(800:1599))^2 > std(down(800:1599))^2
                s.eegVar(j) = std(up(800:1599))^2;
            else
                s.eegVar(j) = std(down(800:1599))^2;
            end
            s.eegMeans(j) = sum(abs(up(800:1599)-down(800:1599)));
            if max(abs(s.emg(i:i+799))) < 0.7
                %[up, down] = envelope(s.emg(i-800:i+1599), 15, 'rms');
                %s.emgMeans(j) = mean(abs(up(800:1599)-down(800:1599)));
                s.emgMeans(j) = median(abs(s.emg(i:i+799)));
            end
        end
    end
    j=j+1;
    waitbar(i/length(eeg), w)
end


%% Calculate the mean value for the whole EEG and EMG (without the artifact)

s.grandMeanEeg = mean(s.eegMeans(s.eegMeans~=0));
s.grandMeanEmg = median(s.emgMeans(s.eegMeans~=0));


%% assign evident n and w

b(s.eegMeans > s.grandMeanEeg & s.emgMeans < s.grandMeanEmg & b ~= '1') = 'n';
b(s.eegMeans < s.grandMeanEeg & s.emgMeans > s.grandMeanEmg & b ~= '1') = 'w';

nMean = [mean(s.eegMeans(b=='n')), mean(s.emgMeans(b=='n'))]; % means of the easily assigned NREM epochs
wMean = [mean(s.eegMeans(b=='w')), mean(s.emgMeans(b=='w'))]; % means of the easily assigned wake epochs


%% assign remaining b based on epoch before and closest means

bLoc = strfind(b,'b');
bLoc(bLoc == 1) = []; % keep only the location of non assigned epoch for rapidity

for i = bLoc
    if strcmp(b(i-1), 'n') == 1 && s.eegMeans(i) > s.grandMeanEeg % Sometime, there's muscle twitch but it's still NREM
        b(i) = 'n';
    elseif strcmp(b(i-1), 'w') == 1 && s.eegMeans(i) < s.grandMeanEeg % quiet waking during wake mostly
        b(i) = 'w';
    elseif abs(s.eegMeans(i)-nMean(1)) < abs(s.eegMeans(i)-wMean(1)) && abs(s.emgMeans(i)-nMean(2)) < abs(s.emgMeans(i)-wMean(2)) % if none of the above, closest match to known means
        b(i) = 'n';
    else
        b(i) = 'w';
    end
end



%% clean a bit and add r and clean again and add r and clean again.

b(strfind(b,'wnw')+1) = 'w';
b(b=='w' & s.emgMeans < s.grandMeanEmg) = 'r';

%% detect arousal in r using EMG

for i = 1:length(b)
    if b(i) == 'r' && i ~= 1 && i ~=2
        [envcUp, envcDo] = envelope(abs(s.emg((i-1)*4*200:i*4*200)).^2);
        intc = sum(envcUp-envcDo);
        [envpUp, envpDo] = envelope(abs(s.emg((i-2)*4*200:(i-1)*4*200)).^2); % Calculate for the precedent epoch
        intp = sum(envpUp-envpDo);
        if (intc*100)/intp > 150 % 50% increase in integrated EMG might be arousal
            b(i) = 'w';
        end
    end
end


%% clean missplaced r

wr = b(strfind(b, 'wr'));
rn = b(strfind(b, 'rn'));

while isempty(wr) == 0 || isempty(rn) == 0
    b(strfind(b, 'wr')+1) = 'w';
    b(strfind(b, '1r')+1) = 'w';
    b(strfind(b, 'rn')) = 'n';
    wr = b(strfind(b, 'wr'));
    rn = b(strfind(b, 'rn'));
end

%% arousal detection

if strcmp(respo, 'EEG based') == 1 || strcmp(respo, 'Both') == 1
    for i = 1:length(b)
        if b(i) == 'n' && i ~= 1 && i ~=2
            be = s.eegMeans(i-1);
            ac = s.eegMeans(i);
            if ac < be*0.8 %decrease of 20 % in eeg might be arousal
                b(i) = 'b';
            end
        end
    end
end

if strcmp(respo, 'EMG based') == 1 || strcmp(respo, 'Both') == 1 % if emg based
    for i = 1:length(b)
        if b(i) == 'n' && i ~= 1 && i ~=2
            [envcUp, envcDo] = envelope(abs(s.emg((i-1)*4*200:i*4*200)).^2);
            intc = sum(envcUp-envcDo);
            [envpUp, envpDo] = envelope(abs(s.emg((i-2)*4*200:(i-1)*4*200)).^2); % Calculate for the precedent epoch
            intp = sum(envpUp-envpDo);
            if (intc*100)/intp > 150 % 50% increase in integrated EMG might be micro arousal
                b(i) = 'b';
            end
        end
    end
end

%% clean a bit

b(strfind(b,'nbr')+1) = 'r';

%% detect artifact using variance of the envelope

%stdVar = std(s.eegVar(b=='w'));
%meanVar = mean(s.eegVar(b=='w'));
an = questdlg('Do you want the advanced artifact detection? Use only for Intan files.','Yep! No so useful.','Yes','No','Yes');
switch an
    case 'Yes'
        b((b=='w') & s.eegVar > 0.007/1000) = '1'; % 0.007 seems a good threshold. Adjust here in case
end

%% Assign first and last b

b(1) = b(2);
b(end) = b(end-1);

close(w)

end

%% function to clean missplaced R which is not used

% function [b] = cleanR (b, s)
% for i = 1:length(b) % remove the missplaced 'r' after a 'w' or a '1'
%     if i ~= 1 && b(i) == 'r' && (b(i-1) == 'w' || b(i-1) == '1')
%         b(i) = 'w';
%     end
% end
% 
% b(strfind(b,'wnw')+1) = 'w';
% 
% b_rev = fliplr(b); % remove the missplaced 'r' before a 'n' (smart reverse vector, such deep thinking.)
% for i = 1:length(b_rev)
%     if i ~= 1
%         if b_rev(i) == 'r' && b_rev(i-1) == 'n'
%             b_rev(i) = 'n';
%         end
%     end
% end
% 
% b = fliplr(b_rev);
% 
% % final removal of missplaced r
% 
% res = 200; % we have 200 point per second
% ny = 100; % Nyquist limit is half the resolution
% 
% nr = 0;
% for i = 1:length(b)
%     if b(i) == 'r'
%         nr = nr +1;
%     elseif nr ~= 0 && b(i) ~= 'r'
%         t = linspace(0,1,((res*4*nr)/2)+1)*ny; % The Hz vector for the x axis
%         t(max(t)) = [];
%         FFT = abs(fft(s.eeg((i-1-nr)*4*200:(i-1)*4*200)));
%         FFT = FFT(1:length(t));
%         Max_freq = find(FFT==max(FFT));
%         if t(Max_freq(1)) > 5 && t(Max_freq) < 10
%             % let it be REM!
%             nr = 0;
%         else
%             b(i-1-nr:i-1) = repmat('b',1,length(i-1-nr:i-1));
%             nr = 0;
%         end
%     end
% end
% end