classdef ThermalH5 < handle
    % ThermalH5  Lazy access to a thermal recording converted with python/ravi2h5.py
    %
    %   T = ThermalH5('AH2_thermBL1.h5');
    %   T                          % summary
    %   img = T.readFrames(1);     % [H x W] single, degC (or counts if no calibration)
    %   S   = T.readFrames(10:20); % [H x W x 11]
    %   c   = T.readCounts(5);     % raw stored uint16 values (0 = invalid pixel)
    %
    % Frames are stored as uint16 energy counts; the conversion to degC is a lookup
    % table (celsius_lut) that is only present when the camera's Kennlinie file was
    % available at conversion time (see README).  If it is missing, readFrames returns
    % int16 energy counts and T.hasCelsius is false.
    %
    % Time base: T.time (seconds since recording start, 2 Hz for the mouse recordings),
    % T.startTime (datetime of the first frame, from the camera metadata), T.valid
    % (false for frames recorded during a shutter/flag cycle).

    properties (SetAccess = private)
        path
        nFrames
        width
        height
        fps
        time            % seconds since start of recording (column vector)
        startTime       % datetime (recording start on the acquisition PC), NaT if unknown
        valid           % logical column: true = frame usable
        hasCelsius      % true when a degC lookup table is present
        lut             % 65536 x 1 single, degC for stored value 0..65535 (NaN when unavailable)
        meta            % struct with per-frame camera metadata (temp_chip, temp_flag, hw_counter, ...)
        stats           % struct with per-frame statistics computed during conversion
        attrs           % all root attributes of the HDF5 file
    end

    methods
        function obj = ThermalH5(path)
            obj.path = path;
            info = h5info(path);
            a = struct();
            for k = 1:numel(info.Attributes)
                a.(matlab.lang.makeValidName(info.Attributes(k).Name)) = info.Attributes(k).Value;
            end
            obj.attrs = a;
            obj.nFrames = double(a.n_frames);
            obj.width = double(a.width);
            obj.height = double(a.height);
            obj.fps = double(a.fps);
            obj.time = double(h5read(path, '/time_s'));
            obj.time = obj.time(:);
            obj.valid = logical(h5read(path, '/frame_valid'));
            obj.valid = obj.valid(:);
            if isfield(a, 'start_time') && ~isempty(a.start_time) && ~all(a.start_time == 0)
                try
                    obj.startTime = datetime(char(a.start_time), 'InputFormat', "yyyy-MM-dd'T'HH:mm:ss.SSS");
                catch
                    obj.startTime = NaT;
                end
            else
                obj.startTime = NaT;
            end
            names = {info.Datasets.Name};
            obj.hasCelsius = any(strcmp(names, 'celsius_lut'));
            if obj.hasCelsius
                obj.lut = single(h5read(path, '/celsius_lut'));
                obj.lut = obj.lut(:);
            else
                obj.lut = nan(65536, 1, 'single');
            end
            obj.meta = ThermalH5.readGroup(path, info, 'meta');
            obj.stats = ThermalH5.readGroup(path, info, 'stats');
        end

        function c = readCounts(obj, idx)
            % readCounts  stored uint16 values, [H x W x numel(idx)], idx 1-based (may be non-contiguous)
            idx = idx(:)';
            c = zeros(obj.height, obj.width, numel(idx), 'uint16');
            % read contiguous runs in one go
            k = 1;
            while k <= numel(idx)
                j = k;
                while j < numel(idx) && idx(j + 1) == idx(j) + 1
                    j = j + 1;
                end
                n = j - k + 1;
                blk = h5read(obj.path, '/frames', [1 1 idx(k)], [obj.width obj.height n]);   % [W x H x n]
                c(:, :, k:j) = permute(blk, [2 1 3]);
                k = j + 1;
            end
        end

        function x = readFrames(obj, idx)
            % readFrames  frames in degC (single, NaN = invalid pixel); energy counts if no calibration
            c = obj.readCounts(idx);
            x = obj.toCelsius(c);
        end

        function x = toCelsius(obj, c)
            % toCelsius  convert stored uint16 counts to degC (or int16 energy counts without calibration)
            if obj.hasCelsius
                x = obj.lut(double(c) + 1);
                x = reshape(x, size(c));
            else
                x = single(typecast(c(:), 'int16'));
                x = reshape(x, size(c));
                x(c == 0) = NaN;
            end
        end

        function s = unitLabel(obj)
            if obj.hasCelsius, s = 'temperature (\circC)'; else, s = 'energy counts (uncalibrated)'; end
        end

        function disp(obj)
            fprintf('ThermalH5: %s\n', obj.path);
            fprintf('  %d frames of %d x %d px, %.4f fps (%.2f h), start %s\n', obj.nFrames, obj.width, obj.height, obj.fps, ...
                obj.time(end) / 3600, string(obj.startTime));
            fprintf('  camera serial %d, FOV %d deg, range %g..%g degC, calibration: %s\n', obj.attrs.serial, obj.attrs.fov_deg, ...
                obj.attrs.range_min, obj.attrs.range_max, ThermalH5.yesno(obj.hasCelsius));
            fprintf('  valid frames: %d / %d\n', nnz(obj.valid), obj.nFrames);
        end
    end

    methods (Static, Access = private)
        function s = readGroup(path, info, name)
            s = struct();
            gi = [];
            for k = 1:numel(info.Groups)
                if strcmp(info.Groups(k).Name, ['/' name]), gi = info.Groups(k); end
            end
            if isempty(gi), return; end
            for k = 1:numel(gi.Datasets)
                v = h5read(path, ['/' name '/' gi.Datasets(k).Name]);
                s.(matlab.lang.makeValidName(gi.Datasets(k).Name)) = double(v(:));
            end
        end

        function s = yesno(b)
            if b, s = 'yes (degC)'; else, s = 'NO - counts only (Kennlinie file missing)'; end
        end
    end
end
