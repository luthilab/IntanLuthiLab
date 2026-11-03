function [value, extra] = roi_hottestN(frame, p)
% roi_hottestN  Mean of the N hottest valid pixels of the frame (default N = 50).
%
% Parameters (fields of p, all optional)
%   N            number of pixels (default 50)
%   excludeMask  logical [H x W], true = ignore pixel
%   smooth       size of a moving-average box applied before ranking (default 0 = off);
%                e.g. 3 suppresses single hot/noisy pixels
%   minSeparation not used here (see roi_hotspotWindow)
%
% Outputs
%   value  = [meanTopN, maxTemp, centroidRow, centroidCol]
%   extra  = struct with the linear indices of the selected pixels
if ~isfield(p, 'N') || isempty(p.N), p.N = 50; end
if isfield(p, 'excludeMask') && ~isempty(p.excludeMask)
    frame(p.excludeMask) = NaN;
end
if isfield(p, 'smooth') && ~isempty(p.smooth) && p.smooth > 1
    nanmask = isnan(frame);
    frame = boxsmooth(frame, p.smooth);
    frame(nanmask) = NaN;
end
v = frame(:);
if nnz(~isnan(v)) < p.N
    value = [NaN NaN NaN NaN];
    extra = struct('idx', []);
    return
end
% maxk instead of a full sort (~15x faster). Pixels tied with the N-th value are taken in
% increasing index order, as the stable sort did, so the result is identical.
v(isnan(v)) = -Inf;
top = maxk(v, p.N);
above = find(v > top(end));
sel = [above; find(v == top(end), p.N - numel(above))];
[vs, order] = sort(v(sel), 'descend');
sel = sel(order);
[r, c] = ind2sub(size(frame), sel);
value = [mean(vs), vs(1), mean(r), mean(c)];
extra = struct('idx', sel);
end
