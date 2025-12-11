function f_ReduceAndNameChnsAndAddFib(str_pathEphys,str_NameEphys,str_pathFib,str_NameFib)

%REDUCEBTFILESIZE This function reduce the size on the BT files by loading
%everything and resaving in one shot. Apparently it reduces them.

   
w = waitbar(.2, 'Loading all variables from file');

if nargin == 0
    [str_NameEphys,str_pathEphys] = uigetfile('*.mat', 'Select your Ephys File');

    fEphys = matfile(fullfile(str_pathEphys,str_NameEphys),'Writable',true);

    [str_NameFib, str_pathFib] = uigetfile('*.doric', 'Select your Doric File');
else
    fEphys = matfile(fullfile(str_pathEphys,str_NameEphys),'Writable',true);
end

trigger = fEphys.traces(7,:);
TimesAfterStart = find(trigger>5e-05);
TimeToAdd = TimesAfterStart(1)/1000;

temp = strsplit(str_NameEphys,'_');
mouseName = temp{2};

% load the .doric to check in which position you find the mouse data

DoricName = strsplit(str_NameFib,'_');
DoricMousePos = find(strcmp(DoricName,mouseName));

if DoricMousePos == 1

   % the mouse in the position one and you need to look at the AIN01
   % channel of the doric file

   fibFileName = fullfile(str_pathFib,str_NameFib);

   % for loading the isosbestic data 
   SignalIso = h5read(fibFileName ,'/DataAcquisition/FPConsole/Signals/Series0001/LockInAOUT01/AIN01');
   % for loading the fluo data 
   SignalFluo = h5read(fibFileName ,'/DataAcquisition/FPConsole/Signals/Series0001/LockInAOUT02/AIN01');
   % for loading the acquisition times
   Times = h5read(fibFileName ,'/DataAcquisition/FPConsole/Signals/Series0001/LockInAOUT01/Time');

   Window = 100;

   SignalIso =  filtfilt(ones(Window,1)/Window,1, SignalIso);
   SignalFluo =  filtfilt(ones(Window,1)/Window,1, SignalFluo); 

   [cof,S,mu]  = polyfit(SignalIso,SignalFluo,2); 
   fitIso = polyval(cof,(SignalIso-mu(1))./mu(2)); 

   dffValues = 100*((SignalFluo - fitIso)./fitIso);  
   dffTimes = Times + TimeToAdd;

   dff = [dffTimes';dffValues'];


elseif DoricMousePos == 2

   fibFileName = fullfile(str_pathFib,str_NameFib);


   % for loading the isosbestic data 
   SignalIso = h5read(fibFileName ,'/DataAcquisition/FPConsole/Signals/Series0001/LockInAOUT03/AIN02');
   % for loading the fluo data 
   SignalFluo = h5read(fibFileName ,'/DataAcquisition/FPConsole/Signals/Series0001/LockInAOUT04/AIN02');

   % for loading the acquisition times
   Times = h5read(fibFileName ,'/DataAcquisition/FPConsole/Signals/Series0001/LockInAOUT03/Time');

   Window = 100;

   SignalIso =  filtfilt(ones(Window,1)/Window,1, SignalIso);
   SignalFluo =  filtfilt(ones(Window,1)/Window,1, SignalFluo); 

   [cof,S,mu]  = polyfit(SignalIso,SignalFluo,2); 
   fitIso = polyval(cof,(SignalIso-mu(1))./mu(2)); 

   dffValues = 100*((SignalFluo - fitIso)./fitIso);  
   dffTimes = Times+TimeToAdd;

   Window = 100;

   dff = [dffTimes';dffValues'];


end

%traceName={'EEG_f','EEG_p','EMG_1','EMG_2','S1_R','Ref','dffLC'};
traceName={'EEG_f','EEG_p','EMG_1','EMG_2','S1','Hip','mPFC','dffLC','DoricTrigger'};
fEphys.dff = dff;
fEphys.traceName = traceName;

% waitbar(.5, w, 'Reassigning names and stuff');
% names = fieldnames(fEphys);
% assi(fEphys,names)
% 
% names{end+1} = 'traceName';
% names{end+2} = 'dff';
% 
% waitbar(.7, w, 'Resaving all at once');
% save([str_path,str_Name], names{:}, '-v7.3')
% waitbar(1, w, 'Top cool');
% close(w)
% 
msgbox('File is done!')
% 
% end
% 
% 
% function assi(f,names)
% 
% for i = 1:numel(names)
%     assignin('caller', names{i}, f.(names{i}))
% end

end