function [ h ] = VS3_display(h)
%VS3_DISPLAY Creates the main figure and its menus

h.white = [1 1 1];
h.black = [0 0 0];
h.wakeColor = [.8 .2 .2];
h.nremColor = [.4 .6 .2];
h.remColor = [.8 .6 .2];

figTitle = ['VeryScore3 v', h.updt];

h.mainFig = figure('unit','normalized',...
    'position', [.1,.1,.8,.8],...
    'color'             ,       h.white,...
    'numbertitle'       ,       'off',...
    'name'              ,       figTitle,...
    'Tag'               ,       'VS3Main',...
    'Menubar'           ,       'none');


%% file menu
h.fileMenu = uimenu(h.mainFig, 'Text', 'File');
h.fileMenu_import = uimenu(h.fileMenu, 'Text', 'Import');
h.fileMenu_importrandom = uimenu(h.fileMenu, 'Text', 'Import randomly', 'Enable', 'on');
h.fileMenu_convertOE = uimenu(h.fileMenu, 'Text', 'Convert Open Ephys recording...', 'Separator', 'on');
h.fileMenu_sensorConvert = uimenu(h.fileMenu, 'Text', 'Sensor CSV files to one H5...');
h.fileMenu_save = uimenu(h.fileMenu, 'Text', 'Save', 'Enable', 'off');
h.fileMenu_export = uimenu(h.fileMenu, 'Text', 'Export displayed traces (.mat)...', 'Enable', 'off');
h.fileMenu_editInfo = uimenu(h.fileMenu, 'Text', 'Edit file Infos', 'Enable', 'off');
h.fileMenu_reduce = uimenu(h.fileMenu, 'Text', 'Reduce file size', 'Enable', 'off');
h.fileMenu_rename = uimenu(h.fileMenu, 'Text', 'Rename files to bt', 'Enable', 'on');

%%  Tools menu
h.toolsMenu = uimenu(h.mainFig, 'Text', 'Tools','enable','off');
h.toolsMenu_autoScore = uimenu(h.toolsMenu, 'Text', 'Auto-Scoring');
h.toolsMenu_autoScoreRun = uimenu(h.toolsMenu_autoScore, 'Text', 'Score this file...');
h.toolsMenu_autoScoreAdd = uimenu(h.toolsMenu_autoScore, 'Text', 'Add this scoring to the library...', 'Separator', 'on');
h.toolsMenu_autoScoreLib = uimenu(h.toolsMenu_autoScore, 'Text', 'Library contents...');
h.toolsMenu_autoScoreClassic = uimenu(h.toolsMenu_autoScore, 'Text', 'Classic auto-scoring (VeryScore2, selected traces)...', 'Separator', 'on');
h.toolsMenu_nameTraces = uimenu(h.toolsMenu, 'Text', 'Reload Names from Infos');
h.toolsMenu_takeSnap = uimenu(h.toolsMenu, 'Text', 'Take a snapshot');
h.toolsMenu_summary = uimenu(h.toolsMenu, 'Text', 'Summary figure...');

%% Thermal video submenu (temperature panel, see VS3_thermalTool)
h.toolsMenu_thermal = uimenu(h.toolsMenu, 'Text', 'Thermal video', 'Separator', 'on');
h.toolsMenu_thermalAnalyse = uimenu(h.toolsMenu_thermal, 'Text', 'Analyse video (.ravi / .h5)...');
h.toolsMenu_thermalShow = uimenu(h.toolsMenu_thermal, 'Text', 'Show temperature panel', 'Checked', 'off', 'Enable', 'off');
h.toolsMenu_thermalOffset = uimenu(h.toolsMenu_thermal, 'Text', 'Change video/EEG offset...', 'Enable', 'off', 'Separator', 'on');
h.toolsMenu_thermalEstimate = uimenu(h.toolsMenu_thermal, 'Text', 'Estimate offset from movement', 'Enable', 'off');
h.toolsMenu_thermalOpenEphys = uimenu(h.toolsMenu_thermal, 'Text', 'EEG start time from Open Ephys recording...');
h.toolsMenu_thermalCalib = uimenu(h.toolsMenu_thermal, 'Text', 'Add camera calibration (degC) to video...', 'Separator', 'on');
h.toolsMenu_thermalPython = uimenu(h.toolsMenu_thermal, 'Text', 'Select python.exe...');

%% Video submenu (Pi camera and thermal video in a column right of the traces, see VS3_videoPanel)
h.toolsMenu_video = uimenu(h.toolsMenu, 'Text', 'Video');
h.toolsMenu_videoPi = uimenu(h.toolsMenu_video, 'Text', 'Open Pi camera video...');
h.toolsMenu_videoThermal = uimenu(h.toolsMenu_video, 'Text', 'Open thermal video (.ravi / .h5)...');
h.toolsMenu_videoShow = uimenu(h.toolsMenu_video, 'Text', 'Show', 'Enable', 'off', 'Separator', 'on');
h.toolsMenu_videoShowPi = uimenu(h.toolsMenu_videoShow, 'Text', 'Pi camera', 'UserData', 'pi');
h.toolsMenu_videoShowThermal = uimenu(h.toolsMenu_videoShow, 'Text', 'Thermal', 'UserData', 'thermal');
h.toolsMenu_videoShowBoth = uimenu(h.toolsMenu_videoShow, 'Text', 'Pi and thermal', 'UserData', 'both');
h.toolsMenu_videoShowOverlap = uimenu(h.toolsMenu_videoShow, 'Text', 'Thermal over Pi', 'UserData', 'overlap');
h.toolsMenu_videoAlign = uimenu(h.toolsMenu_video, 'Text', 'Align thermal on Pi camera...', 'Enable', 'off');
h.toolsMenu_videoAutoAlign = uimenu(h.toolsMenu_video, 'Text', 'Align thermal on Pi from the movement...', 'Enable', 'off');
h.toolsMenu_videoOffset = uimenu(h.toolsMenu_video, 'Text', 'Change video/EEG offsets...', 'Enable', 'off');
h.toolsMenu_videoLag = uimenu(h.toolsMenu_video, 'Text', 'Estimate Pi offset from the movement...', 'Enable', 'off');
h.toolsMenu_videoTiming = uimenu(h.toolsMenu_video, 'Text', 'Load recorder timing folder...', 'Enable', 'off');
h.toolsMenu_videoTimingClear = uimenu(h.toolsMenu_video, 'Text', 'Clear recorder timing (use the offsets)', 'Enable', 'off');
h.toolsMenu_videoRoiAdd = uimenu(h.toolsMenu_video, 'Text', 'Add ROI...', 'Enable', 'off', 'Separator', 'on');
h.toolsMenu_videoRoiOn = uimenu(h.toolsMenu_video, 'Text', 'Measure ROIs at every epoch', 'Checked', 'on', 'Enable', 'off');
h.toolsMenu_videoRoiNow = uimenu(h.toolsMenu_video, 'Text', 'Measure ROIs of this epoch', 'Enable', 'off');
h.toolsMenu_videoRoiRemove = uimenu(h.toolsMenu_video, 'Text', 'Remove ROIs...', 'Enable', 'off');
h.toolsMenu_videoClosePi = uimenu(h.toolsMenu_video, 'Text', 'Close Pi camera video', 'Enable', 'off', 'Separator', 'on');
h.toolsMenu_videoCloseThermal = uimenu(h.toolsMenu_video, 'Text', 'Close thermal video', 'Enable', 'off');

%% Sensor submenu (Pi sensor compared with the EEG / EMG in 4-s epochs, see VS3_sensorView)
h.toolsMenu_sensor = uimenu(h.toolsMenu, 'Text', 'Sensor data');
h.toolsMenu_sensorImport = uimenu(h.toolsMenu_sensor, 'Text', 'Import sensor CSV...');
h.toolsMenu_sensorShow = uimenu(h.toolsMenu_sensor, 'Text', 'Show sensor / EMG comparison', 'Enable', 'off');
h.toolsMenu_sensorSettings = uimenu(h.toolsMenu_sensor, 'Text', 'Alignment and candidate bands...', 'Enable', 'off');

%% Photometry submenu (dF/F of a recorded channel, see VS3_photometry)
h.toolsMenu_photo = uimenu(h.toolsMenu, 'Text', 'Photometry');
h.toolsMenu_photoDFF = uimenu(h.toolsMenu_photo, 'Text', 'Selected trace to dF/F...');
h.toolsMenu_photoFigure = uimenu(h.toolsMenu_photo, 'Text', 'Show dF/F overview figure', 'Enable', 'off');

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

%% Help menu
h.helpMenu = uimenu(h.mainFig, 'Text', 'Help');
h.helpMenu_about = uimenu(h.helpMenu, 'Text', 'About VeryScore3...');

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

%% start screen (logo), removed when a file is imported
h.splash = VS3_logo('start', h.mainFig, h.updt);

end

