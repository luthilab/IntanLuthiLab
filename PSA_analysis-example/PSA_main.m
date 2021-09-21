function PSA_main
%PSA_MAIN This is an example of a practical way of grouping data from
%multiple animals into a PSA. A PSA is a structure which is build using the
%names and info found in the file names that where analysed. It works using
%the name format of VeryScore2 like this:

% animalName_phase_condition_bt.mat

% the phase is 01 for lightphase and 02 for dark, then 03 for the following
% lightphase etc... They last 12h.

%% First we ask if the user needs a new PSA or to complete an existing one.
addpath('analysis_functions')

an = questdlg('Load a PSA or create a new one ?', 'To do.', 'Load PSA', 'New', 'Load PSA');

if strcmp(an, 'Load PSA')
    [Namepsa, Pathpsa] = uigetfile('*.mat', 'Select your psa result structure to complete');
    p = load([Pathpsa,Namepsa]);
    PSA = p.PSA;
else
    PSA = struct;
    an = inputdlg('Give a name for the new PSA: ');
    Namepsa = ['PSA_',an{1},'.mat'];
    Pathpsa = cd;
    save(Namepsa,'PSA','-v7.3');
end

%% Second, make a file selection for the analysis

[Names, Path] = uigetfile('G:\RESEARCH\AL\PRIVATE\*.mat', 'Select your basic bt files to add to PSA','multiselect', 'on');
if ~iscell(Names) % If there is just one file selected we need to put it in a cell for the folowing step.
    Names = {Names};
end

%% Third, loop through the files and extract the information into the PSA.

% Initiate the waitbar and the timer start
w = waitbar(0,'Hard work in progress'); wbomb = onCleanup(@() delete(w));
ela = inf;

for i = 1:length(Names)
    tic % for the elapsed time per file
    % update the waitbar
    waitbar(i/length(Names),w,['Hard work in progress! Remaining: ',num2str(length(Names)-i+1),' file(s) ',num2str(ela*(length(Names)-i+1),5),' sec'])
    
    filename = Names{i}; % get the current filename
    disp(filename) % Show the name
    sep = strsplit(filename, '_'); % Split the name in parts
    animal_name = sep{1}; % Get the animal name
    phase = ['P', sep{2}]; % the phase
    condition = sep{3};
    
    % Extract the traces, the scoring and information
    mfile = matfile([Path,filename]);
    
    traces = mfile.traces; % For simple eeg we have the EEG as (1,:) and EMG as (2,:)
    b = mfile.b; % b is the behavioral state string of 4 sec epochs.
    Infos = mfile.Infos;
    Fs = str2double(Infos.Fs); % Get the sampling rate
    
    % Part to load the traces in a specified order (require that the field
    % Infos.Channel within the file contains the channel names.
%     order = {'prl','em1','em2'};
%     traces = loadCorrectTraces(mfile, order);
    
    % Perform the analysis on the current file and fill the PSA
    
    PSA.(animal_name).result.(phase).(condition).time_in_state = countStates(b);
    PSA.(animal_name).result.(phase).(condition).power_spectrum = powerSpectrum(b, traces(1,:), Fs);
    
    % To estimate the amount of time remaining
    ela = toc;
end

save([Pathpsa,Namepsa],'PSA','-v7.3')
disp(['Done in ',num2str(ela*i),' sec'])
close(w)

end

