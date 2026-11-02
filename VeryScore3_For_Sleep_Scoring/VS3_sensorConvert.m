function target = VS3_sensorConvert(files, target, report)
%VS3_SENSORCONVERT Explicitly selected Pi CSV/CSV.GZ files -> one lossless H5.
% No folder recursion, source edits, deduplication, gap filling or overwriting.
% VS3_sensorConvert({'recording_PWM.csv'}, 'recording_sensor.h5')
% report (optional): @(fraction) called after each block of rows read (a progress bar).
% Quality bits: 1 clipped, 2 step >800 ADC, 4 timing, 8 warmup, 16 demo.
% UTC anchors come from CSV logging time; monotonic elapsed time preserves gaps.
files = cellstr(files);
if nargin < 3; report = []; end
if isempty(files); error('VS3:sensorInput','Select at least one CSV file.'); end
if isfile(target); error('VS3:sensorExists','Output already exists: %s',target); end
if numel(unique(files)) ~= numel(files)
    error('VS3:sensorOverlap','The same input was selected more than once.');
end
[parent,~,~] = fileparts(target);
if isempty(parent); parent = pwd; end
if ~isfolder(parent); error('VS3:sensorInput','Output folder does not exist.'); end
scratch = tempname(parent); mkdir(scratch);
cleaner = onCleanup(@() rmdir(scratch,'s')); %#ok<NASGU>
partial = fullfile(scratch,'sensor.h5');
names = {'time_s','raw_adc','rate_hz','segment','quality','source_id','native_ns','sample_index','native_time_valid'};
types = {'double','uint16','double','uint32','uint8','uint32','int64','uint64','uint8'};
for k=1:numel(names)
    h5create(partial,['/samples/' names{k}],Inf,'Datatype',types{k},'ChunkSize',65536,'Deflate',4);
end
n = 0; startPosix = []; previousTime = -Inf; previousRaw = NaN;
segmentBase = 0; events = {}; provenance = cell(size(files)); timingSources=cell(size(files));
for source = 1:numel(files)
    input = files{source};
    if ~isfile(input); error('VS3:sensorInput','File not found: %s',input); end
    sourceInfo = dir(input);
    provenance{source} = struct('path',input,'bytes',sourceInfo.bytes);
    metaPath=regexprep(input,'(?i)\.csv(?:\.gz)?$','.metadata.json'); metadata=[];
    if isfile(metaPath)
        metadata=VS3_videoTiming('json',metaPath);
        if isfield(metadata,'schema_version') && metadata.schema_version==2 && ...
                (~isfield(metadata,'closed') || ~metadata.closed)
            error('VS3:sensorInput','Select a finalized sensor session; acquisition is not closed.');
        end
    end
    timingSources{source}=struct('source_id',source,'metadata',metadata,'session','','first_row',n+1,'last_row',n);
    if endsWith(lower(input),'.gz')
        expanded = gunzip(input,scratch); input = expanded{1};
    end
    ds = tabularTextDatastore(input,'ReadSize',100000);
    allNames = ds.VariableNames;
    required = {'type','utc','elapsed_s','raw_adc','rate_hz'};
    if ~all(ismember(required,allNames))
        error('VS3:sensorInput','CSV lacks required fields: %s',input);
    end
    numeric = {'elapsed_s','raw_adc','rate_hz','segment_id','near_rail','filter_warmup'};
    formats = repmat({'%q'},size(allNames));
    formats(ismember(allNames,numeric)) = {'%f'};
    ds.TextscanFormats = formats;
    anchor = []; origin = []; previousElapsed = []; maxSegment = 0;
    previousNative=[]; previousIndex=[];
    while hasdata(ds)
        T = read(ds);
        sample = strcmp(string(T.type),'sample');
        if any(~sample)
            events{end+1} = struct('source_id',source,'rows',table2struct(T(~sample,:))); %#ok<AGROW>
        end
        T = T(sample,:);
        if isempty(T); continue; end
        if isempty(anchor)
            anchor = parseUTC(string(T.utc(1)));
            origin = T.elapsed_s(1);
            if isempty(startPosix); startPosix = anchor; end
        end
        x = double(T.raw_adc(:)); fs = double(T.rate_hz(:)); elapsed = double(T.elapsed_s(:));
        if any(~isfinite([x;fs;elapsed])) || any(x<0 | x>4095 | x~=fix(x)) || any(fs<=40)
            error('VS3:sensorInput','Invalid ADC, sample rate or elapsed time in %s.',input);
        end
        time = anchor-startPosix + elapsed-origin;
        if time(1)<=previousTime || any(diff(time)<=0)
            error('VS3:sensorOverlap','Overlapping or non-increasing times; select chronological, non-overlapping inputs.');
        end
        q = zeros(size(x),'uint8');
        rail = x<=5 | x>=4090;
        if ismember('near_rail',allNames); rail = rail | T.near_rail~=0; end
        q(rail) = bitor(q(rail),uint8(1));
        step = abs(diff([previousRaw;x]))>800;
        q(step) = bitor(q(step),uint8(2));
        dt = diff([previousTime;time]);
        timing = dt<.5./fs | dt>1.5./fs;
        if isempty(previousElapsed); timing(1) = false; end
        q(timing) = bitor(q(timing),uint8(4));
        if ismember('filter_warmup',allNames)
            warm = T.filter_warmup~=0; q(warm) = bitor(q(warm),uint8(8));
        end
        if ismember('demo',allNames)
            demo = strcmpi(string(T.demo),'true') | strcmp(string(T.demo),'1');
            q(demo) = bitor(q(demo),uint8(16));
        end
        local = zeros(size(x));
        if ismember('segment_id',allNames); local = T.segment_id; end
        if any(~isfinite(local) | local<0 | local~=fix(local))
            error('VS3:sensorInput','Invalid segment_id.');
        end
        segment = uint32(segmentBase+local);
        maxSegment = max(maxSegment,max(local));
        native=repmat(int64(-1),size(x)); sampleIndex=zeros(size(x),'uint64'); nativeValid=false(size(x));
        if all(ismember({'edge_monotonic_ns','sample_index'},allNames))
            text=string(T.edge_monotonic_ns); indices=string(T.sample_index);
            nativeValid=~ismissing(text) & strlength(text)>0 & ~ismissing(indices) & strlength(indices)>0;
            native(nativeValid)=VS3_videoTiming('ns',text(nativeValid));
            idx=VS3_videoTiming('ns',indices(nativeValid));
            if any(idx<0 | native(nativeValid)<0); error('VS3:sensorInput','Invalid native sensor timestamps or sample indices.'); end
            sampleIndex(nativeValid)=uint64(idx);
        end
        if ismember('session',allNames)
            session=string(T.session);
            if numel(unique(session))~=1 || (strlength(string(timingSources{source}.session))>0 && session(1)~=string(timingSources{source}.session))
                error('VS3:sensorInput','One sensor source must belong to one session.');
            end
            timingSources{source}.session=char(session(1));
            if isstruct(metadata) && isfield(metadata,'session') && session(1)~=string(metadata.session)
                error('VS3:sensorInput','Sensor CSV and acquisition metadata sessions differ.');
            end
        end
        if isstruct(metadata) && isfield(metadata,'schema_version') && metadata.schema_version==2
            if any(~nativeValid)
                error('VS3:sensorInput','Schema-2 sensor samples require original GPIO times and sample indices.');
            end
            if any(diff([previousNative;native])<=0) || any(diff(int64([previousIndex;sampleIndex]))<=0)
                error('VS3:sensorInput','Original sensor timestamps and sample indices must strictly increase within one source.');
            end
            previousNative=native(end); previousIndex=sampleIndex(end);
        end
        values = {time,uint16(x),fs,segment,q,repmat(uint32(source),size(x)),native,sampleIndex,uint8(nativeValid)};
        for k=1:numel(names)
            h5write(partial,['/samples/' names{k}],values{k},n+1,numel(x));
        end
        n = n+numel(x); previousTime = time(end); previousRaw = x(end); previousElapsed = elapsed(end);
        if ~isempty(report); report((source-1+progress(ds))/numel(files)); end
    end
    if isempty(anchor); error('VS3:sensorInput','No samples in %s.',input); end
    segmentBase = segmentBase+maxSegment+1;
    timingSources{source}.last_row=n;
    fprintf('Sensor input %d/%d: %d samples total\n',source,numel(files),n);
end
h5writeatt(partial,'/','schema','VS3_sensor_v1');
h5writeatt(partial,'/','start_posix',startPosix);
h5writeatt(partial,'/','unit','ADC counts');
h5writeatt(partial,'/','quality_bits','1=clipped;2=step>800;4=timing;8=warmup;16=demo');
h5writeatt(partial,'/','clock_anchor','first sample CSV utc (logging clock), with elapsed_s monotonic intervals; clock accuracy not independently verified');
h5writeatt(partial,'/','sources_json',jsonencode(provenance));
h5writeatt(partial,'/','timing_sources_json',jsonencode(timingSources));
payload = unicode2native(jsonencode(events),'UTF-8');
h5create(partial,'/events/json',numel(payload),'Datatype','uint8');
h5write(partial,'/events/json',uint8(payload));
h5writeatt(partial,'/','complete',uint8(1));
% Exclusive check again before publishing the completed file.
if isfile(target); error('VS3:sensorExists','Output appeared while converting.'); end
[ok,msg] = movefile(partial,target);
if ~ok; error('VS3:sensorWrite','%s',msg); end
fprintf('Sensor H5: %d samples, %.3f hours -> %s\n',n,previousTime/3600,target);
end

function t = parseUTC(value)
try
    d = datetime(value,'InputFormat',"yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXX",'TimeZone','UTC');
catch
    d = datetime(value,'InputFormat',"yyyy-MM-dd'T'HH:mm:ssXXX",'TimeZone','UTC');
end
t = posixtime(d);
if ~isfinite(t); error('VS3:sensorClock','Invalid UTC anchor.'); end
end
