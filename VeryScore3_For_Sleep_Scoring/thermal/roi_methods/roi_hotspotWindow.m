function [value, extra] = roi_hotspotWindow(frame, p)
% roi_hotspotWindow  Locate the hottest spot (after smoothing) and average the N hottest
% pixels inside a square window around it. More robust to isolated hot pixels and to
% several separate warm objects than the plain hottest-N approach.
%
% Parameters: N (default 50), halfSize (default 10 px), smooth (default 3), excludeMask
% Outputs: value = [meanTopN_in_window, peakTemp, peakRow, peakCol]
if ~isfield(p, 'N') || isempty(p.N), p.N = 50; end
if ~isfield(p, 'halfSize') || isempty(p.halfSize), p.halfSize = 10; end
if ~isfield(p, 'smooth') || isempty(p.smooth), p.smooth = 3; end
if isfield(p, 'excludeMask') && ~isempty(p.excludeMask), frame(p.excludeMask) = NaN; end
sm = boxsmooth(frame, p.smooth);
sm(isnan(frame)) = -Inf;
[pk, imax] = max(sm(:));
[r0, c0] = ind2sub(size(frame), imax);
rr = max(1, r0 - p.halfSize):min(size(frame, 1), r0 + p.halfSize);
cc = max(1, c0 - p.halfSize):min(size(frame, 2), c0 + p.halfSize);
w = frame(rr, cc);
w = w(~isnan(w));
if numel(w) < p.N
    value = [NaN pk r0 c0]; extra = struct('window', [rr(1) rr(end) cc(1) cc(end)]); return
end
ws = sort(w, 'descend');
value = [mean(ws(1:p.N)), pk, r0, c0];
extra = struct('window', [rr(1) rr(end) cc(1) cc(end)]);
end
