function Ypnos_ConvertToB
%YPNOS_CONVERTTOB is used to treat a Ypnos file and add a b based on the
%direct online scoring. Then you can open it in VeryScore for example.
% Romain Cardis 2017

[names, path] = uigetfile('*.mat','Select your files to convert the states in b.','multiselect','on');

if iscell(names)
    nfile = length(names);
else
    nfile = 1;
    names = {names};
end

for i = 1:nfile
    cur = matfile([path,names{i}],'Writable',true);
    states = cur.states(1,:);
    b = repmat('w',1,floor(length(states)/4));
    for j = 1:length(states)/4
        epoch = states(((j-1)*4)+1:j*4);
        s = mode(epoch);        
        switch s
            case 1
                b(j) = 'w';
            case 2
                b(j) = 'n';
            case 3
                b(j) = 'r';
        end
    end
    cur.bY = b;
    myplot(cur,states)
end 

end

function myplot(cur, states)

traces = cur.traces;
x = linspace(0,length(traces)/1000,length(traces));
x2 = linspace(0,length(traces)/1000,length(states));
figure
reduce_plot(x,traces(1,:));
hold on
reduce_plot(x,traces(2,:)-0.001);
reduce_plot(x2,states(1,:)/1000);

end