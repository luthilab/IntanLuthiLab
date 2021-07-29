function [ conf ] = Y2R_getConf
%YPNOS_GETCONF To add new configuration of implantations
% create new configuration by adding the name in the confList and the order
% of the channel (from intan) as a field of conf.
%
% The channels for the 10 pins of our adapters are {24, 23, 21, 19, 17, 15, 13, 11, 9};
% To set a configuration for each animal precise in the format:
% 
% conf.ConfigPerAnimal = struct(...
%     'A1',{{8,1}},...
%     'A2',{{1,8}},...
%     'A3',{{8,1}},...
%     'A4',{{1,8,9}});

conf.confList = {'Pin6','EEG','Pin10','AO_S1x2','AO_Ph','AllAnalog','Lila','AO_FPh', 'Maxime','pin6ana','AO_Aud','NC_Led','AO_Rb'};

% Keep the same order as the conflist (otherwise it WILL fail)
% To get an analog channel give the channel as character like '1' for first
% ADC channel, '2' for second etc...
% To get the data from the accelerometer if available, add 'xyz' (will add
% three more channel)

conf.Pin6 = {26,7,3,22,12};
conf.EEG = {8,1}; % with the eeg omnetics adaptors
conf.Pin10 = {24, 23, 21, 19, 17, 15, 13, 11, 9};
conf.AO_S1x2 = {[24, 15], 21, 17, [13, 11], 9}; % For right and left S1 recordings
conf.AO_Ph = {21, 17, 13, 11, 24, 9}; % For Pharmacology recordings
conf.AllAnalog = {'1','2','3'};
conf.Lila = struct('A1',{{24,21,19,15,11}},... % ref,EMG,EEF,EEP,EMG JB5
    'A2',{{24,15,23,19,9,13}},... % ref,EMG,EEF,EEP,EMG, A1 JB6
    'A3',{{24,21,19,13,11,17}},... %ref,EMG,EEF,EEP,EMG, A1
    'A4',{{24,21,19,13,11,17}});
conf.AO_FPh = {24, 17, 21, 13, 11, 9,'1','2'}; % For fiber phot
conf.Maxime = {21,13,24,'xyz'};
conf.pin6ana = struct('A1',{{26,7,3,22,12,'1'}},... % ref,EMG,EEF,EEP,EMG JB5
    'A2',{{26,7,3,22,12,'2'}},... % ref,EMG,EEF,EEP,EMG, A1 JB6
    'A3',{{26,7,3,22,12,'3'}},... %ref,EMG,EEF,EEP,EMG, A1
    'A4',{{26,7,3,22,12,'4'}});
conf.AO_Aud = struct('A1',{{24, 15, 13, 11, 21, 19,'1'}},... % ref,EMG,EEF,EEP,EMG JB5
    'A2',{{24, 15, 13, 11, 21, 19,'2'}},... 
    'A3',{{24, 15, 13, 11, 21, 19,'3'}},... 
    'A4',{{24, 15, 13, 11, 21, 19,'4'}});
conf.NC_Led = struct('A1',{{[21, 24], [17, 15], 11, '1'}},... % ref,EMG,EEF,EEP,EMG JB5
    'A2',{{[21, 24], [17, 15], 11, '2'}},... 
    'A3',{{[21, 24], [17, 15], 11, '3'}},... 
    'A4',{{[21, 24], [17, 15], 11, '4'}});
conf.AO_Rb = struct('A1',{{[24, 17], [13, 11], 21, '1'}},... % ref,EMG,EEF,EEP,EMG JB5
    'A2',{{[24, 17], [13, 11], 21, '2'}},... 
    'A3',{{[24, 17], [13, 11], 21, '3'}},... 
    'A4',{{[24, 17], [13, 11], 21, '4'}},...    
    'A5',{{[24, 17], [13, 11], 21, '5'}},...
    'A6',{{[24, 17], [13, 11], 21, '6'}},...
    'A7',{{[24, 17], [13, 11], 21, '7'}},...
    'A8',{{[24, 17], [13, 11], 21, '8'}});

end

