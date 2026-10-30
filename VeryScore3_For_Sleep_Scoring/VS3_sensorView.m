classdef VS3_sensorView < handle
    % Synchronized four-second waveforms and window-corrected amplitude spectra.
    properties
        fig
        sensor
        config
        position = 1
        provider
        navigate
        sensorLine
        filteredLine
        emgLine
        sensorSpectrum
        emgSpectrum
        sensorPeaks
        emgPeaks
        status
        channelMenu
        epochEdit
        axesList
        updating = false
        channelNames
        channelKeys
        catalogProvider = []
        detailPanel
        overviewPanel
        trendAxes
        timeline = []
        viewportSlider
        windowMenu
        viewportListener
        windowSeconds = Inf
        trendPositions
        overviewBusy = false
        overviewDirty = true
        settingsChanged = []
        timelineKeys = {}
    end
    methods
        function self=VS3_sensorView(S,config,names,provider,navigate,visible,catalogProvider)
            if nargin<6; visible='on'; end
            if ~isfield(config,'channels'); config.channels=config.channel; end
            self.sensor=S; self.config=config; self.provider=provider; self.navigate=navigate;
            self.channelNames=names;
            self.channelKeys=arrayfun(@num2str,1:numel(names),'UniformOutput',false);
            if nargin>=7; self.catalogProvider=catalogProvider; self.refreshCatalog(); end
            bg=[.96 .97 .985]; ink=[.12 .16 .22];
            self.fig=figure('Name','Sensor / EEG-EMG comparison','NumberTitle','off', ...
                'MenuBar','none','ToolBar','figure','Color',bg,'Visible',visible,'Position',[180 100 1200 820]);
            uicontrol(self.fig,'Style','text','String','EEG / EMG channels', 'FontSize',12,'FontWeight','bold', ...
                'Units','normalized','Position',[.04 .94 .17 .035],'BackgroundColor',bg,'ForegroundColor',ink);
            self.channelMenu=uicontrol(self.fig,'Style','listbox','String',names,'Min',0,'Max',max(2,numel(names)), ...
                'Value',self.config.channels,'Units','normalized','Position',[.21 .905 .25 .085], ...
                'Callback',@(~,~) self.changeChannel());
            uicontrol(self.fig,'Style','pushbutton','String','< Previous', ...
                'Units','normalized','Position',[.47 .94 .11 .04],'Callback',@(~,~) self.go(self.position-1));
            self.epochEdit=uicontrol(self.fig,'Style','edit','String','1', ...
                'Units','normalized','Position',[.59 .94 .08 .04],'Callback',@(~,~) self.go(str2double(self.epochEdit.String)));
            uicontrol(self.fig,'Style','pushbutton','String','Next >', ...
                'Units','normalized','Position',[.68 .94 .11 .04],'Callback',@(~,~) self.go(self.position+1));
            uicontrol(self.fig,'Style','popupmenu','String',{'Both spectra 0-20 Hz','EMG spectrum up to 100 Hz'}, ...
                'Units','normalized','Position',[.80 .94 .18 .04],'Callback',@(obj,~) self.frequencyRange(obj.Value));
            uicontrol(self.fig,'Style','pushbutton','String','Full recording', ...
                'Units','normalized','Position',[.04 .865 .15 .035],'Callback',@(~,~) self.showOverview());
            uicontrol(self.fig,'Style','pushbutton','String','Current 4 s - waveforms & FFT', ...
                'Units','normalized','Position',[.20 .865 .25 .035],'Callback',@(~,~) self.showDetails());
            uicontrol(self.fig,'Style','pushbutton','String','Refresh trends', ...
                'Units','normalized','Position',[.47 .865 .14 .035],'Callback',@(~,~) self.showOverview(true));
            uicontrol(self.fig,'Style','pushbutton','String','Bands & alignment', ...
                'Units','normalized','Position',[.63 .865 .14 .035],'Callback',@(~,~) self.editSettings());
            uicontrol(self.fig,'Style','text','String','Pan / zoom / inspect', ...
                'Units','normalized','Position',[.79 .865 .19 .035],'BackgroundColor',bg,'ForegroundColor',[.4 .45 .52]);
            self.detailPanel=uipanel(self.fig,'Units','normalized','Position',[.01 .20 .98 .65], ...
                'BorderType','none','BackgroundColor',bg);
            self.overviewPanel=uipanel(self.fig,'Units','normalized','Position',[.01 .20 .98 .65], ...
                'BorderType','none','BackgroundColor',bg,'Visible','off');
            self.axesList=gobjects(1,4);
            positions={[.07 .58 .39 .33],[.57 .58 .39 .33],[.07 .10 .39 .30],[.57 .10 .39 .30]};
            for k=1:4
                self.axesList(k)=axes(self.detailPanel,'Position',positions{k},'Box','off', ...
                    'FontName','Helvetica','FontSize',10,'Color','w','XColor',ink,'YColor',ink,'GridColor',[.85 .88 .92]);
            end
            a=self.axesList;
            self.sensorLine=line(a(1),NaN,NaN,'Color',[.7 .7 .7]);
            self.filteredLine=line(a(1),NaN,NaN,'Color',[.1 .4 .8]);
            title(a(1),'Sensor: raw (grey), 20 Hz low-pass (blue)'); ylabel(a(1),'ADC counts');
            self.emgLine=gobjects(0);
            if isempty(self.catalogProvider)
                title(a(2),'EMG waveform');
            else
                title(a(2),'EMG: main-window filters (200 Hz; gain removed)');
            end
            for k=1:2; xlabel(a(k),'Time since EEG start (s; shared axis)'); end
            linkaxes(a(1:2),'x');
            self.sensorSpectrum=line(a(3),NaN,NaN,'Color',[.1 .4 .8]);
            self.emgSpectrum=gobjects(0);
            self.sensorPeaks=line(a(3),NaN,NaN,'LineStyle','none','Marker','o','Color',[.8 .15 .1]);
            self.emgPeaks=gobjects(0);
            for k=3:4
                xlabel(a(k),'Frequency (Hz)'); xlim(a(k),[0 20]);
                xline(a(k),config.bands(1,1),':','Resp.'); xline(a(k),config.bands(1,2),':');
                xline(a(k),config.bands(2,1),'--','Heart'); xline(a(k),config.bands(2,2),'--');
            end
            title(a(3),'Sensor FFT amplitude (Hann window)'); ylabel(a(3),'Amplitude (ADC counts)');
            title(a(4),'Recorded channel FFT amplitude (Hann window)');
            self.status=uicontrol(self.fig,'Style','edit','Max',2,'Min',0,'Enable','inactive','String','', ...
                'Units','normalized','Position',[.04 .015 .93 .12],'HorizontalAlignment','left', ...
                'BackgroundColor',bg,'ForegroundColor',[.30 .36 .44],'FontSize',10);
            self.trendAxes=gobjects(1,2);
            trendTitles={'Respiration candidates','Heart candidates'};
            trendLocations={[.07 .59 .84 .32],[.07 .12 .84 .32]};
            for k=1:2
                self.trendAxes(k)=axes(self.overviewPanel,'Position',trendLocations{k}, ...
                    'Box','off','FontSize',11,'Color','w','GridColor',[.85 .88 .92]);
                grid(self.trendAxes(k),'on');
                title(self.trendAxes(k),trendTitles{k});
                xlabel(self.trendAxes(k),'Time since EEG start (s)');
                yyaxis(self.trendAxes(k),'left'); ylabel(self.trendAxes(k),'Frequency (Hz)');
                ylim(self.trendAxes(k),config.bands(k,:));
                yyaxis(self.trendAxes(k),'right'); ylabel(self.trendAxes(k),'Rate (times/min)');
                ylim(self.trendAxes(k),config.bands(k,:)*60);
                yyaxis(self.trendAxes(k),'left');
                self.trendAxes(k).ButtonDownFcn=@(~,evt) self.inspectTime(evt.IntersectionPoint(1));
                p=pan(self.fig); setAllowAxesPan(p,self.trendAxes(k),true);
                setAxesPanMotion(p,self.trendAxes(k),'horizontal');
            end
            linkaxes(self.trendAxes,'x');
            self.windowMenu=uicontrol(self.fig,'Style','popupmenu','String', ...
                {'Entire recording','1 minute','5 minutes','15 minutes','60 minutes'}, ...
                'Units','normalized','Position',[.04 .15 .18 .035],'Visible','off', ...
                'Callback',@(~,~) self.changeWindow());
            self.viewportSlider=uicontrol(self.fig,'Style','slider','Min',0,'Max',1,'Value',0, ...
                'Units','normalized','Position',[.25 .155 .71 .025],'Visible','off', ...
                'Callback',@(obj,~) self.setViewportStart(obj.Value));
            self.viewportListener=addlistener(self.viewportSlider,'ContinuousValueChange', ...
                @(obj,~) self.setViewportStart(obj.Value));
        end

        function update(self,ep)
            if ~isgraphics(self.fig) || self.updating; return; end
            self.updating=true; cleanup=onCleanup(@() self.unlock()); %#ok<NASGU>
            epochChanged=ep~=self.position;
            self.position=ep; self.epochEdit.String=num2str(ep);
            self.refreshCatalog();
            if epochChanged; self.followEpoch(); end
            for marker=self.trendPositions(isgraphics(self.trendPositions))
                marker.Value=(ep-.5)*4;
            end
            % Clear before any I/O, including errors and unavailable H5 files.
            for h=[self.sensorLine self.filteredLine self.sensorSpectrum self.sensorPeaks]
                set(h,'XData',NaN,'YData',NaN);
            end
            delete(self.emgLine(isgraphics(self.emgLine)));
            delete(self.emgSpectrum(isgraphics(self.emgSpectrum)));
            delete(self.emgPeaks(isgraphics(self.emgPeaks)));
            self.emgLine=gobjects(0); self.emgSpectrum=gobjects(0); self.emgPeaks=gobjects(0);
            try
                E=VS3_sensorTool('epoch',self.sensor,self.config.offset,ep,self.config.bands);
                set(self.sensorLine,'XData',E.time,'YData',E.raw);
                if E.valid
                    set(self.filteredLine,'XData',E.time,'YData',E.filtered+mean(E.raw));
                    self.drawSpectrum(self.sensorSpectrum,self.sensorPeaks,E.spectrum);
                    sensorText=self.describe(E.spectrum,'ADC');
                    if E.spectrum.harmonic; sensorText=[sensorText '  [heart candidate may be a respiratory harmonic]']; end
                else
                    sensorText=['No valid sensor estimate: ' E.reason];
                end
                emgText={}; colors=lines(numel(self.config.channels));
                for k=1:numel(self.config.channels)
                    channel=self.config.channels(k);
                    if isempty(self.catalogProvider)
                        [x,fs,unit]=self.provider(channel,ep); processing='Provided signal';
                    else
                        [x,fs,unit,processing]=self.provider(self.channelKeys{channel},ep);
                    end
                    x=double(x(:));
                    if numel(x)~=round(4*fs); error('VS3:sensorEmg','Incomplete recorded epoch.'); end
                    R=VS3_sensorTool('spectrum',x,fs,self.config.bands);
                    name=self.channelNames{channel};
                    self.emgLine(k)=line(self.axesList(2),(ep-1)*4+(0:numel(x)-1)'/fs,x,'Color',colors(k,:),'DisplayName',name);
                    self.emgSpectrum(k)=line(self.axesList(4),R.f,R.a,'Color',colors(k,:),'DisplayName',name);
                    self.emgPeaks(k)=line(self.axesList(4),R.frequency,R.amplitude,'LineStyle','none','Marker','o', ...
                        'Color',colors(k,:),'HandleVisibility','off');
                    emgText{end+1}=sprintf('%s [%s]\n%s',name,processing,self.describe(R,unit)); %#ok<AGROW>
                    ylabel(self.axesList(2),unit); ylabel(self.axesList(4),['Amplitude (' unit ')']);
                end
                if ~isempty(self.emgLine)
                    legend(self.axesList(2),self.emgLine,'Location','best','Interpreter','none');
                    legend(self.axesList(4),self.emgSpectrum,'Location','best','Interpreter','none');
                end
                for k=1:2; xlim(self.axesList(k),[(ep-1)*4 ep*4]); end
                self.status.String=sprintf(['Epoch %d | SHARED EEG time: %.0f-%.0f s\n' ...
                    'Sensor data shifted onto EEG clock: sensor starts %+.6f s after EEG (already applied).\n' ...
                    'Sensor: %s\nEMG band maxima (current main-window processing):\n%s\n' ...
                    'Candidates only. FFT spacing: 0.25 Hz (15/min). Axes have different physical units. Clock synchronization unverified.'], ...
                    ep,(ep-1)*4,ep*4,self.config.offset,sensorText,strjoin(emgText,newline));
            catch err
                self.status.String=sprintf('Epoch %d: %s',ep,err.message);
                warning('VS3:sensorDisplay','%s',err.message);
            end
        end

        function drawSpectrum(~,curve,markers,R)
            set(curve,'XData',R.f,'YData',R.a);
            set(markers,'XData',R.frequency,'YData',R.amplitude);
        end

        function text=describe(~,R,unit)
            text=sprintf('Resp %.2f Hz / %.0f per min / %.3f s / %.3g %s; Heart %.2f Hz / %.0f per min / %.3f s / %.3g %s', ...
                R.frequency(1),60*R.frequency(1),R.period(1),R.amplitude(1),unit, ...
                R.frequency(2),60*R.frequency(2),R.period(2),R.amplitude(2),unit);
        end

        function changeChannel(self)
            if isempty(self.channelMenu.Value)
                self.channelMenu.Value=self.config.channels; return
            end
            self.config.channels=self.channelMenu.Value;
            self.config.channelKeys=self.channelKeys(self.config.channels);
            self.overviewDirty=true;
            self.update(self.position);
            if strcmp(self.overviewPanel.Visible,'on'); self.showOverview(); end
        end

        function refreshCatalog(self)
            if isempty(self.catalogProvider); return; end
            [names,keys]=self.catalogProvider();
            if isfield(self.config,'channelKeys')
                selected=self.config.channelKeys;
            else
                % Older saved settings used original recorded channel indices.
                selected=arrayfun(@num2str,self.config.channels,'UniformOutput',false);
            end
            [found,rows]=ismember(selected,keys);
            self.config.channels=rows(found);
            self.config.channelKeys=selected(found);
            self.channelNames=names; self.channelKeys=keys;
            if ~isempty(self.channelMenu) && isgraphics(self.channelMenu)
                self.channelMenu.String=names; self.channelMenu.Value=self.config.channels;
            end
        end

        function go(self,ep)
            if ~isfinite(ep) || ep<1; self.epochEdit.String=num2str(self.position); return; end
            self.navigate(round(ep));
        end

        function frequencyRange(self,value)
            limits=[20 100]; xlim(self.axesList(4),[0 limits(value)]);
        end

        function showOverview(self,force)
            if nargin<2; force=false; end
            if self.overviewBusy || ~isgraphics(self.fig); return; end
            self.refreshCatalog();
            selectedKeys=self.channelKeys(self.config.channels);
            if ~isequal(selectedKeys,self.timelineKeys); self.overviewDirty=true; end
            viewportStart=self.trendAxes(1).XLim(1);
            self.detailPanel.Visible='off'; self.overviewPanel.Visible='on';
            self.windowMenu.Visible='on'; self.viewportSlider.Visible='on';
            if isempty(self.timeline) || self.overviewDirty || force
                self.overviewBusy=true;
                busyCleanup=onCleanup(@() self.finishOverview()); %#ok<NASGU>
                n=max(1,floor((self.sensor.time(end)+self.config.offset)/4));
                if isfield(self.config,'recordingEpochCount'); n=self.config.recordingEpochCount; end
                channels=self.config.channels;
                if ~isempty(self.catalogProvider); channels=self.channelKeys(channels); end
                w=[];
                if strcmp(self.fig.Visible,'on')
                    w=waitbar(0,'Finding band maxima in 4-second windows...', ...
                        'Name','Sensor comparison','WindowStyle','modal', ...
                        'CreateCancelBtn',@(obj,~) setappdata(ancestor(obj,'figure'),'cancel',true));
                    setappdata(w,'cancel',false);
                end
                waitCleanup=onCleanup(@() self.closeProgress(w)); %#ok<NASGU>
                try
                    T=VS3_sensorTool('timeline',self.sensor,self.config.offset,self.config.bands, ...
                        1:n,self.provider,channels,@(k,count) self.trendProgress(w,k,count));
                catch err
                    self.status.String=['Could not build trends: ' err.message]; return;
                end
                if ~isgraphics(self.fig); return; end
                self.timeline=T; self.overviewDirty=T.cancelled;
                self.timelineKeys=selectedKeys;
            end
            self.drawTrends();
            self.setViewportStart(viewportStart);
        end

        function drawTrends(self)
            T=self.timeline; colors=[.88 .43 .20;.48 .37 .72;.14 .58 .48;.67 .43 .55];
            titles={'Respiration candidates','Heart candidates'};
            self.trendPositions=gobjects(1,2);
            for band=1:2
                ax=self.trendAxes(band); yyaxis(ax,'left'); cla(ax); hold(ax,'on');
                curve=plot(ax,T.time,T.sensorFrequency(:,band),'Color',[.08 .45 .83], ...
                    'LineWidth',1.5,'DisplayName','Sensor');
                self.trendTip(curve,T.sensorFrequency(:,band),T.sensorAmplitude(:,band),'ADC counts');
                for k=1:numel(self.config.channels)
                    color=colors(mod(k-1,size(colors,1))+1,:);
                    curve=plot(ax,T.time,T.recordedFrequency(:,band,k),'Color',color,'LineWidth',1.2, ...
                        'LineStyle','-','DisplayName',self.channelNames{self.config.channels(k)});
                    self.trendTip(curve,T.recordedFrequency(:,band,k),T.recordedAmplitude(:,band,k),'recorded units');
                    if band==2
                        mask=T.recordedHarmonic(:,k);
                        plot(ax,T.time(mask),T.recordedFrequency(mask,band,k),'x','Color',color,'HandleVisibility','off','HitTest','off');
                    end
                end
                if band==2
                    mask=T.sensorHarmonic;
                    plot(ax,T.time(mask),T.sensorFrequency(mask,band),'x','Color',[.08 .45 .83],'HandleVisibility','off','HitTest','off');
                end
                self.trendPositions(band)=xline(ax,(self.position-.5)*4,'--', ...
                    'Color',[.55 .59 .65],'HandleVisibility','off','HitTest','off');
                ylim(ax,self.config.bands(band,:)); ylabel(ax,'Frequency (Hz)');
                yyaxis(ax,'right'); ylim(ax,self.config.bands(band,:)*60); ylabel(ax,'Rate (times/min)');
                ax.YAxis(2).TickValues=ax.YAxis(1).TickValues*60;
                ax.YAxis(1).Color=[.22 .28 .36]; ax.YAxis(2).Color=[.40 .46 .54];
                yyaxis(ax,'left'); title(ax,titles{band}); xlabel(ax,'Time since EEG start (s)');
                legend(ax,'Location','northeastoutside','Interpreter','none','Box','off'); grid(ax,'on'); hold(ax,'off');
            end
            self.status.String=sprintf(['4-second windows | strongest local peak in each candidate band | frequency spacing 0.25 Hz = 15 times/min\n' ...
                'Sensor and selected channels share the EEG time axis. Gaps / flagged sensor windows remain empty.\n' ...
                'Click a curve to inspect that epoch. Use the data cursor for frequency and amplitude. x marks possible respiratory harmonics.\n' ...
                'Main-window filters apply to recorded channels. Refresh trends after changing filters or channels. Candidates are not confirmed beats.']);
            if T.cancelled; self.status.String=[self.status.String newline 'Calculation cancelled: partial trends shown. Refresh to finish.']; end
        end

        function trendTip(self,curve,frequency,amplitude,unit)
            curve.ButtonDownFcn=@(~,evt) self.inspectTime(evt.IntersectionPoint(1));
            curve.DataTipTemplate.DataTipRows=[ ...
                dataTipTextRow('EEG time (s)',self.timeline.time); ...
                dataTipTextRow('Frequency (Hz)',frequency); ...
                dataTipTextRow('Rate (times/min)',frequency*60); ...
                dataTipTextRow(['Amplitude (' unit ')'],amplitude)];
        end

        function showDetails(self)
            self.overviewPanel.Visible='off'; self.detailPanel.Visible='on';
            self.windowMenu.Visible='off'; self.viewportSlider.Visible='off';
            self.update(self.position);
        end

        function inspectTime(self,time)
            self.go(floor(max(0,time)/4)+1);
            self.showDetails();
            if strcmp(self.fig.Visible,'on'); figure(self.fig); end
        end

        function changeWindow(self)
            widths=[Inf 60 300 900 3600];
            self.setWindowSeconds(widths(self.windowMenu.Value));
        end

        function setWindowSeconds(self,seconds)
            validateattributes(seconds,{'numeric'},{'scalar','positive'});
            self.windowSeconds=seconds;
            self.setViewportStart((self.position-.5)*4-seconds/2);
        end

        function followEpoch(self)
            if isempty(self.timeline); return; end
            limits=self.trendAxes(1).XLim;
            if (self.position-1)*4<limits(1) || self.position*4>limits(2)
                self.setViewportStart((self.position-.5)*4-self.windowSeconds/2);
            end
        end

        function editSettings(self)
            c=self.config;
            answer=inputdlg({'Sensor start minus EEG start (s; positive = later):', ...
                'Respiration candidate band (Hz, low high):','Heart candidate band (Hz, low high):'}, ...
                'Bands & alignment',[1 62], ...
                {num2str(c.offset,12),num2str(c.bands(1,:)),num2str(c.bands(2,:))});
            if isempty(answer); return; end
            resp=sscanf(answer{2},'%f')'; heart=sscanf(answer{3},'%f')';
            try
                if numel(resp)~=2 || numel(heart)~=2; error('VS3:sensorBand','Enter exactly two frequencies per band.'); end
                self.setAnalysis(str2double(answer{1}),[resp;heart]);
            catch err
                errordlg(err.message,'Bands & alignment');
            end
        end

        function setAnalysis(self,offset,bands)
            validateattributes(offset,{'numeric'},{'scalar','finite'});
            VS3_sensorTool('spectrum',zeros(800,1),200,bands);
            if any(bands(:)>20); error('VS3:sensorBand','Candidate bands must be within the sensor 20 Hz low-pass range.'); end
            self.config.offset=offset; self.config.bands=bands;
            self.timeline=[]; self.overviewDirty=true;
            for k=3:4
                delete(findall(self.axesList(k),'Type','ConstantLine'));
                xline(self.axesList(k),bands(1,1),':','Resp.'); xline(self.axesList(k),bands(1,2),':');
                xline(self.axesList(k),bands(2,1),'--','Heart'); xline(self.axesList(k),bands(2,2),'--');
            end
            if ~isempty(self.settingsChanged); self.settingsChanged(); end
            self.update(self.position);
            if strcmp(self.overviewPanel.Visible,'on'); self.showOverview(); end
        end

        function setViewportStart(self,start)
            if isempty(self.timeline); return; end
            duration=max(4,self.timeline.epochs(end)*4);
            width=min(self.windowSeconds,duration); maximum=max(0,duration-width);
            start=min(max(start,0),maximum);
            for ax=self.trendAxes; xlim(ax,[start start+width]); end
            self.viewportSlider.Max=max(maximum,1); self.viewportSlider.Value=start;
            self.viewportSlider.Enable='on'; if maximum==0; self.viewportSlider.Enable='off'; end
            self.viewportSlider.SliderStep=min([4 max(4,width*.8)]/max(maximum,1),1);
        end

        function keepGoing=trendProgress(self,w,k,n)
            keepGoing=isgraphics(self.fig);
            if ~isempty(w)
                keepGoing=keepGoing && isgraphics(w) && ~getappdata(w,'cancel');
                if keepGoing && (mod(k,25)==1 || k==n)
                    waitbar(k/n,w,sprintf('Window %d / %d - 4 seconds per window',k,n)); drawnow;
                end
            end
        end

        function closeProgress(~,w)
            if ~isempty(w) && isgraphics(w); delete(w); end
        end

        function finishOverview(self)
            self.overviewBusy=false;
        end

        function unlock(self)
            self.updating=false;
        end

        function delete(self)
            if ~isempty(self.fig) && isgraphics(self.fig); delete(self.fig); end
        end
    end
end
