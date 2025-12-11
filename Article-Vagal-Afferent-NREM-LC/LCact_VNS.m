function [dff_zscore, meandff_zscore] = LCact_VNS(targettime,targettime2)

%clc

%close all

%targettime, targettime2 in seconds


% targettime=3440; %baseline time
% targettime1=5365; % injection time
% targettime2=5516;  % time of sleep onset after injection
% targettime3=6320; % time of REMS onset
% the values above are example values for a given recording that were set
% manually


[str_Files, str_Path] = uigetfile('*.mat', 'Select the recording to analyze');  
fileName = fullfile(str_Path,str_Files);

load(fileName)
disp('Loaded...')
disp(str_Files)

% find baseline time
dfftimestamps=dff(1,:); % in 60.2 Hz (0.0166 s) time intervals in the Doric recording systems

baseline_end=targettime; % in s
timediff=abs(dfftimestamps-baseline_end);
[~, baseline_dff]=min(timediff);

dff_baseline=dff(2,1:baseline_dff);

% find time of drug effect

firstsleep=targettime2; % in s
timediff=abs(dfftimestamps-firstsleep);
[~, tofsleep_dff]=min(timediff);

% firstREMS=targettime3; % in s
% timediff=abs(dfftimestamps-firstREMS);
% [~, tofrems_dff]=min(timediff);

%dff_drugtime=dff(2,tofsleep_dff:tofrems_dff);
dff_drughour=dff(2,tofsleep_dff:tofsleep_dff+216720);

% calculate dffs for baseline values

dffmean_baseline=mean(dff_baseline);
%dffmean_drugtime=mean(dff_drugtime)
dffstd_baseline=std(dff(2,1:baseline_dff));
zscoredff_baseline=(dff(2,1:baseline_dff)-dffmean_baseline)./dffstd_baseline;

% calculate dff before first REMS, from injtime
% InjTime=targettime2
% timediff=abs(dfftimestamps-InjTime);
% [~, InjTime_dff]=min(timediff);

%dffmean_treatment=mean(dff(2,InjTime_dff:tofrems_dff))

dff_zscore=(dff_drughour - dffmean_baseline)./dffstd_baseline;
meandff_zscore=[];
meandff_zscore=mean(dff_zscore);
%dff_increase=dffmean_drugtime - dffmean_baseline


% To plot
v_t=1:1:length(b)*4;
v_b=f_b2Vec(b,1);
figure
subplot(2,2,1:2)
plot(v_t,v_b)
subplot(2,2,3:4)
plot(dff(1,:),dff(2,:))
gca
YLim=[-20 100]

end