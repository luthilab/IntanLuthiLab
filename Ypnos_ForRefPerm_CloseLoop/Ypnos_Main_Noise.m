function Ypnos_Main_Noise
%YPNOS_MAIN is used with Intan system to detect NREM sleep online and give
%responses such as TTL pulses. It doesn't need an already scored baseline data
%You can use it with 4 animals. WARNING you need to
%use a read configuration in which EEG and EMG are respectively first and
%second (indexes 1 and 2). Add your configuration in the function
%Ypnos_getConf.m but mostly use the EEG one with implantation same as usual
% Romain Cardis 2017

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
st_Noise.b_NoiseOn = 1;
st_Noise.s_Fs = 44100;
st_Noise.Duation = 2; % seconds
st_Noise.v_Sound = f_pinknoise(1, st_Noise.Duation*st_Noise.s_Fs);
st_Noise.s_MinWait = 20;
st_Noise.s_MaxWait = 60;
st_Noise.WitingTime = 8;
st_Noise.Currenttime = 3;  
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
        
        % change dsp
        para = h.board.get_configuration_parameters();
        para.Chip.Bandwidth.DesiredDsp = .1;
        h.board.set_configuration_parameters(para)
        
        % create the panels
        
        for i = 1:h.nChip
            h.panels{i} = Ypnos_Panel1000hz(h.mainFig,positions(i), i);
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
                    h.console.String = ['>> Record file ',num2str(i),' for ', num2str(ceil(timeLeft))];
                    prevTL = timeLeft;
                    for c = 1:h.nChip
                        st = checkState(h.panels{c});
                        stad = [st;tp];
                        h.matFiles{c,i}.states(1:4,ncheck) = stad;
                        if st(1) == 2 % CHANGE THE STATE HERE TO HAVE TTL HIGH WHEN IT OCCURS. 1:wake, 2:NREMS, 3:REMS
                            h.board.DigitalOutputs(c+12) = 1;
                        else
                            h.board.DigitalOutputs(c+12) = 0;
                        end
                    end
                    
                    %%% Sound stimulation
                    if st_Noise.Currenttime >= st_Noise.WitingTime
                        sound(st_Noise.v_Sound, st_Noise.s_Fs);        
                        st_Noise.WitingTime = round((st_Noise.s_MaxWait-st_Noise.s_MinWait).*rand(1) + st_Noise.s_MinWait);                        
                        st_Noise.b_NoiseOn=1;
                        st_Noise.Currenttime = 0;
                    else
                        st_Noise.Currenttime = st_Noise.Currenttime + 1;
                    end
                    
                    if st_Noise.Currenttime == 0
                        h.board.DigitalOutputs(9) = 1;% It is the 8 pin
                    elseif st_Noise.Currenttime == 2
                        h.board.DigitalOutputs(9) = 0;
                    end
                    %%%%%%%%%%%%%%%%%%%%%%%
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

if isstruct(h.conf)
    nA = fieldnames(h.conf);
    ntraces = zeros(1,length(nA));
    for i = 1:length(nA)
        ntraces(i) = sum(cellfun(@length, h.conf.(char(nA{i}))));
    end
else
    ntraces = repmat(sum(cellfun(@length, h.conf)),1,h.nChip);
end

fLen = h.settings.fileLength;

%traces = zeros(ntraces, fLen*3600*1000); %#ok<NASGU>
states = zeros(4, fLen*3600); 

for i = 1:h.settings.nFiles
    for c = 1:h.nChip
        traces = zeros(ntraces(c)+2, fLen*3600*1000); % +2 traces for the analogs
        tFile = [filename,'_Animal',num2str(c),'_',num2str(i),'.mat'];
        save([path,'\',tFile], 'traces','states','-v7.3')
        h.matFiles{c,i} = matfile([path,'\',tFile],'writable',true);
    end
end

end

function [h,tp] = saveData(h,i)
% function to get and save save the data and update the panels

h.datablock.read_next(h.board);

analog = h.datablock.Board.ADCs; % get the analogue inputs channels

for c = 1:h.nChip
    if isstruct(h.conf)
        nA = fieldnames(h.conf);
        toAdd = h.datablock.Chips{h.chipIndex(c)}.Amplifiers(cell2mat(h.conf.(char(nA{c}))),:);
        oneortwo = length(h.conf.(char(nA{c})){1});
    else   
        toAdd = h.datablock.Chips{h.chipIndex(c)}.Amplifiers(cell2mat(h.conf),:);
        oneortwo = length(h.conf{1});
    end
%     toSave = [toAdd; analog(2*c-1,:); analog(2*c,:)]; % add the analogue readings for the close loop response from the Pi.
%     toSave = [toAdd; analog(c,:); analog(c+4,:)]; % add the analogue 1, 5 for animal one and 2, 6 for animal 2 etc...
    
    %% To check if it is worth to use only one channel, could be even better
    toSave = [toAdd; analog(1,:); analog(c+4,:)]; % add the analogue 1, 5 for animal one and 2, 6 for animal 2 etc...
%Or
%     toSave = [toAdd; analog(c,:); analog(5,:)]; % add the analogue 1, 5 for animal one and 2, 6 for animal 2 etc...
   
    
    
    
    h.matFiles{c,i}.traces(:,h.si:h.si+59) = toSave; 
    % UPDATE OF THE PANELS LAUNCHED HERE see update method of class
    % Ypnos_Panel for details
    if oneortwo == 2
        update(h.panels{c}, [toAdd(1,:)-toAdd(2,:);toAdd(3,:)-toAdd(4,:)])
    else
        update(h.panels{c}, toAdd(1:2,:))
        %update(h.panels{c}, toSave(3:4,:)/1000)
    end
end

tp = double(h.datablock.Timestamps(end))/1000;
h.si = h.si + 60;

end
