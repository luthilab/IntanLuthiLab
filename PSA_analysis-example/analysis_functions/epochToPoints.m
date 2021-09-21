function [points] = epochToPoints(idx_epoch, sec, fs)
%EPOCHTOPOINTS To change one or more epoch coming from a scoring into
%points matching a sampling rate to extract corresponding sequence of a
%trace.
% idx_epoch : index of epoch or epochs (in b) required to extract in the trace
% sec : the time in second of 1 epoch
% fs : the sampling rate of the trace

if sum(idx_epoch <= 0) ~= 0
    error('Epochs can not be negative.')
end

points = zeros(fs*sec, length(idx_epoch));

for i = 1:length(idx_epoch)
    points(:,i) = (idx_epoch(i)*sec*fs)-(fs*sec)+1:idx_epoch(i)*fs*sec;
end

end

