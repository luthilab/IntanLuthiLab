function files = VS3_convertOpenEphys(sourceFolder, targetFolder, varargin)
%VS3_CONVERTOPENEPHYS Convert Open Ephys recordings (binary format, GUI 0.6 / 1.x) into VeryScore files.
%
%   VS3_convertOpenEphys                          asks for both folders (File > Convert Open Ephys recording...)
%   VS3_convertOpenEphys(sourceFolder)            asks for the folder of the converted files
%   VS3_convertOpenEphys(sourceFolder, targetFolder)
%   VS3_convertOpenEphys(..., 'unit', 'uV', 'overwrite', false, 'interactive', false)
%   files = VS3_convertOpenEphys(...)             the .mat files written (cell array of paths)
%
% Every Open Ephys recording found below sourceFolder (any depth: <animal>\experiment1\recording1 as
% well as <session>\Record Node 115\experiment1\recording1) is converted into
%     <targetFolder>\<name>_<yymmdd>.mat
% with the variables VeryScore expects plus everything useful the recording contains:
%
%   traces     [nChannels x nSamples] double, every recorded channel exactly as it was recorded
%   traceName  {1 x nChannels} channel names, e.g. {'CH6','CH7','CH12','CH13','ADC1'}
%   Infos      struct (all fields are text or numbers, so File > Edit file Infos works):
%     Fs, Channel, Unit, BitVolts, ChannelUnits, nSamples, Duration
%     StartTime          time of the first sample, clock of the recording PC, 'yyyy-MM-dd HH:mm:ss.SSS'
%                        (Tools > Thermal video uses it to align the thermal video)
%     StartTimePosix, TimeZone, EndTime, Date, DroppedSamples
%     SoftwareTimeMs, StartSampleNumber, FirstSampleNumber
%     Animal, RecordingFolder, Experiment, Recording, Stream, SourceProcessor
%     OpenEphysVersion, Machine, SettingsDate, RecordedChannels, Converter, ConvertedOn
%   Events     (when TTL events were recorded) sampleNumber, time, line, rising, fullWord
%   Messages   (when messages were recorded) sampleNumber, time, text
%
% THE CHANNELS ARE SAVED RAW. Each channel is the recorded int16 samples times the bit_volts of
% that channel, in volts: Open Ephys gives bit_volts in the unit of the channel ('uV' for the
% headstage channels, 'V' for the ADC inputs, see structure.oebin). Nothing is filtered,
% demodulated, rescaled, added or removed. An ADC channel that carries a fibre photometry detector
% output stays the modulated detector signal (e.g. 0.4 to 4.6 V): its dF/F is computed in
% VeryScore3 with Tools > Photometry.
%
% OPTIONS (name/value, all optional)
%   'unit'         'V' (default) | 'uV' | 'raw/1000' (int16 value / 1000, the first VeryScore converter)
%   'overwrite'    true (default) | false: skip recordings whose .mat already exists. When the
%                  folders are asked and converted files exist already, you are asked.
%   'channels'     channels to convert: their names ({'CH6','CH7'}) or their numbers in the
%                  recording; empty (default) = all. When the folders are asked, you choose the
%                  recordings (when there are several) and the channels in lists.
%   'interactive'  true (default when the folders are asked) | false: no dialogs, messages in the
%                  command window only
%
% Self-contained: the .npy files of the recording are read here (no npy-matlab needed).
% Same conversion as ToVS2_2026 (Alejandro Osorio-Forero, 2026), the converter used before VeryScore3.
%
% Alejandro Osorio-Forero with Claude, 2026.

files = {};
o = struct('unit', 'V', 'overwrite', true, 'interactive', [], 'channels', []);
for k = 1:2:numel(varargin)
    if ~isfield(o, varargin{k}); error('VS3_convertOpenEphys:option', 'Unknown option ''%s''.', varargin{k}); end
    o.(varargin{k}) = varargin{k + 1};
end
if isempty(o.interactive); o.interactive = nargin < 2; end

%% ---------------- folders ----------------
if nargin < 1 || isempty(sourceFolder)
    if ~o.interactive; error('VS3_convertOpenEphys:folder', 'Give the folder holding the Open Ephys recording(s).'); end
    sourceFolder = uigetdir(startFolder('openEphysSource'), 'Select the folder holding the Open Ephys recording(s)');
    if isequal(sourceFolder, 0); return; end
end
if ~isfolder(sourceFolder)
    error('VS3_convertOpenEphys:folder', 'Folder not found: %s', sourceFolder);
end
if nargin < 2 || isempty(targetFolder)
    if ~o.interactive; error('VS3_convertOpenEphys:folder', 'Give the folder for the converted files.'); end
    targetFolder = uigetdir(startFolder('openEphysTarget'), 'Select the folder where the VeryScore files go');
    if isequal(targetFolder, 0); return; end
end
if ~isfolder(targetFolder)
    mkdir(targetFolder);
end
if o.interactive
    VS3_pref('set', 'openEphysSource', fileparts(normPath(sourceFolder)));
    VS3_pref('set', 'openEphysTarget', targetFolder);
end

recs = findRecordings(sourceFolder);
if isempty(recs)
    msg = sprintf('No Open Ephys recording (experiment*\\recording*\\structure.oebin with data) found below\n%s', sourceFolder);
    report(o, msg, 'warn');
    return
end
if o.interactive
    % the recordings (when there are several), the channels, the files converted already
    [recs, o.channels, ok] = chooseRecordings(recs, o.channels);
    if ~ok; return; end
    done = arrayfun(@(r) ~isempty(dir(fullfile(targetFolder, [r.name, '_*', r.suffix, '.mat']))), recs);
    if any(done)
        an = questdlg(sprintf('%d of the recordings seem to be converted already in %s.', sum(done), targetFolder), ...
            'Open Ephys conversion', 'Skip them', 'Convert them again', 'Cancel', 'Skip them');
        if isempty(an) || strcmp(an, 'Cancel'); return; end
        o.overwrite = strcmp(an, 'Convert them again');
    end
end
w = [];
if o.interactive
    w = VS3_logo('waitbar', 0, 'Converting...', 'Name', 'VeryScore3 - Open Ephys');
    set(findall(w, 'Type', 'text'), 'Interpreter', 'none');
end
failed = {};
for k = 1:numel(recs)
    fprintf('Recording %d/%d: %s\n', k, numel(recs), recs(k).name);
    progress = @(f, txt) step(w, (k - 1 + f) / numel(recs), sprintf('%d/%d %s: %s', k, numel(recs), recs(k).name, txt));
    try
        target = convertOne(recs(k), targetFolder, o, progress);
        if ~isempty(target); files{end + 1} = target; end %#ok<AGROW>
    catch err
        fprintf(2, '  FAILED: %s\n', err.message);
        failed{end + 1} = sprintf('%s: %s', recs(k).name, err.message); %#ok<AGROW>
    end
end
if ~isempty(w) && isvalid(w); delete(w); end
names = cellfun(@(f) char(regexprep(f, '^.*[\\/]', '')), files, 'UniformOutput', false);
msg = sprintf('%d file(s) written to %s', numel(files), targetFolder);
if ~isempty(names); msg = sprintf('%s:\n%s', msg, strjoin(names, newline)); end
if ~isempty(failed)
    msg = sprintf('%s\n\nFAILED:\n%s', msg, strjoin(failed, newline));
    report(o, msg, 'error');
else
    report(o, msg, 'info');
end
end

%% ======================================================================= one recording
function target = convertOne(rec, targetFolder, opt, progress)
target = '';
recDir = rec.recDir;
oe = jsondecode(fileread(fullfile(recDir, 'structure.oebin')));

% ---- the continuous stream with the data (not the memory_usage stream) ----
cont = oe.continuous;
c = [];
for k = 1:numel(cont)
    ck = item(cont, k);
    if ck.num_channels > 0 && isempty(regexpi(ck.stream_name, 'memory', 'once'))
        if isempty(c); c = ck; else; fprintf('  note: several data streams, converting only %s\n', c.stream_name); end
    end
end
if isempty(c)
    fprintf('  no data stream (only %s), skipped\n', strjoin(arrayfun(@(i) item(cont, i).stream_name, 1:numel(cont), 'uni', 0), ', '));
    return
end
Fs = double(c.sample_rate);
nCh = double(c.num_channels);
chans = c.channels;
names = cell(1, nCh); bitVolts = zeros(1, nCh); chUnits = cell(1, nCh);
for k = 1:nCh
    chk = item(chans, k);
    names{k} = chk.channel_name;
    bitVolts(k) = chk.bit_volts;
    if isfield(chk, 'units'); chUnits{k} = chk.units; else; chUnits{k} = 'uV'; end
end
streamDir = fullfile(recDir, 'continuous', c.folder_name);
% the channels to convert (option 'channels': names or numbers in the recording, empty = all)
sel = 1:nCh;
if iscell(opt.channels) || isstring(opt.channels)
    sel = find(ismember(names, cellstr(opt.channels)));
elseif ~isempty(opt.channels)
    sel = unique(opt.channels(:)', 'stable');
    if any(sel < 1 | sel > nCh | sel ~= round(sel)); error('channels %s do not exist (%d channels)', mat2str(sel), nCh); end
end
if isempty(sel)
    fprintf('  none of the chosen channels is in this recording, skipped\n');
    return
end
nRecorded = nCh;

% ---- data: the raw samples of every channel, in physical units ----
progress(0.05, 'reading the samples');
datFile = fullfile(streamDir, 'continuous.dat');
fid = fopen(datFile, 'r');
if fid < 0; error('cannot open %s', datFile); end
raw = fread(fid, [nRecorded, Inf], 'int16=>int16');
fclose(fid);
raw = raw(sel, :);
names = names(sel); bitVolts = bitVolts(sel); chUnits = chUnits(sel);
nCh = numel(sel);
% volts: bit_volts is given in the unit of the channel ('uV' for headstage, 'V' for ADC inputs)
toVolts = bitVolts .* cellfun(@(u) unitFactor(u), chUnits);
switch lower(opt.unit)
    case 'v';       traces = double(raw) .* toVolts(:);            unitStr = 'V';
    case 'uv';      traces = double(raw) .* toVolts(:) * 1e6;      unitStr = 'uV';
    case 'raw/1000';traces = double(raw) / 1000;                   unitStr = 'raw/1000 (int16 ADC value / 1000)';
    otherwise;      error('unknown unit %s', opt.unit);
end
clear raw
nS = size(traces, 2);

% ---- sample numbers (gaps) ----
sn = readNpy(fullfile(streamDir, 'sample_numbers.npy'));
sn = double(sn(:));
if numel(sn) ~= nS
    warning('VS3_convertOpenEphys:samples', '%d sample numbers for %d samples in %s', numel(sn), nS, streamDir);
end
dropped = 0;
if numel(sn) > 1; dropped = sum(diff(sn) - 1); end

% ---- start time ----
sync = fullfile(recDir, 'sync_messages.txt');
softMs = NaN; startSample = NaN;
if isfile(sync)
    txt = fileread(sync);
    ms = regexp(txt, 'Software Time[^:\n]*:\s*(\d+)', 'tokens', 'once');
    if ~isempty(ms); softMs = str2double(ms{1}); end
    tok = regexp(txt, 'Start Time for ([^\n]*?) @ ([\d.]+)\s*Hz:\s*(\d+)', 'tokens');
    for k = 1:numel(tok)
        if endsWith(strtrim(tok{k}{1}), c.stream_name); startSample = str2double(tok{k}{3}); break; end
    end
    if isnan(startSample) && ~isempty(tok)
        for k = 1:numel(tok)
            if isempty(regexpi(tok{k}{1}, 'memory', 'once')); startSample = str2double(tok{k}{3}); break; end
        end
    end
end
t0 = NaT;
if ~isnan(softMs)
    t0 = datetime(softMs / 1000, 'ConvertFrom', 'posixtime', 'TimeZone', 'local');
    if ~isnan(startSample) && ~isempty(sn); t0 = t0 + seconds((sn(1) - startSample) / Fs); end
else
    warning('VS3_convertOpenEphys:time', 'no sync_messages.txt in %s: StartTime unknown', recDir);
end

% ---- settings.xml ----
version = ''; settingsDate = ''; machine = ''; recorded = '';
sx = rec.settingsFile;
if ~isempty(sx) && isfile(sx)
    s = fileread(sx);
    version = xmlTag(s, 'VERSION');
    settingsDate = xmlTag(s, 'DATE');
    m = regexp(s, '<MACHINE name="([^"]*)"', 'tokens', 'once'); if ~isempty(m); machine = m{1}; end
    m = regexp(s, '<PROCESSOR name="Record Node".*?<STREAM name="[^"]*"[^>]*>\s*<PARAMETERS channels="([^"]*)"', 'tokens', 'once');
    if ~isempty(m); recorded = m{1}; end
end

% ---- Infos ----
fmt = 'yyyy-MM-dd HH:mm:ss.SSS';
Infos = struct();
Infos.Fs = Fs;
Infos.Channel = strjoin(names, ', ');
Infos.Unit = unitStr;
Infos.BitVolts = bitVolts;
Infos.ChannelUnits = strjoin(chUnits, ', ');
Infos.nSamples = nS;
Infos.Duration = nS / Fs;
if ~isnat(t0)
    Infos.StartTime = char(string(t0, fmt));
    Infos.StartTimePosix = posixtime(t0);
    Infos.TimeZone = t0.TimeZone;
    Infos.EndTime = char(string(t0 + seconds((nS - 1) / Fs), fmt));
    Infos.Date = char(string(t0, 'yyyy-MM-dd'));
else
    Infos.StartTime = ''; Infos.StartTimePosix = NaN; Infos.TimeZone = ''; Infos.EndTime = '';
    Infos.Date = dateFromFolder(recDir, settingsDate);
end
Infos.DroppedSamples = dropped;
Infos.SoftwareTimeMs = softMs;
Infos.StartSampleNumber = startSample;
Infos.FirstSampleNumber = sn(1);
Infos.Animal = rec.name;
Infos.RecordingFolder = recDir;
[expName, recName] = expRec(recDir);
Infos.Experiment = expName;
Infos.Recording = recName;
Infos.Stream = c.stream_name;
Infos.SourceProcessor = c.source_processor_name;
Infos.OpenEphysVersion = version;
Infos.Machine = machine;
Infos.SettingsDate = settingsDate;
Infos.RecordedChannels = recorded;
Infos.ConvertedChannels = sel;  % numbers of the converted channels in the recording (all when nothing was chosen)
Infos.Converter = 'VS3_convertOpenEphys (Open Ephys binary -> VeryScore), VeryScore3 3.0, raw channels';
Infos.ConvertedOn = char(string(datetime('now'), fmt));
traceName = names; %#ok<NASGU>

% ---- events and messages ----
vars = {'Infos', 'traceName', 'traces'};
Events = readTTL(oe, recDir, sn(1), Fs);
if ~isempty(Events); vars{end + 1} = 'Events'; end
Messages = readMessages(recDir, sn(1), Fs);
if ~isempty(Messages); vars{end + 1} = 'Messages'; end

% ---- save ----
if isempty(Infos.Date)
    yymmdd = 'unknown';
else
    yymmdd = char(string(datetime(Infos.Date, 'InputFormat', 'yyyy-MM-dd'), 'yyMMdd'));
end
target = fullfile(targetFolder, [rec.name, '_', yymmdd, rec.suffix, '.mat']);
if isfile(target) && ~opt.overwrite
    fprintf('  exists, skipped: %s\n', target);
    return
end
progress(0.5, sprintf('saving %.0f MB', 8 * numel(traces) / 1e6));
save(target, vars{:}, '-v7.3');
fprintf('  %d channels (%s), %d samples at %g Hz = %.2f h, start %s, %d dropped samples -> %s\n', ...
    nCh, Infos.Channel, nS, Fs, Infos.Duration / 3600, Infos.StartTime, dropped, target);
end

%% ======================================================================= helpers
function [recs, channels, ok] = chooseRecordings(recs, channels)
% chooseRecordings  Lists to choose the recordings (when there are several) and their channels.
ok = false;
info = cell(1, numel(recs));
chans = cell(1, numel(recs));
for k = 1:numel(recs)
    [txt, chans{k}] = describeRecording(recs(k).recDir);
    info{k} = sprintf('%s   |   %s   |   %s', [recs(k).name, recs(k).suffix], txt, recs(k).recDir);
end
if numel(recs) > 1
    [sel, okd] = listdlg('ListString', info, 'SelectionMode', 'multiple', 'InitialValue', 1:numel(recs), ...
        'ListSize', [900 260], 'Name', 'Open Ephys conversion', 'PromptString', 'Recordings to convert:');
    if ~okd || isempty(sel); return; end
    recs = recs(sel);
    chans = chans(sel);
end
names = {};
for k = 1:numel(chans); names = [names, chans{k}(~ismember(chans{k}, names))]; end %#ok<AGROW>
if isempty(channels) && ~isempty(names)
    [sel, okd] = listdlg('ListString', names, 'SelectionMode', 'multiple', 'InitialValue', 1:numel(names), ...
        'ListSize', [300 320], 'Name', 'Open Ephys conversion', ...
        'PromptString', {'Channels to convert (Ctrl / Shift: several).', 'Memory monitoring is never converted.'});
    if ~okd || isempty(sel); return; end
    if numel(sel) < numel(names); channels = names(sel); end
end
ok = true;
end

function [txt, names] = describeRecording(recDir)
% describeRecording  'stream: n channels, Fs Hz, duration' and the channel names of the data stream
txt = '?';
names = {};
try
    oe = jsondecode(fileread(fullfile(recDir, 'structure.oebin')));
    for k = 1:numel(oe.continuous)
        c = item(oe.continuous, k);
        if c.num_channels <= 0 || ~isempty(regexpi(c.stream_name, 'memory', 'once')); continue; end
        d = dir(fullfile(recDir, 'continuous', c.folder_name, 'continuous.dat'));
        dur = NaN;
        if ~isempty(d); dur = d.bytes/(2*c.num_channels*c.sample_rate); end
        txt = sprintf('%s: %d channels, %g Hz, %.2f h', c.stream_name, c.num_channels, c.sample_rate, dur/3600);
        names = arrayfun(@(i) item(c.channels, i).channel_name, 1:c.num_channels, 'UniformOutput', false);
        return
    end
catch
end
end

function recs = findRecordings(root)
% every experiment*/recording*/structure.oebin below root, at any depth, with a readable name.
% Record nodes that hold no data stream (only memory_usage) are left out, so that a session with
% one real node does not get a "_RecordNode115" suffix just because a second node exists.
% A folder inside a recording (continuous, or the folder of a stream) means that recording.
hits = dir(fullfile(root, '**', 'structure.oebin'));
up = root;
for k = 1:3
    if ~isempty(hits); break; end
    up = fileparts(up);
    if isfile(fullfile(up, 'structure.oebin')); root = up; hits = dir(fullfile(root, 'structure.oebin')); end
end
recs = struct('recDir', {}, 'name', {}, 'suffix', {}, 'settingsFile', {});
normRoot = normPath(root);
for k = 1:numel(hits)
    recDir = hits(k).folder;
    [expDir, recName] = fileparts(recDir);
    [nodeDir, expName] = fileparts(expDir);
    if isempty(regexpi(recName, '^recording\d*$', 'once')) || isempty(regexpi(expName, '^experiment\d*$', 'once'))
        continue                                  % not the standard layout
    end
    if ~hasDataStream(fullfile(recDir, 'structure.oebin'))
        continue
    end
    rel = recDir;                                 % path of the recording relative to root
    if startsWith(lower(normPath(recDir)), lower(normRoot))
        rel = extractAfter(normPath(recDir), strlength(normRoot));
    end
    parts = regexp(rel, '[\\/]+', 'split');
    parts = parts(~cellfun(@isempty, parts));
    keep = parts(cellfun(@(s) isempty(regexpi(s, '^(experiment\d*|recording\d*|Record[ _]?Node.*)$', 'once')), parts));
    if isempty(keep)
        [~, base] = fileparts(root);
        name = base;
    else
        name = strjoin(keep, '_');
    end
    sfile = fullfile(nodeDir, 'settings.xml');
    if ~isfile(sfile); sfile = fullfile(fileparts(nodeDir), 'settings.xml'); end
    recs(end + 1) = struct('recDir', recDir, 'name', safeName(name), ...
        'suffix', '', 'settingsFile', sfile); %#ok<AGROW>
end
% disambiguate recordings that ended up with the same name
[u, ~, ic] = unique({recs.name});
for k = 1:numel(u)
    idx = find(ic == k);
    if numel(idx) > 1
        for j = 1:numel(idx)
            [expDir, recName] = fileparts(recs(idx(j)).recDir);
            [nodeDir, expName] = fileparts(expDir);
            [~, node] = fileparts(nodeDir);
            recs(idx(j)).suffix = ['_' safeName([node '_' expName '_' recName])];
        end
    end
end
end

function tf = hasDataStream(oebinFile)
% true when the recording holds a continuous stream with channels that is not the memory monitor
tf = false;
try
    oe = jsondecode(fileread(oebinFile));
catch
    return
end
if ~isfield(oe, 'continuous'); return; end
for k = 1:numel(oe.continuous)
    c = item(oe.continuous, k);
    if c.num_channels > 0 && isempty(regexpi(c.stream_name, 'memory', 'once')); tf = true; return; end
end
end

function p = normPath(p)
% one separator style, no trailing separator: makes "is this below that folder" comparisons work
% even when the user typed forward slashes on Windows
p = regexprep(char(p), '[\\/]+', filesep);
p = regexprep(p, [regexptranslate('escape', filesep) '$'], '');
end

function s = safeName(s)
% keep the folder name as it is, only dropping the characters Windows forbids in a file name
s = regexprep(strtrim(s), '[<>:"/\\|?*]', '-');
s = regexprep(s, '\s+', '_');
end

function f = unitFactor(u)
% factor that turns 'bit_volts in unit u' into volts
switch lower(strtrim(char(u)))
    case {'v', 'volt', 'volts'}; f = 1;
    case {'mv'};                 f = 1e-3;
    case {'uv', char([181 118]), 'microvolt', 'microvolts'}; f = 1e-6;
    otherwise;                   f = 1e-6;       % Open Ephys headstage default
end
end

function x = item(arr, k)
if iscell(arr); x = arr{k}; else; x = arr(k); end
end

function v = xmlTag(s, tag)
v = '';
m = regexp(s, ['<', tag, '>(.*?)</', tag, '>'], 'tokens', 'once');
if ~isempty(m); v = strtrim(m{1}); end
end

function [expName, recName] = expRec(recDir)
[expDir, recName] = fileparts(recDir);
[~, expName] = fileparts(expDir);
end

function d = dateFromFolder(recDir, settingsDate)
m = regexp(recDir, '(\d{4}-\d{2}-\d{2})', 'tokens', 'once');
if ~isempty(m); d = m{1}; return; end
d = '';
try
    d = char(string(datetime(settingsDate, 'InputFormat', 'd MMM yyyy HH:mm:ss', 'Locale', 'en_US'), 'yyyy-MM-dd'));
catch
end
end

function E = readTTL(oe, recDir, firstSample, Fs)
E = [];
if ~isfield(oe, 'events'); return; end
ev = oe.events;
for k = 1:numel(ev)
    e = item(ev, k);
    if isempty(regexp(e.folder_name, 'TTL', 'once')); continue; end
    d = fullfile(recDir, 'events', e.folder_name);
    if ~isfile(fullfile(d, 'sample_numbers.npy')); continue; end
    sn = double(readNpy(fullfile(d, 'sample_numbers.npy')));
    if isempty(sn); continue; end
    st = double(readNpy(fullfile(d, 'states.npy')));
    E = struct();
    E.sampleNumber = sn(:);
    E.time = (sn(:) - firstSample) / Fs;
    E.line = abs(st(:));
    E.rising = st(:) > 0;
    fw = fullfile(d, 'full_words.npy');
    if isfile(fw); E.fullWord = double(readNpy(fw)); E.fullWord = E.fullWord(:); end
    E.channelName = e.channel_name;
    return
end
end

function M = readMessages(recDir, firstSample, Fs)
M = [];
d = fullfile(recDir, 'events', 'MessageCenter');
if ~isfile(fullfile(d, 'text.npy')); return; end
try
    sn = double(readNpy(fullfile(d, 'sample_numbers.npy')));
    txt = readNpyStrings(fullfile(d, 'text.npy'));
catch
    return
end
if isempty(sn); return; end
M = struct();
M.sampleNumber = sn(:);
M.time = (sn(:) - firstSample) / Fs;
M.text = txt(:);
end

function [hdr, fid, cl] = openNpy(f)
% open a .npy file (format 1.0 / 2.0 / 3.0) and read its header; the file stays open at the data
fid = fopen(f, 'r', 'ieee-le');
if fid < 0; error('VS3_convertOpenEphys:npy', 'Cannot open %s.', f); end
cl = onCleanup(@() fclose(fid));
magic = fread(fid, 6, 'uint8=>char')';
if numel(magic) < 6 || ~strcmp(magic(2:6), 'NUMPY'); error('VS3_convertOpenEphys:npy', 'Not a .npy file: %s', f); end
ver = fread(fid, 2, 'uint8');
if ver(1) == 1; hlen = fread(fid, 1, 'uint16'); else; hlen = fread(fid, 1, 'uint32'); end
hdr = fread(fid, hlen, 'uint8=>char')';
end

function x = readNpy(f)
% numeric .npy array (the sample numbers, states and words of Open Ephys); 1-D arrays as columns,
% n-D arrays with their shape (C or Fortran order)
[hdr, fid, cl] = openNpy(f); %#ok<ASGLU>
descr = regexp(hdr, '''descr'':\s*''([<>|=])([a-z])(\d+)''', 'tokens', 'once');
shape = regexp(hdr, '''shape'':\s*\(([^)]*)\)', 'tokens', 'once');
fortran = ~isempty(regexp(hdr, '''fortran_order'':\s*True', 'once'));
if isempty(descr) || isempty(shape); error('VS3_convertOpenEphys:npy', 'Unsupported .npy header in %s: %s', f, hdr); end
types = struct('i1', 'int8', 'i2', 'int16', 'i4', 'int32', 'i8', 'int64', 'u1', 'uint8', 'u2', 'uint16', ...
    'u4', 'uint32', 'u8', 'uint64', 'f4', 'single', 'f8', 'double', 'b1', 'uint8');
code = [descr{2}, descr{3}];
if ~isfield(types, code); error('VS3_convertOpenEphys:npy', 'Unsupported data type %s in %s.', [descr{:}], f); end
dims = str2double(regexp(shape{1}, '\d+', 'match'));
n = prod(dims);                          % prod([]) = 1: a scalar
x = fread(fid, n, ['*', types.(code)]);
if numel(x) ~= n; error('VS3_convertOpenEphys:npy', '%s is truncated.', f); end
if descr{1} == '>'; x = swapbytes(x); end
if strcmp(code, 'b1'); x = logical(x); end
if numel(dims) > 1
    if fortran
        x = reshape(x, dims);
    else
        x = permute(reshape(x, fliplr(dims)), numel(dims):-1:1);
    end
end
end

function txt = readNpyStrings(f)
% the text messages (numpy byte strings |S<n>)
[hdr, fid, cl] = openNpy(f); %#ok<ASGLU>
w = regexp(hdr, '''descr'':\s*''\|S(\d+)''', 'tokens', 'once');
n = regexp(hdr, '''shape'':\s*\((\d+),?\)', 'tokens', 'once');
if isempty(w) || isempty(n); error('VS3_convertOpenEphys:npy', 'Unsupported .npy header in %s', f); end
w = str2double(w{1}); n = str2double(n{1});
txt = cell(n, 1);
for k = 1:n
    b = fread(fid, w, 'uint8=>char')';
    txt{k} = strtrim(b(b ~= 0));
end
end

function d = startFolder(prefName)
d = VS3_pref('get', prefName, pwd);
if ~ischar(d) || ~isfolder(d); d = pwd; end
end

function step(w, f, txt)
if ~isempty(w) && isvalid(w)
    waitbar(min(max(f, 0), 1), w, txt);
    drawnow
end
end

function report(o, msg, kind)
if ~o.interactive
    fprintf('%s\n', msg);
    return
end
switch kind
    case 'error'; errordlg(msg, 'Open Ephys conversion');
    case 'warn';  warndlg(msg, 'Open Ephys conversion');
    otherwise;    msgbox(msg, 'Open Ephys conversion');
end
end
