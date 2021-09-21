function [bpm] = ExtractBPM(emg, b, Fs, filterTrace)
%EXTRACTBPM This function allows to extract the heart rate from the EMG.
%The output is a 10 Hz signal of BPM, that can be smoothed or nor if the
%filterTrace argument is set to 1. Be ready, this takes time.
% Romain Cardis 2020

% Extract the heart rate at 10 Hz with NaN when it's not possible

if nargin==3
    filterTrace=0;
end
if Fs == 1000
    emg = decimate(emg,5,'fir');
end

[a,be] = cheby2(6,40,25/100,'high');
emg = filtfilt(a,be,emg);
hr = abs([0,diff(emg)]).^2;

% Take the values of emg in NREMS to normalize it (zscore)
nr = strfind(b,'nnn');
epnr = epochToPoints(nr,4,200);
nrMean = mean(hr(epnr(:)));
nrStd = std(hr(epnr(:)));
hr = (hr-nrMean)./nrStd;

% go through each epoch and verify that the heartbeats are nice. if not,
% remove the points

% for i = 1:length(b)
%     curemg = hr(epochToPoints(i,4,200));
%     plot(curemg)
%     delete(gca)
% end

% get the peaks
[peak,ploc] = findpeaks(hr,200,'MinPeakDistance', 0.08, 'MinPeakHeight',.3); % HEAVY load but it actually works

% Remove the peaks too high, likely the one in wake
toHigh = peak>10;
peak(toHigh) = [];
ploc(toHigh) = [];

% Look at the time in between peaks (in seconds) and remove the one that
% make no sense (too long in between with bpm below 300)

bpm = 1./diff(ploc)*60;
toLow = bpm<300;
ploc = ploc(2:end);
ploc(toLow) = [];
bpm(toLow) = [];
peak = peak(2:end);
peak(toLow) = [];

% remove the points where it jumps from one value to another in an no
% phisiological manner (with difference > 200 bpm)
dbpm = [0,abs(diff(bpm))];
jum = dbpm>200;
bpm(jum) = NaN;
bpm = interpNan(bpm);

% Get the BPM at same 10 Hz sampling rate as the sigma
x10 = linspace(0,length(emg)/200,length(emg)/20);
bpm = interp1(ploc,bpm,x10);
bpm = interpNan(bpm);
if filterTrace == 1
    bhi = fir1(100, 0.025/10,'low');
    bpm = filtfilt(bhi,1,bpm);
end

end

