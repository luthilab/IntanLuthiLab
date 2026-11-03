function varargout = VS3_autoScoreTool(cmd, varargin)
%VS3_AUTOSCORETOOL Automatic sleep scoring (wake / NREM / REM, 4-s epochs) for VeryScore3.
%
% How it works (version 2, 2026):
%  1. Features of each 4-s epoch, computed on the 200 Hz traces that VeryScore displays:
%     EEG: log power in 0.5-2, 2-4, 4-6, 6-9, 9-12, 12-16, 16-25, 30-45 Hz, total
%     power and theta/delta ratio, for each EEG channel; EMG: high-pass 30 Hz,
%     50/60 Hz notch, log RMS of the epoch and of its noisiest and quietest second,
%     for each EMG channel and, with two EMG channels, for their difference (it
%     cancels the EEG picked up by the neck electrodes). Every feature is
%     normalized within the recording (median / interquartile range), and the two
%     epochs before and after are added as context.
%  2. A linear discriminant model trained on the library of scored recordings gives a
%     first scoring. Library = the recordings shipped with VeryScore3
%     (autoscore/VS3_autoLibrary.mat, never modified by the program) + your own
%     (autoscore/VS3_autoLibrary_local.mat, added with "Add this scoring to the library").
%  3. The muscle tone is bimodal in every recording (awake / asleep): a two-class
%     mixture on the EMG vetoes the first scoring where it contradicts it.
%  4. The model is trained again on the library plus the confident epochs of this
%     recording (and the epochs you already scored in it), three times, so that
%     it adapts to the electrodes, the animal and the amplifier of this recording.
%  5. Epochs with a low probability are left unscored ('b') for review
%     (shift+B jumps to the next one).
% Validated against manual scoring (AO) of 4 x 8 h recordings of 2 mice, each one
% left out of the library in turn: 89.8-92.9 % agreement (kappa 0.82-0.87, REM F1
% 0.87-0.93); with the library from the other mouse only: 82.8-93.5 %. The two human
% scorers (AO vs JF) agreed 87.9-93.0 % on the same recordings. VeryScore1's autoscore: 57-79 %.
%
% Commands
%   [b, R] = VS3_autoScoreTool('score', eeg, emg, b, 'name', value, ...)
%       eeg / emg: 1 or 2 rows each, 200 Hz. b: current scoring (char).
%       Options: 'keepScored' (false) keep the epochs already scored in b and learn from them,
%       'review' (0.6) epochs with max probability below it become 'b' (0 = none),
%       'library' (struct array, default: the library file), 'fs' (200), 'verbose' (true).
%       R: probabilities (nEp x 3, w n r), confidence, number of seeds, etc.
%   F = VS3_autoScoreTool('features', eeg, emg, fs, nEp)
%   VS3_autoScoreTool('addToLibrary', F, b, name, note)  adds (or replaces) one of your recordings
%   lib = VS3_autoScoreTool('library')                shipped + your recordings (field 'shipped')
%   VS3_autoScoreTool('saveLibrary', lib)             saves your recordings of lib (shipped ones are ignored)
%   f = VS3_autoScoreTool('libraryFile')              your library file; ('libraryFile', 'shipped') the other
%   [opts, ok] = VS3_autoScoreTool('dialog', channelNames, nScored, nEpochs, defaults)
%   r = VS3_autoScoreTool('compare', bTruth, bOther)  agreement, kappa, F1 per state
%
% Alejandro Osorio-Forero with Claude, 2026, for VeryScore3 (VeryScore2 by Romain Cardis & Anita Luthi).

switch cmd
    case 'score';        [varargout{1}, varargout{2}] = scoreRecording(varargin{:});
    case 'features';     varargout{1} = epochFeatures(varargin{:});
    case 'addToLibrary'; addToLibrary(varargin{:});
    case 'library';      varargout{1} = loadLibrary();
    case 'saveLibrary';  saveLibrary(varargin{:});
    case 'libraryFile';  varargout{1} = libraryFile(varargin{:});
    case 'dialog';       [varargout{1}, varargout{2}] = optionsDialog(varargin{:});
    case 'compare';      varargout{1} = compareScorings(varargin{:});
    otherwise; error('VS3_autoScoreTool: unknown command %s', cmd);
end
end

%% ------------------------------------------------------------------ scoring
function [b, R] = scoreRecording(eeg, emg, b, varargin)
o = struct('keepScored', false, 'review', 0.6, 'library', [], 'fs', 200, 'verbose', true, 'waitbar', []);
for i = 1:2:numel(varargin); o.(varargin{i}) = varargin{i+1}; end
nEp = numel(b);
nE = size(eeg,1); nM = size(emg,1);
if nE < 1 || nE > 2 || nM < 1 || nM > 2
    error('Select one or two EEG channels and one or two EMG channels.');
end
wb = o.waitbar; progress(wb, 0.05, 'EEG and EMG features');
F = epochFeatures(eeg, emg, o.fs, nEp);
nF = F.nEp; % epochs covered by the traces (normally all of b)
X = context(robustZ(assemble(F, 1:nE, 1:nM)));
st = 'wnr';
bIn = b(:)';
scored = bIn(1:nF) ~= 'b';

% epochs already scored by the user (kept and used as ground truth)
yUser = zeros(nF,1);
if o.keepScored
    bb = mapStates(bIn(1:nF));
    for s = 1:3; yUser(bb==st(s)) = s; end
end

% library of scored recordings with enough channels
progress(wb, 0.25, 'Library model');
lib = o.library;
if isempty(lib); lib = loadLibrary(); end
[XL, yL, wL, names] = libraryMatrix(lib, nE, nM);

% muscle tone: two-class mixture on the most bimodal EMG feature
[pWake, emgSep, emgName] = emgSplit(F);

if ~isempty(yL)
    M = ldaFit(XL, yL, wL);
    P0 = ldaPost(M, X);
    [c0, p0] = max(P0, [], 2);
    seed = p0; seed(c0 < 0.8) = 0;
    if ~isempty(pWake)
        seed(seed==1 & pWake < 0.05) = 0;   % "wake" but the muscle is clearly asleep
        seed(seed>1 & pWake > 0.95) = 0;    % "sleep" but the muscle is clearly active
    end
    method = sprintf('library (%s) + adaptation', strjoin(names, ', '));
else
    seed = unsupervisedSeed(F, pWake, nF);
    method = 'no compatible library: unsupervised (EMG and EEG mixtures) + adaptation';
    XL = zeros(0, size(X,2)); yL = zeros(0,1); wL = zeros(0,1);
end
seed(yUser>0) = yUser(yUser>0);

% adaptation: library + confident epochs of this recording (+ user epochs, weighted more)
for it = 1:3
    progress(wb, 0.4+0.15*it, sprintf('Adapting to this recording (%d/3)', it));
    sel = seed > 0;
    if any(accumarray(seed(sel), 1, [3 1]) < 10)
        if it == 1 && isempty(yL); error('Could not find the three states in this recording (too short?).'); end
        break
    end
    w = ones(sum(sel),1); w(yUser(sel)>0) = 5; w = w/sum(w);
    M = ldaFit([XL; X(sel,:)], [yL; seed(sel)], [wL; w]);
    P = ldaPost(M, X);
    [c, p] = max(P, [], 2);
    seed = p; seed(c < 0.9) = 0; seed(yUser>0) = yUser(yUser>0);
end
if ~exist('P', 'var'); P = P0; [c, p] = max(P, [], 2); end

% output (epochs beyond the traces, if any, are left as they were)
bNew = st(p);
if o.keepScored; bNew(scored) = bIn(scored); end
nRev = 0;
if o.review > 0
    rev = c(:)' < o.review & ~(o.keepScored & scored);
    bNew(rev) = 'b'; nRev = sum(rev);
end
bIn(1:nF) = bNew;
b = reshape(bIn, size(b));
R = struct('prob', P, 'confidence', c, 'states', st, 'method', method, 'nReview', nRev, ...
    'nSeeds', sum(seed>0), 'nUser', sum(yUser>0), 'emgFeature', emgName, 'emgSeparation', emgSep, ...
    'fraction', [mean(p==1), mean(p==2), mean(p==3)]);
progress(wb, 1, 'Done');
if o.verbose
    fprintf('VS3 autoscore: %s\n  EMG wake/sleep split on %s (separation %.1f)\n  W %.1f %%, NREM %.1f %%, REM %.1f %%, %d epochs left for review (p < %.2f)\n', ...
        method, emgName, emgSep, 100*R.fraction, nRev, o.review);
end
end

function progress(wb, x, msg)
if ~isempty(wb) && isvalid(wb); waitbar(x, wb, msg); drawnow; end
end

function seed = unsupervisedSeed(F, pWake, nEp)
% no library: wake from the EMG mixture, NREM/REM from an EEG mixture within sleep
seed = zeros(nEp,1);
if isempty(pWake); error('The EMG is not bimodal and there is no library: cannot score.'); end
seed(pWake > 0.95) = 1;
sleep = pWake < 0.05;
E = [];
for c = 1:numel(F.eeg)
    E = [E, movmean(F.eeg{c}(:,10),3), movmean(F.eeg{c}(:,2),3), movmean(F.eeg{c}(:,1),3)]; %#ok<AGROW>
end
G = gmmFit(E(sleep,:), 2);
[~, rem] = max(G.mu(:,1) - G.mu(:,2)); % higher theta/delta, lower delta
Pr = G.post(:, rem);
idx = find(sleep);
seed(idx(Pr > 0.9)) = 3;
seed(idx(Pr < 0.1)) = 2;
end

%% ----------------------------------------------------------------- features
function F = epochFeatures(eeg, emg, fs, nEp)
% F.eeg{c}: nEp x 10 (log power d1 d2 th0 th al sg be ga, log total, log theta/delta)
% F.emg{c}: nEp x 3 (log RMS >30 Hz of the epoch, of its max and min second); F.emgDiff idem for emg1-emg2
L = 4*fs;
if nargin < 4; nEp = floor(size(eeg,2)/L); end
nEp = min(nEp, floor(min(size(eeg,2), size(emg,2))/L));
bands = [0.5 2; 2 4; 4 6; 6 9; 9 12; 12 16; 16 25; 30 45];
F = struct('eeg', {{}}, 'emg', {{}}, 'emgDiff', [], 'fs', fs, 'nEp', nEp);
win = hann(2*fs);
for c = 1:size(eeg,1)
    Xc = reshape(double(eeg(c,1:nEp*L)), L, nEp);
    Xc = Xc - mean(Xc,1);
    [p, f] = pwelch(Xc, win, fs, 2*fs, fs);
    bp = zeros(nEp, size(bands,1));
    for i = 1:size(bands,1)
        bp(:,i) = sum(p(f>=bands(i,1) & f<bands(i,2), :), 1)';
    end
    tot = sum(p(f>=0.5 & f<=45, :), 1)';
    F.eeg{c} = single([safeLog(bp), safeLog(tot), safeLog(bp(:,4)) - safeLog(bp(:,1)+bp(:,2))]);
end
[bh, ah] = butter(4, 30/(fs/2), 'high');
notches = {};
for f0 = [50 60]
    if f0+2 < fs/2; [bn, an] = butter(2, [f0-2 f0+2]/(fs/2), 'stop'); notches{end+1} = {bn, an}; end %#ok<AGROW>
end
E = double(emg);
if size(E,1) == 2; E = [E; E(1,:) - E(2,:)]; end
for c = 1:size(E,1)
    y = filtfilt(bh, ah, E(c,:));
    for k = 1:numel(notches); y = filtfilt(notches{k}{1}, notches{k}{2}, y); end
    s1 = squeeze(mean(reshape(y(1:nEp*L).^2, fs, 4, nEp), 1)); % 4 x nEp, power of each second
    if nEp == 1; s1 = s1(:); end
    v = single(0.5*[safeLog(mean(s1,1)'), safeLog(max(s1,[],1)'), safeLog(min(s1,[],1)')]);
    if c <= size(emg,1); F.emg{c} = v; else; F.emgDiff = v; end
end
end

function y = safeLog(x)
x = double(x);
pos = x(x>0);
if isempty(pos); y = zeros(size(x)); return; end
y = log(max(x, min(pos)));
end

function A = assemble(F, eegOrder, emgOrder)
% feature matrix in a given channel order (the library is augmented with both orders)
A = [];
for c = eegOrder; A = [A, double(F.eeg{c})]; end %#ok<AGROW>
for c = emgOrder; A = [A, double(F.emg{c})]; end %#ok<AGROW>
if numel(emgOrder) == 2; A = [A, double(F.emgDiff)]; end
end

function Z = robustZ(A)
% per feature: (x - median) / (interquartile range / 1.349)
As = sort(A, 1);
q = @(f) As(max(1, min(size(As,1), round(f*size(As,1)))), :);
med = median(A, 1);
s = (q(0.75) - q(0.25)) / 1.349;
s(s <= 0 | ~isfinite(s)) = 1;
Z = (A - med) ./ s;
Z = max(min(Z, 20), -20); % huge artifacts should not dominate
end

function X = context(Z)
n = size(Z,1); X = Z;
for sh = [-2 -1 1 2]
    X = [X, Z(min(max((1:n)+sh, 1), n), :)]; %#ok<AGROW>
end
end

%% ------------------------------------------------------------------ library
function [XL, yL, wL, names] = libraryMatrix(lib, nE, nM)
% stack the compatible library recordings, both channel orders, each recording weighs the same
XL = []; yL = []; wL = []; names = {};
maxRows = 15000; % per recording, all orders together
rs = RandStream('mt19937ar', 'Seed', 1);
for k = 1:numel(lib)
    e = lib(k);
    if numel(e.eeg) < nE || numel(e.emg) < nM; continue; end
    lab = double(e.y(:)) > 0;
    if sum(lab) < 100; continue; end
    Fk = struct('eeg', {e.eeg}, 'emg', {e.emg}, 'emgDiff', e.emgDiff);
    eo = channelOrders(numel(e.eeg), nE);
    mo = channelOrders(numel(e.emg), nM);
    blocks = {};
    for i = 1:numel(eo)
        for j = 1:numel(mo)
            if nM == 2 && isempty(e.emgDiff); continue; end
            blocks{end+1} = context(robustZ(assemble(Fk, eo{i}, mo{j}))); %#ok<AGROW>
        end
    end
    if isempty(blocks); continue; end
    Xk = vertcat(blocks{:});
    yk = repmat(double(e.y(:)), numel(blocks), 1);
    keep = find(yk > 0);
    if numel(keep) > maxRows; keep = keep(sort(randperm(rs, numel(keep), maxRows))); end
    XL = [XL; Xk(keep,:)]; yL = [yL; yk(keep)]; %#ok<AGROW>
    wL = [wL; ones(numel(keep),1)/numel(keep)]; %#ok<AGROW>
    names{end+1} = e.name; %#ok<AGROW>
end
if ~isempty(wL); wL = wL/sum(wL); end
end

function o = channelOrders(nHave, nNeed)
if nNeed == 2; o = {[1 2], [2 1]};
else; o = num2cell(1:nHave);
end
end

function f = libraryFile(which)
% 'local' (default): your recordings, git-ignored; 'shipped': the recordings that come with VeryScore3
if nargin < 1; which = 'local'; end
d = fullfile(fileparts(mfilename('fullpath')), 'autoscore');
switch which
    case 'shipped'; f = fullfile(d, 'VS3_autoLibrary.mat');
    otherwise
        f = fullfile(d, 'VS3_autoLibrary_local.mat');
        fu = fullfile(prefdir, 'VS3_autoLibrary_local.mat'); % when the VeryScore3 folder is not writable
        if ~exist(f, 'file') && exist(fu, 'file'); f = fu; end
end
end

function lib = loadLibrary()
lib = emptyLibrary();
sources = {libraryFile('shipped'), true; libraryFile('local'), false};
for i = 1:size(sources, 1)
    if ~exist(sources{i,1}, 'file'); continue; end
    S = load(sources{i,1}, 'lib');
    for k = 1:numel(S.lib)
        e = S.lib(k);
        if ~isfield(e, 'note'); e.note = ''; end
        if ~isfield(e, 'added'); e.added = ''; end
        lib(end+1) = struct('name', e.name, 'eeg', {e.eeg}, 'emg', {e.emg}, 'emgDiff', e.emgDiff, 'y', e.y, ...
            'added', e.added, 'note', e.note, 'shipped', sources{i,2}); %#ok<AGROW>
    end
end
end

function lib = emptyLibrary()
lib = struct('name', {}, 'eeg', {}, 'emg', {}, 'emgDiff', {}, 'y', {}, 'added', {}, 'note', {}, 'shipped', {});
end

function saveLibrary(lib)
% only your recordings are saved; the shipped library is never modified
lib = lib(~[lib.shipped]);
lib = rmfield(lib, 'shipped'); %#ok<NASGU>
f = libraryFile('local');
try
    if ~exist(fileparts(f), 'dir'); mkdir(fileparts(f)); end
    save(f, 'lib');
catch
    save(fullfile(prefdir, 'VS3_autoLibrary_local.mat'), 'lib');
end
end

function addToLibrary(F, b, name, note)
if nargin < 4; note = ''; end
st = 'wnr';
b = mapStates(b(:)');
if numel(b) < F.nEp; b(end+1:F.nEp) = 'b'; end
b = b(1:F.nEp);
y = zeros(numel(b), 1, 'uint8');
for s = 1:3; y(b==st(s)) = s; end
if any(accumarray(double(y(y>0)), 1, [3 1]) < 20)
    error('The scoring of %s does not contain enough wake, NREM and REM epochs.', name);
end
lib = loadLibrary();
if any(strcmp({lib([lib.shipped]).name}, name))
    error('%s is one of the recordings shipped with VeryScore3: give the file another name.', name);
end
e = struct('name', name, 'eeg', {F.eeg}, 'emg', {F.emg}, 'emgDiff', F.emgDiff, 'y', y, ...
    'added', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm')), 'note', note, 'shipped', false);
i = find(strcmp({lib.name}, name));
if isempty(i); lib(end+1) = e; else; lib(i(1)) = e; end
saveLibrary(lib);
end

%% ---------------------------------------------------- models (no toolboxes)
function M = ldaFit(X, y, w)
% weighted linear discriminant (class means, pooled within-class covariance, slightly shrunk)
K = 3; p = size(X,2);
M.mu = zeros(K, p);
S = zeros(p);
w = w / sum(w);
for k = 1:K
    i = y == k; wk = w(i) / sum(w(i));
    M.mu(k,:) = wk' * X(i,:);
    Xc = X(i,:) - M.mu(k,:);
    S = S + (Xc .* w(i))' * Xc;
end
lam = 1e-4; % (validated: 0 - 1e-3 equivalent, 0.02 worse)
S = (1-lam)*S + lam*mean(diag(S))*eye(p);
M.R = chol(S);
end

function P = ldaPost(M, X)
ll = zeros(size(X,1), size(M.mu,1));
for k = 1:size(M.mu,1)
    Z = (X - M.mu(k,:)) / M.R;
    ll(:,k) = -0.5*sum(Z.^2, 2);
end
ll = ll - max(ll, [], 2);
P = exp(ll); P = P ./ sum(P, 2);
end

function [pWake, sep, name] = emgSplit(F)
% two-class mixture on the most bimodal EMG RMS (smoothed over 3 epochs)
cand = F.emg; nm = arrayfun(@(i) sprintf('EMG %d', i), 1:numel(F.emg), 'UniformOutput', false);
if ~isempty(F.emgDiff); cand{end+1} = F.emgDiff; nm{end+1} = 'EMG 1-2'; end
sep = -inf; pWake = []; name = '';
for c = 1:numel(cand)
    v = movmean(double(cand{c}(:,1)), 3);
    G = gmmFit(v, 2);
    s = abs(diff(G.mu)) / sqrt(mean(G.var));
    if s > sep
        sep = s; [~, hi] = max(G.mu); pWake = G.post(:, hi); name = nm{c};
    end
end
if sep < 2; pWake = []; name = [name ' (not bimodal, not used)']; end
end

function G = gmmFit(X, K)
% diagonal Gaussian mixture, EM, initialized on quantiles of the first column
n = size(X,1);
[~, o] = sort(X(:,1));
g = zeros(n,1); g(o) = ceil((1:n)'/n*K);
mu = zeros(K, size(X,2)); va = mu; pk = zeros(1,K);
for k = 1:K; mu(k,:) = mean(X(g==k,:),1); va(k,:) = var(X(g==k,:),0,1) + 1e-6; pk(k) = mean(g==k); end
for it = 1:300
    ll = zeros(n, K);
    for k = 1:K
        ll(:,k) = log(pk(k)) - 0.5*sum(log(2*pi*va(k,:))) - 0.5*sum((X - mu(k,:)).^2 ./ va(k,:), 2);
    end
    m = max(ll, [], 2); P = exp(ll - m); P = P ./ sum(P, 2);
    muOld = mu;
    for k = 1:K
        wk = P(:,k); sk = sum(wk);
        mu(k,:) = wk' * X / sk;
        va(k,:) = wk' * (X - mu(k,:)).^2 / sk + 1e-6;
        pk(k) = sk / n;
    end
    if max(abs(mu(:) - muOld(:))) < 1e-6; break; end
end
G = struct('mu', mu, 'var', va, 'p', pk, 'post', P);
if size(X,2) == 1; G.var = va(:)'; end
end

%% ------------------------------------------------------------------ compare
function r = compareScorings(b1, b2)
st = 'wnr';
m = @(b) mapStates(b(:)');
b1 = m(b1); b2 = m(b2); n = min(numel(b1), numel(b2));
b1 = b1(1:n); b2 = b2(1:n);
ok = ismember(b1, st) & ismember(b2, st);
C = zeros(3);
for i = 1:3; for j = 1:3; C(i,j) = sum(b1(ok)==st(i) & b2(ok)==st(j)); end; end
N = sum(C(:)); po = trace(C)/N; pe = sum(sum(C,2) .* sum(C,1)')/N^2;
r = struct('agreement', po, 'kappa', (po-pe)/(1-pe), 'confusion', C, 'nCompared', N);
rec = diag(C)' ./ sum(C,2)'; pre = diag(C)' ./ sum(C,1);
r.F1 = 2*rec.*pre ./ (rec+pre);
end

function b = mapStates(b)
b(b=='1'|b=='m') = 'w'; b(b=='2'|b=='f') = 'n'; b(b=='3') = 'r';
end

%% ------------------------------------------------------------------- dialog
function [opts, ok] = optionsDialog(names, nScored, nEp, d)
% d: defaults struct (eeg, emg, keepScored, review, optional mode = 'library'); names: channel names
ok = false; opts = d;
n = numel(names);
lib = isfield(d, 'mode') && strcmp(d.mode, 'library'); % only the channels (Add this scoring to the library)
fig = figure('Name', 'Auto-scoring', 'NumberTitle', 'off', 'MenuBar', 'none', 'ToolBar', 'none', ...
    'Units', 'pixels', 'Position', [300 200 520 430], 'Resize', 'off', 'WindowStyle', 'modal', 'Color', [.96 .96 .96]);
movegui(fig, 'center');
uicontrol(fig, 'Style', 'text', 'Position', [20 395 480 22], 'HorizontalAlignment', 'left', 'FontWeight', 'bold', ...
    'String', 'Channels (one or two of each, ctrl+click)', 'BackgroundColor', fig.Color);
uicontrol(fig, 'Style', 'text', 'Position', [20 370 230 20], 'HorizontalAlignment', 'left', 'String', 'EEG', 'BackgroundColor', fig.Color);
uicontrol(fig, 'Style', 'text', 'Position', [270 370 230 20], 'HorizontalAlignment', 'left', 'String', 'EMG', 'BackgroundColor', fig.Color);
lbE = uicontrol(fig, 'Style', 'listbox', 'Position', [20 230 230 140], 'String', names, 'Max', n+1, 'Min', 0, 'Value', d.eeg);
lbM = uicontrol(fig, 'Style', 'listbox', 'Position', [270 230 230 140], 'String', names, 'Max', n+1, 'Min', 0, 'Value', d.emg);
if nScored > 0
    txt = sprintf('Keep the %d epochs already scored in this file and learn from them', nScored);
    en = 'on';
else
    txt = 'Keep the epochs already scored (none in this file)'; en = 'off';
end
cbK = uicontrol(fig, 'Style', 'checkbox', 'Position', [20 190 480 22], 'String', txt, 'Value', d.keepScored && nScored > 0, ...
    'Enable', en, 'BackgroundColor', fig.Color);
cbR = uicontrol(fig, 'Style', 'checkbox', 'Position', [20 160 330 22], 'BackgroundColor', fig.Color, ...
    'String', 'Leave uncertain epochs unscored (b) for review, below p =', 'Value', d.review > 0);
edR = uicontrol(fig, 'Style', 'edit', 'Position', [355 160 50 22], 'String', num2str(max(d.review, 0.6)));
info = uicontrol(fig, 'Style', 'text', 'Position', [20 70 480 80], 'HorizontalAlignment', 'left', 'BackgroundColor', fig.Color, ...
    'String', sprintf(['%d epochs. Wake, NREM and REM are scored from EEG spectra and EMG (>30 Hz), with a model ', ...
    'trained on the library of scored recordings and adapted to this recording. Uncertain epochs: shift+B ', ...
    'jumps to the next one. Your current scoring is replaced (except the kept epochs).'], nEp));
btn = uicontrol(fig, 'Style', 'pushbutton', 'Position', [300 20 95 30], 'String', 'Score', 'Callback', @go);
if lib
    fig.Name = 'Add this scoring to the auto-scoring library';
    set([cbK cbR edR], 'Visible', 'off');
    info.String = sprintf(['The %d epochs of this scoring (w / n / r, artifacts counted with their state) and the ', ...
        'features of the selected channels are added to your library (%s). The next auto-scorings learn from them.'], nEp, libraryFile('local'));
    btn.String = 'Add';
end
uicontrol(fig, 'Style', 'pushbutton', 'Position', [405 20 95 30], 'String', 'Cancel', 'Callback', @(~,~) delete(fig));
uiwait(fig);

    function go(~,~)
        e = lbE.Value; m = lbM.Value;
        if isempty(e) || numel(e) > 2 || isempty(m) || numel(m) > 2
            errordlg('Select one or two EEG channels and one or two EMG channels.', 'Auto-scoring', 'modal'); return
        end
        if ~isempty(intersect(e, m))
            errordlg('A channel cannot be both EEG and EMG.', 'Auto-scoring', 'modal'); return
        end
        r = str2double(edR.String);
        if ~cbR.Value || ~isfinite(r); r = 0; end
        opts = struct('eeg', e(:)', 'emg', m(:)', 'keepScored', logical(cbK.Value), 'review', r);
        ok = true;
        delete(fig);
    end
end
