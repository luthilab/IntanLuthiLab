function varargout = VS3_thermalTool(action, varargin)
%VS3_THERMALTOOL Thermal video (Optris .ravi) temperature analysis for VeryScore3.
%
% This is the tool behind the menu Tools > Thermal video. It takes the thermal video
% recorded with PIX Connect (.ravi), converts it once into a compact .h5 file (Python),
% extracts the temperature of the animal from every frame (ROI, MATLAB) and puts it on the
% time base of the scoring: one value per 4-s epoch. The result is stored as the variable
% 'Thermal' in the scoring file and displayed above the hypnogram (VS3_tracesPlot.showThermal).
% The pipeline itself lives in the 'thermal' folder (ThermalH5, thermal_roi_timeseries,
% thermal_align_to_eeg, estimate_offset, roi_methods, python).
%
%   [A, ok] = VS3_thermalTool('analyse', matFile, ...)        video -> .h5 -> ROI -> epochs (dialogs)
%   [A, ok] = VS3_thermalTool('realign', matFile, A, newOffset, ...)  new video/EEG offset, no video access
%   [off, ok] = VS3_thermalTool('offsetDialog', A)            ask a new offset (seconds or EEG start time)
%   [est, out] = VS3_thermalTool('estimateOffset', matFile, A, 'b', b) data-driven offset check
%   [h5, ok] = VS3_thermalTool('convert', raviFile, ...)      .ravi -> .h5 with a progress bar
%   [ok, h5] = VS3_thermalTool('calibrate', h5File, ...)      add the camera's Kennlinie (degC) to a .h5
%   [t, src] = VS3_thermalTool('eegStart', matFile)           EEG start time found in the file (NaT if none)
%   [t, info] = VS3_thermalTool('eegStartOpenEphys', folder)  time of the first sample of an Open Ephys recording
%   exe = VS3_thermalTool('python')                           python.exe used for the conversion
%   [ok, info] = VS3_thermalTool('checkPython', exe)          test a python.exe (numpy + h5py) and remember it
%
% Options of 'analyse' (name/value, all optional; with 'interactive' true - the default - the
% video file and the ROI options are asked with dialogs when not given):
%   'video'        .ravi or already converted .h5 file
%   'roiMethod'    'hottestN' (default) | 'shavedPatch' | 'mouseBody' | 'hotspotWindow' |
%                  'hottestBlob' | 'fixedMask' (see thermal/roi_methods). 'shavedPatch' tracks the
%                  shaved skin of the animal and is the most sensitive; 'mouseBody' measures the
%                  whole segmented animal. Both also return its position, so the frames in which
%                  it moved can be dropped afterwards with thermal_motion_censor.
%   'N'            number of hottest pixels averaged (default 50)
%   'offset'       video time (s since the first frame) at which EEG sample 1 was recorded
%                  (> 0 = the EEG started after the video). Default: computed from the EEG start
%                  time when it is known (see below), otherwise 0 = both started together.
%   'eegStart'     EEG start time (datetime or text 'yyyy-mm-dd HH:MM:SS'); the offset is then
%                  computed from the start time of the video (clock of the recording PC).
%   'b'            current scoring string (for the offset check; read from the file otherwise)
%   'Fs', 'nSamples', 'nEpochs'  information about the EEG (read from the .mat when not given)
%   'save'         true (default): store the result as variable 'Thermal' in the .mat
%   'checkOffset'  true (default): estimate the offset from the movement in the video and,
%                  when interactive, offer to use it if it differs from the one given
%   'interactive'  true (default) | false: no dialogs at all (scripts, tests)
%   'frames'       subset of frames for the ROI extraction (tests)
%   'parallel'     'auto' (default) | true | false: spread the ROI extraction over a process
%                  pool (Parallel Computing Toolbox). 'auto' uses it when a pool is already
%                  running or the video has >= 20000 frames (starting a pool takes ~20 s).
%   'motionCensor' 'auto' (default) | true | false: drop the frames in which the animal moved and
%                  interpolate over them (thermal_motion_censor). The thermal signal jumps when the
%                  animal moves, not because the ROI is misplaced, so this removes most of the
%                  jumps whatever ROI is used. 'auto' applies it to the ROI methods that track the
%                  animal ('shavedPatch', 'mouseBody'), leaving the older methods as they were.
%   'speedThr'     px per frame above which a frame counts as moving (default 0.5)
%
% EEG start time: Infos.StartTime (written by the Open Ephys converter ToVS2_2026), else the first
% of the Infos fields Start, RecordingStart, DateTime or Timestamp that holds a time of day (text
% such as '2026-09-07 12:43:50', a datetime, a datenum or a datevec; add it with File > Edit file
% Infos), else a file-name token _yymmdd_HHMMSS as written by the Intan software. A date alone
% (Infos.Date) is not used, and a start time more than 12 h away from the video start is ignored.
% Offset priority: 'eegStart' > 'offset' > the file's start time > 'previousOffset' > 0.
%
% The result A is the struct made by thermal_align_to_eeg: A.valueEpoch (one value per epoch,
% same indexing as b), A.t2Hz / A.value2Hz (per video frame, seconds since EEG start),
% A.unit ('degC', or 'counts' when the camera calibration file is missing), A.offset,
% A.offsetSource, A.videoStart, A.eegStart, ...
%
% Requirements: Python 3 with numpy and h5py for the .ravi conversion (asked once and
% remembered), Signal Processing Toolbox; 'hottestBlob' needs the Image Processing Toolbox.
%
% Alejandro Osorio-Forero with Claude, 2026.

ensurePath();
switch lower(action)
    case 'analyse'
        [varargout{1:2}] = analyse(varargin{:});
    case 'realign'
        [varargout{1:2}] = realign(varargin{:});
    case 'offsetdialog'
        [varargout{1:3}] = offsetDialog(varargin{:});
    case 'estimateoffset'
        [varargout{1:2}] = estimateOffset(varargin{:});
    case 'convert'
        [varargout{1:2}] = convert(varargin{:});
    case 'calibrate'
        [varargout{1:2}] = calibrate(varargin{:});
    case 'eegstart'
        [varargout{1:2}] = eegStartFromFile(varargin{:});
    case 'eegstartopenephys'
        [varargout{1:2}] = eegStartOpenEphys(varargin{:});
    case 'python'
        varargout{1} = findPython(varargin{:});
    case 'checkpython'
        [varargout{1:2}] = checkPython(varargin{:});
    otherwise
        error('VS3_thermalTool:action', 'Unknown action "%s".', action);
end
end

%% ======================================================================= analyse
function [A, ok] = analyse(matFile, varargin)
A = [];
ok = false;
o = parseOpts(struct('video', '', 'roiMethod', 'hottestN', 'N', 50, 'offset', [], 'eegStart', [], 'b', '', ...
    'Fs', [], 'nSamples', [], 'nEpochs', [], 'save', true, 'checkOffset', true, ...
    'interactive', true, 'frames', [], 'varName', 'Thermal', 'parallel', 'auto', 'previousOffset', [], ...
    'blind', false, 'motionCensor', 'auto', 'speedThr', 0.5), varargin);

% ---- 0. the scoring file: its time base, and can the result be stored in it? -------
[o.Fs, o.nSamples, o.nEpochs] = fileInfo(matFile, o.Fs, o.nSamples, o.nEpochs);
if o.save
    fid = fopen(matFile, 'r+');
    if fid < 0
        msg = sprintf('The result could not be stored: %s cannot be written (read-only?).', matFile);
        if o.interactive; errordlg(msg, 'Thermal video'); return; else; error('VS3_thermalTool:readonly', '%s', msg); end
    end
    fclose(fid);
end

% ---- 1. the video ------------------------------------------------------------------
if isempty(o.video)
    if ~o.interactive
        error('VS3_thermalTool:noVideo', 'Give the video file with the option ''video''.');
    end
    startDir = VS3_pref('get', 'thermalDir', fileparts(matFile));
    if ~isfolder(startDir); startDir = pwd; end
    [f, p] = uigetfile({'*.ravi;*.h5', 'Thermal video (*.ravi, *.h5)'; ...
        '*.ravi', 'Optris PIX Connect recording (*.ravi)'; ...
        '*.h5', 'Converted recording (*.h5)'}, ...
        'Select the thermal video of this recording', [stripSep(startDir), filesep]);
    if isequal(f, 0); return; end
    o.video = fullfile(p, f);
    VS3_pref('set', 'thermalDir', p);
end
if ~isfile(o.video)
    error('VS3_thermalTool:noVideo', 'Video file not found: %s', o.video);
end

% ---- 2. the converted video (.h5) --------------------------------------------------
[~, ~, ext] = fileparts(o.video);
if strcmpi(ext, '.h5')
    h5File = o.video;
else
    [h5File, okc] = convert(o.video, 'interactive', o.interactive);
    if ~okc; return; end
end
T = ThermalH5(h5File);
videoStart = T.startTime;

% ---- 3. the video / EEG offset, from the timestamps when they are known ------------
[eegStartFile, eegSrc] = eegStartFromFile(matFile);
[offset, eegStart, offsetSrc] = resolveOffset(o.offset, o.eegStart, eegStartFile, eegSrc, videoStart, o.previousOffset);

% ---- 4. the options ----------------------------------------------------------------
if o.interactive
    [o.roiMethod, o.N, offset, eegStart, offsetSrc, okd] = optionsDialog(o.roiMethod, o.N, offset, eegStart, offsetSrc, videoStart);
    if ~okd; return; end
end
o.offset = offset;
o.N = round(o.N);
wr = which(['roi_', o.roiMethod]);
if isempty(wr) || ~(isnumeric(o.N) && isscalar(o.N) && o.N >= 1)
    msg = sprintf(['Unknown ROI method "%s" (there is no file roi_%s.m in thermal\\roi_methods), or N is not a ', ...
        'positive whole number. Methods: %s.'], o.roiMethod, o.roiMethod, strjoin(roiMethods(), ', '));
    if o.interactive; errordlg(msg, 'Thermal video'); return; else; error('VS3_thermalTool:roi', '%s', msg); end
end
[~, wr] = fileparts(wr);
o.roiMethod = wr(5:end);   % the exact name of the file (Windows ignores the case)
if ~T.hasCelsius
    msg = sprintf(['The converted video has no temperature calibration: the values will be energy counts, ', ...
        'not degrees (relative changes are still meaningful, about 40 counts per kelvin).\n\n', ...
        'To get degC, get the file Kennlinie-%d-%d-*.prn of the camera (PIX Connect keeps it in ', ...
        '%%APPDATA%%\\Imager\\Cali on the recording PC) and use Tools > Thermal video > Add camera calibration.'], ...
        T.attrs.serial, T.attrs.fov_deg);
    if o.interactive
        uiwait(warndlg(msg, 'No temperature calibration', 'modal'));
    else
        fprintf('WARNING: %s\n', msg);
    end
end

% ---- 5. the ROI temperature, one value per frame -----------------------------------
w = [];
if o.interactive
    w = VS3_logo('waitbar', 0, 'Extracting the temperature from the video...', 'Name', 'VeryScore3 - thermal video', ...
        'CreateCancelBtn', 'setappdata(gcbf, ''canceling'', 1)');
    setappdata(w, 'canceling', 0);
end
t0 = tic;
roiArgs = {'N', o.N, 'progress', @(k, n) roiProgress(w, k, n, t0, o.roiMethod), 'verbose', ~o.interactive, ...
    'parallel', o.parallel};
if ~isempty(o.frames); roiArgs = [roiArgs, {'frames', o.frames}]; end
try
    R = thermal_roi_timeseries(T, o.roiMethod, roiArgs{:});
catch err
    if ishandle(w); delete(w); end
    if strcmp(err.identifier, 'VS3_thermalTool:cancelled'); return; end
    rethrow(err)
end
if ishandle(w); delete(w); end

% ---- 5b. drop the frames in which the animal moved ---------------------------------
% The apparent surface temperature does not jump because the ROI is badly placed, it jumps because
% the animal moves and the camera then sees different fur, limbs and tail (about 9 mK per frame
% while still, several hundred mK while moving). The ROI methods that return the position of the
% animal can therefore censor those frames; 'auto' does it for those methods only, so results of
% the older methods do not change.
[R, o.censored] = censorMotion(R, o);

% ---- 6. on the time base of the scoring --------------------------------------------
[o.Fs, o.nSamples, o.nEpochs] = fileInfo(matFile, o.Fs, o.nSamples, o.nEpochs);
alignArgs = {'save', false, 'Fs', o.Fs, 'nSamples', o.nSamples, 'nEpochs', o.nEpochs};
A = thermal_align_to_eeg(R, matFile, 'offset', o.offset, alignArgs{:});
A = addBookkeeping(A, o.video, offsetSrc, eegStart, NaN, NaN);
if o.censored > 0
    A.motionCensor = struct('frames', o.censored, 'fraction', o.censored / size(R.value, 1), 'speedThr', o.speedThr);
end

% ---- 7. does the movement in the video agree with the wake epochs? -----------------
if o.checkOffset
    b = o.b;
    if isempty(b)
        try %#ok<TRYNC>
            m = matfile(matFile);
            if any(strcmp({whos(m).name}, 'b')); b = m.b; end
        end
    end
    if ~isempty(b) && wakeFractionOk(b)
        try
            [est, out] = estimate_offset(matFile, 'A', A, 'b', b, 'plot', false);
            if isnan(out.ccMax)      % not enough overlap between the video and the scoring
                est = NaN;
            end
            A.offsetEstimate = est;
            A.offsetEstimateCorr = out.ccMax;
            suggest = ~isnan(est) && abs(est - o.offset) > 2 && out.ccMax > 0.3 && out.peakRatio > 1.3;
            if suggest && o.interactive
                an = questdlg(sprintf(['The movement in the video matches the wake epochs best with an offset of %+d s ', ...
                    '(correlation %.2f) instead of the %g s used (%s).\n\nRe-align the temperature with %+d s?'], ...
                    est, out.ccMax, o.offset, offsetSrc, est), 'Video / EEG offset', 'Yes, use the estimate', 'No, keep mine', 'Yes, use the estimate');
                if strcmp(an, 'Yes, use the estimate')
                    A2 = thermal_align_to_eeg(R, matFile, 'offset', est, alignArgs{:});
                    A = addBookkeeping(A2, o.video, 'estimated from the movement in the video', NaT, A.offsetEstimate, A.offsetEstimateCorr);
                end
            elseif suggest
                fprintf('NOTE: the movement in the video suggests an offset of %+d s (corr %.2f) instead of %g s.\n', est, out.ccMax, o.offset);
            end
        catch err
            warning('VS3_thermalTool:offsetCheck', 'The offset check was skipped: %s', err.message)
        end
    end
end

% ---- 8. save and report ------------------------------------------------------------
saveErr = '';
if o.save
    try
        saveVar(matFile, o.varName, A);
    catch err
        saveErr = err.message;   % the result is still returned and shown
    end
end
videoName = o.video;
if o.blind; videoName = '(not shown: blind scoring)'; end
censorNote = '';
if o.censored > 0
    censorNote = sprintf('Moving frames dropped: %d (%.1f %%)\n', o.censored, 100 * o.censored / size(R.value, 1));
end
msg = sprintf(['Thermal analysis done in %s.\n\nVideo: %s\nROI: %s, N = %d\nUnit: %s\n%s%s', ...
    'Epochs with video: %d / %d\n\n%s'], fmtTime(toc(t0)), videoName, o.roiMethod, o.N, A.unit, ...
    censorNote, offsetReport(A), nnz(~isnan(A.valueEpoch)), numel(A.valueEpoch), savedNote(o, matFile, saveErr));
if o.interactive
    msgbox(msg, 'VeryScore3 - thermal video')
else
    fprintf('%s\n', msg);
end
ok = true;
end

function A = addBookkeeping(A, videoFile, offsetSrc, eegStart, est, estCorr)
A.videoFile = videoFile;
A.offsetSource = offsetSrc;
if ~isnat(eegStart); A.eegStart = eegStart; end
A.offsetEstimate = est;
A.offsetEstimateCorr = estCorr;
end

function roiProgress(w, k, n, t0, method)
if isempty(w)
    return
end
if ~ishandle(w) || isequal(getappdata(w, 'canceling'), 1)
    error('VS3_thermalTool:cancelled', 'Cancelled by the user.');
end
if k == 0
    waitbar(0, w, 'Starting the parallel workers (about 20 s, only the first time)...');
    drawnow
    return
end
el = toc(t0);
waitbar(k / n, w,sprintf('Extracting the temperature (%s): %d / %d frames, %s left', method, k, n, fmtTime(el / k * (n - k))));
end

function s = offsetReport(A)
% lines about the alignment for the summary
src = '';
if isfield(A, 'offsetSource'); src = [' (', A.offsetSource, ')']; end
s = sprintf('Offset used: %g s%s\n', A.offset, src);
if isfield(A, 'videoStart') && ~isnat(A.videoStart)
    s = [s, sprintf('Video start: %s (clock of the recording PC)\n', timeStr(A.videoStart))];
end
if isfield(A, 'eegStart') && ~isnat(A.eegStart)
    s = [s, sprintf('EEG start:   %s\n', timeStr(A.eegStart))];
end
if isfield(A, 'offsetEstimate') && ~isnan(A.offsetEstimate)
    s = [s, sprintf('Estimate from the movement in the video: %+d s (correlation %.2f)\n', A.offsetEstimate, A.offsetEstimateCorr)];
end
end

function s = savedNote(o, matFile, saveErr)
if nargin < 3; saveErr = ''; end
[~, n, e] = fileparts(matFile);
where = [n, e];
if isfield(o, 'blind') && o.blind; where = 'the file'; end
if ~o.save
    s = 'The result was not saved.';
elseif isempty(saveErr)
    s = sprintf('The result is stored as the variable ''%s'' in %s.', o.varName, where);
else
    s = sprintf(['WARNING: the result could NOT be stored in %s (%s). It is shown until you close the file; ', ...
        'run the analysis again once the file can be written.'], where, saveErr);
end
end

function names = roiMethods()
% the ROI methods of thermal\roi_methods
d = dir(fullfile(thermalDir(), 'roi_methods', 'roi_*.m'));
names = regexprep({d.name}, '^roi_|\.m$', '');
end

function [R, n] = censorMotion(R, o)
% remove the frames in which the animal moved (see thermal_motion_censor)
n = 0;
want = o.motionCensor;
if (ischar(want) || isstring(want)) && strcmpi(char(want), 'auto')
    want = ismember(lower(string(R.method)), ["mousebody", "shavedpatch"]);
end
if ~want || size(R.value, 2) < 3 || exist('thermal_motion_censor', 'file') ~= 2
    return
end
try
    % only the temperatures are filled over the moving frames; the position and area columns keep
    % the measured values (option keepCols), which the movement estimate of the offset reads
    R = thermal_motion_censor(R, 'speedThr', o.speedThr, 'verbose', false);
    n = nnz(R.censored);
catch err
    warning('VS3_thermalTool:censor', 'The moving frames could not be removed (%s).', err.message);
end
end

function ok = wakeFractionOk(b)
% the offset estimate needs both wake and sleep epochs
w = mean(ismember(b, 'wm1'));
ok = numel(b) > 100 && w > 0.05 && w < 0.95;
end

%% ======================================================================= offset from timestamps
function [offset, eegStart, src] = resolveOffset(offsetOpt, eegStartOpt, eegStartFile, eegSrc, videoStart, prevOffset)
% priority: 'eegStart' option > 'offset' option > EEG start time found in the file > offset of the
% previous analysis > 0. A start time in the file more than 12 h away from the video start is ignored.
if nargin < 6; prevOffset = []; end
eegStart = NaT;
if ~isnat(eegStartFile) && ~isnat(videoStart) && abs(seconds(eegStartFile - videoStart)) > 12 * 3600
    warning('VS3_thermalTool:eegStart', ['The EEG start time in %s (%s) is %.1f h away from the video start (%s): ', ...
        'ignored. Check it with File > Edit file Infos.'], eegSrc, timeStr(eegStartFile), ...
        hours(eegStartFile - videoStart), timeStr(videoStart));
    eegStartFile = NaT;
end
if ~isempty(eegStartOpt)
    eegStart = parseTime(eegStartOpt);
    if isnat(eegStart)
        error('VS3_thermalTool:eegStart', 'Cannot understand the EEG start time "%s".', char(string(eegStartOpt)));
    end
    if isnat(videoStart)
        error('VS3_thermalTool:videoStart', 'The video has no start time: give the offset in seconds instead.');
    end
    offset = seconds(eegStart - videoStart);
    src = 'from the EEG start time given';
elseif ~isempty(offsetOpt)
    offset = offsetOpt;
    src = 'offset given';
    if ~isnat(videoStart); eegStart = videoStart + seconds(offset); end
elseif ~isnat(eegStartFile) && ~isnat(videoStart)
    eegStart = eegStartFile;
    offset = seconds(eegStart - videoStart);
    src = ['from the EEG start time in ', eegSrc];
elseif ~isempty(prevOffset)
    offset = prevOffset;
    src = 'as in the previous analysis';
    if ~isnat(videoStart); eegStart = videoStart + seconds(offset); end
else
    offset = 0;
    src = 'assumed: both recordings started together';
    if ~isnat(videoStart); eegStart = videoStart; end
end
end

function [t, src] = eegStartFromFile(matFile)
% eegStartFromFile  EEG start time stored in the scoring file: the first of the Infos fields
% StartTime, start_time, Start, RecordingStart, recording_start, RecStart, DateTime, date_time,
% Timestamp (text with a time of day, datetime, datenum or datevec), else a file-name token
% _yymmdd_HHmmss (Intan). A date without time of day (Infos.Date) is not used. NaT if none.
t = NaT;
src = '';
try
    m = matfile(matFile);
    if any(strcmp({whos(m).name}, 'Infos'))
        I = m.Infos;
        fn = fieldnames(I);
        order = {'starttime', 'start_time', 'start', 'recordingstart', 'recording_start', 'recstart', ...
            'datetime', 'date_time', 'timestamp'};
        for j = 1:numel(order)
            k = find(strcmpi(fn, order{j}), 1);
            if isempty(k); continue; end
            v = I.(fn{k});
            if (ischar(v) || isstring(v)) && isempty(regexp(char(v), '\d:\d\d|\d{6}_\d{6}', 'once'))
                continue   % a date without time of day
            end
            tt = parseTime(v);
            if ~isnat(tt)
                t = tt;
                src = ['Infos.', fn{k}];
                return
            end
        end
    end
catch
end
[~, name] = fileparts(matFile);
tok = regexp(name, '(?<!\d)(\d{6})_(\d{6})(?!\d)', 'tokens', 'once');
if ~isempty(tok)
    tt = parseTime([tok{1}, '_', tok{2}]);
    if ~isnat(tt)
        t = tt;
        src = 'the file name';
    end
end
end

function t = parseTime(v)
% parseTime  datetime from a datetime, a datenum, a datevec or text in the usual formats; NaT if not understood
t = NaT;
if isempty(v); return; end
if isdatetime(v); t = v(1); return; end
if isnumeric(v)
    if isscalar(v) && v > 7e5 && v < 8e5
        t = datetime(v, 'ConvertFrom', 'datenum');
    elseif numel(v) >= 6
        try t = datetime(v(1:6)); catch; end %#ok<CTCH>
    end
    return
end
if ~(ischar(v) || isstring(v)); return; end
s = strtrim(char(v));
if isempty(s); return; end
fmts = {'yyyy-MM-dd HH:mm:ss.SSS', 'yyyy-MM-dd HH:mm:ss', 'yyyy-MM-dd HH:mm', 'yyyy-MM-dd''T''HH:mm:ss.SSS', ...
    'yyyy-MM-dd''T''HH:mm:ss', 'yyyy/MM/dd HH:mm:ss', 'dd/MM/yyyy HH:mm:ss', 'dd.MM.yyyy HH:mm:ss', ...
    'dd-MM-yyyy HH:mm:ss', 'dd-MMM-yyyy HH:mm:ss', 'yyMMdd_HHmmss', 'yyyyMMdd_HHmmss', 'yyyyMMdd''T''HHmmss', 'yyyy-MM-dd'};
for k = 1:numel(fmts)
    try
        t = datetime(s, 'InputFormat', fmts{k});
        if ~isnat(t); return; end
    catch
    end
end
try
    t = datetime(s);
catch
    t = NaT;
end
end

function s = timeStr(t)
s = char(string(t, 'yyyy-MM-dd HH:mm:ss.SSS'));
end

function [method, N, offset, eegStart, src, ok] = optionsDialog(method, N, offset, eegStart, src, videoStart)
% the questions of 'Analyse video'
ok = false;
if isnat(videoStart); vs = 'unknown'; else; vs = timeStr(videoStart); end
if isnat(eegStart); es = ''; else; es = timeStr(eegStart); end
prompts = {sprintf('ROI method, one of: %s (see thermal\\roi_methods)', strjoin(roiMethods(), ', ')), ...
    'Number of hottest pixels averaged (N)', ...
    sprintf(['Offset (s): video time at which the EEG recording started (%s). ', ...
    '0 = both started together, positive = the EEG started after the video.'], src), ...
    sprintf(['EEG start time (yyyy-mm-dd HH:MM:SS), or empty to use the offset above. The video started at %s ', ...
    'on the clock of the recording PC; the two clocks must agree.'], vs)};
def = {method, num2str(N), num2str(offset), es};
an = inputdlg(prompts, 'Thermal analysis options', [1 110], def);
if isempty(an); return; end
method = strtrim(an{1});
N = str2double(an{2});
if isnan(N) || N < 1
    errordlg('N must be a positive number.', 'Thermal video')
    return
end
[offset, eegStart, src, ok] = interpretOffsetFields(an{3}, an{4}, def{3}, def{4}, videoStart, offset, eegStart, src);
end

function [offset, eegStart, src, ok] = interpretOffsetFields(offsetTxt, timeTxt, offsetDef, timeDef, videoStart, offset, eegStart, src)
% common rule of the two dialogs: a typed EEG start time wins, unless only the offset was edited
ok = false;
offsetTyped = str2double(offsetTxt);
timeTxt = strtrim(timeTxt);
offsetChanged = ~strcmp(strtrim(offsetTxt), strtrim(offsetDef));
timeChanged = ~strcmp(timeTxt, strtrim(timeDef));
if ~isempty(timeTxt) && (timeChanged || ~offsetChanged)
    t = parseTime(timeTxt);
    if isnat(t)
        errordlg(sprintf('Cannot understand the EEG start time "%s". Use yyyy-mm-dd HH:MM:SS.', timeTxt), 'Thermal video')
        return
    end
    if isnat(videoStart)
        errordlg('The video has no start time: give the offset in seconds instead.', 'Thermal video')
        return
    end
    eegStart = t;
    offset = seconds(t - videoStart);
    if timeChanged; src = 'from the EEG start time typed'; end
else
    if isnan(offsetTyped)
        errordlg('The offset must be a number of seconds.', 'Thermal video')
        return
    end
    offset = offsetTyped;
    if offsetChanged; src = 'offset typed'; end
    if ~isnat(videoStart); eegStart = videoStart + seconds(offset); else; eegStart = NaT; end
end
ok = true;
end

function [newOffset, ok, src] = offsetDialog(A)
% offsetDialog  Ask a new video/EEG offset, in seconds or as the EEG start time.
% newOffset is a number of seconds (see 'realign'); src says where it comes from.
ok = false;
newOffset = [];
videoStart = NaT;
if isfield(A, 'videoStart'); videoStart = A.videoStart; end
eegStart = NaT;
if isfield(A, 'eegStart') && ~isnat(videoStart); eegStart = videoStart + seconds(A.offset); end
src = 'current';
if isfield(A, 'offsetSource'); src = A.offsetSource; end
if isnat(videoStart); vs = 'unknown'; else; vs = timeStr(videoStart); end
if isnat(eegStart); es = ''; else; es = timeStr(eegStart); end
prompts = {sprintf(['Offset (s): video time at which the EEG recording started (%s). ', ...
    '0 = both started together, positive = the EEG started after the video, negative = before.'], src), ...
    sprintf(['Or the EEG start time (yyyy-mm-dd HH:MM:SS). The video started at %s on the clock of the ', ...
    'recording PC; the two clocks must agree.'], vs)};
def = {num2str(A.offset), es};
an = inputdlg(prompts, 'Video / EEG offset', [1 110], def);
if isempty(an); return; end
[newOffset, ~, src, ok] = interpretOffsetFields(an{1}, an{2}, def{1}, def{2}, videoStart, A.offset, eegStart, src);
end

%% ======================================================================= Open Ephys start time
function [t, info] = eegStartOpenEphys(p)
% eegStartOpenEphys  Absolute time (clock of the recording PC) of the first EEG sample of an
% Open Ephys recording (binary format, GUI 0.6 / 1.x): the software time that the GUI writes
% in sync_messages.txt when the recording starts, plus the position of the first stored sample.
% p = sync_messages.txt, its recording folder, or any parent folder (first recording found).
if isfile(p) && endsWith(lower(p), 'sync_messages.txt')
    sf = p;
else
    d = dir(fullfile(p, '**', 'sync_messages.txt'));
    if isempty(d)
        error('VS3_thermalTool:openEphys', 'No sync_messages.txt found under %s.', p);
    end
    if numel(d) > 1
        warning('VS3_thermalTool:openEphys', '%d recordings found under %s, using the first one (%s).', numel(d), p, d(1).folder);
    end
    sf = fullfile(d(1).folder, d(1).name);
end
txt = fileread(sf);
ms = regexp(txt, 'Software Time[^:\n]*:\s*(\d+)', 'tokens', 'once');
if isempty(ms)
    error('VS3_thermalTool:openEphys', 'No "Software Time" line in %s.', sf);
end
tSoft = datetime(str2double(ms{1}) / 1000, 'ConvertFrom', 'posixtime', 'TimeZone', 'local');
tSoft.TimeZone = '';                       % clock time without zone, like the video start time
% the continuous data stream: "Start Time for <stream> @ <rate> Hz: <sample number>"
tok = regexp(txt, 'Start Time for ([^\n]*?) @ ([\d.]+)\s*Hz:\s*(\d+)', 'tokens');
stream = ''; rate = NaN; startSample = NaN;
for k = 1:numel(tok)
    if isempty(regexpi(tok{k}{1}, 'memory', 'once'))
        stream = strtrim(tok{k}{1});
        rate = str2double(tok{k}{2});
        startSample = str2double(tok{k}{3});
        break
    end
end
% first stored sample number of the continuous data
firstSample = NaN;
dd = dir(fullfile(fileparts(sf), 'continuous', '*', 'sample_numbers.npy'));
if ~isempty(dd)
    firstSample = readNpyFirst(fullfile(dd(1).folder, dd(1).name));
end
t = tSoft;
if ~isnan(startSample) && ~isnan(firstSample) && ~isnan(rate)
    t = tSoft + seconds((firstSample - startSample) / rate);
end
info = struct('syncFile', sf, 'softwareTime', tSoft, 'stream', stream, 'rate', rate, ...
    'startSample', startSample, 'firstSample', firstSample);
end

function v = readNpyFirst(f)
% readNpyFirst  first element of a 1-D .npy file (numpy format 1.0 / 2.0 / 3.0)
fid = fopen(f, 'r', 'ieee-le');
if fid < 0
    error('VS3_thermalTool:npy', 'Cannot open %s.', f);
end
c = onCleanup(@() fclose(fid)); %#ok<NASGU>
magic = fread(fid, 6, 'uint8=>char')';
if ~strcmp(magic(2:6), 'NUMPY')
    error('VS3_thermalTool:npy', '%s is not a .npy file.', f);
end
ver = fread(fid, 2, 'uint8');
if ver(1) == 1
    hlen = fread(fid, 1, 'uint16');
else
    hlen = fread(fid, 1, 'uint32');
end
hdr = fread(fid, hlen, 'uint8=>char')';
descr = regexp(hdr, '''descr'':\s*''([^'']+)''', 'tokens', 'once');
if isempty(descr)
    error('VS3_thermalTool:npy', 'Cannot read the header of %s.', f);
end
code = descr{1}(end-1:end);
types = struct('i8', 'int64', 'i4', 'int32', 'i2', 'int16', 'u8', 'uint64', 'u4', 'uint32', 'f8', 'double', 'f4', 'single');
if ~isfield(types, code)
    error('VS3_thermalTool:npy', 'Unsupported data type %s in %s.', descr{1}, f);
end
x = fread(fid, 1, ['*', types.(code)]);
if descr{1}(1) == '>'
    x = swapbytes(x);
end
v = double(x);
end

%% ======================================================================= realign
function [A2, ok] = realign(matFile, A, newOffset, varargin)
o = parseOpts(struct('Fs', [], 'nSamples', [], 'nEpochs', [], 'save', true, 'varName', 'Thermal', 'source', ''), varargin);
ok = false;
src = o.source;
if ~isnumeric(newOffset)                 % an EEG start time instead of seconds
    t = parseTime(newOffset);
    if isnat(t)
        error('VS3_thermalTool:eegStart', 'Cannot understand the EEG start time "%s".', char(string(newOffset)));
    end
    if ~isfield(A, 'videoStart') || isnat(A.videoStart)
        error('VS3_thermalTool:videoStart', 'The video has no start time: give the offset in seconds instead.');
    end
    newOffset = seconds(t - A.videoStart);
    if isempty(src); src = 'from the EEG start time typed'; end
elseif isempty(src)
    src = 'offset typed';
end
R = struct();
R.time = (A.t2Hz(:) + A.offset);
R.value = A.allColumns';
R.valid = logical(A.valid2Hz(:));
R.frames = (1:numel(R.time))';
R.method = A.roiMethod;
R.params = A.roiParams;
R.extra = [];
R.unit = A.unit;
R.source = A.source;
R.startTime = NaT;
if isfield(A, 'videoStart'); R.startTime = A.videoStart; end
[o.Fs, o.nSamples, o.nEpochs] = fileInfo(matFile, o.Fs, o.nSamples, o.nEpochs);
A2 = thermal_align_to_eeg(R, matFile, 'offset', newOffset, 'save', false, 'Fs', o.Fs, 'nSamples', o.nSamples, 'nEpochs', o.nEpochs);
videoFile = '';
if isfield(A, 'videoFile'); videoFile = A.videoFile; end
est = NaN; estCorr = NaN;
if isfield(A, 'offsetEstimate'); est = A.offsetEstimate; end
if isfield(A, 'offsetEstimateCorr'); estCorr = A.offsetEstimateCorr; end
A2 = addBookkeeping(A2, videoFile, src, NaT, est, estCorr);
if isfield(A, 'motionCensor'); A2.motionCensor = A.motionCensor; end
if o.save
    saveVar(matFile, o.varName, A2);
end
ok = true;
end

%% ======================================================================= estimateOffset
function [est, out] = estimateOffset(matFile, A, varargin)
o = parseOpts(struct('b', '', 'plot', true), varargin);
b = o.b;
if isempty(b)
    m = matfile(matFile);
    if ~any(strcmp({whos(m).name}, 'b'))
        error('VS3_thermalTool:noScoring', 'No scoring found: score (or auto-score) the file first, the estimate uses the wake epochs.');
    end
    b = m.b;
end
if ~wakeFractionOk(b)
    error('VS3_thermalTool:noWake', 'The estimate needs both wake and sleep epochs in the scoring (at least 5%% of each).');
end
[est, out] = estimate_offset(matFile, 'A', A, 'b', b, 'plot', o.plot);
if isnan(out.ccMax)
    if isfield(out, 'fig') && isgraphics(out.fig); close(out.fig); end
    error('VS3_thermalTool:noOverlap', 'Not enough overlap between the video and the scoring to estimate the offset.');
end
end

%% ======================================================================= convert
function [h5File, ok] = convert(raviFile, varargin)
o = parseOpts(struct('interactive', true, 'output', '', 'overwrite', false, 'extraArgs', {{}}), varargin);
ok = false;
h5File = o.output;
if isempty(h5File)
    [p, n] = fileparts(raviFile);
    h5File = fullfile(p, [n, '.h5']);
end
if isfile(h5File) && ~o.overwrite
    if o.interactive
        an = questdlg(sprintf('A converted version of this video already exists:\n%s\n\nUse it (fast) or convert the video again?', h5File), ...
            'Converted video found', 'Use it', 'Convert again', 'Use it');
        if isempty(an); return; end
        if strcmp(an, 'Use it'); ok = true; return; end
    else
        ok = true;
        return
    end
end
if ~canWrite(fileparts(h5File))
    if ~o.interactive
        error('VS3_thermalTool:readonly', 'Cannot write in %s: give the option ''output''.', fileparts(h5File));
    end
    d = uigetdir(fileparts(raviFile), 'The video folder is read-only: where should the converted (.h5) file go?');
    if isequal(d, 0); return; end
    [~, n] = fileparts(raviFile);
    h5File = fullfile(d, [n, '.h5']);
end
exe = findPython(o.interactive);
if isempty(exe)
    if ~o.interactive
        error('VS3_thermalTool:noPython', 'No Python with numpy and h5py found (see VS3_thermalTool(''checkPython'', exe)).');
    end
    return
end
script = fullfile(thermalDir(), 'python', 'ravi2h5.py');
args = [{'-u', script, raviFile, '-o', h5File, '--overwrite'}, o.extraArgs];
logFile = [tempname, '_ravi2h5.log'];
[status, logTxt] = runWithProgress(exe, args, logFile, 'Converting the thermal video (.ravi -> .h5), a few minutes...', @convertParser, o.interactive);
if status == -1                      % cancelled
    if isfile(h5File); delete(h5File); end
    return
end
if status == 0 && isfile(logFile); delete(logFile); end
if status ~= 0 || ~isfile(h5File)
    if isfile(h5File); delete(h5File); end
    msg = sprintf('The conversion of the video failed (exit code %d). Last lines of the log:\n%s', status, logTail(logTxt, 12));
    if o.interactive; errordlg(msg, 'Thermal video'); return; else; error('VS3_thermalTool:convert', '%s', msg); end
end
ok = true;
end

function [frac, msg] = convertParser(logTxt)
frac = 0;
msg = 'Converting the thermal video: reading the file index...';
tok = regexp(logTxt, '(\d+)/(\d+) frames, (\d+)s elapsed, (\d+)s left', 'tokens');
if ~isempty(tok)
    t = tok{end};
    k = str2double(t{1}); n = str2double(t{2});
    frac = k / max(n, 1);
    msg = sprintf('Converting the thermal video: %d / %d frames, %s left', k, n, fmtTime(str2double(t{4})));
elseif ~isempty(regexp(logTxt, 'converting \d+ frames', 'once'))
    msg = 'Converting the thermal video: reading the metadata of every frame...';
end
end

%% ======================================================================= calibrate
function [ok, h5File] = calibrate(h5File, varargin)
o = parseOpts(struct('interactive', true, 'kennlinie', ''), varargin);
ok = false;
if nargin < 1; h5File = ''; end
if isempty(h5File) || ~isfile(h5File)
    if ~o.interactive
        error('VS3_thermalTool:noH5', 'Give the converted video (.h5).');
    end
    startDir = VS3_pref('get', 'thermalDir', pwd);
    if ~isfolder(startDir); startDir = pwd; end
    [f, p] = uigetfile({'*.h5', 'Converted thermal video (*.h5)'}, 'Select the converted video to calibrate', [stripSep(startDir), filesep]);
    if isequal(f, 0); return; end
    h5File = fullfile(p, f);
end
calibDir = fullfile(thermalDir(), 'calibration');
T = ThermalH5(h5File);
if isempty(o.kennlinie) && o.interactive
    msg = sprintf(['Select the characteristic curve of the camera that made this recording: ', ...
        'Kennlinie-%d-%d-*.prn (serial %d, %d degree lens). PIX Connect keeps it in %%APPDATA%%\\Imager\\Cali ', ...
        'on the PC connected to the camera. The file will be copied into\n%s'], T.attrs.serial, T.attrs.fov_deg, T.attrs.serial, T.attrs.fov_deg, calibDir);
    uiwait(msgbox(msg, 'Camera calibration', 'modal'));
    startDir = calibDir;
    appd = fullfile(getenv('APPDATA'), 'Imager', 'Cali');
    if isempty(dir(fullfile(calibDir, 'Kennlinie-*.prn'))) && isfolder(appd); startDir = appd; end
    [f, p] = uigetfile({'Kennlinie-*.prn', 'Optris characteristic curve (Kennlinie-*.prn)'}, ...
        sprintf('Select Kennlinie-%d-%d-*.prn', T.attrs.serial, T.attrs.fov_deg), [stripSep(startDir), filesep]);
    if isequal(f, 0); return; end
    o.kennlinie = fullfile(p, f);
end
if ~isempty(o.kennlinie)
    % Kennlinie-<serial>-<lens>-...prn: refuse the curve of another camera before using it
    tok = regexp(o.kennlinie, 'Kennlinie-(\d+)-(\d+)', 'tokens', 'once');
    if ~isempty(tok) && isfield(T.attrs, 'serial') && str2double(tok{1}) ~= double(T.attrs.serial)
        msg = sprintf(['This characteristic curve belongs to camera %s, but the video was recorded with camera %d: ', ...
            'the temperatures would be wrong. Select Kennlinie-%d-*.prn.'], tok{1}, T.attrs.serial, T.attrs.serial);
        if o.interactive; errordlg(msg, 'Camera calibration'); return; else; error('VS3_thermalTool:calibSerial', '%s', msg); end
    end
    [p, f, e] = fileparts(o.kennlinie);
    if o.interactive && ~strcmpi(stripSep(p), stripSep(calibDir))
        if ~isfolder(calibDir); mkdir(calibDir); end
        copyfile(o.kennlinie, fullfile(calibDir, [f, e]));
    end
end
exe = findPython(o.interactive);
if isempty(exe)
    if ~o.interactive
        error('VS3_thermalTool:noPython', 'No Python with numpy and h5py found.');
    end
    return
end
script = fullfile(thermalDir(), 'python', 'add_calibration.py');
args = {'-u', script, h5File};
if ~isempty(o.kennlinie); args = [args, {'--kennlinie', o.kennlinie}]; end
logFile = [tempname, '_add_calibration.log'];
[status, logTxt] = runWithProgress(exe, args, logFile, 'Adding the temperature calibration to the video...', @calibParser, o.interactive);
if status == -1; return; end
if status == 0 && isfile(logFile); delete(logFile); end
if status ~= 0
    msg = sprintf('Adding the calibration failed (exit code %d). Last lines of the log:\n%s', status, logTail(logTxt, 12));
    if o.interactive; errordlg(msg, 'Thermal video'); return; else; error('VS3_thermalTool:calibrate', '%s', msg); end
end
warn = regexp(logTxt, 'WARNING[^\n]*', 'match');
if ~isempty(warn)
    if o.interactive
        uiwait(warndlg(strjoin(warn, newline), 'Calibration warning', 'modal'));
    else
        fprintf('%s\n', warn{:});
    end
end
ok = true;
end

function [frac, msg] = calibParser(logTxt)
frac = 0;
msg = 'Adding the temperature calibration: building the lookup table...';
tok = regexp(logTxt, 'stats (\d+)/(\d+)', 'tokens');
if ~isempty(tok)
    t = tok{end};
    k = str2double(t{1}); n = str2double(t{2});
    frac = k / max(n, 1);
    msg = sprintf('Adding the temperature calibration: statistics %d / %d frames', k, n);
end
end

%% ======================================================================= python
function exe = findPython(interactive)
if nargin < 1; interactive = true; end
exe = '';
cands = {};
pref = VS3_pref('get', 'pythonExe', '');
if ~isempty(pref); cands{end+1} = pref; end
try %#ok<TRYNC>
    pe = pyenv;
    if strlength(pe.Executable) > 0; cands{end+1} = char(pe.Executable); end
end
[st, outp] = system('where python 2>NUL');
if st == 0
    lines = strtrim(strsplit(strtrim(outp), {'\r', '\n'}));
    cands = [cands, lines(~cellfun(@isempty, lines))];
end
[st, outp] = system('py -3 -c "import sys;print(sys.executable)" 2>NUL');
if st == 0 && ~isempty(strtrim(outp)); cands{end+1} = strtrim(outp); end
for root = {fullfile(getenv('LOCALAPPDATA'), 'Programs', 'Python'), getenv('ProgramFiles'), getenv('USERPROFILE')}
    d = [dir(fullfile(root{1}, 'Python3*', 'python.exe')); dir(fullfile(root{1}, '*conda3', 'python.exe'))];
    for k = 1:numel(d); cands{end+1} = fullfile(d(k).folder, d(k).name); end %#ok<AGROW>
end
cands = unique(cands, 'stable');
for k = 1:numel(cands)
    if isfile(cands{k}) && checkPython(cands{k})
        exe = cands{k};
        return
    end
end
if interactive
    uiwait(msgbox(['Python 3 with the packages numpy and h5py is needed to convert .ravi videos and was not found. ', ...
        'Install Python (python.org), run "pip install numpy h5py" in a command prompt, then select python.exe. ', ...
        'Or cancel and select an already converted .h5 video.'], 'Python needed', 'modal'));
    [f, p] = uigetfile({'python.exe', 'python.exe'}, 'Locate python.exe');
    if isequal(f, 0); return; end
    [okp, info] = checkPython(fullfile(p, f));
    if okp
        exe = fullfile(p, f);
    else
        errordlg(sprintf('This Python cannot import numpy and h5py:\n%s\n\nInstall them with:  pip install numpy h5py', info), 'Thermal video')
    end
end
end

function [ok, info] = checkPython(exe)
% run the interpreter once: it must import numpy and h5py; remembered in the preferences
ok = false;
info = '';
if isempty(exe) || ~isfile(exe); info = sprintf('%s does not exist', exe); return; end
[st, outp] = system(sprintf('"%s" -c "import sys, numpy, h5py; print(''Python'', sys.version.split()[0], ''numpy'', numpy.__version__, ''h5py'', h5py.__version__)" 2>&1', exe));
info = strtrim(outp);
if st == 0 && startsWith(info, 'Python')
    ok = true;
    info = sprintf('%s\n%s', exe, info);
    VS3_pref('set', 'pythonExe', exe);
end
end

%% ======================================================================= external process with progress bar
function [status, logTxt] = runWithProgress(exe, args, logFile, title, parser, interactive)
% run "exe args..." in the background, its output goes to logFile which is parsed every
% half second to update a waitbar (cancel button kills the process). status -1 = cancelled.
cmd = java.util.ArrayList();
cmd.add(java.lang.String(exe));
for k = 1:numel(args)
    cmd.add(java.lang.String(args{k}));
end
pb = java.lang.ProcessBuilder(cmd);
pb.redirectErrorStream(true);
pb.redirectOutput(java.io.File(logFile));
proc = pb.start();
w = [];
if interactive
    w = VS3_logo('waitbar', 0, title, 'Name', 'VeryScore3 - thermal video', 'CreateCancelBtn', 'setappdata(gcbf, ''canceling'', 1)');
    setappdata(w, 'canceling', 0);
else
    fprintf('%s\n', title);
end
lastMsg = '';
logTxt = '';
while proc.isAlive()
    pause(0.5)
    if interactive && (~ishandle(w) || isequal(getappdata(w, 'canceling'), 1))
        proc.destroy();
        pause(0.5)
        status = -1;
        if ishandle(w); delete(w); end
        logTxt = readLog(logFile);
        return
    end
    logTxt = readLog(logFile);
    [frac, msg] = parser(logTxt);
    if interactive
        waitbar(max(0, min(1, frac)), w, msg);
    elseif ~strcmp(msg, lastMsg)
        fprintf('  %s\n', msg);
        lastMsg = msg;
    end
end
status = proc.exitValue();
pause(0.2)
logTxt = readLog(logFile);
if ishandle(w); delete(w); end
end

function s = readLog(f)
s = '';
if isfile(f)
    try %#ok<TRYNC>
        s = fileread(f);
    end
end
end

function s = logTail(txt, n)
lines = strsplit(txt, {'\r', '\n'});
lines = lines(~cellfun(@isempty, strtrim(lines)));
s = strjoin(lines(max(1, end-n+1):end), newline);
end

%% ======================================================================= helpers
function ensurePath()
% the thermal code of this VeryScore3 folder, even when another copy (VeryScore2) is on the path
d = thermalDir();
w = which('thermal_roi_timeseries');
if isempty(w) || ~startsWith(w, d, 'IgnoreCase', true) || exist('ThermalH5', 'class') ~= 8
    addpath(d, fullfile(d, 'roi_methods'));
end
end

function d = thermalDir()
d = fullfile(fileparts(mfilename('fullpath')), 'thermal');
end

function o = parseOpts(o, args)
if mod(numel(args), 2) ~= 0
    error('VS3_thermalTool:options', 'Options must be name/value pairs.');
end
for k = 1:2:numel(args)
    name = args{k};
    if ~isfield(o, name)
        error('VS3_thermalTool:options', 'Unknown option "%s".', name);
    end
    o.(name) = args{k+1};
end
end

function [Fs, nSamples, nEpochs] = fileInfo(matFile, Fs, nSamples, nEpochs)
% sampling rate, number of samples and of 4-s epochs of the scoring file (VeryScore formats)
m = matfile(matFile);
w = whos(m);
names = {w.name};
if isempty(Fs)
    if any(strcmp(names, 'Infos'))
        I = m.Infos;
        if isfield(I, 'Fs')
            Fs = I.Fs;
            if ischar(Fs) || isstring(Fs); Fs = str2double(Fs); end
        end
    end
    if isempty(Fs) || isnan(Fs)
        error('VS3_thermalTool:noFs', 'The sampling rate (Infos.Fs) was not found in %s.', matFile);
    end
end
if isempty(nSamples)
    if any(strcmp(names, 'traces'))
        nSamples = max(w(strcmp(names, 'traces')).size);
    elseif any(strcmp(names, 't'))
        nSamples = max(w(strcmp(names, 't')).size) / 2;  % old format: the two channels concatenated
    else
        error('VS3_thermalTool:noTraces', 'No traces found in %s.', matFile);
    end
end
if isempty(nEpochs)
    if any(strcmp(names, 'b'))
        nEpochs = max(w(strcmp(names, 'b')).size);
    else
        nEpochs = floor(nSamples / Fs / 4);
    end
end
end

function saveVar(matFile, name, A)
S = struct();
S.(name) = A;
save(matFile, '-struct', 'S', '-append');
end

function ok = canWrite(folder)
ok = false;
if ~isfolder(folder); return; end
[~, tn] = fileparts(tempname);
f = fullfile(folder, ['.vs2_', tn, '.tmp']);
fid = fopen(f, 'w');
if fid < 0; return; end
fclose(fid);
delete(f);
ok = true;
end

function s = stripSep(p)
s = char(p);
while ~isempty(s) && (s(end) == '\' || s(end) == '/')
    s(end) = [];
end
end

function s = fmtTime(sec)
if isnan(sec) || isinf(sec)
    s = '?';
elseif sec < 60
    s = sprintf('%.0f s', sec);
elseif sec < 3600
    s = sprintf('%d min %02.0f s', floor(sec / 60), mod(sec, 60));
else
    s = sprintf('%d h %02d min', floor(sec / 3600), floor(mod(sec, 3600) / 60));
end
end
