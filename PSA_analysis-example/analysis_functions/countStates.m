function [res] = countStates(b)
%COUNTSTATES To count the number of wake, nrem, rem.
% Input:
% b: is a classic b string of states obtain with VeryScore.
%
% Output:
% res: is a structure containing 
% 'states' 1x4 matrix with (in seconds):
% [total wake time, total nrem time, total rem time, number of scored
% Microarousals (m)].
% 'so': Sleep onset in seconds.
% 'waso': wake after sleep onset in seconds.
% 'nma': number of detected MA (old way detection with wake epoch).

b(b=='1') = 'w';
b(b=='2') = 'n';
b(b=='3') = 'r';

res.wake = length(b(b=='w'))*4;
res.nrem = length(b(b=='n'))*4;
res.rem = length(b(b=='r'))*4;
res.ma = length(findBouts(b,'m',1));

so = strfind(b,'nnnnnn');
if ~isempty(so)
    res.so = so(1)*4;
    bso = b(so(1):end);
    res.waso = length(bso(bso=='w'));
else
    res.so = NaN;
    res.waso = NaN;
end

nma = [strfind(b,'nnnnnwnnn'),strfind(b,'nnnnnwwnnn'),strfind(b,'nnnnnwwwnnn')];%;strfind(b,'nnnnnwwwwnnn')];
res.nma = length(nma);

end