function [traces] = loadCorrectTraces(mfile, order)
%ORDERCHANNELS is a short function that takes the string of channel names
%and give back a colum of indexes to have the channels in order as precised
%by 'order'.

Info = mfile.Infos;
channels = Info.Channel;

channels(channels==' ') = [];
cha = strsplit(channels, ',');

traceIndex = zeros(length(order),1);
toad = NaN;
for i = 1:length(order)
    cpo = find(ismember(cha,order{i}));
    if length(cpo) > 1
        warning(['There is two channel with the name ', order{i}, ', the second will be added at the end!'])
        toad = cpo(2);
    end
    traceIndex(i) = cpo(1);
end

if ~isnan(toad)
    traceIndex = [traceIndex; toad];
end

traces = mfile.traces(min(traceIndex):max(traceIndex),:); % load the minimum number of traces in one shot
%cha = cha(min(traceIndex):max(traceIndex),:);
traceIndex = traceIndex-min(traceIndex)+1; % adjust the indexes for the traces
traces = traces(traceIndex,:); % Order the traces correctly
%cha = cha(traceIndex,:); % just to check that it's correct.

end

