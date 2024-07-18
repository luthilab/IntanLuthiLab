function st_Output = f_ActivitySourges(v_dff,v_EEG,v_EMG,v_strb)
    % This program finds the peaks in a dff vector of calcium activity
    % during NREM sleep to compare the brain activity dynamics In the
    % desired channel at MA vs noMA. It uses the filtered (under 0.5 Hz)
    % dff signal (dff).
    %
    % The first step consist in finding the LC peaks within the whole NREM
    % signal (See f_GetPeaks). 
    % 
    % LC surges are then defined from the maximum peaks during the NREM
    % sleep using a sliding window of 20 s. The surges x1.5 within a time
    % constant (See p_GetTau) following a wakefulness >60 s are excluded
    % for furhter analysis to include only those in consolidated NREMs.
    %
    % Then it sorts and means each surge in noMA and MA marked as with 1,
    % or more epochs in the b file (v_TypeOfMA in output structure).
    %
    % To further describe the LC surges between noMA and MA. We use a 100 s
    % window around the surge and defined the start of the surge as the 
    % moment with the earliest peak in the derivative signal that falls
    % within the 10 s before the peak and the end of it as the moment when
    % the LC activity reaches 15 % of the signal maximum signal within the
    % 100 s window.
    %
    % Inputs:
    %   v_dff: Calcium signal from the LC at 10 Hz. 
    %   v_EEG: EEG signal at 200 Hz for Delta, Sigma, and Gamma spectral
    %           dynamics.
    %   v_EMG: EMG signal for heart rate and muscle tone.
    %   v_strb: Hypnogram coding for sleep stages at 4 s windows using:
    %           w:REM; n: NREM sleep; r: REM sleep; 1: Art. in w; 2: Art.
    %           in n; 3: Art. in r; m: microarousal (Optional); f: Other.
    %
    % Output:
    %   st_Output: Structure containing,
    %       The position of all LC peaks during NREM sleep in v_LCPeaksPos.
    %       
    %       The type of Microarousal (v_TypeOfMA) for each detected 
    %       activity surge.
    % 
    %       The windows of activity 150 before and 50 after the LC activity
    %       suges. It contains the values for Gamma (m_Gamma), Sigma 
    %       (m_Sigma), and Delta (m_Delta) of EEG. The LC calcium activity 
    %       (m_dff), the heart rate (m_EKG) and muscle tone (m_EMG).
    %       
    %       The peak value of LC activity (v_LCPeaks) and heart reate 
    %       (v_Peak_EKG) over the last 10 seconds before the surge peak.
    %
    %       The mean activivity for gamma (v_Peak_Gamma), Sigma 
    %       (v_Peak_Sigma) and Delta (v_Peak_Delta) bands in the EEG as
    %       well as EMG activity.
    %
    %       Description of the LC activity surges including the number of
    %       peaks (v_SurgePeaks) their lengths (v_SurgeLengths) and
    %       area under the courves (v_SurgeAreas).
    %
    % 17.07.2024
    %
    % See also  f_ElimMA f_b2Vec f_MGT f_baselineCalculation 
    %           p_GetTau f_GetPeaks f_GetPeakInfo
    
    %% Constants and initialization
    s_Fs = 10;
    s_Fs_EEG_EMG = 200;
    
    % Hypnogram and time vectors
    [v_bnoMA,v_cMA] = f_ElimMA(v_strb);
    v_b = f_b2Vec(v_bnoMA,s_Fs);
    v_t = linspace(0,length(v_dff)/s_Fs,length(v_dff));
    
    %% Get average time constant and initial peak detection
    % (See p_GetTau and f_GetPeaks).
    v_Tau = p_GetTau(v_dff,v_strb);
    s_Tau = nanmean(v_Tau);
    v_PeaksPos = f_GetPeaks(v_dff,v_strb,b_2Plot);
    
    % v_PeaksPos are all the activity peaks in the signal, useful to
    % quantify the changes of overal activity after an specific
    % manipulation such as after Sleep Deprivation or Stressful Sleep
    % Deprivation.
    

    %% From now on is the detection of the activity surgers

    % Eliminate peaks too close to the begining of the bout using the tau
    v_PeaksPos2 = v_PeaksPos;
    v_PosElim=false(size(v_PeaksPos2));
    for idxPeak = 1:length(v_PeaksPos2)
        v_CurrState = find(v_t>(v_t(v_PeaksPos(idxPeak))-s_Tau*1.5)&v_t<(v_t(v_PeaksPos(idxPeak))));
        if any(v_b(v_CurrState) > 2 )
            v_PosElim(idxPeak)=true;
        end
    end
    v_PeaksPos2(v_PosElim) = [];

    % Find the maximum peak using a sliding window of 20 seconds
    v_PeaksPos3 = v_PeaksPos2;
    s_Window = 20*s_Fs;
    for idx = 1 : length(v_dff_High)-s_Window-1
        v_CurrPeaks = find(v_PeaksPos3 > idx & v_PeaksPos3 < (idx+s_Window));
        if length(v_CurrPeaks) > 1
            [~,s_BiggetsPeak] = max(v_dff_High(v_PeaksPos3(v_CurrPeaks)));
            v_2Elim = true(1,length(v_CurrPeaks));
            v_2Elim(s_BiggetsPeak)=false;
            v_PeaksPos3(v_CurrPeaks(v_2Elim))=[];
        end
    end
    
    %% Get HR and EMG activity
    disp('EMG and EKG processing...')
    [v_EKG] = ExtractBPM(v_EMG, v_strb, s_Fs_EEG_EMG, 1);
    
    v_envEMG = envelope(abs(v_EMG));
    v_envEMG = resample(v_envEMG,s_Fs,s_Fs_EEG_EMG);
    
    %% Get activity bands using wavelet transform
    disp('Calculating power dynamics...')
    disp('Gamma')
    [m_T_Gamma,~] = f_MGT(v_EEG,s_Fs_EEG_EMG,60,80,.25);
    m_T_Gamma = abs(m_T_Gamma);
    m_T_Gamma = resample(m_T_Gamma',s_Fs,s_Fs_EEG_EMG)';
    v_Gamma = mean(abs(m_T_Gamma));
    
    disp('Sigma')
    [m_T_Sigma,~] = f_MGT(v_EEG,s_Fs_EEG_EMG,s_Fs,15,.25);
    m_T_Sigma = abs(m_T_Sigma);
    m_T_Sigma = resample(m_T_Sigma',s_Fs,s_Fs_EEG_EMG)';
    v_Sigma = mean(abs(m_T_Sigma));
    
    disp('Delta')
    [m_T_Delta,~] = f_MGT(v_EEG,s_Fs_EEG_EMG,1.5,4,.25);
    m_T_Delta = abs(m_T_Delta);
    m_T_Delta = resample(m_T_Delta',s_Fs,s_Fs_EEG_EMG)';
    v_Delta = mean(abs(m_T_Delta));
    
    %% Isolate activity surges.
    s_MeanWindow = 200; % use of a 200 s window 150 before 50 after
    
    % In these matrices we will save the frequency powers arround
    % each of the peaks that were found in the previous step
    m_Gamma = nan(length(v_PeaksPos3),s_Fs*s_MeanWindow);
    m_Sigma  = nan(length(v_PeaksPos3),s_Fs*s_MeanWindow);
    m_Delta  = nan(length(v_PeaksPos3),s_Fs*s_MeanWindow);
    m_dff    = nan(length(v_PeaksPos3),s_Fs*s_MeanWindow);
    m_EMG    = nan(length(v_PeaksPos3),s_Fs*s_MeanWindow);
    m_EKG    = nan(length(v_PeaksPos3),s_Fs*s_MeanWindow);
    
    v_LCPeaks = nan(length(v_PeaksPos3),1);
    v_Peak_Gamma = nan(length(v_PeaksPos3),1);
    v_Peak_Sigma  = nan(length(v_PeaksPos3),1);
    v_Peak_Delta  = nan(length(v_PeaksPos3),1);
    v_Peak_EMG  = nan(length(v_PeaksPos3),1);
    v_Peak_EKG  = nan(length(v_PeaksPos3),1);

    v_TypeOfMA = zeros(length(v_PeaksPos3),1);
    % Type of MA: 0, without MA; 1: one epoch MA; 
    % 2: Two epochs or more of MA. 
    % The exact time of the MA is not included.
    disp('Identifying types of peaks...')
    for idx_Peaks = 1:length(v_PeaksPos3)
        s_CurrPeak = v_PeaksPos3(idx_Peaks);
        % Get window of sourge
        v_Positions = s_CurrPeak-150*s_Fs+1:s_CurrPeak+round(50)*s_Fs;
    
        % Only include those peaks for which the window is inside the 
        % recording (that is, We if the peak is at the beginning or the 
        % end of the recordin is not taken into account.

        if any(v_Positions<1)||any(v_Positions>length(v_Gamma))
        else
            % The data is Z-scored
            m_Gamma(idx_Peaks,:)  = (v_Gamma(v_Positions) - mean(v_Gamma(v_Positions)))   / std(v_Gamma(v_Positions));
            m_Sigma(idx_Peaks,:)  = (v_Sigma(v_Positions)  - mean(v_Sigma(v_Positions)))  / std(v_Sigma(v_Positions));
            m_Delta(idx_Peaks,:)  = (v_Delta(v_Positions)  - mean(v_Delta(v_Positions)))  / std(v_Delta(v_Positions));
            m_dff(idx_Peaks,:)    = (v_dff(v_Positions)    - mean(v_dff(v_Positions)))    / std(v_dff(v_Positions));
            m_EMG(idx_Peaks,:)    = (v_envEMG(v_Positions) - mean(v_envEMG(v_Positions))) / std(v_envEMG(v_Positions));
            m_EKG(idx_Peaks,:)    = (v_EKG(v_Positions)    - mean(v_EKG(v_Positions)))    / std(v_EKG(v_Positions));
        end
    
        %% Mean amplitudes of dff peaks, as a function of MA type
        % Get LC peak activity using the 
        v_LCPeaks(idx_Peaks) = m_dff(idx_Peaks,1500)-nanmin(m_dff(idx_Peaks,1500-100:1500));
        v_Peak_EKG(idx_Peaks)  = m_EKG(idx_Peaks,1500)-nanmin(m_EKG(idx_Peaks,1500-100:1500));

        %% Mean power band values 1 s after LC peak for every band, per recording type per animal
        v_Peak_Gamma(idx_Peaks) = nanmean(m_Gamma(idx_Peaks,1500:1510));
        v_Peak_Sigma(idx_Peaks)  = nanmean(m_Sigma(idx_Peaks,1500:1510));
        v_Peak_Delta(idx_Peaks)  = nanmean(m_Delta(idx_Peaks,1500:1510));
        v_Peak_EMG(idx_Peaks)  = nanmean(m_EMG(idx_Peaks,1500:1510));
    
        %% Here is only to identify the type of MA of each peak
        for idx_MA = 1:length(v_cMA)
            v_MA = v_cMA{idx_MA};
            if any((abs(v_MA*4-(s_CurrPeak/s_Fs)))<5)
                v_TypeOfMA(idx_Peaks) = idx_MA;
                break;
            end
        end
    end
    
    v_TypeOfMA(v_TypeOfMA>1)=1;

    %% Organize output
    % Save the information for further analysis.
    st_Output=struct([]);
    st_Output.v_LCPeaksPos = v_PeaksPos;
    st_Output.m_Gamma = m_Gamma;
    st_Output.m_Sigma = m_Sigma;
    st_Output.m_Delta = m_Delta;
    st_Output.m_dff = m_dff;
    st_Output.m_EKG = m_EKG;
    st_Output.m_EMG = m_EMG;

    st_Output.v_TypeOfMA = v_TypeOfMA;

    st_Output.v_LCPeaks = v_LCPeaks;
    st_Output.v_Peak_EKG = v_Peak_EKG;
    st_Output.v_Peak_Gamma = v_Peak_Gamma;
    st_Output.v_Peak_Sigma = v_Peak_Sigma;
    st_Output.v_Peak_Delta = v_Peak_Delta;
    st_Output.v_Peak_EMG = v_Peak_EMG;

    %% Description of LC surges to compare between those with or without MAs
    % Initialize window
    s_MeanWindow = 100; 

    m_dff_Descriptions = nan(length(v_PeaksPos3),s_Fs*s_MeanWindow);

    v_SurgePeaks = nan(length(v_PeaksPos3),1);
    v_SurgeLengths = nan(length(v_PeaksPos3),1);
    v_SurgeAreas = nan(length(v_PeaksPos3),1);
    for idx_Peaks = 1:length(v_PeaksPos3)
        s_CurrPeak = v_PeaksPos3(idx_Peaks);
        v_Positions = s_CurrPeak-round(s_MeanWindow/2)*s_Fs+1:s_CurrPeak+round(s_MeanWindow/2)*s_Fs; 
        
        % Only include those peaks for which the window is inside the 
        % recording (that is, We if the peak is at the beginning or the 
        % end of the recordin is not taken into account.
        if any(v_Positions<1)||any(v_Positions>length(v_dff))
        else
            v_LCActivityInDetectedPeak = (v_dff(v_Positions)-min(v_dff(v_Positions)))/std(v_dff(v_Positions)); % a within-window modified z-scoring with minimum at 0
            m_dff(idx_Peaks,:) = v_LCActivityInDetectedPeak;
            s_ThPerc = .15;
            round(v_Positions(1)/10)
            [s_Peaks,s_Lengths,s_Areas] = f_GetPeakInfo(v_LCActivityInDetectedPeak,s_Fs,s_ThPerc); % Use single one
            v_SurgePeaks(idx_Peaks) = s_Peaks;
            v_SurgeLengths(idx_Peaks) = s_Lengths;
            v_SurgeAreas(idx_Peaks) = s_Areas;
        
        end
    end

    %% Save results 
    st_Output.v_SurgePeaks = v_SurgePeaks;
    st_Output.v_Lengths = v_SurgeLengths;
    st_Output.v_Areas = v_SurgeAreas;

end



function v_Tau = p_GetTau(v_dff,b);
% This program calculates the time constant (Tau) decay of LC activity
% of all NREM bouts followed by wakefulness of >60 s
% (Change in s_TimeWakeBeforeNR). Using a fixed sample frequency (Fs)
% of 10 Hz.
%
% In short, this function uses a single exponential fit of the lower
% envelope of the the filtered (<0.1 Hz) dff signal.
%
%
% Inputs:
%   v_dff: Calcium signal to find the decay constant.
%   b : Hypnogram of the signal in 4 s windows coded as described in
%       f_ActivitySourges.
%
% Outputs:
%   v_Tau: Vector of time constants for each NREM bout followed by a
%          long Wake (>60 s) period.

%% Constants
s_TimeWakeBeforeNR = 60;
s_Fs = 10;

%% Initialization: eliminate MA from b and filtering of dff signal

[v_bnoMA,~]     = f_ElimMA(b); % Include MA as part of NR

bhi_Low = fir1(100, 0.1/5,'low');
v_dff_filt = filtfilt(bhi_Low,1,v_dff);

%% Find NREM bouts (>96 s) followed by long >60 s wake

[v_WNR_Ini,v_WNR_End] = regexp(v_bnoMA,'w{15}n{24,}');

% If the last bout is too close to the end of the recording,
% the dff might include an artifact of the df/f. We thus eliminate such
% bout.
if v_WNR_End(end)>length(v_bnoMA)*.99
    v_WNR_Ini(end)=[];
    v_WNR_End(end)=[];
end

%  List of all bouts found in regexp, one epoch to be added for last pos in regexp
m_W2NR = nan(length(v_WNR_Ini),max(v_WNR_End-v_WNR_Ini)*4*s_Fs+39);

% Get the calcium data for each bout.
for idx_W2NRBout = 1:length(v_WNR_Ini)

    if v_WNR_End(idx_W2NRBout)==length(v_bnoMA)

        v_CurrBout = v_dff_filt(v_WNR_Ini(idx_W2NRBout)*4*s_Fs:v_WNR_End(idx_W2NRBout)*4*s_Fs);
        v_CurrBout = v_CurrBout-min(v_CurrBout); % Minimum at 0.
        m_W2NR(idx_W2NRBout,1:length(v_CurrBout)) = v_CurrBout;

    else

        v_CurrBout = v_dff_filt(v_WNR_Ini(idx_W2NRBout)*4*s_Fs:v_WNR_End(idx_W2NRBout)*4*s_Fs+39);
        v_CurrBout = v_CurrBout-min(v_CurrBout);
        m_W2NR(idx_W2NRBout,1:length(v_CurrBout)) = v_CurrBout;

    end
end
%% Get Tau

v_Tau = zeros(1,size(v_WNR_Ini,2)); % One value per bout.
for s_bout = 1:length(v_WNR_Ini)

    clc
    disp(['Bout: ',num2str(s_bout),' of ',num2str(length(v_WNR_Ini))])

    v_Curr_dff = m_W2NR(s_bout,~isnan(m_W2NR(s_bout,:)));
    v_t = linspace(0,length(v_Curr_dff)/s_Fs,length(v_Curr_dff));

    % Calculate the Lower envelope using a window of 96 s
    [~,v_LowEnvelope] = envelope(v_Curr_dff,960,"peak");

    % Fit exponential decay to such envelope (eliminate the minute of wake included for each bout).
    f_ExpDec_v3 = fit(v_t(v_t>s_TimeWakeBeforeNR)',v_LowEnvelope(v_t>s_TimeWakeBeforeNR)','exp1');
    s_Tau = coeffvalues(f_ExpDec_v3);
    v_Tau(s_bout) = -1/s_Tau(2);

end

% Eliminate Tau for bouts with values over 100 s and under 0 s.
v_BadBout = find(v_Tau<0|v_Tau>1000);
disp(['number of bad bouts is ', num2str(length(v_BadBout))])
v_Tau(v_BadBout)=[];

end


function v_PeaksPos = f_GetPeaks(v_dff,v_strb,b_2Plot)
% f_GetPeaks
% This function gets the all the peaks within NREM sleep (including MA)
% in a photometry signal. The function uses the filtered dff signal at
% 0.5 Hz (High filter) and 0.1 Hz (Low filter).
%
% Then it uses the envelope of the throughs of the low filtered signal
% to correct for the ongoing baseline of the data in the high filtered
% signal using a window of 96 s.
%
% This correction is done on the High filtered signal which is then
% used to optain the peaks. The peak location is done using the
% findpeak function of Matlab keeping those that with a minimum of
% 60% of prominance of the total amount of peaks. Finally, those peaks
% with a prominance higher than 25% and whose absolute amplitude is
% at least 20% of the signal amplitude are kept for furhter analysis.
%
% Inputs:
%   v_dff: Calcium signal to find the decay constant.
%   v_strb : Hypnogram of the signal in 4 s windows coded as described
%            in f_ActivitySourges.
%   b_2Plot: Boolean to plot examples of the detected Tau.
%
% Outputs:
%   v_PeaksPos: Position of all Calcium peaks.

%% Initialize
s_Fs = 10;
[v_b,s_NMA]     = f_ElimMA(v_strb);  % Include MA as NREM sleep.

v_Hyp = f_b2Vec(v_b,s_Fs);   % Convert hypnogram to coded vector.
v_Hyp(end-10*s_Fs*60:end) = 3; % This line is to convert the
% last 10 minutes in Wake, because in
% many cases there is an artifact in the
% df/f at the end of the recording.

v_Hyp(1) = 3;
v_Hyp(v_Hyp==4) = 3;
v_Hyp(v_Hyp==5) = 2;
v_Hyp(v_Hyp==6) = 1;
v_t = linspace(0,length(v_Hyp)/s_Fs,length(v_Hyp)); % There is the problem!!!!!! 03.02.23


if b_2Plot % ONLY FOR PLOTTING for the analysis it does not change
    disp('Plotting...')
    disp('Correcting baseline for dff..')
    [fitbasdff,~] = f_baselineCalculation(v_dff,60,v_strb,s_Fs);
    v_dff=v_dff-fitbasdff;
    %%%%%%%%%%
    st_Fig = figure('Units','normalized','Position',[.05 .1 .9 .8],...
        'Name',[str_Animal,' ',str_Recording],'Color','w');
    h(1) = subplot(5,1,1);
    plot(v_t,v_Hyp,'LineWidth',1,'Color','k')
    set(gca,'ytick',[1 2 3],'yTickLabel',{'REM','NREM','Wake'})

    h(2) = subplot(5,1,2:3);
    s_Ymin = min(v_dff(1:3600));
    s_Ymax = max(v_dff(1:3600));
    plot(v_t,v_dff,'LineWidth',1,'Color',[70 160 70]/255)
    set(gca,'YLim',[s_Ymin s_Ymax])
    ylabel('Df/f')
end

%% Filter signal
bhi_High = fir1(100, .5/5,'low');
bhi_Low = fir1(100, 0.1/5,'low');

v_dff_High = filtfilt(bhi_High,1,v_dff);
v_dff_Low = filtfilt(bhi_Low,1,v_dff);

%% Envelop Method
% Calculate the lower envelope using a window of 96 s
[~,v_LowerEnvelope] = envelope(v_dff_Low,960,"peak");
if b_2Plot % ONLY FOR PLOTTING for the analysis it does not change
    hold on;
    plot(v_t,v_dff_High,'LineWidth',1,'Color','r')
    plot(v_t,v_dff_Low,'LineWidth',1,'Color','b')
    plot(v_t,v_LowerEnvelope,'LineWidth',1)
end
v_ToDetectPeaks = v_dff_High-v_LowerEnvelope; % Rectification of the fast signal
v_ToDetectPeaks(v_Hyp~=2) = nan;

if b_2Plot % ONLY FOR PLOTTING for the analysis it does not change
    h(3) = subplot(5,1,4:5);
    plot(v_t,v_ToDetectPeaks,'LineWidth',1)
end

[pks1,locs1,v_widths1,v_proms1] = findpeaks(v_ToDetectPeaks);
% Select peaks with a minimum prominence of the 60 percentile of all peaks.
[pks2,locs2,v_widths2,v_proms2] = findpeaks(v_ToDetectPeaks,"MinPeakProminence",prctile(v_proms1,60),'WidthReference','halfheight');

%% Eliminate small peaks with at least 25 % of Maximum LC activity
idx_Peaks = 1;
while idx_Peaks <= length(locs2)
    if v_proms2(idx_Peaks)<.25*nanmax(v_ToDetectPeaks(locs2(1:end-1))) && v_ToDetectPeaks(locs2(idx_Peaks))<(nanmax(v_ToDetectPeaks))*.20
        pks2(idx_Peaks)      = [];
        locs2(idx_Peaks)     = [];
        v_widths2(idx_Peaks) = [];
        v_proms2(idx_Peaks)  = [];
    else
        idx_Peaks = idx_Peaks + 1;
    end
end

v_PeaksPos = locs2;

if b_2Plot % ONLY FOR PLOTTING for the analysis it does not change
    hold on
    scatter(v_t(locs2),v_ToDetectPeaks(locs2),'kx')
    hold off
    axes(h(2))
    scatter(v_t(locs2),v_dff_High(locs2),'kx')
    linkaxes(h,'x')
end


end


function [s_Peaks,s_Length,s_Area] = f_GetPeakInfo(v_LCActivityInDetectedPeak,s_Fs,s_ThPerc)
    % f_GetPeakInfo Defines the begining and end of the surge using a 100 s
    % window around the detected surge peaks. The start of the surge is
    % then defined as the momento when the derivative signal that falls
    % within the 10 s before the peak and the end of it as the moment when
    % the LC activity reaches 15 % of the signal maximum signal within the
    % 100 s window.
    % Finally the number of activity peaks, the length and the area under
    % the courve of the surge are output from the function.
    % 
    % Input:
    %   v_LCActivityInDetectedPeak:
    %   s_Fs: Sampling frequency (10 Hz for must purposes).
    %   s_ThPerc: Threshold to define the end of the surge (Usually 15 %).
    %
    % Ouytput:
    %   s_Peaks: Number of peaks within the surge.
    %   s_Length: Length of the surge.
    %   s_Area: Area under the curve of the surge.
    %

    % Threshold of after peak for end of surge
    s_CurrTh = v_LCActivityInDetectedPeak(length(v_LCActivityInDetectedPeak)/2)*s_ThPerc;    
    v_DiffLC = diff(v_LCActivityInDetectedPeak);

    %% Find start based on the derivative signal
    % Find peaks the peaks of in the derivate signal in the 10 seconds before the peak
    [v_ValPeaksDiff,v_PosPeaksDiff] = findpeaks(v_DiffLC(400:500));

    % Using the first big peak over at least 25 % of the signal.
    v_PosPeaksDiff(v_ValPeaksDiff<max(v_ValPeaksDiff)*.25)=[];
    s_StartEvent = 400 + v_PosPeaksDiff(1);    
    
    %% End of the event based on the threshold
    s_EndEvent = find(v_LCActivityInDetectedPeak(round(length(v_LCActivityInDetectedPeak)/2):end)<s_CurrTh,1,'first')+round(length(v_LCActivityInDetectedPeak)/2);
    
    %% Peak Description
    v_LCActivityInDetectedPeak(1:s_StartEvent)=nan;
    v_LCActivityInDetectedPeak(s_EndEvent:end)=nan;

    s_Peaks = length(findpeaks(v_LCActivityInDetectedPeak));
    s_Length = sum(~isnan(v_LCActivityInDetectedPeak))/s_Fs; %AL: this should not be the sum of values but the length of the vector?
    s_Area = nansum(v_LCActivityInDetectedPeak);

end