function [fig, S] = VS3_summary(varargin)
%VS3_SUMMARY Overview of a recording: hypnogram, EEG sigma activity, temperature, breathing, heart
%rate and photometry.
%
%   [fig, S] = VS3_summary('b', b, 'eeg', x, 'fs', 200, ...)      (Tools > Summary figure)
%
% Panels, on one time axis (hours since the first sample), zoomed together:
%   1. hypnogram (wake / NREM / REM; artifacts with their state, microarousals with wake)
%   2. sigma activity of the EEG: power in the sigma band (10-15 Hz) of every 4-s epoch, in % of its
%      mean over NREM epochs (of the median when no NREM is scored); NREM in green: 3-epoch moving
%      median (keeps the ~1-min infraslow fluctuations, damps single-epoch peaks) over the values of
%      every epoch (light); artifact epochs (1/2/3) left out
%   3. temperature of the thermal video, when given (one value per epoch, per frame in grey)
%   4. breathing rate, when given: of the Pi sensor (strongest peak in its respiration band in every
%      4-s epoch, in steps of 15 /min) and seen by Pi ROIs of the video (dots in the colour of the
%      state of the epoch: only sleep in the nest shows the breathing)
%   5. heart rate of the Pi sensor, when given (strongest peak in its heart band in every 4-s epoch;
%      in grey the epochs where it can be a harmonic of the breathing)
%   6. photometry dF/F, when given (20 Hz in grey, 10-s mean in colour; the start left out of the
%      baseline fit shaded)
% and, on the right: when the recording ran, a ring of the time spent in each state, the duration of the
% bouts of each state (box plots over every bout) and the states hour by hour.
%
% Options (name/value):
%   'b'           scoring, one letter per 4-s epoch (w n r, 1 2 3 artifacts, m microarousal, f, b unscored)
%   'eeg', 'fs'   EEG trace for the sigma activity and its sampling rate (default 200 Hz, as displayed)
%   'eegName'     name of that channel
%   'sigmaBand'   [10 15] Hz
%   'thermal'     struct Thermal of the file (VS3_thermalTool), or []
%   'photometry'  struct Photometry of the file (VS3_photometry), or []
%   'sensor'      struct of the Pi sensor (from VS3_sensorTool 'timeline'): epochs, breathing and heart
%                 (Hz, NaN = no value), harmonic (true: the heart peak can be a harmonic of the
%                 breathing), bands ([2 x 2] Hz); or []
%   'videoBreathing'  struct array, one per Pi ROI (VS3_videoPanel roiBreathing): roi (name), epochs,
%                 frequency (Hz); or []
%   'startTime'   time of the first sample (text or datetime), shown in the axis label ('' = unknown)
%   'title'       title of the figure (file name; '' in blind mode)
%   'navigate'    function handle fcn(epoch): a click in the figure calls it (VeryScore3 jumps there)
%   'file'        file proposed by Summary > Save as .fig and .png (default: summary.fig)
%   'saveAs'      save the summary right away as this .fig (and a .png next to it)
%   'visible'     'on' (default) | 'off'
%
%   VS3_summary('save', fig, file)   saves a summary figure as file.fig and file.png. The .fig opens in
%   MATLAB with its panels still zoomed together (openfig / double-click); clicking no longer navigates.
% S holds what is drawn: time (h) and state of every epoch, sigma (% and raw power), the temperature,
% breathing (per min), heart (per min) and photometry series, S.stats (minutes, %, bouts, bout
% durations per state) and S.perHour.
%
% Alejandro Osorio-Forero with Claude, 2026, for VeryScore3.

if nargin > 0 && ischar(varargin{1}) && strcmpi(varargin{1}, 'save')
    saveSummary(varargin{2:end});
    fig = []; S = [];
    return
end
o = struct('b', '', 'eeg', [], 'fs', 200, 'eegName', 'EEG', 'sigmaBand', [10 15], 'thermal', [], ...
    'photometry', [], 'sensor', [], 'videoBreathing', [], 'startTime', '', 'title', '', 'navigate', [], 'visible', 'on', ...
    'file', 'summary.fig', 'saveAs', '');
for k = 1:2:numel(varargin)
    if ~isfield(o, varargin{k}); error('VS3_summary:option', 'Unknown option ''%s''.', varargin{k}); end
    o.(varargin{k}) = varargin{k + 1};
end
b = char(o.b(:)');
nEp = numel(b);
if nEp == 0; error('VS3_summary:noScoring', 'No epochs to summarize.'); end
epLen = 4;                                            % s
tEp = ((1:nEp) - 0.5) * epLen / 3600;                 % epoch centres, hours

colW = [.8 .2 .2]; colN = [.4 .6 .2]; colR = [.8 .6 .2]; colPhot = [0 .45 .74]; colTherm = [.75 .15 .1];
colBreath = [.1 .45 .6]; colHeart = [.55 .2 .5];

% ---- states ----
state = zeros(1, nEp);                                % 3 wake, 2 NREM, 1 REM, 0 unscored / other
state(ismember(b, 'w1m')) = 3;
state(ismember(b, 'n2')) = 2;
state(ismember(b, 'r3')) = 1;
artifact = ismember(b, '123');
S = struct('time', tEp, 'state', state, 'b', b);
S.stats = stateStats(b, state, epLen);

% ---- sigma activity ----
S.sigma = [];
if ~isempty(o.eeg)
    [S.sigmaPower, S.sigma, S.sigmaRef] = sigmaActivity(o.eeg, o.fs, nEp, o.sigmaBand, state, artifact);
end

% ---- figure ----
hasT = isstruct(o.thermal) && isfield(o.thermal, 'valueEpoch') && ~isempty(o.thermal.valueEpoch);
hasP = isstruct(o.photometry) && isfield(o.photometry, 'dff') && isfield(o.photometry, 'time') && ~isempty(o.photometry.dff);
hasS = isstruct(o.sensor) && isfield(o.sensor, 'epochs') && ~isempty(o.sensor.epochs);
hasV = isstruct(o.videoBreathing) && ~isempty(o.videoBreathing) && isfield(o.videoBreathing, 'frequency');
panels = {'hypno'};
if ~isempty(S.sigma); panels{end + 1} = 'sigma'; end
if hasT; panels{end + 1} = 'thermal'; end
if hasS || hasV; panels{end + 1} = 'breathing'; end
if hasS; panels{end + 1} = 'heart'; end
if hasP; panels{end + 1} = 'photometry'; end
np = numel(panels);
ttl = 'Summary';
if ~isempty(o.title); ttl = ['Summary - ', o.title]; end
scr = get(groot, 'ScreenSize');
hFig = max(820, 180 + 170 * np);
if scr(4) > 400; hFig = min(hFig, scr(4) - 90); end   % (on the screen, also with many panels)
fig = figure('Name', ttl, 'NumberTitle', 'off', 'Color', 'w', 'Visible', o.visible, ...
    'Units', 'pixels', 'Position', [60 50 1720 hFig]);
left = 0.055; width = 0.60; top = 0.94; gap = 0.035;
h1 = 0.12;                                            % hypnogram height (normalized)
hRest = min(0.30, (top - 0.08 - h1 - gap * (np - 1)) / max(np - 1, 1));
if np <= 2; h1 = 0.22; end                            % few panels: not stretched over the whole height
used = h1 + (np - 1) * (hRest + gap);
ax = gobjects(1, np);
y = top - max(0, (top - 0.08 - used) / 2);            % the panels centred in the height
for i = 1:np
    hi = hRest; if i == 1; hi = h1; end
    y = y - hi;
    ax(i) = axes('Parent', fig, 'Position', [left, y, width, hi], 'TickDir', 'out', 'Box', 'off', 'FontSize', 9, ...
        'Tag', 'VS3summary');
    y = y - gap;
    hold(ax(i), 'on')
end
xEnd = nEp * epLen / 3600;

for i = 1:np
    a = ax(i);
    switch panels{i}
        case 'hypno'
            % thin grey stairs for the transitions, thick coloured segments for the states
            lv = state; lv(lv == 0) = NaN;
            xs = (0:nEp) * epLen / 3600;
            stairs(a, xs, [lv, lv(end)], 'Color', [.6 .6 .6], 'LineWidth', 0.5);
            levels = [3 2 1]; cols = {colW, colN, colR};
            for k = 1:3
                e = find(state == levels(k));
                if isempty(e); continue; end
                X = [(e - 1); e; nan(size(e))] * epLen / 3600;
                Y = repmat(levels(k), 3, numel(e)); Y(3, :) = NaN;
                line(a, X(:), Y(:), 'Color', cols{k}, 'LineWidth', 5);
            end
            m = find(b == 'm');
            if ~isempty(m)
                plot(a, tEp(m), 3.35 * ones(size(m)), 'v', 'MarkerSize', 3, 'Color', [.3 .3 .3], 'MarkerFaceColor', [.3 .3 .3]);
            end
            a.YLim = [0.5 3.6]; a.YTick = 1:3; a.YTickLabel = {'REM', 'NREM', 'Wake'};
            title(a, ttl, 'Interpreter', 'none', 'FontWeight', 'normal', 'FontSize', 10);
        case 'sigma'
            v = S.sigma;
            vs = movmedian(v, 3, 'omitnan');               % single-epoch peaks damped
            S.sigmaSmooth = vs;
            vn = v; vn(state ~= 2) = NaN;
            vsn = vs; vsn(state ~= 2) = NaN;
            plot(a, tEp, v, 'Color', [.85 .85 .85], 'LineWidth', 0.5);
            plot(a, tEp, vn, 'Color', 0.45 * colN + 0.55, 'LineWidth', 0.5);
            plot(a, tEp, vsn, 'Color', colN * 0.8, 'LineWidth', 0.9);
            ref = 'mean NREM';
            if ~any(state == 2 & ~artifact); ref = 'median'; end
            ylabel(a, sprintf('sigma %g-%g Hz\n%% of %s', o.sigmaBand, ref));
            a.YLim = robustLim(vsn(isfinite(vsn)), vs(isfinite(vs)), [0.5 99.5]);
            text(a, 1, 1.02, o.eegName, 'Units', 'normalized', 'HorizontalAlignment', 'right', ...
                'VerticalAlignment', 'bottom', 'FontSize', 8, 'Color', [.4 .4 .4], 'Interpreter', 'none');
        case 'thermal'
            A = o.thermal;
            if isfield(A, 't2Hz') && isfield(A, 'value2Hz') && ~isempty(A.t2Hz)
                plot(a, A.t2Hz(:)' / 3600, A.value2Hz(:)', 'Color', [.82 .82 .82], 'LineWidth', 0.5);
            end
            ve = nan(1, nEp); n = min(nEp, numel(A.valueEpoch)); ve(1:n) = A.valueEpoch(1:n);
            plot(a, tEp, ve, 'Color', colTherm, 'LineWidth', 0.8);
            unit = 'counts';
            if isfield(A, 'unit') && strcmpi(A.unit, 'degC'); unit = [char(176) 'C']; end
            meth = 'ROI'; if isfield(A, 'roiMethod'); meth = A.roiMethod; end
            ylabel(a, sprintf('temperature\n(%s)', unit));
            a.YLim = robustLim(ve(isfinite(ve)), ve(isfinite(ve)), [0.5 99.5]);
            text(a, 1, 1.02, sprintf('thermal video, %s', meth), 'Units', 'normalized', 'HorizontalAlignment', 'right', ...
                'VerticalAlignment', 'bottom', 'FontSize', 8, 'Color', [.4 .4 .4], 'Interpreter', 'none');
            S.thermal = struct('time', tEp, 'value', ve, 'unit', unit);
        case 'breathing'
            S.breathing = struct('time', tEp, 'sensor', [], 'video', struct('roi', {}, 'time', {}, 'value', {}));
            shown = gobjects(0); names = {}; main = []; every = [];
            if hasS
                v = perEpoch(o.sensor.breathing, o.sensor.epochs, nEp) * 60;
                shown(end + 1) = plot(a, tEp, v, '.-', 'Color', colBreath, 'LineWidth', 0.5, 'MarkerSize', 4); % (dots: an epoch between gaps)
                names{end + 1} = sprintf('Pi sensor (%g-%g Hz, every 4-s epoch)', o.sensor.bands(1, :));
                S.breathing.sensor = v;
                main = v(isfinite(v)); every = main;
            end
            if hasV
                marks = 'osd^v';
                stateCols = {colR, colN, colW};              % state 1 REM, 2 NREM, 3 wake
                for r = 1:numel(o.videoBreathing)
                    B = o.videoBreathing(r);
                    e = B.epochs(:)'; f = 60 * B.frequency(:)';
                    ok = isfinite(f) & e >= 1 & e <= nEp;
                    e = e(ok); f = f(ok);
                    mk = marks(1 + mod(r - 1, numel(marks)));
                    for lv = 0:3
                        sel = state(e) == lv;
                        if ~any(sel); continue; end
                        c = [.6 .6 .6]; if lv > 0; c = stateCols{lv}; end
                        plot(a, tEp(e(sel)), f(sel), mk, 'MarkerSize', 4.5, 'MarkerFaceColor', c, 'MarkerEdgeColor', 'w', 'LineWidth', 0.3);
                    end
                    shown(end + 1) = plot(a, NaN, NaN, mk, 'MarkerSize', 4, 'MarkerFaceColor', [.4 .4 .4], 'MarkerEdgeColor', 'none'); %#ok<AGROW>
                    names{end + 1} = sprintf('video ROI %s (colour of the state)', B.roi); %#ok<AGROW>
                    S.breathing.video(end + 1) = struct('roi', B.roi, 'time', tEp(e), 'value', f);
                    sleep = f(ismember(state(e), [1 2]));
                    main = [main, sleep(:)']; every = [every, f]; %#ok<AGROW>
                end
            end
            ylabel(a, sprintf('breathing\n(per min)'));
            if isempty(main); main = every; end
            if ~isempty(every); a.YLim = robustLim(main, every, [0.5 99.5]); end
            legend(a, shown, names, 'Location', 'northoutside', 'Orientation', 'horizontal', 'Box', 'off', ...
                'FontSize', 7, 'Interpreter', 'none', 'AutoUpdate', 'off');
        case 'heart'
            v = perEpoch(o.sensor.heart, o.sensor.epochs, nEp) * 60;
            harm = perEpoch(double(o.sensor.harmonic), o.sensor.epochs, nEp) == 1;
            vc = v; vc(harm) = NaN;                          % a harmonic of the breathing is no heart rate
            vh = v; vh(~harm) = NaN;
            plot(a, tEp, vh, '.', 'Color', [.75 .75 .75], 'MarkerSize', 4);
            plot(a, tEp, vc, '.-', 'Color', colHeart, 'LineWidth', 0.5, 'MarkerSize', 4);
            ylabel(a, sprintf('heart rate\n(per min)'));
            if any(isfinite(v)); a.YLim = robustLim(vc(isfinite(vc)), v(isfinite(v)), [0.5 99.5]); end
            text(a, 1, 1.02, sprintf(['Pi sensor, strongest peak %g-%g Hz in every 4-s epoch (not detected heartbeats); ', ...
                'grey: can be a harmonic of the breathing'], o.sensor.bands(2, :)), ...
                'Units', 'normalized', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom', 'FontSize', 8, ...
                'Color', [.4 .4 .4], 'Interpreter', 'none');
            S.heart = struct('time', tEp, 'sensor', v, 'harmonic', harm);
        case 'photometry'
            P = o.photometry;
            tp = double(P.time(:)') / 3600;
            d = double(P.dff(:)'); d(~isfinite(d)) = NaN;
            fsP = 1 / median(diff(double(P.time(:))));
            ds = movmean(d, max(1, round(10 * fsP)), 'omitnan');
            skip = 0;
            if isfield(P, 'params') && isfield(P.params, 'skipStart'); skip = P.params.skipStart / 3600; end
            fitted = tp > skip;
            yl = robustLim(ds(fitted & isfinite(ds)), d(fitted & isfinite(d)), [0.5 99.5]);
            if skip > 0
                patch(a, [0 skip skip 0], yl([1 1 2 2]), [.93 .93 .93], 'EdgeColor', 'none');
            end
            plot(a, tp, d, 'Color', [.82 .82 .82], 'LineWidth', 0.5);
            plot(a, tp, ds, 'Color', colPhot, 'LineWidth', 0.8);
            ylabel(a, sprintf('dF/F (%%)\n%s', methodLabel(P)));
            a.YLim = yl;
            ch = 'photometry'; if isfield(P, 'channel'); ch = ['photometry, ', P.channel]; end
            text(a, 1, 1.02, ch, 'Units', 'normalized', 'HorizontalAlignment', 'right', ...
                'VerticalAlignment', 'bottom', 'FontSize', 8, 'Color', [.4 .4 .4], 'Interpreter', 'none');
            S.photometry = struct('time', tp, 'dff', d, 'dff10s', ds);
    end
    a.XLim = [0 xEnd];
    if i < np; a.XTickLabel = []; end
end
xl = 'hours since the first sample';
st = startText(o.startTime);
if ~isempty(st); xl = sprintf('hours since %s', st); end
xlabel(ax(end), xl);
linkaxes(ax, 'x');
ax(1).XLim = [0 xEnd];

% ---- click to navigate in VeryScore3 ----
if ~isempty(o.navigate)
    for i = 1:np
        set(ax(i), 'ButtonDownFcn', @(src, ev) goTo(src, o.navigate, nEp, epLen));
        set(allchild(ax(i)), 'HitTest', 'off');
    end
end

% ---- right column: when, how much, how long, hour by hour; logo; saving ----
S.perHour = rightColumn(fig, S.stats, state, b, nEp, epLen, o.startTime, {colW, colN, colR});
setappdata(fig, 'VS3summaryFile', o.file);
mm = uimenu(fig, 'Text', 'Summary');
uimenu(mm, 'Text', 'Save as .fig and .png...', 'MenuSelectedFcn', 'VS3_summary(''save'', gcbf)');
if ~isempty(o.saveAs)
    saveSummary(fig, o.saveAs);
end
end

%% ======================================================================= saving
function saveSummary(fig, f)
% file.fig (MATLAB figure, panels zoomed together when it is opened again) and file.png
if nargin < 2 || isempty(f)
    d = getappdata(fig, 'VS3summaryFile');
    if isempty(d); d = 'summary.fig'; end
    [fn, p] = uiputfile({'*.fig', 'MATLAB figure (*.fig), saved with a .png'}, 'Save the summary', d);
    if isequal(fn, 0); return; end
    f = fullfile(p, fn);
end
[p, n] = fileparts(f);
if isempty(p); p = pwd; end
ax = findobj(fig, 'Type', 'axes', 'Tag', 'VS3summary');
bd = get(ax, {'ButtonDownFcn'});
cf = get(ax, {'CreateFcn'});
set(ax, 'ButtonDownFcn', '');   % the link to the VeryScore3 window cannot be saved
set(ax, 'CreateFcn', 'linkaxes(findobj(ancestor(gcbo, ''figure''), ''Type'', ''axes'', ''Tag'', ''VS3summary''), ''x'')');
fcf = fig.CreateFcn;
fig.CreateFcn = 'set(gcbo, ''Visible'', ''on'')';  % a summary made without window (scripts) still opens visible
try
    savefig(fig, fullfile(p, [n, '.fig']));
    exportgraphics(fig, fullfile(p, [n, '.png']), 'Resolution', 150);
catch err
    set(ax, {'ButtonDownFcn'}, bd); set(ax, {'CreateFcn'}, cf); fig.CreateFcn = fcf;
    rethrow(err)
end
set(ax, {'ButtonDownFcn'}, bd);
set(ax, {'CreateFcn'}, cf);
fig.CreateFcn = fcf;
fprintf('Summary saved: %s (.fig and .png)\n', fullfile(p, n));
end

%% ======================================================================= helpers
function [p, pct, ref] = sigmaActivity(x, fs, nEp, band, state, artifact)
% power in the band of every 4-s epoch (Welch, 2-s Hann windows, half overlap), in % of the NREM mean
L = 4 * fs;
n = min(nEp, floor(numel(x) / L));
X = reshape(double(x(1:n * L)), L, n);
X = X - mean(X, 1);
[pw, f] = pwelch(X, hann(2 * fs), fs, 2 * fs, fs);
inBand = f >= band(1) & f <= band(2);
p = nan(1, nEp);
p(1:n) = sum(pw(inBand, :), 1) * (f(2) - f(1));
p(artifact) = NaN;
use = state == 2 & isfinite(p);
if any(use); ref = mean(p(use)); else; ref = median(p(isfinite(p))); end
pct = 100 * p / ref;
end

function st = stateStats(b, state, epLen)
% minutes, % of the scored time, bouts and mean bout duration of each state
names = {'Wake', 'NREM', 'REM'}; lv = [3 2 1];
scored = state > 0;
st = struct('state', names, 'minutes', 0, 'percent', 0, 'bouts', 0, 'meanBout', NaN);
for k = 1:3
    is = state == lv(k);
    st(k).minutes = sum(is) * epLen / 60;
    st(k).percent = 100 * sum(is) / max(1, sum(scored));
    d = diff([0, is, 0]);
    starts = find(d == 1); ends = find(d == -1);
    st(k).bouts = numel(starts);
    st(k).boutDurations = (ends - starts)' * epLen;     % s, one per bout
    if ~isempty(starts); st(k).meanBout = mean(ends - starts) * epLen; end
end
st(1).microarousals = sum(b == 'm');
st(1).artifactEpochs = sum(ismember(b, '123'));
st(1).unscoredEpochs = sum(~scored);
end

function perHour = rightColumn(fig, st, state, b, nEp, epLen, startTime, cols)
% the right column of the summary: header (when), ring (how much), box plots (how long), bars (hour by hour)
colW = cols{1}; colN = cols{2}; colR = cols{3};
x0 = 0.695; w = 0.285;
t0 = parseStart(startTime);
durH = nEp * epLen / 3600;
scored = state > 0;

% ---- header: logo and when ----
VS3_logo('show', fig, 'icon', [x0, 0.855, 0.055, 0.115]);
ah = axes('Parent', fig, 'Position', [x0 + 0.062, 0.855, w - 0.062, 0.115], 'Visible', 'off', 'XLim', [0 1], 'YLim', [0 1]);
if isnat(t0)
    l1 = sprintf('%.2f h recording', durH);
else
    l1 = sprintf('%s  %s - %s', char(string(t0, 'yyyy-MM-dd')), char(string(t0, 'HH:mm')), ...
        char(string(t0 + seconds(nEp * epLen), 'HH:mm')));
end
sleepPct = 100 * sum(state == 2 | state == 1) / max(1, sum(scored));
l2 = sprintf('%.2f h, %d epochs, %.1f %% scored', durH, nEp, 100 * mean(scored));
l3 = sprintf('Sleep %.1f %% of the scored time', sleepPct);
extra = {};
if st(1).microarousals > 0; extra{end + 1} = sprintf('%d microarousals', st(1).microarousals); end
if st(1).artifactEpochs > 0; extra{end + 1} = sprintf('%d artifact epochs', st(1).artifactEpochs); end
if st(1).unscoredEpochs > 0; extra{end + 1} = sprintf('%d unscored', st(1).unscoredEpochs); end
text(ah, 0, 0.88, l1, 'FontSize', 11, 'FontWeight', 'bold', 'Color', [.15 .15 .25], 'VerticalAlignment', 'top', 'Interpreter', 'none');
text(ah, 0, 0.55, l2, 'FontSize', 9, 'Color', [.35 .35 .4], 'VerticalAlignment', 'top');
text(ah, 0, 0.30, strjoin([{l3}, extra], '  ·  '), 'FontSize', 9, 'Color', [.35 .35 .4], 'VerticalAlignment', 'top');

% ---- ring: share of the scored time in each state ----
ar = axes('Parent', fig, 'Position', [x0 + 0.02, 0.555, w - 0.04, 0.255]);
hold(ar, 'on'); axis(ar, 'equal', 'off');
fr = [st.percent] / 100;                   % wake, NREM, REM
names = {'Wake', 'NREM', 'REM'}; cc = {colW, colN, colR};
order = [2 3 1];                           % NREM, REM, wake clockwise from the top
th0 = pi / 2;
for k = order
    if fr(k) <= 0; continue; end
    th = linspace(th0, th0 - 2 * pi * fr(k), max(3, ceil(360 * fr(k))));
    patch(ar, [cos(th), 0.62 * cos(fliplr(th))], [sin(th), 0.62 * sin(fliplr(th))], cc{k}, 'EdgeColor', 'w', 'LineWidth', 1.5);
    mid = th0 - pi * fr(k);
    ha = 'left'; if cos(mid) < -0.15; ha = 'right'; elseif abs(cos(mid)) <= 0.15; ha = 'center'; end
    text(ar, 1.14 * cos(mid), 1.14 * sin(mid), sprintf('%s %.1f %%\n%.0f min, %d bouts', names{k}, 100 * fr(k), st(k).minutes, st(k).bouts), ...
        'HorizontalAlignment', ha, 'VerticalAlignment', 'middle', 'FontSize', 8.5, 'Color', 0.75 * cc{k}, 'FontWeight', 'bold');
    th0 = th0 - 2 * pi * fr(k);
end
text(ar, 0, 0.08, sprintf('%.0f %%', sleepPct), 'HorizontalAlignment', 'center', 'FontSize', 15, 'FontWeight', 'bold', 'Color', [.2 .2 .3]);
text(ar, 0, -0.2, 'asleep', 'HorizontalAlignment', 'center', 'FontSize', 9, 'Color', [.4 .4 .45]);
ar.XLim = [-1.9 1.9]; ar.YLim = [-1.15 1.15];

% ---- box plots: duration of every bout of each state ----
ab = axes('Parent', fig, 'Position', [x0 + 0.045, 0.315, w - 0.06, 0.185], 'TickDir', 'out', 'Box', 'off', 'FontSize', 8.5);
hold(ab, 'on');
allD = [];
for k = 1:3
    dk = st(k).boutDurations(:);
    if isempty(dk); continue; end
    allD = [allD; dk]; %#ok<AGROW>
    jit = (mod((1:numel(dk))' * 0.618034, 1) - 0.5) * 0.5;      % fixed jitter: the same figure every time
    scatter(ab, k + jit, dk, 10, cc{k}, 'filled', 'MarkerFaceAlpha', 0.35, 'MarkerEdgeColor', 'none');
    boxchart(ab, k * ones(size(dk)), dk, 'BoxFaceColor', cc{k}, 'BoxFaceAlpha', 0.2, 'WhiskerLineColor', 0.7 * cc{k}, ...
        'BoxEdgeColor', 0.7 * cc{k}, 'MarkerStyle', 'none', 'LineWidth', 1.2, 'BoxWidth', 0.55);
    plot(ab, k, mean(dk), '+', 'Color', [.1 .1 .1], 'MarkerSize', 8, 'LineWidth', 1.3);
end
ab.YScale = 'log';
ab.XLim = [0.4 3.6];
ab.XTick = 1:3;
ab.XTickLabel = arrayfun(@(k) sprintf('%s (%d)', names{k}, st(k).bouts), 1:3, 'UniformOutput', false);
if ~isempty(allD)
    tk = [4 10 30 60 120 300 600 1800 3600 7200 14400];
    lo = max(min(allD) * 0.8, 2); hi = max(allD) * 1.25;
    ab.YLim = [lo hi];
    tk = tk(tk >= lo & tk <= hi);
    ab.YTick = tk;
    ab.YTickLabel = arrayfun(@durLabel, tk, 'UniformOutput', false);
end
title(ab, 'Bout durations (box: quartiles, +: mean)', 'FontWeight', 'normal', 'FontSize', 9);

% ---- bars: states hour by hour (a last part shorter than 15 min is left out) ----
durS = nEp * epLen;
nH = floor(durS / 3600);
if durS - nH * 3600 >= 900 || nH == 0; nH = nH + 1; end
F = zeros(nH, 3);
for j = 1:nH
    idx = (floor((j - 1) * 3600 / epLen) + 1):min(nEp, floor(j * 3600 / epLen));
    for k = 1:3
        F(j, k) = 100 * mean(state(idx) == 4 - k);           % wake (3), NREM (2), REM (1)
    end
end
ax = axes('Parent', fig, 'Position', [x0 + 0.045, 0.075, w - 0.06, 0.17], 'TickDir', 'out', 'Box', 'off', 'FontSize', 8.5);
bh = bar(ax, 1:nH, F(:, [2 3 1]), 'stacked', 'BarWidth', 0.85, 'EdgeColor', 'none');   % NREM, REM, wake from the bottom
bh(1).FaceColor = colN; bh(2).FaceColor = colR; bh(3).FaceColor = colW;
ax.YLim = [0 100]; ax.XLim = [0.4 nH + 0.6];
ylabel(ax, '% of the hour');
step = max(1, ceil(nH / 9));
ax.XTick = 1:step:nH;
if isnat(t0)
    lab = arrayfun(@(j) sprintf('%d', j - 1), ax.XTick, 'UniformOutput', false);
    xlabel(ax, 'hours since the start');
else
    lab = arrayfun(@(j) char(string(t0 + hours(j - 1), 'HH:mm')), ax.XTick, 'UniformOutput', false);
end
ax.XTickLabel = lab;
title(ax, 'States per hour', 'FontWeight', 'normal', 'FontSize', 9);
perHour = struct('fraction', F, 'columns', {{'Wake', 'NREM', 'REM'}}, 'hourStart', (0:nH - 1));
end

function s = durLabel(x)
if x < 60
    s = sprintf('%g s', x);
elseif x < 3600
    s = sprintf('%g min', x / 60);
else
    s = sprintf('%g h', x / 3600);
end
end

function t = parseStart(t)
% datetime of the first sample, NaT when unknown
if isempty(t); t = NaT; return; end
if isdatetime(t); return; end
try
    t = datetime(char(t), 'InputFormat', 'yyyy-MM-dd HH:mm:ss.SSS');
catch
    try t = datetime(char(t)); catch; t = NaT; end
end
end

function yl = robustLim(main, all, pr)
% y limits from the percentiles of the main values (fallback: all values), with a margin
v = main;
if numel(v) < 10; v = all; end
if isempty(v); yl = [0 1]; return; end
yl = prctile(v, pr);
if ~(yl(2) > yl(1)); yl = [min(v) max(v)]; end
if ~(yl(2) > yl(1)); yl = yl(1) + [-1 1]; end
yl = yl + [-1 1] * 0.08 * diff(yl);
end

function s = startText(t)
s = '';
if isempty(t); return; end
try
    if ~isdatetime(t); t = datetime(char(t), 'InputFormat', 'yyyy-MM-dd HH:mm:ss.SSS'); end
    s = char(string(t, 'HH:mm:ss (yyyy-MM-dd)'));
catch
    s = char(string(t));
end
end

function s = methodLabel(P)
s = '';
if isfield(P, 'method')
    if strcmp(P.method, 'purple'); s = 'purple baseline'; else; s = 'exponential baseline'; end
end
end

function v = perEpoch(x, epochs, nEp)
% values x of the epochs given, on all the epochs of the recording (NaN elsewhere)
v = nan(1, nEp);
epochs = epochs(:)';
ok = epochs >= 1 & epochs <= nEp;
x = double(x(:)');
v(epochs(ok)) = x(ok);
end

function goTo(src, fcn, nEp, epLen)
x = src.CurrentPoint(1, 1);                           % hours
ep = min(max(floor(x * 3600 / epLen) + 1, 1), nEp);
try
    fcn(ep);
catch
end
end
