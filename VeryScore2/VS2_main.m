function VS2_main
% VS2_MAIN Version
% Last version 1.5 addings.
% - Microarousal epoch corresponding to keyboard key 'm'
% - Treatment of last channel if it's too big (usually stimulation trace)
% -d Correction of a bug that did not let you import another file while one
% was already loaded making it mandatory to quit VS2 between files.
% - New Random import that will automatically ask and reload another file
% randomly from the batch selected during the first import.
% - Added a menu to directly access the reduce file size (useful for files
% from INTAN recordings).
% - Correction of a 3bug that did not correctly show the last epoch of the
% scoring and the xlim of the main plot.
% - Retrocompatibility with the files containing old variable t
% - Add a failsafe if the scoring is not saved and the windows is closed
% (Najma will not loose scoring again)
% -Added a f epoch that can be use for whatever like drawziness or else.
% The color is the wonderful purple because it's Najma's
%- Fixed a bug that prevented to edit file Infos because of the new
%configuration field containing the Intan configuration for the specific
%animals.

% Romain Cardis 2021

%clear h
%close all
%clc

%% create main figure and menus
h = struct();
h.updt = '1.5';
h = VS2_display(h);

%% set menu callbacks

h.mainFig.CloseRequestFcn = @SureToClose;
h.issaved = 1;

% File
h.fileMenu_import.Callback = @importOne;
h.fileMenu_save.Callback = @saveScoring;
h.fileMenu_editInfo.Callback = @editInfos;
h.fileMenu_importrandom.Callback = @importRand;
h.fileMenu_reduce.Callback = @reduceFile;

% Traces
h.tracesMenu_bipol.Callback = @bipol;
h.tracesMenu_filt.Callback = @filt;
h.tracesMenu_lockYlim.Callback = @lockYlim;
h.tracesMenu_ChangeGain.Callback = @changeGain1000;
h.tracesMenu_notch.Callback = @notching;
h.tracesMenu_Supress.Callback = @supressTraces;
h.tracesMenu_swapTraces.Callback = @swapT;
h.tracesMenu_reverse.Callback = @reverseAll;
h.tracesMenu_origain.Callback = @origain;

% Tools
h.toolsMenu_autoScore.Callback = @launchAuto;
h.toolsMenu_nameTraces.Callback = @reloadNames;
h.toolsMenu_takeSnap.Callback = @takeSnap;

% Width
h.widthMenu_8.Callback = @changeWidth;
h.widthMenu_16.Callback = @changeWidth;
h.widthMenu_24.Callback = @changeWidth;
h.widthMenu_32.Callback = @changeWidth;
h.widthMenu_40.Callback = @changeWidth;
h.widthMenu_48.Callback = @changeWidth;
h.widthMenu_96.Callback = @changeWidth;
h.widthMenu_384.Callback = @changeWidth;
% fishy

%% set keyboard function
h.mainFig.KeyPressFcn = @key;

%% callback functions

    function SureToClose(~,~)
        if h.issaved == 0
            an = questdlg('It seems you did not save your scoring, you are risking loosing it all like Najma once! Are you sure to close?', 'CAREFUL!','Yes, my scoring is worthless.', 'No wait! I will save!', 'No wait! I will save!');
            if strcmp(an, 'Yes, my scoring is worthless.')
                delete(h.mainFig)
            end
        else
            delete(h.mainFig)
        end
    end

    function reduceFile(~,~)
        ReduceBTfileSize(h.file)
    end

    function origain(~,~)
        h.bigplot.backToGain()
    end
    
    function takeSnap(~,~)
        figure
        f = axes();
        for i = 1:length(h.bigplot.graphLines)
            copyobj(h.bigplot.graphLines{i}, f)
        end
        title(h.filen)
        f.TickDir = 'out';
    end

    function swapT(~,~)
        h.bigplot.swapTraces();
    end

    function supressTraces(~,~)  
        h.bigplot.supressTraces()
    end
    
    function reloadNames(~,~)
        varInfo = who(h.file);
        if ismember('Infos',varInfo)
            Infos = h.file.Infos;
            if isfield(Infos,'Channel')
                chanames = Infos.Channel;
                h.Channel = strsplit(chanames(~isspace(chanames)),',');
                h.bigplot.ChannelNames = h.Channel;
                h.bigplot.initiateNames()
            end
        end
    end

    function editInfos(~,~)
        varInfo = who(h.file);
        action = questdlg('Edit current Infos or add a new field?', 'There should be a better way no?', 'Edit', 'New', 'Edit');
        switch action
            case 'Edit'
                if ismember('Infos',varInfo)
                    Infos = h.file.Infos;
                    nam = fieldnames(Infos);
                    df = struct2cell(Infos);
                    ifc = find(strcmp(nam,'Configuration'));
                    conf = df{ifc};
                    nam(ifc) = [];
                    df(ifc) = [];
                    n = cellfun(@ischar, df);
                    df(~n) = cellfun(@num2str, df(~n),'UniformOutput',false);
                    an = inputdlg(nam, 'Edit Infos', [1,40], df);
                    if ~isempty(an)
                         nInfos = cell2struct(an,nam);
                         if ~isempty(ifc)
                            nInfos.Configuration = conf;
                         end
                         h.file.Infos = nInfos;
                    end
                else
                    errordlg('There is no Infos variable in the file!')
                end
                
            case 'New'
                if ismember('Infos',varInfo)
                    Infos = h.file.Infos;
                else
                    Infos = struct;
                end
                an = inputdlg({'New field name', 'Field content'}, 'Edit Infos', [1,40]);
                Infos.(char(an{1})) = an{2};
                h.file.Infos = Infos;
        end
    end

    function changeGain1000(~,~)
        an = questdlg('Plus or minus?','Quite dumb to ask like that no?','plus','minus','minus');
        h.bigplot.changeGain(an,1000);
    end

    function lockYlim(obj,~)
        if strcmp(obj.Checked, 'on')
            obj.Checked = 'off';
            h.bigplot.lockYlim = 0;
        else
            obj.Checked = 'on';
            h.bigplot.lockYlim = 1;
        end
        
    end

    function reverseAll(~,~)
        h.b = h.bigplot.giveMeB();
        posi = h.bigplot.position;
        wi = h.bigplot.width;
        delete(h.bigplot.plotax)
        delete(h.bigplot.hypno)
        delete(h.bigplot.localhypno)
        h.bigplot = VS2_tracesPlot(h,posi,wi);
        h.bigplot.updatePlot()
    end

    function saveScoring(~,~)
        b = h.bigplot.giveMeB();
        h.file.b = b;
        h.file.bTrans = h.bigplot.realTrans;
        h.issaved = 1;
        if strcmp(h.filen(end-5), 'b') == 0
            if strcmp(h.filen(end-4), 't') == 1
                movefile([h.path,h.filen],[h.path,h.filen(1:end-6),'_bt.mat'],'f')
                h.filen = [h.filen(1:end-6),'_bt.mat'];
            else
                movefile([h.path,h.filen],[h.path,h.filen(1:end-4),'_bt.mat'],'f')
                h.filen = [h.filen(1:end-4),'_bt.mat'];
            end
        end
        h.file = matfile([h.path, h.filen], 'writable', true);
        m = msgbox('Saved!');
        waitfor(m)
        if h.rand == 1 && h.curRandFile < length(h.filebatch)
            an = questdlg('Do you want to stay blind and import the next random file?', 'Keep it blind!', 'Yes, I''m a good scientist', 'No I want to cheat', 'Yes, I''m a good scientist');
            if strcmp(an, 'Yes, I''m a good scientist')
                h.curRandFile = h.curRandFile +1;
                h.filen = h.filebatch{h.randOrder(h.curRandFile)};
                import
            end
        elseif h.rand == 1
            msgbox('You are done with this batch. CONGRATS!')
            h.fileMenu_importrandom.Enable = 'on';
            h.fileMenu_import.Enable = 'on';
        end
    end
    
    function importRand(~,~)
        [h.filebatch, pathf] = uigetfile('*.mat','Select multiple files and i''ll choose one','multiselect','on');       
        if iscell(h.filebatch)
            h.randOrder = datasample(1:length(h.filebatch), length(h.filebatch),'Replace',false);
            h.curRandFile = 1;
            h.filen = h.filebatch{h.randOrder(h.curRandFile)};
            h.path = pathf;
            h.rand = 1; % means rand is active
            h.fileMenu_import.Enable = 'off';
            h.fileMenu_importrandom.Enable = 'off';
            import
        else
            if h.filebatch == 0; return; end
            errordlg('You need to select multiple files and I''ll choose one randomly.')
        end
    end
    
    function importOne(~,~)
        h.rand = 0;
        import  
    end
    
    function import(~,~)
        % function to import a file into the software and create the plots
        if h.rand == 0
            [filen, pathf] = uigetfile('*.mat','Select your file to score');
            if filen == 0; return; end
            h.filen = filen;
            h.path = pathf;
        end
        w = waitbar(0,'Your file is being loaded');
        h.file = matfile([h.path, h.filen], 'writable', true);
        try
            traces = h.file.traces;
        catch
            t = h.file.t;
            traces = [t(1:end/2);t(end/2+1:end)];
        end
        
        if max(traces(end,:)) > 3
            traces(end,:) = traces(end,:)/4000; % if it's a stimulation trace
        end
        if h.rand == 0
            h.mainFig.Name = ['VeryScore2 v', h.updt,' - Scoring file: ',h.filen];
        else
            h.mainFig.Name = ['VeryScore2 v', h.updt,' - Scoring file: RANDOM! HA!'];
        end
        varInfo = who(h.file);
        
        % Get sampling rate
        if ismember('Infos',varInfo)
            Infos = h.file.Infos;
            if isfield(Infos,'Fs')
                sr = Infos.Fs;
                if ischar(sr)
                    sr = str2double(sr);
                end
            else
                sr = questdlg('What is the sampling rate of the traces?', 'Please inform', '200 Hz', '1000 Hz', '200 Hz');
                sr = strsplit(sr,' ');
                sr = str2double(sr{1});
                Infos.Fs = num2str(sr);
                h.file.Infos = Infos;
            end
            if isfield(h,'Channel') % in case the Channel field is still present from a previous file.
                h = rmfield(h, 'Channel');
            end
            if isfield(Infos,'Channel')
                chanames = Infos.Channel;
                h.Channel = strsplit(chanames(~isspace(chanames)),',');
            end
        else
            sr = questdlg('What is the sampling rate of the traces?', 'Please inform', '200 Hz', '1000 Hz', '200 hz');
            sr = strsplit(sr,' ');
            sr = str2double(sr{1});
            Infos = struct('Fs',num2str(sr));
            h.file.Infos = Infos;
        end
        deciFactor = sr/200;
        [si,~] = size(traces); 
        h.tra = [];
        for i = 1:si
            waitbar(i/si,w)
            ntra = decimate(traces(i,:),deciFactor,'fir');
            if max(ntra > 0.08) % it's likely a stimulation trace 0-3.3 V
                ntra = ntra/1000;  
            end
            h.tra = [h.tra; ntra]; % set gain here in case you lost
        end
        clear('traces')
        close(w)
        if ismember('b', varInfo)
            h.b = h.file.b;
        else
            h.b = repmat('b', 1, floor(length(h.tra)/800));
        end
  
        if isfield(h,'bigplot')
            delete(h.bigplot.plotax)
            delete(h.bigplot.hypno)
            delete(h.bigplot.localhypno)
        end
        
        h.bigplot = VS2_tracesPlot(h,1,10);
        
        if ismember('bTrans', varInfo)
            h.bigplot.realTrans = h.file.bTrans;
        end
        
        % Activate Menus
        h.fileMenu_save.Enable = 'on';
        h.toolsMenu.Enable = 'on';
        h.tracesMenu.Enable = 'on';
        h.widthMenu.Enable = 'on';
        h.fileMenu_editInfo.Enable = 'on';
        h.fileMenu_reduce.Enable = 'on';
    end

% autoscore
    function launchAuto(~,~)
        h.bigplot.autoscore()
    end

% Change width function
    function changeWidth(obj,~)
        h.widthMenu_8.Checked = 'off';
        h.widthMenu_16.Checked = 'off';
        h.widthMenu_24.Checked = 'off';
        h.widthMenu_32.Checked = 'off';
        h.widthMenu_40.Checked = 'off';
        h.widthMenu_48.Checked = 'off';
        h.widthMenu_96.Checked = 'off';
        h.widthMenu_384.Checked = 'off';
        newWidth = obj.UserData;
        obj.Checked = 'on';
        h.bigplot.changeWidth(newWidth)
    end

%% Traces functions
    function bipol(~,~)
        h.bigplot.bipolarize()
    end

    function filt(~,~)
        req = questdlg('Choose y''a type o''filter', 'Choose one', 'High-pass 0.75Hz', 'High-pass 25 Hz', 'Low-pass 25 Hz', 'High-pass 0.75Hz');
        switch req
            case 'High-pass 0.75Hz'; [a,b] = cheby2(7,40, 0.75/100, 'high');
            case 'High-pass 25 Hz'; [a,b] = cheby2(7,40, 25/100, 'high');
            case 'Low-pass 25 Hz'; [a,b] = cheby2(7,40, 25/100, 'low');
        end
        h.bigplot.filterTrace(a,b)
    end

    function notching(~,~)
        req = questdlg('Choose y''a type o''notch', 'Choose one', '50 Hz', '60 Hz', '50 Hz');
        switch req
            case '50 Hz'; [a,b] = cheby2(7,40, [46,54]/100, 'stop');
            case '60 Hz'; [a,b] = cheby2(7,40, [56,64]/100, 'stop');
        end
        h.bigplot.filterTrace(a,b)
    end

%% Navigation functions
    function goPrev(~,~)
        pos = h.bigplot.position;
        if pos-1 > 0
            h.bigplot.position = pos-1;
        end
        h.bigplot.updatePlot()
    end

    function goNext(~,~)
        pos = h.bigplot.position;
        if pos+1 <= length(h.b)
            h.bigplot.position = pos+1;
            h.bigplot.updatePlot()
        end
    end

%% Keyboard shortcut
    function key(~,evnt)%works only when datacursor mode is off
        if strcmp(evnt.Modifier, 'shift') == 1
            switch evnt.Key
                case 'uparrow'; h.bigplot.moveTrace('up')
                case 'downarrow'; h.bigplot.moveTrace('dn')
                case 'w'; h.bigplot.goTrans('nextW')
                case 'n'; h.bigplot.goTrans('nextN')
                case 'r'; h.bigplot.goTrans('nextR')
                case 'm'; h.bigplot.goTrans('nextM')
                case 'f'; h.bigplot.goTrans('nextF')
            end
        elseif strcmp(evnt.Modifier, 'control') == 1 
            switch evnt.Key
                case 'z'; disp('not there yet')
            end
        else
            switch evnt.Key
                case 'a'; goPrev()
                case 'd'; goNext()
                case 'uparrow'; h.bigplot.changeGain('plus',1)
                case 'downarrow'; h.bigplot.changeGain('minus',1)
                case 'w'; h.bigplot.changeB('w'); h.issaved = 0;             
                case '1'; h.bigplot.changeB('1'); h.issaved = 0;
                case 'n'; h.bigplot.changeB('n'); h.issaved = 0;            
                case '2'; h.bigplot.changeB('2'); h.issaved = 0;
                case 'r'; h.bigplot.changeB('r'); h.issaved = 0;
                case '3'; h.bigplot.changeB('3'); h.issaved = 0;
                case 'leftarrow'; h.bigplot.goTrans('prev')
                case 'rightarrow'; h.bigplot.goTrans('next')
                case 'm'; h.bigplot.changeB('m'); h.issaved = 0;
                case 'f'; h.bigplot.changeB('f'); h.issaved = 0;
                    % here to custom epochs
            end
        end
    end

end
