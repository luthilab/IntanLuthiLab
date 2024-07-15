function Adonis_Main
%Automatic Detection Of NREMS Infraslow State or ADONIS. Adonis was the
%greek god of beauty, desire and vegetation. It matches the idea of this
%software through the beauty of the analysis and usefulness of it, my
%desire for it to work well and the vegetation associated to sleep.
%Overall, what matches well is the imbred dumbness of some lines (coded by a biologist),
%since adonis' mother was also his sister.
%
%Adonis_MAIN is used with Intan system to detect NREMS and the specific
%state of the infraslow "Fragility" or "continuity" and give TTL time-lock
%to one of them. Its architecture is mostly based on YPNOS.
%
% Romain Cardis 2019

clear vars
close all
 

%%

sampling_rate = rhd2000.SamplingRate.rate1000;

h = struct();
conf = Adonis_getConf;
h = Adonis_mainFig(h);

%% set callbacks

h.browse.Callback = @browseFile;
h.recSettings.Callback = @launchSett;
h.start.Callback = @startConnect;

%% Animal Panels

h.panels = cell(1,4);
positions = [0.67, 0.46,0.25,0.04];

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
            'color',         [172/255, 207/255, 232/255],...
            'name',          'Settings',...
            'numbertitle',   'off',...
            'units',         'normalized',...
            'outerposition', [0.15 .3 0.27 0.6]);
        h.settings = Adonis_recSettings(setfig, conf);
        
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
        
        % change DSP
        para = h.board.get_configuration_parameters();
        para.Chip.Bandwidth.DesiredDsp = .1;
        h.board.set_configuration_parameters(para)
        
        % create the panels
        for i = 1:h.nChip
%             h.panels{i} = Adonis_Panel_simple(h.mainFig, positions(i), i); % This is for simple thresholf method, might be easier to adapt to a new experiment
            h.panels{i} = Adonis_Panel_NeuralNet(h.mainFig, positions(i), i); % This is for the neural network method
  
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
        
        % create files
        h.console.String = '>> Creating new files...';
        pause(1)
        h = createfile(h, conf);
        
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
                
                [h,tp] = saveData(h,i);
                
                if prevTL ~= timeLeft
                    h.console.String = ['>> Record file ',num2str(i),' for ', num2str(timeLeft)];
                    prevTL = timeLeft;
                    for c = 1:h.nChip
                        st = checkState(h.panels{c});
                        stad = [st;tp;h.nBlock];
                        h.matFiles{c,i}.states(:,ncheck) = stad;
                        % Here is given the answer if the animal c is in
                        % the correct state chosen in the settings.
                        if st(4) == h.settings.contFrag(c)
                            h.board.DigitalOutputs(c+12) = 1;
                        else
                            h.board.DigitalOutputs(c+12) = 0;
                        end
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
        h.board.DigitalOutputs = zeros(1,length(h.board.DigitalOutputs));
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
traces = zeros(ntraces + 1, fLen*3600*1000); %#ok<NASGU> % +1 for 1 analog
states = zeros(6+2, fLen*3600); %#ok<NASGU> 6 per neural net 7 per simple
Infos = struct;
Infos.RecordingDate = datestr(now);
Infos.FileLen = num2str(h.settings.fileLength);
Infos.Fs = '1000';
posS = {'cont','frag'};
for i = 1:h.settings.nFiles
    for c = 1:h.nChip
        tFile = [filename,'_Animal',num2str(c),'_',num2str(i),'.mat'];
        Infos.Period = posS{h.settings.contFrag(c)};
        Infos.OriginalName = tFile;
        save([path,'\',tFile], 'traces','states','Infos','-v7.3')
        h.matFiles{c,i} = matfile([path,'\',tFile],'writable',true);
    end
end

end

function [h,tp] = saveData(h,i)
% function to get and save save the data and update the panels

h.datablock.read_next(h.board);
analog = h.datablock.Board.ADCs; % get the analogue inputs channels

for c = 1:h.nChip
    
    toAdd = h.datablock.Chips{h.chipIndex(c)}.Amplifiers(cell2mat(h.conf),:);
    toSave = [toAdd; analog(c,:)]; % add the analogue readings for the close loop response from the Pi.
    h.matFiles{c,i}.traces(:,h.si:h.si+59) = toSave;
    
    % UPDATE OF THE PANELS LAUNCHED HERE see update method of class
    % Adonis_Panel for details
    
    if length(h.conf{1}) == 2 % if it's referential recording
        update(h.panels{c}, [toAdd(1,:)-toAdd(2,:);toAdd(3,:)-toAdd(4,:)])
    else % if it's bipolar recording
        update(h.panels{c}, toAdd(1:2,:))
    end
    
end

tp = double(h.datablock.Timestamps(end))/1000;
h.si = h.si + 60;

end
