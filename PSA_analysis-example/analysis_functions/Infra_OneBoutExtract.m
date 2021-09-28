function [infra] = Infra_OneBoutExtract(sig, freq, Fs, filt)
%INFRA_ONEBOUTEXTRACT is used to extract the infraslow signal from a given
%signal. The infra is given in a 10Hz resolution.

% Input:
% sig -> original signal
% freq -> the boundary frequency in Hz from wich to extract
% sr -> sampling rate of the original signal

% Output :
% infra -> the 10Hz infraslow signal
%
% Romain Cardis 2020


v_freq = freq(1):.5:freq(2);
[wav] = SL_wavelet(sig, v_freq, Fs);
infra = mean(wav,1);
infra = decimate(infra, Fs/10);

if nargin == 4
    bhi = fir1(100, 0.025/10,'low');
    if filt == 1
        infra = filtfilt(bhi,1,infra);
    end
end

end

