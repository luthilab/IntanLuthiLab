function [P] = powerSpectrum(b, trace, Fs, type)
%EXACT_POWERSPECTRUM To calculate power spectral density across three
%states and the mean value to normalize on, which is the mean of NREMS, REMS and wake together (same weight per state).
% as in Vassali and Franken 2017

wtri = strfind(b, 'www')+1;
ntri = strfind(b, 'nnn')+1;
rtri = strfind(b, 'rrr')+1;

wfft = extract(wtri, trace, Fs);
nfft = extract(ntri, trace, Fs);
rfft = extract(rtri, trace, Fs);

% Calculate the value used to normalize the three states
Hz = Get_Hz(Fs,4);
lim = find(Hz==0.75):find(Hz==47); % from 0.75 to 47 Hz

P = struct();

if nargin == 3
    type = 'mean';
end

if strcmp(type, 'median')
    w = median(mean(wfft(:,lim),2));
    n = median(mean(nfft(:,lim),2));
    r = median(mean(rfft(:,lim),2));
    P.NORVAL = mean([w,n,r]);
    P.wFFT = median(wfft,1);
    P.nFFT = median(nfft,1);
    P.rFFT = median(rfft,1);
else
    w = mean(mean(wfft(:,lim),2));
    n = mean(mean(nfft(:,lim),2));
    r = mean(mean(rfft(:,lim),2));
    P.NORVAL = mean([w,n,r]);
    P.wFFT = mean(wfft,1);
    P.nFFT = mean(nfft,1);
    P.rFFT = mean(rfft,1);
end

end

function sfft = extract(tri,eeg, Fs)

[a,b] = cheby2(7, 40, 0.5/100,'high');
eeg = filtfilt(a,b, eeg);

sfft = zeros(length(tri), Fs*2+1);
k = 1;
for i = tri
    epoch = eeg((i*Fs*4)-(Fs*4-1):i*Fs*4);
    lafft = abs(fft(epoch-mean(epoch)));
    lafft = lafft./((Fs*4)/2);
    sfft(k,:) = lafft(1:end/2+1).^2;
    k = k+1;
end

end