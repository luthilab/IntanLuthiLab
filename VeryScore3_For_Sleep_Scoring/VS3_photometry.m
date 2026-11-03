function varargout = VS3_photometry(action, varargin)
%VS3_PHOTOMETRY Fibre photometry dF/F for VeryScore3 (menu Tools > Photometry).
%
% Turns a recorded photometry channel (the raw, LED-modulated detector output, e.g. ADC1 of an
% Open Ephys acquisition board) into dF/F, with the method worked out in the project
% TestsPhotometry (demod_photometry_AH2_2026-10-01.py and photometry_expfit_AH2_2026-10-01.py):
%
%   1. the carrier of each LED is measured in the channel itself (FFT peak within +-2 Hz of the
%      nominal frequency: 217.38 Hz for the 465 nm signal LED, 322.57 Hz for the purple 405 nm LED)
%   2. quadrature demodulation: the channel is multiplied by cos and sin of the carrier, low-pass
%      filtered (2-s Kaiser FIR, 8 Hz) and decimated to 20 Hz; the amplitude is 2*hypot(I, Q)
%   3. dF/F = 100 * (signal - F0) / F0, with one of two baselines F0, because it depends on the sensor:
%        'purple'       F0 = a * purple + b, the 405 nm channel fitted onto the signal (linear fit
%                       on the data after the first 600 s). Removes bleaching and movement together,
%                       for sensors whose 405 nm response does not depend on the ligand.
%        'exponential'  F0 = a1*exp(-t/tau1) + a2*exp(-t/tau2) + c, a robust (soft-L1) fit of the
%                       signal itself on its 1-Hz means after the first 300 s. The purple channel
%                       is treated the same way and kept as a control (P.dffIso).
%
% The channel is read from the file at its full sampling rate: the traces VeryScore3 displays
% are downsampled to 200 Hz, which removes the carriers.
%
%   [P, ok] = VS3_photometry('analyse', matFile, row, ...)   dialogs, compute, save 'Photometry'
%   P       = VS3_photometry('compute', x, fs, ...)          the computation alone (x in volts;
%                                                             other units: 'volts', false)
%   fig     = VS3_photometry('figure', P, titleText)         overview figure of a result
%
% Options of 'analyse' (name/value):
%   'name'         name of the channel, for the messages (default: traceName of the file)
%   'Fs'           sampling rate of the file (default: Infos.Fs)
%   'method'       'exponential' | 'purple' (default: the last one used, asked when interactive)
%   'fSignal'      nominal carrier of the signal LED, Hz (default 217.38)
%   'fIso'         nominal carrier of the purple LED, Hz (default 322.57; [] = no purple LED)
%   'skipStart'    seconds left out of the fit at the start (default 300 exponential, 600 purple)
%   'save'         true (default): store the result as variable 'Photometry' in the file
%   'blind'        true: the messages do not show the file name (File > Import randomly)
%   'interactive'  true (default) | false: no dialogs (scripts, tests)
%
% Result P (struct, also what is saved; all series are 1 x m at P.fs = 20 Hz):
%   time           seconds since the first sample of the traces
%   dff            dF/F in % with the chosen method
%   signal, iso    carrier amplitudes of the signal and of the purple LED (V)
%   baseline       F0 of the signal;  baselineIso, dffIso, betaIso: the purple control (exponential)
%   method, fit    the method and its fitted parameters (time constants in hours)
%   fSignal, fIso  the measured carriers (Hz);  carrierSNR;  clip (ADC ceiling statistics)
%   channel, channelIndex, params, created
%
% Alejandro Osorio-Forero with Claude, 2026.

switch lower(action)
    case 'analyse'
        [varargout{1:2}] = analyse(varargin{:});
    case 'compute'
        varargout{1} = compute(varargin{:});
    case 'figure'
        varargout{1} = overviewFigure(varargin{:});
    otherwise
        error('VS3_photometry:action', 'Unknown action "%s".', action);
end
end

%% ======================================================================= analyse (file + dialogs)
function [P, ok] = analyse(matFile, row, varargin)
P = [];
ok = false;
o = parseOpts(struct('name', '', 'Fs', [], 'interactive', true, 'method', '', 'fSignal', NaN, ...
    'fIso', NaN, 'skipStart', NaN, 'save', true, 'varName', 'Photometry', 'blind', false), varargin);

m = matfile(matFile);
vars = who(m);
if ~ismember('traces', vars)
    error('VS3_photometry:noTraces', 'The file has no variable "traces" to read the channel from.');
end
sz = size(m, 'traces');
if row < 1 || row > sz(1)
    error('VS3_photometry:row', 'Channel %d does not exist: the file has %d channels.', row, sz(1));
end
Infos = struct();
if ismember('Infos', vars); Infos = m.Infos; end
Fs = o.Fs;
if isempty(Fs) && isfield(Infos, 'Fs')
    Fs = Infos.Fs;
    if ischar(Fs) || isstring(Fs); Fs = str2double(Fs); end
end
if isempty(Fs) || isnan(Fs)
    error('VS3_photometry:noFs', 'The sampling rate of the file is unknown (Infos.Fs).');
end
name = o.name;
if isempty(name)
    name = sprintf('Trace %d', row);
    if ismember('traceName', vars)
        tn = m.traceName;
        if iscell(tn) && numel(tn) >= row; name = char(tn{row}); end
    end
end

% ---- method and parameters: the options given, else the last ones used ----
method = lower(char(o.method));
if isempty(method); method = VS3_pref('get', 'photometryMethod', 'exponential'); end
fS = o.fSignal;
if isscalar(fS) && isnan(fS); fS = VS3_pref('get', 'photometryFSignal', 217.38); end
fI = o.fIso;
if isscalar(fI) && isnan(fI); fI = VS3_pref('get', 'photometryFIso', 322.57); end
skip = o.skipStart;
if o.interactive
    def = 'Exponential decay';
    if strcmp(method, 'purple'); def = 'Purple signal (405 nm)'; end
    an = questdlg(sprintf(['Which baseline F0 for the dF/F of %s? It depends on the sensor.\n\n', ...
        'Purple signal (405 nm): F0 is the purple channel fitted onto the signal. It removes bleaching and ', ...
        'movement together, for sensors whose 405 nm response does not depend on the ligand.\n\n', ...
        'Exponential decay: F0 is a double-exponential bleaching fit of the signal itself. ', ...
        'The purple channel is only kept as a control.'], name), ...
        'Photometry dF/F', 'Purple signal (405 nm)', 'Exponential decay', def);
    if isempty(an); return; end
    if strcmp(an, 'Exponential decay'); method = 'exponential'; else; method = 'purple'; end
    skipDef = skip;
    if isnan(skipDef); skipDef = VS3_pref('get', skipPrefName(method), defaultSkip(method)); end
    isoTxt = '';
    if ~isempty(fI); isoTxt = num2str(fI); end
    prompts = {'Carrier of the signal LED (465 nm), in Hz. The exact frequency is measured within 2 Hz of this value.', ...
        'Carrier of the purple LED (405 nm), in Hz. Leave empty when there is no purple LED.', ...
        'Seconds left out of the fit at the start of the recording (detector settling or clipping).'};
    an = inputdlg(prompts, sprintf('dF/F of %s', name), [1 100], {num2str(fS), isoTxt, num2str(skipDef)});
    if isempty(an); return; end
    fS = str2double(an{1});
    fI = str2double(an{2});
    if isempty(strtrim(an{2})); fI = []; end
    skip = str2double(an{3});
    if isnan(fS) || (~isempty(fI) && isnan(fI)) || isnan(skip) || skip < 0
        errordlg('The carriers must be frequencies in Hz and the skipped time a number of seconds.', 'Photometry');
        return
    end
end

% ---- read the channel at full rate and compute ----
w = [];
if o.interactive
    w = VS3_logo('waitbar', 0, sprintf('Reading %s from the file...', name), 'Name', 'VeryScore3 - photometry');
    set(findall(w, 'Type', 'text'), 'Interpreter', 'none'); % channel names with underscores
end
if isnan(skip); skip = VS3_pref('get', skipPrefName(method), defaultSkip(method)); end
t0 = tic;
try
    x = double(m.traces(row, :)); % int16 or single traces too
    [x, isVolts, inputNote] = toVolts(x, Infos, row);
    P = compute(x, Fs, 'method', method, 'fSignal', fS, 'fIso', fI, 'skipStart', skip, ...
        'volts', isVolts, 'progress', @(f) progress(w, f, name));
catch err
    if ishandle(w); delete(w); end
    P = [];
    if o.interactive && startsWith(err.identifier, 'VS3_photometry:')
        errordlg(err.message, 'Photometry');
        return
    end
    rethrow(err)
end
if ishandle(w); delete(w); end
clear x
P.channel = name;
P.channelIndex = row;
P.inputNote = inputNote;

% ---- save, remember the choices, report ----
saveErr = '';
if o.save
    S = struct();
    S.(o.varName) = P;
    try
        save(matFile, '-struct', 'S', '-append');
    catch err
        saveErr = err.message; % keep the result on screen even if the file cannot be written
    end
end
VS3_pref('set', 'photometryMethod', P.method);
VS3_pref('set', 'photometryFSignal', fS);
VS3_pref('set', 'photometryFIso', fI);
VS3_pref('set', skipPrefName(P.method), P.params.skipStart);
msg = summary(P, toc(t0));
if ~isempty(inputNote); msg = [msg, newline, inputNote]; end
if o.save
    [~, n, e] = fileparts(matFile);
    where = [n, e];
    if o.blind; where = 'the file'; end
    if isempty(saveErr)
        msg = sprintf('%s\n\nStored as the variable ''%s'' in %s. Traces > Reverse gain and filter shows the raw trace again.', msg, o.varName, where);
    else
        msg = sprintf(['%s\n\nWARNING: the result could NOT be stored in %s (%s). It is shown until you close ', ...
            'the file; check that the file is not read-only and compute it again.'], msg, where, saveErr);
    end
end
if o.interactive
    msgbox(msg, 'VeryScore3 - photometry');
else
    fprintf('%s\n', msg);
end
ok = true;
end

function s = defaultSkip(method)
if strcmp(method, 'purple'); s = 600; else; s = 300; end
end

function n = skipPrefName(method)
% the skipped time is remembered per method (defaults 300 s and 600 s)
if strcmp(method, 'purple'); n = 'photometrySkipPurple'; else; n = 'photometrySkipExponential'; end
end

function progress(w, f, name)
if ~isempty(w) && ishandle(w)
    waitbar(f, w, sprintf('Demodulating %s: %.0f %%', name, 100 * f));
end
end

function [x, isVolts, note] = toVolts(x, Infos, row)
% the computation expects volts; files of ToVS2_2026 say which unit they are in. Its versions before
% 2026-09-17 (they wrote no field ChannelUnits) took every channel for microvolts per bit, which
% left the ADC and AUX inputs, whose bit_volts are in volts, a million times too small: corrected here.
isVolts = false;
note = '';
u = '';
if isfield(Infos, 'Unit'); u = lower(strtrim(char(Infos.Unit))); end
bv = NaN;
if isfield(Infos, 'BitVolts')
    b = Infos.BitVolts;
    if ischar(b) || isstring(b); b = sscanf(strrep(char(b), ',', ' '), '%f')'; end   % numbers become text in Edit file Infos
    if isnumeric(b) && numel(b) >= row; bv = b(row); elseif isnumeric(b) && isscalar(b); bv = b; end
end
known = false;                                   % does the file say the unit of this channel?
inVolts = false;                                 % bit_volts of this channel in volts (ADC, AUX), not microvolts
if isfield(Infos, 'ChannelUnits')
    cu = strtrim(strsplit(char(Infos.ChannelUnits), ','));
    if numel(cu) >= row
        known = true;
        inVolts = strcmpi(cu{row}, 'V');
    end
end
if ~known && ~isnan(bv); inVolts = bv < 0.01; end  % 0.195 for headstage channels, 0.00015 for ADC inputs
if startsWith(u, 'raw')
    if ~isnan(bv)
        f = 1e-6;
        if inVolts; f = 1; end
        x = x * 1000 * bv * f;
        isVolts = true;
    end
elseif startsWith(u, 'uv') || startsWith(u, 'v')
    if startsWith(u, 'uv'); x = x * 1e-6; end
    isVolts = true;
    if ~known && inVolts
        x = x * 1e6;
        note = ['This file was made by an early version of the converter, which stored this channel ', ...
            'a million times too small. The values were corrected before the computation.'];
    end
end
end

function msg = summary(P, sec)
msg = sprintf('dF/F of %s computed in %.0f s, baseline: %s.\n\n', P.channel, sec, methodText(P.method));
msg = [msg, sprintf('Carrier of the signal LED: %.3f Hz\n', P.fSignal)];
if ~isempty(P.fIso)
    msg = [msg, sprintf('Carrier of the purple LED: %.3f Hz\n', P.fIso)];
else
    msg = [msg, sprintf('No purple LED carrier found: no control channel.\n')];
end
if strcmp(P.method, 'exponential')
    msg = [msg, sprintf('Bleaching time constants: %s and %s\n', hoursText(P.fit.pSignal(2)), hoursText(P.fit.pSignal(4)))];
    if isfield(P.fit, 'atBound') && P.fit.atBound
        msg = [msg, sprintf(['WARNING: a time constant of the bleaching fit sits at its limit (%s): the fit is poorly ', ...
            'constrained (transient, short recording?). Check the overview figure; the dF/F before %.0f s is an ', ...
            'extrapolation.\n'], P.fit.boundNote, P.params.skipStart)];
    end
else
    msg = [msg, sprintf('Fit: signal = %.4f x purple + %.4f V (correlation %.3f)\n', P.fit.a, P.fit.b, P.fit.corr)];
end
sel = P.time > P.params.skipStart;
msg = [msg, sprintf('Signal amplitude: %.3f V at the start, %.3f V at the end\n', mean(P.signal(1:min(end, 1200))), mean(P.signal(max(1, end - 1199):end)))];
msg = [msg, sprintf('Standard deviation of the dF/F: %.2f %%', std(P.dff(sel)))];
if P.clip.fraction > 0 && ~isnan(P.clip.lastTime)
    if P.clip.lastTime <= P.params.skipStart
        msg = [msg, sprintf('\nThe detector touched the ADC ceiling until %.0f s, inside the %.0f s left out of the fit.', P.clip.lastTime, P.params.skipStart)];
    else
        msg = [msg, sprintf(['\nWARNING: the detector touched the ADC ceiling (%.2f V) as late as %.0f s, after the %.0f s ', ...
            'left out of the fit. The dF/F is not valid around the clipped samples.'], P.clip.ceiling, P.clip.lastTime, P.params.skipStart)];
    end
end
end

function s = methodText(method)
if strcmp(method, 'purple')
    s = 'purple signal (405 nm fitted onto the signal)';
else
    s = 'exponential decay (double exponential of the signal itself)';
end
end

function s = hoursText(h)
if h < 1.5
    s = sprintf('%.0f min', h * 60);
else
    s = sprintf('%.1f h', h);
end
end

%% ======================================================================= compute
function P = compute(x, fs, varargin)
o = parseOpts(struct('method', 'exponential', 'fSignal', 217.38, 'fIso', 322.57, 'searchHz', 2, ...
    'lowpassHz', 8, 'filterSeconds', 2, 'kaiserBeta', 9, 'fsOut', 20, 'trim', 3, 'skipStart', NaN, ...
    'fScale', [], 'volts', true, 'ceiling', 4.5903, 'progress', []), varargin);
method = lower(char(o.method));
if startsWith(method, 'exp')
    method = 'exponential';
elseif any(strcmp(method, {'purple', '405', 'iso', 'isosbestic', 'violet'}))
    method = 'purple';
else
    error('VS3_photometry:method', 'Unknown method "%s": use ''exponential'' or ''purple''.', o.method);
end
if isnan(o.skipStart); o.skipStart = defaultSkip(method); end
x = double(x(:));
N = numel(x);
minFit = 120;
if strcmp(method, 'exponential'); minFit = 1200; end    % a double exponential needs a long stretch
if N / fs < o.skipStart + minFit
    error('VS3_photometry:tooShort', ['The recording lasts %.0f s: too short for the %s baseline, which needs at ', ...
        'least %.0f s after the first %.0f s left out.%s'], N / fs, method, minFit, o.skipStart, ...
        repmat(' Try the purple-signal baseline.', 1, strcmp(method, 'exponential')));
end
bad = ~isfinite(x);
if any(bad)
    if mean(bad) > 0.001
        error('VS3_photometry:notFinite', '%.2g %% of the samples of this channel are NaN or Inf: cannot demodulate it.', 100 * mean(bad));
    end
    good = find(~bad);
    x(bad) = interp1(good, x(good), find(bad), 'nearest', 'extrap'); % a few missing samples
end
if max(x) - min(x) <= 0
    error('VS3_photometry:flat', 'This channel is constant: no photometry signal.');
end

% ---- is the detector output usable? (ADC ceiling of the Open Ephys board: 4.5903 V) ----
clip = struct('ceiling', NaN, 'fraction', 0, 'lastTime', NaN);
if o.volts && ~isempty(o.ceiling)
    isClip = x >= o.ceiling - 0.0005;
    clip.ceiling = o.ceiling;
else
    mx = max(x);
    isClip = x >= mx - 1e-9 * abs(mx);
    clip.ceiling = mx;
    if nnz(isClip) < 50; isClip(:) = false; end      % a few samples at the maximum are not clipping
end
clip.fraction = mean(isClip);
k = find(isClip, 1, 'last');
if ~isempty(k); clip.lastTime = (k - 1) / fs; end
clear isClip
if clip.fraction > 0.5
    error('VS3_photometry:saturated', ['The detector output is saturated: %.0f %% of the samples sit at the ADC ', ...
        'ceiling (%.4g). No fluorescence can be recovered; lower the detector gain or the LED power.'], ...
        100 * clip.fraction, clip.ceiling);
end

% ---- carriers ----
[f1, snr1, share1, a1] = findCarrier(x, fs, o.fSignal, o.searchHz);
if ~(snr1 >= 20)
    error('VS3_photometry:noCarrier', ['No LED carrier found near %.2f Hz in this channel (the peak is only %.1f times ', ...
        'the background). Is this the photometry channel?'], o.fSignal, snr1);
end
if share1 < 0.02
    % an EEG channel can pick up a trace of the LED modulation: a sharp but minute peak
    error('VS3_photometry:noCarrier', ['The carrier near %.2f Hz holds only %.2g %% of the power of this channel, so this is ', ...
        'not the detector output (probably pickup of the LED modulation). Select the photometry channel.'], o.fSignal, 100 * share1);
end
f2 = [];
snr2 = NaN;
if ~isempty(o.fIso) && ~isnan(o.fIso) && o.fIso + o.searchHz < fs / 2
    [f2, snr2, ~, a2] = findCarrier(x, fs, o.fIso, o.searchHz);
    if ~(snr2 >= 20) || a2 < 0.01 * a1; f2 = []; end
end
if strcmp(method, 'purple') && isempty(f2)
    if isempty(o.fIso) || isnan(o.fIso)
        error('VS3_photometry:noIso', 'The purple-signal baseline needs the carrier frequency of the purple (405 nm) LED.');
    end
    error('VS3_photometry:noIso', ['The purple-signal baseline needs the purple (405 nm) LED, and no carrier was found ', ...
        'near %.2f Hz. Use the exponential decay instead.'], o.fIso);
end

% ---- quadrature demodulation, low-pass and decimation ----
D = max(1, round(fs / o.fsOut));
fo = fs / D;
nT = 2 * round(o.filterSeconds * fs / 2) + 1;            % 2001 taps at 1 kS/s
hfir = kaiserLowpass(nT, o.lowpassHz, fs, o.kaiserBeta);
[sig, iso] = demodulate(x, fs, f1, f2, hfir, D, o.progress);
clear x
t = (0:numel(sig) - 1)' / fo;
k0 = round(o.trim * fo);                                 % the filter needs 1 s at each end
keep = (k0 + 1):(numel(sig) - k0);
sig = sig(keep);
t = t(keep);
if ~isempty(iso); iso = iso(keep); end

% ---- baseline and dF/F ----
fit = struct();
base = []; baseIso = []; dffIso = []; betaIso = NaN;
late = t > o.skipStart;
switch method
    case 'purple'
        pf = polyfit(iso(late), sig(late), 1);
        base = pf(1) * iso + pf(2);
        cc = corrcoef(sig(late), iso(late));
        fit.a = pf(1);
        fit.b = pf(2);
        fit.corr = cc(1, 2);
        fit.note = 'F0 = a * iso + b, fitted on the samples after skipStart';
    case 'exponential'
        fScale = o.fScale;
        if isempty(fScale)
            fScale = 0.003;                               % volts, as in the TestsPhotometry script
            med = median(sig);
            if ~o.volts || med < 0.01 || med > 10; fScale = 0.004 * med; end
        end
        [t1, s1] = blockMeans(t / 3600, sig, floor(fo));
        use = t1 > o.skipStart / 3600;
        if nnz(use) < 60
            error('VS3_photometry:tooShort', 'Not enough data after the first %.0f s for the bleaching fit.', o.skipStart);
        end
        [pS, atB, bNote] = fitDoubleExp(t1(use), s1(use), fScale, o.skipStart);
        base = doubleExp(pS, t / 3600);
        fit.pSignal = pS;
        fit.atBound = atB;
        fit.boundNote = bNote;
        fit.fScale = fScale;
        fit.note = 'F0 = a1*exp(-t/tau1) + a2*exp(-t/tau2) + c, parameters [a1 tau1 a2 tau2 c], t and tau in hours';
        if ~isempty(iso)
            [~, i1] = blockMeans(t / 3600, iso, floor(fo));
            pI = fitDoubleExp(t1(use), i1(use), fScale, o.skipStart);
            baseIso = doubleExp(pI, t / 3600);
            dffIso = (iso - baseIso) ./ baseIso * 100;
            fit.pIso = pI;
        end
end
if any(base <= 0)
    error('VS3_photometry:baseline', 'The fitted baseline F0 reaches zero: the dF/F cannot be computed. Check the channel and the skipped time.');
end
dff = (sig - base) ./ base * 100;
if ~isempty(dffIso)
    pf = polyfit(dffIso(late), dff(late), 1);
    betaIso = pf(1);                                      % dff - betaIso * dffIso regresses the control out
end

% ---- result ----
P = struct();
P.method = method;
P.time = t';
P.fs = fo;
P.dff = dff';
P.signal = sig';
P.iso = iso';
P.baseline = base';
P.baselineIso = baseIso';
P.dffIso = dffIso';
P.betaIso = betaIso;
P.fit = fit;
P.fSignal = f1;
P.fIso = f2;
P.carrierSNR = [snr1, snr2];
P.carrierShare = share1;
P.clip = clip;
P.unit = 'dff in %, signal / iso / baseline in V';
P.params = rmfield(o, 'progress');
P.params.Fs = fs;
P.params.decimation = D;
P.params.nTaps = nT;
P.description = ['VS3_photometry: quadrature demodulation (Kaiser FIR low-pass) of the raw detector channel, ', ...
    'dF/F = 100*(signal - baseline)/baseline, baseline: ', methodText(method)];
P.created = char(string(datetime('now'), 'yyyy-MM-dd HH:mm:ss'));
end

function [fPeak, snr, share, amp] = findCarrier(x, fs, f0, searchHz)
% frequency of the spectral peak within +-searchHz of f0 (600 s from the middle of the recording,
% Hann window, parabolic interpolation of the log magnitude), its height over the background,
% the share of the power of the channel it holds and its amplitude (both slightly underestimated
% when the peak falls between two frequency bins)
N = numel(x);
i0 = floor(N / 2);
L = min(round(600 * fs), N - i0);
s = x(i0 + 1:i0 + L);
s = s - mean(s);
w = 0.5 - 0.5 * cos(2 * pi * (0:L - 1)' / (L - 1));
X = abs(fft(s .* w));
nb = floor(L / 2) + 1;
X = X(1:nb);
f = (0:nb - 1)' * fs / L;
band = f > f0 - searchHz & f < f0 + searchHz;
band([1, nb]) = false;
if ~any(band)
    error('VS3_photometry:noCarrier', 'The carrier %.2f Hz is outside the range of a recording sampled at %g Hz.', f0, fs);
end
[pk, k] = max(X .* band);
if ~(pk > 0)
    fPeak = f0; snr = 0; share = 0; amp = 0;   % nothing in the band: reported as "no carrier"
    return
end
snr = pk / median(X(band));
amp = 2 * pk / sum(w);
share = 0;
if var(s) > 0; share = (amp ^ 2 / 2) / var(s); end
la = log(X(k - 1)); lb = log(X(k)); lc = log(X(k + 1));
fPeak = f(k) + 0.5 * (la - lc) / (la - 2 * lb + lc) * (f(2) - f(1));
end

function h = kaiserLowpass(nT, cutoffHz, fs, beta)
% windowed-sinc low-pass with a Kaiser window, unity gain at 0 Hz (same as scipy.signal.firwin)
alpha = (nT - 1) / 2;
m = (0:nT - 1)' - alpha;
c = cutoffHz / (fs / 2);
h = c * ones(nT, 1);
nz = m ~= 0;
h(nz) = sin(pi * c * m(nz)) ./ (pi * m(nz));
w = besseli(0, beta * sqrt(max(0, 1 - (m / alpha) .^ 2))) / besseli(0, beta);
h = h .* w;
h = h / sum(h);
end

function [amp1, amp2] = demodulate(x, fs, f1, f2, h, D, progressFcn)
% amplitude of the carriers f1 (and f2) of x at fs / D samples per second: the output sample j is
% centred on the input sample D*j (zero phase), zeros are assumed outside the recording
N = numel(x);
nT = numel(h);
M = (nT - 1) / 2;
J = floor(N / D);
amp1 = zeros(J, 1);
amp2 = [];
if ~isempty(f2); amp2 = zeros(J, 1); end
nq = ceil(nT / D);
Hm = reshape([flipud(h(:)); zeros(nq * D - nT, 1)], D, nq)';      % polyphase rows of the filter
chunk = max(100, floor(1e6 / D));                               % 20000 at 1 kS/s
for j0 = 0:chunk:J - 1
    j1 = min(j0 + chunk, J) - 1;
    nj = j1 - j0 + 1;
    n = (D * j0 - M:D * j1 + M)';                                 % input samples needed (0-based)
    seg = zeros(numel(n), 1);
    in = n >= 0 & n <= N - 1;
    seg(in) = x(n(in) + 1);
    tt = n / fs;
    ph = 2 * pi * mod(f1 * tt, 1);
    amp1(j0 + 1:j1 + 1) = 2 * hypot(stridedFilter(seg .* cos(ph), Hm, D, nj), stridedFilter(seg .* sin(ph), Hm, D, nj));
    if ~isempty(f2)
        ph = 2 * pi * mod(f2 * tt, 1);
        amp2(j0 + 1:j1 + 1) = 2 * hypot(stridedFilter(seg .* cos(ph), Hm, D, nj), stridedFilter(seg .* sin(ph), Hm, D, nj));
    end
    if ~isempty(progressFcn); progressFcn((j1 + 1) / J); end
end
end

function y = stridedFilter(v, Hm, D, nj)
% y(m) = sum_i hflipped(i) * v(D*m + i): FIR filtering and decimation in one step
nq = size(Hm, 1);
nb = nj + nq - 1;
vp = zeros(nb * D, 1);
vp(1:numel(v)) = v;
Z = Hm * reshape(vp, D, nb);
y = zeros(nj, 1);
for q = 0:nq - 1
    y = y + Z(q + 1, (1:nj) + q).';
end
end

function [tb, yb] = blockMeans(t, y, ds)
L = floor(numel(y) / ds) * ds;
tb = mean(reshape(t(1:L), ds, []), 1)';
yb = mean(reshape(y(1:L), ds, []), 1)';
end

function y = doubleExp(p, t)
y = p(1) * exp(-t / p(2)) + p(3) * exp(-t / p(4)) + p(5);
end

function [p, atBound, note] = fitDoubleExp(t, y, fScale, skipStart)
% robust (soft-L1 loss, scale fScale) fit of a1*exp(-t/tau1) + a2*exp(-t/tau2) + c with
% a1, a2, c >= 0, tau1 in [0.01 3] h and tau2 in [0.5 500] h: the same problem as the scipy
% least_squares call of the TestsPhotometry script. The amplitudes are solved exactly for each
% pair of time constants (non-negative weighted least squares), the time constants by a simplex
% search from several starting points. VeryScore3: tau1 is at least a third of the time left out
% at the start (a faster component cannot be measured after it, and its extrapolation to the start
% explodes); atBound says whether a time constant ended on a limit.
if nargin < 4; skipStart = 0; end
lo = [max(0.01, skipStart / 3 / 3600), 0.5];
hi = [3, 500];
starts = [0.4, 8; 0.1, 2; 1, 20; 2.5, 100; 0.05, 0.8];
opts = optimset('TolX', 1e-7, 'TolFun', 1e-13, 'MaxFunEvals', 3000, 'MaxIter', 3000, 'Display', 'off');
best = Inf;
ub = log(starts(1, :));
for s = 1:size(starts, 1)
    [u, c] = fminsearch(@(u) expCost(u, t, y, fScale, lo, hi), log(starts(s, :)), opts);
    if c < best
        best = c;
        ub = u;
    end
end
tau = min(max(exp(ub), lo), hi);
[~, a] = expCost(log(tau), t, y, fScale, lo, hi);
p = [a(1), tau(1), a(2), tau(2), a(3)];
names = {'fast', 'slow'};
lim = abs(log(tau ./ lo)) < 1e-3 | abs(log(tau ./ hi)) < 1e-3;
lim = lim & a(1:2)' > 0.05 * median(y);   % a limit only matters for a component that weighs
atBound = any(lim);
note = strjoin(arrayfun(@(i) sprintf('%s %s', names{i}, hoursText(tau(i))), find(lim), 'UniformOutput', false), ', ');
end

function [c, a] = expCost(u, t, y, fScale, lo, hi)
tau = min(max(exp(u), lo), hi);
A = [exp(-t / tau(1)), exp(-t / tau(2)), ones(size(t))];
w = ones(size(y));
a = zeros(3, 1);
for it = 1:60                                             % iteratively reweighted least squares
    Aw = A .* w;
    aNew = nnls3(A' * Aw, Aw' * y);
    r = A * aNew - y;
    w = 1 ./ sqrt(1 + (r / fScale) .^ 2);
    done = max(abs(aNew - a)) <= 1e-12 * max(1, max(abs(aNew)));
    a = aNew;
    if done; break; end
end
r = A * a - y;
c = mean(sqrt(1 + (r / fScale) .^ 2) - 1);
c = c * (1 + sum((u - log(tau)) .^ 2));                   % keeps the search inside the bounds
end

function a = nnls3(G, g)
% minimise 0.5*a'*G*a - g'*a over a >= 0 for three unknowns, by trying every set of free variables
sets = {[], 1, 2, 3, [1 2], [1 3], [2 3], [1 2 3]};
best = Inf;
a = zeros(3, 1);
for s = 1:numel(sets)
    S = sets{s};
    p = zeros(3, 1);
    if ~isempty(S)
        GS = G(S, S);
        if rcond(GS) < 1e-14; continue; end
        p(S) = GS \ g(S);
        if any(p(S) < 0); continue; end
    end
    obj = 0.5 * (p' * G * p) - g' * p;
    if obj < best
        best = obj;
        a = p;
    end
end
end

%% ======================================================================= overview figure
function fig = overviewFigure(P, ttl)
if nargin < 2; ttl = ''; end
ds = max(1, floor(P.fs));
b1 = @(v) mean(reshape(v(1:floor(numel(v) / ds) * ds), ds, []), 1);
th = b1(P.time) / 3600;
cS = [0.06 0.46 0.43];
cI = [0.76 0.25 0.05];
hasIso = ~isempty(P.iso);
showCtl = strcmp(P.method, 'exponential') && ~isempty(P.dffIso);
nAx = 2 + showCtl;
fig = figure('Color', 'w', 'Name', 'Photometry dF/F', 'NumberTitle', 'off');
ax = gobjects(nAx, 1);

ax(1) = subplot(nAx, 1, 1);
plot(th, b1(P.signal), 'Color', cS); hold on
leg = {sprintf('signal LED, carrier %.2f Hz', P.fSignal)};
if hasIso
    plot(th, b1(P.iso), 'Color', cI);
    leg{end + 1} = sprintf('purple LED, carrier %.2f Hz', P.fIso);
end
plot(th, b1(P.baseline), 'k', 'LineWidth', 1.2);
leg{end + 1} = 'baseline F0 of the signal';
if ~isempty(P.baselineIso)
    plot(th, b1(P.baselineIso), '--', 'Color', [.4 .4 .4], 'LineWidth', 1.2);
    leg{end + 1} = 'double exponential of the purple channel';
end
ylabel('carrier amplitude (V)'); legend(leg, 'Location', 'best', 'Box', 'off'); grid on
if strcmp(P.method, 'exponential')
    title(sprintf('%s   demodulated channels, bleaching time constants %s and %s', ttl, hoursText(P.fit.pSignal(2)), hoursText(P.fit.pSignal(4))), 'Interpreter', 'none');
else
    title(sprintf('%s   demodulated channels, F0 = %.3f x purple + %.3f V', ttl, P.fit.a, P.fit.b), 'Interpreter', 'none');
end

ax(2) = subplot(nAx, 1, 2);
plot(th, b1(P.dff), 'Color', cS); hold on
plot(th([1 end]), [0 0], 'Color', [.5 .5 .5]);
ylabel('dF/F (%)'); grid on
title(['dF/F of the signal, baseline: ', methodText(P.method)], 'Interpreter', 'none');

if showCtl
    ax(3) = subplot(nAx, 1, 3);
    plot(th, b1(P.dffIso), 'Color', cI); hold on
    plot(th([1 end]), [0 0], 'Color', [.5 .5 .5]);
    ylabel('dF/F (%)'); grid on
    title('purple (405 nm) channel against its own double exponential, as a control');
end
xlabel(ax(end), 'time since the start of the recording (h)');
linkaxes(ax, 'x');
xlim(ax(1), [0, th(end)]);
set(ax, 'TickDir', 'out', 'Box', 'off');
end

%% ======================================================================= helpers
function o = parseOpts(o, args)
if mod(numel(args), 2) ~= 0
    error('VS3_photometry:options', 'Options must be name/value pairs.');
end
for k = 1:2:numel(args)
    name = args{k};
    if ~isfield(o, name)
        error('VS3_photometry:options', 'Unknown option "%s".', name);
    end
    o.(name) = args{k + 1};
end
end
