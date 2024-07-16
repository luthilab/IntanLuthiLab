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

conf.confList = {'Pin6','EEG','Pin10','AO_S1x2','AO_Ph','colabRodriguez','AllAnalog',...
    'Lila','AO_FPh','Maxime','pin6ana','AO_Aud','AO_Rb','AO_FPhx2',...
    'NC_opto_Led','NC_FPhx2_Neu30','GF_FPh_Neu30'};

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
conf.colabRodriguez = {24, 23, 21, 19, 15, 11}; % Leonardo Marconi & Laura: 24/refL, 23/EEGf, 21/EEGp, 19/S1R, 15/EMGr, 11/EMGl
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
conf.AO_Rb = struct('A1',{{[24, 17], [13, 11], 21, '1'}},... % ref,EMG,EEF,EEP,EMG JB5
    'A2',{{[24, 17], [13, 11], 21, '2'}},... 
    'A3',{{[24, 17], [13, 11], 21, '3'}},... 
    'A4',{{[24, 17], [13, 11], 21, '4'}},...    
    'A5',{{[24, 17], [13, 11], 21, '5'}},...
    'A6',{{[24, 17], [13, 11], 21, '6'}},...
    'A7',{{[24, 17], [13, 11], 21, '7'}},...
    'A8',{{[24, 17], [13, 11], 21, '8'}});
conf.AO_FPhx2 = {[24, 17], [13, 11], 21,'1','2','3'}; % For fiber phot

%% NAJMA
%For opto Neurobau32 LEFT NC
conf.NC_opto_Led = struct('A1',{{[13,17],[19,21],24,9, '1'}},...
    'A2',{{[13,17],[19,21],24,9, '2'}},... 
    'A3',{{[13,17],[19,21],24,9, '3'}},... 
    'A4',{{[13,17],[19,21],24,9, '4'}});
% For fiber phot Neurobau30 NC
conf.NC_FPhx2_Neu30 =  struct('A1',{{[24, 17],[13,11],21,9,'1','3'}},... %CVSNA: EEGf,EEGp,EMG1,EMG2,S1,ref,signal,read
    'A2',{{[24, 17],[13,11],21,9,'2','3'}});

%% Georgios
%For fiber photometry 2 signals GF
conf.GF_FPh_Neu30 =  struct( 'A1',{{[24, 17],[13,11],21,9,'4'}}); %GF test
end

