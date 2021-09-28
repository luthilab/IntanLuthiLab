function proba = transitionProbability(b, MA_is_wake)
%TRANSITIONPROBABILITY Gets the transition probability for each stage to
%itself or other in a matrix of 1,2,3 x 1,2,3 (w,n,r),
% Output: probability matrix of the probability of rows transitioning in
% the columns. Meaning (1,1) is the probability of w > w, (1,2) is w > n
% and (1,3) is w > r. etc...
%
% Romain Cardis 2020


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

proba = zeros(3,3);

% Terrible way, but it works.
proba(1,1) = length(strfind(b,'ww'));
proba(1,2) = length(strfind(b,'wn'));
proba(1,3) = length(strfind(b,'wr'));

proba(2,1) = length(strfind(b,'nw'));
proba(2,2) = length(strfind(b,'nn'));
proba(2,3) = length(strfind(b,'nr'));

proba(3,1) = length(strfind(b,'rw'));
proba(3,2) = length(strfind(b,'rn'));
proba(3,3) = length(strfind(b,'rr'));

proba = proba./sum(proba,2);

end

