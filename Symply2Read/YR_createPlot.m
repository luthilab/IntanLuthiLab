function [ h, c ] = YR_createPlot( h, c )
%createSubplot This function creates subplots for proper display
%   Detailed explanation goes here

layoutstr   = h.setLayout.String;
tempval     = h.setLayout.Value;
tempstr     = layoutstr{tempval};

switch tempstr
    case 'thals1'  
        h.traceIndex = {[23 9], [17 11], 19, 15, 13, 24,[],[],[],[]};
        h.nb = length(h.traceIndex);
        h.traceName = {'eeg', 'emg', 'S1', 'm1','prl','ref','stim1','stim2','stim3','stim4'};
    case 'iRo1'
        h.traceIndex = {24, 23, 21, 17, 15, 13, 9, [], []};
        h.nb = length(h.traceIndex);
        h.traceName = {'ref', 'emg', 'S1L', 'emg', 'eeg','S1R','eeg','stimLeg','stimHead'};
    case 'Laura'
        h.traceIndex = {24, 23, 21, 17, 13, 11, 9};
        h.nb = length(h.traceIndex);
        h.traceName = {'EEG1', 'EEG2', 'S1a', 'S1b', 'EMG1', 'EMG2', 'REF'};
    case 'S1HL_opto'
        h.traceIndex = {24, 23, 21, 17, 15, 13, 9};
        h.nb = length(h.traceIndex);
        h.traceName =  {'ref', 'eep', 'S1R', 'emg', 'eef','S1L','emg'};
    case 'HUMAN'
        h.traceIndex = {23};
        h.nb = length(h.traceIndex);
        h.traceName = {'Head'};
    case 'EEG+Stim'
        h.traceIndex = {1,2,[],[]};
        h.nb = length(h.traceIndex);
        h.traceName = {'eeg', 'emg', 'Stim1', 'Stim2l'};
    case 'RC_HeadChip'
        h.traceIndex = {24,21,15,[23,17],[13,11],9};
        h.nb = length(h.traceIndex);
        h.traceName = {'EEHH', 'OOHH', 'Chocolat', 'Cuscus', 'Soleil', 'BaBaBa'};
    case 'SL_silicon16'
        %h.traceIndex = []; TO DEFINE
        h.nb = length(h.traceIndex);
    case 'SL_AEPs'
        h.traceIndex = {[24,23],21, 17, [13,11], 9, []};
        h.nb = length(h.traceIndex);
        h.traceName = {'EEG', 'S1', 'Au1', 'EMG', 'Ref', 'Stim'};
    case 'SL_OAEPs'
        h.traceIndex = {[24,23],21, 17, [13,11], 9, [], []};
        h.nb = length(h.traceIndex);
        h.traceName = {'EEG', 'S1', 'Au1', 'EMG', 'Ref', 'Noise', 'Laser'};
    case 'ALL'
        h.traceIndex = {24,23, 22, 21, 20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9};
        h.nb = length(h.traceIndex);
        h.traceName = {'24','23', '22', '21', '20', '19', '18', '17', '16', '15', '14', '13', '12', '11', '10', '9'};
    case '10Pin'
        h.traceIndex = {24, 23, 21, 19, 17, 15, 13, 11, 9};
        h.nb = length(h.traceIndex);
        h.traceName = {'23', '22', '20', '18', '16', '14', '12', '10', '8'};
    case 'LC-TRN_Pharm'
        h.traceIndex = {24, 21, 17, [13, 11], 9};
        h.nb = length(h.traceIndex);
        h.traceName = {'S1', 'EEG_f', 'EEG_p', 'EMG', 'Ref'};        
    case 'DIO'
        h.traceIndex = {24, 23, 21, 19, 17, 15, 13, 11, 9};
        h.nb = length(h.traceIndex);
        h.traceName = {'23', '22', '20', '18', '16', '14', '12', '10', '8'};
    case 'EEG1'
        h.traceIndex = {1, 8};
        h.nb = length(h.traceIndex);
        h.traceName = {'EEG','EMG'};
        
    otherwise
        h.nb = str2double(tempstr(1:(strfind(tempstr, 'x')-1)));
        h.traceIndex = 1:h.nb;
end


h.traceHandle = cell(h.nb,3);

%% check and remove old layout

if isfield(h,'mainPlot') == 1
    delete(h.mainPlot)
    delete(h.fftPlot)
    h = rmfield(h,'mainPlot'); 
    h = rmfield(h,'fftPlot');
end

%% set new layout

sr = 200; %SET IT SOMEWHERE
X_temp = -20:(1/sr):(-1/sr);
Y_temp = zeros(1,20*sr);

for j = 1:h.chipID
    h.mainPlot(j) = axes('parent', h.tabAnimal(j),...
        'position', [.1 .07 .85 .9]);
    h.mainPlot(j).YColor = c.background;
    h.mainPlot(j).TickDirMode = 'manual';
    h.mainPlot(j).TickDir = 'out';
    
    for i = 1:length(h.traceIndex)
        h.(char(['trace_animal', num2str(j)])){i,1} = line(X_temp,Y_temp + h.nb - i +1);
        if isempty(h.traceIndex{i})
            h.(char(['trace_animal', num2str(j)])){i,2} = 1;
        else
            h.(char(['trace_animal', num2str(j)])){i,2} = 1000;
        end
        h.(char(['trace_animal', num2str(j)])){i,3} = Y_temp;
        
        h.(char(['edittrace', num2str(j)])){1,i} = uicontrol('style', 'edit',...
            'parent',  h.tabAnimal(j),...
            'units', 'normalized',...
            'position', [.01 .94-(i*1/h.nb)*0.77 .08 .05],...
            'string', h.traceName{i});
    end
    
    h.mainPlot(j).YLim = [h.nb-i, h.nb+1];
    h.mainPlot(j).TickDir = 'out';
    xlabel('Time (s)')
end

%% create the fft axes

h.fftPlot = axes('parent', h.panelFFT);
res = 200; % we have 200 point per second
ny = res/2; % Nyquist limit is half the resolution
Hz = linspace(0,1,((res*4)/2)+1)*ny;
h.fftLine = line(h.fftPlot,Hz, ones(1,length(Hz)));
h.fftPlot.XScale = 'linear';
ylim([0 0.02])
xlim([0 60])

end

