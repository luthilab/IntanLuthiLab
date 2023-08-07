function [h] = YR_refreshDisp(h, board)
%YR_REFRESHDISP Is used to aquire a new datablock and refresh the display
%everytime the timer tic. Is uses the traces handles to refresh the
%correct number of lines.

%traceHandles contains the handles of the plots. Same for FFT
%board is the intan board
%chipID is a cell containing the two indice for each chip connected

%% get the data from the board

datablock = board.read_next_data_block();

if h.save
    switch h.typeOfFile
        case '.rhd'
            datablock.save();
        case '.mat'
            
            for i = 1:h.chipID
                an = sum(cellfun('isempty',(h.traceIndex)));%how many analog channels
                if an>0
                    tempIndex = h.traceIndex(1:end-an);
                    toAdd = datablock.Chips{h.chipIndex(i)}.Amplifiers(cell2mat(tempIndex),:);
                    
                    for anIdx = 1:an
                        toAddstim = datablock.Board.get_one_adc(anIdx-1);
                        toAdd = [toAdd;toAddstim];
                    end
                    
                    h.matFile{i}.traces(:,h.si1:h.si1+59) = toAdd;
                else
                    
                    toAdd = datablock.Chips{h.chipIndex(i)}.Amplifiers(cell2mat(h.traceIndex),:);
                    
                    h.matFile{i}.traces(:,h.si1:h.si1+59) = toAdd;
                end
            end
            h.si1 = h.si1 + 60;
    end
end

%% Manipulate the x axis of the mainplot
X = double(datablock.Timestamps)/h.samplingRate;
x = linspace(X(1), X(end), 12);

tabnb = str2num(h.tabgpTraces.SelectedTab.Title(9));

if h.refCount == 0
    h.mainPlot(tabnb).XLim = [x(end)-20, x(end)];
end

%% refresh the lines

% tabnb = str2num(h.tabgpTraces.SelectedTab.Title(9));

for c = 1:h.chipID
    anCh = 0;
    for i = 1:h.nb
        tIn = h.traceIndex{i};
        if isempty(tIn)
            ne = datablock.Board.ADCs;%./10;
            newB = ne(anCh+1,:);
            %newB = datablock.Board.get_one_adc(anCh);
            anCh = anCh +1;
        else
            if length(tIn) == 2
                newB = datablock.Chips{h.chipIndex(c)}.Amplifiers(tIn(1),:) - datablock.Chips{h.chipIndex(c)}.Amplifiers(tIn(2),:);
            else
                newB = datablock.Chips{h.chipIndex(c)}.Amplifiers(tIn,:);
            end
        end
        intB = (interp1(X, newB, x));
        h.(char(['trace_animal', num2str(c)])){i,3} = cat(2, h.(char(['trace_animal', num2str(c)])){i,3}(13:end), intB);
        
        if h.notch
            h.(char(['trace_animal', num2str(c)])){i,3} = filter(h.b, h.a,h.(char(['trace_animal', num2str(c)])){i,3});
        end
        if h.refCount == 0 && c == tabnb
            set(h.(char(['trace_animal', num2str(c)])){i,1},...
                'YData', h.(char(['trace_animal', num2str(c)])){i,3}*h.(char(['trace_animal', num2str(c)])){i,2}+h.nb-i+1,...
                'XData', linspace(x(end)-20,x(end),4000));
            h.fifo.String = [num2str(board.FIFOLag),' / ', num2str(board.FIFOPercentageFull)];
            %drawnow limitrate nocallbacks
        end
        
        
    end
end

%% refresh the fft

        if h.refCount == 0
            epoch = h.(char(['trace_animal', num2str(tabnb)])){h.selected,3}(end-799:end);
            lafft = abs(fft(epoch-mean(epoch)));
            h.fftLine.YData = smooth(lafft(1:401));
            h.refCount = 3;
            %drawnow;
        end

h.refCount = h.refCount - 1;

% Apply change to figure
%drawnow;

end

