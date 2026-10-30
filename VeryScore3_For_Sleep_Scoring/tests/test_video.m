function tests = test_video
% TEST_VIDEO Video column of VeryScore3 (Tools > Video): VS3_video, VS3_videoPanel, VS3_videoTiming.
%
% Synthetic recordings made in a temporary folder: a 60-s EEG file (start 2026-10-20 10:00:00 UTC),
% a Pi camera video of 30 s at 30 frames/s that started 10 s before the EEG, with its
% .timestamps.csv (the gray level of frame k is known, a textured square moves by 5 pixels at
% 0.5 Hz), a thermal .h5 of 60 s at 2 Hz that started 5 s before the EEG, and a .ravi.
%
%   results = runtests('tests/test_video.m')
tests = functiontests(localfunctions);
end

function setupOnce(t)
addpath(fileparts(fileparts(mfilename('fullpath'))));
d = tempname;
mkdir(d);
t.TestData.dir = d;
F = videoFixtures(d);
for f = fieldnames(F)'; t.TestData.(f{1}) = F.(f{1}); end
end

function teardownOnce(t)
close all force
rmdir(t.TestData.dir, 's');
end

%% ======================================================================= VS3_video
function testPiTimesAndFrames(t)
V = VS3_video(t.TestData.pi);
c = onCleanup(@() delete(V));
verifyEqual(t, V.kind, 'pi');
verifyEqual(t, V.nFrames, 900);
verifyEqual(t, V.time(31), 1, 'AbsTol', 1e-6);
verifyEqual(t, posixtime(V.startTime), posixtime(datetime(2026, 10, 20, 9, 59, 50, 'TimeZone', 'UTC')), 'AbsTol', 1e-6);
for k = [500 12 13 14 899 1 2 400]     % random access, then sequential frames
    img = V.frame(k);
    verifyLessThan(t, abs(double(img(5, 5, 1)) - piLevel(k)), 6, sprintf('frame %d', k));
end
V.offset = 10;
verifyEqual(t, V.frameAt(0), 301);       % EEG time 0 = video time 10 s
verifyEqual(t, V.frameAt(1.01), 331);
verifyTrue(t, isnan(V.frameAt(25)));     % after the end of the video
verifyEqual(t, numel(V.framesBetween(0, 4)), 120);
end

function testThermalH5(t)
V = VS3_video(t.TestData.h5);
c = onCleanup(@() delete(V));
verifyEqual(t, [V.kind, '/', V.format], 'thermal/h5');
verifyEqual(t, V.unit, 'counts');
img = V.frame(7);
verifyEqual(t, size(img), [48 64]);
verifyEqual(t, double(img(1)), 1007);
V.offset = 5;
verifyEqual(t, V.frameAt(0), 11);
verifyEqual(t, V.frameAt(0.9), 12);
end

function testRavi(t)
V = VS3_video(t.TestData.ravi);
c = onCleanup(@() delete(V));
verifyEqual(t, [V.nFrames V.width V.height], [20 64 24]);
verifyEqual(t, V.time(1:3)', [0 .5 1], 'AbsTol', 1e-9);      % hardware counter / camera rate
verifyEqual(t, V.time([15 16 20])', [7 8 10], 'AbsTol', 1e-9); % the dropped camera frame is seen
V.frame(5);
verifyFalse(t, V.valid(5));                                 % shutter cycle, known once read
verifyEqual(t, double(V.frame(3)), 2003*ones(24, 64));
verifyEqual(t, char(string(V.startTime, 'yyyy-MM-dd HH:mm:ss')), '2026-10-20 11:59:55');
end

function testDefaultOffsetsInMainWindow(t)
fig = openMain(t, 'pi', t.TestData.pi, 'thermal', t.TestData.h5);
P = getappdata(findobj(fig, 'Tag', 'VS3video'), 'VS3_videoPanel');
verifyEqual(t, P.pi.offset, 10, 'AbsTol', 1e-6);      % UTC of the first frame
verifyEqual(t, P.thermal.offset, 5, 'AbsTol', 1e-6);  % start time of the camera, clock of the PC
end

%% ======================================================================= the column of the main window
function testColumnFollowsTheEpoch(t)
fig = openMain(t, 'pi', t.TestData.pi, 'thermal', t.TestData.h5);
panel = findobj(fig, 'Tag', 'VS3video');
P = getappdata(panel, 'VS3_videoPanel');
verifyEqual(t, char(panel.Visible), 'on');
plotax = P.plot.plotax;
verifyEqual(t, plotax.Position(3), .58, 'AbsTol', 1e-9);     % the traces made room
key(fig, 'd'); key(fig, 'd');                                 % epoch 3: EEG 8 s
verifyEqual(t, P.plot.position, 3);
im = findobj(panel, 'Type', 'image');
verifyEqual(t, numel(im), 2);
piImg = im(arrayfun(@(i) size(i.CData, 3) == 3, im));
verifyLessThan(t, abs(double(piImg.CData(5, 5, 1)) - piLevel(541)), 6); % video 18 s = frame 541
thImg = im(arrayfun(@(i) size(i.CData, 3) == 1, im));
verifyEqual(t, double(thImg.CData(1)), 1027);                % thermal 13 s = frame 27

P.setMode('overlap')
verifyNotEmpty(t, findobj(panel, 'Type', 'surface'));
P.setMode('thermal')
verifyEqual(t, numel(findobj(panel, 'Type', 'image')), 1);

closeMenu = findobj(fig, 'Type', 'uimenu', 'Text', 'Close Pi camera video');
closeMenu.Callback(closeMenu, []);
verifyTrue(t, isempty(P.pi) && ~isempty(P.thermal));
closeMenu = findobj(fig, 'Type', 'uimenu', 'Text', 'Close thermal video');
closeMenu.Callback(closeMenu, []);
verifyEmpty(t, findobj(fig, 'Tag', 'VS3video'));             % the column disappeared
verifyEqual(t, plotax.Position(3), .9, 'AbsTol', 1e-9);
end

function testPlaybackRunsOverTheEpoch(t)
fig = openMain(t, 'pi', t.TestData.pi);
P = getappdata(findobj(fig, 'Tag', 'VS3video'), 'VS3_videoPanel');
key(fig, 'space');
pause(1)
L = findobj(P.plot.plotax, 'Type', 'line', 'Color', [0 0 0], 'LineWidth', 1.5);
verifyNotEmpty(t, L);
verifyGreaterThan(t, L(1).XData(1), 0.3);       % the line moves with the frames
pause(4)
verifyEmpty(t, findobj(P.plot.plotax, 'Type', 'line', 'LineWidth', 1.5)); % stopped at the end of the epoch
end

function testRoiFollowsTheMovingSquare(t)
fig = openMain(t, 'pi', t.TestData.pi);
P = getappdata(findobj(fig, 'Tag', 'VS3video'), 'VS3_videoPanel');
P.rois = struct('video', 'pi', 'rect', [150 100 40 40], 'name', 'square');
P.refresh()
D = P.roiData;
verifyEqual(t, {D.name}, {'square dx', 'square dy', 'square brightness'});
k = (0:119)' + 300;                              % frames of epoch 1 (video 10 to 14 s)
x = round(5*sin(2*pi*0.5*k/30));
verifyEqual(t, D(1).v, x - x(1), 'AbsTol', 0.6);
verifyEqual(t, D(2).v, zeros(120, 1), 'AbsTol', 0.6);
end

function testOverlayAlignmentTransform(t)
fig = openMain(t, 'pi', t.TestData.pi, 'thermal', t.TestData.h5);
P = getappdata(findobj(fig, 'Tag', 'VS3video'), 'VS3_videoPanel');
P.overlay = [2 0 10; 0 2 20; 0 0 1];
P.setMode('overlap')
s = findobj(fig, 'Type', 'surface');
verifyEqual(t, s.XData(1, :), [2*.5+10, 2*64.5+10]);
verifyEqual(t, s.YData(:, 1)', [2*.5+20, 2*48.5+20]);
S = P.settings();
verifyEqual(t, S.overlay, P.overlay);
verifyEqual(t, S.piOffset, 10, 'AbsTol', 1e-6);
end

%% ======================================================================= clock maps
function testTimeMapNeverCrossesInvalidAnchors(t)
S = struct('native', [0 1 2 3 4], 'common', [10 11 NaN 13 14], 'valid', [1 1 0 1 1], ...
    'segment', [1 1 1 1 1], 'uncertainty', zeros(1, 5));
M = VS3_videoTiming('build', S);
[x, ok] = VS3_videoTiming('forward', M, [0.5 1.5 3.5 5]);
verifyEqual(t, x(1), 10.5, 'AbsTol', 1e-12);
verifyEqual(t, ok, [true false true false]);
verifyEqual(t, x(3), 13.5, 'AbsTol', 1e-12);
y = VS3_videoTiming('inverse', M, 13.25);
verifyEqual(t, y, 3.25, 'AbsTol', 1e-12);
verifyEqual(t, VS3_videoTiming('ns', '1761300000123456789'), int64(1761300000123456789));
end

function testRecorderTimingCamera(t)
% two status observations of the camera clock (1000 s and 1010 s of its sensor clock = video times 0
% and 10 s), seen by the PC at EEG start + 15 s and + 25 s, camera clock 5 s ahead of the PC:
% video time 0 -> EEG 10 s, 10 s -> EEG 20 s, nothing outside (synthetic, after Wenjie's fixture)
d = fullfile(t.TestData.dir, 'timing_camera');
mkdir(d);
video = fullfile(d, 'camera.mp4');
copyfile(t.TestData.pi, video);
origin = int64(1793188174)*int64(1e9) + int64(95000000);
f = fopen(fullfile(d, 'camera.timestamps.csv'), 'w');
fprintf(f, 'frame_index,video_pts_us,sensor_timestamp_ns,estimated_utc,interval_ms,timestamp_source\n');
for k = 0:899
    pts = round(k/30*1e6);
    fprintf(f, '%d,%d,%s,2026-10-28T11:49:50.000000+00:00,33.3,request_metadata\n', k, pts, ...
        string(int64(1e12) + int64(pts)*int64(1000)));
end
fclose(f);
writeJson(fullfile(d, 'camera.json'), struct('schema_version', 2, 'video', 'camera.mp4', 'session', 'CAMERA_SESSION', ...
    'closed', true, 'clock_anchor', struct('boot_id', 'BOOT_CAMERA', 'monotonic_clock', 'CLOCK_BOOTTIME')));
for k = 1:2
    clk = struct('utc_ns', origin + int64(15 + (k-1)*10)*int64(1e9), 'monotonic_ns', int64(1000 + (k-1)*10)*int64(1e9), ...
        'boot_id', 'BOOT_CAMERA', 'monotonic_clock', 'CLOCK_BOOTTIME', 'capture_uncertainty_ns', 100);
    events(k) = struct('schema_version', 1, 'device', 'camera', 'event', 'status_observed', 'details', ...
        struct('session', 'CAMERA_SESSION', 'instance', 'INSTANCE_CAMERA', 'path', video, 'clock', clk)); %#ok<AGROW>
    comparisons(k) = struct('device', 'camera', 'usable', true, 'transition', 'continuous', ...
        'offset_definition', 'remote_utc_minus_host_utc', 'estimated_offset_ns', int64(5)*int64(1e9), ...
        'uncertainty_ns', int64(200000000), 'remote_clock', clk); %#ok<AGROW>
end
writeJson(fullfile(d, 'quality.json'), struct('clock_comparisons', comparisons));
writeJson(fullfile(d, 'manifest.json'), struct('schema_version', 1, 'recording_state', 'saved'));
writeText(fullfile(d, 'evidence.jsonl'), [jsonencode(events(1)), newline, jsonencode(events(2)), newline]);

V = VS3_video(video);
c = onCleanup(@() delete(V));
M = VS3_videoTiming('camera', d, V, origin);
V.timeMap = M;
e = V.eegTimes();
verifyEqual(t, e([1 151 301]), [10; 15; 20], 'AbsTol', 1e-6);
verifyTrue(t, all(isnan(e(302:end))));
verifyEqual(t, V.frameAt(15), 151);
meta = VS3_videoTiming('json', fullfile(d, 'camera.json'));
meta.session = 'OTHER_SESSION';
writeJson(fullfile(d, 'camera.json'), meta);
verifyError(t, @() VS3_videoTiming('camera', d, V, origin), 'VS3_videoTiming:camera');
end

function testRecorderTimingThermal(t)
% every frame of the .ravi mapped onto an EEG sample number (frame 2 not mapped), the EEG stream found
% by its identity although its path is that of the recording PC (synthetic, after Wenjie's fixture)
d = fullfile(t.TestData.dir, 'timing_thermal');
mkdir(d);
V = VS3_video(t.TestData.ravi);
c = onCleanup(@() delete(V));
utc = int64(1793188174)*int64(1e9) + int64(95000000);
first = int64(156287173);
streamPath = 'C:\Ran\eeg\Record Node 116\experiment1\recording3\continuous\Acquisition_Board-114.acquisition_board';
stream = struct('path', streamPath, 'origin', struct('utc_ns', utc, 'sample_number', first, 'sample_rate', 1000), 'samples', 10000);
writeJson(fullfile(d, 'thermal-eeg-quality.json'), struct('schema_version', 1, 'thermal_path', ['C:\Ran\thermal\', 'therm.ravi'], ...
    'frames', V.nFrames, 'eeg_streams', stream));
writeJson(fullfile(d, 'manifest.json'), struct('schema_version', 1, 'recording_state', 'saved'));
f = fopen(fullfile(d, 'thermal-eeg-alignment.csv'), 'w');
fprintf(f, 'frame_index,counter_hw,utc_estimate_ns,eeg_stream,eeg_sample_number_estimate,nearest_recorded_sample_number,sample_row,status\n');
g = fopen(fullfile(d, 'thermal-frame-times.csv'), 'w');
fprintf(g, 'frame_index,counter_hw,utc_estimate_ns,transport_epoch,method,direct_ipc_counter_match,delivery_residual_max_seconds,capture_latency_bound_seconds,averaging_window_reference\n');
for k = 0:V.nFrames-1
    value = 4 + .5*k;
    status = 'software_estimate';
    method = 'native_counter_calibrated';
    if k == 2; status = 'thermal_unmapped'; method = 'unmapped'; end
    ns = utc + int64(value*1e9);
    sample = double(first) + value*1000;
    fprintf(f, '%d,%d,%s,%s,%.6f,%.0f,%.0f,%s\n', k, 100 + k, string(ns), streamPath, sample, sample, value*1000, status);
    fprintf(g, '%d,%d,%s,1,%s,True,0.01,unknown,unverified\n', k, 100 + k, string(ns), method);
end
fclose(f);
fclose(g);
Infos = struct('Fs', 1000, 'nSamples', 10000, 'FirstSampleNumber', double(first), 'StartTimePosix', double(utc)/1e9);
M = VS3_videoTiming('thermal', d, V, VS3_videoTiming('eeg', Infos));
[x, ok] = VS3_videoTiming('forward', M, [0 1 2 3 4]);
verifyEqual(t, ok, [true true false true true]);
verifyEqual(t, x(ok), [4 4.5 5.5 6], 'AbsTol', 1e-9);
V.timeMap = M;
verifyTrue(t, isnan(V.frameAt(5.3)));    % frame 2 (EEG 5 s) has no clock observation: not shown
verifyEqual(t, V.frameAt(5.6), 4);       % frame 3, 0-based
Infos.nSamples = 9999;                   % another EEG
verifyError(t, @() VS3_videoTiming('thermal', d, V, VS3_videoTiming('eeg', Infos)), 'VS3_videoTiming:eeg');
end

%% ======================================================================= helpers
function v = piLevel(k)
% gray level of frame k of the Pi video
v = mod(k*7, 200) + 30;
end

function fig = openMain(t, varargin)
before = findall(groot, 'Type', 'figure');
VS3_main(t.TestData.eeg, varargin{:});
fig = setdiff(findall(groot, 'Type', 'figure'), before);
fig = fig(1);
closeMsg();
t.addTeardown(@() closeFig(fig));
end

function closeMsg()
% the message of Tools > Video > Open (not shown by VS3_main(file, ...), but just in case)
delete(findall(groot, 'Type', 'figure', 'Tag', 'Msgbox_Video'));
end

function closeFig(fig)
if isgraphics(fig); close(fig); end
end

function key(fig, k)
fig.KeyPressFcn(fig, struct('Key', k, 'Modifier', {{}}, 'Character', k));
end

function writeJson(p, value)
writeText(p, jsonencode(value));
end

function writeText(p, value)
f = fopen(p, 'w');
fprintf(f, '%s', value);
fclose(f);
end
