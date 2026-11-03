classdef VS3_video < handle
    %VS3_VIDEO One video recorded with the EEG, read frame by frame from its file.
    %
    % Two kinds of videos:
    %   'pi'       camera of the Raspberry Pi (.mp4, .avi, ...), with its <name>.timestamps.csv
    %              (frame_index, video_pts_us, sensor_timestamp_ns, estimated_utc, ...): the time of
    %              every frame and the clock time of the first one. Without that file the nominal
    %              frame rate is used (times can drift on variable frame rate videos).
    %   'thermal'  Optris video, the .ravi of PIX Connect read directly (energy counts) or the .h5
    %              made by Tools > Thermal video (degC when the camera calibration was added).
    % Nothing is converted or copied: one frame is read when it is shown.
    %
    %   V = VS3_video(file)               open (the kind follows from the extension)
    %   t = V.eegTimes()                  EEG time (s since EEG sample 1) of every frame, NaN = none
    %   k = V.frameAt(t)                  the frame on screen at EEG time t (NaN when there is none)
    %   k = V.framesBetween(t0, t1)       the frames with an EEG time in [t0, t1)
    %   img = V.frame(k)                  frame k (1 = first): RGB uint8, or a matrix (degC / counts)
    %   txt = V.describe()                one line for the messages (file, frames, rate, start)
    %
    % Alignment with the EEG, as for the thermal tool (Thermal.offset):
    %   video time = EEG time + V.offset   (V.offset > 0: the EEG started after the video)
    % or, when a recorder timing folder was loaded (VS3_videoTiming), the clock map of every
    % frame in V.timeMap, which replaces the offset.
    %
    % Alejandro Osorio-Forero with Claude, 2026. Frame access of the .ravi and the use of the Pi
    % timestamps after the synchronized review of Wenjie (VeryScore3, October 2026).

    properties
        offset = 0          % video time (s) at which EEG sample 1 was recorded
        offsetSource = ''   % where the offset comes from (start times, typed, ...)
        timeMap = []        % clock map of a recorder timing folder (VS3_videoTiming), [] = offset
    end

    properties (SetAccess = private)
        file
        kind                % 'pi' | 'thermal'
        format              % 'video' | 'ravi' | 'h5'
        nFrames = 0
        width = 0
        height = 0
        fs = NaN            % frame rate (frames / s, from the frame times)
        time                % time of every frame, s since time 0 of the video clock (column)
        startTime = NaT     % clock time of video time 0 (TimeZone 'UTC' for the Pi, PC clock otherwise)
        unit = 'RGB'        % 'RGB' | 'degC' | 'counts'
        clockFile = ''      % Pi: the .timestamps.csv ('' = nominal frame rate)
        valid               % per frame: false = not usable (thermal shutter cycle)
    end

    properties (Access = private)
        reader = []         % VideoReader (Pi) or ThermalH5 (.h5)
        fid = -1            % .ravi file
        ravi = struct()     % .ravi layout: frame offsets, stored height, metadata row
        ptsShift = 0        % Pi: time of the reader minus time of the timestamps file (first frame)
        lastIdx = NaN       % last frame read (sequential reading during playback)
        lastImg = []
        eegCache = []       % EEG time of every frame, for cacheKey
        cacheKey = []
    end

    methods
        function self = VS3_video(file)
            if ~isfile(file)
                error('VS3_video:file', 'The video file does not exist:\n%s', file);
            end
            [~, ~, ext] = fileparts(file);
            self.file = char(file);
            switch lower(ext)
                case '.ravi'
                    self.kind = 'thermal';
                    self.format = 'ravi';
                    self.openRavi();
                case '.h5'
                    self.kind = 'thermal';
                    self.format = 'h5';
                    self.openH5();
                otherwise
                    self.kind = 'pi';
                    self.format = 'video';
                    self.openPi();
            end
            dt = diff(self.time);
            dt = dt(dt > 0);
            if ~isempty(dt); self.fs = 1/median(dt); end
        end

        %% Time
        function t = eegTimes(self)
            % eegTimes  EEG time of every frame (s since EEG sample 1); NaN where the recorder
            % timing map has no valid clock observation.
            key = {self.offset, self.timeMap};
            if isequal(key, self.cacheKey) && numel(self.eegCache) == self.nFrames
                t = self.eegCache;
                return
            end
            if isempty(self.timeMap)
                t = self.time - self.offset;
            elseif strcmp(self.timeMap.coordinate, 'frame_index')
                t = VS3_videoTiming('forward', self.timeMap, (0:self.nFrames-1)');
            else
                t = VS3_videoTiming('forward', self.timeMap, self.time);
                if isfield(self.timeMap, 'frameValid') && numel(self.timeMap.frameValid) == self.nFrames
                    t(~self.timeMap.frameValid) = NaN; % frames without their camera request time
                end
            end
            t = t(:);
            self.eegCache = t;
            self.cacheKey = key;
        end

        function k = frameAt(self, t)
            % frameAt  The frame on screen at EEG time t: the last frame shown before t, unless the
            % video has a gap there (no frame for more than 1.5 frame intervals). NaN = no frame.
            e = self.eegTimes();
            k = find(e <= t + 1e-9, 1, 'last');
            if isempty(k) || ~(t - e(k) < 1.5/self.fs) || ~self.valid(k)
                k = NaN;
            end
        end

        function k = framesBetween(self, t0, t1)
            % framesBetween  Indices of the frames with an EEG time in [t0, t1), in time order.
            e = self.eegTimes();
            k = find(e >= t0 & e < t1 & self.valid);
            [~, o] = sort(e(k));
            k = k(o);
        end

        %% Frames
        function img = frame(self, k)
            % frame  Frame k (1 = first): RGB uint8 for the Pi, single matrix for a thermal video
            % (degC, or energy counts without the camera calibration; NaN = invalid pixel).
            if k == self.lastIdx
                img = self.lastImg;
                return
            end
            if k < 1 || k > self.nFrames || k ~= round(k)
                error('VS3_video:frame', 'There is no frame %g in this video (%d frames).', k, self.nFrames);
            end
            switch self.format
                case 'video'; img = self.piFrame(k);
                case 'h5';    img = self.reader.readFrames(k);
                case 'ravi';  img = self.raviFrame(k);
            end
            self.lastIdx = k;
            self.lastImg = img;
        end

        function txt = describe(self)
            % describe  File, number of frames, rate and start time, for the messages.
            [~, n, e] = fileparts(self.file);
            st = 'start time unknown';
            if ~isnat(self.startTime)
                s = self.startTime;
                if ~isempty(s.TimeZone); s.TimeZone = 'local'; end
                st = sprintf('first frame %s', char(string(s + seconds(self.time(1)), 'yyyy-MM-dd HH:mm:ss.SSS')));
            end
            txt = sprintf('%s%s: %d frames of %d x %d px, %.3g frames/s, %.2f h, %s', n, e, self.nFrames, ...
                self.width, self.height, self.fs, (self.time(end) - self.time(1))/3600, st);
            if strcmp(self.kind, 'pi') && isempty(self.clockFile)
                txt = sprintf('%s (no timestamps.csv: nominal frame rate)', txt);
            end
        end

        function C = cameraClock(self)
            % cameraClock  Clock columns of the Pi timestamps file used by the recorder timing
            % maps (VS3_videoTiming): C.hasRaw, C.firstSensorNs (int64), C.frameValid (per frame:
            % its time comes from the camera request metadata and agrees with its PTS).
            C = struct('hasRaw', false, 'firstSensorNs', int64([]), 'frameValid', false(self.nFrames, 1));
            if isempty(self.clockFile); return; end
            f = fopen(self.clockFile, 'r');
            cleanup = onCleanup(@() fclose(f));
            header = strsplit(fgetl(f), ',');
            src = find(strcmp(header, 'timestamp_source'), 1);
            if isempty(src); return; end
            fmt = repmat({'%*s'}, 1, numel(header));
            fmt([2 3 src]) = {'%f', '%s', '%s'};
            D = textscan(f, [strjoin(fmt, ''), '%*[^\n]'], 'Delimiter', ',', 'ReturnOnError', false);
            pts = D{1};
            fromRequest = strcmp(D{3}, 'request_metadata') & ~cellfun(@isempty, D{2});
            first = find(fromRequest, 1);
            if isempty(first); return; end
            ns = zeros(numel(pts), 1, 'int64');
            ns(fromRequest) = VS3_videoTiming('ns', D{2}(fromRequest));
            C.hasRaw = true;
            C.firstSensorNs = ns(first) - int64(round(pts(first)))*int64(1000);
            ok = fromRequest & abs(ns - C.firstSensorNs - int64(round(pts))*int64(1000)) <= int64(1000);
            n = min(numel(ok), self.nFrames);
            C.frameValid(1:n) = ok(1:n);
        end

        function delete(self)
            if self.fid >= 0; fclose(self.fid); end
            self.fid = -1;
            self.reader = [];
        end
    end

    methods (Access = private)
        %% Raspberry Pi camera
        function openPi(self)
            self.reader = VideoReader(self.file);
            self.width = self.reader.Width;
            self.height = self.reader.Height;
            [p, n] = fileparts(self.file);
            csv = fullfile(p, [n, '.timestamps.csv']);
            if isfile(csv)
                [self.time, self.startTime] = readPiClock(csv);
                self.clockFile = csv;
            else
                % no timestamps: nominal frame rate (the number of frames is counted by the reader)
                n = self.reader.NumFrames;
                self.time = (0:n-1)'/self.reader.FrameRate;
            end
            self.nFrames = numel(self.time);
            self.valid = true(self.nFrames, 1);
            % the reader can count the time from another origin than the timestamps file (MATLAB
            % puts the first frame of some .mp4 at 1/fps): its time of the first frame, before any read
            self.ptsShift = self.reader.CurrentTime - self.time(1);
        end

        function img = piFrame(self, k)
            % frame k of the Pi video, found by its presentation time (PTS): the reader's CurrentTime
            % is the PTS of the next frame it reads. The reader is moved only when k is not the next
            % frame (playback reads the frames one after the other).
            R = self.reader;
            t = self.time(k) + self.ptsShift;
            tol = 1e-4;
            if isempty(self.clockFile)
                if k ~= self.lastIdx + 1; R.CurrentTime = t; end
                img = readFrame(R);
                return
            end
            next = self.lastIdx + 1;    % the frame the reader is at, when nothing moved it
            sequential = k >= next && k - next <= 15 && hasFrame(R) && ...
                abs(R.CurrentTime - (self.time(min(next, self.nFrames)) + self.ptsShift)) <= tol;
            if sequential
                for i = next:k-1        % a few frames ahead (late playback): read on, faster than a seek
                    readFrame(R);
                end
            else
                if k <= 3
                    R.CurrentTime = 0; % from the first frame
                    for i = 1:k-1; readFrame(R); end
                else
                    R.CurrentTime = max(0, self.time(k-3) + self.ptsShift - 0.5/self.fs);
                    readFrame(R);
                    while hasFrame(R) && R.CurrentTime < t - tol
                        readFrame(R);
                    end
                end
            end
            if ~hasFrame(R) || (k > 1 && abs(R.CurrentTime - t) > tol)
                self.lastIdx = NaN;
                error('VS3_video:pts', ['Frame %d of the video is not where its timestamps file puts it ', ...
                    '(%.4f s expected, %.4f s found).'], k, t, R.CurrentTime);
            end
            img = readFrame(R);
        end

        %% Thermal video converted to .h5 (Tools > Thermal video)
        function openH5(self)
            addpath(fullfile(fileparts(mfilename('fullpath')), 'thermal'));
            T = ThermalH5(self.file);
            self.reader = T;
            self.width = T.width;
            self.height = T.height;
            self.nFrames = T.nFrames;
            self.time = T.time(:);
            self.valid = T.valid(:);
            self.startTime = T.startTime;
            self.unit = 'counts';
            if T.hasCelsius; self.unit = 'degC'; end
        end

        %% Thermal video of PIX Connect (.ravi), read directly
        function openRavi(self)
            self.fid = fopen(self.file, 'r', 'ieee-le');
            if self.fid < 0
                error('VS3_video:ravi', 'The thermal video cannot be read:\n%s', self.file);
            end
            info = dir(self.file);
            L = struct('movi', zeros(0, 2), 'index', [], 'fs', NaN, 'width', 0, 'storedHeight', 0, 'xml', '');
            L = raviChunks(self.fid, 0, info.bytes, L);
            if ~isempty(L.index)        % OpenDML index: one ix00 chunk per RIFF segment
                offsets = cell(1, numel(L.index));
                for k = 1:numel(L.index)
                    fseek(self.fid, L.index(k), 'bof');
                    h = fread(self.fid, 32, '*uint8');
                    if ~strcmp(char(h(1:4)'), 'ix00')
                        error('VS3_video:ravi', 'Unknown frame index in the thermal video.');
                    end
                    n = double(typecast(h(13:16), 'uint32'));
                    base = double(typecast(h(21:28), 'uint64'));
                    tab = fread(self.fid, [2, n], '*uint32');
                    offsets{k} = base + double(tab(1, :));
                end
                offsets = [offsets{:}];
            else                        % no index: every frame chunk of the movi lists
                offsets = [];
                for k = 1:size(L.movi, 1)
                    pos = L.movi(k, 1);
                    while pos + 8 <= L.movi(k, 2)
                        fseek(self.fid, pos, 'bof');
                        id = fread(self.fid, 4, 'uint8=>char')';
                        len = fread(self.fid, 1, 'uint32');
                        if numel(id) == 4 && any(strcmp(id(3:4), {'db', 'dc'})) && len > 0
                            offsets(end+1) = pos + 8; %#ok<AGROW>
                        end
                        pos = pos + 8 + len + rem(len, 2);
                    end
                end
            end
            if isempty(offsets) || ~isfinite(L.fs)
                error('VS3_video:ravi', 'No thermal frames found in %s.', self.file);
            end
            self.ravi.offsets = offsets(:);
            self.ravi.storedHeight = L.storedHeight;
            self.width = L.width;
            self.nFrames = numel(offsets);

            % the metadata line of the camera: first line (recent files) or last line (old files)
            self.ravi.metaRow = 0;
            first = self.raviRow(1, 1);
            last = self.raviRow(1, L.storedHeight);
            if isMetaRow(first, L.width)
                self.ravi.metaRow = 1;
            elseif isMetaRow(last, L.width)
                self.ravi.metaRow = L.storedHeight;
            end
            self.height = L.storedHeight - (self.ravi.metaRow > 0);

            % frame times: hardware frame counter / camera frame rate (as the .h5 conversion), else k/fs
            self.time = (0:self.nFrames-1)'/L.fs;
            self.valid = true(self.nFrames, 1);
            camFs = str2double(regexp(L.xml, '<Videoformat>.*?<FR>([\d.]+)</FR>', 'tokens', 'once'));
            if self.ravi.metaRow > 0 && self.width >= 39
                if ~isempty(camFs) && isfinite(camFs) && camFs > 0
                    self.time = self.raviCounter()/camFs;
                end
                % the shutter state of a frame is read with the frame (raviFrame): a few frames
                % every few minutes, reading the metadata line of all frames takes minutes on a network drive
                m = self.raviRow(1, self.ravi.metaRow, 39);
                ticks = double(m(25)) + double(m(26))*2^16 + double(m(27))*2^32 + double(m(28))*2^48;
                if ticks > 0 && ticks < 4e18
                    self.startTime = datetime(1, 1, 1) + seconds(ticks/1e7); % .NET ticks, clock of the PC
                    self.startTime.Format = 'yyyy-MM-dd HH:mm:ss.SSS';
                end
            end
            self.unit = 'counts';
        end

        function r = raviRow(self, k, row, n)
            % raviRow  line 'row' of stored frame k (uint16), its first n words
            if nargin < 4; n = self.width; end
            fseek(self.fid, self.ravi.offsets(k) + (row-1)*self.width*2, 'bof');
            r = fread(self.fid, n, '*uint16');
        end

        function c = raviCounter(self)
            % raviCounter  Hardware frame counter of the camera for every stored frame, unwrapped,
            % from the first one (camera frames; word 37 of the metadata line, 16 bits). PIX Connect
            % saves one camera frame in about N (27 Hz camera, 2 Hz video: 13 and 14 alternate), so
            % the counter stays within 1 camera frame of a straight line as long as no frame is
            % dropped. It is read for one frame in about 1400 and the frames in between are put on
            % that line; where the counter is off the line (dropped frames) the interval is halved
            % and read again, down to single frames. Reading every frame took 20 s for a 5-h
            % video on a network drive; this gives the times of the .h5 conversion within 2 camera
            % frames (70 ms; checked on a 5-h recording against the counters of the recorder).
            n = self.nFrames;
            raw = nan(n, 1);        % counter as stored (mod 65536), NaN = not read
            c = nan(n, 1);          % unwrapped
            first = min(n, 10);
            for k = 1:first; raw(k) = readCount(k); end
            c(1:first) = raw(1) + [0; cumsum(mod(diff(raw(1:first)), 65536))];
            inc = median(diff(c(1:first)));    % camera frames per stored frame (about)
            if ~(inc > 0); c = (0:n-1)'; return; end
            step = max(1, floor(20000/inc));   % far from the wrap of 65536
            if n < 10*step; step = 1; end      % a short video: every frame (the line needs many stretches)
            s = unique([first:step:n, n]);
            for i = 2:numel(s)
                b = s(i);
                raw(b) = readCount(b);
                c(b) = c(s(i-1)) + mod(raw(b) - raw(s(i-1)), 65536);
            end
            rate = median(diff(c(s))./diff(s(:))); % camera frames per stored frame, over long stretches
            if ~isfinite(rate); rate = inc; end
            for i = 2:numel(s)
                spread(s(i-1), s(i))
            end
            c = c - c(1);

            function spread(a, b)
                % frames between a and b (counters known): on the line unless a frame was dropped
                if b - a <= 1; return; end
                if abs(c(b) - c(a) - rate*(b - a)) <= 3
                    c(a+1:b-1) = c(a) + (c(b) - c(a))*(1:b-a-1)'/(b - a);
                    return
                end
                m = floor((a + b)/2);
                raw(m) = readCount(m);
                c(m) = c(a) + mod(raw(m) - raw(a), 65536);
                spread(a, m)
                spread(m, b)
            end

            function v = readCount(k)
                fseek(self.fid, self.ravi.offsets(k) + ((self.ravi.metaRow-1)*self.width + 36)*2, 'bof');
                v = double(fread(self.fid, 1, 'uint16'));
            end
        end

        function img = raviFrame(self, k)
            fseek(self.fid, self.ravi.offsets(k), 'bof');
            raw = fread(self.fid, [self.width, self.ravi.storedHeight], '*uint16')';
            if self.ravi.metaRow > 0
                if self.width >= 39
                    self.valid(k) = raw(self.ravi.metaRow, 39) == 0; % not during a shutter cycle
                end
                raw(self.ravi.metaRow, :) = [];
            end
            img = reshape(single(typecast(raw(:), 'int16')), size(raw)); % energy counts, as ThermalH5
            img(raw == 0) = NaN;
        end
    end
end

%% ======================================================================= helpers
function [t, start] = readPiClock(csv)
% time of every frame (video_pts_us, in s) and the clock time of video time 0 (estimated_utc of
% the first frame minus its PTS), from the .timestamps.csv of the Raspberry Pi camera
fid = fopen(csv, 'r');
if fid < 0; error('VS3_video:clock', 'The timestamps file cannot be read:\n%s', csv); end
cleanup = onCleanup(@() fclose(fid));
header = fgetl(fid);
if ~startsWith(header, 'frame_index,video_pts_us')
    error('VS3_video:clock', 'Not a timestamps file of the Pi camera (frame_index, video_pts_us, ...):\n%s', csv);
end
pos = ftell(fid);
row = strsplit(fgetl(fid), ',', 'CollapseDelimiters', false);
fseek(fid, pos, 'bof');
D = textscan(fid, '%f %f %*[^\n]', 'Delimiter', ',');
t = D{2}/1e6;
if any(diff(t) <= 0)
    error('VS3_video:clock', 'The frame times of %s do not increase.', csv);
end
start = NaT;
if numel(row) >= 4 && ~isempty(row{4})
    try
        start = VS3_videoTiming('utc', row{4}) - seconds(str2double(row{2})/1e6);
    catch
        start = NaT; % no usable clock time: the offset must be typed
    end
end
end

function L = raviChunks(fid, first, last, L)
% the RIFF chunks of a .ravi between file offsets first and last (lists are entered)
pos = first;
while pos + 8 <= last
    fseek(fid, pos, 'bof');
    id = fread(fid, 4, 'uint8=>char')';
    len = fread(fid, 1, 'uint32');
    if isempty(len) || numel(id) < 4 || pos + 8 + len > last + 1; break; end
    data = pos + 8;
    stop = data + len;
    switch id
        case {'RIFF', 'LIST'}
            type = fread(fid, 4, 'uint8=>char')';
            if strcmp(type, 'movi')
                L.movi(end+1, :) = [data + 4, stop];
            elseif any(strcmp(type, {'AVI ', 'AVIX', 'hdrl', 'strl', 'odml', 'INFO'}))
                L = raviChunks(fid, data + 4, stop, L);
            end
        case 'avih'
            fseek(fid, data, 'bof');
            a = fread(fid, 14, 'uint32');
            if a(1) > 0; L.fs = 1e6/a(1); end
            L.width = a(9);
            L.storedHeight = a(10);
        case 'strh'
            fseek(fid, data + 20, 'bof');
            a = fread(fid, 2, 'uint32');
            if a(1) > 0 && a(2) > 0; L.fs = a(2)/a(1); end
        case 'strf'
            fseek(fid, data + 4, 'bof');
            a = fread(fid, 2, 'int32');
            L.width = a(1);
            L.storedHeight = abs(a(2));
        case 'indx'
            fseek(fid, data + 4, 'bof');
            n = fread(fid, 1, 'uint32');
            fseek(fid, data + 24, 'bof');
            a = fread(fid, [2, n], 'uint64');
            L.index = double(a(1, :));
        otherwise
            if ~isempty(regexp(id, '^I\d{3}$', 'once'))   % PIX Connect layout (XML), in pieces
                fseek(fid, data, 'bof');
                L.xml = [L.xml, fread(fid, len, 'uint8=>char')'];
            end
    end
    pos = stop + rem(len, 2);
end
end

function tf = isMetaRow(r, width)
% the metadata line of the camera starts with its size, a version 10xx and the frame width
tf = numel(r) >= 5 && r(2) >= 1000 && r(2) < 1100 && r(5) == width;
end
