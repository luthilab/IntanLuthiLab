function VS3_main(file, varargin)
% VS3_MAIN VeryScore3: score mouse sleep (wake / NREM / REM) in 4-s epochs.
%
% VeryScore3 is the continuation of VeryScore2 (Romain Cardis & Anita Luthi,
% Luthi lab, University of Lausanne, 2018-2021; updates by Georgios Foustoukos
% 2023-2024). It reads and writes the same files as VeryScore2.
%
% Version 3.0 (2026, Alejandro Osorio-Forero with Claude): VeryScore2 1.6-1.8
% unified in one program (all files VS3_*), see CHANGELOG.md.
% - Preferences in the group 'VeryScore3' (VS3_pref), taken over from VeryScore2.
% - Save: names not ending in _t.mat no longer lose characters.
% - Import randomly no longer needs the Statistics toolbox.
% - Auto-scoring library: the shipped recordings plus your own, kept apart.
% - File > Convert Open Ephys recording (VS3_convertOpenEphys).
% - Tools > Summary figure: hypnogram, EEG sigma, temperature, photometry (VS3_summary).
% - The VeryScore3 logo: start screen, progress windows, Help > About (VS3_logo).
% - File > Export displayed traces: the traces as displayed (filters, bipolar,
% dF/F) in a new .mat file, in the units of the file, with Fs and start time.
%
% Version 3.1 (2026-10-30): the additions of Wenjie (October 2026) in the main window.
% - Tools > Video: Pi camera and thermal video in a column right of the traces,
% following the epoch, Play 4 s (space bar), thermal over Pi, ROI traces, recorder
% timing maps (VS3_videoPanel, VS3_video, VS3_videoTiming), saved as 'Video'.
% - Tools > Sensor data: Pi sensor compared with the EEG / EMG (VS3_sensorView).
% - Open Ephys conversion: recordings and channels chosen in lists.
% - VS3_main(file, 'pi', video, 'thermal', video) opens a file (and videos) directly.
%
% History of VeryScore2:
% Version 1.5 addings.
% - Microarousal epoch corresponding to keyboard key 'm'
% - Treatment of last channel if it's too big (usually stimulation trace)
% -d Correction of a bug that did not let you import another file while one
% was already loaded making it mandatory to quit VS2 between files.
% - New Random import that will automatically ask and reload another file
% randomly from the baselected during the first import.
% - Added a menu to directly access the reduce file size (useful for
% files
% from INTAN
% recordings).
% - Correction of a 3bug that did not correctly show the last epoch of the
% scoring and the xlim of the main plot.
% - Retrocompatibility with the files containing old variable t
% - Add a failsafe if the scoring is not saved and the windows is closed
% -Added a f epoch that can be use for whatever like drawziness or else.
% The color is the wonderful purple because it's Najma's
%- Fixed a bug that prevented to edit file Infos because of the new
%configuration field containing the Intan configuration for the specific
%animals.
%
% Version 1.6 addings (2026, Alejo Osorio with Claude):
% - Thermal video temperature: Tools > Thermal video analyses an Optris
% .ravi recording (see VS3_thermalTool) and shows the temperature of the
% animal in a panel above the hypnogram. The result is stored as the variable
% 'Thermal' in the scoring file and shown again when the file is loaded.
%
% Version 1.7 addings (2026, Alejo Osorio with Claude):
% - Photometry: Tools > Photometry turns the selected trace (the raw,
% LED-modulated detector channel) into dF/F, see VS3_photometry. Two baselines,
% because it depends on the sensor: the purple (405 nm) signal fitted onto the
% signal, or the double-exponential decay of the signal itself. The result is
% stored as the variable 'Photometry' in the file and shown again at loading.
%
% Version 1.8 addings (2026, Alejo Osorio with Claude):
% - New auto-scoring (Tools > Auto-Scoring > Score this file), see
% VS3_autoScoreTool: EEG spectra and EMG >30 Hz, a model trained on a library
% of manually scored recordings and adapted to each recording, uncertain epochs
% left as 'b' for review (shift+B jumps to the next one). Corrected scorings can
% be added to the library. The VeryScore1 autoscore stays as "Classic".
%
% Romain Cardis 2021

%clear h
%close all
%clc

%% create main figure and menus
h = struct();
h.updt = '3.1';
h = VS3_display(h);
h.thermal = [];   % temperature of the thermal video (struct 'Thermal'), see VS3_thermalTool
h.Fs = [];        % sampling rate of the loaded file (Hz)
h.photometry = []; % dF/F of a photometry channel (struct 'Photometry'), see VS3_photometry
h.video = [];     % video column right of the traces (Pi camera, thermal video), see VS3_videoPanel
h.sensor = [];    % sensor H5, offset, bands and channels compared (struct 'Sensor'), see VS3_sensorView
h.sensorData = []; % the sensor H5 opened (VS3_sensorTool 'read')
h.sensorView = []; % the comparison window

%% set menu callbacks

h.mainFig.CloseRequestFcn = @SureToClose;
h.mainFig.DeleteFcn = @mainDeleted;
h.issaved = 1;

% File
h.fileMenu_import.Callback = @importOne;
h.fileMenu_save.Callback = @saveScoring;
h.fileMenu_export.Callback = @exportTraces;
h.fileMenu_editInfo.Callback = @editInfos;
h.fileMenu_importrandom.Callback = @importRand;
h.fileMenu_convertOE.Callback = @convertOpenEphys;
h.fileMenu_sensorConvert.Callback = @sensorConvert;
h.fileMenu_reduce.Callback = @reduceFile;
h.fileMenu_rename.Callback = @renameFileToBt;
% Traces
h.tracesMenu_bipol.Callback = @bipol;
h.tracesMenu_filt.Callback = @filt;
h.tracesMenu_lockYlim.Callback = @lockYlim;
h.tracesMenu_ChangeGain.Callback = @changeGain1000;
h.tracesMenu_notch.Callback = @notching;
h.tracesMenu_Supress.Callback = @supressTraces;
h.tracesMenu_swapTraces.Callback = @swapT;
h.tracesMenu_reverse.Callback = @reverseAll;
h.tracesMenu_origain.Callback = @origain;

% Tools
h.toolsMenu_autoScoreRun.Callback = @autoScoreRun;
h.toolsMenu_autoScoreAdd.Callback = @autoScoreAdd;
h.toolsMenu_autoScoreLib.Callback = @autoScoreLibrary;
h.toolsMenu_autoScoreClassic.Callback = @launchAuto;
h.toolsMenu_nameTraces.Callback = @reloadNames;
h.toolsMenu_takeSnap.Callback = @takeSnap;
h.toolsMenu_summary.Callback = @summaryFigure;
h.helpMenu_about.Callback = @(~,~) VS3_logo('about', h.updt);
% Tools > Thermal video
h.toolsMenu_thermalAnalyse.Callback = @thermalAnalyse;
h.toolsMenu_thermalShow.Callback = @thermalShowHide;
h.toolsMenu_thermalOffset.Callback = @thermalOffset;
h.toolsMenu_thermalEstimate.Callback = @thermalEstimate;
h.toolsMenu_thermalCalib.Callback = @thermalCalibrate;
h.toolsMenu_thermalPython.Callback = @thermalPython;
h.toolsMenu_thermalOpenEphys.Callback = @thermalOpenEphys;
% Tools > Photometry
h.toolsMenu_photoDFF.Callback = @photometryDFF;
h.toolsMenu_photoFigure.Callback = @photometryFigure;
% Tools > Video
h.toolsMenu_videoPi.Callback = @(~,~) videoOpen('pi');
h.toolsMenu_videoThermal.Callback = @(~,~) videoOpen('thermal');
set([h.toolsMenu_videoShowPi, h.toolsMenu_videoShowThermal, h.toolsMenu_videoShowBoth, h.toolsMenu_videoShowOverlap], ...
    'Callback', @videoShow);
h.toolsMenu_videoAlign.Callback = @videoAlign;
h.toolsMenu_videoAutoAlign.Callback = @videoAutoAlign;
h.toolsMenu_videoLag.Callback = @videoLag;
h.toolsMenu_videoOffset.Callback = @videoOffsets;
h.toolsMenu_videoTiming.Callback = @videoTiming;
h.toolsMenu_videoTimingClear.Callback = @videoTimingClear;
h.toolsMenu_videoRoiAdd.Callback = @videoRoiAdd;
h.toolsMenu_videoRoiOn.Callback = @videoRoiOn;
h.toolsMenu_videoRoiNow.Callback = @videoRoiNow;
h.toolsMenu_videoRoiRemove.Callback = @videoRoiRemove;
h.toolsMenu_videoClosePi.Callback = @(~,~) videoClose('pi');
% Tools > Sensor data
h.toolsMenu_sensorImport.Callback = @sensorImport;
h.toolsMenu_sensorShow.Callback = @sensorShow;
h.toolsMenu_sensorSettings.Callback = @sensorSettings;
h.toolsMenu_videoCloseThermal.Callback = @(~,~) videoClose('thermal');

% Width
h.widthMenu_8.Callback = @changeWidth;
h.widthMenu_16.Callback = @changeWidth;
h.widthMenu_24.Callback = @changeWidth;
h.widthMenu_32.Callback = @changeWidth;
h.widthMenu_40.Callback = @changeWidth;
h.widthMenu_48.Callback = @changeWidth;
h.widthMenu_96.Callback = @changeWidth;
h.widthMenu_384.Callback = @changeWidth;
% fishy

%% set keyboard function
h.mainFig.KeyPressFcn = @key;

%% a file given on the command line (scripts, tests):
% VS3_main(file, 'pi', video, 'thermal', video, 'timing', recorderTimingFolder)
if nargin > 0 && ~isempty(file)
    h.rand = 0;
    h.pendingFile = char(file);
    import
    for iArg = 1:2:numel(varargin) % (names not used in the nested functions, which share them)
        if strcmpi(varargin{iArg}, 'timing'); continue; end
        argVideo = videoLoad(varargin{iArg}, varargin{iArg+1});
        if ~isempty(argVideo); videoAttach(varargin{iArg}, argVideo); end
    end
    iArg = find(strcmpi(varargin(1:2:end), 'timing'), 1);
    if ~isempty(iArg); videoTimingLoad(varargin{2*iArg}, false); end
end

%% callback functions

    function SureToClose(~,~)
        if h.issaved == 0
            an = questdlg('It seems you did not save your scoring, you are risking loosing it all like Najma once! Are you sure to close?', 'CAREFUL!','Yes, my scoring is worthless.', 'No wait! I will save!', 'No wait! I will save!');
            if strcmp(an, 'Yes, my scoring is worthless.')
                closeMain()
            end
        else
            closeMain()
        end
    end

    function closeMain()
        delete(h.mainFig) % see mainDeleted
    end

    function mainDeleted(~,~)
        % the main window is deleted: the video column (its timer and video files) and the sensor
        % comparison window go with it
        if ~isempty(h.video) && isvalid(h.video); delete(h.video); end
        sensorClose()
    end

    function reduceFile(~,~)
        ReduceBTfileSize(h.file)
    end

    function origain(~,~)
        h.bigplot.backToGain()
    end
    
    function takeSnap(~,~)
        figure
        f = axes();
        for i = 1:length(h.bigplot.graphLines)
            copyobj(h.bigplot.graphLines{i}, f)
        end
        title(h.filen)
        f.TickDir = 'out';
    end

    function summaryFigure(~,~)
        % hypnogram, EEG sigma activity, temperature and photometry of the whole recording (VS3_summary)
        b = h.bigplot.giveMeB();
        names = autoScoreNames();
        d = autoScoreDefaults(names); % the EEG chosen for the auto-scoring, if any
        [sel, ok] = listdlg('ListString', names, 'SelectionMode', 'single', 'InitialValue', d.eeg(1), ...
            'Name', 'Summary figure', 'PromptString', 'EEG channel for the sigma activity (10-15 Hz):', 'ListSize', [320 160]);
        if ~ok || isempty(sel); return; end
        st = '';
        ttl = h.filen;
        [~, base] = fileparts(h.filen);
        sfile = fullfile(h.path, [base, '_summary.fig']); % proposed when the summary is saved
        if h.rand == 1
            ttl = 'blind scoring'; % no file name, no date
            sfile = fullfile(h.path, 'summary.fig');
        elseif ismember('Infos', who(h.file))
            Infos = h.file.Infos;
            if isfield(Infos, 'StartTime'); st = Infos.StartTime; end
        end
        try
            VS3_summary('b', b, 'eeg', h.bigplot.oriTraces(sel, :), 'fs', 200, 'eegName', regexprep(names{sel}, '^\d+: ', ''), ...
                'thermal', h.thermal, 'photometry', h.photometry, 'startTime', st, 'title', ttl, 'navigate', @goToEpoch, ...
                'file', sfile);
        catch err
            errordlg(sprintf('The summary could not be made:\n%s', err.message), 'Summary figure');
        end
    end

    function goToEpoch(ep)
        % show epoch ep in the main window (a click in the summary figure)
        if ~isgraphics(h.mainFig) || ~isfield(h, 'bigplot'); return; end
        h.bigplot.position = min(max(round(ep), 1), numel(h.bigplot.bstate));
        h.bigplot.updatePlot()
        figure(h.mainFig)
    end

    function swapT(~,~)
        h.bigplot.swapTraces();
    end

    function supressTraces(~,~)  
        h.bigplot.supressTraces()
    end
    
    function reloadNames(~,~)
        % the names typed in Infos.Channel (File > Edit file Infos), as at import: traceName (the
        % recorded names of a converted file) only when Infos.Channel does not name every trace.
        % traceName used to win, so names typed for a converted file were never shown
        varInfo = who(h.file);
        names = {};
        if ismember('Infos',varInfo)
            Infos = h.file.Infos;
            if isfield(Infos,'Channel')
                chanames = Infos.Channel;
                names = strsplit(chanames(~isspace(chanames)),',');
            end
        end
        if numel(names) ~= size(h.bigplot.oriTraces,1) && ismember('traceName',varInfo)
            names = cellstr(h.file.traceName);
            names = names(:)';
        end
        if isempty(names); return; end
        h.Channel = names;
        h.bigplot.ChannelNames = h.Channel;
        h.bigplot.initiateNames()
    end

    function editInfos(~,~)
        varInfo = who(h.file);
        action = questdlg('Edit current Infos or add a new field?', 'There should be a better way no?', 'Edit', 'New', 'Edit');
        switch action
            case 'Edit'
                if ismember('Infos',varInfo)
                    Infos = h.file.Infos;
                    nam = fieldnames(Infos);
                    df = struct2cell(Infos);
                    ifc = find(strcmp(nam,'Configuration'));
                    conf = [];
                    if ~isempty(ifc) % files without the Intan Configuration field (e.g. Open Ephys) made this crash
                        conf = df{ifc};
                    end
                    nam(ifc) = [];
                    df(ifc) = [];
                    n = cellfun(@ischar, df);
                    df(~n) = cellfun(@num2str, df(~n),'UniformOutput',false);
                    an = inputdlg(nam, 'Edit Infos', [1,40], df);
                    if ~isempty(an)
                         nInfos = cell2struct(an,nam);
                         if ~isempty(ifc)
                            nInfos.Configuration = conf;
                         end
                         h.file.Infos = nInfos;
                    end
                else
                    errordlg('There is no Infos variable in the file!')
                end
                
            case 'New'
                if ismember('Infos',varInfo)
                    Infos = h.file.Infos;
                else
                    Infos = struct;
                end
                an = inputdlg({'New field name', 'Field content'}, 'Edit Infos', [1,40]);
                if isempty(an) || ~isvarname(strtrim(an{1})); return; end % cancelled, or not a field name
                Infos.(strtrim(an{1})) = an{2};
                h.file.Infos = Infos;
        end
    end

    function changeGain1000(~,~)
        an = questdlg('Plus or minus?','Quite dumb to ask like that no?','plus','minus','minus');
        h.bigplot.changeGain(an,1000);
    end

    function lockYlim(obj,~)
        if strcmp(obj.Checked, 'on')
            obj.Checked = 'off';
            h.bigplot.lockYlim = 0;
        else
            obj.Checked = 'on';
            h.bigplot.lockYlim = 1;
        end
        
    end

    function reverseAll(~,~)
        h.b = h.bigplot.giveMeB();
        posi = h.bigplot.position;
        wi = h.bigplot.width;
        rt = h.bigplot.realTrans; % the transitions you placed by hand (saved as bTrans)
        shown = ~isempty(h.bigplot.thermax) && isgraphics(h.bigplot.thermax);
        h.bigplot.deleteAxes()
        h.bigplot = VS3_tracesPlot(h,posi,wi);
        h.bigplot.epochChangedFunction = @sensorUpdate;
        h.bigplot.realTrans = rt;
        h.bigplot.updatePlot()
        if ~isempty(h.thermal) && shown
            h.bigplot.showThermal(h.thermal)
        end
        thermalMenus()
        if ~isempty(h.photometry)
            h.bigplot.showDFF(h.photometry.channelIndex, h.photometry)
        end
        if ~isempty(h.video) && isvalid(h.video)
            h.video.attach(h.bigplot) % the video column follows the new traces
        end
    end

    function saveScoring(~,~)
        b = h.bigplot.giveMeB();
        h.file.b = b;
        h.file.bTrans = h.bigplot.realTrans;
        if ~isempty(h.video) && isvalid(h.video)
            h.file.Video = h.video.settings(); % the videos, offsets, view and ROIs, reopened at loading
        elseif ismember('Video', who(h.file))
            h.file.Video = videoNone();        % the videos were closed: not reopened any more
        end
        if ~isempty(h.sensor)
            sensorCaptureConfig()
            h.file.Sensor = h.sensor;          % the sensor H5 and the settings of the comparison
        end
        h.issaved = 1;
        % a scored file is called <name>_bt.mat: <name>_t.mat -> <name>_bt.mat, <name>.mat -> <name>_bt.mat
        [~, base] = fileparts(h.filen);
        if ~endsWith(base, '_bt')
            if endsWith(base, '_t'); base = base(1:end-2); end
            newName = [base, '_bt.mat'];
            movefile([h.path,h.filen],[h.path,newName],'f')
            h.filen = newName;
        end
        h.file = matfile([h.path, h.filen], 'writable', true);
        m = msgbox('Saved!');
        waitfor(m)
        if h.rand == 1 && h.curRandFile < length(h.filebatch)
            an = questdlg('Do you want to stay blind and import the next random file?', 'Keep it blind!', 'Yes, I''m a good scientist', 'No I want to cheat', 'Yes, I''m a good scientist');
            if strcmp(an, 'Yes, I''m a good scientist')
                h.curRandFile = h.curRandFile +1;
                h.filen = h.filebatch{h.randOrder(h.curRandFile)};
                import
            end
        elseif h.rand == 1
            msgbox('You are done with this batch. CONGRATS!')
            h.fileMenu_importrandom.Enable = 'on';
            h.fileMenu_import.Enable = 'on';
        end
    end
    
    function exportTraces(~,~)
        % the traces as displayed (filters, notches, bipolar, dF/F; order and suppressed traces as on
        % screen) in a new .mat file at 200 Hz, in the units of the file (dF/F in %), with their names,
        % Fs and the start time, see VS3_tracesPlot.exportTraces. Opens in VeryScore3 like any file.
        [X, names, rows] = h.bigplot.exportTraces();
        if isempty(X)
            errordlg('There is no trace to export.', 'Export traces'); return
        end
        [~, base] = fileparts(h.filen);
        def = fullfile(h.path, [regexprep(base, '_b?t$', ''), '_processed.mat']);
        if h.rand == 1; def = fullfile(h.path, 'processed.mat'); end % blind: no file name
        [f, p] = uiputfile('*.mat', 'Export the displayed traces as', def);
        if isequal(f, 0); return; end
        target = fullfile(p, f);
        if strcmpi(target, fullfile(h.file.Properties.Source))
            errordlg('This is the file you are scoring: choose another name.', 'Export traces'); return
        end
        Src = struct();
        if ismember('Infos', who(h.file)); Src = h.file.Infos; end
        st = '';
        if isfield(Src, 'StartTime') && ~isempty(Src.StartTime)
            st = Src.StartTime;
            if isdatetime(st); st = char(string(st, 'yyyy-MM-dd HH:mm:ss.SSS')); else; st = char(st); end
        end

        % names of the channels (an empty name leaves the trace out) and the start time
        n = numel(names);
        prompts = cell(1, n);
        for i = 1:n
            c = rows(i).channels;
            what = sprintf('channel %d', c(1));
            if numel(c) == 2; what = sprintf('channel %d - %d', c(1), c(2)); end
            steps = regexprep(rows(i).steps, ' \(.*$', ''); % the short form, e.g. 'high-pass 0.75 Hz'
            prompts{i} = sprintf('Trace %d (%s):', i, strjoin([{what}, steps], ', '));
        end
        prompts{1} = sprintf('Names of the channels in the exported file (empty = trace not saved).\n\n%s', prompts{1});
        defs = names;
        if h.rand == 0 % blind: the start time would give the date away, it is copied unseen
            prompts{end+1} = 'Start time of the first sample (Infos.StartTime, e.g. 2026-10-08 09:30:00.000; empty if unknown):';
            defs{end+1} = st;
        end
        an = inputdlg(prompts, 'Export displayed traces', [1 70], defs, 'on');
        if isempty(an); return; end
        keep = ~cellfun(@(s) isempty(strtrim(s)), an(1:n));
        if ~any(keep)
            errordlg('All the names are empty: nothing to export.', 'Export traces'); return
        end
        if h.rand == 0; st = strtrim(an{end}); end

        % units: those of the traces of the file, % for the dF/F. Infos.Unit is the unit of the traces
        % (VS3_convertOpenEphys; its ChannelUnits is the unit of BitVolts, not of the traces); an
        % exported file has no Unit and the units of its traces in ChannelUnits
        nOri = size(h.bigplot.oriTraces, 1);
        unitOf = repmat({''}, 1, nOri);
        if isfield(Src, 'Unit') && ischar(Src.Unit)
            unitOf(:) = {Src.Unit};
        elseif isfield(Src, 'ChannelUnits') && ischar(Src.ChannelUnits)
            cu = strtrim(strsplit(Src.ChannelUnits, ','));
            if numel(cu) == nOri; unitOf = cu; end
        end
        unit = cell(1, n);
        traceProcessing = cell(1, n);
        for i = 1:n
            c = rows(i).channels;
            src = sprintf('channel %d of the file', c(1));
            if numel(c) == 2; src = sprintf('channel %d minus channel %d of the file', c(1), c(2)); end
            if rows(i).dff
                unit{i} = '%';
            else
                unit{i} = unitOf{c(1)};
                src = sprintf('%s, decimated to 200 Hz', src);
            end
            traceProcessing{i} = strjoin([{src}, rows(i).steps], '; ');
        end

        traces = X(keep, :);
        traceName = reshape(strtrim(an(keep)), 1, []);
        traceProcessing = traceProcessing(keep);
        Infos = struct();
        Infos.Fs = 200;
        Infos.StartTime = st;
        Infos.Channel = strjoin(strrep(traceName, ',', ';'), ', '); % VeryScore reads the names from here
        if any(~cellfun(@isempty, unit(keep))); Infos.ChannelUnits = strjoin(unit(keep), ', '); end
        Infos.nSamples = size(X, 2);
        Infos.Duration = size(X, 2)/200;
        Infos.Source = h.file.Properties.Source;
        Infos.Exported = sprintf(['VeryScore3 v%s, File > Export displayed traces, %s: the traces as displayed, display ', ...
            'gain undone (see traceProcessing)'], h.updt, char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
        SourceInfos = Src; % the Infos of the scored file
        w = VS3_logo('waitbar', 0.5, 'Saving the traces...', 'Name', 'Export traces');
        try
            save(target, 'traces', 'traceName', 'traceProcessing', 'Infos', 'SourceInfos', '-v7.3');
        catch err
            if isvalid(w); close(w); end
            errordlg(sprintf('The traces could not be saved:\n%s', err.message), 'Export traces'); return
        end
        if isvalid(w); close(w); end
        txt = sprintf('%d traces saved (%.1f h at 200 Hz) in\n%s', sum(keep), Infos.Duration/3600, target);
        if isempty(st); txt = sprintf('%s\n\nNo start time: Infos.StartTime is empty.', txt); end
        msgbox(txt, 'Export traces');
    end

    function importRand(~,~)
        [h.filebatch, pathf] = uigetfile('*.mat','Select multiple files and i''ll choose one', VS3_fileHistory('get', 'eegMat', pwd), 'multiselect','on');       
        if iscell(h.filebatch)
            h.randOrder = randperm(length(h.filebatch)); % random order (no Statistics toolbox needed)
            h.curRandFile = 1;
            h.filen = h.filebatch{h.randOrder(h.curRandFile)};
            h.path = pathf;
            h.rand = 1; % means rand is active
            h.fileMenu_import.Enable = 'off';
            h.fileMenu_importrandom.Enable = 'off';
            import
        else
            if h.filebatch == 0; return; end
            errordlg('You need to select multiple files and I''ll choose one randomly.')
        end
    end
    
    function importOne(~,~)
        h.rand = 0;
        import  
    end

    function convertOpenEphys(~,~)
        % Open Ephys binary recordings -> VeryScore files, see VS3_convertOpenEphys
        try
            files = VS3_convertOpenEphys();
        catch err
            errordlg(sprintf('The conversion failed:\n%s', err.message), 'Open Ephys conversion');
            return
        end
        if numel(files) ~= 1 || (isfield(h, 'rand') && h.rand == 1); return; end
        [~, n, e] = fileparts(files{1});
        an = questdlg(sprintf('Open %s%s now?', n, e), 'Open Ephys conversion', 'Open', 'Not now', 'Open');
        if ~strcmp(an, 'Open'); return; end
        if isfield(h, 'bigplot') && h.issaved == 0
            an = questdlg('The scoring of the file that is open is not saved. Open the converted file anyway?', ...
                'CAREFUL!', 'Open anyway', 'Cancel', 'Cancel');
            if ~strcmp(an, 'Open anyway'); return; end
        end
        h.rand = 0;
        h.pendingFile = files{1};
        import
    end
    
    function import(~,~)
        % function to import a file into the software and create the plots
        if h.rand == 0
            if isfield(h, 'pendingFile') && ~isempty(h.pendingFile) % a file just converted (convertOpenEphys)
                [pathf, n, e] = fileparts(h.pendingFile);
                filen = [n, e];
                pathf = [pathf, filesep];
                h.pendingFile = '';
            else
                [filen, pathf] = uigetfile('*.mat','Select your file to score', VS3_fileHistory('get', 'eegMat', pwd));
                if filen == 0; return; end
                VS3_fileHistory('remember', 'eegMat', fullfile(pathf, filen));
            end
            h.filen = filen;
            h.path = pathf;
        end
        w = VS3_logo('waitbar', 0, 'Your file is being loaded', 'Name', 'VeryScore3');
        h.file = matfile([h.path, h.filen], 'writable', true);
        try
            traces = h.file.traces;
        catch
            t = h.file.t;
            traces = [t(1:end/2);t(end/2+1:end)];
        end
        
        h.traScale = ones(size(traces,1),1); % what each channel is divided by for the display (undone by the export)
        if max(traces(end,:)) > 3
            traces(end,:) = traces(end,:)/4000; % if it's a stimulation trace
            h.traScale(end) = 4000;
        end
        if h.rand == 0
            h.mainFig.Name = ['VeryScore3 v', h.updt,' - Scoring file: ',h.filen];
        else
            h.mainFig.Name = ['VeryScore3 v', h.updt,' - Scoring file: RANDOM! HA!'];
        end
        varInfo = who(h.file);
        
        % Get sampling rate
        if ismember('Infos',varInfo)
            Infos = h.file.Infos;
            if isfield(Infos,'Fs')
                sr = Infos.Fs;
                if ischar(sr)
                    sr = str2double(sr);
                end
            else
                sr = questdlg('What is the sampling rate of the traces?', 'Please inform', '200 Hz', '1000 Hz', '200 Hz');
                sr = strsplit(sr,' ');
                sr = str2double(sr{1});
                Infos.Fs = num2str(sr);
                h.file.Infos = Infos;
            end
            if isfield(h,'Channel') % in case the Channel field is still present from a previous file.
                h = rmfield(h, 'Channel');
            end
            if isfield(Infos,'Channel')
                chanames = Infos.Channel;
                if iscell(chanames)
                    chanames=chanames{1};
                end
                h.Channel = strsplit(chanames(~isspace(chanames)),',');
                if numel(h.Channel) ~= size(traces,1) && ismember('traceName', varInfo)
                    % Infos.Channel of the whole recording but only some channels converted: the
                    % names of the channels in the file
                    tn = cellstr(h.file.traceName);
                    if numel(tn) == size(traces,1); h.Channel = tn(:)'; end
                end
            end
        else
            sr = questdlg('What is the sampling rate of the traces?', 'Please inform', '200 Hz', '1000 Hz', '200 hz');
            sr = strsplit(sr,' ');
            sr = str2double(sr{1});
            Infos = struct('Fs',num2str(sr));
            h.file.Infos = Infos;
        end
        h.Fs = sr;
        % Open Ephys acquisition board (File > Convert Open Ephys recording): each channel has its own
        % DC level, the traces are centred in their slot on screen (display only)
        h.centerTraces = isfield(Infos, 'Stream') && strcmpi(char(Infos.Stream), 'acquisition_board');
        deciFactor = sr/200;
        [si,~] = size(traces); 
        h.tra = [];
        for i = 1:si
            waitbar(i/si,w)
            ntra = decimate(traces(i,:),deciFactor,'fir');
            if max(ntra > 0.08) % it's likely a stimulation trace 0-3.3 V
                ntra = ntra/1000;
                h.traScale(i) = h.traScale(i)*1000;
            end
            h.tra = [h.tra; ntra]; % set gain here in case you lost
        end
        clear('traces')
        close(w)
        if ismember('b', varInfo)
            h.b = h.file.b;
        else
            h.b = repmat('b', 1, floor(length(h.tra)/800));
        end
  
        if isfield(h,'bigplot')
            h.bigplot.deleteAxes()
        end
        if ~isempty(h.video) && isvalid(h.video) % the videos of the previous file
            delete(h.video)
        end
        h.video = [];
        if isfield(h, 'splash') % the start screen
            delete(h.splash(isgraphics(h.splash)));
            h.splash = [];
        end
        
        h.bigplot = VS3_tracesPlot(h,1,10);
        h.bigplot.epochChangedFunction = @sensorUpdate; % the sensor comparison follows the epoch
        
        if ismember('bTrans', varInfo)
            h.bigplot.realTrans = h.file.bTrans;
        end

        % Temperature of the thermal video, if this file was already analysed (Tools > Thermal video)
        h.thermal = [];
        if ismember('Thermal', varInfo)
            try
                h.thermal = h.file.Thermal;
                h.bigplot.showThermal(h.thermal)
            catch err
                h.thermal = [];
                warning('VS3:thermal', 'The temperature stored in the file could not be displayed: %s', err.message)
            end
        end
        thermalMenus()

        % dF/F of a photometry channel, if it was already computed for this file (Tools > Photometry)
        h.photometry = [];
        if ismember('Photometry', varInfo)
            try
                P = h.file.Photometry;
                if isfield(P, 'dff') && isfield(P, 'time') && isfield(P, 'channelIndex')
                    h.photometry = P;
                    h.bigplot.showDFF(P.channelIndex, P)
                    nm = regexprep(h.bigplot.ChannelNames{P.channelIndex}, ' dF/F$', '');
                    if isfield(P, 'channel') && ~isempty(regexp(nm, '\S', 'once')) && ~strcmpi(strtrim(nm), strtrim(P.channel)) ...
                            && ~startsWith(nm, 'Trace ')
                        warning('VS3:photometry', 'The dF/F stored in the file was computed on "%s" but channel %d is now called "%s".', ...
                            P.channel, P.channelIndex, nm)
                    end
                end
            catch err
                h.photometry = [];
                warning('VS3:photometry', 'The dF/F stored in the file could not be displayed: %s', err.message)
            end
        end
        photometryMenus()

        % Videos of this file (Tools > Video), reopened when their files are still there
        if ismember('Video', varInfo)
            try
                videoRestore(h.file.Video)
            catch err
                warning('VS3:video', 'The videos stored in the file could not be reopened: %s', err.message)
            end
        end
        videoMenus()

        % Sensor H5 compared with the EEG / EMG (Tools > Sensor data): only its file and settings are
        % in the scoring file; a moved H5 is also looked for next to the scored file
        sensorClose()
        h.sensor = [];
        h.sensorData = [];
        if ismember('Sensor', varInfo)
            try
                h.sensor = h.file.Sensor;
                if ~isfile(h.sensor.source)
                    [~, n, e] = fileparts(h.sensor.source);
                    h.sensor.source = fullfile(h.path, [n, e]);
                end
                h.sensorData = VS3_sensorTool('read', h.sensor.source);
            catch err
                h.sensor = [];
                h.sensorData = [];
                warning('VS3:sensor', 'The sensor H5 of this file is not available (import the sensor CSV again): %s', err.message)
            end
        end
        sensorMenus()

        % Activate Menus
        h.fileMenu_save.Enable = 'on';
        h.fileMenu_export.Enable = 'on';
        h.toolsMenu.Enable = 'on';
        h.tracesMenu.Enable = 'on';
        h.widthMenu.Enable = 'on';
        h.fileMenu_editInfo.Enable = 'on';
        h.fileMenu_reduce.Enable = 'on';
    end

%% Thermal video (temperature) functions, see VS3_thermalTool
    function thermalMenus()
        % enable / check the thermal menu items according to the current state
        has = ~isempty(h.thermal);
        shown = has && ~isempty(h.bigplot.thermax) && isgraphics(h.bigplot.thermax);
        onoff = {'off', 'on'};
        h.toolsMenu_thermalShow.Enable = onoff{has+1};
        h.toolsMenu_thermalShow.Checked = onoff{shown+1};
        h.toolsMenu_thermalOffset.Enable = onoff{has+1};
        h.toolsMenu_thermalEstimate.Enable = onoff{has+1};
    end

    function applyThermal(A)
        h.thermal = A;
        h.bigplot.showThermal(A)
        thermalMenus()
    end

    function d = thermalDefaults()
        % options of the previous analysis of this file, used as defaults for the next one
        d = {'blind', h.rand == 1};
        if isempty(h.thermal); return; end
        if isfield(h.thermal, 'offset')
            src = '';
            if isfield(h.thermal, 'offsetSource'); src = h.thermal.offsetSource; end
            if any(startsWith(src, {'offset typed', 'from the EEG start time typed', 'estimated from the movement'}))
                d = [d, {'offset', h.thermal.offset}];          % your choice: kept
            else
                d = [d, {'previousOffset', h.thermal.offset}];  % the EEG start time of the file wins, if it has one
            end
        end
        if isfield(h.thermal, 'roiMethod'); d = [d, {'roiMethod', h.thermal.roiMethod}]; end
        if isfield(h.thermal, 'roiParams') && isfield(h.thermal.roiParams, 'N'); d = [d, {'N', h.thermal.roiParams.N}]; end
    end

    function thermalAnalyse(~,~)
        % select a .ravi (or converted .h5), extract the temperature and align it with the epochs
        if ~isempty(h.thermal)
            an = questdlg('A temperature analysis already exists for this file. Run it again and replace it?', 'Thermal video', 'Yes', 'No', 'No');
            if ~strcmp(an, 'Yes'); return; end
        end
        b = h.bigplot.giveMeB();
        d = thermalDefaults();
        try
            [A, ok] = VS3_thermalTool('analyse', h.file.Properties.Source, 'Fs', h.Fs, 'nEpochs', length(b), 'b', b, d{:});
        catch err
            errordlg(sprintf('The thermal analysis failed:\n%s', err.message), 'Thermal video')
            return
        end
        if ok; applyThermal(A); end
    end

    function thermalShowHide(obj,~)
        if isempty(h.thermal); return; end
        if strcmp(obj.Checked, 'on')
            h.bigplot.hideThermal()
        else
            h.bigplot.showThermal(h.thermal)
        end
        thermalMenus()
    end

    function thermalRealign(newOffset, src)
        % newOffset in seconds, or the EEG start time (datetime / text); src = where it comes from
        if nargin < 2; src = ''; end
        b = h.bigplot.giveMeB();
        try
            [A, ok] = VS3_thermalTool('realign', h.file.Properties.Source, h.thermal, newOffset, 'Fs', h.Fs, 'nEpochs', length(b), 'source', src);
        catch err
            errordlg(sprintf('The re-alignment failed:\n%s', err.message), 'Thermal video')
            return
        end
        if ok; applyThermal(A); end
    end

    function thermalOffset(~,~)
        % new offset in seconds, or as the EEG start time (the video start time is in the file)
        if isempty(h.thermal); return; end
        [newOffset, ok, src] = VS3_thermalTool('offsetDialog', h.thermal);
        if ~ok; return; end
        thermalRealign(newOffset, src)
    end

    function thermalEstimate(~,~)
        if isempty(h.thermal); return; end
        b = h.bigplot.giveMeB();
        try
            [est, out] = VS3_thermalTool('estimateOffset', h.file.Properties.Source, h.thermal, 'b', b, 'plot', true);
        catch err
            errordlg(sprintf('The offset could not be estimated:\n%s', err.message), 'Thermal video')
            return
        end
        cur = h.thermal.offset;
        ccCur = out.cc(out.lags == round(cur));
        if isempty(ccCur); ccCur = NaN; end
        near = out.lags(out.cc >= out.ccMax - 0.01); % offsets that fit about as well
        src = '';
        if isfield(h.thermal, 'offsetSource'); src = h.thermal.offsetSource; end
        if out.ccMax < 0.3
            msgbox(sprintf(['The movement in the video does not follow the wake epochs well enough to estimate the ', ...
                'offset (best correlation %.2f). The current offset (%g s) is kept.'], out.ccMax, cur), 'Video / EEG offset');
            return
        end
        txt = sprintf(['The movement in the video matches the wake epochs best with an offset of %+d s (correlation %.2f, ', ...
            'peak ratio %.2f); offsets from %+d to %+d s fit about as well. The current offset is %g s (%s), correlation %.2f.'], ...
            est, out.ccMax, out.peakRatio, min(near), max(near), cur, src, ccCur);
        if startsWith(src, 'from the EEG start time')
            txt = sprintf(['%s\n\nThe current offset comes from the start times of the two recordings, which is usually more ', ...
                'precise than this estimate (a few seconds).'], txt);
        end
        an = questdlg(sprintf('%s\n\nRe-align the temperature with %+d s?', txt, est), 'Video / EEG offset', 'Yes', 'No', 'No');
        if strcmp(an, 'Yes'); thermalRealign(est, 'estimated from the movement in the video'); end
    end

    function thermalCalibrate(~,~)
        % add the camera's Kennlinie (energy -> degC) table to a converted video, then re-analyse
        h5 = '';
        if ~isempty(h.thermal) && isfield(h.thermal, 'source') && isfile(h.thermal.source)
            h5 = h.thermal.source;
        end
        try
            [ok, h5] = VS3_thermalTool('calibrate', h5);
        catch err
            errordlg(sprintf('Adding the calibration failed:\n%s', err.message), 'Thermal video')
            return
        end
        if ~ok; return; end
        an = questdlg('Calibration added. Run the temperature analysis again now to get values in degC?', 'Thermal video', 'Yes', 'Later', 'Yes');
        if ~strcmp(an, 'Yes'); return; end
        b = h.bigplot.giveMeB();
        d = thermalDefaults();
        try
            [A, ok] = VS3_thermalTool('analyse', h.file.Properties.Source, 'video', h5, 'Fs', h.Fs, 'nEpochs', length(b), 'b', b, d{:});
        catch err
            errordlg(sprintf('The thermal analysis failed:\n%s', err.message), 'Thermal video')
            return
        end
        if ok; applyThermal(A); end
    end

    function thermalOpenEphys(~,~)
        % read the EEG start time from the Open Ephys recording of this file, store it in Infos.StartTime
        startDir = VS3_pref('get', 'openEphysDir', h.path);
        if ~isfolder(startDir); startDir = h.path; end
        [f, p] = uigetfile({'sync_messages.txt', 'Open Ephys sync_messages.txt'}, ...
            'Select sync_messages.txt in the Open Ephys recording of this file (experiment*\recording*)', fullfile(startDir, 'sync_messages.txt'));
        if isequal(f, 0); return; end
        VS3_pref('set', 'openEphysDir', p);
        try
            t = VS3_thermalTool('eegStartOpenEphys', fullfile(p, f));
        catch err
            errordlg(sprintf('Could not read the start time:\n%s', err.message), 'Thermal video')
            return
        end
        ts = char(string(t, 'yyyy-MM-dd HH:mm:ss.SSS'));
        if ismember('Infos', who(h.file)); Infos = h.file.Infos; else; Infos = struct; end
        Infos.StartTime = ts;
        h.file.Infos = Infos;
        msg = sprintf(['First EEG sample recorded at %s (clock of the Open Ephys PC).\n', ...
            'Stored as Infos.StartTime in the file: the thermal analysis uses it from now on.'], ts);
        if ~isempty(h.thermal) && isfield(h.thermal, 'videoStart') && ~isnat(h.thermal.videoStart)
            off = seconds(t - h.thermal.videoStart);
            an = questdlg(sprintf('%s\n\nThe video started at %s, so the offset is %.3f s (current: %g s). Re-align the temperature now?', ...
                msg, char(string(h.thermal.videoStart, 'yyyy-MM-dd HH:mm:ss.SSS')), off, h.thermal.offset), 'Thermal video', 'Yes', 'No', 'Yes');
            if strcmp(an, 'Yes'); thermalRealign(t, 'from the Open Ephys recording'); end
        else
            msgbox(msg, 'Thermal video')
        end
    end

    function thermalPython(~,~)
        [f, p] = uigetfile({'python.exe', 'python.exe'}, 'Select the python.exe used to convert .ravi videos (needs numpy and h5py)');
        if isequal(f, 0); return; end
        [ok, info] = VS3_thermalTool('checkPython', fullfile(p, f));
        if ok
            msgbox(sprintf('Python found and remembered:\n%s', info), 'Thermal video')
        else
            errordlg(sprintf('This Python cannot import numpy and h5py:\n%s\n\nInstall them with:  pip install numpy h5py', info), 'Thermal video')
        end
    end

%% Video functions (Pi camera and thermal video in a column right of the traces), see VS3_videoPanel
    function videoMenus()
        % enable / check the video menu items according to the videos that are open
        onoff = {'off', 'on'};
        has = ~isempty(h.video) && isvalid(h.video);
        hasPi = has && ~isempty(h.video.pi);
        hasTh = has && ~isempty(h.video.thermal);
        h.toolsMenu_videoShow.Enable = onoff{(hasPi && hasTh)+1};
        set([h.toolsMenu_videoAlign, h.toolsMenu_videoAutoAlign, h.toolsMenu_videoLag], 'Enable', onoff{(hasPi && hasTh)+1})
        set([h.toolsMenu_videoOffset, h.toolsMenu_videoTiming, h.toolsMenu_videoRoiAdd], 'Enable', onoff{(hasPi || hasTh)+1})
        timed = (hasPi && ~isempty(h.video.pi.timeMap)) || (hasTh && ~isempty(h.video.thermal.timeMap));
        h.toolsMenu_videoTimingClear.Enable = onoff{timed+1};
        hasRoi = has && ~isempty(h.video.rois);
        set([h.toolsMenu_videoRoiOn, h.toolsMenu_videoRoiNow, h.toolsMenu_videoRoiRemove], 'Enable', onoff{hasRoi+1})
        h.toolsMenu_videoRoiOn.Checked = onoff{(~has || h.video.roiOn)+1};
        h.toolsMenu_videoClosePi.Enable = onoff{hasPi+1};
        h.toolsMenu_videoCloseThermal.Enable = onoff{hasTh+1};
        m = '';
        if has; m = h.video.shownMode(); end
        for it = h.toolsMenu_videoShow.Children(:)'
            it.Checked = onoff{strcmp(it.UserData, m)+1};
        end
    end

    function videoOpen(kind)
        % select the video of the Pi camera or of the thermal camera and show it next to the traces
        if strcmp(kind, 'pi')
            filt = {'*.mp4;*.avi;*.mkv;*.mov', 'Pi camera video (with its .timestamps.csv)'};
            ttl = 'Select the video of the Pi camera (its .timestamps.csv next to it)';
        else
            filt = {'*.ravi;*.h5', 'Thermal video (.ravi, or .h5 made by the thermal tool)'};
            ttl = 'Select the thermal video (.ravi, or the .h5 made by Tools > Thermal video)';
        end
        startDir = VS3_fileHistory('get', [kind, 'Video'], h.path);
        if strcmp(kind, 'thermal') && ~isempty(h.thermal) && isfield(h.thermal, 'source') && isfile(h.thermal.source)
            startDir = h.thermal.source; % the video of the temperature analysis
        end
        if isfolder(startDir); startDir = fullfile(startDir, filesep); end
        [f, p] = uigetfile(filt, ttl, startDir);
        if isequal(f, 0); return; end
        V = videoLoad(kind, fullfile(p, f));
        if isempty(V); return; end
        VS3_fileHistory('remember', [kind, 'Video'], fullfile(p, f));
        videoAttach(kind, V)
        h.video.update()
        if h.rand == 1
            msgbox(sprintf('Video opened: %d frames, offset %.3f s (%s).', V.nFrames, V.offset, V.offsetSource), 'Video')
        else
            msgbox(sprintf('%s\n\nOffset: %.3f s (%s). Tools > Video > Change video/EEG offsets to correct it.', ...
                V.describe(), V.offset, V.offsetSource), 'Video')
        end
    end

    function V = videoLoad(kind, file, offset, src)
        % open the video file; offset and its source given (saved settings) or from the start times
        V = [];
        w = VS3_logo('waitbar', 0.3, 'Opening the video...', 'Name', 'Video');
        try
            V = VS3_video(file);
        catch err
            if isvalid(w); close(w); end
            errordlg(sprintf('The video could not be opened:\n%s', err.message), 'Video')
            return
        end
        if isvalid(w); close(w); end
        if ~strcmp(V.kind, kind)
            names = struct('pi', 'a Pi camera video', 'thermal', 'a thermal video (.ravi / .h5)');
            errordlg(sprintf('This is not %s.', names.(kind)), 'Video')
            delete(V); V = [];
            return
        end
        if nargin > 2
            V.offset = offset;
            V.offsetSource = src;
        else
            [V.offset, V.offsetSource] = videoDefaultOffset(V);
        end
    end

    function videoAttach(kind, V)
        % put video V in the column (created with the first video)
        if isempty(h.video) || ~isvalid(h.video)
            h.video = VS3_videoPanel(h.mainFig);
            h.video.keyFunction = @key;
            h.video.blind = h.rand == 1;
            h.video.attach(h.bigplot)
        end
        h.video.setVideo(kind, V)
        videoMenus()
    end

    function videoClose(kind)
        if isempty(h.video) || ~isvalid(h.video); return; end
        h.video.setVideo(kind, [])
        if ~h.video.isOpen() % no video left: the column disappears
            delete(h.video)
            h.video = [];
            h.bigplot.video = [];
            h.bigplot.layoutAxes()
        end
        videoMenus()
    end

    function S = videoNone()
        % settings of the column without any video (Save after the videos were closed)
        S = struct('piFile', '', 'thermalFile', '', 'mode', 'both', 'overlay', [], 'alpha', 0.6, ...
            'rois', struct('video', {}, 'rect', {}, 'name', {}), 'roiOn', true, 'timingFolder', '');
    end

    function videoRestore(S)
        % the videos saved with this file (File > Save), when their files are still there; a video
        % that was moved is also looked for in the folder of the scored file
        for kind = {'pi', 'thermal'}
            k = kind{1};
            if ~isfield(S, [k, 'File']) || isempty(S.([k, 'File'])); continue; end
            f = S.([k, 'File']);
            if ~isfile(f)
                [~, n, e] = fileparts(f);
                f = fullfile(h.path, [n, e]);
                if ~isfile(f)
                    warning('VS3:video', 'The %s video of this file is not found any more: %s', k, S.([k, 'File']))
                    continue
                end
            end
            V = videoLoad(k, f, S.([k, 'Offset']), S.([k, 'OffsetSource']));
            if ~isempty(V); videoAttach(k, V); end
        end
        if isempty(h.video) || ~isvalid(h.video); return; end
        h.video.apply(S)
        if isfield(S, 'timingFolder') && ~isempty(S.timingFolder) && isfolder(S.timingFolder)
            videoTimingLoad(S.timingFolder, false)
        end
    end

    function [off, src] = videoDefaultOffset(V)
        % video time at EEG sample 1, as for the thermal tool: the offset of the temperature analysis
        % when it was made on this thermal video, else from the start times of the two recordings
        % (Pi: clock time of its first frame in the timestamps file, UTC; thermal: start time of the
        % camera, clock of the PC). Not used when the EEG would fall outside the video, nor for the
        % thermal camera when the PC clocks are more than 12 h apart (as the thermal tool)
        off = 0;
        src = 'no start time, 0 used';
        if strcmp(V.kind, 'thermal') && ~isempty(h.thermal) && isfield(h.thermal, 'offset')
            [~, a] = fileparts(V.file);
            names = {};
            if isfield(h.thermal, 'source'); [~, names{end+1}] = fileparts(h.thermal.source); end
            if isfield(h.thermal, 'videoFile'); [~, names{end+1}] = fileparts(h.thermal.videoFile); end
            if any(strcmpi(a, names))
                off = h.thermal.offset;
                src = 'offset of the temperature analysis';
                return
            end
        end
        if isnat(V.startTime); return; end
        [eegPosix, eegClock] = eegStartTime();
        if strcmp(V.kind, 'pi')
            if isnan(eegPosix); src = 'no EEG start time, 0 used'; return; end
            o = eegPosix - posixtime(V.startTime);
        else
            if isnat(eegClock); src = 'no EEG start time, 0 used'; return; end
            o = seconds(eegClock - V.startTime);
        end
        dur = numel(h.bigplot.bstate)*4;
        if o > V.time(end) || o < -dur
            src = sprintf('by the start times the EEG is outside the video (%.1f h), 0 used', o/3600);
            return
        end
        if strcmp(V.kind, 'thermal') && abs(o) > 12*3600
            src = sprintf('the start times are %.1f h apart, 0 used', o/3600);
            return
        end
        off = o;
        src = 'from the start times';
    end

    function [p, t] = eegStartTime()
        % time of EEG sample 1: posix time (UTC) and clock time of the recording PC (no time zone)
        p = NaN;
        Infos = struct();
        if ismember('Infos', who(h.file)); Infos = h.file.Infos; end
        t = VS3_thermalTool('eegStart', h.file.Properties.Source);
        if ~isnat(t) && ~isempty(t.TimeZone)
            p = posixtime(t);
            t.TimeZone = '';
        end
        if isfield(Infos, 'StartTimePosix') && isnumeric(Infos.StartTimePosix) && isscalar(Infos.StartTimePosix) ...
                && isfinite(Infos.StartTimePosix)
            p = double(Infos.StartTimePosix);  % written by File > Convert Open Ephys recording
        elseif isnan(p) && ~isnat(t)
            tz = 'local';
            if isfield(Infos, 'TimeZone') && ischar(Infos.TimeZone) && ~isempty(Infos.TimeZone); tz = Infos.TimeZone; end
            try
                tt = t;
                tt.TimeZone = tz;
                p = posixtime(tt);
            catch
            end
        end
    end

    function videoShow(obj, ~)
        if isempty(h.video) || ~isvalid(h.video); return; end
        h.video.setMode(obj.UserData)
        videoMenus()
    end

    function videoAlign(~,~)
        if isempty(h.video) || ~isvalid(h.video); return; end
        h.video.alignOverlay();
        videoMenus()
    end

    function videoLag(~,~)
        % the movements of the animal in the Pi video against the thermal video: delay of the Pi video
        if isempty(h.video) || ~isvalid(h.video) || isempty(h.video.pi) || isempty(h.video.thermal); return; end
        P = h.video.pi;
        [W, w, ok] = videoWarmSpot('Pi offset from the movement');
        if ~ok; return; end
        try
            [lag, R] = VS3_videoMotion('piLag', P, h.video.thermal, W, @(f, txt) videoProgress(w, 0.4 + 0.6*f, txt));
        catch err
            if isvalid(w); delete(w); end
            if ~strcmp(err.identifier, 'VS3_videoMotion:cancelled'); errordlg(err.message, 'Pi offset from the movement'); end
            return
        end
        if isvalid(w); delete(w); end
        ref = 'its start time';
        if ~isempty(h.video.thermal.timeMap); ref = 'the recorder timing'; end
        found = sprintf('%d movement onsets found (after 5 s at rest), %d clear and agreeing', numel(R.onsets), sum(R.used));
        if isnan(lag)
            msgbox(sprintf(['No estimate: %s (correlation > 0.5); at least 3 are needed. The Pi offset is kept ', ...
                '(%.3f s).'], found, P.offset), 'Pi offset from the movement')
            return
        end
        an = questdlg(sprintf(['The movements of the animal appear %+.1f s later in the Pi video than in the thermal ', ...
            'video (aligned by %s): %s, delays %s s, correlation %.2f to %.2f.\n\nCorrect the Pi offset by %+.1f s ', ...
            '(%.3f -> %.3f s)?'], lag, ref, found, strjoin(compose('%+.1f', R.lags(R.used)), ', '), ...
            min(R.r(R.used)), max(R.r(R.used)), lag, P.offset, P.offset + lag), 'Pi offset from the movement', ...
            'Correct it', 'Keep it', 'Correct it');
        if ~strcmp(an, 'Correct it'); return; end
        P.offset = P.offset + lag;
        P.offsetSource = sprintf('%s, %+.1f s from the movement', regexprep(P.offsetSource, ', [+-][\d.]+ s from the movement$', ''), lag);
        h.video.refresh()
    end

    function videoAutoAlign(~,~)
        % thermal -> Pi transform from the places of the moving animal in both videos
        if isempty(h.video) || ~isvalid(h.video) || isempty(h.video.pi) || isempty(h.video.thermal); return; end
        [W, w, ok] = videoWarmSpot('Align thermal on Pi');
        if ~ok; return; end
        try
            [T, R] = VS3_videoMotion('align', h.video.pi, h.video.thermal, W, @(f, txt) videoProgress(w, 0.4 + 0.6*f, txt));
        catch err
            if isvalid(w); delete(w); end
            if ~strcmp(err.identifier, 'VS3_videoMotion:cancelled'); errordlg(err.message, 'Align thermal on Pi'); end
            return
        end
        if isvalid(w); delete(w); end
        txt = sprintf(['Fitted on the moments where the animal moved: %d of %d agree within 3 %% of the image; remaining ', ...
            'error %.0f pixels of the Pi camera. The thermal image is scaled %.2f times and turned by %.0f degrees.'], ...
            R.nAgree, R.nPairs, R.rms, R.scale, R.rotation);
        if isempty(regexp(h.video.pi.offsetSource, 'from the movement', 'once'))
            txt = sprintf(['%s\n\nThe Pi offset was not checked on the movement (Estimate Pi offset from the movement): ', ...
                'a wrong offset pairs the wrong moments.'], txt);
        end
        an = questdlg(sprintf('%s\n\nShow the thermal video over the Pi camera with this alignment?', txt), ...
            'Align thermal on Pi', 'Use it', 'Cancel', 'Use it');
        if ~strcmp(an, 'Use it'); return; end
        h.video.overlay = T; % place, scale and rotation fitted on the pairs that agree
        h.video.setMode('overlap')
        videoMenus()
    end

    function [W, w, ok] = videoWarmSpot(ttl)
        % the animal in the thermal video, once per video (about 5 min for 5 h on a network drive)
        ok = false;
        W = [];
        w = VS3_logo('waitbar', 0, 'Finding the animal in the thermal video...', 'Name', ttl, ...
            'CreateCancelBtn', 'setappdata(gcbf, ''canceling'', 1)');
        setappdata(w, 'canceling', 0);
        if isempty(h.video.warmSpot)
            try
                h.video.warmSpot = VS3_videoMotion('warmSpot', h.video.thermal, 2, @(f, txt) videoProgress(w, 0.4*f, txt));
            catch err
                if isvalid(w); delete(w); end
                if ~strcmp(err.identifier, 'VS3_videoMotion:cancelled'); errordlg(err.message, ttl); end
                return
            end
        end
        W = h.video.warmSpot;
        ok = true;
    end

    function goOn = videoProgress(w, f, txt)
        % progress bar of the movement tools; false when Cancel was pressed or the window closed
        goOn = isvalid(w) && ~isequal(getappdata(w, 'canceling'), 1);
        if goOn
            waitbar(min(max(f, 0), 1), w, txt)
        end
    end

    function videoOffsets(~,~)
        % new offsets (video time at EEG sample 1, in s); an empty field takes the start times again
        if isempty(h.video) || ~isvalid(h.video); return; end
        kinds = {};
        prompts = {};
        defs = {};
        labels = struct('pi', 'Pi camera', 'thermal', 'Thermal video');
        for kind = {'pi', 'thermal'}
            V = h.video.(kind{1});
            if isempty(V); continue; end
            kinds{end+1} = kind{1}; %#ok<AGROW>
            p = sprintf('%s: video time (s) at which EEG sample 1 was recorded (> 0: the EEG started after the video). Now: %s.', ...
                labels.(kind{1}), V.offsetSource);
            if ~isempty(V.timeMap); p = [p, ' The recorder timing is used for now.']; end %#ok<AGROW>
            prompts{end+1} = p; %#ok<AGROW>
            defs{end+1} = sprintf('%.3f', V.offset); %#ok<AGROW>
        end
        prompts{1} = sprintf('Empty field: from the start times again.\n\n%s', prompts{1});
        an = inputdlg(prompts, 'Video / EEG offsets', [1 90], defs);
        if isempty(an); return; end
        for i = 1:numel(kinds)
            V = h.video.(kinds{i});
            txt = strtrim(an{i});
            if isempty(txt)
                [V.offset, V.offsetSource] = videoDefaultOffset(V);
            elseif ~strcmp(txt, defs{i})
                o = str2double(txt);
                if ~isfinite(o)
                    errordlg(sprintf('"%s" is not a number of seconds.', txt), 'Video / EEG offsets'); return
                end
                V.offset = o;
                V.offsetSource = 'typed';
            end
        end
        h.video.refresh()
    end

    function videoTiming(~,~)
        folder = uigetdir(VS3_fileHistory('get', 'timingFolder', h.path), ...
            'Select the recorder timing folder (manifest.json, quality.json, thermal-eeg-*.csv)');
        if isequal(folder, 0); return; end
        VS3_fileHistory('remember', 'timingFolder', folder, 'Mode', 'folder');
        videoTimingLoad(folder, true)
    end

    function videoTimingLoad(folder, interactive)
        % clock maps of the open videos from a recorder timing folder (VS3_videoTiming); a video
        % that cannot be mapped keeps its offset
        if isempty(h.video) || ~isvalid(h.video); return; end
        msg = {};
        Infos = struct();
        if ismember('Infos', who(h.file)); Infos = h.file.Infos; end
        try
            VS3_videoTiming('folder', folder);
        catch err
            if interactive; errordlg(err.message, 'Recorder timing'); end
            return
        end
        labels = struct('pi', 'Pi camera', 'thermal', 'Thermal video');
        dur = numel(h.bigplot.bstate)*4;
        for kind = {'pi', 'thermal'}
            V = h.video.(kind{1});
            if isempty(V); continue; end
            try
                if strcmp(kind{1}, 'pi')
                    p = eegStartTime();
                    if isnan(p); error('VS3:video', 'the EEG start time (Infos.StartTimePosix) is unknown'); end
                    M = VS3_videoTiming('camera', folder, V, int64(round(p*1e9)));
                else
                    M = VS3_videoTiming('thermal', folder, V, VS3_videoTiming('eeg', Infos));
                end
                old = V.timeMap;
                V.timeMap = M;
                e = V.eegTimes();
                n = sum(e >= 0 & e < dur);
                if n == 0
                    V.timeMap = old;
                    error('VS3:video', 'its mapped frames do not fall within this recording');
                end
                msg{end+1} = sprintf('%s: %d frames mapped onto the EEG (%d without a valid clock observation are not shown).', ...
                    labels.(kind{1}), n, sum(isnan(e))); %#ok<AGROW>
            catch err
                msg{end+1} = sprintf('%s: not mapped, the offset is kept (%s).', labels.(kind{1}), err.message); %#ok<AGROW>
            end
        end
        h.video.refresh()
        videoMenus()
        if interactive
            msgbox([msg, {'', ['Software clock estimates: camera latency, EEG drift and the averaging of the thermal ', ...
                'frames are not measured.']}], 'Recorder timing')
        else
            fprintf('Recorder timing %s:\n%s\n', folder, strjoin(msg, newline)); % scripts, reopened files
        end
    end

    function videoTimingClear(~,~)
        if isempty(h.video) || ~isvalid(h.video); return; end
        for kind = {'pi', 'thermal'}
            if ~isempty(h.video.(kind{1})); h.video.(kind{1}).timeMap = []; end
        end
        h.video.refresh()
        videoMenus()
    end

    function videoRoiAdd(~,~)
        if isempty(h.video) || ~isvalid(h.video); return; end
        kind = 'pi';
        if isempty(h.video.pi)
            kind = 'thermal';
        elseif ~isempty(h.video.thermal)
            an = questdlg('Draw the ROI on which video?', 'Video ROI', 'Pi camera', 'Thermal', 'Cancel', 'Pi camera');
            if isempty(an) || strcmp(an, 'Cancel'); return; end
            if strcmp(an, 'Thermal'); kind = 'thermal'; end
        end
        h.video.addRoi(kind)
        videoMenus()
    end

    function videoRoiOn(obj, ~)
        if isempty(h.video) || ~isvalid(h.video); return; end
        h.video.roiOn = strcmp(obj.Checked, 'off');
        videoMenus()
        if h.video.roiOn; h.video.update(); end
    end

    function videoRoiNow(~,~)
        if isempty(h.video) || ~isvalid(h.video) || isempty(h.video.rois); return; end
        h.video.measureRois()
        h.video.drawRois()
    end

    function videoRoiRemove(~,~)
        if isempty(h.video) || ~isvalid(h.video) || isempty(h.video.rois); return; end
        [sel, ok] = listdlg('ListString', {h.video.rois.name}, 'SelectionMode', 'multiple', 'Name', 'Video ROI', ...
            'PromptString', 'ROIs to remove:', 'OKString', 'Remove', 'ListSize', [260 160]);
        if ~ok || isempty(sel); return; end
        h.video.removeRois(sel)
        videoMenus()
    end

%% Sensor data (Pi sensor compared with the EEG / EMG in 4-s epochs), see VS3_sensorView
% After the sensor comparison of Wenjie (VeryScore3, October 2026): VS3_sensorConvert, VS3_sensorTool,
% VS3_sensorView.
    function sensorMenus()
        onoff = {'off', 'on'};
        h.toolsMenu_sensorShow.Enable = onoff{~isempty(h.sensorData)+1};
        h.toolsMenu_sensorSettings.Enable = onoff{~isempty(h.sensorData)+1};
    end

    function sensorConvert(~,~)
        % the CSV / CSV.GZ files of one sensor recording (in chronological order) -> one H5
        [f, p] = uigetfile({'*.csv;*.csv.gz', 'Pi sensor CSV / CSV.GZ'}, ...
            'Select the sensor files of one recording, in chronological order', VS3_fileHistory('get', 'sensor', pwd), ...
            'MultiSelect', 'on');
        if isequal(f, 0); return; end
        if ischar(f); f = {f}; end
        VS3_fileHistory('remember', 'sensor', fullfile(p, f{1}));
        def = fullfile(p, regexprep(f{1}, '(?i)\.csv(\.gz)?', '.h5'));
        [out, folder] = uiputfile('*.h5', 'Save the sensor recording as', def);
        if isequal(out, 0); return; end
        w = VS3_logo('waitbar', 0, 'Converting the sensor files...', 'Name', 'Sensor data');
        try
            VS3_sensorConvert(fullfile(p, f), fullfile(folder, out), @(x) sensorProgress(x, w));
        catch err
            if isvalid(w); close(w); end
            errordlg(sprintf('The sensor files could not be converted:\n%s', err.message), 'Sensor data')
            return
        end
        if isvalid(w); close(w); end
        msgbox(sprintf('Sensor recording saved in\n%s\n\nOpen the EEG, then Tools > Sensor data > Import sensor CSV.', ...
            fullfile(folder, out)), 'Sensor data')
    end

    function sensorImport(~,~)
        % the CSV / CSV.GZ files of the Pi sensor (several: in chronological order), or an H5 made from
        % them. The CSV files are read once into an H5 next to the EEG file, which is used again the next
        % time (the CSV files are not changed)
        [f, p] = uigetfile({'*.csv;*.csv.gz;*.h5', 'Pi sensor CSV / CSV.GZ (or its H5)'}, ...
            'Select the sensor CSV of this recording (several: in chronological order)', ...
            VS3_fileHistory('get', 'sensor', h.path), 'MultiSelect', 'on');
        if isequal(f, 0); return; end
        f = cellstr(f);
        VS3_fileHistory('remember', 'sensor', fullfile(p, f{1}));
        if any(endsWith(lower(f), '.h5'))
            if numel(f) > 1
                errordlg('Select the CSV files of the recording, or one H5.', 'Sensor data')
                return
            end
            source = fullfile(p, f{1});
        else
            source = sensorH5(fullfile(p, f));
            if isempty(source); return; end
        end
        try
            S = VS3_sensorTool('read', source);
            offset = VS3_sensorTool('offset', S.startPosix, h.file.Infos);
        catch err
            errordlg(err.message, 'Sensor data')
            return
        end
        [names, keys] = sensorChannelNames();
        first = find(contains(names, 'EMG', 'IgnoreCase', true), 1);
        if isempty(first); first = 1; end
        [chans, ok] = listdlg('ListString', names, 'SelectionMode', 'multiple', 'InitialValue', first, ...
            'Name', 'Sensor data', 'ListSize', [480 240], 'PromptString', ...
            {'EEG / EMG traces to compare with the sensor (Ctrl: several).', 'They can be changed later in the comparison.'});
        if ~ok; return; end
        sensorClose()
        h.sensorData = S;
        h.sensor = struct('source', S.source, 'offset', offset, 'bands', [.5 5; 5 15], 'channels', chans, ...
            'channelKeys', {keys(chans)}, 'alignment', 'recorded UTC clocks; independent clock accuracy unverified');
        h.issaved = 0;
        sensorMenus()
        sensorShow()
        h.sensorView.showOverview();
    end

    function target = sensorH5(files)
        % the H5 of these CSV files (VS3_sensorConvert): next to the EEG file, since the folder of the
        % CSV can be read-only, named after the first CSV. An H5 already made from the same files (same
        % paths and sizes) is used again; '' when cancelled or failed
        [~, base] = fileparts(regexprep(files{1}, '(?i)\.csv(\.gz)?$', ''));
        target = fullfile(h.path, [base '_sensor.h5']);
        k = 1;
        while isfile(target) && ~sensorH5Holds(target, files)
            k = k + 1;
            target = fullfile(h.path, sprintf('%s_sensor_%d.h5', base, k));
        end
        if isfile(target); return; end
        probe = tempname(h.path);
        if mkdir(probe)
            rmdir(probe)
        else % the folder of the EEG file is read-only
            [out, folder] = uiputfile('*.h5', 'Save the sensor recording (H5) as', [base '_sensor.h5']);
            if isequal(out, 0); target = ''; return; end
            target = fullfile(folder, out);
            if isfile(target) && sensorH5Holds(target, files); return; end
        end
        bytes = sum(cellfun(@(x) getfield(dir(x), 'bytes'), files)); %#ok<GFLD>
        w = VS3_logo('waitbar', 0, sprintf('Reading the sensor CSV (%.1f GB)...', bytes/1e9), 'Name', 'Sensor data');
        try
            VS3_sensorConvert(files, target, @(x) sensorProgress(x, w));
        catch err
            if isvalid(w); close(w); end
            errordlg(sprintf('The sensor CSV could not be read:\n%s', err.message), 'Sensor data')
            target = '';
            return
        end
        if isvalid(w); close(w); end
    end

    function sensorProgress(x, w)
        % the part of the CSV read (VS3_sensorConvert), on the progress window while it is open
        if isvalid(w); waitbar(x, w); end
    end

    function same = sensorH5Holds(target, files)
        % the H5 was made from these files (same paths, order and sizes)
        same = false;
        try
            sources = jsondecode(h5readatt(target, '/', 'sources_json'));
            same = numel(sources) == numel(files) && all(arrayfun(@(k) strcmpi(sources(k).path, files{k}) ...
                && sources(k).bytes == getfield(dir(files{k}), 'bytes'), 1:numel(files))); %#ok<GFLD>
        catch
        end
    end

    function [names, keys] = sensorChannelNames()
        [names, keys] = h.bigplot.sensorCatalog(sensorOriginalNames());
    end

    function names = sensorOriginalNames()
        % names of the recorded channels in the file (traceName, else Infos.Channel)
        n = size(h.bigplot.oriTraces, 1);
        names = arrayfun(@(k) sprintf('Channel %d', k), 1:n, 'UniformOutput', false);
        if ismember('traceName', who(h.file))
            tn = cellstr(h.file.traceName);
            if numel(tn) == n; names = tn(:)'; end
        elseif isfield(h, 'Channel') && numel(h.Channel) == n
            names = h.Channel;
        end
    end

    function sensorShow(~,~)
        % the comparison window (made again with its settings when it was closed)
        if isempty(h.sensorData); return; end
        if ~isempty(h.sensorView) && isvalid(h.sensorView) && isgraphics(h.sensorView.fig)
            figure(h.sensorView.fig)
            sensorUpdate(h.bigplot.position)
            return
        end
        sensorCaptureConfig()
        if ~isempty(h.sensorView) && isvalid(h.sensorView); delete(h.sensorView); end
        h.sensor.recordingEpochCount = numel(h.bigplot.bstring);
        h.sensorView = VS3_sensorView(h.sensorData, h.sensor, sensorChannelNames(), @sensorEmg, @goToEpoch, 'on', @sensorChannelNames);
        h.sensorView.channelMenu.Callback = @sensorChannelChanged;
        h.sensorView.settingsChanged = @sensorConfigChanged;
        sensorUpdate(h.bigplot.position)
    end

    function sensorChannelChanged(~,~)
        h.sensorView.changeChannel();
        sensorConfigChanged()
    end

    function sensorConfigChanged()
        sensorCaptureConfig()
        h.issaved = 0;
    end

    function [x, fs, unit, processing] = sensorEmg(key, ep)
        % the displayed samples of a trace in epoch ep, for the comparison
        [x, fs, processing, isDff] = h.bigplot.sensorEpoch(key, ep);
        unit = 'recorded units';
        Infos = h.file.Infos;
        if isfield(Infos, 'Unit'); unit = char(Infos.Unit); end
        if isDff; unit = '% dF/F'; end
    end

    function sensorCaptureConfig()
        if ~isempty(h.sensorView) && isvalid(h.sensorView)
            h.sensor = h.sensorView.config;
        end
    end

    function sensorUpdate(ep)
        if ~isempty(h.sensorView) && isvalid(h.sensorView) && isgraphics(h.sensorView.fig)
            h.sensorView.update(ep);
        end
    end

    function sensorClose()
        sensorCaptureConfig()
        if ~isempty(h.sensorView) && isvalid(h.sensorView); delete(h.sensorView); end
        h.sensorView = [];
    end

    function sensorSettings(~,~)
        % the offset (sensor start minus EEG start) and the two candidate bands
        if isempty(h.sensorData); return; end
        sensorCaptureConfig()
        c = h.sensor;
        an = inputdlg({'Sensor start minus EEG start (s, > 0: the sensor started later):', ...
            'Respiration candidate band [low high] (Hz):', 'Heart candidate band [low high] (Hz):'}, ...
            'Sensor alignment and bands', [1 65], {num2str(c.offset, 16), num2str(c.bands(1,:)), num2str(c.bands(2,:))});
        if isempty(an); return; end
        offset = str2double(an{1});
        bands = [sscanf(an{2}, '%f')'; sscanf(an{3}, '%f')'];
        try
            if ~isfinite(offset); error('VS3:sensorBand', 'The offset must be a number of seconds.'); end
            VS3_sensorTool('spectrum', zeros(800, 1), 200, bands); % checks the bands
            if any(bands(:) > 20); error('VS3:sensorBand', 'The bands must stay below 20 Hz (low-pass of the sensor).'); end
        catch err
            errordlg(err.message, 'Sensor data')
            return
        end
        sensorClose()
        h.sensor.offset = offset;
        h.sensor.bands = bands;
        h.issaved = 0;
        sensorShow()
    end

%% Photometry (dF/F) functions, see VS3_photometry
    function photometryMenus()
        % the overview figure needs a result made by VS3_photometry
        onoff = {'off', 'on'};
        has = ~isempty(h.photometry) && isfield(h.photometry, 'baseline') && isfield(h.photometry, 'method');
        h.toolsMenu_photoFigure.Enable = onoff{has+1};
    end

    function photometryDFF(~,~)
        % dF/F of the selected trace, computed from the full-rate channel of the file
        sele = find(h.bigplot.selectedTraces);
        if length(sele) ~= 1
            errordlg('Select the photometry trace first: click on it, one trace only.', 'Photometry');
            return
        end
        ud = h.bigplot.graphLines{sele}.UserData;
        if length(ud) ~= 2
            errordlg('Select a recorded channel, not the difference of two traces.', 'Photometry');
            return
        end
        name = regexprep(h.bigplot.ChannelNames{sele}, ' dF/F$', '');
        old = [];
        if ~isempty(h.photometry) && isfield(h.photometry, 'channelIndex') && h.photometry.channelIndex ~= ud(2)
            % one dF/F per file: the stored one is replaced
            oldName = sprintf('channel %d', h.photometry.channelIndex);
            if isfield(h.photometry, 'channel'); oldName = h.photometry.channel; end
            an = questdlg(sprintf(['The file already holds the dF/F of %s (one photometry channel per file). ', ...
                'Replace it by the dF/F of %s?'], oldName, name), 'Photometry', 'Replace', 'Cancel', 'Cancel');
            if ~strcmp(an, 'Replace'); return; end
            old = h.photometry.channelIndex;
        end
        try
            [P, ok] = VS3_photometry('analyse', h.file.Properties.Source, ud(2), 'name', name, 'Fs', h.Fs, 'blind', h.rand == 1);
        catch err
            errordlg(sprintf('The dF/F could not be computed:\n%s', err.message), 'Photometry');
            return
        end
        if ~ok; return; end
        if ~isempty(old)
            % the channel that held the previous dF/F shows its raw trace again
            rows = find(cellfun(@(g) numel(g.UserData) == 2 && g.UserData(2) == old, h.bigplot.graphLines));
            for r = rows(:)'; h.bigplot.rawTrace(r); end
            h.bigplot.initiateNames()
        end
        h.photometry = P;
        h.bigplot.showDFF(sele, P)
        photometryMenus()
    end

    function photometryFigure(~,~)
        % carrier amplitudes, baseline and dF/F of the whole recording
        if isempty(h.photometry); return; end
        ttl = '';
        if h.rand == 0; ttl = h.filen; end
        if isfield(h.photometry, 'channel'); ttl = strtrim([ttl, '   ', h.photometry.channel]); end
        VS3_photometry('figure', h.photometry, ttl);
    end

% autoscore
    function launchAuto(~,~)
        % classic VeryScore1 autoscore on the selected EEG and EMG traces
        h.bigplot.autoscore()
        h.issaved = 0;
    end

%% Auto-scoring (version 2), see VS3_autoScoreTool
    function names = autoScoreNames()
        % names of the original channels (rows of oriTraces)
        n = size(h.bigplot.oriTraces, 1);
        names = arrayfun(@(i) sprintf('Trace %d', i), 1:n, 'UniformOutput', false);
        if isfield(h, 'Channel') && numel(h.Channel) == n
            names = h.Channel;
        elseif ismember('traceName', who(h.file))
            tn = h.file.traceName;
            if iscell(tn) && numel(tn) == n; names = tn; end
        end
        names = cellfun(@(s, i) sprintf('%d: %s', i, s), names(:)', num2cell(1:n), 'UniformOutput', false);
    end

    function d = autoScoreDefaults(names)
        % last choice for the same channel names, else by name, else EMG = 1-2 and EEG = 3-4
        n = numel(names);
        d = struct('eeg', 1, 'emg', min(2, n), 'keepScored', false, 'review', 0.6);
        if n >= 4; d.eeg = [3 4]; d.emg = [1 2]; end
        isE = find(contains(names, 'EEG', 'IgnoreCase', true));
        isM = find(contains(names, 'EMG', 'IgnoreCase', true));
        if ~isempty(isE) && ~isempty(isM); d.eeg = isE(1:min(2,end)); d.emg = isM(1:min(2,end)); end
        if VS3_pref('is', 'autoScore')
            p = VS3_pref('get', 'autoScore');
            if isfield(p, 'names') && isequal(p.names, names); d.eeg = p.eeg; d.emg = p.emg; end
            if isfield(p, 'review'); d.review = p.review; end
        end
    end

    function autoScoreRun(~,~)
        b = h.bigplot.giveMeB();
        names = autoScoreNames();
        nScored = sum(b ~= 'b');
        d = autoScoreDefaults(names);
        d.keepScored = nScored > 0 && nScored < 0.5*numel(b); % a partly scored file: learn from it
        [o, ok] = VS3_autoScoreTool('dialog', names, nScored, numel(b), d);
        if ~ok; return; end
        VS3_pref('set', 'autoScore', struct('names', {names}, 'eeg', o.eeg, 'emg', o.emg, 'review', o.review));
        tra = h.bigplot.oriTraces;
        w = VS3_logo('waitbar', 0, 'Auto-scoring...', 'Name', 'Auto-scoring');
        try
            [b, R] = VS3_autoScoreTool('score', tra(o.eeg,:), tra(o.emg,:), b, ...
                'keepScored', o.keepScored, 'review', o.review, 'waitbar', w);
        catch err
            if isvalid(w); close(w); end
            errordlg(sprintf('The auto-scoring failed:\n%s', err.message), 'Auto-scoring')
            return
        end
        if isvalid(w); close(w); end
        h.bigplot.initiateB(b)
        h.bigplot.hypnoline.YData = h.bigplot.bstate;
        h.bigplot.updatePlot()
        h.issaved = 0;
        msg = sprintf(['Wake %.1f %%, NREM %.1f %%, REM %.1f %%.\n%d uncertain epochs left unscored (b): ', ...
            'shift+B jumps to the next one.\n\nMethod: %s.\nWake/sleep muscle tone from %s.'], ...
            100*R.fraction, R.nReview, R.method, R.emgFeature);
        if R.nUser > 0; msg = sprintf('%s\nLearned from the %d epochs you had scored.', msg, R.nUser); end
        msgbox(msg, 'Auto-scoring')
    end

    function autoScoreAdd(~,~)
        % add the (corrected) scoring of this file to the library, so that the model learns it
        b = h.bigplot.giveMeB();
        if mean(b ~= 'b') < 0.8
            errordlg('Score (or correct) at least 80 % of the file first: only finished scorings should go in the library.', 'Auto-scoring')
            return
        end
        names = autoScoreNames();
        d = autoScoreDefaults(names);
        d.mode = 'library';
        [o, ok] = VS3_autoScoreTool('dialog', names, 0, numel(b), d);
        if ~ok; return; end
        [~, name] = fileparts(h.filen);
        w = VS3_logo('waitbar', 0.3, 'Computing the features...', 'Name', 'Auto-scoring library');
        try
            tra = h.bigplot.oriTraces;
            F = VS3_autoScoreTool('features', tra(o.eeg,:), tra(o.emg,:), 200, numel(b));
            VS3_autoScoreTool('addToLibrary', F, b, name, sprintf('EEG %s, EMG %s', strjoin(names(o.eeg), ' + '), strjoin(names(o.emg), ' + ')));
        catch err
            if isvalid(w); close(w); end
            errordlg(sprintf('Could not add it to the library:\n%s', err.message), 'Auto-scoring')
            return
        end
        if isvalid(w); close(w); end
        if h.rand == 1; name = 'This recording'; end % stay blind
        msgbox(sprintf('%s is now in your auto-scoring library (%d recordings in all).', name, numel(VS3_autoScoreTool('library'))), 'Auto-scoring')
    end

    function autoScoreLibrary(~,~)
        % show the library (shipped recordings + yours), optionally remove some of yours
        lib = VS3_autoScoreTool('library');
        if isempty(lib); msgbox('The library is empty.', 'Auto-scoring'); return; end
        origin = {'yours', 'shipped'};
        items = arrayfun(@(e) sprintf('[%s]  %s  |  %d EEG, %d EMG  |  W %d  N %d  R %d  |  added %s  %s', origin{e.shipped+1}, e.name, ...
            numel(e.eeg), numel(e.emg), sum(e.y==1), sum(e.y==2), sum(e.y==3), e.added, e.note), lib, 'UniformOutput', false);
        [sel, ok] = listdlg('ListString', items, 'SelectionMode', 'multiple', 'ListSize', [760 250], 'Name', 'Auto-scoring library', ...
            'PromptString', {['Your recordings: ', VS3_autoScoreTool('libraryFile')], ...
            'Select some of YOUR recordings to remove them, or Cancel to keep everything:'}, ...
            'OKString', 'Remove selected', 'InitialValue', []);
        if ~ok || isempty(sel); return; end
        if any([lib(sel).shipped])
            errordlg('The shipped recordings cannot be removed here, only yours.', 'Auto-scoring')
            return
        end
        an = questdlg(sprintf('Remove %d of your recording(s) from the library?', numel(sel)), 'Auto-scoring', 'Remove', 'Cancel', 'Cancel');
        if strcmp(an, 'Remove'); lib(sel) = []; VS3_autoScoreTool('saveLibrary', lib); end
    end

% Change width function
    function changeWidth(obj,~)
        h.widthMenu_8.Checked = 'off';
        h.widthMenu_16.Checked = 'off';
        h.widthMenu_24.Checked = 'off';
        h.widthMenu_32.Checked = 'off';
        h.widthMenu_40.Checked = 'off';
        h.widthMenu_48.Checked = 'off';
        h.widthMenu_96.Checked = 'off';
        h.widthMenu_384.Checked = 'off';
        newWidth = obj.UserData;
        obj.Checked = 'on';
        h.bigplot.changeWidth(newWidth)
    end

%% Traces functions
    function bipol(~,~)
        h.bigplot.bipolarize()
    end

    function filt(~,~)
        req = questdlg('Choose y''a type o''filter', 'Choose one', 'High-pass 0.75Hz', 'High-pass 25 Hz', 'Low-pass 25 Hz', 'High-pass 0.75Hz');
        switch req
            case 'High-pass 0.75Hz'; [a,b] = cheby2(7,40, 0.75/100, 'high'); lbl = 'high-pass 0.75 Hz';
            case 'High-pass 25 Hz'; [a,b] = cheby2(7,40, 25/100, 'high'); lbl = 'high-pass 25 Hz';
            case 'Low-pass 25 Hz'; [a,b] = cheby2(7,40, 25/100, 'low'); lbl = 'low-pass 25 Hz';
            otherwise; return % dialog closed
        end
        h.bigplot.filterTrace(a,b, [lbl, ' (Chebyshev II, order 7, 40 dB, zero-phase)'])
    end

    function notching(~,~)
        req = questdlg('Choose y''a type o''notch', 'Choose one', '50 Hz', '60 Hz', '50 Hz');
        switch req
            case '50 Hz'; [a,b] = cheby2(7,40, [46,54]/100, 'stop'); lbl = 'notch 50 Hz, 46-54 Hz';
            case '60 Hz'; [a,b] = cheby2(7,40, [56,64]/100, 'stop'); lbl = 'notch 60 Hz, 56-64 Hz';
            otherwise; return % dialog closed
        end
        h.bigplot.filterTrace(a,b, [lbl, ' (Chebyshev II band-stop, 40 dB, zero-phase)'])
    end

%% Navigation functions
    function goPrev(~,~)
        pos = h.bigplot.position;
        if pos-1 > 0
            h.bigplot.position = pos-1;
        end
        h.bigplot.updatePlot()
    end

    function goNext(~,~)
        pos = h.bigplot.position;
        if pos+1 <= length(h.b)
            h.bigplot.position = pos+1;
            h.bigplot.updatePlot()
        end
    end

%% Keyboard shortcut
    function key(~,evnt)%works only when datacursor mode is off
        if strcmp(evnt.Modifier, 'shift') == 1
            switch evnt.Key
                case 'uparrow'; h.bigplot.moveTrace('up')
                case 'downarrow'; h.bigplot.moveTrace('dn')
                case 'w'; h.bigplot.goTrans('nextW')
                case 'n'; h.bigplot.goTrans('nextN')
                case 'r'; h.bigplot.goTrans('nextR')
                case 'm'; h.bigplot.goTrans('nextM')
                case 'f'; h.bigplot.goTrans('nextF')
                case 'b'; h.bigplot.goTrans('nextB') % next unscored / uncertain epoch
            end
        elseif strcmp(evnt.Modifier, 'control') == 1 
            switch evnt.Key
                case 'z'; disp('not there yet')
            end
        else
            switch evnt.Key
                case 'a'; goPrev()
                case 'd'; goNext()
                case 'space' % play the epoch in the video column
                    if ~isempty(h.video) && isvalid(h.video); h.video.togglePlay(); end
                case 'uparrow'; h.bigplot.changeGain('plus',1)
                case 'downarrow'; h.bigplot.changeGain('minus',1)
                case 'w'; h.bigplot.changeB('w'); h.issaved = 0;             
                case '1'; h.bigplot.changeB('1'); h.issaved = 0;
                case 'n'; h.bigplot.changeB('n'); h.issaved = 0;            
                case '2'; h.bigplot.changeB('2'); h.issaved = 0;
                case 'r'; h.bigplot.changeB('r'); h.issaved = 0;
                case '3'; h.bigplot.changeB('3'); h.issaved = 0;
                case 'leftarrow'; h.bigplot.goTrans('prev')
                case 'rightarrow'; h.bigplot.goTrans('next')
                case 'm'; h.bigplot.changeB('m'); h.issaved = 0;
                case 'f'; h.bigplot.changeB('f'); h.issaved = 0;
                    % here to custom epochs
            end
        end
    end

end
