function [ chunks ] = ExtractSleepChunks(b, show)
%EXTRACTSLEEPCHUNKS This function separates the best it can the sleep
%chunks from a scored b behavioral state vector (hypnogram). If you precise
%show as 1 it plot the separation nicely.

if nargin == 1
    show = 0;
end

b(b=='1') = 'w';
b(b=='2') = 'n';
b(b=='3') = 'r';

% remove short NREMS bout
shortN = [regexp(b, '[^n]n{1,5}[^n]','start'); regexp(b, '[^n]n{1,5}[^n]','end')];
for i = 1:size(shortN,2)
    b(shortN(1,i):shortN(2,i)) = 'w';
end

longW = findBouts(b,'w',20); %105

%longW = wakeBouts;
if show == 1
    hyp = zeros(1,length(b));
    hyp(b=='w') = 3;
    hyp(b=='n'|b=='2') = 2;
    hyp(b=='r'|b=='3') = 1;
    figure
    plot(hyp)
    ylim([-1,5])
    for i = 1:length(longW)-1
        line([longW(2,i),longW(1,i+1)], [3.2,3.2], 'linewidth',6)
    end
end

chunks = [longW(2,1:end-1);longW(1,2:end)];

end

