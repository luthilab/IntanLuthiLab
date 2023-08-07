classdef Ypnos_Panelv1 < handle
    %YPNOS_PANEL Is a panel used for one animal
    
    properties
        
        panel
        Vposition
        aNumber
        checkActiv
        browse
        fileName
        lastSecAx
        fftAx
        probaAx
        state
        eegLine
        emgLine
        fftLine
        eegData
        emgData
        fftData
        scoredFile
        meansStates
        cheA
        cheB
        curentState = 1 % wake
        colorstate = {'red','green','yellow'}
        stringstate = {'Wake','NREM','REM'}
    end
    
    methods
        
        %% __INIT__ function
        
        function obj = Ypnos_Panel(fig, Vpos, aNum)
            [obj.cheA, obj.cheB] = cheby2(3,40,10/500,'high');
            obj.Vposition = Vpos;
            obj.aNumber = aNum;
            
            obj.panel = uipanel('parent', fig,...
                'FontName',           'Monospaced',...
                'FontSize',           12,...
                'ForegroundColor',    'white',...
                'backgroundcolor',    'black',...
                'units',              'normalized',...
                'position',           [.05, Vpos, .9, .2],...
                'title',              ['Animal ', num2str(aNum)]);
            
%             obj.checkActiv = uicontrol('parent', obj.panel,...
%                 'FontName', 'Monospaced',...
%                 'ForegroundColor', 'white',...
%                 'style', 'checkbox',...
%                 'Value',1,...
%                 'unit', 'normalized',...
%                 'position', [.02,.7,.05,.1],...
%                 'string', 'Active ',...
%                 'horizontalalignment','right',...
%                 'backgroundcolor', 'black',...
%                 'callback', @obj.activatePanel);
            
            obj.browse = uicontrol('style', 'pushbutton',...
                'FontName', 'Monospaced',...
                'ForegroundColor', 'white',...
                'parent',           obj.panel,...
                'units',            'normalized',...
                'position',         [.02 .2 0.025 0.1],...
                'string',           '...',...
                'callback',         @obj.browseFile,...
                'backgroundcolor',  'black');
            
            obj.fileName = uicontrol('parent', obj.panel,...
                'FontName', 'Monospaced',...
                'ForegroundColor', 'white',...
                'style', 'text',...
                'unit', 'normalized',...
                'position', [.02, .4, .07, .2],...
                'string', sprintf('Choose a\nscored file'),...
                'horizontalalignment','left',...
                'backgroundcolor', 'black');
            
            obj.lastSecAx = axes('parent', obj.panel,...
                'box', 'off',...
                'tickdir', 'out',...
                'color', 'black',...
                'XColor', 'white',...
                'YColor', 'white',...
                'unit', 'normalized',...
                'position', [.15 .25 .2 .7]);
            
            xlabel('Time (s)','FontSize',8)
            
            Xaxis = linspace(-4,0,400);
            
            obj.eegData = zeros(1,400)+0.00025;
            obj.eegLine = line(Xaxis, obj.eegData,...
                'parent', obj.lastSecAx);
            
            obj.emgData = zeros(1,400)-0.00025;
            obj.emgLine = line(Xaxis, obj.emgData,...
                'parent', obj.lastSecAx,...
                'color',    [0.8500 0.3250 0.0980]);
            ylim([-0.0005,0.0005])
            
            obj.fftAx = axes('parent', obj.panel,...
                'box', 'off',...
                'tickdir', 'out',...
                'color', 'black',...
                'XColor', 'white',...
                'YColor', 'white',...
                'unit', 'normalized',...
                'position', [.4 .25 .2 .7]);
            
            
            Hz = linspace(0,1,((100*2)/2)+1)*50;
            obj.fftData = zeros(1,length(Hz));
            obj.fftLine = line(Hz, obj.fftData,...
                'parent', obj.fftAx);
            xlabel('Frequency (Hz)','FontSize',8)
            
            obj.probaAx = axes('parent', obj.panel,...
                'box', 'off',...
                'tickdir', 'out',...
                'color', 'black',...
                'XColor', 'white',...
                'YColor', 'white',...
                'unit', 'normalized',...
                'position', [.65 .25 .2 .7]);
            
            xlabel('Time (s)','FontSize',8)
            
            obj.state = uicontrol('parent', obj.panel,...
                'FontName', 'Monospaced',...
                'ForegroundColor', 'white',...
                'style', 'text',...
                'unit', 'normalized',...
                'FontSize', 20,...
                'position', [.87, .4, .1, .2],...
                'string', 'Wake',...
                'horizontalalignment','center',...
                'backgroundcolor', 'red');
        end
        
        %% other Methods
        
%         function obj = activatePanel(obj,src,~)
%             % Used to activate of deactivate the animals panels
%             if get(src,'Value') == 1
%                 obj.panel.ForegroundColor = [1 1 1];
%                 obj.panel.HighlightColor = [1 1 1];
%                 src.String = 'Active';
%             else
%                 obj.panel.ForegroundColor = [.2 .2 .2];
%                 obj.panel.HighlightColor = [.2 .2 .2];
%                 src.String = 'Inactive';
%             end
%         end
        
        function obj = browseFile(obj,~,~)
            userID = getenv('username');
            tempdir = ['C:\Users\', userID, '\Documents'];
            [f,p] = uigetfile(tempdir);
            obj.scoredFile = [p,f];
            obj.fileName.String = f;
        end
        
        function update(obj, toAdd)
            ee = decimate(toAdd(1,:),10) + 0.00025;
            ema = filtfilt(obj.cheA, obj.cheB, toAdd(2,:));
            em = decimate(ema,10) - 0.00025;
            obj.eegData = [obj.eegData(7:end), ee];
            obj.emgData = [obj.emgData(7:end), em];
            
            obj.eegLine.YData = obj.eegData;
            obj.emgLine.YData = obj.emgData;
            
            addfft = smooth(abs(fft(obj.eegData(201:end)-mean(obj.eegData(201:end)))),20)';
            obj.fftData = addfft(1:101);
            obj.fftLine.YData = obj.fftData;
            
        end
        
        function obj = extractScore(obj)
            mf = matfile(obj.scoredFile);
            wtri = strfind(mf.b, 'www');
            ntri = strfind(mf.b, 'nnn');
            rtri = strfind(mf.b, 'rrr');
            %art = strfind(mf.b, '1');
            si = size(mf, 't');
            si = si(2);
            eeg = decimate(mf.t(1,1:si/2),2);
            [a,b] = cheby2(3,40,10/100,'high');
            emg = filtfilt(a, b, mf.t(1,(si/2)+1:si));
            emg = decimate(emg,2);
            
            wMeans = extractMeans(wtri, eeg, emg); 
            nMeans = extractMeans(ntri, eeg, emg);
            rMeans = extractMeans(rtri, eeg, emg);
            %artMeans = extractMeans(art, eeg, emg);
            
            obj.meansStates = [wMeans(1),nMeans(1),rMeans(1);...
                wMeans(2),nMeans(2),rMeans(2)]; % the means are arranged to have the [w,n,r;w,n,r] 1,: is eeg 2,: is emg
            
        end
        
        function st = checkState(obj)
            %need to extract values from the last 2 sec        
            
            lafft = obj.fftData;
            delta = mean(mean(lafft(:,3:9))); % delta from 1-4Hz
            theta = mean(mean(lafft(:,10:21))); %theta from 4.5-10Hz
            delthe = repmat(delta/theta,1,3);
            
            %get the closest match for delta/theta se is the state based on
            %eeg only
            
            [~,se] = min(abs(diff([delthe; obj.meansStates(1,:)])));
            
            % get the emg value and find the closest match sm is emg value
            
            emg = obj.emgData(end-199:end); %last 200 points
            emg = (emg-mean(emg))+1; % +1 because I have trouble with log distributions...
            emgVal = repmat(std(emg)^2, 1, 3); %repmat(mean(abs(log(emg.^2))),1,3);
            
            [~,sm] = min(abs(diff([emgVal; obj.meansStates(2,:)])));
            if sm == 3
                sm = 2; %because the emg should not differ too much between NREM and REM
            end
            
            switch obj.curentState  % Case where it's wake before
                case 1
                    if sm == 2 && se == 2
                        obj.curentState = 2;
                    end
                case 2 % Case where it's NREM before
                    if se == 3 && sm == 2
                        obj.curentState = 3;
                    elseif se == 1 && sm == 1
                        obj.curentState = 1;
                    end
                case 3 % Case where it's REM before
                    if sm == 1
                        obj.curentState = 1;
                    end
            end
                        
            obj.state.BackgroundColor = obj.colorstate{obj.curentState};
            obj.state.String = obj.stringstate{obj.curentState};
            st = [obj.curentState;delthe(1);emgVal(1)];
        end
        
    end
    
end

function means = extractMeans(tri, eeg, emg)

sr = 100;
k = 1;
km = 1;
lesfft = zeros(length(tri)*2, 101);
mEMG = zeros(length(tri),1);

for i = tri   
    curEE = eeg((i-1)*sr*4+1:i*sr*4);
    curEM = emg((i-1)*sr*4+1:i*sr*4);
    
    curEM = (curEM-mean(curEM))+1; % +1 because I have trouble with log distributions...    
    mEMG(km) = std(curEM)^2; %mean(abs(log(curEM.^2)));
    km = km+1;
    for j = 1:2
        ee = curEE((j-1)*sr*2+1:j*sr*2);
        lafft = smooth(abs(fft(ee-mean(ee))),20);
        lesfft(k,:) = lafft(1:101); 
        k = k+1;
    end
end

% For a first try lets use ration delta/theta and emg level
%means = [mean(lesfft,1), repmat(mean(mEMG),1,50)];

delta = mean(mean(lesfft(:,3:9))); % delta from 1-4Hz
theta = mean(mean(lesfft(:,10:21))); %theta from 4.5-10Hz

means = [delta/theta,mean(mEMG)];

end
