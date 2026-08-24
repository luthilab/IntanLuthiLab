function [tempCelsius] = f_cortical_temperature(temp_raw,animalID)
%% To have cortical temperature in °C with the trace downsampled to 10Hz using beta value of thermistors
% OUTPUT : tempCelsius
% plot hypnogram + cortical temp for 1 recording

% animalID = 'TempCVS1';
% [b,t] = cut_Traces(b,traces,11,Infos);
% temp_raw = t(7,:);

%% Thermistors
p = load('F:\aluthi1\fbm_move\D2c\_PROJECTS\PROJECT_Najma\CorticalTemperature\Matlab_temperature\PSA_thermistors.mat');
PSA = p.PSA;
switch char(regexp(animalID,'\d{2}','match'))
    case '1'
        thermistor = 'BSC30';
    case '2'
        thermistor = 'CSC30';
    case '3'
        thermistor = 'DSC30';
    case '4'
        thermistor = 'ESC30';
    case '5'
        thermistor = 'JSC30';
    case '7'
        thermistor = 'LSC30';
    case '9'
        thermistor = 'MSC30';
    case '10'
        thermistor = 'USC30';
    case '11'
        thermistor = 'VSC30';
    case '13'
        thermistor = 'XSC30';
end
beta = PSA.(char(thermistor)).beta;
U25 = PSA.(char(thermistor)).U25; 

%% Convert Voltage to Deg Celsius 
% Intensity of current delivered by current box in Amp
% I = 100uA
I = 100e-6; 
% Resistance of thermistor in Ohm
R25 = U25 / I; 
% Temperature in °Kelvin (°C + 273.15)
temp25 = 25 + 273.15;
% temperature is the traces (*1000 because matlab put in mV)
Utemp = temp_raw*1000;

Rtemp = Utemp / I;
tempCelsius = zeros(1,length(Rtemp));
for index = 1:length(Rtemp)
    tempCelsius(index) = (((1 / beta) * log(Rtemp(index) / R25) + (1/temp25))^-1) - 273.15 ;
end

tempCelsius = resample(tempCelsius,10,1000); %sample to 10Hz

%to remove artefacts
tempCelsius = filloutliers(tempCelsius,"nearest","movmedian",1000);

end
