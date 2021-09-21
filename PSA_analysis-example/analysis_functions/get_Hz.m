function [ Hz ] = get_Hz(Fs, sec)
%GET_HZ to get Hz xaxis for ffts
% Fs is sampling rate
% sec is window length in second

ny = Fs/2; % Nyquist limit is half the resolution
Hz = linspace(0,1,((Fs*sec)/2)+1)*ny;
        
end

