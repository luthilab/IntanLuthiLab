function varargout = VS3_pref(action, name, value)
%VS3_PREF Preferences of VeryScore3 (python.exe, folders, photometry and auto-scoring choices).
%
%   v  = VS3_pref('get', name, default)   value, or default when it was never set
%   VS3_pref('set', name, value)
%   tf = VS3_pref('is', name)
%   VS3_pref('remove', name)
%
% Stored with MATLAB's setpref in the group 'VeryScore3'. A preference that VeryScore2 (v1.6-1.8,
% group 'VeryScore2') already had is taken over the first time it is read, so nothing has to be
% set again after the update.

group = 'VeryScore3';
old = 'VeryScore2';
switch action
    case 'get'
        if ~ispref(group, name) && ispref(old, name)
            setpref(group, name, getpref(old, name));
        end
        if ispref(group, name)
            varargout{1} = getpref(group, name);
        elseif nargin > 2
            varargout{1} = value;
        else
            varargout{1} = [];
        end
    case 'set'
        setpref(group, name, value);
    case 'is'
        varargout{1} = ispref(group, name) || ispref(old, name);
    case 'remove'
        if ispref(group, name); rmpref(group, name); end
        if ispref(old, name); rmpref(old, name); end
    otherwise
        error('VS3_pref:action', 'Unknown action "%s".', action);
end
end
