function [ conf ] = Ypnos_getConf
%YPNOS_GETCONF To add new configuration of implantations

conf.confList = {'EEG';'Pin10';'colabRodriguez';'SL_AEPs';'SL_test';'SL_test2';'EEG17';'s1hl';'thalS1';'thalS14';'OS8';'Os17';'OsLi';'FPh';'DoubleCL';'SoundOpt';'Rb';'RT';'RT_mod'};

% Keep the same order as the conflist

conf.EEG = {1,2};
conf.Pin10 = {24, 23, 21, 19, 17, 15, 13, 11, 9};
conf.colabRodriguez = {19,9,24,23,15,11}; % Leonardo Marconi & Laura: 24/refL, 23/EEGf, 19/EEGp, 15/S1R, 11/EMGr, 9/EMGl
conf.SL_AEPs = {[24,23],21, 17, [13,11], 9};
conf.SL_test = {[24,23],[13,11]};
conf.SL_test2 = {24,11};
conf.EEG17 = {1,8};
conf.s1hl = {[23 15], [17 9], 21, 13, 24}; % {'ref', 'eep', 'S1R', 'emg', 'eef','S1L','emg'};{24, 23, 21, 17, 15, 13, 9};
conf.thalS1 = {[23 9], [17 11], 19, 15, 13, 24}; % {[eef, eep], [emg, emg], S1, M1, Prl, Ref};
conf.thalS14 = struct('A1',{{[23 9], [17 11], 19, 15, 13, 24}},...
    'A2',{{[23 9], [17 11], 19, 15, 13, 24}},...
    'A3',{{[23 9], [17 11], 19, 15, 13, 24}},...
    'A4',{{[23 9], [21 15], 13, 17, 19, 24}});
conf.OS8 = {[24 15],[13 11],23,19,9};
conf.Os17 = {[24 15],[13 11], 23, 21, 19, 9};
conf.OsLi = {[24 15],[13 11], 23, 21, 17, 9};
conf.FPh = {[24 15],[13 11],  21, 9};
conf.DoubleCL = {[22,12], [7,3], 26};
conf.SoundOpt = {[24 15],[13 11],23,19};
% conf.Rb = {[24 15],[13 11],21};
conf.AO_Rb = struct('A1',{{[24, 17], [13, 11], 21}},...
    'A2',{{[24, 17], [13, 11], 21}},... 
    'A3',{{[24, 17], [13, 11], 21}},... 
    'A4',{{[24, 17], [9, 11], 21}},...    
    'A5',{{[24, 17], [13, 11], 21}},...
    'A6',{{[24, 17], [13, 11], 21}},...
    'A7',{{[24, 17], [13, 11], 21}},...
    'A8',{{[24, 17], [13, 11], 21}});
conf.RT = {[24 15],[13 11],23,19};

conf.RT_Mod = struct('A1',{{[19 13],[11 9],17,15}},...
    'A2',{{[24 15],[13 11],23,19}},... 
    'A3',{{[24 15],[13 11],23,19}},... 
    'A4',{{[24 15],[13 11],23,19}});  
    
end

