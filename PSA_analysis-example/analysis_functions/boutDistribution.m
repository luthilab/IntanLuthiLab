function boutDist = boutDistribution(b, MA_is_wake)
% To detect Wake NREM and REM bouts and their duration in second.
% Be aware that the first and last bout of the scoring will not be counted
% as we don't know their real duration.
%
% Advice to plot: 
% use the cdfplot function from matlab.
% AL update-Dec2021: This is an example file for which the proper use of the regexp function needs to be verified.
% Romain Cardis 2021


if nargin==1
    MA_is_wake = true;
end

if MA_is_wake
    b(b=='m') = 'w';
else
    b(b=='m') = 'n';
end

b(b=='1') = 'w';
b(b=='2') = 'n';
b(b=='3') = 'r';

w_bouts = (regexp(b,'[^w]w+[^w]','end')-1) - (regexp(b,'[^w]w+[^w]','start')+1);
n_bouts = (regexp(b,'[^n]n+[^n]','end')-1) - (regexp(b,'[^n]n+[^n]','start')+1);
r_bouts = (regexp(b,'[^r]r+[^r]','end')-1) - (regexp(b,'[^r]r+[^r]','start')+1);

boutDist = struct();
boutDist.nBouts = n_bouts*4;
boutDist.wBouts = w_bouts*4;
boutDist.rBouts = r_bouts*4;

end

