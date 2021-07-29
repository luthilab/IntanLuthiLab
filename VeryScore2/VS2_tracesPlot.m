classdef VS2_tracesPlot < handle
    %UNTITLED Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        traces
        bstring
        bstate
        colstate
        oriTraces
        width % in epoch
        plotax
        fftax
        hypno
        position % in epoch
        second
        points
        time
        graphLines
        fftline
        hypnoline
        posiline
        posipatch
        selectedTraces
        space = 0.0006
        localhypno
        colors = [.8 .6 .2;.4 .6 .2;.8 .2 .2;.6 .4 .0;.2 .4 .0;.6 .0 .0;0 0.4470 0.7410; 0.8500, 0.3250, 0.0980; 0.4940, 0.1840, 0.5560];
        localhypnolines = cell(1,10);
        lockYlim = 0
        selectedFunction
        namax
        ChannelNames
        realTrans
        transObj
    end
    
    methods
        %% Initiation function:
        function self = VS2_tracesPlot(h,posi,wi)
            self.position = posi;
            self.width = wi;
            % Get the bstates to know the number of epochs
            self.initiateB(h.b);
            self.realTrans = NaN(2,length(self.bstate));
            % the positions in seconds for each epoch
            self.second = [linspace(0,(length(self.bstate)*4)-4,length(self.bstate)); linspace(4,length(self.bstate)*4,length(self.bstate))];
            
            self.traces = h.tra;
            self.oriTraces = h.tra;
            self.time = linspace(0, length(self.traces)/200, length(self.traces)); % the time vector for the traces
            
            % The positions in points for each epoch
            self.points = [1:800:length(self.bstate)*800; 800:800:length(self.bstate)*800];
            
            %% main plot initation
            self.plotax = axes('parent', h.mainFig,...
                'unit', 'normalized',...
                'position', [.05 .3 .9 .65],...
                'TickDir', 'out',...
                'xcolor','w',...
                'ycolor','w');
            
            self.graphLines = cell(size(self.traces,1),1); % will contain the lines objects in (:,1)
            self.selectedTraces = zeros(size(self.traces,1),1); % if the traces are selected or not
            for i = 1:size(self.traces,1)
                self.graphLines{i} = line(self.time(1:self.points(2,self.position+self.width)),...
                    self.traces(i,1:self.points(2,self.position+self.width))-self.space*i,...
                    'ButtonDownFcn', @selected,...
                    'UserData', [i,i]); % The userdata is used to identify the traces, (1) is the position (2) is the original trace index
            end
            
            % Function that select the traces
            function selected(~,~)
                li = gco;
                sele = li.UserData(1);
                switch self.selectedTraces(sele, 1)
                    case 0
                        self.graphLines{sele}.Color = [0.85,0.33,0.10];
                        self.selectedTraces(sele, 1) = 1;
                    case 1
                        self.graphLines{sele}.Color = [0,0.447,0.741];
                        self.selectedTraces(sele, 1) = 0;
                end
                self.updatePlot()
            end
            
            self.selectedFunction = @selected; % fancy way! I need it afterward in the bipolarize function.
            
            
            %% shaded position initiation
            minp = (prctile(h.tra(end,:), .1)*1.5)-self.space*(size(h.tra,1)+1);
            maxp = prctile(h.tra(1,:),99)*1.5;
            
            self.posipatch = patch(self.plotax,[0, 4, 4, 0],...
                [minp,minp,maxp,maxp],...
                [0.4660 0.6740 0.1880],...
                'FaceAlpha', .2,...
                'EdgeColor', 'none',...
                'ButtonDownFcn', @clickRealTrans);
            
            %ylim([minp,maxp])
            
            function clickRealTrans(~,act)
                if act.Button ~= 1;return;end
                if self.bstate(self.position) ~= self.bstate(self.position-1)
                    [newLoc,~,button] = ginput(1);
                    if button ~= 1; return ;end
                    [~,lo] = min(abs(self.time-newLoc));
                    self.realTrans(:,self.position) = [self.time(lo);lo];
                    self.updatePlot
                end
            end
            
            %% Name axe initiation
            self.namax = axes('unit', 'normalized',...
                'xcolor','none',...
                'ycolor','none',...
                'ylim', [0,1],...
                'xlim', [0,1],...
                'position', [.955 .26 .3 .71]);
            
            if isfield(h,'Channel')
                self.ChannelNames = h.Channel;
            else
                self.ChannelNames = cell(1,size(self.traces,1));
                for i = 1:size(self.traces,1)
                    self.ChannelNames{i} = ['Trace ', num2str(i)];
                end
            end
            
            self.initiateNames();
            
            %% fft plot initiation
            self.fftax = axes('parent', h.mainFig,...
                'unit', 'normalized',...
                'position', [.8 .05 .16 .13],...
                'TickDir', 'out',...
                'ycolor', 'w');
            xlabel('Frequency (Hz)')
            
            
            self.fftline = line(linspace(0,1,((200*4)/2)+1)*100, zeros(1,401));
            xlim([0,20])
            
            %% hypnogram plot initiation
            self.hypno = axes('parent', h.mainFig,...
                'unit', 'normalized',...
                'position', [.05 .05 .75 .13],...
                'TickDir', 'out',...
                'ycolor','w',...
                'xcolor','w',...
                'ButtonDownFcn', @navigate);
            
            function navigate(~,~)
                [newLoc,~,button] = ginput(1);
                if button == 3; return ;end
                pos = ceil(newLoc);
                pos = pos-mod(pos,4);
                self.position = pos/4;
                self.updatePlot()
            end
            
            self.hypnoline = line(linspace(0,self.time(end),length(self.bstate)), self.bstate, 'color' , [0.3010 0.7450 0.9330],'ButtonDownFcn', @navigate);
            ylim([0.5,3.5])
            
            self.posiline = line([self.second(1,self.position), self.second(self.position)], [0.5,3.5], 'color', 'black', 'linewidth',3);
            
            %% local hypno initiation
            self.localhypno = axes('parent', h.mainFig,...
                'unit', 'normalized',...
                'position', [.05 .25 .9 .05],...
                'TickDir', 'out',...
                'ycolor', 'w');
            xlabel('Time (s)')
            
            for i = 1:self.width
                self.localhypnolines{i} = line([self.second(1,self.position+(i-1)), self.second(2,self.position+(i-1))], [1, 1],...
                    'Color', self.colors(self.colstate(self.position+(i-1)),:),...
                    'linewidth',15);
            end
            xlim([0,40])
            self.transObj = line(self.localhypno,[1,1],self.localhypno.YLim,'color','none','linewidth',2);
        end
        
        %% Other methods
        function initiateNames(self)
            nTra = length(self.selectedTraces);
            if length(self.ChannelNames) ~= nTra
                err = errordlg('The number of names does not match the number of traces! Maybe reverse changes before using this function.');
                waitfor(err)
                for i = 1:size(self.traces,1)
                    self.ChannelNames{i} = ['Trace ', num2str(i)];
                end
            end
            cla(self.namax)
            ids = linspace(1/(nTra+1), 1-1/(nTra+1), nTra);
            ids = fliplr(ids);
            for i = 1:nTra
                text(self.namax, 0,ids(i), self.ChannelNames{i});
            end
        end
        
        function initiateB(self, b)
            bs = zeros(1,length(b));
            bs(b=='1'|b=='w') = 3;
            bs(b=='2'|b=='n') = 2;
            bs(b=='3'|b=='r') = 1;
            bs(b=='m') = 3.1;
            bs(b=='f') = 2.5;
            bs(b=='b') = 3.2;
            self.bstring = b;
            self.bstate = bs;
            col = zeros(1,length(b));
            col(b=='1') = 6;
            col(b=='2') = 5;
            col(b=='3') = 4;
            col(b=='w') = 3;
            col(b=='n') = 2;
            col(b=='r') = 1;
            col(b=='b') = 7;
            col(b=='m') = 8;
            col(b=='f') = 9;
            self.colstate = col;
        end
        
        % Navigate to transition
        function goTrans(self,type)
            cur = self.position;
            e = self.bstring(cur);
            switch type
                case 'next'; np = find(self.bstring(cur:end) ~= e, 1)+cur;
                case 'prev'; np = find(self.bstring(1:cur) ~= e, 1, 'last')+1;
                case 'nextW'; np = find(self.bstring(cur:end) == 'w', 1)+cur;
                case 'nextN'; np = find(self.bstring(cur:end) == 'n', 1)+cur;
                case 'nextR'; np = find(self.bstring(cur:end) == 'r', 1)+cur;
                case 'nextB'; np = find(self.bstring(cur:end) == 'b', 1)+cur;
                case 'nextM'; np = find(self.bstring(cur:end) == 'm', 1)+cur;
                case 'nextF'; np = find(self.bstring(cur:end) == 'f', 1)+cur;              
            end
            if ~isempty(np)
                self.position = np-1;
                self.updatePlot()
            end
        end
        
        % autoscore
        function autoscore(self)
            sele = find(self.selectedTraces);
            if isempty(sele) || length(sele)>2
                errordlg('Please select EEG and EMG only')
                return
            end
            an = questdlg('Which of EEG or EMG is comming FIRST (above the other) ?','Dirty fix (Alejo''s idea)','EEG','EMG','EEG');
            switch an
                case 'EEG'
                    b = VS2_autoScore(self.traces(sele(1),:), self.traces(sele(2),:), self.bstring);
                case 'EMG'
                    b = VS2_autoScore(self.traces(sele(2),:), self.traces(sele(1),:), self.bstring);
            end
            self.initiateB(b)
            self.updatePlot()
            self.hypnoline.YData = self.bstate;
        end
        
        % change the width
        function changeWidth(self, newWidth)
            self.width = newWidth;
            cellfun(@delete, self.localhypnolines)
            self.localhypnolines = cell(1,newWidth);
            self.updatePlot()
        end
        
        % give b to save
        function b = giveMeB(self)
            b = self.bstring;
        end
        
        % Function to change the bstate
        function changeB(self,state)
            self.bstring(self.position) = state;
            switch state
                case 'w'
                    self.bstate(self.position) = 3;
                    self.colstate(self.position) = 3;
                case '1'
                    self.bstate(self.position) = 3;
                    self.colstate(self.position) = 6;
                case 'n'
                    self.bstate(self.position) = 2;
                    self.colstate(self.position) = 2;
                case '2'
                    self.bstate(self.position) = 2;
                    self.colstate(self.position) = 5;
                case 'r'
                    self.bstate(self.position) = 1;
                    self.colstate(self.position) = 1;
                case '3'
                    self.bstate(self.position) = 1;
                    self.colstate(self.position) = 4;
                case 'm'
                    self.bstate(self.position) = 3.1;
                    self.colstate(self.position) = 8;
                case 'f'
                    self.bstate(self.position) = 2.5;
                    self.colstate(self.position) = 9;
            end
            if self.position < length(self.bstate)
                self.position = self.position+1;
            end
            self.hypnoline.YData = self.bstate;
            self.updatePlot()
        end
        
        %Function to increase  or decrease the gain
        function changeGain(self, sign, coef)
            sele = find(self.selectedTraces);
            if isempty(sele)
                switch sign
                    case 'plus'; self.space = self.space+0.0001;
                    case 'minus'; self.space = self.space-0.0001;
                end
            else
                switch sign
                    case 'plus'; self.traces(sele,:) = self.traces(sele,:)*1.1*coef;
                    case 'minus'; self.traces(sele,:) = self.traces(sele,:)/(1.1*coef);
                end
            end
            self.updatePlot()
        end
        
        % Function to filter the traces
        function filterTrace(self,a,b)
            sele = find(self.selectedTraces);
            if isempty(sele)
                errordlg('C''mon, you need to select at least one trace.')
                return
            end
            for i = 1:length(sele)
                self.traces(sele(i),:) = filtfilt(a, b, self.traces(sele(i),:));
            end
            self.updatePlot()
        end
        
        % Function to retreive original gain and filter
        function backToGain(self)
            sele = find(self.selectedTraces);
            if isempty(sele)
                errordlg('You need to select traces for this option.')
                return
            end
            for i = 1:length(sele)
                idx = self.graphLines{sele(i)}.UserData;
                if length(idx) == 3
                    self.traces(sele(i),:) = self.oriTraces(idx(2),:)-self.oriTraces(idx(3),:);
                else
                    self.traces(sele(i),:) = self.oriTraces(idx(2),:);
                end
            end
            self.updatePlot()
        end
        
        % Function to differenciate two traces
        function bipolarize(self)
            sele = find(self.selectedTraces);
            if length(sele) ~= 2
                errordlg('You need to select two traces for this option.')
                return
            end
            oritra1 = self.graphLines{sele(1)}.UserData(2);
            oritra2 = self.graphLines{sele(2)}.UserData(2);
            an = questdlg('Do you want to keep the two original traces or not?', 'Nice that you have a choice right?', 'Yes','No','No');
            newt = self.oriTraces(oritra1,:)-self.oriTraces(oritra2,:);
            switch an
                case 'No'
                    self.traces(sele(1),:) = newt;
                    self.traces(sele(2),:) = [];
                    delete(self.graphLines{sele(2)})
                    self.graphLines(sele(2)) = [];
                    self.selectedTraces(sele(2)) = [];
                    self.graphLines{sele(1)}.UserData = [self.graphLines{sele(1)}.UserData(1), oritra1, oritra2];
                    self.ChannelNames{sele(1)} = [self.ChannelNames{sele(1)}, ' - ', self.ChannelNames{sele(2)}];
                    self.ChannelNames(sele(2)) = [];
                case 'Yes'
                    self.traces(end+1,:) = newt;
                    self.graphLines{end+1} = line(self.plotax, self.time(1:self.points(2,self.position+self.width)),...
                        self.traces(end,1:self.points(2,self.position+self.width))-self.space*size(self.traces,1),...
                        'ButtonDownFcn', self.selectedFunction,...
                        'UserData', [size(self.traces,1), oritra1, oritra2],...
                        'Color',[0.85,0.33,0.10]);
                    self.selectedTraces(end+1,1) = 1;
                    self.ChannelNames{end+1} = [self.ChannelNames{sele(1)}, ' - ', self.ChannelNames{sele(2)}];
            end
            self.updatePlot()
            self.initiateNames()
        end
        
        % Function to supress traces
        function supressTraces(self)
            sele = find(self.selectedTraces);
            if isempty(sele)
                errordlg('You need to select traces for this option.')
                return
            end
            for i = 1:length(sele)
                delete(self.graphLines{sele(i)})
            end
            self.traces(sele,:) = [];
            self.graphLines(sele) = [];
            self.selectedTraces(sele) = [];
            self.ChannelNames(sele) = [];
            
            self.updatePlot()
            self.initiateNames()
        end
        
        % Function to swap traces
        function swapTraces(self)
            sele = find(self.selectedTraces);
            if length(sele) ~= 2
                errordlg('You need to select 2 traces for this option.')
                return
            end
            self.traces(sele,:) = self.traces([sele(2), sele(1)],:);
            self.graphLines(sele) = self.graphLines([sele(2), sele(1)]);
            self.ChannelNames(sele) = self.ChannelNames([sele(2), sele(1)]);
            
            self.updatePlot()
            self.initiateNames()
        end
        
        % function to move one trace
        function moveTrace(self,dire)
            sele = find(self.selectedTraces);
            if length(sele) ~= 1
                errordlg('Select just one trace to move up or down!')
                return
            end
            switch dire
                case 'up'
                    if sele == 1
                        return
                    else
                        self.traces(sele-1:sele,:) = self.traces([sele, sele-1],:);
                        self.graphLines(sele-1:sele) = self.graphLines([sele, sele-1]);
                        self.selectedTraces(sele-1:sele) = self.selectedTraces([sele, sele-1]);
                        self.ChannelNames(sele-1:sele) = self.ChannelNames([sele, sele-1]);
                    end
                case 'dn'
                    if sele == length(self.selectedTraces)
                        return
                    else
                        self.traces(sele:sele+1,:) = self.traces([sele+1, sele],:);
                        self.graphLines(sele:sele+1) = self.graphLines([sele+1, sele]);
                        self.selectedTraces(sele:sele+1) = self.selectedTraces([sele+1, sele]);
                        self.ChannelNames(sele:sele+1) = self.ChannelNames([sele+1, sele]);
                    end
            end
            self.updatePlot()
            self.initiateNames()
        end
        
        
        
        
        %% MOST IMPORTANTEST FUNCTION! THE ONE THAT UPDATE ALL AFTER EVERY ACTION!! VERY DON'T TOUCH!
        function updatePlot(self)
            %disp(self.position)
            % update traces
            if self.position - self.width/2 < 1 % at the begining
                positionBorder = [1, self.width];
                pointsBorder = self.points(1,positionBorder(1)):self.points(2,positionBorder(2));
                
            elseif self.position + self.width/2 >= length(self.bstate) % at the end
                positionBorder = [length(self.bstate)-self.width+1, length(self.bstate)];
                pointsBorder = self.points(1,positionBorder(1)):self.points(2,positionBorder(2));
                
            else % all along
                positionBorder = [self.position-(self.width/2)+1, self.position+self.width/2];
                pointsBorder = self.points(1,positionBorder(1)):self.points(2,positionBorder(2));
            end
            
            for i = 1:size(self.traces,1)
                set(self.graphLines{i}, 'XData', self.time(pointsBorder),...
                    'YData', self.traces(i, pointsBorder) - self.space*i)
                self.graphLines{i}.UserData(1) = i;
            end
            self.plotax.XLim = [self.second(1,positionBorder(1)), self.second(2,positionBorder(2))];
            
            
            % update posipatch
            if self.lockYlim == 0
                minp = prctile(self.graphLines{end}.YData,0.5)-self.space/3;
                maxp = prctile(self.graphLines{1}.YData,99.5)+self.space/3;
                set(self.posipatch, 'XData', [self.second(1,self.position), self.second(2,self.position), self.second(2,self.position), self.second(1,self.position)],...
                    'YData', [minp, minp, maxp, maxp])
            else
                set(self.posipatch, 'XData', [self.second(1,self.position), self.second(2,self.position), self.second(2,self.position), self.second(1,self.position)]);
            end
            % update the bstate lines
            axes(self.localhypno)
            for i = 1:self.width
                xdat = [self.second(1,positionBorder(1)+(i-1)), self.second(2,positionBorder(1)+(i-1))];
                if isempty(self.localhypnolines{i}) % in case there was a change of width
                    self.localhypnolines{i} = line(xdat, [1,1],...
                        'Color', self.colors(self.colstate(positionBorder(1)+(i-1)),:),...
                        'linewidth', 15);
                else
                    set(self.localhypnolines{i}, 'XData', xdat,...
                        'Color', self.colors(self.colstate(positionBorder(1)+(i-1)),:));
                end
            end
            self.localhypno.XLim = [self.second(1,positionBorder(1)), self.second(2,positionBorder(2))];
            
            % update ylim
            if self.lockYlim == 0
                self.plotax.YLim = [minp, maxp];
            end
            
            % update posiline in hypnogram
            self.posiline.XData = [self.second(1,self.position), self.second(1,self.position)];
            
            % update fft for selected line
            sele = find(self.selectedTraces,1);
            if ~isempty(sele)
                totreat = self.traces(sele, self.points(1,self.position):self.points(2,self.position));
                totreat = totreat-mean(totreat);
                lafft = abs(fft(totreat));
                self.fftline.YData = lafft(1:401).^2;
            end
            %update the real transition position if is at a transition and
            %if it exists
            if self.position ~= 1
                if self.bstate(self.position) ~= self.bstate(self.position-1)
                    if ~isnan(self.realTrans(2,self.position))
                        self.transObj.Color = 'black';
                        self.transObj.XData = [self.realTrans(1,self.position),self.realTrans(1,self.position)];
                    else
                        self.realTrans(:,self.position) = NaN(2,1);
                        self.transObj.Color = 'none';
                    end
                else
                    self.transObj.Color = 'none';
                end
            end
        end
        
    end
    
end

