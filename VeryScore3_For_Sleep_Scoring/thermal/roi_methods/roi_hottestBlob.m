function [value, extra] = roi_hottestBlob(frame, p)
% roi_hottestBlob  Segment the animal as the connected region of pixels above a threshold
% relative to the frame background, then report the mean of its N hottest pixels, the
% blob mean, its area and centroid. Needs Image Processing Toolbox (bwconncomp).
%
% Parameters: N (default 50), deltaT (default 3 degC above the background median),
%             minArea (default 30 px), smooth (default 3), excludeMask
% Outputs: value = [meanTopN_of_blob, blobMean, blobArea, centroidRow, centroidCol]
if ~isfield(p, 'N') || isempty(p.N), p.N = 50; end
if ~isfield(p, 'deltaT') || isempty(p.deltaT)
    p.deltaT = 3;                                   % kelvin
    if isfield(p, 'unit') && strcmpi(p.unit, 'counts'), p.deltaT = 3 * 40; end   % uncalibrated video: ~40 counts per K
end
if ~isfield(p, 'minArea') || isempty(p.minArea), p.minArea = 30; end
if ~isfield(p, 'smooth') || isempty(p.smooth), p.smooth = 3; end
if isfield(p, 'excludeMask') && ~isempty(p.excludeMask), frame(p.excludeMask) = NaN; end
bg = median(frame(:), 'omitnan');
fr2 = frame; fr2(isnan(fr2)) = bg;
fr2 = boxsmooth(fr2, p.smooth);
bw = fr2 > bg + p.deltaT;
cc = bwconncomp(bw, 8);
if cc.NumObjects == 0
    value = [NaN NaN 0 NaN NaN]; extra = struct('idx', []); return
end
% choose the component with the highest peak temperature among those big enough
best = 0; bestPk = -Inf;
for k = 1:cc.NumObjects
    idx = cc.PixelIdxList{k};
    if numel(idx) < p.minArea, continue; end
    pk = max(fr2(idx));
    if pk > bestPk, bestPk = pk; best = k; end
end
if best == 0
    value = [NaN NaN 0 NaN NaN]; extra = struct('idx', []); return
end
idx = cc.PixelIdxList{best};
v = frame(idx); v = v(~isnan(v));
vs = sort(v, 'descend');
[r, c] = ind2sub(size(frame), idx);
value = [mean(vs(1:min(p.N, numel(vs)))), mean(v), numel(idx), mean(r), mean(c)];
extra = struct('idx', idx);
end
