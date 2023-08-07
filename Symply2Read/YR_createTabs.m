function [h] = YR_createTabs(h,c)
%YR_createTabs This function creates as many tabs as the connected chips
%   After established connection with the intan RHD2000 board, h.chipID
%   contains the number of detected chips (headstages) plugged. This
%   function creates different tabs for displaying the data from each chip
%   once a specific tab is selected.
%
%   See XXX for updating graphs in each tab

h.tabgpTraces = uitabgroup(h.mainFig, 'Position', [.23 .02 .75 .96]);

for i = 1:h.chipID
    h.tabAnimal(i) = uitab(h.tabgpTraces,'Title',['Animal #', num2str(i)],'backgroundcolor', c.background);
end

end

