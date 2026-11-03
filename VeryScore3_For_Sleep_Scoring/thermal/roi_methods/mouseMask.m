function [mask, info] = mouseMask(frame, p)
%mouseMask  Segment the animal in a thermal frame. Shared by roi_mouseBody and roi_shavedPatch.
%
% The animal is by far the warmest object in these recordings, so it is found by thresholding at
% median + k*sigma (sigma robust, from the median absolute deviation) and keeping the largest
% connected component. The threshold is relative to the frame, so it works in energy counts and in
% degC alike and needs no background model. On the 2026-10-01 recording this finds the animal in
% 100 % of 57 637 frames, on the 2026-09-07 one in 99.5 % (the misses are shutter frames).
%
% Parameters (fields of p, all optional)
%   k            threshold in robust sigmas above the frame median (default 10)
%   minArea      smallest acceptable blob in pixels (default 300)
%   excludeMask  logical [H x W], true = pixel never used
%   smooth       box filter size used for the mask only (default 3, 0 = off); the measurements are
%                always taken on the unsmoothed frame
%
% Outputs
%   mask  logical [H x W], empty when nothing plausible was found
%   info  struct with threshold, area, centroid [row col] and the bounding box
%
% Alejo Osorio, 2026 (with Claude).

if ~isfield(p, 'k') || isempty(p.k), p.k = 10; end
if ~isfield(p, 'minArea') || isempty(p.minArea), p.minArea = 300; end
if ~isfield(p, 'smooth') || isempty(p.smooth), p.smooth = 3; end

mask = [];
info = struct('threshold', NaN, 'area', 0, 'centroid', [NaN NaN], 'bbox', [NaN NaN NaN NaN]);

if isfield(p, 'excludeMask') && ~isempty(p.excludeMask)
    frame(p.excludeMask) = NaN;
end
v = frame(~isnan(frame));
if numel(v) < 100, return; end
med = median(v);
sig = 1.4826 * median(abs(v - med));
if sig <= 0, return; end
info.threshold = med + p.k * sig;

det = frame;
if p.smooth > 1
    det = boxsmooth(frame, p.smooth);
    det(isnan(frame)) = NaN;
end
bw = det > info.threshold;
bw(isnan(det)) = false;
bw = imopen(bw, ones(3));
bw = imclose(bw, ones(5));
bw = imfill(bw, 'holes');

cc = bwconncomp(bw, 8);
if cc.NumObjects == 0, return; end
n = cellfun(@numel, cc.PixelIdxList);
[area, best] = max(n);
if area < p.minArea, return; end

idx = cc.PixelIdxList{best};
if nnz(~isnan(frame(idx))) < p.minArea, return; end
mask = false(size(frame));
mask(idx) = true;
[r, c] = ind2sub(size(frame), idx);
info.area = numel(idx);
info.centroid = [mean(r) mean(c)];
info.bbox = [min(r) max(r) min(c) max(c)];
end
