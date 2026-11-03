function A = thermal_align_to_eeg(R, matFile, varargin)
% thermal_align_to_eeg  Put a thermal ROI time series on the time base of the EEG .mat
% file (sample rate Infos.Fs and hypnogram epochs b) and optionally save it there.
%
%   A = thermal_align_to_eeg(R, 'AH2_eegBL1_260907_TEST_bt.mat')                % offset 0
%   A = thermal_align_to_eeg(R, matFile, 'offset', 12.5)                        % EEG started 12.5 s after the video
%   A = thermal_align_to_eeg(R, matFile, 'eegStart', datetime(2026,9,7,12,44,0)) % absolute EEG start time
%   A = thermal_align_to_eeg(R, matFile, 'save', true, 'varName', 'Thermal')
%
% R is the output of thermal_roi_timeseries (uses R.value(:, column)).
%
% Time convention:  t_eeg = t_thermal - offset,  i.e. 'offset' is the thermal time (seconds
% since the first video frame) at which EEG sample 1 was acquired. offset > 0 when the EEG
% started later than the video. Alternatively give 'eegStart' as a datetime and the offset
% is computed from the video start time stored in the recording (R.startTime).
%
% Options
%   'offset'       seconds (default 0)
%   'eegStart'     datetime of EEG sample 1 (overrides offset)
%   'column'       column of R.value to use (default 1)
%   'epochLength'  hypnogram epoch length in s (default 4)
%   'method'       'linear' (default) | 'previous' (zero-order hold) | 'nearest' for the Fs series
%   'epochStat'    'mean' (default) | 'median' | 'max' for the per-epoch value
%   'maxGap'       do not interpolate across gaps (invalid frames) longer than this, s (default 5)
%   'save'         false (default) | true -> append variable to the .mat (v7.3)
%   'varName'      name of the saved variable (default 'Thermal')
%   'Fs','nSamples','nEpochs'  override values read from the .mat
%
% Output A (struct, also what gets saved)
%   .t2Hz        thermal sample times in EEG seconds (frame times - offset)
%   .value2Hz    ROI value per frame (NaN = invalid)
%   .valid2Hz    logical
%   .valueFs     [1 x nSamples] single, value for every EEG sample (NaN outside the video)
%   .tFs         not stored (use (0:nSamples-1)/Fs)
%   .valueEpoch  [1 x nEpochs] value per hypnogram epoch
%   .nFramesEpoch number of valid frames that contributed to each epoch
%   .offset, .Fs, .epochLength, .unit, .roiMethod, .roiParams, .source, .videoStart, .eegStart

p = struct('offset', 0, 'eegStart', [], 'column', 1, 'epochLength', 4, 'method', 'linear', ...
    'epochStat', 'mean', 'maxGap', 5, 'save', false, 'varName', 'Thermal', 'Fs', [], 'nSamples', [], 'nEpochs', []);
for k = 1:2:numel(varargin), p.(varargin{k}) = varargin{k + 1}; end

% ---- EEG file information (without loading the traces) --------------------------------
m = matfile(matFile);
w = whos(m);
names = {w.name};
if isempty(p.Fs)
    if any(strcmp(names, 'Infos')), inf_ = m.Infos; p.Fs = inf_.Fs; else, error('Fs not found in %s; pass ''Fs''', matFile); end
end
if isempty(p.nSamples)
    if any(strcmp(names, 'traces'))
        sz = w(strcmp(names, 'traces')).size; p.nSamples = max(sz);
    else
        error('traces not found in %s; pass ''nSamples''', matFile);
    end
end
if isempty(p.nEpochs)
    if any(strcmp(names, 'b')), sz = w(strcmp(names, 'b')).size; p.nEpochs = max(sz); else, p.nEpochs = ceil(p.nSamples / p.Fs / p.epochLength); end
end

% ---- offset ---------------------------------------------------------------------------
if ~isempty(p.eegStart)
    if isempty(R.startTime) || isnat(R.startTime)
        error('video start time unknown, cannot use ''eegStart''');
    end
    p.offset = seconds(p.eegStart - R.startTime);
end

t = R.time(:) - p.offset;                 % thermal frame times in EEG seconds
v = double(R.value(:, p.column));
ok = ~isnan(v) & R.valid(:);

% ---- per EEG sample ----------------------------------------------------------------
tFs = (0:p.nSamples - 1)' / p.Fs;
valueFs = nan(p.nSamples, 1);
if nnz(ok) >= 2
    tt = t(ok); vv = v(ok);
    valueFs = interp1(tt, vv, tFs, p.method);
    % blank interpolation across long gaps
    gaps = find(diff(tt) > p.maxGap);
    for g = gaps'
        valueFs(tFs > tt(g) & tFs < tt(g + 1)) = NaN;
    end
    valueFs(tFs < tt(1) | tFs > tt(end)) = NaN;
end

% ---- per hypnogram epoch ---------------------------------------------------------------
ep = floor(t / p.epochLength) + 1;        % epoch index of every frame
valueEpoch = nan(p.nEpochs, 1);
nFramesEpoch = zeros(p.nEpochs, 1);
inrange = ok & ep >= 1 & ep <= p.nEpochs;
switch lower(p.epochStat)
    case 'mean',   f = @mean;
    case 'median', f = @median;
    case 'max',    f = @max;
    otherwise, error('unknown epochStat %s', p.epochStat);
end
if any(inrange)
    valueEpoch(1:max(ep(inrange))) = accumarray(ep(inrange), v(inrange), [max(ep(inrange)) 1], f, NaN);
    nFramesEpoch(1:max(ep(inrange))) = accumarray(ep(inrange), 1, [max(ep(inrange)) 1]);
end

A = struct();
A.t2Hz = t';
A.value2Hz = v';
A.valid2Hz = ok';
A.valueFs = single(valueFs');
A.valueEpoch = valueEpoch';
A.nFramesEpoch = nFramesEpoch';
A.offset = p.offset;
A.Fs = p.Fs;
A.epochLength = p.epochLength;
A.nSamples = p.nSamples;
A.nEpochs = p.nEpochs;
A.unit = R.unit;
A.roiMethod = R.method;
A.roiParams = R.params;
A.roiColumn = p.column;
A.allColumns = R.value';          % every output of the ROI method (rows) per frame
A.source = R.source;
A.videoStart = R.startTime;
if ~isempty(p.eegStart), A.eegStart = p.eegStart; elseif ~isnat(R.startTime), A.eegStart = R.startTime + seconds(p.offset); else, A.eegStart = NaT; end
A.created = datetime('now');

fprintf('thermal_align_to_eeg: offset %.3f s, %d/%d valid frames, EEG coverage %.1f%% of %d samples, %d/%d epochs with data\n', ...
    p.offset, nnz(ok), numel(ok), 100 * mean(~isnan(valueFs)), p.nSamples, nnz(~isnan(valueEpoch)), p.nEpochs);

if p.save
    S = struct(); S.(p.varName) = A; %#ok<STRNU>
    save(matFile, '-struct', 'S', '-append');
    fprintf('saved variable ''%s'' into %s\n', p.varName, matFile);
end
end
