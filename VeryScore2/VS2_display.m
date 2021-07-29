function [ h ] = VS2_display(h)
%VS2_TRACESPLOT To create the main figure

h.white = [1 1 1];
h.black = [0 0 0];
h.wakeColor = [.8 .2 .2];
h.nremColor = [.4 .6 .2];
h.remColor = [.8 .6 .2];

figTitle = ['VeryScore2 v', h.updt];

h.mainFig = figure('unit','normalized',...
    'position', [.1,.1,.8,.8],...
    'color'             ,       h.white,...
    'numbertitle'       ,       'off',...
    'name'              ,       figTitle,...
    'Menubar'           ,       'none');


%% file menu
h.fileMenu = uimenu(h.mainFig, 'Text', 'File');
h.fileMenu_import = uimenu(h.fileMenu, 'Text', 'Import');
h.fileMenu_importrandom = uimenu(h.fileMenu, 'Text', 'Import randomly', 'Enable', 'on');
h.fileMenu_save = uimenu(h.fileMenu, 'Text', 'Save', 'Enable', 'off');
h.fileMenu_editInfo = uimenu(h.fileMenu, 'Text', 'Edit file Infos', 'Enable', 'off');
h.fileMenu_reduce = uimenu(h.fileMenu, 'Text', 'Reduce file size', 'Enable', 'off');

%%  Tools menu
h.toolsMenu = uimenu(h.mainFig, 'Text', 'Tools','enable','off');
h.toolsMenu_autoScore = uimenu(h.toolsMenu, 'Text', 'Auto-Scoring');
h.toolsMenu_nameTraces = uimenu(h.toolsMenu, 'Text', 'Reload Names from Infos');
h.toolsMenu_takeSnap = uimenu(h.toolsMenu, 'Text', 'Take a snapshot');

%% Traces menue
h.tracesMenu = uimenu(h.mainFig, 'Text', 'Traces', 'enable', 'off');
h.tracesMenu_lockYlim = uimenu(h.tracesMenu, 'Text', 'Lock YLim', 'Checked','off');
h.tracesMenu_filt = uimenu(h.tracesMenu, 'Text', 'Filter traces');
h.tracesMenu_bipol = uimenu(h.tracesMenu, 'Text', 'Bipolarize');
h.tracesMenu_ChangeGain = uimenu(h.tracesMenu, 'Text', 'Change gain *1000');
h.tracesMenu_notch = uimenu(h.tracesMenu, 'Text', 'Notch');
h.tracesMenu_Supress = uimenu(h.tracesMenu, 'Text', 'Supress selected traces');
h.tracesMenu_swapTraces = uimenu(h.tracesMenu, 'Text', 'Swap traces position');
h.tracesMenu_origain = uimenu(h.tracesMenu, 'Text', 'Reverse gain and filter');
h.tracesMenu_reverse = uimenu(h.tracesMenu, 'Text', 'Reverse all changes');

%% Width menu
h.widthMenu = uimenu(h.mainFig, 'Text', 'Width','Enable','off');
h.widthMenu_8 = uimenu(h.widthMenu, 'Text', '8 seconds', 'Checked','off', 'UserData', 2);
h.widthMenu_16 = uimenu(h.widthMenu, 'Text', '16 seconds', 'Checked','off', 'UserData', 4);
h.widthMenu_24 = uimenu(h.widthMenu, 'Text', '24 seconds', 'Checked','off', 'UserData', 6);
h.widthMenu_32 = uimenu(h.widthMenu, 'Text', '32 seconds', 'Checked','off', 'UserData', 8);
h.widthMenu_40 = uimenu(h.widthMenu, 'Text', '40 seconds', 'Checked','on', 'UserData', 10);
h.widthMenu_48 = uimenu(h.widthMenu, 'Text', '48 seconds', 'Checked','off', 'UserData', 12);
h.widthMenu_96 = uimenu(h.widthMenu, 'Text', '96 seconds', 'Checked','off', 'UserData', 24);
h.widthMenu_384 = uimenu(h.widthMenu, 'Text', '384 seconds', 'Checked','off', 'UserData', 96);

end

