function Y2R_Main
%
%
% Romain Cardis 2019


clear varsu
close all

%%



sampling_rate = rhd2000.SamplingRate.rate1000;
h = struct();
conf = Y2R_getConf;
h = Y2R_mainFig(h);

%% set callbacks

h.browse.Callback = @browseFile;
h.recSettings.Callback = @launchSett;
h.start.Callback = @startConnect;

%% callback functions

    function browseFile(~,~)
        userID = getenv('username');
        tempdir = ['C:\Users\', userID, '\Documents'];
        h.folder = uigetdir(tempdir);
        if ischar(h.folder)
            h.console.String = '>> Choose the recording settings';
            h.recSettings.Enable = 'on';
        end
    end

%% Settings and board connection

    function launchSett(~,~)
        setfig = figure('menubar', 'none',...
            'color',         'white',...
            'name',          'Settings',...
            'numbertitle',   'off',...
            'units',         'normalized',...
            'outerposition', [0.15 .4 0.27 0.5]);
        h.settings = Y2R_recSettings(setfig, conf);
        
        waitfor(setfig)
        
        %connect to board
        
        h.console.String = '>> Connecting to board...';
        pause(1)
        h.driver = rhd2000.Driver();
        h.board = h.driver.create_board();
        h.datablock = rhd2000.datablock.DataBlock(h.board); % allocate space for the datablock
        h.board.SamplingRate = sampling_rate;
        h.nChip = length(h.board.Chips(h.board.Chips ~= 0));
        h.chipIndex = find(h.board.Chips ~= 0);
        ctem = fieldnames(conf);
        h.conf = conf.(char(ctem{h.settings.config+1}));
        
        % change DSP
        para = h.board.get_configuration_parameters();
        para.Chip.Bandwidth.DesiredDsp = .1;
        h.board.set_configuration_parameters(para)
        
        % create the panels
        h.tab = cell(1,h.nChip);
        h.tabs = uitabgroup(h.mainFig,'units', 'normalized',...
            'Position', [.05, .05, .9, .815]);
        
        if ~isstruct(h.conf)
            cconf = h.conf;
            h.conf = struct;
            for i = 1:h.nChip
                h.conf.(['A',num2str(i)]) = cconf;
            end
        end
        
        nA = fieldnames(h.conf);
        h.ntra = zeros(1,h.nChip);
        [h.ana, h.xyz] = deal(cell(1,length(nA)));
   
        for i = 1:length(nA)
            cconf = h.conf.(char(nA{i}));
            h.ntra(i) = sum(cellfun(@length, cconf));
            ana = find(cellfun(@ischar, cconf));
            anach = cconf(ana);
            for j = 1:length(anach)
                if strcmp(anach{j}, 'xyz')
                    h.xyz{i} = [1,2,3];
                    anach{j} = '0';
                end
            end
            cconf(ana) = [];
            h.ana{i} = cellfun(@str2double, anach);
            h.ana{i}(h.ana{i}==0) = [];
            h.conf.(char(nA{i})) = cconf;
        end
        
        for i = 1:h.nChip
            h.tab{i} = uitab(h.tabs, 'Title',['Animal ', num2str(i)],...
                'backgroundcolor','white');
            h.panels{i} = Y2R_panel(h.tab{i}, h.ntra(i));
        end
        
        h.start.Enable = 'on';
        h.console.String = '>> Now press start to start if you want to start';
        
    end

%% Start

    function startConnect(~,~)
        if isempty(h.settings.config)
            errordlg('please configure correctly before starting!')
            return
        end
        h.start.Enable = 'off';
        % create files
        h.console.String = '>> Creating new files...';
        pause(1)
        h = createfile(h);
        
        % wait or not depending if there's waiting or not.
        if ~strcmp(h.settings.startAt, 'now')
            % wait for right time
            cur = clock;
            startt = datevec(h.settings.startAt);
            timeToWait = etime(startt, cur);
            h.console.String = ['>> waiting: ',num2str(timeToWait)];
            h.console.ForegroundColor = [0.8500 0.3250 0.0980];
            
            while timeToWait ~= 0
                timeToWait = ceil(etime(startt, clock));
                h.console.String = ['>> waiting: ',num2str(timeToWait)];
                pause(.999)
            end
            
        end
        
        % start recording
        
        h.board.run_continuously(); % launch board
        
        h.console.ForegroundColor = [0.4660 0.6740 0.1880];
        fLen = h.settings.fileLength;
        
        h.curFile = 1;
        h.si = 1;
        h.nBlock = 0;
        
        for i = 1:h.settings.nFiles
            rTo = datestr(addtodate(now,fLen,'hour'));
            timeLeft = etime(datevec(rTo),clock);
            prevTL = ceil(timeLeft);
            h.console.String = ['>> Record file ',num2str(i)];
            drawnow
            
            % Actual recording files for chosen duration
            while timeLeft ~= 0
                
                timeLeft = ceil(etime(datevec(rTo), clock));
                
                h.nBlock = h.nBlock+1;
                idxpanel = str2double(h.tabs.SelectedTab.Title(end)); % get which tab is selected
                
                h = saveData(h, i, idxpanel);
                
                if prevTL ~= timeLeft
                    h.console.String = ['>> Record file ',num2str(i),' for ', num2str(ceil(timeLeft))];
                    
                    drawnow
                end
            end
            
            % Go to next file
            h.curFile = h.curFile+1;
            h.si = 1;
            
        end
        
        h.console.String = '>> Finished with successful success';
        h.board.DigitalOutputs = zeros(1,length(h.board.DigitalOutputs));
        h.board.stop()
        
    end

end

function [h] = createfile(h)

filename = h.fileEdit.String;
path = h.folder;

fLen = h.settings.fileLength;

Infos = struct;
Infos.Configuration = h.conf;
Infos.Fs = '1000';
Infos.RecordingDate = datestr(now);
Infos.FileLen = h.settings.fileLength;

for i = 1:h.settings.nFiles
    for c = 1:h.nChip
        tFile = [filename,'_Animal',num2str(c),'_',num2str(i),'.mat'];
        Infos.OriginalName = tFile;
        traces = zeros(h.ntra(c), fLen*3600*1000); %#ok<NASGU> %
        save([path,'\',tFile], 'traces','Infos','-v7.3')
        h.matFiles{c,i} = matfile([path,'\',tFile],'writable',true);
    end
end

end

function [h] = saveData(h,i,idxpanel)
% function to get and save the data and update the panels

h.datablock.read_next(h.board);

for c = 1:h.nChip

    nA = fieldnames(h.conf);
    % BE CAREFULL ABOUT THE DIVISION OF 1000
    toAdd = [h.datablock.Chips{h.chipIndex(c)}.Amplifiers(cell2mat(h.conf.(char(nA{c}))),:);...
        h.datablock.Board.ADCs(h.ana{c},:)./1000;...
        repelem((h.datablock.Chips{h.chipIndex(c)}.AuxInputs(h.xyz{c},:)-1.5)./1000,1,4)];
    h.matFiles{c,i}.traces(:,h.si:h.si+59) = toAdd; % actual saving
    
    % UPDATE OF THE SELECTED PANEL LAUNCHED HERE see update method of class
    % Y2R_panel for details
    if c == idxpanel
        updp = 1;
    else
        updp = 0;
    end
    
    update(h.panels{c}, toAdd, updp)
    
end

h.si = h.si + 60;

end
