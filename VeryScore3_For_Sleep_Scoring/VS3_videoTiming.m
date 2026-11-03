function varargout = VS3_videoTiming(action, varargin)
%VS3_VIDEOTIMING Clock maps of a recorder timing folder: video frames on the EEG time base.
%
% The recorder (camera of the Raspberry Pi, thermal camera, EEG) writes a timing folder for each
% saved recording: manifest.json, quality.json, evidence.jsonl, thermal-frame-times.csv,
% thermal-eeg-alignment.csv, thermal-eeg-quality.json (formats of 29 October 2026). When it is
% loaded (Tools > Video > Load recorder timing folder), each video gets a clock map that gives
% the EEG time of every frame, replacing the single offset of VS3_video. These are estimates of
% the PC software clocks: camera latency, EEG drift and the averaging of the thermal frames are
% not measured. Where the map has no valid observation the frames are not shown (no guess).
%
%   M = VS3_videoTiming('camera', folder, V, eegStartNs)   map of a Pi video V (VS3_video)
%   M = VS3_videoTiming('thermal', folder, V, eeg)         map of a thermal video V
%       eeg: struct of the EEG with fs, nSamples, firstSampleNumber, startUtcNs (see 'eeg')
%   eeg = VS3_videoTiming('eeg', Infos)                   that struct from the Infos of the file
%   M = VS3_videoTiming('build', S)        map from anchors S.native, S.common, S.valid, S.segment,
%                                          S.uncertainty (optional S.maxGap, S.errorMode)
%   [t, ok, u] = VS3_videoTiming('forward', M, native)    native clock -> EEG time (NaN outside)
%   [x, ok, u] = VS3_videoTiming('inverse', M, t)         EEG time -> native clock
%   ns = VS3_videoTiming('ns', text)       exact int64 nanoseconds from text (no rounding through double)
%   d = VS3_videoTiming('utc', text)       ISO time with its time zone -> datetime (UTC)
%   J = VS3_videoTiming('json', file)      jsondecode keeping long integers (epoch ns) exact
%
% Alejandro Osorio-Forero with Claude, 2026, from the recorder timing adapters written by Wenjie
% for the synchronized review (VeryScore3, October 2026).

switch lower(action)
    case 'camera';  varargout{1} = cameraMap(varargin{:});
    case 'thermal'; varargout{1} = thermalMap(varargin{:});
    case 'eeg';     varargout{1} = eegIdentity(varargin{:});
    case 'build';   varargout{1} = buildMap(varargin{:});
    case 'forward'; [varargout{1:3}] = mapTime(varargin{1}, varargin{2}, 'forward');
    case 'inverse'; [varargout{1:3}] = mapTime(varargin{1}, varargin{2}, 'inverse');
    case 'ns';      varargout{1} = integerNs(varargin{1});
    case 'utc';     varargout{1} = utcTime(varargin{1});
    case 'json';    varargout{1} = exactJson(fileread(varargin{1}));
    case 'folder';  varargout{1} = savedManifest(varargin{1});
    otherwise
        error('VS3_videoTiming:action', 'Unknown action "%s".', action);
end
end

%% ======================================================================= camera of the Pi
function M = cameraMap(folder, V, origin)
% Camera clock (CLOCK_BOOTTIME of the Pi) observed by the recording PC: each status observation
% of the camera, matched with its request/response clock comparison, gives one anchor
% (camera clock, EEG time). Restarts and clock steps start a new segment.
savedManifest(folder);
origin = integerNs(origin);
[videoFolder, name] = fileparts(V.file);
metaFile = fullfile(videoFolder, [name, '.json']);
if ~isfile(metaFile)
    error('VS3_videoTiming:camera', 'The metadata of the camera (%s.json) is not next to the video.', name);
end
meta = exactJson(fileread(metaFile));
if ~isfield(meta, 'schema_version') || meta.schema_version ~= 2 || ~isfield(meta, 'session') || ...
        ~isfield(meta, 'closed') || ~meta.closed || ~isfield(meta, 'clock_anchor') || ~isfield(meta, 'video')
    error('VS3_videoTiming:camera', 'The camera metadata must come from a finished recording (schema 2, closed).');
end
if ~strcmpi(leaf(meta.video), leaf(V.file))
    error('VS3_videoTiming:camera', 'The camera metadata belongs to another video (%s).', leaf(meta.video));
end
if ~strcmp(meta.clock_anchor.monotonic_clock, 'CLOCK_BOOTTIME')
    error('VS3_videoTiming:camera', 'The camera map needs the CLOCK_BOOTTIME observations of the camera.');
end
C = V.cameraClock();
if ~C.hasRaw || isempty(C.firstSensorNs)
    error('VS3_videoTiming:camera', 'The timestamps file of the video has no camera request times.');
end
quality = exactJson(fileread(fullfile(folder, 'quality.json')));
if ~isfield(quality, 'clock_comparisons')
    error('VS3_videoTiming:camera', 'quality.json has no clock comparisons of the camera.');
end
comparisons = items(quality.clock_comparisons);
events = readEvents(folder);
S = struct('native', [], 'common', [], 'valid', [], 'segment', [], 'uncertainty', []);
segment = 0;
lastId = '';
lastRemote = [];
for k = 1:numel(events)
    e = events{k};
    if ~isfield(e, 'device') || ~strcmp(e.device, 'camera') || ~isfield(e, 'event') || ...
            ~strcmp(e.event, 'status_observed') || ~isfield(e, 'details'); continue; end
    d = e.details;
    if ~all(isfield(d, {'session', 'instance', 'path', 'clock'})) || ~strcmp(d.session, meta.session) || ...
            ~strcmpi(leaf(d.path), leaf(V.file)); continue; end
    c = d.clock;
    if ~all(isfield(c, {'utc_ns', 'monotonic_ns', 'boot_id', 'monotonic_clock'})) || ...
            ~strcmp(c.boot_id, meta.clock_anchor.boot_id); continue; end
    if ~strcmp(c.monotonic_clock, 'CLOCK_BOOTTIME')
        error('VS3_videoTiming:camera', 'The camera observations mix clock domains.');
    end
    q = [];
    for j = 1:numel(comparisons)
        x = comparisons{j};
        if isfield(x, 'device') && strcmp(x.device, 'camera') && isfield(x, 'remote_clock') && ...
                integerNs(x.remote_clock.utc_ns) == integerNs(c.utc_ns) && ...
                integerNs(x.remote_clock.monotonic_ns) == integerNs(c.monotonic_ns) && strcmp(x.remote_clock.boot_id, c.boot_id)
            q = x;
            break
        end
    end
    if isempty(q); continue; end
    id = [char(c.boot_id), '|', char(d.instance)];
    remote = integerNs(c.monotonic_ns);
    transition = '';
    if isfield(q, 'transition'); transition = char(q.transition); end
    if segment == 0 || ~strcmp(id, lastId) || any(strcmp(transition, {'restart', 'clock_step'})) || ...
            (~isempty(lastRemote) && remote <= lastRemote)
        segment = segment + 1;
    end
    lastId = id;
    lastRemote = remote;
    ok = isfield(q, 'usable') && q.usable && ~(isfield(q, 'issues') && ~isempty(q.issues));
    common = NaN;
    u = NaN;
    if ok
        if ~isfield(q, 'offset_definition') || ~strcmp(q.offset_definition, 'remote_utc_minus_host_utc')
            error('VS3_videoTiming:camera', 'Unknown direction of the camera clock offset.');
        end
        utc = integerNs(c.utc_ns) - integerNs(q.estimated_offset_ns);
        common = double(utc - origin)/1e9;
        u = double(integerNs(q.uncertainty_ns));
        if isfield(c, 'capture_uncertainty_ns'); u = u + double(integerNs(c.capture_uncertainty_ns)); end
    end
    S.native(end+1) = double(remote - C.firstSensorNs)/1e9;
    S.common(end+1) = common;
    S.valid(end+1) = ok;
    S.segment(end+1) = segment;
    S.uncertainty(end+1) = u/1e9;
end
if isempty(S.native)
    error('VS3_videoTiming:camera', 'No camera observation of the timing folder belongs to this video (session, boot, file).');
end
S.maxGap = 180;
S.errorMode = 'linear';
M = buildMap(S);
M.coordinate = 'seconds';
M.frameValid = C.frameValid;
M.folder = char(folder);
M.note = 'PC software clock estimate; camera capture latency not calibrated';
end

%% ======================================================================= thermal camera
function M = thermalMap(folder, V, eeg)
% Every thermal frame mapped by the recorder onto an EEG sample number of one EEG stream. The
% stream of this EEG is found by its identity (rate, first sample, number of samples, start).
savedManifest(folder);
p = fullfile(folder, 'thermal-eeg-quality.json');
if ~isfile(p); error('VS3_videoTiming:thermal', 'The thermal map is not finished yet (no thermal-eeg-quality.json).'); end
Q = exactJson(fileread(p));
if ~isfield(Q, 'schema_version') || Q.schema_version ~= 1
    error('VS3_videoTiming:thermal', 'Unknown version of thermal-eeg-quality.json.');
end
if ~strcmpi(leaf(Q.thermal_path), leaf(V.file))
    error('VS3_videoTiming:thermal', 'The thermal map belongs to another video (%s).', leaf(Q.thermal_path));
end
stream = matchStream(Q, eeg);
n = double(Q.frames);
if n ~= V.nFrames
    error('VS3_videoTiming:thermal', 'The timing folder counts %d thermal frames, the video %d.', n, V.nFrames);
end
methods = strings(n, 1);
groups = strings(n, 1);
counters = nan(n, 1);
T = readCsv(fullfile(folder, 'thermal-frame-times.csv'), {'frame_index', 'counter_hw', 'transport_epoch', 'method'});
ix = str2double(T.frame_index) + 1;
if any(~isfinite(ix) | ix < 1 | ix > n | ix ~= fix(ix)); error('VS3_videoTiming:thermal', 'Invalid thermal frame index.'); end
methods(ix) = T.method;
groups(ix) = T.transport_epoch;
counters(ix) = str2double(T.counter_hw);
common = nan(n, 1);
ok = false(n, 1);
T = readCsv(fullfile(folder, 'thermal-eeg-alignment.csv'), {'frame_index', 'counter_hw', 'eeg_stream', 'eeg_sample_number_estimate', 'status'});
T = T(strcmpi(strrep(T.eeg_stream, '\', '/'), strrep(string(stream.path), '\', '/')), :);
ix = str2double(T.frame_index) + 1;
if any(~isfinite(ix) | ix < 1 | ix > n | ix ~= fix(ix)) || numel(unique(ix)) ~= numel(ix)
    error('VS3_videoTiming:thermal', 'Duplicate or invalid thermal frame in the alignment.');
end
if any(str2double(T.counter_hw) ~= counters(ix))
    error('VS3_videoTiming:thermal', 'The frame counters differ between the two thermal timing files.');
end
sample = str2double(T.eeg_sample_number_estimate);
good = strcmp(T.status, 'software_estimate') & ismember(methods(ix), ["native_counter_calibrated", "bounded_extrapolation"]) & isfinite(sample);
common(ix(good)) = (sample(good) - double(eeg.firstSampleNumber))/eeg.fs;
ok(ix) = good;
groups(ismissing(groups) | strlength(groups) == 0) = "unmapped"; % each transport epoch is its own segment
S = struct('native', (0:n-1)', 'common', common, 'valid', ok, 'segment', groups, 'uncertainty', nan(n, 1), 'maxGap', 1.01);
M = buildMap(S);
M.coordinate = 'frame_index';
M.folder = char(folder);
M.note = 'per-frame EEG software mapping; thermal capture/averaging reference not verified';
end

function eeg = eegIdentity(I)
% identity of the EEG stream from the Infos written by VS3_convertOpenEphys
need = {'Fs', 'nSamples', 'FirstSampleNumber', 'StartTimePosix'};
if ~all(isfield(I, need)) || ~isfinite(I.StartTimePosix)
    error('VS3_videoTiming:eeg', ['The recorder timing needs a file converted by File > Convert Open Ephys recording ', ...
        '(Infos.Fs, nSamples, FirstSampleNumber and StartTimePosix).']);
end
fs = I.Fs;
if ischar(fs); fs = str2double(fs); end
eeg = struct('fs', double(fs), 'nSamples', double(I.nSamples), 'firstSampleNumber', integerNs(I.FirstSampleNumber), ...
    'startUtcNs', int64(round(I.StartTimePosix*1e9)), 'recording', '');
if isfield(I, 'RecordingFolder'); eeg.recording = char(I.RecordingFolder); end
end

function s = matchStream(Q, eeg)
% the EEG stream of the timing report with the same rate, first sample, length and start (1 ms);
% when several Record Nodes have the same (they record the same board), the one of this recording
% (Record Node, experiment, recording in Infos.RecordingFolder)
streams = items(Q.eeg_streams);
same = [];
for k = 1:numel(streams)
    o = streams{k}.origin;
    if o.sample_rate == eeg.fs && integerNs(o.sample_number) == eeg.firstSampleNumber && ...
            streams{k}.samples == eeg.nSamples && abs(double(integerNs(o.utc_ns) - eeg.startUtcNs)) <= 1e6
        same(end+1) = k; %#ok<AGROW>
    end
end
if ~isempty(same)
    s = streams{same(1)};
    parts = regexp(char(eeg.recording), '[^\\/]+', 'match');
    if numel(parts) >= 3
        tail = lower(strjoin(parts(end-2:end), '/'));   % e.g. record node 117/experiment1/recording3
        for k = same
            if contains(lower(strjoin(regexp(char(streams{k}.path), '[^\\/]+', 'match'), '/')), tail); s = streams{k}; return; end
        end
    end
    return
end
error('VS3_videoTiming:eeg', ['No EEG stream of the timing folder is this recording (sampling rate, first sample ', ...
    'number, number of samples and start time are compared).']);
end

%% ======================================================================= clock maps
function M = buildMap(S)
% anchors (native clock, EEG time) in segments; each segment must increase in both clocks
need = {'native', 'common', 'valid', 'segment', 'uncertainty'};
if ~all(isfield(S, need)); error('VS3_videoTiming:map', 'The clock anchors miss fields.'); end
n = numel(S.native);
for k = 1:numel(need)
    if numel(S.(need{k})) ~= n; error('VS3_videoTiming:map', 'The clock anchors differ in length.'); end
end
if n == 0 || any(~isfinite(S.native)) || any(~isfinite(S.common(logical(S.valid))))
    error('VS3_videoTiming:map', 'The clock anchors must be finite where they are valid.');
end
M = struct('native', double(S.native(:)), 'common', double(S.common(:)), 'valid', logical(S.valid(:)), ...
    'segment', string(S.segment(:)), 'uncertainty', double(S.uncertainty(:)), 'maxGap', Inf, 'errorMode', 'max', ...
    'groups', [], 'coordinate', 'seconds');
if any(M.uncertainty < 0); error('VS3_videoTiming:map', 'Negative clock uncertainty.'); end
if isfield(S, 'maxGap'); M.maxGap = S.maxGap; end
if isfield(S, 'errorMode'); M.errorMode = char(S.errorMode); end
M.groups = unique(M.segment, 'stable');
for g = 1:numel(M.groups)
    ids = find(M.segment == M.groups(g));
    known = M.common(ids(M.valid(ids)));
    if any(diff(M.native(ids)) <= 0) || any(diff(known) <= 0)
        error('VS3_videoTiming:map', 'Each clock segment must increase in both clocks.');
    end
end
end

function [out, valid, uncertainty] = mapTime(M, query, direction)
% linear interpolation between valid neighbouring anchors of one segment, never across an
% invalid anchor, a gap longer than M.maxGap or two segments; NaN elsewhere
shape = size(query);
q = double(query(:));
out = nan(size(q));
uncertainty = out;
valid = false(size(q));
matches = zeros(size(q));
for g = 1:numel(M.groups)
    ids = find(M.segment == M.groups(g));
    if ~any(M.valid(ids)); continue; end
    if strcmp(direction, 'forward')
        [v, ok, u, covered] = interpolate(M.native(ids), M.common(ids), M.valid(ids), M.uncertainty(ids), q, M.maxGap, M.errorMode);
        merge(v, ok, u, covered);
    else
        % invalid EEG times cannot be ordered: each run of valid anchors separately
        run = diff([false; M.valid(ids) & isfinite(M.common(ids)); false]);
        starts = find(run == 1);
        stops = find(run == -1) - 1;
        for r = 1:numel(starts)
            b = ids(starts(r):stops(r));
            [v, ok, u, covered] = interpolate(M.common(b), M.native(b), M.valid(b), M.uncertainty(b), q, Inf, M.errorMode);
            if numel(b) > 1          % a gap of the native clock stays a gap
                bins = discretize(v, [M.native(b); Inf]);
                gap = diff(M.native(b));
                for a = find(ok & isfinite(bins) & bins < numel(b))'
                    if v(a) ~= M.native(b(bins(a))) && gap(bins(a)) > M.maxGap; ok(a) = false; end
                end
            end
            merge(v, ok, u, covered);
        end
    end
end
valid = valid & matches == 1;
out(~valid) = NaN;
uncertainty(~valid) = NaN;
out = reshape(out, shape);
valid = reshape(valid, shape);
uncertainty = reshape(uncertainty, shape);

    function merge(v, ok, u, covered)
        matches(covered) = matches(covered) + 1;
        out(ok) = v(ok);
        uncertainty(ok) = u(ok);
        valid(ok) = true;
    end
end

function [v, ok, u, covered] = interpolate(x, y, flags, errors, q, maxGap, errorMode)
v = nan(size(q));
u = v;
ok = false(size(q));
covered = isfinite(q) & q >= x(1) & q <= x(end);
if ~any(covered); return; end
active = find(covered);
bins = discretize(q(active), [x; Inf]);
for k = 1:numel(active)
    a = active(k);
    b = bins(k);
    if q(a) == x(b)
        if flags(b); v(a) = y(b); u(a) = errors(b); ok(a) = isfinite(v(a)); end
    elseif b < numel(x) && flags(b) && flags(b+1) && x(b+1) - x(b) <= maxGap
        f = (q(a) - x(b))/(x(b+1) - x(b));
        v(a) = y(b) + f*(y(b+1) - y(b));
        if isfinite(errors(b)) && isfinite(errors(b+1))
            if strcmp(errorMode, 'linear'); u(a) = errors(b) + f*(errors(b+1) - errors(b));
            else; u(a) = max(errors(b:b+1)); end
        end
        ok(a) = isfinite(v(a));
    end
end
end

%% ======================================================================= files
function manifest = savedManifest(folder)
p = fullfile(folder, 'manifest.json');
if ~isfile(p); error('VS3_videoTiming:folder', 'There is no manifest.json in this folder: not a recorder timing folder.'); end
manifest = exactJson(fileread(p));
if ~isfield(manifest, 'schema_version') || manifest.schema_version ~= 1 || ...
        ~isfield(manifest, 'recording_state') || ~strcmp(manifest.recording_state, 'saved')
    error('VS3_videoTiming:folder', 'This recording is not finished (recording_state is not "saved").');
end
end

function list = readEvents(folder)
% the events of evidence.jsonl, or those embedded in manifest.json when it was not copied
p = fullfile(folder, 'evidence.jsonl');
list = {};
if ~isfile(p)
    J = savedManifest(folder);
    if isfield(J, 'devices')
        devices = fieldnames(J.devices);
        for k = 1:numel(devices)
            if isfield(J.devices.(devices{k}), 'events')
                list = [list, reshape(items(J.devices.(devices{k}).events), 1, [])]; %#ok<AGROW>
            end
        end
    end
    return
end
fid = fopen(p, 'r');
cleanup = onCleanup(@() fclose(fid));
while ~feof(fid)
    line = fgetl(fid);
    if ~ischar(line) || isempty(strtrim(line)); continue; end
    e = exactJson(line);
    if isfield(e, 'schema_version') && e.schema_version ~= 1
        error('VS3_videoTiming:folder', 'Unknown version of evidence.jsonl.');
    end
    list{end+1} = e; %#ok<AGROW>
end
end

function T = readCsv(p, need)
% a timing CSV, every column as text (sample numbers and nanoseconds stay exact)
if ~isfile(p); error('VS3_videoTiming:folder', 'A file of the timing folder is missing: %s', p); end
o = detectImportOptions(p, 'Delimiter', ',');
o = setvartype(o, o.VariableNames, 'string');
T = readtable(p, o);
if ~all(ismember(need, T.Properties.VariableNames))
    error('VS3_videoTiming:folder', 'Columns missing in %s.', p);
end
end

function J = exactJson(text)
% jsondecode would round epoch nanoseconds through double: long integers are read as text
[first, last, tokens] = regexp(text, '"(?:\\.|[^"\\])*"|-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?', 'start', 'end', 'match');
parts = {};
previous = 1;
for k = 1:numel(tokens)
    if ~isempty(regexp(tokens{k}, '^-?\d{16,}$', 'once'))
        parts{end+1} = text(previous:first(k)-1); %#ok<AGROW>
        parts{end+1} = ['"', tokens{k}, '"']; %#ok<AGROW>
        previous = last(k) + 1;
    end
end
parts{end+1} = text(previous:end);
J = jsondecode([parts{:}]);
end

function value = integerNs(x)
% exact int64 nanoseconds from int64, an exact double or decimal text
if isa(x, 'int64'); value = x; return; end
if isnumeric(x)
    if any(~isfinite(x(:)) | x(:) ~= fix(x(:)) | abs(x(:)) > flintmax)
        error('VS3_videoTiming:ns', 'Nanoseconds must be given as text or int64.');
    end
    value = int64(x);
    return
end
s = strip(string(x));
shape = size(s);
s = s(:);
if any(ismissing(s) | strlength(s) == 0); error('VS3_videoTiming:ns', 'Missing nanoseconds.'); end
negative = startsWith(s, '-');
s(negative) = extractAfter(s(negative), 1);
if any(~matches(s, digitsPattern)); error('VS3_videoTiming:ns', 'Invalid nanosecond integer.'); end
c = char(pad(s, max(strlength(s)), 'left', '0'));
value = zeros(numel(s), 1, 'int64');
for k = 1:size(c, 2)
    d = int64(c(:, k) - '0');
    if any(value > idivide(intmax('int64') - d, int64(10), 'floor')); error('VS3_videoTiming:ns', 'Nanosecond overflow.'); end
    value = value*int64(10) + d;
end
value(negative) = -value(negative);
value = reshape(value, shape);
end

function d = utcTime(s)
% '2026-10-20T02:02:03.350427+00:00' or '...Z' -> datetime in UTC (no time zone = refused)
t = regexp(char(s), '^(\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d)(\.\d{1,9})?(Z|[+-]\d\d:\d\d)$', 'tokens', 'once');
if isempty(t); error('VS3_videoTiming:utc', 'A time with its time zone is needed, got "%s".', char(s)); end
d = datetime([t{1}, t{3}], 'InputFormat', "yyyy-MM-dd'T'HH:mm:ssXXX", 'TimeZone', 'UTC');
if ~isempty(t{2}); d = d + seconds(str2double(t{2})); end
d.Format = 'yyyy-MM-dd HH:mm:ss.SSSSSS';
end

function c = items(x)
if iscell(x); c = x; else; c = num2cell(x); end
end

function n = leaf(p)
[~, n, e] = fileparts(strrep(char(p), '\', '/'));
n = [n, e];
end
