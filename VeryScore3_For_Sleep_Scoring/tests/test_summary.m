function tests = test_summary
% TEST_SUMMARY Summary figure (VS3_summary, Tools > Summary figure): the breathing and heart rate of the
% Pi sensor, the breathing seen by a Pi ROI and the temperature of the warm spot of the thermal video.
% Synthetic data only (videoFixtures, a sensor CSV with breathing at 2 Hz and a heart at 7.25 Hz).
%
%   results = runtests('tests/test_summary.m')
tests = functiontests(localfunctions);
end

function setupOnce(t)
addpath(fileparts(fileparts(mfilename('fullpath'))));
t.TestData.dir = tempname;
mkdir(t.TestData.dir);
end

function teardownOnce(t)
close all force
rmdir(t.TestData.dir, 's');
end

function testSensorAndVideoBreathingPanels(t)
nEp = 300;
b = repmat('n', 1, nEp); b(1:50) = 'w'; b(200:240) = 'r';
sensor = struct('epochs', (1:nEp)', 'breathing', 2*ones(nEp, 1), 'heart', 8*ones(nEp, 1), ...
    'harmonic', false(nEp, 1), 'bands', [.5 5; 5 15]);
sensor.breathing(100:110) = NaN;                           % no value (gap, clipping)
sensor.heart(120:126) = 4; sensor.harmonic(120:126) = true; % twice the breathing: not a heart rate
video = struct('roi', 'nest', 'epochs', (8:15:nEp)', 'frequency', 2.5*ones(numel(8:15:nEp), 1));
video.frequency(1) = NaN;                                   % the animal moved
[fig, S] = VS3_summary('b', b, 'sensor', sensor, 'videoBreathing', video, 'visible', 'off');
t.addTeardown(@() close(fig));
ax = findall(fig, 'Type', 'axes', 'Tag', 'VS3summary');
labels = arrayfun(@(a) strjoin(cellstr(a.YLabel.String), ' '), ax, 'UniformOutput', false);
verifyEqual(t, numel(ax), 3);                              % hypnogram, breathing, heart rate
verifyTrue(t, any(contains(labels, 'breathing')) && any(contains(labels, 'heart rate')));
verifyEqual(t, S.breathing.sensorMedian, 120*ones(1, nEp), 'AbsTol', 1e-9);
verifyEqual(t, S.heart.sensorMedian, 480*ones(1, nEp), 'AbsTol', 1e-9); % the harmonic epochs left out
verifyEqual(t, S.breathing.video.value, 150*ones(1, numel(23:15:nEp)));
verifyEqual(t, S.breathing.video.time, ((23:15:nEp) - 0.5)*4/3600, 'AbsTol', 1e-12);
end

function testOnlyTheVideoBreathing(t)
% no sensor: a breathing panel without the heart rate
b = repmat('n', 1, 120);
video = struct('roi', 'nest', 'epochs', (8:15:120)', 'frequency', 2*ones(8, 1));
[fig, S] = VS3_summary('b', b, 'videoBreathing', video, 'visible', 'off');
t.addTeardown(@() close(fig));
verifyEqual(t, numel(findall(fig, 'Type', 'axes', 'Tag', 'VS3summary')), 2);
verifyEqual(t, S.breathing.video.value, 120*ones(1, 8));
verifyFalse(t, isfield(S, 'heart'));
end

function testSummaryOfTheMainWindow(t)
% Tools > Summary figure with the Pi and thermal videos open, a Pi ROI and the sensor of the file:
% the temperature of the warm spot (thermal frame k: 1000 + k + an animal of 300 counts), the breathing
% and heart rate of the sensor; the ROI and warm spot results are kept with the video settings
d = fullfile(t.TestData.dir, 'main'); mkdir(d);
F = videoFixtures(d);
csv = sensorCsv(fullfile(d, 'sensor.csv'));
h5 = fullfile(d, 'sensor.h5');
VS3_sensorConvert({csv}, h5);
m = matfile(F.eeg, 'Writable', true);
m.Sensor = struct('source', h5, 'offset', 0, 'bands', [.5 5; 5 15], 'channels', 1);
dialogs = fullfile(t.TestData.dir, 'dialogs'); mkdir(dialogs);
writeText(fullfile(dialogs, 'listdlg.m'), sprintf(['function [s, ok] = listdlg(varargin)\n', ...
    '%% test stand-in: the first item of a single choice, every item of a multiple one\n', ...
    'ok = true; s = 1:numel(varargin{2});\n', ...
    'if any(strcmpi(varargin(cellfun(@ischar, varargin)), ''single'')); s = 1; end\nend\n']));
addpath(dialogs);
t.addTeardown(@() rmpath(dialogs));
before = findall(groot, 'Type', 'figure');
VS3_main(F.eeg, 'pi', F.pi, 'thermal', F.h5);
main = setdiff(findall(groot, 'Type', 'figure'), before);
main = main(strcmp(get(main, 'Tag'), 'VS3Main'));
t.addTeardown(@() delete(main));
P = getappdata(findobj(main, 'Tag', 'VS3video'), 'VS3_videoPanel');
P.rois = struct('video', 'pi', 'rect', [150 100 40 40], 'name', 'square');
P.refresh()
menu = findall(main, 'Type', 'uimenu', 'Text', 'Summary figure...');
menu.Callback(menu, []);
fig = findall(groot, 'Type', 'figure', '-regexp', 'Name', '^Summary');
assertEqual(t, numel(fig), 1);
ax = findall(fig, 'Type', 'axes', 'Tag', 'VS3summary');
labels = arrayfun(@(a) strjoin(cellstr(a.YLabel.String), ' '), ax, 'UniformOutput', false);
verifyTrue(t, all(cellfun(@(x) any(contains(labels, x)), {'temperature', 'breathing', 'heart rate'})));
th = ax(contains(labels, 'temperature'));
L = findobj(th, 'Type', 'line', 'Color', [.75 .15 .1]);
v = L.YData;
verifyEqual(t, numel(v), 15);
verifyEqual(t, diff(v(2:10)), 8*ones(1, 8), 'AbsTol', 1e-6); % 8 frames (2 Hz) per epoch
verifyEqual(t, v(2) - (1000 + 2*(6 + 5)), 300, 'AbsTol', 20); % frames of epoch 2: video 9 to 13 s
br = ax(contains(labels, 'breathing'));
sensorLine = findobj(br, 'Type', 'line', 'Color', [.1 .45 .6]);
verifyEqual(t, median(sensorLine.YData, 'omitnan'), 120, 'AbsTol', 1e-6);
hr = ax(contains(labels, 'heart rate'));
heartLine = findobj(hr, 'Type', 'line', 'Color', [.55 .2 .5]);
verifyEqual(t, median(heartLine.YData, 'omitnan'), 435, 'AbsTol', 1e-6);
S = P.settings();
verifyTrue(t, isfield(S.warmSpot, 'value'));
verifyEqual(t, {S.breathing.roi}, {'square'});
verifyEqual(t, S.breathing.epochs, 8);  % one epoch per minute: the middle of the first minute
end

%% ======================================================================= helpers
function file = sensorCsv(file)
% 60 s of the Pi sensor at 200 Hz from the start of the EEG (2026-10-20 10:00:00 UTC):
% breathing at 2 Hz, heart at 7.25 Hz (not a harmonic of the breathing: 8 Hz would be counted as one)
time = (0:200*60 - 1)'/200;
raw = round(2000 + 120*sin(2*pi*2*time) + 40*sin(2*pi*7.25*time));
fid = fopen(file, 'w');
fprintf(fid, 'type,session,sample_index,utc,elapsed_s,raw_adc,rate_hz,segment_id,near_rail,filter_warmup,demo,edge_monotonic_ns\n');
for k = 1:numel(time)
    fprintf(fid, 'sample,session,%d,2026-10-20T10:00:00+00:00,%.9f,%d,200,0,0,0,False,%.0f\n', k, time(k), raw(k), 1e12 + time(k)*1e9);
end
fclose(fid);
end

function writeText(p, value)
f = fopen(p, 'w');
fprintf(f, '%s', value);
fclose(f);
end
