function out = VS3_sensorTool(action, varargin)
%VS3_SENSORTOOL H5 metadata, explicit clock alignment and 4-s candidate spectra.
switch action
    case 'read'
        path = varargin{1};
        if ~strcmp(h5readatt(path,'/','schema'),'VS3_sensor_v1') || h5readatt(path,'/','complete')~=1
            error('VS3:sensorSchema','Not a completed VeryScore sensor H5.');
        end
        out = struct('source',path,'startPosix',double(h5readatt(path,'/','start_posix')), ...
            'time',double(h5read(path,'/samples/time_s')));
        out.time = out.time(:);
        if isempty(out.time) || any(~isfinite(out.time)) || any(diff(out.time)<=0) || ~isfinite(out.startPosix)
            error('VS3:sensorSchema','Invalid sensor time axis.');
        end
        for name = {'raw_adc','rate_hz','quality','segment','source_id'}
            info = h5info(path,['/samples/' name{1}]);
            if prod(info.Dataspace.Size)~=numel(out.time)
                error('VS3:sensorSchema','Sensor arrays have different lengths.');
            end
        end
    case 'offset'
        sensorStart = varargin{1}; I = varargin{2};
        if isfield(I,'StartTimePosix') && isnumeric(I.StartTimePosix) && isscalar(I.StartTimePosix) && isfinite(I.StartTimePosix)
            eegStart = I.StartTimePosix;
        elseif isfield(I,'StartTime') && isa(I.StartTime,'datetime') && ~isempty(I.StartTime.TimeZone) && isscalar(I.StartTime) && ~isnat(I.StartTime)
            eegStart = posixtime(I.StartTime);
        else
            error('VS3:sensorClock','An unambiguous EEG start time is required (Infos.StartTimePosix or timezone-aware datetime).');
        end
        out = sensorStart-eegStart; % positive: sensor starts AFTER EEG
    case 'spectrum'
        out = spectrum(varargin{:});
    case 'epoch'
        out = epoch(varargin{:});
    case 'timeline'
        out = timeline(varargin{:});
    otherwise
        error('VS3:sensorAction','Unknown action: %s',action);
end
end

function T = timeline(S,offset,bands,epochs,provider,channels,progress)
if nargin<7; progress=@(~,~) true; end
epochs=epochs(:); n=numel(epochs); nc=numel(channels);
% Read the small sensor arrays once per overview, avoiding thousands of H5 opens.
S.cached=struct();
for name={'raw_adc','quality','rate_hz','segment'}
    S.cached.(name{1})=h5read(S.source,['/samples/' name{1}]);
end
T=struct('time',(epochs-.5)*4,'epochs',epochs, ...
    'sensorFrequency',nan(n,2),'sensorAmplitude',nan(n,2),'sensorHarmonic',false(n,1), ...
    'recordedFrequency',nan(n,2,nc),'recordedAmplitude',nan(n,2,nc), ...
    'recordedHarmonic',false(n,nc),'reason',{cell(n,1)},'cancelled',false);
for k=1:n
    if ~progress(k,n); T.cancelled=true; return; end
    E=epoch(S,offset,epochs(k),bands);
    T.reason{k}=E.reason;
    if E.valid
        T.sensorFrequency(k,:)=E.spectrum.frequency;
        T.sensorAmplitude(k,:)=E.spectrum.amplitude;
        T.sensorHarmonic(k)=E.spectrum.harmonic;
    end
    for ch=1:nc
        if iscell(channels); key=channels{ch}; else; key=channels(ch); end
        try
            [x,fs]=provider(key,epochs(k));
            if numel(x)~=round(4*fs); continue; end
            R=spectrum(x,fs,bands);
            T.recordedFrequency(k,:,ch)=R.frequency;
            T.recordedAmplitude(k,:,ch)=R.amplitude;
            T.recordedHarmonic(k,ch)=R.harmonic;
        catch err
            if ~strcmp(err.identifier,'VS3:sensorEmg'); rethrow(err); end
        end
    end
end
end

function R = spectrum(x, fs, bands)
validateattributes(fs,{'numeric'},{'scalar','finite','positive'});
validateattributes(bands,{'numeric'},{'size',[2 2],'finite','positive'});
if any(bands(:,1)>=bands(:,2)) || any(bands(:)>=fs/2)
    error('VS3:sensorBand','Bands must increase and lie below Nyquist.');
end
x = double(x(:)); n = numel(x);
R = struct('f',(0:floor(n/2))'*fs/max(n,1),'a',nan(floor(n/2)+1,1), ...
    'frequency',[NaN NaN],'amplitude',[NaN NaN],'period',[NaN NaN], ...
    'candidates',{{[],[]}},'resolution',fs/max(n,1),'harmonic',false);
if n<4 || any(~isfinite(x)); return; end
x = x-mean(x);
w = hann(n,'periodic');
a = abs(fft(x.*w))/sum(w); a = a(1:floor(n/2)+1);
if rem(n,2)==0; a(2:end-1)=2*a(2:end-1); else; a(2:end)=2*a(2:end); end
R.a = a;
if max(abs(x))<=eps(max(1,max(abs(x)))); return; end
% Local maxima, not the rising edge of an out-of-band peak. Retain alternatives.
peaks = find(a(2:end-1)>a(1:end-2) & a(2:end-1)>=a(3:end))+1;
peaks = peaks(a(peaks)>max(a)*1e-8);
for k=1:2
    idx = peaks(R.f(peaks)>=bands(k,1) & R.f(peaks)<=bands(k,2));
    [~,order] = sort(a(idx),'descend'); idx=idx(order);
    R.candidates{k} = [R.f(idx) a(idx)];
    if ~isempty(idx)
        R.frequency(k)=R.f(idx(1)); R.amplitude(k)=a(idx(1));
        R.period(k)=1/R.frequency(k);
    end
end
if all(isfinite(R.frequency))
    multiple = round(R.frequency(2)/R.frequency(1));
    R.harmonic = multiple>=2 && abs(R.frequency(2)-multiple*R.frequency(1))<=R.resolution;
end
end

function E = epoch(S, offset, ep, bands)
validateattributes(offset,{'numeric'},{'scalar','finite'});
validateattributes(ep,{'numeric'},{'scalar','integer','positive'});
left=(ep-1)*4-offset; right=left+4;
E = struct('valid',false,'reason','No sensor coverage','time',[], 'raw',[], 'filtered',[], ...
    'spectrum',spectrum(nan(800,1),200,bands),'fs',NaN);
i = timeRange(S.time,left,right);
if isempty(i); return; end
first=i(1); last=i(end);
raw = double(readSamples(S,'raw_adc',first,numel(i)));
q = readSamples(S,'quality',first,numel(i));
rates = double(readSamples(S,'rate_hz',first,numel(i)));
seg = readSamples(S,'segment',first,numel(i));
E.time=S.time(i)+offset; E.raw=raw(:); E.fs=rates(1);
% Break display lines across missing samples and acquisition segment boundaries.
breaks=[false; diff(S.time(i))>1.5./rates(2:end) | diff(double(seg(:)))~=0];
E.raw(breaks)=NaN;
fs=E.fs;
if any(rates~=fs) || numel(unique(seg))~=1
    E.reason='Sampling-rate or segment boundary'; return
end
if S.time(first)-left>1.01/fs || right-S.time(last)>1.01/fs || any(diff(S.time(i))>1.5/fs) || any(diff(S.time(i))<.5/fs) || abs(numel(i)-4*fs)>1
    E.reason='Incomplete epoch or timing gap'; return
end
if any(q~=0)
    E.reason='Flagged samples: clipping / step / timing / warmup / demo'; return
end
% Filter with two seconds of surrounding context from this SAME valid segment.
context=timeRange(S.time,left-2,right+2);
cfirst=context(1); count=numel(context);
craw=double(readSamples(S,'raw_adc',cfirst,count));
cq=readSamples(S,'quality',cfirst,count);
cseg=readSamples(S,'segment',cfirst,count);
crates=double(readSamples(S,'rate_hz',cfirst,count));
ok=cq==0 & cseg==seg(1) & crates==fs;
lo=first-cfirst+1; hi=last-cfirst+1;
badBefore=find(~ok(1:lo),1,'last'); if isempty(badBefore); badBefore=0; end
badAfter=find(~ok(hi:end),1); if isempty(badAfter); badAfter=numel(ok)-hi+2; end
loContext=badBefore+1; hiContext=hi+badAfter-2;
if lo-loContext<round(.5*fs) || hiContext-hi<round(.5*fs)
    E.reason='Insufficient valid filter context at a boundary'; return
end
tx=S.time(cfirst+loContext-1:cfirst+hiContext-1);
if any(diff(tx)>1.5/fs) || any(diff(tx)<.5/fs)
    E.reason='Gap inside filter context'; return
end
% Only correct sub-sample acquisition jitter; missing samples were rejected above.
grid=(left:1/fs:right-1/fs)';
uniform=(tx(1):1/fs:tx(end))';
xx=interp1(tx,craw(loContext:hiContext),uniform,'linear');
xx=xx-mean(xx);
[b,a]=butter(4,20/(fs/2),'low'); yy=filtfilt(b,a,xx);
E.filtered=interp1(uniform,yy,grid,'linear',NaN);
if any(~isfinite(E.filtered)); E.reason='Incomplete filter coverage'; return; end
E.time=grid+offset;
E.raw=interp1(tx,craw(loContext:hiContext),grid,'linear',NaN);
E.spectrum=spectrum(E.filtered,fs,bands);
E.valid=true; E.reason='';
end

function indices=timeRange(time,left,right)
indices=(lowerBound(time,left):lowerBound(time,right)-1)';
end

function values=readSamples(S,name,first,count)
if isfield(S,'cached')
    values=S.cached.(name)(first:first+count-1); values=values(:);
else
    values=h5read(S.source,['/samples/' name],first,count);
end
end

function index=lowerBound(time,value)
lo=1; hi=numel(time)+1;
while lo<hi
    middle=floor((lo+hi)/2);
    if time(middle)<value; lo=middle+1; else; hi=middle; end
end
index=lo;
end
