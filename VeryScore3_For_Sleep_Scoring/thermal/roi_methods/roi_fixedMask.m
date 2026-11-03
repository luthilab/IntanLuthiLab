function [value, extra] = roi_fixedMask(frame, p)
% roi_fixedMask  Statistics of a fixed region (logical mask or rectangle).
%
% Parameters
%   mask   logical [H x W]           - or -
%   rect   [row0 row1 col0 col1] (1-based, inclusive)
%   stat   'mean' (default) | 'max' | 'median' | 'topN' (with N)
% Outputs: value = [stat, mean, max, min] of the valid pixels inside the region
if isfield(p, 'mask') && ~isempty(p.mask)
    m = logical(p.mask);
elseif isfield(p, 'rect') && ~isempty(p.rect)
    m = false(size(frame));
    m(p.rect(1):p.rect(2), p.rect(3):p.rect(4)) = true;
else
    error('roi_fixedMask: give ''mask'' or ''rect''');
end
if isfield(p, 'excludeMask') && ~isempty(p.excludeMask), m = m & ~p.excludeMask; end
v = frame(m); v = v(~isnan(v));
if isempty(v), value = [NaN NaN NaN NaN]; extra = []; return; end
stat = 'mean'; if isfield(p, 'stat'), stat = p.stat; end
switch lower(stat)
    case 'mean',   s = mean(v);
    case 'max',    s = max(v);
    case 'median', s = median(v);
    case 'topn'
        N = 50; if isfield(p, 'N'), N = p.N; end
        vs = sort(v, 'descend'); s = mean(vs(1:min(N, numel(vs))));
    otherwise, error('unknown stat %s', stat);
end
value = [s, mean(v), max(v), min(v)];
extra = [];
end
