function [h] = plotMultiLabelLines(x,y,labels)
%PLOTMULTILABELLINES This function plots all the l lines in the y matrix
%l x c and gives them a hover function that shows the associated label

h = cell(size(y,1));
axes
for i = 1:size(y,1)
    h{i} = line(x,y(i,:), 'ButtonDownFcn', @giveLabel, 'UserData', i);
end

    function giveLabel(obj,~)
        lgd = legend(labels{obj.UserData});
        title(lgd,'Selected line')
        for j = 1:length(h)
            h{j}.LineWidth = 1;
            h{j}.Color = [0 0.4470 0.7410];
        end
        obj.Color = [0.8500 0.3250 0.0980];
        obj.LineWidth = 2;
    end

end

