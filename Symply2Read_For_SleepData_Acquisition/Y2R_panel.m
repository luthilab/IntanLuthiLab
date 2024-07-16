classdef Y2R_panel < handle
    %Y2R_PANEL Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        mainplot
        data
        dataLines
        offset = 0.0007
        dataMultiplier
        A
        B
        selectedLines
    end
    
    methods
        function obj = Y2R_panel(parent, ntra)
            %Y2R_PANEL initiation
            % cheby filter
            [obj.A, obj.B] = cheby2(4, 40, 0.7/500, 'high');
            obj.dataMultiplier = ones(ntra,1);
            
            % Mainplot
            obj.mainplot = axes('parent', parent,...
                'box', 'off',...
                'tickdir', 'out',...
                'color', 'white',...
                'XColor', 'black',...
                'YColor', 'none',...
                'unit', 'normalized',...
                'YLim', [-ntra*obj.offset-obj.offset, 0],...
                'position', [.05 .1 .8 .85]);
            xlabel('Time(s)') 
            
            obj.dataLines = gobjects(ntra);
            obj.selectedLines = false(ntra,1);
            y = zeros(1,10000);
            x = linspace(-10,0,10000);
            for i = 1:ntra
                obj.dataLines(i) = line('XData', x, 'YData', y-i*obj.offset,...
                    'color', [0, 0.4470, 0.7410],...
                    'UserData', i,...
                    'ButtonDownFcn', @obj.selected);
            end
            
            
            obj.data = zeros(ntra, 10000);
            
            % button gain -
            uicontrol(parent,...
                'unit', 'normalized',...
                'position', [.87 .85 .04 .07],...
                'String', '-',...
                'Fontsize', 25,...
                'Callback', @obj.Moffset,...
                'TooltipString', 'Decrease gain of selected traces.');
            
            % button gain .
            uicontrol(parent,...
                'unit', 'normalized',...
                'position', [.92 .85 .02 .07],...
                'String', '.',...
                'Callback', @obj.Moffset,...
                'Fontsize', 25,...
                'TooltipString', 'Restore gain of selected traces.');
            
            % button gain +
            uicontrol(parent,...
                'unit', 'normalized',...
                'position', [.95 .85 .04 .07],...
                'String', '+',...
                'Fontsize', 25,...
                'Callback', @obj.Moffset,...
                'TooltipString', 'Increase gain of selected traces.');
            
            % button snapshot
            uicontrol(parent,...
                'unit', 'normalized',...
                'position', [.87 .75 .12 .07],...
                'String', 'SnapShot',...
                'Callback', @obj.takeasnap,...
                'TooltipString', 'Take a snapshot of current 10 seconds with original gain');
        end
        
        %% Other methods
        function selected(obj,~,~)
            li = gco;
            sele = li.UserData;
            switch obj.selectedLines(sele)
                case 0
                    obj.dataLines(sele).Color = [0.85,0.33,0.10];
                    obj.selectedLines(sele) = 1;
                case 1
                    obj.dataLines(sele).Color = [0,0.447,0.741];
                    obj.selectedLines(sele) = 0;
            end
        end
            
        function takeasnap(obj, ~, ~)
            %To take a snapshot of the current data
            offs = linspace(0, obj.offset*(size(obj.data,1)+1), size(obj.data,1))';
            figure
            plot(linspace(-10,0,10000), obj.data-repmat(offs,1,10000))
            set(gca,'tickdir','out')
            box off
        end
        
        function Moffset(obj, src, ~)
            % To modify the gain of the selected traces
            switch src.String
                case '+'
                    obj.dataMultiplier(obj.selectedLines) = obj.dataMultiplier(obj.selectedLines) + 0.1;
                case '-'
                    nm = obj.dataMultiplier(obj.selectedLines) - 0.1;
                    nm(nm<0) = 0.01;
                    obj.dataMultiplier(obj.selectedLines) = nm;
                case '.'
                    obj.dataMultiplier(obj.selectedLines) = 1;
            end
        end
        
        function update(obj, toAdd, upplo)
            %METHOD to update the data and the plots if selected
            obj.data = [obj.data(:,61:end), toAdd];
            if upplo == 1
                for i = 1:size(toAdd,1)
                    %nd = filtfilt(obj.A, obj.B, obj.data(i,:))*obj.dataMultiplier(i);
                    nd = obj.data(i,:)*obj.dataMultiplier(i);
                    obj.dataLines(i).YData = nd - i*obj.offset;
                end
            end
        end
        
    end
end

