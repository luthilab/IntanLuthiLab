classdef VS3_videoPanel < handle
    %VS3_VIDEOPANEL The video column of the main window (Tools > Video).
    %
    % When a video is opened, a column appears right of the traces (VS3_tracesPlot.layoutAxes makes
    % the traces narrower) and disappears when the last video is closed. It shows the frame of the
    % Raspberry Pi camera and/or of the thermal camera at the start of the epoch on screen, follows
    % every move of the main window, and plays the 4 s of the epoch (button Play or the space bar),
    % with a black line running over the traces at the time of the frame.
    %
    % View (menu of the column, or Tools > Video > Show):
    %   'pi'       the Pi camera            'thermal'  the thermal video
    %   'both'     one above the other      'overlap'  the thermal video over the Pi camera, its warm
    %              parts opaque (transparency with the slider), after Tools > Video > Align thermal
    %              on Pi camera (points clicked on both videos); until then it is simply fitted in.
    %
    % ROIs (Tools > Video > Add ROI): rectangles drawn on a video. For every frame of the epoch the
    % Pi ROIs give their movement (dx, dy, tracked from the first frame of the epoch, pixels) and
    % brightness (mean gray level), the thermal ROIs their mean (degC or counts). The traces of the
    % epoch are drawn under the videos, with the amplitude spectrum of the one clicked.
    % roiBreathing measures the breathing rate seen by a Pi ROI in chosen epochs (Tools > Summary
    % figure); the results are kept in breathing and saved with the settings.
    %
    % Alejandro Osorio-Forero with Claude, 2026.

    properties
        pi = []                 % VS3_video of the Raspberry Pi camera ([] = none)
        thermal = []            % VS3_video of the thermal camera ([] = none)
        overlay = []            % 3 x 3 affine transform, thermal pixel [x y 1] -> Pi pixel; [] = fitted in
        alpha = 0.6             % opacity of the warmest parts of the thermal video over the Pi camera
        rois = struct('video', {}, 'rect', {}, 'name', {}) % rect = [x y w h], pixels of that video
        roiOn = true            % measure the ROIs at every epoch
        blind = false           % blind scoring (Import randomly): no file names
        keyFunction = []        % key presses in the column go to the main window (scoring keys)
        warmSpot = []           % the animal in the thermal video (VS3_videoMotion 'warmSpot'), kept for this video
        breathing = struct('roi', {}, 'rect', {}, 'offset', {}, 'timing', {}, 'epochs', {}, 'frequency', {}, 'amplitude', {})
                                % breathing seen by Pi ROIs (roiBreathing), one per ROI measured to the end
    end

    properties (SetAccess = private)
        mode = 'both'           % 'pi' | 'thermal' | 'both' | 'overlap'
        panel                   % uipanel in the main figure
        plot = []               % VS3_tracesPlot of the main window
        roiData = struct('name', {}, 'unit', {}, 't', {}, 'v', {}) % ROI traces of epoch roiEpoch
        roiEpoch = 0
    end

    properties (Access = private)
        axPi = []
        axTh = []
        axRoi = []
        axFft = []
        imPi = []
        imTh = []
        surfTh = []             % thermal texture over the Pi camera (overlap)
        boxes = gobjects(0)
        playBtn
        speedMenu
        viewMenu
        alphaSlider
        info
        roiSel = 1
        roiLines = gobjects(0)
        playLines = gobjects(0)
        shown = [NaN NaN]       % frames on screen (Pi, thermal)
        clim = []               % color limits of the thermal video for this epoch
        playTimer = []          % timer of the playback
        playT = [0 4]           % EEG times played
        playClock
        epochShown = NaN
    end

    properties (Constant)
        modes = {'pi', 'thermal', 'both', 'overlap'}
        modeNames = {'Pi camera', 'Thermal', 'Pi and thermal', 'Thermal over Pi'}
        speeds = [1 0.5 0.25 2]
    end

    methods
        function self = VS3_videoPanel(fig)
            white = [1 1 1];
            self.panel = uipanel('Parent', fig, 'Units', 'normalized', 'Position', [.70 .25 .29 .72], ...
                'BorderType', 'none', 'BackgroundColor', white, 'Visible', 'off', 'Tag', 'VS3video');
            p = self.panel;
            setappdata(p, 'VS3_videoPanel', self); % found from the figure (tests)
            self.playBtn = uicontrol(p, 'Style', 'pushbutton', 'String', 'Play 4 s', 'Units', 'normalized', ...
                'Position', [0 .95 .2 .045], 'Callback', @(o,~) self.button(o, @self.togglePlay), ...
                'TooltipString', 'Play the epoch (space bar)');
            self.speedMenu = uicontrol(p, 'Style', 'popupmenu', 'String', {'1x', '0.5x', '0.25x', '2x'}, ...
                'Units', 'normalized', 'Position', [.21 .95 .14 .045], 'BackgroundColor', white, ...
                'TooltipString', 'Speed of the playback');
            self.viewMenu = uicontrol(p, 'Style', 'popupmenu', 'String', self.modeNames, 'Value', 3, ...
                'Units', 'normalized', 'Position', [.36 .95 .3 .045], 'BackgroundColor', white, ...
                'Callback', @(o,~) self.setMode(self.modes{o.Value}));
            self.alphaSlider = uicontrol(p, 'Style', 'slider', 'Min', 0, 'Max', 1, 'Value', self.alpha, ...
                'Units', 'normalized', 'Position', [.68 .958 .32 .03], 'Visible', 'off', ...
                'TooltipString', 'Opacity of the thermal video', 'Callback', @(o,~) self.setAlpha(o.Value));
            self.info = uicontrol(p, 'Style', 'text', 'String', '', 'Units', 'normalized', ...
                'Position', [0 .885 1 .06], 'BackgroundColor', white, 'HorizontalAlignment', 'left', ...
                'FontSize', 8, 'ForegroundColor', [.3 .3 .3]);
            % the scoring keys keep working when a control of the column has the focus
            for c = [self.playBtn, self.speedMenu, self.viewMenu, self.alphaSlider]
                c.KeyPressFcn = @(~,e) self.forwardKey(e);
            end
        end

        function attach(self, plot)
            % attach  Follow this VS3_tracesPlot (a new one after Import or Reverse all changes).
            self.stop()
            self.plot = plot;
            plot.video = self;
            self.roiEpoch = 0;
            self.epochShown = NaN;
            self.refresh()
        end

        function tf = isOpen(self)
            tf = ~isempty(self.pi) || ~isempty(self.thermal);
        end

        function setVideo(self, kind, V)
            % setVideo  Show video V (VS3_video) as the 'pi' or 'thermal' video ([] closes it).
            self.stop()
            old = self.(kind);
            self.(kind) = V;
            if ~isempty(old) && ~isequal(old, V); delete(old); end
            if isempty(V)
                self.rois(strcmp({self.rois.video}, kind)) = [];
                if strcmp(kind, 'thermal'); self.overlay = []; end
            end
            if strcmp(kind, 'thermal'); self.warmSpot = []; end
            if ~isempty(self.pi) && ~isempty(self.thermal) && ~isempty(V)
                self.mode = 'both';
            end
            self.roiEpoch = 0;
            self.refresh()
        end

        function setMode(self, mode)
            % setMode  'pi', 'thermal', 'both' or 'overlap' (the videos that are open).
            if ~any(strcmp(mode, self.modes)); return; end
            self.stop()
            self.mode = mode;
            self.refresh()
        end

        function m = shownMode(self)
            % shownMode  What is shown: the mode, unless one of its videos is not open.
            m = self.mode;
            if isempty(self.thermal); m = 'pi'; elseif isempty(self.pi); m = 'thermal'; end
        end

        function place(self, pos)
            % place  Position of the column in the figure (from VS3_tracesPlot.layoutAxes).
            self.panel.Position = pos;
            self.panel.Visible = 'on';
        end

        function hide(self)
            self.stop()
            self.panel.Visible = 'off';
        end

        %% Follow the main window
        function update(self)
            % update  The frames at the start of the epoch on screen (called by updatePlot).
            if isempty(self.plot) || ~self.isOpen() || ~isgraphics(self.panel); return; end
            ep = self.plot.position;
            if ep == self.epochShown && ~isempty(self.playTimer) && isvalid(self.playTimer) && strcmp(self.playTimer.Running, 'on')
                return
            end
            self.stop()
            t0 = self.plot.second(1, ep);
            if ep ~= self.epochShown; self.clim = []; end
            self.epochShown = ep;
            try
                self.showAt(t0)
                if self.roiOn && ~isempty(self.rois) && self.roiEpoch ~= ep
                    self.measureRois()
                end
                self.drawRois()
            catch err % a frame that cannot be read must not stop the scoring
                self.shown = [NaN NaN];
                self.info.String = sprintf('The video could not be shown here: %s', err.message);
            end
        end

        function refresh(self)
            % refresh  Rebuild the axes of the column (view, videos or ROIs changed).
            if ~isgraphics(self.panel); return; end
            if ~isempty(self.plot) && isvalid(self.plot)
                self.plot.layoutAxes()   % room right of the traces (or given back)
            end
            m = self.shownMode();
            self.viewMenu.Value = find(strcmp(m, self.modes));
            self.viewMenu.Enable = onOff(~isempty(self.pi) && ~isempty(self.thermal));
            self.alphaSlider.Visible = onOff(strcmp(m, 'overlap'));
            old = [self.axPi, self.axTh, self.axRoi, self.axFft];
            delete(old(isgraphics(old)))
            [self.axPi, self.axTh, self.axRoi, self.axFft, self.imPi, self.imTh, self.surfTh] = deal([]);
            self.boxes = gobjects(0);
            self.roiLines = gobjects(0);
            self.playLines = gobjects(0);
            self.shown = [NaN NaN];
            if ~self.isOpen(); return; end

            hasRoi = ~isempty(self.rois);
            bottom = 0;
            if hasRoi; bottom = .31; end
            top = .875;
            hPi = 0; hTh = 0;
            if ~isempty(self.pi); hPi = self.pi.height/self.pi.width; end
            if ~isempty(self.thermal); hTh = self.thermal.height/self.thermal.width; end
            switch m
                case {'pi', 'overlap'}; parts = {'pi', top - bottom};
                case 'thermal'; parts = {'thermal', top - bottom};
                case 'both'; f = hPi/(hPi + hTh); parts = {'pi', (top - bottom)*f; 'thermal', (top - bottom)*(1 - f)};
            end
            y = top;
            for i = 1:size(parts, 1)
                y = y - parts{i, 2};
                ax = axes('Parent', self.panel, 'Units', 'normalized', 'Position', [0 y + .005 1 parts{i, 2} - .035], ...
                    'YDir', 'reverse', 'Visible', 'off', 'SortMethod', 'childorder', 'PickableParts', 'all');
                ax.Toolbar = [];
                disableDefaultInteractivity(ax)
                if strcmp(parts{i, 1}, 'pi'); self.axPi = ax; else; self.axTh = ax; colormap(ax, hot(256)); end
            end
            if strcmp(m, 'overlap'); colormap(self.axPi, hot(256)); end
            if hasRoi
                self.axRoi = axes('Parent', self.panel, 'Units', 'normalized', 'Position', [.02 .04 .62 .23], ...
                    'TickDir', 'out', 'YColor', 'none', 'FontSize', 7, 'Box', 'off');
                self.axFft = axes('Parent', self.panel, 'Units', 'normalized', 'Position', [.72 .07 .27 .2], ...
                    'TickDir', 'out', 'FontSize', 7, 'Box', 'off');
                xlabel(self.axFft, 'Hz', 'FontSize', 7)
                self.axRoi.Toolbar = [];
                self.axFft.Toolbar = [];
            end
            self.epochShown = NaN;
            self.update()
        end

        %% Frames
        function showAt(self, t)
            % showAt  The frames on screen at EEG time t (s since EEG sample 1).
            m = self.shownMode();
            txt = sprintf('EEG %s (epoch %d)', clockText(t), floor(t/4) + 1);
            if any(strcmp(m, {'pi', 'both', 'overlap'}))
                [~, s] = self.drawPi(t);
                txt = sprintf('%s   |   %s', txt, s);
            end
            if any(strcmp(m, {'thermal', 'both', 'overlap'}))
                [~, s] = self.drawThermal(t);
                txt = sprintf('%s   |   %s', txt, s);
            end
            self.info.String = txt;
            % the black line over the traces (and the ROI traces) during the playback
            for L = self.playLines(isgraphics(self.playLines))
                L.XData = [t t];
            end
        end

        function [k, s] = drawPi(self, t)
            V = self.pi;
            k = V.frameAt(t);
            s = sprintf('Pi: %s', self.alignText(V));
            if isnan(k)
                if ~isempty(self.imPi) && isgraphics(self.imPi); self.imPi.Visible = 'off'; end
                title(self.axPi, 'Pi camera: no frame at this time', 'FontSize', 8, 'FontWeight', 'normal', 'Visible', 'on')
                self.shown(1) = NaN;
                return
            end
            if k ~= self.shown(1)
                img = V.frame(k);
                if isempty(self.imPi) || ~isgraphics(self.imPi)
                    self.imPi = image(self.axPi, 'CData', img, 'HitTest', 'off');
                    axis(self.axPi, 'image')
                    self.axPi.XLim = [.5 V.width + .5];
                    self.axPi.YLim = [.5 V.height + .5];
                else
                    set(self.imPi, 'CData', img, 'Visible', 'on')
                end
                self.shown(1) = k;
            end
            ttl = sprintf('Pi camera, frame %d (%.3f s of the video)', k, V.time(k));
            if self.blind; ttl = sprintf('Pi camera, frame %d', k); end
            title(self.axPi, ttl, 'FontSize', 8, 'FontWeight', 'normal', 'Interpreter', 'none', 'Visible', 'on')
        end

        function [k, s] = drawThermal(self, t)
            V = self.thermal;
            k = V.frameAt(t);
            over = strcmp(self.shownMode(), 'overlap');
            s = sprintf('thermal: %s', self.alignText(V));
            ax = self.axTh;
            if over; ax = self.axPi; end
            if isnan(k)
                if ~isempty(self.imTh) && isgraphics(self.imTh); self.imTh.Visible = 'off'; end
                if ~isempty(self.surfTh) && isgraphics(self.surfTh); self.surfTh.Visible = 'off'; end
                if ~over; title(ax, 'Thermal: no frame at this time', 'FontSize', 8, 'FontWeight', 'normal', 'Visible', 'on'); end
                self.shown(2) = NaN;
                return
            end
            if k ~= self.shown(2)
                img = V.frame(k);
                if isempty(self.clim)
                    v = img(isfinite(img));
                    self.clim = [0 1];
                    if ~isempty(v)
                        self.clim = double(prctile(v, [1 99.8]));
                        if diff(self.clim) <= 0; self.clim = self.clim + [-.5 .5]; end
                    end
                end
                if over
                    self.drawOverlay(img)
                else
                    if isempty(self.imTh) || ~isgraphics(self.imTh)
                        self.imTh = image(ax, 'CData', img, 'CDataMapping', 'scaled', 'HitTest', 'off');
                        axis(ax, 'image')
                        ax.XLim = [.5 V.width + .5];
                        ax.YLim = [.5 V.height + .5];
                    else
                        set(self.imTh, 'CData', img, 'Visible', 'on')
                    end
                    ax.CLim = self.clim;
                end
                self.shown(2) = k;
            end
            u = 'counts';
            if strcmp(V.unit, 'degC'); u = [char(176) 'C']; end
            if ~over
                title(ax, sprintf('Thermal, frame %d (%.4g - %.4g %s)', k, self.clim(1), self.clim(2), u), ...
                    'FontSize', 8, 'FontWeight', 'normal', 'Visible', 'on')
            end
        end

        function drawOverlay(self, img)
            % the thermal frame over the Pi camera: a texture placed by the overlay transform, the
            % cold parts transparent and the warmest ones with the opacity self.alpha
            ax = self.axPi;
            T = self.overlayTransform();
            [W, H] = deal(self.thermal.width, self.thermal.height);
            c = [.5 .5 1; W+.5 .5 1; .5 H+.5 1; W+.5 H+.5 1]*T';
            X = reshape(c(:, 1), 2, 2)';
            Y = reshape(c(:, 2), 2, 2)';
            lo = self.clim(1) + 0.4*diff(self.clim); % below: transparent
            a = min(max((double(img) - lo)/(self.clim(2) - lo), 0), 1).^0.7*self.alpha;
            a(~isfinite(a)) = 0;
            if isempty(self.surfTh) || ~isgraphics(self.surfTh)
                self.surfTh = surface(ax, X, Y, zeros(2), 'CData', img, 'FaceColor', 'texturemap', ...
                    'EdgeColor', 'none', 'CDataMapping', 'scaled', 'FaceAlpha', 'texturemap', ...
                    'AlphaDataMapping', 'none', 'AlphaData', a, 'HitTest', 'off');
            else
                set(self.surfTh, 'XData', X, 'YData', Y, 'CData', img, 'AlphaData', a, 'Visible', 'on')
            end
            ax.CLim = self.clim;
            ax.ALim = [0 1];
        end

        function T = overlayTransform(self)
            % overlayTransform  Thermal pixel -> Pi pixel: the alignment, or the thermal frame fitted in
            T = self.overlay;
            if isempty(T)
                s = min(self.pi.width/self.thermal.width, self.pi.height/self.thermal.height);
                d = ([self.pi.width self.pi.height] - s*[self.thermal.width self.thermal.height])/2;
                T = [s 0 d(1); 0 s d(2); 0 0 1];
            end
        end

        function setAlpha(self, a)
            self.alpha = a;
            self.shown(2) = NaN;
            if ~isnan(self.epochShown); self.showAt(self.plot.second(1, self.epochShown)); end
        end

        function s = alignText(self, V)
            if ~isempty(V.timeMap)
                s = 'recorder timing';
            elseif self.blind
                s = sprintf('offset %.3f s', V.offset);
            else
                s = sprintf('offset %.3f s (%s)', V.offset, V.offsetSource);
            end
        end

        %% Playback of the epoch
        function togglePlay(self)
            if ~isempty(self.playTimer) && isvalid(self.playTimer) && strcmp(self.playTimer.Running, 'on')
                self.stop()
                return
            end
            if isempty(self.plot) || ~self.isOpen(); return; end
            t0 = self.plot.second(1, self.plot.position);
            self.playT = [t0, t0 + 4];
            self.addPlayLines(t0)
            if isempty(self.playTimer) || ~isvalid(self.playTimer)
                self.playTimer = timer('ExecutionMode', 'fixedSpacing', 'Period', 0.02, 'BusyMode', 'drop', ...
                    'TimerFcn', @(~,~) self.tick(), 'ErrorFcn', @(~,~) self.stop());
            end
            self.playClock = tic;
            self.playBtn.String = 'Pause';
            start(self.playTimer)
        end

        function stop(self)
            if ~isempty(self.playTimer) && isvalid(self.playTimer) && strcmp(self.playTimer.Running, 'on')
                stop(self.playTimer)
            end
            if ~isempty(self.playBtn) && isgraphics(self.playBtn); self.playBtn.String = 'Play 4 s'; end
            delete(self.playLines(isgraphics(self.playLines)))
            self.playLines = gobjects(0);
        end

        function tick(self)
            if ~isgraphics(self.panel); self.stop(); return; end
            t = self.playT(1) + toc(self.playClock)*self.speeds(self.speedMenu.Value);
            if t >= self.playT(2)
                self.stop()
                return
            end
            try
                self.showAt(t)
            catch err
                self.stop()
                self.info.String = sprintf('Playback stopped: %s', err.message);
            end
            drawnow limitrate
        end

        %% ROIs
        function addRoi(self, kind)
            % addRoi  Draw a rectangle (two opposite corners) on the 'pi' or 'thermal' video.
            V = self.(kind);
            if isempty(V); return; end
            self.stop()
            if strcmp(self.shownMode(), 'overlap') || (strcmp(kind, 'pi') && isempty(self.axPi)) || ...
                    (strcmp(kind, 'thermal') && isempty(self.axTh))
                self.setMode('both')
            end
            ax = self.axPi;
            if strcmp(kind, 'thermal'); ax = self.axTh; end
            title(ax, 'Click two opposite corners of the ROI (right click: cancel)', 'Color', [.8 .2 .2], 'Visible', 'on')
            [x, y, b] = clicks(ax, 2);
            title(ax, '', 'Color', 'k')
            if numel(x) < 2 || any(b ~= 1); self.epochShown = NaN; self.update(); return; end
            x = min(max(sort(x), .5), V.width + .5);
            y = min(max(sort(y), .5), V.height + .5);
            rect = [round(x(1) + .5), round(y(1) + .5), round(x(2) - x(1)), round(y(2) - y(1))];
            if any(rect(3:4) < 4)
                errordlg('The ROI must be at least 4 x 4 pixels.', 'Video ROI'); return
            end
            n = sum(strcmp({self.rois.video}, kind)) + 1;
            def = sprintf('Pi ROI %d', n);
            if strcmp(kind, 'thermal'); def = sprintf('Thermal ROI %d', n); end
            an = inputdlg('Name of the ROI:', 'Video ROI', [1 40], {def});
            if isempty(an); self.epochShown = NaN; self.update(); return; end
            self.rois(end+1) = struct('video', kind, 'rect', rect, 'name', strtrim(an{1}));
            self.roiEpoch = 0;
            self.refresh()
        end

        function removeRois(self, which)
            self.rois(which) = [];
            self.roiEpoch = 0;
            self.roiSel = 1;
            self.refresh()
        end

        function measureRois(self)
            % measureRois  The ROI traces of the epoch on screen, frame by frame.
            ep = self.plot.position;
            t0 = self.plot.second(1, ep);
            D = struct('name', {}, 'unit', {}, 't', {}, 'v', {});
            self.info.String = 'Measuring the ROIs of this epoch...';
            drawnow
            try
                for kind = {'pi', 'thermal'}
                    r = self.rois(strcmp({self.rois.video}, kind{1}));
                    V = self.(kind{1});
                    if isempty(r) || isempty(V); continue; end
                    k = V.framesBetween(t0, t0 + 4);
                    e = V.eegTimes();
                    if strcmp(kind{1}, 'pi')
                        D = [D, trackPi(V, k, e(k), r)]; %#ok<AGROW>
                    else
                        D = [D, thermalMeans(V, k, e(k), r)]; %#ok<AGROW>
                    end
                end
            catch err
                self.info.String = sprintf('The ROIs could not be measured: %s', err.message);
            end
            self.roiData = D;
            self.roiEpoch = ep;
            self.shown = [NaN NaN]; % the reading moved the video: frames read again
            self.showAt(t0)
        end

        function R = roiBreathing(self, which, epochs, progress)
            % roiBreathing  Breathing rate seen by the Pi ROI which (index in rois) in the given epochs:
            % the strongest peak of its movement between 0.5 and 5 Hz (as the respiration band of the
            % sensor), in dx or dy, whichever is larger. NaN in the epochs in which the ROI moved by more
            % than 1 pixel (the animal moving, not breathing; breathing in the nest is about 0.05 pixel)
            % or was tracked in less than 80 % of the frames. progress(k, n) returns false to stop
            % (R.cancelled). A result measured to the end is kept in breathing (one per ROI).
            if nargin < 4; progress = @(~, ~) true; end
            roi = self.rois(which);
            V = self.pi;
            if ~strcmp(roi.video, 'pi') || isempty(V); error('VS3_videoPanel:roi', 'Breathing is measured on a Pi ROI.'); end
            epochs = epochs(:);
            n = numel(epochs);
            R = struct('roi', roi.name, 'rect', roi.rect, 'offset', V.offset, 'timing', ~isempty(V.timeMap), ...
                'epochs', epochs, 'frequency', nan(n, 1), 'amplitude', nan(n, 1));
            cancelled = false;
            e = V.eegTimes();
            for i = 1:n
                if ~progress(i, n); cancelled = true; break; end
                t0 = self.plot.second(1, epochs(i));
                k = V.framesBetween(t0, t0 + 4);
                if numel(k) < 8; continue; end
                D = trackPi(V, k, e(k), roi);
                best = 0;
                for d = D(1:2)
                    v = d.v;
                    if mean(isfinite(v)) < 0.8 || max(v) - min(v) > 1; best = NaN; break; end
                    [f, a] = amplitudeSpectrum(d.t, v, t0);
                    in = find(f >= 0.5 & f <= 5);
                    in = in(in > 1 & in < numel(a));
                    in = in(a(in) > a(in - 1) & a(in) >= a(in + 1)); % local maxima, not the edge of a peak outside
                    [m, j] = max(a(in));
                    if ~isempty(m) && m > best
                        best = m;
                        R.frequency(i) = f(in(j));
                        R.amplitude(i) = m;
                    end
                end
                if isnan(best); R.frequency(i) = NaN; R.amplitude(i) = NaN; end
            end
            self.shown = [NaN NaN]; % the reading moved the video: frames read again
            self.showAt(self.plot.second(1, self.plot.position))
            if ~cancelled
                self.breathing(strcmp({self.breathing.roi}, roi.name)) = [];
                self.breathing(end+1) = R;
            end
            R.cancelled = cancelled;
        end

        function R = breathingOf(self, which)
            % breathingOf  The kept breathing of the Pi ROI which, if it was measured with this ROI and
            % this timing of the Pi video; [] otherwise
            R = [];
            roi = self.rois(which);
            V = self.pi;
            if isempty(V); return; end
            for B = self.breathing(:)'
                if strcmp(B.roi, roi.name) && isequal(B.rect, roi.rect) && B.offset == V.offset && B.timing == ~isempty(V.timeMap)
                    R = B;
                end
            end
        end

        function drawRois(self)
            % the rectangles on the videos, the ROI traces of the epoch and the spectrum of one
            delete(self.boxes(isgraphics(self.boxes)))
            self.boxes = gobjects(0);
            for i = 1:numel(self.rois)
                r = self.rois(i);
                if strcmp(r.video, 'pi'); ax = self.axPi; else; ax = self.axTh; end
                if strcmp(r.video, 'thermal') && strcmp(self.shownMode(), 'overlap') && ~isempty(self.axPi)
                    ax = self.axPi;  % the thermal rectangle where it falls on the Pi camera
                    T = self.overlayTransform();
                    c = [r.rect(1)-.5, r.rect(2)-.5, 1; r.rect(1)+r.rect(3)-.5, r.rect(2)-.5, 1; ...
                        r.rect(1)+r.rect(3)-.5, r.rect(2)+r.rect(4)-.5, 1; r.rect(1)-.5, r.rect(2)+r.rect(4)-.5, 1]*T';
                    self.boxes(end+1) = line(ax, c([1:4 1], 1), c([1:4 1], 2), 'Color', [.2 .8 1], 'HitTest', 'off');
                    continue
                end
                if isempty(ax) || ~isgraphics(ax); continue; end
                self.boxes(end+1) = rectangle(ax, 'Position', [r.rect(1:2) - .5, r.rect(3:4)], ...
                    'EdgeColor', [.2 .8 1], 'HitTest', 'off');
                self.boxes(end+1) = text(ax, r.rect(1) - .5, r.rect(2) - 1, r.name, 'Color', [.2 .8 1], ...
                    'FontSize', 7, 'VerticalAlignment', 'bottom', 'Interpreter', 'none', 'HitTest', 'off');
            end
            if isempty(self.axRoi) || ~isgraphics(self.axRoi); return; end
            cla(self.axRoi)
            cla(self.axFft)
            self.roiLines = gobjects(0);
            ep = self.plot.position;
            t0 = self.plot.second(1, ep);
            D = self.roiData;
            if self.roiEpoch ~= ep
                text(self.axRoi, .5, .5, 'ROIs not measured for this epoch (Tools > Video > Measure ROIs)', ...
                    'Units', 'normalized', 'HorizontalAlignment', 'center', 'FontSize', 7, 'Color', [.4 .4 .4])
                return
            end
            n = numel(D);
            cols = lines(max(n, 1));
            self.roiSel = min(max(self.roiSel, 1), max(n, 1));
            for i = 1:n
                v = D(i).v;
                g = v(isfinite(v));
                ran = 1;
                if numel(g) > 1 && range(g) > 0; ran = range(g); end
                y = (v - median(g))/ran*0.8 + (n - i + 1);
                w = 0.75;
                if i == self.roiSel; w = 1.5; end
                self.roiLines(i) = line(self.axRoi, D(i).t, y, 'Color', cols(i, :), 'LineWidth', w, ...
                    'ButtonDownFcn', @(~,~) self.selectRoi(i));
                text(self.axRoi, t0, n - i + 1.35, sprintf('%s (range %.3g %s)', D(i).name, ran, D(i).unit), ...
                    'FontSize', 6, 'Color', cols(i, :), 'Interpreter', 'none', 'Clipping', 'on')
            end
            self.axRoi.XLim = [t0, t0 + 4];
            self.axRoi.YLim = [.3, n + .9];
            if n > 0
                [f, a] = amplitudeSpectrum(D(self.roiSel).t, D(self.roiSel).v, t0);
                if ~isempty(f)
                    line(self.axFft, f, a, 'Color', cols(self.roiSel, :))
                    self.axFft.XLim = [0 max(f)];
                end
                title(self.axFft, D(self.roiSel).name, 'FontSize', 7, 'FontWeight', 'normal', 'Interpreter', 'none')
            end
        end

        function selectRoi(self, i)
            self.roiSel = i;
            self.drawRois()
        end

        %% Thermal over Pi camera
        function [ok, res] = alignOverlay(self, xyPi, xyThermal)
            % alignOverlay  Click the same points on the Pi camera and on the thermal video (at least
            % 3, Enter to finish): affine transform thermal -> Pi by least squares. From a script:
            % alignOverlay(xyPi, xyThermal), the points as rows [x y] in pixels of each video;
            % res = remaining error (root mean square, pixels of the Pi camera).
            ok = false;
            res = NaN;
            if isempty(self.pi) || isempty(self.thermal); return; end
            if nargin < 3
                self.setMode('both')
                title(self.axPi, 'Click at least 3 points that you can find in both videos, then Enter', ...
                    'Color', [.8 .2 .2], 'FontSize', 8, 'Visible', 'on')
                [xp, yp] = clicks(self.axPi, Inf);
                hp = line(self.axPi, xp, yp, 'LineStyle', 'none', 'Marker', '+', 'Color', 'c', 'MarkerSize', 10);
                n = numel(xp);
                if n < 3; delete(hp); self.refresh(); return; end
                title(self.axTh, sprintf('Click the same %d points, in the same order', n), ...
                    'Color', [.8 .2 .2], 'FontSize', 8, 'Visible', 'on')
                [xt, yt] = clicks(self.axTh, n);
                delete(hp)
                if numel(xt) < n; self.refresh(); return; end
            else
                xp = xyPi(:, 1); yp = xyPi(:, 2);
                xt = xyThermal(:, 1); yt = xyThermal(:, 2);
                n = numel(xp);
                if n < 3 || numel(xt) ~= n; error('VS3_videoPanel:align', 'Give at least 3 pairs of points.'); end
            end
            A = [xt(:), yt(:), ones(n, 1)];
            P = A \ [xp(:), yp(:)];          % 3 x 2: [x y 1]*P = Pi pixel
            T = [P'; 0 0 1];
            res = sqrt(mean(sum((A*P - [xp(:) yp(:)]).^2, 2)));
            self.overlay = T;
            self.mode = 'overlap';
            self.refresh()
            ok = true;
            if n > 3 && nargin < 3
                msgbox(sprintf('Thermal video aligned on the Pi camera (%d points, residual %.1f pixels of the Pi camera).', ...
                    n, res), 'Thermal over Pi')
            end
        end

        %% Settings saved with the scoring (variable 'Video', see VS3_main)
        function S = settings(self)
            S = struct('piFile', '', 'piOffset', 0, 'piOffsetSource', '', 'thermalFile', '', 'thermalOffset', 0, ...
                'thermalOffsetSource', '', 'mode', self.mode, 'overlay', self.overlay, 'alpha', self.alpha, ...
                'rois', self.rois, 'roiOn', self.roiOn, 'timingFolder', '', 'breathing', self.breathing, 'warmSpot', self.warmSpot);
            for kind = {'pi', 'thermal'}
                V = self.(kind{1});
                if isempty(V); continue; end
                S.([kind{1}, 'File']) = V.file;
                S.([kind{1}, 'Offset']) = V.offset;
                S.([kind{1}, 'OffsetSource']) = V.offsetSource;
                if ~isempty(V.timeMap) && isfield(V.timeMap, 'folder'); S.timingFolder = V.timeMap.folder; end
            end
        end

        function apply(self, S)
            % apply  View, overlay, ROIs of saved settings (the videos are opened by VS3_main).
            if isfield(S, 'mode') && any(strcmp(S.mode, self.modes)); self.mode = S.mode; end
            if isfield(S, 'overlay'); self.overlay = S.overlay; end
            if isfield(S, 'alpha') && isscalar(S.alpha); self.alpha = S.alpha; self.alphaSlider.Value = S.alpha; end
            if isfield(S, 'rois') && isstruct(S.rois) && all(isfield(S.rois, {'video', 'rect', 'name'}))
                keep = arrayfun(@(r) ~isempty(self.(r.video)), S.rois);
                self.rois = S.rois(keep);
            end
            if isfield(S, 'roiOn'); self.roiOn = logical(S.roiOn); end
            if isfield(S, 'breathing') && isstruct(S.breathing) && all(isfield(S.breathing, fieldnames(self.breathing)))
                self.breathing = S.breathing;
            end
            if isfield(S, 'warmSpot') && isstruct(S.warmSpot) && ~isempty(self.thermal) && isfield(S, 'thermalFile') && ...
                    strcmp(S.thermalFile, self.thermal.file)
                self.warmSpot = S.warmSpot;     % (of this thermal video: its frames, not its timing)
            end
            self.roiEpoch = 0;
            self.refresh()
        end

        function delete(self)
            if ~isempty(self.playTimer) && isvalid(self.playTimer)
                stop(self.playTimer)
                delete(self.playTimer)
            end
            delete(self.playLines(isgraphics(self.playLines)))
            if ~isempty(self.pi); delete(self.pi); end
            if ~isempty(self.thermal); delete(self.thermal); end
            if isgraphics(self.panel); delete(self.panel); end
        end
    end

    methods (Access = private)
        function addPlayLines(self, t)
            delete(self.playLines(isgraphics(self.playLines)))
            self.playLines = gobjects(0);
            if ~isempty(self.plot) && isgraphics(self.plot.plotax)
                self.playLines(end+1) = line(self.plot.plotax, [t t], self.plot.plotax.YLim, 'Color', 'k', ...
                    'LineWidth', 1.5, 'HitTest', 'off');
            end
            if ~isempty(self.axRoi) && isgraphics(self.axRoi)
                self.playLines(end+1) = line(self.axRoi, [t t], self.axRoi.YLim, 'Color', 'k', 'HitTest', 'off');
            end
        end

        function button(self, o, fun)
            % a button of the column: run it, then give the focus back to the figure so that the
            % space bar does not press the button again and the scoring keys work
            fun()
            o.Enable = 'off';
            drawnow
            o.Enable = 'on';
            figure(ancestor(self.panel, 'figure'))
        end

        function forwardKey(self, e)
            if ~isempty(self.keyFunction); self.keyFunction(ancestor(self.panel, 'figure'), e); end
        end
    end
end

%% ======================================================================= helpers
function s = onOff(tf)
if tf; s = 'on'; else; s = 'off'; end
end

function s = clockText(t)
s = sprintf('%02d:%02d:%06.3f', floor(t/3600), floor(mod(t, 3600)/60), mod(t, 60));
end

function [x, y, b] = clicks(ax, n)
% points clicked in axes ax (Enter ends, right click cancels), in the coordinates of the axes
fig = ancestor(ax, 'figure');
figure(fig)
x = []; y = []; b = [];
while numel(x) < n
    try
        [xi, yi, bi] = ginput(1);
    catch
        return % figure closed
    end
    if isempty(bi); break; end           % Enter
    if gca ~= ax; continue; end          % a click elsewhere
    x(end+1) = xi; y(end+1) = yi; b(end+1) = bi; %#ok<AGROW>
    if bi ~= 1; break; end
    line(ax, xi, yi, 'Marker', '+', 'Color', 'c', 'MarkerSize', 8, 'Tag', 'VS3click');
end
delete(findobj(ax, 'Tag', 'VS3click'))
end

function D = trackPi(V, k, t, rois)
% movement (dx, dy) and brightness of each ROI over the frames k of the Pi camera: each ROI is
% tracked from frame to frame by normalized cross-correlation within 8 pixels, starting from its
% place in the first frame of the epoch (dx = dy = 0 there)
n = numel(k);
nr = numel(rois);
dx = nan(n, nr); dy = dx; br = dx;
rect = reshape([rois.rect], 4, [])';
tmpl = cell(1, nr);
pos = rect(:, 1:2);
for j = 1:n
    img = V.frame(k(j));
    for r = 1:nr
        w = rect(r, 3); h = rect(r, 4);
        if isempty(tmpl{r})
            x = pos(r, 1); y = pos(r, 2);
            if x < 1 || y < 1 || x + w - 1 > size(img, 2) || y + h - 1 > size(img, 1); continue; end
            tmpl{r} = gray(img, x, y, w, h);
            dx(j, r) = 0; dy(j, r) = 0; br(j, r) = mean(tmpl{r}(:));
            continue
        end
        [p, ok] = track(img, tmpl{r}, pos(r, :), 8);
        if ~ok; continue; end
        pos(r, :) = p;
        dx(j, r) = p(1) - rect(r, 1);
        dy(j, r) = p(2) - rect(r, 2);
        q = round(p);
        br(j, r) = mean(gray(img, q(1), q(2), w, h), 'all');
    end
end
D = struct('name', {}, 'unit', {}, 't', {}, 'v', {});
for r = 1:nr
    D(end+1) = struct('name', [rois(r).name, ' dx'], 'unit', 'px', 't', t, 'v', dx(:, r)); %#ok<AGROW>
    D(end+1) = struct('name', [rois(r).name, ' dy'], 'unit', 'px', 't', t, 'v', dy(:, r)); %#ok<AGROW>
    D(end+1) = struct('name', [rois(r).name, ' brightness'], 'unit', 'gray', 't', t, 'v', br(:, r)); %#ok<AGROW>
end
end

function g = gray(img, x, y, w, h)
x = max(1, x); y = max(1, y);
g = mean(double(img(y:min(end, y+h-1), x:min(end, x+w-1), :)), 3);
end

function [p, ok] = track(img, tmpl, p0, radius)
% best place of template tmpl near p0 (upper left corner, pixels), with sub-pixel refinement;
% refused when the correlation is below 0.6 or not unique (no texture)
[h, w] = size(tmpl);
x0 = max(1, round(p0(1)) - radius); y0 = max(1, round(p0(2)) - radius);
x1 = min(size(img, 2), round(p0(1)) + w - 1 + radius); y1 = min(size(img, 1), round(p0(2)) + h - 1 + radius);
S = mean(double(img(y0:y1, x0:x1, :)), 3);
p = p0;
ok = false;
if size(S, 1) < h || size(S, 2) < w || std(tmpl(:)) < 1e-6; return; end
k = ones(h, w);
c0 = tmpl - mean(tmpl(:));
sums = conv2(S, k, 'valid');
sums2 = conv2(S.^2, k, 'valid');
den = sqrt(max(0, sums2 - sums.^2/numel(tmpl))*sum(c0(:).^2));
c = conv2(S, rot90(c0, 2), 'valid')./max(den, eps);
c(den < eps) = -Inf;
[peak, i] = max(c(:));
[py, px] = ind2sub(size(c), i);
other = c;
other(max(1, py-2):min(end, py+2), max(1, px-2):min(end, px+2)) = -Inf;
if ~isfinite(peak) || peak < .6 || peak - max(other(:)) < .02; return; end
ddx = 0; ddy = 0;
if px > 1 && px < size(c, 2); ddx = parabola(c(py, px-1:px+1)); end
if py > 1 && py < size(c, 1); ddy = parabola(c(py-1:py+1, px)); end
p = [x0 + px - 1 + ddx, y0 + py - 1 + ddy];
ok = true;
end

function d = parabola(v)
den = v(1) - 2*v(2) + v(3);
d = 0;
if abs(den) > eps; d = max(-.5, min(.5, .5*(v(1) - v(3))/den)); end
end

function D = thermalMeans(V, k, t, rois)
% mean of each thermal ROI (fixed rectangle) over the frames k
n = numel(k);
nr = numel(rois);
m = nan(n, nr);
for j = 1:n
    img = V.frame(k(j));
    if ~V.valid(k(j)); continue; end % shutter cycle of the camera (known once the frame is read)
    for r = 1:nr
        q = rois(r).rect;
        a = img(max(1, q(2)):min(end, q(2)+q(4)-1), max(1, q(1)):min(end, q(1)+q(3)-1));
        a = a(isfinite(a));
        if ~isempty(a); m(j, r) = mean(a); end
    end
end
u = 'counts';
if strcmp(V.unit, 'degC'); u = [char(176) 'C']; end
D = struct('name', {}, 'unit', {}, 't', {}, 'v', {});
for r = 1:nr
    D(end+1) = struct('name', [rois(r).name, ' mean'], 'unit', u, 't', t, 'v', m(:, r)); %#ok<AGROW>
end
end

function [f, a] = amplitudeSpectrum(t, v, t0)
% single-sided amplitude spectrum of v (frame times t) over the epoch [t0, t0+4), Hann window,
% on a regular grid at the frame rate; empty when more than 20 % of the epoch is missing
f = []; a = [];
ok = isfinite(v) & isfinite(t);
if sum(ok) < 8; return; end
fs = 1/median(diff(t(ok)));
g = (t0:1/fs:t0 + 4 - 1/(2*fs))';
x = interp1(t(ok), v(ok), g, 'linear');
if mean(isnan(x)) > 0.2; return; end
x(isnan(x)) = mean(x, 'omitnan');
x = x - mean(x);
w = hann(numel(x), 'periodic');
X = abs(fft(x.*w))/sum(w);
m = floor(numel(x)/2) + 1;
a = X(1:m);
a(2:end) = 2*a(2:end);
f = (0:m-1)'*fs/numel(x);
end
