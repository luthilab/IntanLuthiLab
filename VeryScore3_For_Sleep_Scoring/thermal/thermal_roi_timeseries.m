function R = thermal_roi_timeseries(T, method, varargin)
% thermal_roi_timeseries  Per-frame ROI temperature from a ThermalH5 recording.
%
%   R = thermal_roi_timeseries(T, 'hottestN', 'N', 50)
%   R = thermal_roi_timeseries(T, 'hotspotWindow', 'N', 50, 'halfSize', 8)
%   R = thermal_roi_timeseries(T, 'fixedMask', 'mask', logical(H x W))
%   R = thermal_roi_timeseries(T, @myRoiFunction, 'param', value, ...)
%
% Inputs
%   T       ThermalH5 object (see ThermalH5.m) or path to the .h5 file
%   method  name of a function roi_<method>.m in matlab/roi_methods, or a function handle
%           with signature  [value, extra] = fn(frame, p)  where frame is [H x W] single
%           (degC, NaN = invalid pixel) and p the parameter struct. 'value' may be a row
%           vector (several outputs), 'extra' an optional struct (e.g. centroid).
%
% Name/value options (all optional)
%   'frames'     indices of frames to process (default: all)
%   'chunk'      frames read per HDF5 access (default 64)
%   'excludeMask' logical [H x W], true = pixel never used (e.g. water bottle, heat lamp)
%   'invalidToNaN' true (default): frames flagged invalid (shutter cycle) -> NaN
%   'verbose'    true (default)
%   'progress'   function handle fn(nDone, nTotal) called after every chunk (e.g. to update a waitbar);
%                an error thrown by it stops the analysis (used for Cancel buttons)
%   'parallel'   false (default) | true | 'auto': spread the frames over a process pool
%                (Parallel Computing Toolbox). 'auto' = only when a process pool is already
%                running or the video is long (>= 20000 frames, ~2.8 h at 2 Hz), as starting a
%                pool takes ~20 s. Same result as the serial run, frame for frame.
%   ... any other name/value pair is passed to the ROI method in the struct p
%
% Output R (struct)
%   .value    [nFrames x nOut] ROI temperature(s) per frame (NaN for invalid frames)
%   .time     seconds since recording start
%   .valid    logical, frame usable
%   .method   name, .params  struct used, .extra  struct array from the method (if any)
%   .unit     'degC' or 'counts'
%
% Adding your own ROI method: create matlab/roi_methods/roi_<name>.m following roi_hottestN.m.

if ischar(T) || isstring(T), T = ThermalH5(char(T)); end
p = struct('frames', 1:T.nFrames, 'chunk', 64, 'excludeMask', [], 'invalidToNaN', true, 'verbose', true, 'progress', [], ...
    'parallel', false);
extraArgs = {};
for k = 1:2:numel(varargin)
    name = varargin{k};
    if isfield(p, name), p.(name) = varargin{k + 1}; else, extraArgs(end + 1:end + 2) = varargin(k:k + 1); end %#ok<AGROW>
end
mp = struct();                       % parameters for the ROI method
for k = 1:2:numel(extraArgs), mp.(extraArgs{k}) = extraArgs{k + 1}; end
mp.excludeMask = p.excludeMask;
if ~isfield(mp, 'unit')                 % thresholds in kelvin need the unit of the frames
    mp.unit = 'counts';
    if T.hasCelsius, mp.unit = 'degC'; end
end

addpath(fullfile(fileparts(mfilename('fullpath')), 'roi_methods'));
if isa(method, 'function_handle')
    fn = method; mname = func2str(method);
else
    mname = char(method);
    fn = str2func(['roi_' mname]);
end

frames = p.frames(:)';
n = numel(frames);
if useParallel(p.parallel, n)
    try
        [value, extra] = runParallel(T, fn, mname, mp, frames, p);
    catch err
        if ~strcmp(err.identifier, 'thermal_roi_timeseries:poolStart'), rethrow(err); end
        warning('thermal_roi_timeseries:poolStart', '%s Running serially.', err.message);
        [value, extra] = roiFrames(T, fn, mname, mp, frames, p);
    end
else
    [value, extra] = roiFrames(T, fn, mname, mp, frames, p);
end

R = struct();
R.value = value;
R.time = T.time(frames);
R.valid = T.valid(frames);
R.frames = frames(:);
if p.invalidToNaN
    R.value(~R.valid, :) = NaN;
end
R.method = mname;
R.params = mp;
R.extra = extra;
R.unit = 'counts';
if T.hasCelsius, R.unit = 'degC'; end
R.source = T.path;
R.startTime = T.startTime;
end

function [value, extra] = roiFrames(T, fn, mname, mp, frames, p)
% the ROI method on every frame, read p.chunk frames at a time
n = numel(frames);
value = [];
extra = [];
t0 = tic;
for k0 = 1:p.chunk:n
    kk = k0:min(k0 + p.chunk - 1, n);
    X = T.readFrames(frames(kk));                     % [H x W x numel(kk)] single degC
    for j = 1:numel(kk)
        fr = X(:, :, j);
        [v, ex] = fn(fr, mp);
        if isempty(value)
            value = nan(n, numel(v), 'double');
        end
        value(kk(j), :) = v;
        if ~isempty(ex)
            if isempty(extra), extra = repmat(ex, n, 1); end
            extra(kk(j)) = ex;
        end
    end
    report(p, mname, kk(end), n, t0);
end
end

function report(p, mname, k, n, t0)
if p.verbose && (mod(k, p.chunk * 20) < p.chunk || k == n)
    el = toc(t0);
    fprintf('  ROI %s: %d / %d frames (%.0f s, ~%.0f s left)\n', mname, k, n, el, el / k * (n - k));
end
if ~isempty(p.progress)
    p.progress(k, n);
end
end

function tf = useParallel(opt, n)
if ischar(opt) || isstring(opt)
    if ~strcmpi(opt, 'auto'), error('thermal_roi_timeseries: ''parallel'' must be true, false or ''auto'''); end
    tf = canUsePool() && (isa(gcp('nocreate'), 'parallel.ProcessPool') || n >= 20000);
else
    tf = logical(opt) && canUsePool();
    if logical(opt) && ~tf
        warning('thermal_roi_timeseries:noParallel', 'Parallel Computing Toolbox not available: running serially.');
    end
end
end

function tf = canUsePool()
tf = false;
try %#ok<TRYNC>
    tf = canUseParallelPool() && ~isa(gcp('nocreate'), 'parallel.ThreadPool');   % thread workers cannot read HDF5
end
end

function [value, extra] = runParallel(T, fn, mname, mp, frames, p)
% blocks of frames on a process pool; each worker reads its frames from the .h5 itself
pool = gcp('nocreate');
if isempty(pool)
    if p.verbose, fprintf('  starting a parallel pool (about 20 s, only the first time)...\n'); end
    if ~isempty(p.progress), p.progress(0, numel(frames)); end
    try
        pool = parpool('Processes');
    catch err
        error('thermal_roi_timeseries:poolStart', 'The parallel pool could not start (%s).', err.message);
    end
end
n = numel(frames);
blk = min(2048, max(p.chunk, ceil(n / (4 * pool.NumWorkers))));
blk = ceil(blk / p.chunk) * p.chunk;
starts = 1:blk:n;
nb = numel(starts);
if exist(func2str(fn), 'file') == 2, fnArg = func2str(fn); else, fnArg = fn; end   % name: resolved on the worker
dirs = {fileparts(mfilename('fullpath')), fullfile(fileparts(mfilename('fullpath')), 'roi_methods')};
key = fileKey(T.path);   % the workers re-open the video when the file changed (calibration added, converted again)
for b = nb:-1:1
    kk = starts(b):min(starts(b) + blk - 1, n);
    F(b) = parfeval(pool, @roiBlock, 2, T.path, key, dirs, fnArg, mp, frames(kk), p.chunk);
end
vals = cell(nb, 1);
exs = cell(nb, 1);
done = 0;
t0 = tic;
try
    for i = 1:nb
        [b, v, ex] = fetchNext(F);   % (vals{b} as output would use the previous b)
        vals{b} = v;
        exs{b} = ex;
        done = done + size(v, 1);
        report(p, mname, done, n, t0);
    end
catch err
    cancel(F);
    if ~isempty(err.cause)
        err = err.cause{1};          % show the worker's own error, not "completed with an error"
    end
    rethrow(err)
end
value = vertcat(vals{:});
extra = [];
full = find(~cellfun(@isempty, exs), 1);
if ~isempty(full)
    for b = 1:nb
        if isempty(exs{b}), exs{b} = repmat(exs{full}(1), size(vals{b}, 1), 1); end
    end
    extra = vertcat(exs{:});
end
end

function [value, extra] = roiBlock(path, key, dirs, fn, mp, frames, chunk)
% runs on a pool worker; keeps the ThermalH5 object between blocks of the same, unchanged file
persistent T K
if exist('ThermalH5', 'class') ~= 8 || exist('boxsmooth', 'file') ~= 2, addpath(dirs{:}); end
if isempty(T) || ~isvalid(T) || ~strcmp(T.path, path) || ~isequal(K, key)
    T = ThermalH5(path);
    K = key;
end
if ischar(fn), fn = str2func(fn); end   % the function's own name (roi_<method> or a function of yours)
[value, extra] = roiFrames(T, fn, '', mp, frames, struct('chunk', chunk, 'verbose', false, 'progress', []));
end

function k = fileKey(path)
% modification time and size of the video file
d = dir(path);
k = [d.datenum, d.bytes];
end
