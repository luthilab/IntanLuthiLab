function [ h ] = plot_95CI(x, data, color, varargin)
%Romain Cardis 2018

%PLOT_95CI plot the data matrix with individuals as row (ideal for time
%courses or fft plots) it plots the line with the 95 CI as a shaded area

% 'x' is the x axis values for the line to plot
% 'data' is the data matrix with individuals as row and columns of same
% number of columns as x.

fishy

p = inputParser;
addParameter(p, 'style', '-', @ischar);
addParameter(p, 'faceAlpha', 1, @isnumeric);
addParameter(p, 'edgeAlpha', 1, @isnumeric);
parse(p, varargin{:})

style = p.Results.style;
facealpha = p.Results.faceAlpha;
edgealpha = p.Results.edgeAlpha;

h = plot(x, nanmean(data,1),style,'color',color);
X = [x,fliplr(x)];
ci = CI95(data,1);
Y = [ci(1,:), fliplr(ci(2,:))];
if strcmp(style, '-')
    patch(X,Y,color,'faceAlpha',facealpha,'edgeAlpha',edgealpha)
else
    for i = 1:length(ci)
        line([x(i), x(i)], [ci(1,i), ci(2,i)], 'color', color)
    end
end

box off
set(gca, 'tickdir', 'out')

end

