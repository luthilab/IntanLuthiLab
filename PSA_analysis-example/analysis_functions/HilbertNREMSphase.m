function [phase] = HilbertNREMSphase(signal, b, plo)
%HIBLERTNREMSPHASE To obtain the hilbert phase of a signal, likely sigma
%power fluctuation centered around NREMS values. The trough have value of
%180°. The sampling rate of signal must be 10 Hz.

% You obtain "signal" from the Infra_OneBoutExtract() function

if nargin==2
    plo = 0;
end

bs = b;
bs(strfind(bs, 'nnnnnwwwwnnn')+5) = 'n';
bs(strfind(bs, 'nnnnnwwwnnn')+5) = 'n';
bs(strfind(bs, 'nnnnnwwnnn')+5) = 'n';
bs(strfind(bs, 'nnnnnwnnn')+5) = 'n';
nrem = [strfind(bs,'n'),strfind(bs,'m')];
nrem = epochToPoints(nrem, 4, 10);
signal = signal-mean(signal(nrem(:)));
hilSig = hilbert(signal);
phasesig = (360*angle(hilSig))/(2*pi)+180; % lol
phase = wrapTo360(phasesig+180); % loler

if plo == 1
    figure
    x = linspace(0,length(signal)/10,length(signal));
    plot(x, signal)
    yyaxis right
    plot(x,phase)
    ylim([-300,660])
end
    

end

