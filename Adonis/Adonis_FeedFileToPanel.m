function detection = Adonis_FeedFileToPanel(tra)
%ADONIS_FEEDFILETOPANEL is used to simulate a file being recorded and feed
%it to the ADONIS panel class to treat and do testings.

close all

% Choose a fitting file with a "traces" variable if not given
if nargin == 0
    [fil,pat] = uigetfile('*.mat','Select your file to feed to ADONIS');
    m = matfile([pat,fil]);
    traces = m.traces(1:2,:);
else
    traces = tra(1:2,:);
end


% Initiate fake ADONIS
h = struct();
h = Adonis_mainFig(h);
% h.panels = Adonis_Panel_NeuralNet(h.mainFig, 0.67, 1);
h.panels = Adonis_PanelThreshold(h.mainFig, 0.67, 1);
% h.panels = Adonis_PanelThreshold_Cont(h.mainFig, 0.67, 1);

% h.panels = Adonis_Panel_simple(h.mainFig, 0.67, 1);
states = zeros(7,ceil(length(traces)/1000));
% states = zeros(9,ceil(length(traces)/1000));
ti = 1000:1000:length(traces);
%realstate = m.states(4,:);

% Actual test like if it was intan giving the data
k = 1;
for i = 1:length(traces)/60
    toAdd = traces(:,(i-1)*60+1:i*60);
    h.panels.update(toAdd)
    if k <= length(ti)
        if i*60 > ti(k) % every second.. ish
            st = h.panels.checkState;
            states(:,k) = [st; i*60];
            drawnow
            pause(.05)
            k = k+1;
        end
    end
end

detection = struct;
detection.st = states(4,:);
detection.if = states(6,:);

% ST = states(4,:);
% [cont,frag] = deal(NaN(size(ST)));
% cont(ST==1) = 1;
% frag(ST==2) = 1;
% figure
% plot(cont, 'LineWidth', 3, 'color', 'blue', 'LineStyle', '-')
% hold on
% plot(frag, 'LineWidth', 3,'color', 'red', 'LineStyle', '-')
% yyaxis right
% plot(states(6,:))
% 
% % figure
% % plot(ST)
% % hold on
% % plot(realstate)
% 
% figure
% 
% IF = states(5,:);
% IFs = states(6,:);
% plot(IF); hold on; plot(IFs); plot(states(7,:))
% 
% x = 1:length(ST);
% y = ones(1,length(ST))+1;
% slo = states(8,:);
% plot(slo)
% line([0,length(slo)],[0,0])
% line([0,length(slo)],[1,1])
% 
% yyaxis right
% 
% scatter(x(ST==1),y(ST==1),100,'.','green')
% scatter(x(ST==2),y(ST==2),100,'.','red');
% plot(states(1,:))
% ylim([-20,20])
% 
% figure
% xt = linspace(1,length(ST),length(traces));
% reduce_plot(xt,traces(1,:));hold on
% reduce_plot(xt,traces(2,:)-0.007);
% yyaxis right
% plot(states(1,:))
% ylim([-20,20])

end

