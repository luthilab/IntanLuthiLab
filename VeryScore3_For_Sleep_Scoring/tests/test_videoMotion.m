function tests = test_videoMotion
% TEST_VIDEOMOTION Pi offset and thermal -> Pi alignment from the movements of the animal (VS3_videoMotion).
%
% A synthetic animal rests 15 s, then walks 4 s to another place at least 50 pixels away, for 8 min. It is drawn in a thermal
% video (.h5, 160 x 120 pixels, 2 Hz, a warm spot) and in a Pi video (320 x 240, 10 frames/s, a dark
% spot on a texture). The Pi image is the thermal image turned by 180 degrees and scaled 2 times:
% Pi = [-2 0 321; 0 -2 241] * [x; y; 1]. Its timestamps file puts the first frame 2 s too late, so that
% the offset from the start times (8 s) is 2 s smaller than the true one (10 s): the Pi video shows
% every movement 2 s late.
%
%   results = runtests('tests/test_videoMotion.m')
tests = functiontests(localfunctions);
end

function setupOnce(t)
addpath(fileparts(fileparts(mfilename('fullpath'))));
d = tempname;
mkdir(d);
t.TestData.dir = d;
% path of the animal (thermal pixels) on a 0.1-s grid of EEG time, -15 to 310 s
rs = RandStream('mt19937ar', 'Seed', 3);
tau = (-15:0.1:490)';
p = zeros(numel(tau), 2);
pos = [80 60];
k = 1;
while k <= numel(tau)
    rest = min(numel(tau), k + 150);              % 15 s at rest
    p(k:rest, :) = repmat(pos, rest - k + 1, 1);
    k = rest + 1;
    if k > numel(tau); break; end
    target = pos;
    while norm(target - pos) < 50; target = [25 + 110*rand(rs), 20 + 80*rand(rs)]; end
    walk = min(numel(tau), k + 39);               % 4 s walking
    f = ((1:walk - k + 1)'/(walk - k + 1));
    p(k:walk, :) = pos + f*(target - pos);
    pos = target;
    k = walk + 1;
end
t.TestData.T = [-2 0 321; 0 -2 241; 0 0 1];
at = @(s) interp1(tau, p, s);

% thermal video: frame j at EEG time j/2 - 5
n = 960;
[X, Y] = ndgrid(1:160, 1:120);
fr = zeros(160, 120, n, 'uint16');
for j = 0:n-1
    q = at(j/2 - 5);
    fr(:, :, j+1) = uint16(1000 + 0.5*X + 300*exp(-((X - q(1)).^2 + (Y - q(2)).^2)/(2*4^2)));
end
h5 = fullfile(d, 'therm.h5');
h5create(h5, '/time_s', [n 1]); h5write(h5, '/time_s', (0:n-1)'/2);
h5create(h5, '/frame_valid', [n 1], 'Datatype', 'uint8'); h5write(h5, '/frame_valid', uint8(ones(n, 1)));
h5create(h5, '/frames', [160 120 n], 'Datatype', 'uint16'); h5write(h5, '/frames', fr);
for a = {'n_frames', n; 'width', 160; 'height', 120; 'fps', 2}'
    h5writeatt(h5, '/', a{1}, a{2});
end
t.TestData.h5 = h5;

% Pi video: frame k at EEG time k/10 - 10 (true offset 10 s)
pi = fullfile(d, 'cam.mp4');
w = VideoWriter(pi, 'MPEG-4');
w.FrameRate = 10;
w.Quality = 95;
open(w)
bg = conv2(rand(rs, 260, 340)*255, ones(9)/81, 'same');
bg = uint8(bg(11:250, 11:330));
[PX, PY] = meshgrid(1:320, 1:240);
for k = 0:4899
    q = t.TestData.T*[at(k/10 - 10), 1]';
    img = bg;
    img((PX - q(1)).^2 + (PY - q(2)).^2 < 9^2) = 20;   % the dark animal
    writeVideo(w, repmat(img, 1, 1, 3));
end
close(w)
f = fopen(fullfile(d, 'cam.timestamps.csv'), 'w');
fprintf(f, 'frame_index,video_pts_us,sensor_timestamp_ns,estimated_utc,interval_ms\n');
for k = 0:4899
    fprintf(f, '%d,%d,,2026-10-20T09:59:52.000000+00:00,100\n', k, round(k/10*1e6)); % 2 s too late
end
fclose(f);
t.TestData.pi = pi;
end

function teardownOnce(t)
rmdir(t.TestData.dir, 's');
end

function testPiLagIsFound(t)
[P, T] = videos(t);
W = VS3_videoMotion('warmSpot', T, 2);
[lag, R] = VS3_videoMotion('piLag', P, T, W);
verifyGreaterThanOrEqual(t, sum(R.used), 3);
verifyEqual(t, lag, 2, 'AbsTol', 0.5);
end

function testAlignmentFromTheMovement(t)
[P, T] = videos(t);
P.offset = 10;                                   % corrected
W = VS3_videoMotion('warmSpot', T, 2);
[Tm, R] = VS3_videoMotion('align', P, T, W);
verifyEqual(t, R.scale, 2, 'RelTol', 0.05);
verifyEqual(t, abs(R.rotation), 180, 'AbsTol', 5);
q = [20 20 1; 140 20 1; 80 100 1];
verifyLessThan(t, max(hypot(q*Tm(1, :)' - q*t.TestData.T(1, :)', q*Tm(2, :)' - q*t.TestData.T(2, :)')), 10);
verifyLessThan(t, R.rms, 8);
end

function testCancel(t)
[~, T] = videos(t);
verifyError(t, @() VS3_videoMotion('warmSpot', T, 2, @(~, ~) false), 'VS3_videoMotion:cancelled');
end

function [P, T] = videos(t)
P = VS3_video(t.TestData.pi);
T = VS3_video(t.TestData.h5);
P.offset = 8;                                    % from the (wrong) start time of the timestamps file
T.offset = 5;
t.addTeardown(@() delete(P));
t.addTeardown(@() delete(T));
end
