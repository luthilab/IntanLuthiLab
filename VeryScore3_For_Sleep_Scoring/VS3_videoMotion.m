function varargout = VS3_videoMotion(action, varargin)
%VS3_VIDEOMOTION The movements of the animal seen by both cameras: Pi offset and thermal -> Pi alignment.
%
% Behind Tools > Video > Estimate Pi offset from the movement and Align thermal on Pi from the
% movement. The animal is the warm spot of the thermal video; in the Pi video it is where the image
% changes when it moves. Comparing the two:
%   - when the animal starts moving after a rest, the Pi video and the thermal video must show it at
%     the same EEG time: the delay between them corrects the offset of the Pi video, the thermal video
%     being the reference (best with the recorder timing of the thermal camera);
%   - at moments when the animal moves, its places in the two videos are pairs of points: the place,
%     scale and rotation thermal pixel -> Pi pixel are fitted on them, robustly (RANSAC), without clicking.
%
%   W = VS3_videoMotion('warmSpot', thermal, step, progress)
%       warm spot (mean place of the 0.3 % warmest pixels) in every step-th frame of the thermal
%       video: W.frame (frame numbers), W.x, W.y (pixels of the thermal video, NaN = none)
%   [lag, R] = VS3_videoMotion('piLag', pi, thermal, W, progress)
%       how much later the Pi video shows the movements (s; add it to the offset of the Pi video), NaN
%       when fewer than 3 movement onsets give a clear answer that agrees; R.onsets (EEG times), R.lags,
%       R.r (correlation of each), R.used (the onsets kept: r > 0.5 and within 1 s of their median)
%   [T, R] = VS3_videoMotion('align', pi, thermal, W, progress)
%       3 x 3 transform (place, scale, rotation), [x y 1] of the thermal video -> Pi pixel;
%       R.thermalPoints, R.piPoints (the pairs that agree), R.nPairs, R.nAgree, R.rms (pixels of the
%       Pi camera), R.scale, R.rotation (degrees). Error when too few pairs agree.
%
% progress(f, txt) is called with the fraction done and returns false to cancel.
% The thresholds are relative to the size of the thermal image (checked on 382 x 288 pixels at 2 Hz).
% The videos are read on the EEG time base of their offsets / recorder timing (VS3_video).
%
% Alejandro Osorio-Forero with Claude, 2026; tried on the overnight recording of 28-29 October 2026,
% where the Pi video was 2 s late and the thermal camera saw the cage upside down at 1/3.6 the scale.

switch lower(action)
    case 'warmspot'; varargout{1} = warmSpot(varargin{:});
    case 'pilag';    [varargout{1:2}] = piLag(varargin{:});
    case 'align';    [varargout{1:2}] = alignVideos(varargin{:});
    otherwise
        error('VS3_videoMotion:action', 'Unknown action "%s".', action);
end
end

%% ======================================================================= warm spot of the thermal video
function W = warmSpot(T, step, progress)
if nargin < 3; progress = @(~, ~) true; end
idx = (1:step:T.nFrames)';
W = struct('frame', idx, 'x', nan(size(idx)), 'y', nan(size(idx)));
n = numel(idx);
for i = 1:n
    if rem(i, 200) == 1 && ~progress(i/n, sprintf('Finding the animal in the thermal video (%d/%d frames)', i, n))
        error('VS3_videoMotion:cancelled', 'Cancelled.');
    end
    f = double(T.frame(idx(i)));
    v = sort(f(isfinite(f)), 'descend');
    if numel(v) < 100; continue; end
    [r, c] = find(f >= v(ceil(0.003*numel(v))));
    if numel(r) > 5
        W.x(i) = mean(c);
        W.y(i) = mean(r);
    end
end
end

function [t, x, y] = spotTimes(T, W)
% EEG times of the warm spot (frames without a time or a spot left out)
e = T.eegTimes();
t = e(W.frame);
ok = isfinite(t) & isfinite(W.x);
t = t(ok); x = W.x(ok); y = W.y(ok);
[t, o] = sort(t);
x = x(o); y = y(o);
end

%% ======================================================================= delay of the Pi video
function [lag, R] = piLag(P, T, W, progress)
if nargin < 4; progress = @(~, ~) true; end
[t, x, y] = spotTimes(T, W);
if numel(t) < 100; error('VS3_videoMotion:data', 'The animal was not found in enough thermal frames.'); end
s = T.width/382;                               % thresholds made for 382-pixel wide thermal images
grid = (ceil(t(1)):0.5:floor(t(end)))';
v = [0; hypot(diff(interp1(t, x, grid)), diff(interp1(t, y, grid)))]; % pixels per 0.5 s
v = movmean(v, 3, 'omitnan');
still = movmax(v, [10 0]) < 3*s;               % 5 s at rest
cand = find(v > 5*s & [false; still(1:end-1)]); % then moving
on = [];                                       % one per 30 s at most
for i = cand(:)'
    if isempty(on) || i - on(end) > 60; on(end+1, 1) = i; end %#ok<AGROW>
end
pe = P.eegTimes();
cover = @(t0) any(pe >= t0 - 20 & pe < t0 - 19) && any(pe >= t0 + 19 & pe < t0 + 20);
on = on(arrayfun(@(i) cover(grid(i)), on));
if numel(on) > 12; on = on(round(linspace(1, numel(on), 12))); end
lags = (-10:0.5:10)';
R = struct('onsets', grid(on), 'lags', nan(numel(on), 1), 'r', nan(numel(on), 1), 'used', false(numel(on), 1));
for j = 1:numel(on)
    t0 = grid(on(j));
    tt = (t0 - 20:0.5:t0 + 20)';
    m = nan(size(tt));
    prev = [];
    for i = 1:numel(tt)
        if ~progress((j - 1 + i/numel(tt))/numel(on), sprintf('Movement onset %d of %d: reading the Pi video', j, numel(on)))
            error('VS3_videoMotion:cancelled', 'Cancelled.');
        end
        k = P.frameAt(tt(i));
        if isnan(k); prev = []; continue; end
        g = mean(double(P.frame(k)), 3);
        g = g(1:4:end, 1:4:end);
        if ~isempty(prev); m(i) = mean(abs(g(:) - prev(:))); end
        prev = g;
    end
    vt = interp1(grid, v, tt);
    c = nan(size(lags));
    for L = 1:numel(lags)
        sh = round(lags(L)/0.5);
        a = vt(max(1, 1 - sh):min(end, end - sh));
        b = m(max(1, 1 + sh):min(end, end + sh));
        good = isfinite(a) & isfinite(b);
        if sum(good) > 40 && std(a(good)) > 0 && std(b(good)) > 0
            q = corrcoef(a(good), b(good));
            c(L) = q(1, 2);
        end
    end
    [R.r(j), w] = max(c);
    R.lags(j) = lags(w);
end
% the clear onsets (r > 0.5) that agree within 1 s of their median; at least 3
R.used = R.r > 0.5;
lag = NaN;
if sum(R.used) >= 3
    R.used = R.used & abs(R.lags - median(R.lags(R.used))) <= 1;
    if sum(R.used) >= 3; lag = median(R.lags(R.used)); end
end
end

%% ======================================================================= thermal -> Pi transform
function [Tm, R] = alignVideos(P, T, W, progress)
if nargin < 4; progress = @(~, ~) true; end
[t, x, y] = spotTimes(T, W);
if numel(t) < 100; error('VS3_videoMotion:data', 'The animal was not found in enough thermal frames.'); end
sp = hypot(diff(x), diff(y))./diff(t);         % pixels of the thermal video per second
s = T.width/382;
moving = find(sp > 7.5*s & sp < 60*s & diff(t) < 3);
if numel(moving) < 20; error('VS3_videoMotion:data', 'The animal moved too little in the thermal video (%d moments).', numel(moving)); end
pick = moving(round(linspace(1, numel(moving), min(160, numel(moving)))));
pairs = nan(numel(pick), 5);   % thermal x y, Pi x y, strength
g = exp(-((-12:12)'.^2 + (-12:12).^2)/50);
g = g/sum(g(:));
for j = 1:numel(pick)
    if ~progress(j/numel(pick), sprintf('Moment %d of %d: the moving animal in the Pi video', j, numel(pick)))
        error('VS3_videoMotion:cancelled', 'Cancelled.');
    end
    i = pick(j);
    tm = (t(i) + t(i+1))/2;                    % the spot halfway, the Pi image change around it
    k1 = P.frameAt(tm - 0.25);
    k2 = P.frameAt(tm + 0.25);
    if isnan(k1) || isnan(k2) || k1 == k2; continue; end
    a = mean(double(P.frame(k1)), 3);
    b = mean(double(P.frame(k2)), 3);
    d = conv2(abs(a(1:4:end, 1:4:end) - b(1:4:end, 1:4:end)), g, 'same');
    [mx, w] = max(d(:));
    [yy, xx] = ind2sub(size(d), w);
    pairs(j, :) = [(x(i) + x(i+1))/2, (y(i) + y(i+1))/2, (xx - 0.5)*4, (yy - 0.5)*4, mx/max(median(d(:)), eps)];
end
pairs = pairs(all(isfinite(pairs), 2) & pairs(:, 5) > 4, :);
n = size(pairs, 1);
if n < 12; error('VS3_videoMotion:data', 'Only %d moments with a clear moving spot in the Pi video.', n); end
% RANSAC: the transform of 2 pairs that most pairs agree with (3 % of the Pi image width). Two cameras
% looking down at the cage differ by a place, a scale and a rotation only (similarity, 4 parameters):
% with noisy pairs a full affine transform would also fit a shear, and could even mirror
tol = 0.03*P.width;
rs = RandStream('mt19937ar', 'Seed', 1);
best = false(n, 1);
for it = 1:3000
    k = randperm(rs, n, 2);
    if norm(diff(pairs(k, 1:2))) < 1; continue; end
    Tk = similarity(pairs(k, 1:2), pairs(k, 3:4));
    q = [pairs(:, 1:2), ones(n, 1)]*Tk';
    in = hypot(q(:, 1) - pairs(:, 3), q(:, 2) - pairs(:, 4)) < tol;
    if sum(in) > sum(best); best = in; end
end
if sum(best) < 12
    error('VS3_videoMotion:fit', 'The moving spots of the two videos do not agree (%d of %d pairs). Correct the Pi offset first.', sum(best), n);
end
Tm = similarity(pairs(best, 1:2), pairs(best, 3:4));
q = [pairs(best, 1:2), ones(sum(best), 1)]*Tm';
res = hypot(q(:, 1) - pairs(best, 3), q(:, 2) - pairs(best, 4));
R = struct('thermalPoints', pairs(best, 1:2), 'piPoints', pairs(best, 3:4), 'nPairs', n, 'nAgree', sum(best), ...
    'rms', sqrt(mean(res.^2)), 'scale', sqrt(det(Tm(1:2, 1:2))), 'rotation', atan2d(Tm(2, 1), Tm(1, 1)));
end

function T = similarity(u, v)
% least-squares place, scale and rotation, u (thermal pixels) -> v (Pi pixels): x' = a x - b y + c,
% y' = b x + a y + d
n = size(u, 1);
A = [u(:, 1), -u(:, 2), ones(n, 1), zeros(n, 1); u(:, 2), u(:, 1), zeros(n, 1), ones(n, 1)];
p = A \ [v(:, 1); v(:, 2)];
T = [p(1) -p(2) p(3); p(2) p(1) p(4); 0 0 1];
end
