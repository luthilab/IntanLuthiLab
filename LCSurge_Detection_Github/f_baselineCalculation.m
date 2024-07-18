function [fitbas,baseline] = f_baselineCalculation(signal,window,b,fs)
% This function is computing the baseline of a calcium singal using the
% 5th percentile method of the 1Hz lowpass signal and then using the b file
% it fits a line only using the bouts of NREM and REM but expluding the
% wake bouts

% Inputs:
% signal : input calcium signal
% window: window around every point that is used to compute the percentile
% in points (usually 2000 points)
% fs: sampling frequency

% Outputs:
% baseline: the computed baseline
% fitbas : the fitting line using only the NREM and REM bouts of the singal


% filter the singal at 1Hz to remove calcium activity

% design the low-pass filter
lpFilt = designfilt('lowpassiir','FilterOrder',8, 'PassbandFrequency',1,...
        'PassbandRipple',0.01, 'SampleRate',fs);

%filter the singal using the filter
filtsig = filtfilt(lpFilt,double(signal));

% initialise the baseline signal 
baseline = zeros(1,length(filtsig));

% look at the defined window around every-time point and compute the 5th
% percentile of the 1Hz lowpass signal

 for i_timepoint=1:length(filtsig)

     windowSignal = filtsig(max(1,(i_timepoint-window*fs)):min(length(filtsig),(i_timepoint+window*fs)-1));
     baseline(i_timepoint) = prctile(windowSignal,5);

     if mod(i_timepoint,1000) == 0

         %disp(['Calculation at: ', num2str(i_timepoint)])
     end
     
 end


% find the times of b that we have NREM and REM bouts 
TimesOfb = linspace(0,(size(b,2)-1)*4,size(b,2));
exp = 'n+[^w]*';
[startIndexNREMR,endIndexNREMR] = regexp(b,exp) ;

points = [];
baselineAprox = [];


% keep the part of the signal with NREM and REM bouts and the points in
% time that we have Wake bouts at the same time (we keep the points where
% each value corresponds to use it later for sorting)

interpIntervals = 0;

for i=1:length(startIndexNREMR)

    StartIndexToKeep = TimesOfb(startIndexNREMR(i));
    EndIndexToKeep =  TimesOfb(endIndexNREMR(i))+ 4;

    % keep the baseline signal when NREM/REM bout is present
    NREMRBaselineSignal{i}.signal = baseline((StartIndexToKeep*fs+1):(EndIndexToKeep*fs));
    NREMRBaselineSignal{i}.points = (StartIndexToKeep*fs+1):1:(EndIndexToKeep*fs);
    
    points = [points, NREMRBaselineSignal{i}.points];
    baselineAprox = [baselineAprox, NREMRBaselineSignal{i}.signal];

   % when it starts with wake bout before a NREM/REM bout
    if i == 1
        interpIntervals = interpIntervals + 1;
        NREMRBaselineInterTime{interpIntervals}.startPoint = nan ;
        NREMRBaselineInterTime{interpIntervals}.endPoint = TimesOfb(startIndexNREMR(i));
       % disp(NREMRBaselineInterTime{interpIntervals})
        continue;
    end

    % when NREM/REM bout is between to wake bouts
    interpIntervals = interpIntervals + 1;
    NREMRBaselineInterTime{interpIntervals}.startPoint = TimesOfb(endIndexNREMR(i-1)) + 4;
    NREMRBaselineInterTime{interpIntervals}.endPoint = TimesOfb(startIndexNREMR(i));

     %disp(NREMRBaselineInterTime{interpIntervals})

    % when it finished with wake bouts after a NREM/REM bout
    if i == length(startIndexNREMR)
        interpIntervals = interpIntervals + 1;
        NREMRBaselineInterTime{interpIntervals}.startPoint = (TimesOfb(endIndexNREMR(i))) + 4;
        NREMRBaselineInterTime{interpIntervals}.endPoint = nan;
       % disp(NREMRBaselineInterTime{interpIntervals})
    end


end

%fill the points of wake with nan's (we again keep the points to use it for
%sorting)

for s=1:size(NREMRBaselineInterTime,2)

    % for first NREM/REM bout  
    if isnan(NREMRBaselineInterTime{s}.startPoint)

        InterLines{s}.signal = ones(1,NREMRBaselineInterTime{s}.endPoint*fs) *nan;
        InterLines{s}.points = 1:1:NREMRBaselineInterTime{s}.endPoint*fs;

        points = [points,  InterLines{s}.points];
        baselineAprox = [baselineAprox, InterLines{s}.signal];

    % for last NREM/REM bout 
    elseif isnan(NREMRBaselineInterTime{s}.endPoint)

        InterLines{s}.signal = ones(1,max(0,size(baseline,2)-NREMRBaselineInterTime{s}.startPoint*fs))*nan;
        InterLines{s}.points = (NREMRBaselineInterTime{s}.startPoint*fs + 1):1:size(baseline,2);

        points = [points,  InterLines{s}.points];
        baselineAprox = [baselineAprox, InterLines{s}.signal];
    else
        % for the NREM/REM bouts in between
        numberOfPoints =  (NREMRBaselineInterTime{s}.endPoint - NREMRBaselineInterTime{s}.startPoint)*fs + 2;

        Temp.signal =ones(1,numberOfPoints)*nan;
        Temp.points = (NREMRBaselineInterTime{s}.startPoint*fs):1:(NREMRBaselineInterTime{s}.endPoint*fs+1);

        InterLines{s}.signal = Temp.signal(2:(end-1));
        InterLines{s}.points = Temp.points(2:(end-1));

        points = [points,  InterLines{s}.points];
        baselineAprox = [baselineAprox, InterLines{s}.signal];
    end

end

% put the baseline values and the points in one matrix 
baselineAndPoints = [baselineAprox',points'];

% sort according to the points
baselineSorted = sortrows(baselineAndPoints,2);

% keep only the values
baselineFinal = baselineSorted(:,1);

% fit only the nan values of the signals with a second degree polynomial 
len = (1:1:size(baselineFinal,1))';
idx = isnan(baselineFinal);
[cof,S,mu] = polyfit(len(~idx),baselineFinal(~idx),2);

% calculate the same fit function for the whole time of the recordings 
lenBasOr = 1:1:size(baseline,2);
fitbas = polyval(cof,(lenBasOr-mu(1))./mu(2));

end