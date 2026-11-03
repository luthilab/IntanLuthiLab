function [value, extra] = roi_mouseBody(frame, p)
% roi_mouseBody  Segment the animal and measure the temperature of its whole body.
%
% Use this when you want the surface temperature of the animal as a whole. If the animal has a
% shaved patch, use roi_shavedPatch instead: bare skin carries about 2.5x more signal than the
% fur-covered average (wake is 0.83 K above NREM on bare skin, 0.32 K through fur; see README).
%
% Parameters (fields of p, all optional)
%   N            number of pixels for the "hottest N" column (default 50)
%   trim         percentile trimmed off each end for the trimmed mean (default 10 = mean of 10-90 %)
%   k            segmentation threshold in robust sigmas (default 10, see mouseMask)
%   minArea      smallest acceptable body in pixels (default 300)
%   smooth       box filter size used for the mask only (default 3)
%   excludeMask  logical [H x W], true = pixel never used
%
% Outputs
%   value = [trimMean, bodyMean, topN, p90, p50, bodyArea, centroidRow, centroidCol]
%     trimMean   body mean after trimming the coldest and warmest 'trim' % (the headline value:
%                the most movement-robust whole-body measure)
%     bodyMean   mean of every pixel of the body
%     topN       mean of the N hottest pixels of the body (the old hottest-N measure, but
%                guaranteed to be on the animal)
%     p90, p50   percentiles of the body temperature distribution
%     bodyArea   body size in pixels (posture proxy: curled when asleep, extended when active)
%     centroidRow/Col  position of the animal. As in every ROI method here the position is the last
%                two columns, which is what thermal_motion_censor uses.
%   extra = struct with the segmentation threshold and the bounding box
%
% The frame-to-frame step of any thermal ROI scales with how fast the animal moves (about 9 mK when
% still, several hundred mK when moving). Run thermal_motion_censor on the result.
%
% Alejo Osorio, 2026 (with Claude).

if ~isfield(p, 'N') || isempty(p.N), p.N = 50; end
if ~isfield(p, 'trim') || isempty(p.trim), p.trim = 10; end

[mask, info] = mouseMask(frame, p);
extra = struct('threshold', info.threshold, 'bbox', info.bbox);
if isempty(mask)
    value = [NaN NaN NaN NaN NaN 0 NaN NaN];
    return
end

b = frame(mask);
b = b(~isnan(b));
bs = sort(b, 'descend');
q = prctile(b, [p.trim, 50, 90, 100 - p.trim]);
inTrim = b >= q(1) & b <= q(4);

value = [mean(b(inTrim)), mean(b), mean(bs(1:min(p.N, numel(bs)))), q(3), q(2), ...
    numel(b), info.centroid(1), info.centroid(2)];
end
