function tests = test_openEphys
% TEST_OPENEPHYS File > Convert Open Ephys recording (VS3_convertOpenEphys) on a synthetic recording:
% Session\Record Node 115\experiment1\recording1, an acquisition board stream (CH6, CH7, ADC1 at
% 1000 Hz, 48 s) and a memory monitor stream that is never converted.
% Any folder of the recording (session down to the folder of the stream) finds that recording; the
% channels keep their physical values; 'channels' converts a part of them; 'overwrite' false
% leaves an existing conversion alone. After the Open Ephys test of Wenjie (October 2026).
%
%   results = runtests('tests/test_openEphys.m')
tests = functiontests(localfunctions);
end

function setupOnce(t)
addpath(fileparts(fileparts(mfilename('fullpath'))));
d = tempname;
t.TestData.folder = d;
t.TestData.node = fullfile(d, 'Session', 'Record Node 115');
t.TestData.experiment = fullfile(t.TestData.node, 'experiment1');
t.TestData.recording = fullfile(t.TestData.experiment, 'recording1');
t.TestData.continuous = fullfile(t.TestData.recording, 'continuous');
t.TestData.stream = fullfile(t.TestData.continuous, 'Acquisition_Board-114.acquisition_board');
mkdir(t.TestData.stream);
time = (0:47999)/1000;
t.TestData.raw = int16([round(500*sin(2*pi*2*time)); round(200*sin(2*pi*8*time)); 2000 + round(100*sin(2*pi*time))]);
writeBinary(fullfile(t.TestData.stream, 'continuous.dat'), t.TestData.raw, 'int16');
writeNpy(fullfile(t.TestData.stream, 'sample_numbers.npy'), int64(100 + (0:47999)), '<i8', 'int64');
channels = struct('channel_name', {'CH6', 'CH7', 'ADC1'}, 'bit_volts', {.195, .195, .001}, 'units', {'uV', 'uV', 'V'});
stream = struct('stream_name', 'acquisition_board', 'num_channels', 3, 'sample_rate', 1000, 'channels', channels, ...
    'folder_name', 'Acquisition_Board-114.acquisition_board', 'source_processor_name', 'Acquisition Board');
memory = stream;
memory.stream_name = 'memory_usage';
memory.num_channels = 1;
memory.sample_rate = 100;
memory.channels = struct('channel_name', 'MEM', 'bit_volts', 1, 'units', '%');
memory.folder_name = 'Acquisition_Board-114.memory_usage';
mkdir(fullfile(t.TestData.continuous, memory.folder_name));
writeBinary(fullfile(t.TestData.continuous, memory.folder_name, 'continuous.dat'), int16(ones(1, 4800)), 'int16');
writeText(fullfile(t.TestData.recording, 'structure.oebin'), jsonencode(struct('continuous', [stream memory])));
writeText(fullfile(t.TestData.recording, 'sync_messages.txt'), sprintf([ ...
    'Software Time (milliseconds since midnight Jan 1st 1970 UTC): 1790270348745\n' ...
    'Start Time for Acquisition Board (114) - acquisition_board @ 1000 Hz: 100\n']));
end

function teardownOnce(t)
if isfolder(t.TestData.folder); rmdir(t.TestData.folder, 's'); end
end

function testEveryFolderOfTheRecording(t)
names = {'session', 'node', 'experiment', 'recording', 'continuous', 'stream'};
folders = {fullfile(t.TestData.folder, 'Session'), t.TestData.node, t.TestData.experiment, t.TestData.recording, ...
    t.TestData.continuous, t.TestData.stream};
for k = 1:numel(folders)
    files = VS3_convertOpenEphys(folders{k}, fullfile(t.TestData.folder, ['out_', names{k}]), 'interactive', false);
    assertNumElements(t, files, 1, names{k});
    S = load(files{1});
    verifyEqual(t, S.traceName, {'CH6', 'CH7', 'ADC1'}, names{k});
    verifyEqual(t, S.traces, double(t.TestData.raw).*[.195e-6; .195e-6; .001], 'AbsTol', 1e-14);
    verifyEqual(t, [S.Infos.Fs, S.Infos.nSamples, S.Infos.FirstSampleNumber], [1000 48000 100]);
    verifyEqual(t, S.Infos.Stream, 'acquisition_board');
end
end

function testChosenChannels(t)
files = VS3_convertOpenEphys(t.TestData.node, fullfile(t.TestData.folder, 'numbers'), 'interactive', false, 'channels', [1 2]);
S = load(files{1});
verifyEqual(t, S.traceName, {'CH6', 'CH7'});
verifyEqual(t, S.Infos.Channel, 'CH6, CH7');
verifyEqual(t, S.Infos.BitVolts, [.195 .195]);
verifyEqual(t, S.Infos.ConvertedChannels, [1 2]);
verifyEqual(t, S.traces, double(t.TestData.raw(1:2, :))*.195e-6, 'AbsTol', 1e-14);
files = VS3_convertOpenEphys(t.TestData.node, fullfile(t.TestData.folder, 'names'), 'interactive', false, 'channels', {'ADC1', 'CH6'});
S = load(files{1});
verifyEqual(t, S.traceName, {'CH6', 'ADC1'});
verifyEqual(t, S.Infos.ConvertedChannels, [1 3]);
end

function testNoOverwrite(t)
out = fullfile(t.TestData.folder, 'noOverwrite');
files = VS3_convertOpenEphys(t.TestData.node, out, 'interactive', false, 'overwrite', false);
sentinel = 12345;
save(files{1}, 'sentinel');
VS3_convertOpenEphys(t.TestData.node, out, 'interactive', false, 'overwrite', false);
verifyEqual(t, load(files{1}), struct('sentinel', sentinel));
end

function testSubsetNamesAndCentredDisplay(t)
% a file with Infos.Channel of the whole recording but only some channels (older conversions), and
% DC levels of the acquisition board: the names come from traceName, the traces are centred
file = fullfile(t.TestData.folder, 'subset.mat');
time = (0:47999)/1000;
traces = [.005 + .0001*sin(2*pi*2*time); -.003 + .0001*sin(2*pi*8*time)];
Infos = struct('Fs', 1000, 'Channel', 'CH6, CH7, CH9, CH10', 'Unit', 'V', 'Stream', 'acquisition_board');
traceName = {'CH6', 'CH7'};
save(file, 'traces', 'Infos', 'traceName', '-v7.3');
before = findall(groot, 'Type', 'figure');
VS3_main(file);
fig = setdiff(findall(groot, 'Type', 'figure'), before);
c = onCleanup(@() delete(fig));
txt = findobj(fig, 'Type', 'text');
verifyTrue(t, all(ismember({'CH6', 'CH7'}, {txt.String})));
L = findobj(fig, 'Type', 'line', '-function', @(o) numel(o.UserData) == 2);
verifyEqual(t, numel(L), 2);
for k = 1:2
    i = L(k).UserData(1);
    verifyEqual(t, median(L(k).YData), -6e-4*i, 'AbsTol', 1e-8); % in its slot (space 0.0006)
end
end

%% ======================================================================= helpers
function writeText(p, txt)
fid = fopen(p, 'w');
fprintf(fid, '%s', txt);
fclose(fid);
end

function writeBinary(p, values, type)
fid = fopen(p, 'w', 'ieee-le');
fwrite(fid, values, type);
fclose(fid);
end

function writeNpy(p, values, descr, type)
% numpy 1.0, one-dimensional, little-endian (header aligned to 64 bytes)
header = sprintf('{''descr'': ''%s'', ''fortran_order'': False, ''shape'': (%d,), }', descr, numel(values));
header = [header, repmat(' ', 1, mod(-(10 + numel(header) + 1), 64)), newline];
fid = fopen(p, 'w', 'ieee-le');
fwrite(fid, [147 double('NUMPY') 1 0], 'uint8');
fwrite(fid, numel(header), 'uint16');
fwrite(fid, header, 'char');
fwrite(fid, values, type);
fclose(fid);
end
