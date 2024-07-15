function [ conf ] = Adonis_getConf
%YPNOS_GETCONF To add new configuration of implantations
% create new configuration by adding the name in the confList and the order
% of the channel (from intan) as a field of conf.
%
% The channels for the 10 pins of our adapters are {24, 23, 21, 19, 17, 15, 13, 11, 9};
% Give two channels in [] to extract the differential. The first two
% channels must be EEG and EMG.

conf.confList = {'DoubleCL','S1HL','oldEEG','EEG','Pin10','LC_Opt','SNI_L','OS8','Os17','OsLi'};

% Keep the same order as the conflist VERY IMPORTANT! 
conf.DoubleCL = {[22,12], [7,3], 26};
conf.S1HL = {[26,7],[22,12],3};
conf.oldEEG = {1,8};
conf.EEG = {8,1};
conf.Pin10 = {24, 23, 21, 19, 17, 15, 13, 11, 9};
conf.LC_Opt = {[17, 15], [23,9], 21,11,24};
conf.SNI_L = {[11 13],[23 9],21,19,17,15,24};
conf.OS8 = {[24 15],[13 11],23,19,9};
conf.Os17 = {[24 15],[13 11], 23, 21, 19, 9};
conf.OsLi = {[24 15],[13 11], 23, 21, 17, 9};

end

