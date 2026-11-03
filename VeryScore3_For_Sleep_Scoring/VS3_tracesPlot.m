classdef VS3_tracesPlot < handle
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
        thermax = []              % axes of the temperature panel (empty when hidden), see showThermal
        thermal = []              % struct 'Thermal' of the file / VS3_thermalTool (valueEpoch, t2Hz, value2Hz, ...)
        thermLines = struct()     % graphic objects of the temperature panel
        thermColor = [.75 .15 .1] % color of the per-epoch temperature line
        navigateFunction          % click-to-navigate callback shared by the hypnogram and the temperature panel
        dffScale = []             % display units per % of dF/F of the photometry trace (see showDFF)
        oriScale = []             % per recorded channel: factor back to the units of the file (the import divides some channels, see VS3_main)
        rowInfo                   % per display row: scale (to the units of the file, % for a dF/F), steps (filters...), noData (samples without dF/F at start / end), dff; see exportTraces
        video = []                % video column right of the traces (VS3_videoPanel), [] = no video open
        centerTraces = false      % centre every trace in its slot on screen (DC levels of the Open Ephys acquisition board)
        epochChangedFunction = [] % called with the epoch after every update (sensor comparison, VS3_sensorView)
    end
    
    methods
        %% Initiation function:
        function self = VS3_tracesPlot(h,posi,wi)
            self.position = posi;
            self.width = wi;
            % Get the bstates to know the number of epochs
            self.initiateB(h.b);
            self.realTrans = NaN(2,length(self.bstate));
            % the positions in seconds for each epoch
            self.second = [linspace(0,(length(self.bstate)*4)-4,length(self.bstate)); linspace(4,length(self.bstate)*4,length(self.bstate))];
            
            self.traces = h.tra;
            self.oriTraces = h.tra;
            self.oriScale = ones(size(h.tra,1),1);
            if isfield(h, 'traScale') && numel(h.traScale) == size(h.tra,1)
                self.oriScale = h.traScale(:);
            end
            self.rowInfo = struct('scale', num2cell(self.oriScale), 'steps', {{}}, 'noData', [0 0], 'dff', false);
            self.time = linspace(0, length(self.traces)/200, length(self.traces)); % the time vector for the traces
            if isfield(h, 'centerTraces'); self.centerTraces = h.centerTraces; end
            
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
                y = self.traces(i,1:self.points(2,self.position+self.width));
                if self.centerTraces; y = y - median(y, 'omitnan'); end % display only (see updatePlot)
                self.graphLines{i} = line(self.time(1:self.points(2,self.position+self.width)),...
                    y-self.space*i,...
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
            self.namax = axes('parent', h.mainFig,...
                'unit', 'normalized',...
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
                % epoch k covers [4(k-1), 4k) s; clicks outside the recording go to its first / last epoch
                self.position = min(max(floor(newLoc/4)+1, 1), numel(self.bstate));
                self.updatePlot()
            end
            
            self.navigateFunction = @navigate; % shared with the temperature panel (see showThermal)
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
                    b = VS3_autoScoreClassic(self.traces(sele(1),:), self.traces(sele(2),:), self.bstring);
                case 'EMG'
                    b = VS3_autoScoreClassic(self.traces(sele(2),:), self.traces(sele(1),:), self.bstring);
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
                g = 1;
                switch sign
                    case 'plus'; g = 1.1*coef;
                    case 'minus'; g = 1/(1.1*coef);
                end
                self.traces(sele,:) = self.traces(sele,:)*g;
                for r = sele(:)' % the display gain is undone when the traces are exported
                    self.rowInfo(r).scale = self.rowInfo(r).scale/g;
                end
            end
            self.updatePlot()
        end

        % Function to filter the traces (label: what the filter is, kept for the export)
        function filterTrace(self,a,b,label)
            sele = find(self.selectedTraces);
            if isempty(sele)
                errordlg('C''mon, you need to select at least one trace.')
                return
            end
            for i = 1:length(sele)
                self.traces(sele(i),:) = filtfilt(a, b, self.traces(sele(i),:));
                if nargin > 3 && ~isempty(label)
                    self.rowInfo(sele(i)).steps{end+1} = label;
                end
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
                self.rawTrace(sele(i))
            end
            self.updatePlot()
            self.initiateNames()
        end

        function rawTrace(self, row)
            % rawTrace  Show the recorded channel(s) of display row 'row' again, without gain or
            % filter; a dF/F trace (Tools > Photometry) becomes the raw channel again.
            idx = self.graphLines{row}.UserData;
            if length(idx) == 3
                self.traces(row,:) = self.oriTraces(idx(2),:)-self.oriTraces(idx(3),:);
            else
                self.traces(row,:) = self.oriTraces(idx(2),:);
            end
            self.rowInfo(row) = self.rawRowInfo(idx(2:end));
            self.ChannelNames{row} = regexprep(self.ChannelNames{row}, ' dF/F$', '');
        end

        function r = rawRowInfo(self, chans)
            % rawRowInfo  rowInfo of a row showing recorded channel chans(1) (minus chans(2)), unprocessed
            r = struct('scale', self.oriScale(chans(1)), 'steps', {{}}, 'noData', [0 0], 'dff', false);
            if numel(chans) == 2 && self.oriScale(chans(2)) ~= self.oriScale(chans(1))
                r.steps = {'units mixed: the two channels were scaled differently at loading'};
            end
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
                    self.rowInfo(sele(1)) = self.rawRowInfo([oritra1, oritra2]);
                    self.rowInfo(sele(2)) = [];
                    delete(self.graphLines{sele(2)})
                    self.graphLines(sele(2)) = [];
                    self.selectedTraces(sele(2)) = [];
                    self.graphLines{sele(1)}.UserData = [self.graphLines{sele(1)}.UserData(1), oritra1, oritra2];
                    self.ChannelNames{sele(1)} = [self.ChannelNames{sele(1)}, ' - ', self.ChannelNames{sele(2)}];
                    self.ChannelNames(sele(2)) = [];
                case 'Yes'
                    self.traces(end+1,:) = newt;
                    self.rowInfo(end+1) = self.rawRowInfo([oritra1, oritra2]);
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
            self.rowInfo(sele) = [];

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
            self.rowInfo(sele) = self.rowInfo([sele(2), sele(1)]);

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
                        self.rowInfo(sele-1:sele) = self.rowInfo([sele, sele-1]);
                    end
                case 'dn'
                    if sele == length(self.selectedTraces)
                        return
                    else
                        self.traces(sele:sele+1,:) = self.traces([sele+1, sele],:);
                        self.graphLines(sele:sele+1) = self.graphLines([sele+1, sele]);
                        self.selectedTraces(sele:sele+1) = self.selectedTraces([sele+1, sele]);
                        self.ChannelNames(sele:sele+1) = self.ChannelNames([sele+1, sele]);
                        self.rowInfo(sele:sele+1) = self.rowInfo([sele+1, sele]);
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
                y = self.traces(i, pointsBorder);
                if self.isDFF(i)
                    % photometry dF/F: centred in its slot on every screen (it drifts slowly over the
                    % night) and kept within 1.5 slots of it; display only
                    y = y - median(y, 'omitnan');
                    y = min(max(y, -1.5*self.space), 1.5*self.space);
                elseif self.centerTraces
                    y = y - median(y, 'omitnan'); % display only: the samples, filters and export are unchanged
                end
                set(self.graphLines{i}, 'XData', self.time(pointsBorder),...
                    'YData', y - self.space*i)
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
            % update the temperature panel (thermal video), if displayed
            self.updateThermal()
            % update the video column (Tools > Video), if a video is open
            if ~isempty(self.video) && isvalid(self.video)
                self.video.update()
            end
            % and the sensor comparison (Tools > Sensor data), if open
            if ~isempty(self.epochChangedFunction)
                self.epochChangedFunction(self.position)
            end
        end

        %% Temperature panel (thermal video, see VS3_thermalTool)
        function showThermal(self, A)
            % showThermal  Display the temperature of the thermal video in a panel above the
            % hypnogram. A is the struct stored as 'Thermal' in the file (made by VS3_thermalTool):
            % A.valueEpoch = one value per 4-s epoch (same indexing as the scoring),
            % A.t2Hz / A.value2Hz = one value per video frame, in seconds since EEG start.
            % Without argument the panel is rebuilt from the data already given.
            if nargin < 2 || isempty(A)
                A = self.thermal;
            end
            if isempty(A) || ~isfield(A, 'valueEpoch')
                return
            end
            self.hideThermal()
            self.thermal = A;

            nEp = length(self.bstate);
            ve = nan(1, nEp);
            n = min(nEp, numel(A.valueEpoch));
            ve(1:n) = A.valueEpoch(1:n);
            if numel(A.valueEpoch) ~= nEp
                warning('VS3:thermalEpochs', 'The temperature has %d epochs but the scoring %d: the panel shows the first %d.', numel(A.valueEpoch), nEp, n)
            end

            self.layoutAxes(true)
            fig = ancestor(self.hypno, 'figure');
            self.thermax = axes('parent', fig,...
                'unit', 'normalized',...
                'position', [.05 .19 .75 .10],...
                'TickDir', 'out',...
                'xcolor', 'w',...
                'ButtonDownFcn', self.navigateFunction);

            self.thermLines = struct();
            if isfield(A, 't2Hz') && isfield(A, 'value2Hz') && ~isempty(A.t2Hz)
                self.thermLines.frames = line(self.thermax, A.t2Hz, A.value2Hz,...
                    'Color', [.8 .8 .8],...
                    'ButtonDownFcn', self.navigateFunction); % one value per video frame
            end
            self.thermLines.epochs = line(self.thermax, self.second(1,:), ve,...
                'Color', self.thermColor,...
                'LineWidth', 1,...
                'ButtonDownFcn', self.navigateFunction); % one value per 4-s epoch

            % y limits robust to artifacts (0.5 - 99.5 percentiles of the epoch values)
            vv = ve(~isnan(ve));
            if isempty(vv)
                yl = [0 1];
            else
                yl = prctile(vv, [0.5 99.5]);
                if yl(2) <= yl(1); yl = [min(vv) max(vv)]; end
                if yl(2) <= yl(1); yl = yl(1) + [-1 1]; end
            end
            pad = 0.08*diff(yl);
            self.thermax.YLim = [yl(1)-pad, yl(2)+pad];
            linkaxes([self.hypno, self.thermax], 'x') % same time axis as the hypnogram
            self.hypno.XLim = [0, self.second(2,end)]; % the recording, not the union with a longer video

            x = self.second(1, self.position);
            self.thermLines.posi = line(self.thermax, [x x], self.thermax.YLim, 'color', 'black', 'linewidth', 2);
            meth = 'ROI';
            if isfield(A, 'roiMethod'); meth = A.roiMethod; end
            % label (left) and value of the current epoch (right), just above the panel
            self.thermLines.label = text(self.thermax, 0, 1.04, sprintf('Thermal video: %s (%s)', meth, self.thermalUnit()),...
                'Units', 'normalized', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom',...
                'FontSize', 8, 'Color', [.4 .4 .4], 'Interpreter', 'none');
            self.thermLines.text = text(self.thermax, 1, 1.04, '',...
                'Units', 'normalized', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom',...
                'FontWeight', 'bold', 'Color', self.thermColor, 'Interpreter', 'none');
            self.updateThermal()
        end

        function hideThermal(self)
            % hideThermal  Remove the temperature panel (the data are kept, see showThermal).
            if ~isempty(self.thermax) && isgraphics(self.thermax)
                linkaxes([self.hypno, self.thermax], 'off')
                delete(self.thermax)
                self.hypno.XLimMode = 'auto';
            end
            self.thermax = [];
            self.thermLines = struct();
            self.layoutAxes(false)
        end

        function updateThermal(self)
            % updateThermal  Move the position line of the temperature panel and refresh the readout.
            if isempty(self.thermax) || ~isgraphics(self.thermax)
                return
            end
            x = self.second(1, self.position);
            set(self.thermLines.posi, 'XData', [x x], 'YData', self.thermax.YLim)
            v = NaN;
            if self.position <= numel(self.thermal.valueEpoch)
                v = self.thermal.valueEpoch(self.position);
            end
            if isnan(v)
                self.thermLines.text.String = 'no video';
            else
                self.thermLines.text.String = sprintf('%.2f %s', v, self.thermalUnit());
            end
        end

        function s = thermalUnit(self)
            % thermalUnit  degC symbol, or 'counts' when the camera calibration is missing
            s = 'counts';
            if ~isempty(self.thermal) && isfield(self.thermal, 'unit') && strcmpi(self.thermal.unit, 'degC')
                s = [char(176) 'C'];
            end
        end

        function layoutAxes(self, withThermal)
            % layoutAxes  Make room above the hypnogram for the temperature panel (or give it back),
            % and right of the traces for the video column when a video is open (VS3_videoPanel).
            if nargin < 2
                withThermal = ~isempty(self.thermax) && isgraphics(self.thermax);
            end
            withVideo = ~isempty(self.video) && isvalid(self.video) && self.video.isOpen();
            w = .9;
            if withVideo; w = .58; end
            if withThermal
                y = .40; ht = .55;
            else
                y = .3; ht = .65;
            end
            self.plotax.Position = [.05 y w ht];
            self.localhypno.Position = [.05 y-.05 w .05];
            self.namax.Position = [.05+w+.005 y-.04 .3 ht+.06];
            if withVideo
                self.video.place([.70 y-.05 .295 ht+.07])
            elseif ~isempty(self.video) && isvalid(self.video)
                self.video.hide()
            end
        end

        %% Photometry (dF/F of a recorded channel, see VS3_photometry)
        function showDFF(self, row, P)
            % showDFF  Replace the display of the trace 'row' by the dF/F in P, the struct made by
            % VS3_photometry and stored as 'Photometry' in the file (P.time in seconds since the
            % first sample, P.dff in %). The dF/F is scaled so that it is about as high as one
            % trace slot (self.dffScale display units per %); the values in % stay in P.
            % Traces > Reverse gain and filter shows the raw channel again.
            if isempty(P) || ~isfield(P, 'dff') || ~isfield(P, 'time') || isempty(P.dff)
                return
            end
            if isempty(row) || row < 1 || row > size(self.traces, 1)
                return
            end
            d = double(P.dff(:)');
            tP = double(P.time(:)');
            d(~isfinite(d)) = NaN;
            v = interp1(tP, d, self.time, 'linear', NaN);
            ok = find(~isnan(v));
            if isempty(ok)
                return
            end
            v(1:ok(1)-1) = v(ok(1)); % the dF/F starts 3 s after and stops 3 s before the ends of the recording
            v(ok(end)+1:end) = v(ok(end));
            % scale: the typical spread of the dF/F within one minute fills most of a trace slot (the
            % slow drift over the night is removed on screen, see updatePlot); computed on the part
            % used by the baseline fit (the start left out can be an extrapolation)
            fitted = ~isnan(d);
            if isfield(P, 'params') && isfield(P.params, 'skipStart') && any(fitted & tP > P.params.skipStart)
                fitted = fitted & tP > P.params.skipStart;
            end
            x = d(fitted);
            seg = max(2, round(60/median(diff(tP))));
            nb = floor(numel(x)/seg);
            if nb >= 3
                X = reshape(x(1:nb*seg), seg, nb);
                ran = median(diff(prctile(X, [2.5 97.5], 1), 1, 1), 'omitnan')/0.8;
            else
                ran = diff(prctile(x, [0.5 99.5]));
            end
            sc = 1;
            if ran > 0
                sc = self.space/ran; % then rounded to 1, 2 or 5 times a power of ten
                e = floor(log10(sc));
                m = sc/10^e;
                steps = [1 2 5 10];
                sc = steps(find(m < [1.5 3.5 7.5 Inf], 1))*10^e;
            end
            self.traces(row,:) = v*sc;
            self.dffScale = sc;
            self.rowInfo(row) = struct('scale', 1/sc, 'steps', {{dffStep(P)}}, 'noData', [ok(1)-1, numel(v)-ok(end)], 'dff', true);
            self.ChannelNames{row} = [regexprep(self.ChannelNames{row}, ' dF/F$', ''), ' dF/F'];
            self.updatePlot()
            self.initiateNames()
        end

        function tf = isDFF(self, row)
            % isDFF  Is display row 'row' a photometry dF/F (see showDFF)?
            tf = numel(self.ChannelNames) >= row && ischar(self.ChannelNames{row}) && endsWith(self.ChannelNames{row}, ' dF/F');
        end

        %% Export of the displayed traces (File > Export displayed traces, see VS3_main)
        function [X, names, rows] = exportTraces(self)
            % exportTraces  The traces as they are displayed, at 200 Hz, one row per trace in the order
            % of the screen (suppressed traces left out): filters, notches, bipolar differences and the
            % photometry dF/F are kept; the display gain and the scaling of the import are undone, so
            % the values are in the units of the file (dF/F in %, NaN where there is no dF/F).
            % rows(i).channels = recorded channel(s) of row i (two: the first minus the second),
            % rows(i).steps = what was applied to it, in order; rows(i).dff = true for a dF/F.
            n = size(self.traces, 1);
            X = zeros(size(self.traces));
            rows = struct('channels', cell(n,1), 'steps', cell(n,1), 'dff', cell(n,1));
            for i = 1:n
                r = self.rowInfo(i);
                X(i,:) = self.traces(i,:)*r.scale;
                X(i, 1:r.noData(1)) = NaN;
                X(i, end-r.noData(2)+1:end) = NaN;
                ud = self.graphLines{i}.UserData;
                rows(i).channels = ud(2:end);
                rows(i).steps = r.steps;
                rows(i).dff = r.dff;
            end
            names = self.ChannelNames(:)';
        end

        %% Sensor comparison (Tools > Sensor data, see VS3_sensorView)
        function [labels, keys] = sensorCatalog(self, originalNames)
            % sensorCatalog  One entry per display row: its name and the names of its recorded
            % channel(s) in the file; keys = the recorded channels ('3' or '3-4' for a difference),
            % which follow the row when the traces are swapped or suppressed.
            n = size(self.traces, 1);
            labels = cell(1, n);
            keys = cell(1, n);
            for row = 1:n
                src = self.graphLines{row}.UserData(2:end);
                keys{row} = strjoin(arrayfun(@num2str, src, 'UniformOutput', false), '-');
                labels{row} = sprintf('%s | original: %s', self.ChannelNames{row}, strjoin(originalNames(src), ' - '));
            end
        end

        function [x, fs, processing, isDff] = sensorEpoch(self, key, ep)
            % sensorEpoch  The displayed samples of the row with recorded channel(s) 'key' in epoch
            % ep, at 200 Hz, in the units of the file (filters kept, display gain undone).
            row = [];
            for k = 1:numel(self.graphLines)
                src = self.graphLines{k}.UserData(2:end);
                if strcmp(strjoin(arrayfun(@num2str, src, 'UniformOutput', false), '-'), key); row = k; break; end
            end
            if isempty(row); error('VS3:sensorEmg', 'The selected trace is no longer displayed.'); end
            fs = 200;
            first = (ep-1)*800 + 1;
            last = ep*800;
            if first < 1 || last > size(self.traces, 2); error('VS3:sensorEmg', 'Incomplete displayed epoch.'); end
            r = self.rowInfo(row);
            x = self.traces(row, first:last)*r.scale;
            idx = first:last;
            x(idx <= r.noData(1) | idx > size(self.traces, 2) - r.noData(2)) = NaN;
            processing = strjoin(r.steps, '; ');
            if isempty(processing); processing = 'No additional main-window filter'; end
            processing = [processing, '; main-window samples at 200 Hz; display gain removed'];
            isDff = r.dff;
        end

        function deleteAxes(self)
            % deleteAxes  Delete every axes of this plot (before a new VS3_tracesPlot is created).
            axs = {self.plotax, self.localhypno, self.hypno, self.fftax, self.namax, self.thermax};
            for i = 1:numel(axs)
                if ~isempty(axs{i}) && isgraphics(axs{i})
                    delete(axs{i})
                end
            end
            self.thermax = [];
        end

    end

end

function s = dffStep(P)
% dffStep  What the dF/F of P (VS3_photometry) is, for the export of the traces
how = {};
if isfield(P, 'method') && ~isempty(P.method); how{end+1} = sprintf('%s baseline', P.method); end
if isfield(P, 'fSignal') && ~isempty(P.fSignal)
    car = sprintf('carriers %.2f Hz signal', P.fSignal);
    if isfield(P, 'fIso') && ~isempty(P.fIso) && ~isnan(P.fIso); car = sprintf('%s / %.2f Hz purple', car, P.fIso); end
    how{end+1} = sprintf('%s demodulated from the full-rate channel', car);
end
if isfield(P, 'fs'); how{end+1} = sprintf('computed at %g Hz', P.fs); end
s = sprintf('photometry dF/F in %% (%s), interpolated to 200 Hz', strjoin(how, '; '));
end

