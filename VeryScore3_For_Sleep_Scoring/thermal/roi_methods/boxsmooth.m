function sm = boxsmooth(frame, k)
% boxsmooth  k x k moving-average of a frame with replicate padding (no border bias).
% NaN pixels are replaced by the frame minimum before smoothing.
if nargin < 2 || isempty(k) || k <= 1
    sm = frame;
    return
end
fr = frame;
mn = min(frame(:));
if isnan(mn), mn = 0; end
fr(isnan(fr)) = mn;
pad = floor(k / 2);
[h, w] = size(fr);
ri = [ones(1, pad) 1:h h * ones(1, pad)];
ci = [ones(1, pad) 1:w w * ones(1, pad)];
fp = fr(ri, ci);
sm = conv2(double(fp), ones(k) / k^2, 'valid');
sm = cast(sm(1:h, 1:w), 'like', frame);
end
