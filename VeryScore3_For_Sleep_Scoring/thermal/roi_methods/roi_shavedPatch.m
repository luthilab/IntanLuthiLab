function [value, extra] = roi_shavedPatch(frame, p)
% roi_shavedPatch  Track the shaved skin patch of the animal and measure its temperature.
%
% Exposed skin has no fur insulation, so it sits several kelvin above the rest of the body and
% forms one compact blob that can be followed as the animal turns. On AH2 (shaved upper neck) the
% patch is about 186 px and 4.7 K above the body median, and it is found in 99.99 % of the 57 637
% frames of the 2026-10-01 recording.
%
% Why this one: measured against the scored hypnogram of that session, bare skin separates wake
% from NREM by 0.83 K while the fur-covered body mean manages only 0.32 K, at the same measurement
% noise (15-20 mK after motion censoring). It is also what the old hottest-N method was really
% measuring, since the hottest pixels land on the patch in 94.7 % of frames; tracking it explicitly
% adds robustness and a quality signal (patchArea) rather than sensitivity. See README.
%
% The patch is segmented inside the body as the largest connected region above half of the
% within-body contrast, median + (p99.5 - median)/2. That threshold is relative, so it follows the
% patch as the whole animal warms or cools, and it needs no absolute temperature.
%
% Parameters (fields of p, all optional)
%   N            number of hottest patch pixels averaged for the headline value (default 80)
%   contrast     fraction of the within-body contrast used as the patch threshold (default 0.5)
%   k            segmentation threshold of the body in robust sigmas (default 10, see mouseMask)
%   minArea      smallest acceptable body in pixels (default 300)
%   minPatch     below this many patch pixels the patch is treated as hidden (default 30)
%   smooth       box filter size used for the masks only (default 3)
%   excludeMask  logical [H x W], true = pixel never used
%
% Outputs
%   value = [patchCore, patchMean, patchArea, patchRow, patchCol, bodyArea, centroidRow, centroidCol]
%     patchCore  mean of the N hottest pixels of the patch (the headline value)
%     patchMean  mean of the whole patch
%     patchArea  patch size in pixels. A quality signal: it drops when the animal curls so that the
%                shaved skin is hidden (below ~60 px in 2 % of frames of the 2026-10-01 session).
%     patchRow/Col  position of the patch inside the frame
%     bodyArea   body size in pixels
%     centroidRow/Col  position of the animal, last two columns as in every ROI method here, which
%                is what thermal_motion_censor uses.
%   extra = struct with the body and patch thresholds and the bounding box
%
% When the patch is hidden (fewer than minPatch pixels) patchCore falls back to the N hottest
% pixels of the body, so the series has no gaps, and patchArea tells you it happened.
%
% Alejo Osorio, 2026 (with Claude).

if ~isfield(p, 'N') || isempty(p.N), p.N = 80; end
if ~isfield(p, 'contrast') || isempty(p.contrast), p.contrast = 0.5; end
if ~isfield(p, 'minPatch') || isempty(p.minPatch), p.minPatch = 30; end

[mask, info] = mouseMask(frame, p);
extra = struct('threshold', info.threshold, 'patchThreshold', NaN, 'bbox', info.bbox);
if isempty(mask)
    value = [NaN NaN 0 NaN NaN 0 NaN NaN];
    return
end

b = frame(mask);
b = b(~isnan(b));
bs = sort(b, 'descend');
med = median(b);
pThr = med + p.contrast * (prctile(b, 99.5) - med);
extra.patchThreshold = pThr;

pm = mask & frame >= pThr;
pm(isnan(frame)) = false;
pm = imopen(pm, ones(3));

patchCore = NaN; patchMean = NaN; patchArea = 0; pr = NaN; pc = NaN;
cc = bwconncomp(pm, 8);
if cc.NumObjects > 0
    n = cellfun(@numel, cc.PixelIdxList);
    [~, best] = max(n);
    idx = cc.PixelIdxList{best};
    pv = frame(idx);
    pv = pv(~isnan(pv));
    if numel(pv) >= p.minPatch
        pvs = sort(pv, 'descend');
        patchMean = mean(pv);
        patchArea = numel(pv);
        patchCore = mean(pvs(1:min(p.N, numel(pvs))));
        [r, c] = ind2sub(size(frame), idx);
        pr = mean(r); pc = mean(c);
    end
end
if isnan(patchCore)                       % patch hidden: fall back to the hottest pixels of the body
    patchCore = mean(bs(1:min(p.N, numel(bs))));
end

value = [patchCore, patchMean, patchArea, pr, pc, numel(b), info.centroid(1), info.centroid(2)];
end
