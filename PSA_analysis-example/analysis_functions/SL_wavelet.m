function [masterWavelet, v_time, v_freq] = SL_wavelet(toTreat,v_freq,Fr)
%v_freq = 0.1:0.1:25;

v_time = 1/Fr:1/Fr:length(toTreat)/Fr;

v_length = length(v_time);
sig = toTreat;

v_halflen = floor(v_length / 2) + 1;

cycles = 4;

v_sigFFT      = fft(sig, numel(sig));
v_WAxis = (2.* pi./ v_length).* (0:(v_length - 1));
v_WAxis = v_WAxis.* Fr;
v_WAxisHalf = v_WAxis(1:v_halflen);

m_Transform    = zeros(numel(v_freq), numel(v_time));



for iter    = 1:length(v_freq)
    s_ActFrq=v_freq(iter);
    dtseg      = cycles * (1 /s_ActFrq);
    v_WinFFT = zeros(v_length, 1);
    v_WinFFT(1:v_halflen) = exp(-0.5.* ...
        realpow(v_WAxisHalf - (2.* pi.* s_ActFrq), 2).* ...
        realpow(dtseg,2));
    v_WinFFT = v_WinFFT.* sqrt(v_length)./ norm(v_WinFFT, 2);
    m_Transform(iter,:) = ifft(v_sigFFT.* v_WinFFT')./ ...
        sqrt(dtseg);
end

masterWavelet = abs(m_Transform);

% sigpow = mean(masterWavelet(101:150,:),1); %10-15 Hz
% swa = mean(masterWavelet(10:40,:),1);%1-4


%        figure();
%         imagesc(v_time , v_freq , abs(m_Transform(:,2*Fr:end-2*Fr)));
%         set(gca,'ydir','normal','xlim',[v_time(1) v_time(end)])
%         xlabel('Time (s)')
%         ylabel('Freq (Hz)')

        
        
end