function out = VS3_fileHistory(action, kind, p, varargin)
%VS3_FILEHISTORY Folder in which each open dialog starts, remembered per kind of file.
%
%   folder = VS3_fileHistory('get', kind, default)     last folder used for this kind of file (with
%            a file separator at the end, ready for uigetfile), else the most recent folder of any
%            kind, else default, else the current folder
%   VS3_fileHistory('remember', kind, file)            the folder of this file
%   VS3_fileHistory('remember', kind, folder, 'Mode', 'folder')
%
% kind is a free name: 'eegMat', 'eegFolder', 'piVideo', 'thermalVideo', 'sensor', 'timingFolder',
% 'calibration', ... Cancelling a dialog changes nothing. Stored in the preferences of VeryScore3
% (VS3_pref 'fileHistory'), so it survives MATLAB restarts. Option 'State' (a struct instead of the
% preferences, returned by 'remember') for tests.
%
% After the folder memory of Wenjie (VeryScore3, October 2026).

o = struct('State', [], 'Mode', 'file');
for k = 1:2:numel(varargin); o.(varargin{k}) = varargin{k+1}; end
persist = isempty(o.State);
if persist; S = VS3_pref('get', 'fileHistory', struct()); else; S = o.State; end
if ~isstruct(S) || ~isscalar(S); S = struct(); end
if ~isfield(S, 'byKind') || ~isstruct(S.byKind); S.byKind = struct(); end
if ~isfield(S, 'recent') || ~iscell(S.recent); S.recent = {}; end
kind = matlab.lang.makeValidName(char(kind));

switch lower(action)
    case 'get'
        if nargin < 3; p = ''; end
        candidates = S.recent(:)';
        if isfield(S.byKind, kind); candidates = [{S.byKind.(kind)}, candidates]; end
        candidates = [candidates, {p, pwd}];
        for k = 1:numel(candidates)
            f = candidates{k};
            if (ischar(f) || isstring(f)) && ~isempty(f) && isfolder(f)
                out = fullfile(char(f), filesep);
                return
            end
        end
        out = fullfile(pwd, filesep);
    case 'remember'
        out = S;
        if ~(ischar(p) || isstring(p)) || isempty(p); return; end
        p = char(p);
        if strcmpi(o.Mode, 'folder')
            f = p;
        else
            f = fileparts(p);
        end
        if ~isfolder(f); return; end
        [ok, a] = fileattrib(f);
        if ok; f = a.Name; end
        S.byKind.(kind) = f;
        S.recent = [{f}, S.recent(~strcmpi(S.recent, f))];
        S.recent = S.recent(1:min(end, 16));
        out = S;
        if persist; VS3_pref('set', 'fileHistory', S); end
    otherwise
        error('VS3_fileHistory:action', 'Unknown action "%s".', action);
end
end
