function [h, p, ci, stats] = linesConnect(x,y,c,testType)
%LINESCONNECT To create lines to connects points in a scatter when the
%points are paired (from same animal for example)

% x is the position of the two groups 1x2 matrix
% y is a matrix of the position in y of the points per group
if nargin == 3
    testType = 'ttest';
end

for i = 1:length(y)
    line(x,y(i,:),'color',c)
end
if strcmp(testType, 'ttest')
    [h,p,ci,stats] = ttest(y(:,1),y(:,2));
    Y = max(y(:)) + nanstd(y(:))/3;
    text(mean(x), Y, sprintf(['t: ', num2str(stats.tstat,4),'\np: ',num2str(p,4)]),'HorizontalAlignment','center','color',c)
elseif strcmp(testType, 'signRank')
    [p,h] = signrank(y(:,1),y(:,2));
    Y = max(y(:)) + nanstd(y(:))/3;
    text(mean(x), Y, sprintf(['p: ',num2str(p,4)]),'HorizontalAlignment','center','color',c)
else
    error('test type not recognized')
end

tickout

end

