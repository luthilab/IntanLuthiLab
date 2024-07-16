function Scoring_test
% To test the accuracy of the scoring. Need to run the Ypnos_convertToB
% first to get the bY.

[names, path] = uigetfile('*.mat','Select your files to convert the states in b.','multiselect','on');

if ~iscell(names)
    names = {names};
end


for i = 1:length(names)
    figure('name',names{i})
    cur = matfile([path,names{i}],'Writable',true);
    b = cur.b;
    bY = cur.bY;
    b(b=='1') = 'w';
    b(b=='2') = 'n';
    b(b=='3') = 'r';
    acc = 0;
    w = 0;
    n = 0;
    r = 0;
    for j = 1:length(b)  
        if b(j) == bY(j)
            acc = acc+1;
        end
        
        switch b(j)
            case 'n'
                if bY(j) == 'n'
                    n = n+1;
                end
            case 'w'
                if bY(j) == 'w'
                    w = w+1;
                end
            case 'r'
                if bY(j) == 'r'
                    r = r+1;
                end
        end
    end
    accu = acc/length(b)*100;
    disp([names{i}, ' has an accuracy of ', num2str(accu), ' %'])
    nrem = n/length(b(b=='n'))*100;
    rem = r/length(b(b=='r'))*100;
    wake = w/length(b(b=='w'))*100;
    disp(['Wake accuracy: ', num2str(wake), ' %'])
    disp(['NREMS accuracy: ', num2str(nrem), ' %'])
    disp(['REMS accuracy: ', num2str(rem), ' %'])
    
    b = bToHyp(b);
    bY = bToHyp(bY);
    t = cur.traces;
    st = cur.states(1,:);
    
    tim = linspace(0,length(t)/200,length(t));
    reduce_plot(tim,t(1,:));
    hold on
    reduce_plot(tim, t(2,:)-0.003);
    yyaxis right
    tim2 = linspace(0,length(t)/200,length(b));
    plot(tim2,b)
    hold on
    tim3 = linspace(0,length(t)/200,length(st));
    plot(tim3,-st)
    ylim([-10,10])
    %delete(gca)
    
end

end

