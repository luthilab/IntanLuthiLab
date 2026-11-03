function varargout = VS3_logo(action, varargin)
%VS3_LOGO The VeryScore3 logo in the program: start screen, progress windows, About window.
%
%   [rgb, alpha] = VS3_logo('image', 'icon' | 'banner')   the picture (images\VS3_icon.png / VS3_banner.png)
%   ax = VS3_logo('show', parent, 'icon' | 'banner', position)   picture in a new axes of parent
%                                                         (position normalized; the aspect ratio is kept)
%   w  = VS3_logo('waitbar', x, message, ...)             MATLAB waitbar with the icon on its left (same
%                                                         arguments as waitbar; update it with waitbar(x, w, msg))
%   VS3_logo('about')                                     About VeryScore3 (credits, version, repository)
%   h  = VS3_logo('start', fig, version)                  start screen of the main window (deleted on import)
%
% The logo was made for VeryScore3 (images\VS3_makeLogo.py). Everything here is decoration: if the
% pictures are missing, the program works the same without them.
%
% Alejandro Osorio-Forero with Claude, 2026, for VeryScore3.

switch lower(action)
    case 'image';   [varargout{1}, varargout{2}] = picture(varargin{:});
    case 'show';    varargout{1} = showPicture(varargin{:});
    case 'waitbar'; varargout{1} = logoWaitbar(varargin{:});
    case 'about';   aboutWindow(varargin{:});
    case 'start';   varargout{1} = startScreen(varargin{:});
    otherwise;      error('VS3_logo:action', 'Unknown action "%s".', action);
end
end

%% ----------------------------------------------------------------------- pictures
function [rgb, alpha] = picture(kind)
persistent cache
if isempty(cache); cache = struct(); end
if ~isfield(cache, kind)
    rgb = []; alpha = [];
    f = fullfile(fileparts(mfilename('fullpath')), 'images', sprintf('VS3_%s.png', kind));
    if isfile(f)
        try
            [rgb, ~, alpha] = imread(f);
        catch
        end
    end
    cache.(kind) = {rgb, alpha};
end
rgb = cache.(kind){1};
alpha = cache.(kind){2};
end

function ax = showPicture(parent, kind, position)
ax = [];
[rgb, alpha] = picture(kind);
if isempty(rgb); return; end
ax = axes('Parent', parent, 'Units', 'normalized', 'Position', position, 'Visible', 'off', ...
    'HandleVisibility', 'off', 'HitTest', 'off', 'PickableParts', 'none');
im = image(ax, rgb, 'HitTest', 'off', 'PickableParts', 'none');
if ~isempty(alpha); im.AlphaData = double(alpha) / 255; end
axis(ax, 'image', 'off');
ax.Tag = 'VS3logo';
end

%% ----------------------------------------------------------------------- progress window
function w = logoWaitbar(x, msg, varargin)
w = waitbar(x, msg, varargin{:});
[rgb, alpha] = picture('icon');
if isempty(rgb); return; end
try
    % room on the left of the bar for the icon
    w.Units = 'pixels';
    p = w.Position;
    pad = 64;
    w.Position = [p(1) - pad / 2, p(2), p(3) + pad, p(4)];
    kids = allchild(w);
    for k = 1:numel(kids)
        if isprop(kids(k), 'Units') && isprop(kids(k), 'Position')
            kids(k).Units = 'pixels';
            kids(k).Position(1) = kids(k).Position(1) + pad;
        end
    end
    s = min(52, p(4) - 12);
    ax = axes('Parent', w, 'Units', 'pixels', 'Position', [10, (p(4) - s) / 2, s, s], 'Visible', 'off', ...
        'HandleVisibility', 'off', 'HitTest', 'off');   % hidden from waitbar's own updates
    im = image(ax, rgb, 'HitTest', 'off');
    if ~isempty(alpha); im.AlphaData = double(alpha) / 255; end
    axis(ax, 'image', 'off');
catch
end
end

%% ----------------------------------------------------------------------- start screen
function hs = startScreen(fig, version)
% the banner in the middle of the empty main window, with what to do first
hs = gobjects(0);
ax = showPicture(fig, 'banner', [.15 .50 .70 .30]);
if ~isempty(ax); hs(end + 1) = ax; end
t = axes('Parent', fig, 'Units', 'normalized', 'Position', [.1 .25 .8 .2], 'Visible', 'off', ...
    'HandleVisibility', 'off', 'HitTest', 'off', 'XLim', [0 1], 'YLim', [0 1]);
text(t, .5, .85, 'File > Import  to open a recording', 'HorizontalAlignment', 'center', 'FontSize', 13, 'Color', [.25 .25 .35]);
text(t, .5, .62, 'File > Convert Open Ephys recording...  for Open Ephys data', 'HorizontalAlignment', 'center', ...
    'FontSize', 11, 'Color', [.4 .4 .5]);
text(t, .5, .25, sprintf(['VeryScore3 v%s  -  the continuation of VeryScore2 by Romain Cardis and Anita L', char(252), 'thi ', ...
    '(L', char(252), 'thi lab, University of Lausanne)  -  Help > About VeryScore3'], version), ...
    'HorizontalAlignment', 'center', 'FontSize', 9, 'Color', [.5 .5 .55]);
hs(end + 1) = t;
end

%% ----------------------------------------------------------------------- About
function aboutWindow(version)
if nargin < 1; version = '3'; end
f = figure('Name', 'About VeryScore3', 'NumberTitle', 'off', 'MenuBar', 'none', 'ToolBar', 'none', ...
    'Color', 'w', 'Resize', 'off', 'Units', 'pixels', 'Position', [300 200 760 470], 'WindowStyle', 'normal');
movegui(f, 'center');
showPicture(f, 'banner', [.02 .66 .96 .32]);
u = char(252);
lines = { ...
    sprintf('VeryScore3  v%s', version), ...
    '', ...
    'Mouse sleep scoring in 4-s epochs, with auto-scoring, thermal video, fibre photometry and Open Ephys.', ...
    '', ...
    sprintf('VeryScore2 (2018-2021): Romain Cardis and Anita L%sthi, L%sthi lab, Department of Fundamental', u, u), ...
    'Neurosciences, University of Lausanne; updates by Georgios Foustoukos (2023-2024).', ...
    'VeryScore3 (2026): Alejandro Osorio-Forero (Netherlands Institute for Neuroscience), with Claude (Anthropic).', ...
    '', ...
    sprintf('Dedicated to Romain Cardis and Anita L%sthi, who wrote VeryScore2 and shared it with all of us.', u), ...
    sprintf('If you use VeryScore in published work, please cite the L%sthi lab (README and CITATION.cff).', u)};
uicontrol(f, 'Style', 'text', 'Units', 'normalized', 'Position', [.04 .14 .92 .50], 'String', lines, ...
    'HorizontalAlignment', 'left', 'BackgroundColor', 'w', 'FontSize', 10);
uicontrol(f, 'Style', 'pushbutton', 'Units', 'normalized', 'Position', [.04 .03 .30 .08], ...
    'String', 'VeryScore3 on GitHub', 'Callback', @(~,~) web('https://github.com/aosorioforero/VeryScore3', '-browser'));
uicontrol(f, 'Style', 'pushbutton', 'Units', 'normalized', 'Position', [.36 .03 .30 .08], ...
    'String', sprintf('L%sthi lab repository', u), 'Callback', @(~,~) web('https://github.com/luthilab/IntanLuthiLab', '-browser'));
uicontrol(f, 'Style', 'pushbutton', 'Units', 'normalized', 'Position', [.80 .03 .16 .08], 'String', 'Close', ...
    'Callback', @(~,~) delete(f));
end
