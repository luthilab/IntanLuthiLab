function Ypnos_FeedFileToPanel
%YPNOS_FEEDFILETOPANEL Summary of this function goes here
%   Detailed explanation goes here

[fil,pat] = uigetfile('*.mat','Select your file to score');

m = matfile([pat,fil]);
orib = m.b;
orib = bToHyp(orib);

traces = m.traces(1:2,:);

transEMG = 0.1:0.01:0.5;
transEMGlow = [0.1:0.01:0.5]./2;
transNREM = 0.4:0.01:2;
transREM = [0.4:0.01:2]./2;


resu = zeros(5,6601);
r = 1;
w = waitbar(0,'wait until greatness');
for tr1 = 1:length(transEMG)
    em1 = transEMG(tr1);
    em2 = transEMGlow(tr1);
    
    for tri2 = 1:length(transNREM)
        waitbar(r/6601,w)
        % set parameters
        h = struct();
        h = Ypnos_mainFig(h);
        h.panels = Ypnos_Panel1000hz(h.mainFig, 0.67, 1);
        states = zeros(4,length(traces)/1000);
         
        h.panels.transEMG = em1;
        h.panels.transEMGlow = em2;
        r1 = transNREM(tri2);
        h.panels.transNREM = r1;
        r2 = transREM(tri2);
        h.panels.transREM = r2;
        ti = 1000:1000:length(traces);
        % actual test
        k = 1;
        for i = 1:length(traces)/60
            toAdd = traces(:,(i-1)*60+1:i*60);
            h.panels.update(toAdd)
            if i*60 > ti(k) % every second.. ish
                st = h.panels.checkState;
                states(:,k) = [st; i*60];
                k = k+1;
            end
        end
        
        accu = 0;
        for j = 1:length(states)/4
            epoch = states(1,((j-1)*4)+1:j*4);
            if ismember(1,epoch)
                if orib(j) == 1
                    accu = accu+1;
                end
            elseif ismember(3,epoch)
                if orib(j) == 3
                    accu = accu+1;
                end
            else
                if orib(j) == 2
                    accu = accu+1;
                end
            end
        end
        resu(:,r) = [accu/length(orib); r1; r2; em1; em2];
        r = r+1;
        save('Result_of_greatness.mat','resu');
        close all
    end
end

end

