function [m_Transform,v_freq] = f_MGT(v_Signal,s_Fr,minf,maxf,resf);
% This function calculates the wavelet transform of a signal of interest
% using a Gabor-Morlet kernel.
%
% Sintaxis:
%           f_MyGT(Y,Fr,minf,maxf,resf,b_2Draw)
% Inputs:
%           v_Signal: Signal to transform.
%           s_Fr: Sample frequency
%           minf: min transform frequency. Default 10
%           maxf: max transform frequency. Default 15
%           resf: frequency resolution. Default 0.1
%
% Outputs:
%           m_Transform: Matrix containing the complex wavelet transform of
%           the signal between the designed frequencies. In order to get
%           the amplitude information use abs(m_Transform) and to get the
%           phase information use angle(m_Transform)
%
%           v_freq: vector containing the frequency information in
%           m_Transform.
%
% See also f_FFTPowAsLab, f_GeneralDynamics, f_PhaseAnalysis, f_SpindleDetection
%
% Alejandro Osorio-Forero 2019
    
    %% Initialization
    if nargin<4 || isempty(resf)
        resf     = 0.1;
    end
    if nargin<3 || isempty(maxf) || isempty(minf)
        maxf     = 15;
        minf     = 10;
    end
    
    % In case of empty, this part of the function just test the GT
    if nargin<2
%         close all
        clear all
        clc

        minf        = 1;
        maxf        = 20;
        resf        = 0.25;

        % Test Alpha for a drowsy human
%         d_drow = load('drowsy.mat');
%         s_Fr          = d_drow.s_SRate;    
%         v_Signal	= d_drow.v_EEGData(s_Fr*20:s_Fr*100);   

        % Test mouse in NR sleep
%         d_file = matfile('MouseS1inNR.mat');
%         s_Fr     = 200;    
%         v_Signal = d_file.v_Signal;
%         v_Signal = resample(v_Signal(1:end-1),200,d_file.s_Fs);

% %         % Test Two signals
        s_Fr     = 100;    
        v_t=linspace(0,10,1000);
        v_Signal = 10*cos (4*2*pi*v_t)+20*cos(10*2*pi*v_t); % sinusoidal of 10 amplitude and 4 hz and anotherone with 20 amplitude and 10 Hz 

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    end % DO NOT COMMENT THIS END
    
   % This is to put the signal as a column vector instead of a row vector 
   if size(v_Signal,1)<size(v_Signal,2)
       v_Signal=v_Signal';
   end

    cycles      = 4;

    v_freq      = minf : resf : maxf;
    s_Len       = length(v_Signal);
    s_HalfLen   = floor(s_Len / 2) + 1;
    

    % In case of drawing 
    v_YFFT      = fft(v_Signal, numel(v_Signal));
    
    v_WAxis = (2.* pi./ s_Len).* (0:(s_Len - 1));   % Vector with length of signal normalized to 2Pi
    v_WAxis = v_WAxis.* s_Fr;
    v_WAxisHalf = v_WAxis(1:s_HalfLen);             % first half of the signal, until Pi*sampling rate
    m_Transform    = zeros(numel(v_freq), length(v_Signal));% Initial matrix
    
    for iter    = 1:length(v_freq);

        s_ActFrq = v_freq(iter); % Current Frequency

        dtseg      = cycles * (1 /s_ActFrq); % Size of the gaussian window (pretty much the standard deviation of the gaussian)
        
        v_WinFFT = zeros(s_Len, 1);

        % Transform with normalizations
        v_WinFFT(1:s_HalfLen) = 2*exp(-0.5.* realpow(v_WAxisHalf - (2.* pi.* s_ActFrq), 2).*realpow(dtseg,2));        
        v_WinFFT = v_WinFFT.* sqrt(s_Len)./ norm(v_WinFFT, 2); % Normalization L2
%         % Normalization for unitary energy
        m_Transform(iter,:) = ifft(v_YFFT.* v_WinFFT)./ sqrt(dtseg);

        % No normalization
%           v_WinFFT(1:s_HalfLen) = 2*exp(-0.5.* realpow(v_WAxisHalf - (2.* pi.* s_ActFrq), 2).*realpow(dtseg,2));
%           m_Transform(iter,:) = ifft(v_YFFT.*v_WinFFT);
    end

    if nargin<2
        figure('color','w');
        h(1)=subplot(2,3,4:5);
        imagesc([1:s_Len]/s_Fr,v_freq,abs(m_Transform(:,:)));
        xlabel('Time (s)')
        ylabel('Freq (Hz)')
        h(2)=subplot(2,3,1:2);
        plot([1:s_Len]/s_Fr,v_Signal)
        xlabel('Time (s)')
        linkaxes(h,'x')
        set(h,'box','off','tickdir','out','xlim',[1,s_Len]/s_Fr,'ydir','normal');
        g(1) = subplot(2,3,6);
        plot(v_freq,mean(abs(m_Transform(:,:))'))
        set(g,'box','off','tickdir','out');
    end
end