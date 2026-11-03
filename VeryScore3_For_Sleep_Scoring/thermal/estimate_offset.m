function [offsetEst, out] = estimate_offset(matFile, varargin)
% estimate_offset  Estimate the time offset between the thermal video and the EEG by
% cross-correlating a movement proxy from the thermal ROI (frame-to-frame displacement of
% the hot-spot centroid) with the wake epochs of the hypnogram b.
%
%   [offsetEst, out] = estimate_offset('AH2_eegBL1_260907_TEST_bt.mat')
%   ... options: 'varName' ('Thermal'), 'wakeChars' ('wm'), 'maxLag' (900 s), 'plot' (true),
%                'A' (Thermal struct instead of reading it from the file),
%                'b' (scoring string instead of reading it from the file)
%
% offsetEst has the same meaning as 'offset' in thermal_align_to_eeg: video time (seconds
% since the first frame) at which EEG sample 1 was acquired. The offset already stored in
% the Thermal variable is taken into account, so the result is absolute.
% out.lags / out.cc give the whole correlation curve; out.peakRatio (peak / 2nd highest
% local maximum) tells how unambiguous the estimate is.
p = struct('varName', 'Thermal', 'wakeChars', 'wm', 'maxLag', 900, 'plot', true, 'A', [], 'smoothSec', 8, 'b', '');
for k = 1:2:numel(varargin), p.(varargin{k}) = varargin{k + 1}; end
m = matfile(matFile);
if isempty(p.b), b = m.b; else, b = p.b; end
b = b(:)';
if isempty(p.A), A = m.(p.varName); else, A = p.A; end

tv = A.t2Hz + A.offset;                          % video time of every frame
ac = A.allColumns;
rc = [];                                         % rows of the hot-spot position (row, column) for each ROI method
if isfield(A, 'roiMethod')
    switch lower(A.roiMethod)
        case {'hottestn', 'hotspotwindow'}, rc = [3 4];
        case 'hottestblob', rc = [4 5];
        case {'shavedpatch', 'mousebody'}, rc = [7 8];   % position of the whole animal
    end
end
if ~isempty(rc) && size(ac, 1) >= max(rc)
    mov = [0 hypot(diff(ac(rc(1), :)), diff(ac(rc(2), :)))];   % centroid displacement in pixels
    proxy = 'hot-spot centroid displacement';
else
    mov = [0 abs(diff(A.value2Hz))];
    proxy = '|diff(ROI value)|';
end
mov(~A.valid2Hz) = NaN;
mov = log1p(mov);                                % tame heavy tails

% movement per second on the video axis
nS = floor(tv(end)) + 1;
idx = floor(tv) + 1;
ok = ~isnan(mov) & idx >= 1 & idx <= nS;
movS = accumarray(idx(ok)', mov(ok)', [nS 1], @mean, NaN)';
if p.smoothSec > 1
    movS = movmean(movS, p.smoothSec, 'omitnan');
end
% wake indicator per second on the EEG axis
wakeS = double(repelem(ismember(b, p.wakeChars), A.epochLength));
if p.smoothSec > 1, wakeS = movmean(wakeS, p.smoothSec); end
nE = numel(wakeS);

lags = -p.maxLag:p.maxLag;
cc = nan(size(lags));
for i = 1:numel(lags)
    L = lags(i);                                 % EEG second j corresponds to video second j + L
    kv = (1:nS);                                 % video seconds (1-based)
    ke = kv - L;                                 % EEG seconds (1-based)
    sel = ke >= 1 & ke <= nE;
    x = movS(kv(sel)); y = wakeS(ke(sel));
    good = ~isnan(x);
    if nnz(good) > 600
        c = corrcoef(x(good), y(good)); cc(i) = c(1, 2);
    end
end
[ccMax, iMax] = max(cc);
offsetEst = lags(iMax);
% second highest local maximum at least 60 s away from the peak
far = abs(lags - offsetEst) > 60;
cc2 = max(cc(far));
out = struct('lags', lags, 'cc', cc, 'ccMax', ccMax, 'peakRatio', ccMax / max(cc2, eps), 'proxy', proxy, ...
    'wakeChars', p.wakeChars, 'nFramesUsed', nnz(ok));
fprintf('estimate_offset: best offset %+d s (corr %.3f, 2nd best %.3f -> ratio %.2f), proxy = %s\n', ...
    offsetEst, ccMax, cc2, out.peakRatio, proxy);
if p.plot
    fig = figure('Color', 'w', 'Name', 'estimate_offset');
    subplot(2, 1, 1); plot(lags, cc, 'k'); hold on; plot(offsetEst, ccMax, 'ro'); grid on
    xlabel('offset (s): video time of EEG sample 1'); ylabel('corr(movement proxy, wake)');
    title(sprintf('best offset %+d s, corr %.3f', offsetEst, ccMax));
    subplot(2, 1, 2);
    tE = (0:nE - 1) / 3600; kv = 1:nS; ke = kv - offsetEst; sel = ke >= 1 & ke <= nE;
    plot(tE, wakeS * max(movS, [], 'omitnan'), 'Color', [1 0.6 0.6]); hold on
    plot((ke(sel) - 1) / 3600, movS(kv(sel)), 'k');
    xlabel('time since EEG start (h)'); ylabel('movement proxy'); legend({'wake (scaled)', proxy}); grid on
    out.fig = fig;
end
end
