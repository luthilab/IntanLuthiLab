function F = videoFixtures(d)
% VIDEOFIXTURES Synthetic recordings for tests/test_video.m in folder d (see its header):
% F.eeg, F.pi (with cam.timestamps.csv), F.h5, F.ravi.
F = struct();
t0 = datetime(2026, 10, 20, 10, 0, 0, 'TimeZone', 'UTC');

% EEG: 2 channels, 60 s at 200 Hz
traces = 1e-4*randn(2, 200*60);
Infos = struct('Fs', 200, 'Channel', 'EEG, EMG', 'StartTimePosix', posixtime(t0), 'TimeZone', 'Europe/Amsterdam', ...
    'StartTime', char(string(datetime(t0, 'TimeZone', 'Europe/Amsterdam'), 'yyyy-MM-dd HH:mm:ss.SSS')));
F.eeg = fullfile(d, 'rec_t.mat');
save(F.eeg, 'traces', 'Infos', '-v7.3');

% Pi camera: 900 frames, started 10 s before the EEG
F.pi = fullfile(d, 'cam.mp4');
w = VideoWriter(F.pi, 'MPEG-4');
w.FrameRate = 30;
w.Quality = 95;
open(w)
[X, Y] = meshgrid(1:320, 1:240);
checker = uint8(255*(mod(floor(X/4) + floor(Y/4), 2)));
for k = 0:899
    img = repmat(uint8(piLevel(k + 1)), 240, 320);
    x = 150 + round(5*sin(2*pi*0.5*k/30));
    img(100:139, x:x+39) = checker(1:40, 1:40);
    writeVideo(w, repmat(img, 1, 1, 3));
end
close(w)
f = fopen(fullfile(d, 'cam.timestamps.csv'), 'w');
fprintf(f, 'frame_index,video_pts_us,sensor_timestamp_ns,estimated_utc,interval_ms\n');
for k = 0:899
    fprintf(f, '%d,%d,,%s,33.3\n', k, round(k/30*1e6), '2026-10-20T09:59:50.000000+00:00');
end
fclose(f);

% thermal .h5: 120 frames at 2 Hz, started 5 s before the EEG (clock of the PC, Amsterdam)
F.h5 = fullfile(d, 'therm.h5');
n = 120;
h5create(F.h5, '/time_s', [n 1]);
h5write(F.h5, '/time_s', (0:n-1)'/2);
h5create(F.h5, '/frame_valid', [n 1], 'Datatype', 'uint8');
h5write(F.h5, '/frame_valid', uint8(ones(n, 1)));
fr = zeros(64, 48, n, 'uint16');
[X, Y] = ndgrid(1:64, 1:48);
blob = uint16(300*exp(-((X - 32).^2 + (Y - 30).^2)/60)); % a warm animal
for k = 1:n; fr(:, :, k) = 1000 + k + blob; end
h5create(F.h5, '/frames', [64 48 n], 'Datatype', 'uint16');
h5write(F.h5, '/frames', fr);
for a = {'n_frames', n; 'width', 64; 'height', 48; 'fps', 2; 'start_time', '2026-10-20T11:59:55.000'}'
    h5writeatt(F.h5, '/', a{1}, a{2});
end

% thermal .ravi: 20 frames, camera at 26 Hz, one frame in 13 saved (one more skipped after frame 15),
% frame 5 during a shutter cycle
F.ravi = fullfile(d, 'therm.ravi');
writeRavi(F.ravi, 20, 64, 24);
end

function v = piLevel(k)
% gray level of frame k of the Pi video (the same in test_video)
v = mod(k*7, 200) + 30;
end

function writeRavi(file, n, W, H)
% minimal PIX Connect .ravi: AVI with a metadata line first in every frame, no index
sh = H + 1;
ticks = uint64(posixtime(datetime(2026, 10, 20, 11, 59, 55))*1e7) + uint64(621355968000000000);
frames = uint8([]);
for k = 1:n
    raw = zeros(sh, W, 'uint16');
    raw(2:end, :) = 2000 + k;
    raw(1, 1) = 96; raw(1, 2) = 1001; raw(1, 5) = W;
    raw(1, 25:28) = typecast(ticks, 'uint16');
    raw(1, 37) = mod((k-1)*13 + 13*(k > 15), 65536); % one camera frame dropped after frame 15
    raw(1, 39) = k == 5;
    frames = [frames, chunk('00db', typecast(reshape(raw', 1, []), 'uint8'))]; %#ok<AGROW>
end
avih = zeros(1, 14, 'uint32'); avih(1) = 500000; avih(5) = n; avih(9) = W; avih(10) = sh;
strh = zeros(1, 56, 'uint8'); strh(1:4) = uint8('vids');
strh(21:28) = typecast(uint32([1 2]), 'uint8');
strf = zeros(1, 40, 'uint8'); strf(1:4) = typecast(uint32(40), 'uint8');
strf(5:12) = typecast(int32([W sh]), 'uint8');
xml = uint8('<Layout><Videoformat><FR>26</FR></Videoformat></Layout>');
hdrl = list('hdrl', [chunk('avih', typecast(avih, 'uint8')), list('strl', [chunk('strh', strh), chunk('strf', strf)])]);
body = [uint8('AVI '), hdrl, list('INFO', chunk('I000', xml)), list('movi', frames)];
f = fopen(file, 'w');
fwrite(f, [uint8('RIFF'), typecast(uint32(numel(body)), 'uint8'), body], 'uint8');
fclose(f);
end

function c = chunk(id, data)
c = [uint8(id), typecast(uint32(numel(data)), 'uint8'), data];
if mod(numel(data), 2); c(end+1) = 0; end
end

function c = list(type, data)
c = chunk('LIST', [uint8(type), data]);
end
