% Main script
% This software allows recording with Intan RHD2000 board

function YR_main
clear vars
close all 
clc

%Create main structure that contains all handles
h = struct();
c = struct();


% Launch the script that created the figure and all handles
[h,c] = YR_display(h,c);

% Establish connection with webcam
% if ~isempty(webcamlist)
%     h.cam = webcam;
%     h.cam.Resolution = '352x288';
%     YR_createVid( h );
% end

%% set some variables
folder_name = [];
driver = [];
board = [];
dates = cell(1,2); %Cell 1 = recStart // Cell 2 = updatingTime

%% Set Timers
tim = timer('ExecutionMode',    'fixedSpacing',...% Run timer repeatedly
    'Period',           0.001, ...
    'TimerFcn',         @launchRefresh); % Specify callback

timNoise = timer('ExecutionMode', 'singleShot',...
    'startDelay',       0.05,...
    'TimerFcn',         @TTLmod); %50 ms delay

%% set callbacks
h.pF_browse.Callback        = @browseFolder;
h.pF_okButton.Callback      = @validate;
h.butStart.Callback         = @startRec;
h.butStop.Callback          = @stopRec;
h.butNoiseOn.Callback         = @playNoise;
h.setLayout.Callback        = @updateLayout;
h.mainFig.WindowButtonDownFcn = @mouseClick;
h.gainPlus.Callback         = @increaseGain;
h.gainMinus.Callback        = @decreaseGain;
h.setNotch.Callback         = @applyNotch;

h.mainFig.CloseRequestFcn   = @closeEVERYTHING;

%% Set variables
h.typeOfFile = '.mat';
h.notch = false;
h.save = false;
h.scheduledStart = [];
h.si1 = 1;
%% set drop menu (uimenu) items

h.menu.rhd = uimenu(h.menu.typeFile, 'label', 'RHD files', 'Callback', {@typeFileSaved, 'rhd'});
h.menu.mat = uimenu(h.menu.typeFile, 'label', 'Matlab files', 'Callback', {@typeFileSaved, 'mat'}, 'Checked', 'on');
h.menu.both = uimenu(h.menu.typeFile, 'label', 'Both (such greed)', 'Callback', {@typeFileSaved, 'both'});

h.menu.plannedRecord.Callback = @run_schedule;
%% set Functions

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% BROWSE FOLDER
    function browseFolder(~,~)
        tempstr = h.pF_edit.String;
        
        if char(tempstr(1)) == '0' || char(tempstr(1)) == 'B'
            userID = getenv('username');
            tempdir = ['C:\Users\', userID, '\Documents'];
        else
            tempdir = tempstr;
        end
        
        folder_name = uigetdir(tempdir);
        h.pF_edit.String = folder_name;
    end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% VALIDATE FILENAME
    function validate(~,~)
        tempname = [h.pF_editFileName.String, h.typeOfFile];
        tempfile = fullfile(folder_name, tempname);
        if exist(tempfile) ~= 0 %#ok<EXIST>
            errordlg('This file already exists, please modify its name',...
                'Fatal Error');
            return
        end
        
        driver = rhd2000.Driver();
        board = driver.create_board();
        
%         %% remove dsp
%          para = board.get_configuration_parameters();
%         para.Chip.Bandwidth.DspEnabled = 1;
%         board.set_configuration_parameters(para)
%         %%
% DSP filter settings to put it at 0.1 or not
        para = board.get_configuration_parameters();
        %para.Chip.Bandwidth.DspEnabled = 1;
        para.Chip.Bandwidth.DesiredDsp = .1; % This line set the filter at 0.1
        board.set_configuration_parameters(para)
        
        h.chipID = length(board.Chips(board.Chips ~= 0));
        h.chipIndex = find(board.Chips ~= 0);
        [h] = YR_createTabs(h,c);
        
        h.pF_okButton.BackgroundColor   = c.greenl;
        h.pF_okButton.ForegroundColor   = c.greend;
        h.setSF.Enable                  = 'on';
        h.setLayout.Enable              = 'on';
        h.butStart.Enable               = 'on';
        h.butStop.Enable                = 'on';
        h.setNotch.Enable               = 'on';
        h.butNoiseOn.Enable               = 'on';
    end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% START ACQUISITION
    function startRec(~,~)
        %Check that a layout has been selected (value~=1)
        if h.setLayout.Value == 1
            msgbox('Please Select a display layout');
            return
        end
        
        h.butStart.BackgroundColor      = c.greenl;
        h.butStart.ForegroundColor      = c.greend;
        h.butStart.Enable               = 'off';
        h.butStop.Enable                = 'on';
        h.panelGain.Visible             = 'on';
        tempstr                         = h.setSF.String;
        tempval                         = h.setSF.Value;
        tempSF                          = tempstr{tempval};
        h.samplingRate = str2double(tempSF(strfind(tempSF, 'e')+1:end));
        
%         driver = rhd2000.Driver();
%         board = driver.create_board();
        %sr
        board.SamplingRate = rhd2000.SamplingRate.(char(tempSF));
        board.run_continuously();
        h.numberOfFile = 1;
        
%         h.chipID = length(board.Chips(board.Chips ~= 0));
        
%         board.run_continuously();
        h.refCount = 0;
        
        [h.b, h.a] = butter(3, [45/(200/2), 55/(200/2)], 'stop'); %adapt sampling rate to display (200 Hz)
        
        dates{1} = now;
        h.recStartvalue.String = datestr(dates{1}, 'HH:MM:SS');
        [h] = YR_create_file(h, board, folder_name);
        
        start(tim)
        
        
        
    end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% STOP ACQUISITION
    function stopRec(~,~)
        stop(tim)
        dates{2} = now;
        timeElapsed = dates{2}-dates{1};
        switch h.typeOfFile
            case '.rhd'
                board.SaveFile.close();
                board.SaveFile.Note2 = ['Total recording length: ', datestr(timeElapsed, 'HH:MM:SS')];
            case '.mat'
                for i = 1:h.chipID
                    h.matFile{i}.traces = h.matFile{i}.traces(:,1:h.si1);
                end
        end
        board.stop();
        h.butStart.BackgroundColor      = c.background;
        h.butStart.ForegroundColor      = c.textcolor;
        h.butStart.Enable               = 'on';
        h.butStop.Enable                = 'off';
        
        
    end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% UPDATE LAYOUT
    function updateLayout(~,~)
        [h,c] = YR_createPlot(h,c);
        h.selected = 1;
    end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TIMER CALLBACK
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% MOST IMPORTANTER FUNCTION
    function launchRefresh(~,~)
        if h.save
            dates{2} = now;
            timeElapsed = dates{2}-dates{1};
            h.timeElvalue.String = datestr(timeElapsed, 'HH:MM:SS');
        end
        if isempty(h.scheduledStart) %no planner recording, record from beginning
            dates{1} = now; %record from NOW
            h.save = true; %save the datablocks
            h.scheduledStart = now; %scheduledStard is NOW
            h.recordingLength = '12'; %DEFAULT recording length is 12 hours
        elseif datestr(now, 'HH:MM:SS') == h.scheduledStart %assign saving BOOL once scheduled start is true
            dates{1} = now; %start recording from NOW
            h.save = true;
        end
        
        if str2double(h.timeElvalue.String(1:2)) == str2double(h.recordingLength) %if we are recording since 12 hours
            dates{1} = now; %reset the NOW
            newFile; %create new file
        end
        h = YR_refreshDisp(h, board);
    end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% SELECT TRACE
    function mouseClick(~,~)
        cli = get(gcbf, 'SelectionType'); %#ok<NASGU>
        curC = get(gcbf, 'CurrentPoint');
        if curC(1) > 0.23 && curC(1) < 0.97 && curC(2) < 0.93 && curC(2) > 0.0868
            h.traceHandle{h.selected}.Color = c.blue;            
            x1 = 0.0868;
            x2 = 0.9371;
            a = (x2-x1)/h.nb;
            t = ceil(((curC(2)-(x1+a/2))/(1-(x1+a+(1-x2))))*h.nb);
            h.selected = (h.nb-t+1);
            disp(h.selected)
            h.traceHandle{h.selected}.Color = c.orange;
        end
    end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% INCREASE GAIN
    function increaseGain(~,~)
        h.traceHandle{h.selected,2} = h.traceHandle{h.selected,2}+200;
        %disp(h.selected)
        %disp(h.traceHandle{h.selected,2})
    end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% DECREASE GAIN
    function decreaseGain(~,~)
        h.traceHandle{h.selected,2} = h.traceHandle{h.selected,2}-200;
        %disp(h.selected)
        %disp(h.traceHandle{h.selected,2})
    end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% DECREASE GAIN
    function applyNotch(~,~)
        switch h.setNotch.Value;
            case 1
                h.notch = false;
            case 2
                h.notch = true;
        end
    end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% PLAY NOISE
    function playNoise(~,~)
        board.DigitalOutputs = [0 0 0 0 1 1 1 1 1 0 0 0 0 0 0 0];
        start(timNoise)
    end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% TimNoise Function
    function TTLmod(~,~) %this function is executed 50 ms after timNoise starts
        board.DigitalOutputs = [0 0 0 0 1 1 1 1 0 0 0 0 0 0 0 0];
    end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% New File
    function newFile(~,~)
        switch h.typeOfFile
            case '.rhd'               
                % Save previous file
                board.SaveFile.Note2 = ['file stopped at: ', datestr(dates{2})];
                board.SaveFile.close();
                % New file
                h.numberOfFile = h.numberOfFile+1;
                tempname = [h.pF_editFileName.String, '_',num2str(h.numberOfFile),'.rhd'];
                tempfile = fullfile(folder_name, tempname);
                board.SaveFile.Note1 = ['file start: ',datestr(dates{2}, 'HH:MM:SS')];
                board.SaveFile.open(rhd2000.savefile.Format.intan, tempfile);      
            case '.mat'
                h.numberOfFile = h.numberOfFile+1;
                if isempty(cell2mat(h.traceIndex(h.nb)))
                    traces = zeros(length(cell2mat(h.traceIndex))+1, 12*3600*1000); %#ok<PREALL>
                else
                    traces = zeros(length(cell2mat(h.traceIndex)), 12*3600*1000); %#ok<NASGU>
                end
                info = struct();
                tempfile = cell(1,h.chipID);
                traceIndex = h.traceIndex;
                traceName = h.traceName;
                for i = 1:h.chipID
                    tempname = [h.pF_editFileName.String,'_Animal', num2str(i), '_', num2str(h.numberOfFile), '.mat'];
                    tempfile{i} = fullfile(folder_name, tempname);
                    save(tempfile{i}, 'traces','info', 'traceIndex', 'traceName', '-v7.3')
                    h.matFile{i} = matfile(tempfile{i},'Writable',true);
                end
        end
        
    end

    function typeFileSaved(~,~,type)
        h.menu.mat.Checked = 'off';
        h.menu.rhd.Checked = 'off';
        h.menu.both.Checked = 'off';
        switch type
            case 'mat'
                h.typeOfFile = '.mat';
                h.menu.mat.Checked = 'on';
            case 'rhd'
                h.typeOfFile = '.rhd';
                h.menu.rhd.Checked = 'on';
            case 'both'
                h.typeOfFile = 'both';
                h.menu.both.Checked = 'on';
        end
    end

    function closeEVERYTHING(~,~)
        stop(tim)
%         delete(h.cam)
        if strcmp(h.butStop.Enable,'on') == 1
            board.stop();
            delete(board)
            delete(driver)
        end
        delete(gcf)
        clear
    end

    function run_schedule(~,~)
        prompt = {'Scheduled recording start:'; 'Planned files recording length (h):'};
        dlg_title = 'Request user Input';
        num_lines = 1;
        def_ans = {'09:00:00'; '12'};
        answer = inputdlg(prompt, dlg_title, num_lines, def_ans);
        h.scheduledStart = datestr(answer{1}, 'HH:MM:SS');
        h.recordingLength = answer{2};
    end

end

