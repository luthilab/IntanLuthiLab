function Ypnos_Main
%YPNOS_MAIN is used with Intan system to detect NREM sleep online and give
%responses such as TTL pulses. It needs an already scored baseline data
%from the same animal. You can use it with 4 animals. WARNING you need to
%use a read configuration in which EEG and EMG are respectively first and
%second (indexes 1 and 2). Add your configuration in the function
%Ypnos_getConf.m


clear vars
close all

%%

sampling_rate = rhd2000.SamplingRate.rate1000;

h = struct();
conf = Ypnos_getConf;
h = Ypnos_mainFig(h);

%% set callbacks

h.browse.Callback = @browseFile;
h.recSettings.Callback = @launchSett;
h.start.Callback = @startConnect;

%% Animal Panels

h.panels = cell(1,4);
positions = [0.67, 0.46,0.25,0.04];

%update(h.panels{1},5);

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
            'color',         'black',...
            'name',          'Settings',...
            'numbertitle',   'off',...
            'units',         'normalized',...
            'outerposition', [0.15 .4 0.27 0.5]);
        h.settings = Ypnos_recSettings(setfig, conf);
        
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
        
        % create the panels
        
        for i = 1:h.nChip
            h.panels{i} = Ypnos_Panel(h.mainFig,positions(i), i);
        end
        
        h.start.Enable = 'on';
        h.console.String = '>> Now choose a scored file per animal and press start';
        
    end

%% Start

    function startConnect(~,~)
        if isempty(h.settings.config)
            errordlg('please configure correctly before starting!')
            return
        end
        
        for i = 1:h.nChip
            if isempty(h.panels{i}.scoredFile)
                errordlg('please choose scored file!')
                return
            end
        end
        
        % get the information from the scored files
        h.console.String = '>> Learning from scored files...';
        for i = 1:h.nChip
            h.panels{i} = extractScore(h.panels{i});
        end
       
        % create files
        h.console.String = '>> Creating new files...';
        pause(1)
        h = createfile(h, conf);
        
        % wait or not
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
        
        h.console.ForegroundColor = [ 0.4660 0.6740 0.1880];
        fLen = h.settings.fileLength;
        
        h.curFile = 1;
        h.nPic = 1;
        h.si = 1;
        h.nBlock = 0;
        ncheck = 1;
        for i = 1:h.settings.nFiles
            rTo = datestr(addtodate(now,fLen,'hour'));
            timeLeft = etime(datevec(rTo),clock);
            prevTL = ceil(timeLeft);
            h.console.String = ['>> Record file ',num2str(i)];
            drawnow
            
            while timeLeft ~= 0
                
                timeLeft = ceil(etime(datevec(rTo), clock));

                h.nBlock = h.nBlock+1;
                
                h = saveData(h,i);
                
                if prevTL ~= timeLeft
                    h.console.String = ['>> Record file ',num2str(i),' for ', num2str(ceil(timeLeft))];
                    prevTL = timeLeft;
                    for c = 1:h.nChip
                        st = checkState(h.panels{c});
                        h.matFiles{c,i}.states(:,ncheck) = st;
                    end
                    ncheck = ncheck + 1;
                    drawnow
                end
            end
            
            h.curFile = h.curFile+1;
            h.nPic = 1;
            h.si = 1;
            ncheck = 1;
        end
        
        h.console.String = '>> Finished with successful success';
        h.board.stop()
        
    end

end

function [h] = createfile(h, conf)

filename = h.fileEdit.String;
path = h.folder;
ctem = fieldnames(conf);
h.conf = conf.(char(ctem{h.settings.config+1}));
ntraces = sum(cellfun(@length, h.conf));
fLen = h.settings.fileLength;
traces = zeros(ntraces, fLen*3600*1000); %#ok<NASGU>
states = zeros(3, fLen*3600); %#ok<NASGU>

for i = 1:h.settings.nFiles
    for c = 1:h.nChip
        tFile = [filename,'_Animal',num2str(c),'_',num2str(i),'.mat'];
        save([path,'\',tFile], 'traces','states','-v7.3')
        h.matFiles{c,i} = matfile([path,'\',tFile],'writable',true);
    end
end

end

function [h] = saveData(h,i)
% function to save the date and update the panels

h.datablock.read_next(h.board);

for c = 1:h.nChip
    toAdd = h.datablock.Chips{h.chipIndex(c)}.Amplifiers(cell2mat(h.conf),:);
    h.matFiles{c,i}.traces(:,h.si:h.si+59) = toAdd;
    
    % UPDATE OF THE PANELS LAUNCHED HERE see update method of class
    % Ypnos_Panel for details
    update(h.panels{c}, toAdd(1:2,:))
    
end

h.si = h.si + 60;

end
