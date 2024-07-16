classdef Ypnos_Panel1000hz < handle
    
    %YPNOS_PANEL Is a panel used for one animal
    %this one is not based on scoring but on delta/theta ratio and value of
    %normalized amplitude of EMG based on min and max value detected for
    %each seconds.
    
    properties
        
        panel
        Vposition
        aNumber
        
        lastSecAx
        eegData = zeros(1,4000);
        eegLine
        emgData = zeros(1,4000);
        emgLine
        cheAlow
        cheBlow
        
        deltathetaAx
        delTheLine
        
        emgAx
        emgValLine
        emgMax
        emgMin
        cheA
        cheB
        
        stateLabel
        colorState = {[0.6350 0.0780 0.1840],[0.4660 0.6740 0.1880],[0.9290 0.6940 0.1250]}
        stringState = {'Wake','NREM','REM'}
        
        flagValue = 0
        
        curentState = 1 % wake
        
        % Give threshold here
        transEMG = 0.4
        transEMGlow = 0.2
        transNREM = 1
        transREM = 0.5
        
    end
    
    methods
        
        %% __INIT__ function
        
        function obj = Ypnos_Panel1000hz(fig, Vpos, aNum)
            
            [obj.cheAlow, obj.cheBlow] = cheby2(3,40,[0.7,100]/500);
            [obj.cheA, obj.cheB] = cheby2(3,40,20/500,'high');
            
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
            
            
            obj.lastSecAx = axes('parent', obj.panel,...
                'box', 'off',...
                'tickdir', 'out',...
                'color', 'black',...
                'XColor', 'white',...
                'YColor', 'white',...
                'unit', 'normalized',...
                'position', [.1 .25 .2 .7]);
            
            xlabel('Time (s)','FontSize',8)
            
            Xaxis = linspace(-4,0,4000);
            
            obj.eegLine = line(Xaxis, obj.eegData,...
                'parent', obj.lastSecAx);
            
            obj.emgLine = line(Xaxis, obj.emgData,...
                'parent', obj.lastSecAx,...
                'color',    [0.8500 0.3250 0.0980]);
            
            ylim([-0.0005,0.0005])
            
            obj.deltathetaAx = axes('parent', obj.panel,...
                'box', 'off',...
                'tickdir', 'out',...
                'color', 'black',...
                'XColor', 'white',...
                'YColor', 'white',...
                'unit', 'normalized',...
                'position', [.35 .25 .2 .7]);
            
            obj.delTheLine = line(-4:0, zeros(1,5),...
                'parent', obj.deltathetaAx);
            
            ylim([0,4])
            line([-4,0], [obj.transNREM,obj.transNREM], 'color', 'white')
            line([-4,0], [obj.transREM,obj.transREM], 'color', 'white')
            xlabel('Time (s)','FontSize',8)
            
            obj.emgAx = axes('parent', obj.panel,...
                'box', 'off',...
                'tickdir', 'out',...
                'color', 'black',...
                'XColor', 'white',...
                'YColor', 'white',...
                'unit', 'normalized',...
                'position', [.60 .25 .2 .7]);
            
            obj.emgValLine = line(-4:0, zeros(1,5),...
                'parent', obj.emgAx,...
                'color', [0.8500 0.3250 0.0980]);
            
            line([-4,0], [obj.transEMG,obj.transEMG], 'color', 'white')
            line([-4,0], [obj.transEMGlow,obj.transEMGlow], 'color', 'white')
            ylim([0,1])
            xlabel('Time (s)','FontSize',8)
            
            obj.stateLabel = uicontrol('parent', obj.panel,...
                'FontName', 'Monospaced',...
                'ForegroundColor', 'white',...
                'style', 'text',...
                'unit', 'normalized',...
                'FontSize', 20,...
                'position', [.87, .4, .1, .2],...
                'string', 'Wake',...
                'horizontalalignment','center',...
                'backgroundcolor', obj.colorState{1});
            
        end
        
        %% other Methods
        
        function update(obj, toAdd)
            % To update the data stored every new datablock (60 ms) and the
            % content of the plot of raw data
            ee = toAdd(1,:); 
            em = filtfilt(obj.cheA, obj.cheB, toAdd(2,:)); % highpass emg at 20 Hz

            % update the current last 4 second with the new datablock
            obj.eegData = [obj.eegData(61:end), ee];
            obj.emgData = [obj.emgData(61:end), em];
            
        end
        
        function st = checkState(obj)
            % checkstate updates the plots and check which in which state is the animal
            
            % update the raw data plot with the new data with an offset
            % between eeg and emg
            
            filEEG = filtfilt(obj.cheAlow,obj.cheBlow,obj.eegData); % HighPass the current epoch eeg over 0.75 hz
            obj.eegLine.YData = filEEG + 0.00025;
            obj.emgLine.YData = obj.emgData - 0.00025;
            
            % calculate the delta theta ratio and update the plot
            epoch = filEEG-mean(filEEG);
            epoch = [epoch(end-1999:end), fliplr(epoch(end-1999:end))];
                 
            % using fft
            lafft = abs(fft(epoch)).^2;
            delta = mean(lafft(5:17));
            theta = mean(lafft(25:37));
            
            ratio = delta/theta;
            obj.delTheLine.YData = [obj.delTheLine.YData(2:end), ratio];
            
            % calculate the emg value and ajust the normalization (min/max)
            % Get the new min and max if there is
            
            emg = abs(obj.emgData(end-1000:end)).^2; % last second of EMG, absolute^2;
            emgv = median(log10(emg));
            
            st = [0;0;0];
            
            if isinf(emgv) == 0 && obj.flagValue == 0 % the case of the first point without enough data
                obj.emgMax = emgv;
                obj.emgMin = emgv;
                obj.flagValue = 1;
            elseif obj.flagValue == 1 % when it's running and got data
                obj.emgMax = max([emgv,obj.emgMax]);
                obj.emgMin = min([emgv,obj.emgMin]);
                
                emgNo = (emgv-obj.emgMin) / (obj.emgMax-obj.emgMin);
                obj.emgValLine.YData = [obj.emgValLine.YData(2:end), emgNo];
                
                r = obj.delTheLine.YData > obj.transNREM;
                m = obj.emgValLine.YData > obj.transEMG; % 1 if it's high
                rR = obj.delTheLine.YData > obj.transREM; %rR is used for transition to REM. More stringent cause for REM theta is higher than delta
                ml = obj.emgValLine.YData > obj.transEMGlow; % ml for very low emg to detect REM
                
                switch obj.curentState
                    case 1 % wake
                        if sum(m(3:5)) == 0 && sum(r(2:5)) >= 3 % if the last 3 sec of muscle activity are low and the ratio was high for 2 out of the last 3 sec
                            obj.curentState = 2;
                            updateState(2)
                        elseif sum(ml) == 0 && sum(rR) == 0
                            obj.curentState = 3;
                            updateState(3)
                        end
                        
                    case 2
                        if sum(m(5)) == 1 % If the last 1 sec of emg are high, then it's wake
                            obj.curentState = 1;
                            updateState(1)
                        elseif sum(ml(3:5)) == 0 && sum(rR) <= 3 && sum(r) == 0  % if emg is very low for the last 3 sec and the ratio is low for the last 4 sec + very low for at least 2 points
                            obj.curentState = 3; 
                            updateState(3)
                        end
                        
                    case 3
                        if sum(m(5)) == 1 % If the last 1 sec of emg are high, then it's wake
                            obj.curentState = 1;
                            updateState(1)
                        elseif sum(r) >= 5 % if the ratio (delta higher) for more than 5 seconds it might be NREM again
                            obj.curentState = 2;
                            updateState(2)
                        end
                        
                end
                
                st = [obj.curentState;ratio;emgNo];
                
            end
            
            function updateState(state)
                obj.stateLabel.String = obj.stringState{state};
                obj.stateLabel.BackgroundColor = obj.colorState{state};
            end
            
        end
               
    end
        
end


