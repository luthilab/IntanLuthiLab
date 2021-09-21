function [hyp] = bToHyp(b,art)
%BTOHYP Summary of this function goes here
%   Detailed explanation goes here

if nargin == 2
    if art == 1
        hyp = zeros(1,length(b));
        hyp(b=='w') = 3;
        hyp(b=='1') = 3.1;
        hyp(b=='n') = 2;
        hyp(b=='2') = 2.1;
        hyp(b=='r') = 1;
        hyp(b=='3') = 1.1;
        hyp(b=='m') = 2.5;
        hyp(b=='f') = 2.3;
    else
        hyp = zeros(1,length(b));
        hyp(b=='w'|b=='1') = 3;
        hyp(b=='n'|b=='2') = 2;
        hyp(b=='r'|b=='3') = 1;
        hyp(b=='m') = 2.5;
        hyp(b=='f') = 2.3;
    end
else
    hyp = zeros(1,length(b));
    hyp(b=='w'|b=='1') = 3;
    hyp(b=='n'|b=='2') = 2;
    hyp(b=='r'|b=='3') = 1;
    hyp(b=='m') = 2.5;
    hyp(b=='f') = 2.3;
end

end

