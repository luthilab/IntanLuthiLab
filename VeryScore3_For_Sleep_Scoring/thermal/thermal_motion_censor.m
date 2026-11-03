function Rc = thermal_motion_censor(R, varargin)
% thermal_motion_censor  Remove the frames in which the animal moved from a thermal ROI series.
%
%   Rc = thermal_motion_censor(R)                        R from thermal_roi_timeseries(..., 'mouseBody')
%   Rc = thermal_motion_censor(R, 'speedThr', 0.5)       px per frame (default 0.5)
%   Rc = thermal_motion_censor(R, 'fill', 'interp')      'interp' (default) | 'nan' | 'hold'
%
% Why: in these recordings the apparent surface temperature does not jump because the ROI is badly
% placed, it jumps because the animal moves and the camera then sees different fur, limbs and tail.
% Measured on 30 min of the 2026-10-01 recording, the median frame-to-frame step of the hottest-50
% signal is 9 mK while the animal is still and about 900 mK while it moves fast. Dropping the moving
% frames removes 95 % of the jumps whatever ROI is used, which no change of ROI shape achieves.
%
% R must contain the centroid of the animal. roi_mouseBody puts it in columns 7 and 8 of R.value;
% pass 'centroidCols' to point at other columns.
%
% OPTIONS
%   'speedThr'     px per frame above which a frame is censored (default 0.5)
%   'grow'         also censor this many frames on each side of a moving frame (default 2 = 1 s at 2 Hz)
%   'centroidCols' [row col] columns of R.value holding the position (default: the last two, which
%                  is where every ROI method in thermal\roi_methods puts it)
%   'areaCol'      column holding the segmented area ([] = none; default: the column before the
%                  position for roi_mouseBody and roi_shavedPatch, which both put the body area
%                  there). Frames whose area jumps by more than 'areaThr' are censored too, which
%                  catches a posture change without displacement.
%   'areaThr'      relative area change per frame (default 0.15 = 15 %)
%   'fill'         'interp' linear interpolation over censored frames (default)
%                  'nan'    leave them NaN
%                  'hold'   previous valid value
%   'keepCols'     columns left exactly as measured, never filled (default: the geometry of the ROI
%                  method, that is position and area: 3:end for shavedPatch and hottestBlob,
%                  end-2:end for mouseBody, the position for the others). Filling them would erase
%                  the movement record that estimate_offset needs for the video/EEG offset check.
%   'verbose'      true (default)
%
% OUTPUT Rc: a copy of R with
%   .value        censored (and filled) temperatures
%   .valueRaw     the original values
%   .censored     logical, true = frame was censored
%   .speed        px per frame
%   .censorParams the options used
%
% Alejo Osorio, 2026 (with Claude).

p = struct('speedThr', 0.5, 'grow', 2, 'centroidCols', [], 'areaCol', [], 'areaThr', 0.15, ...
    'fill', 'interp', 'keepCols', [], 'verbose', true);
for k = 1:2:numel(varargin), p.(varargin{k}) = varargin{k + 1}; end

V = R.value;
nc = size(V, 2);
if isempty(p.centroidCols)
    p.centroidCols = [nc - 1, nc];               % every roi_* method puts the position last
end
if isempty(p.keepCols)
    % Geometry columns (position, area) are left untouched: they are not temperatures, and
    % interpolating them would erase the very movement that this function detects. estimate_offset
    % reads the position back out of Thermal.allColumns to check the video/EEG offset, and that
    % check fails completely when the position has been smoothed over the moving frames.
    switch lower(string(R.method))
        case {"shavedpatch", "hottestblob"}, p.keepCols = 3:nc;
        case "mousebody",                    p.keepCols = (nc - 2):nc;
        otherwise,                           p.keepCols = p.centroidCols;
    end
end
p.keepCols = intersect(p.keepCols, 1:nc);
if isempty(p.areaCol) && ismember(lower(string(R.method)), ["mousebody", "shavedpatch"])
    p.areaCol = nc - 2;                          % these two put the body area before the position
end
if nc < 3 || max(p.centroidCols) > nc || min(p.centroidCols) < 1
    error('thermal_motion_censor:cols', ...
        ['R.value has %d columns, so the position cannot be read from columns %s. Use an ROI ' ...
         'method that returns a position (mouseBody, shavedPatch, hottestN, hotspotWindow, ' ...
         'hottestBlob) or pass ''centroidCols''.'], nc, mat2str(p.centroidCols));
end
cy = V(:, p.centroidCols(1));
cx = V(:, p.centroidCols(2));
n = numel(cy);

speed = [0; hypot(diff(cy), diff(cx))];
speed(~isfinite(speed)) = Inf;                 % frames without a segmentation count as moving

bad = speed > p.speedThr;
if ~isempty(p.areaCol) && size(V, 2) >= p.areaCol
    a = V(:, p.areaCol);
    da = [0; abs(diff(a))] ./ max(median(a, 'omitnan'), eps);
    bad = bad | da > p.areaThr;
end
bad = bad | any(~isfinite(V(:, setdiff(1:size(V, 2), p.centroidCols))), 2);
if p.grow > 0
    bad = movmax(double(bad), 2 * p.grow + 1) > 0;
end

Vc = V;
fillCols = setdiff(1:nc, p.keepCols);            % the temperature columns; geometry stays raw
switch lower(p.fill)
    case 'nan'
        Vc(bad, fillCols) = NaN;
    case {'interp', 'hold'}
        for c = fillCols
            x = V(:, c);
            x(bad) = NaN;
            good = isfinite(x);
            if nnz(good) < 2, Vc(:, c) = x; continue; end
            if strcmpi(p.fill, 'interp')
                x = interp1(find(good), x(good), (1:n)', 'linear');
                x(1:find(good, 1) - 1) = x(find(good, 1));
                x(find(good, 1, 'last') + 1:end) = x(find(good, 1, 'last'));
            else
                idx = cummax((1:n)' .* good);
                idx(idx == 0) = find(good, 1);
                x = x(idx);
            end
            Vc(:, c) = x;
        end
    otherwise
        error('thermal_motion_censor:fill', 'unknown fill ''%s''', p.fill);
end

Rc = R;
Rc.valueRaw = V;
Rc.value = Vc;
Rc.censored = bad;
Rc.speed = speed;
Rc.censorParams = p;

if p.verbose
    fprintf('thermal_motion_censor: %d / %d frames censored (%.1f %%), speed > %g px/frame, fill ''%s''\n', ...
        nnz(bad), n, 100 * mean(bad), p.speedThr, p.fill);
    c1 = 1;
    d0 = abs(diff(V(:, c1))); d1 = abs(diff(Vc(:, c1)));
    fprintf('   column %d: frame-to-frame step p99 %.1f -> %.1f (counts or degC), steps > 20 units: %d -> %d\n', ...
        c1, prctile(d0, 99), prctile(d1, 99), nnz(d0 > 20), nnz(d1 > 20));
end
end
