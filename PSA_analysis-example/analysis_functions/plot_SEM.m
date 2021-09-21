function [ h ] = plot_SEM(x, data, color, varargin)
%Romain Cardis 2018

%PLOT_SEM plot the data matrix with individuals as row (ideal for time
%courses or fft plots) it plots the line with the SEM as a shaded area :(

% 'x' is the x axis values for the line to plot
% 'data' is the data matrix with individuals as row and columns of same
% number of columns as x.

fishy

p = inputParser;
addParameter(p, 'style', '-', @ischar);
addParameter(p, 'faceAlpha', 1, @isnumeric);
addParameter(p, 'edgeAlpha', 1, @isnumeric);
addParameter(p, 'ignoreNaN', 1, @isnumeric);
parse(p, varargin{:})

style = p.Results.style;
facealpha = p.Results.faceAlpha;
edgealpha = p.Results.edgeAlpha;
ignoreNaN = p.Results.ignoreNaN;

X = [x,fliplr(x)];
if ignoreNaN == 0
    sem = std(data,1)./sqrt(length(data(~isnan(data(:,1)),1)));
    mda = mean(data,1);
else
    sem = nanstd(data,1)./sqrt(length(data(~isnan(data(:,1)),1)));
    mda = nanmean(data,1);
end

h = plot(x, mda, style, 'color', color);

Y = [mda-sem, fliplr(mda+sem)];
if strcmp(style, '-')
    patch(X,Y,color,'faceAlpha',facealpha,'edgeAlpha',edgealpha)
else
    for i = 1:length(sem)
        line([x(i), x(i)], [mda(i)-sem(i), mda(i)+sem(i)], 'color', color)
    end
end

box off
set(gca, 'tickdir', 'out')

end

