classdef Y2R_recSettings < handle
    %Y2R_RECSETTINGS To ask for the configurations specifics
    
    properties
        
        display
        config
        startAt
        nFiles
        fileLength
        forground = 'black'
        background = 'white'
        police = 'Arial'
        
    end
    
    methods
        
        function obj = Y2R_recSettings(setfig, conf)
            
            settingPanel = uipanel('parent', setfig,...
                'FontName', obj.police,...
                'ForegroundColor', obj.forground,...
                'backgroundcolor',    obj.background,...
                'units',              'normalized',...
                'position',           [0.05 0.05 0.9 0.9],...
                'title',              'Settings');
            
            %Read conf label
            uicontrol('parent', settingPanel,...
                'FontName', obj.police,...
                'ForegroundColor', obj.forground,...
                'style', 'text',...
                'unit', 'normalized',...
                'position', [.04,.8,.45,.1],...
                'string', 'Read configuration : ',...
                'horizontalalignment','right',...
                'backgroundcolor', obj.background);
            
            obj.display.config = uicontrol('parent', settingPanel,...
                'FontName', obj.police,...
                'ForegroundColor', obj.forground,...
                'style', 'popup',...
                'unit', 'normalized',...
                'position', [.52,.82,.4,.1],...
                'string', conf.confList,...
                'backgroundcolor', obj.background);
            
            %start at
            uicontrol('parent', settingPanel,...
                'FontName', obj.police,...
                'ForegroundColor', obj.forground,...
                'style', 'text',...
                'unit', 'normalized',...
                'position', [.04,.6,.45,.1],...
                'string', 'Start at : ',...
                'horizontalalignment','right',...
                'backgroundcolor', obj.background);
            
            nextday = datestr(addtodate(now,1,'day'));
            nextday = [nextday(1:12),'09:00:00'];
            
            obj.display.startAt = uicontrol('parent', settingPanel,...
                'FontName', obj.police,...
                'ForegroundColor', obj.forground,...
                'style', 'edit',...
                'unit', 'normalized',...
                'position', [.52,.62,.4,.1],...
                'string', nextday,...
                'backgroundcolor', obj.background);
            
            %number of files
            uicontrol('parent', settingPanel,...
                'FontName', obj.police,...
                'ForegroundColor', obj.forground,...
                'style', 'text',...
                'unit', 'normalized',...
                'position', [.04,.4,.45,.1],...
                'string', 'Number of files : ',...
                'horizontalalignment','right',...
                'backgroundcolor', obj.background);
            
            obj.display.nFiles = uicontrol('parent', settingPanel,...
                'FontName', obj.police,...
                'ForegroundColor', obj.forground,...
                'style', 'edit',...
                'unit', 'normalized',...
                'position', [.52,.42,.4,.1],...
                'string', '1',...
                'backgroundcolor', obj.background);
            
            %file length
            uicontrol('parent', settingPanel,...
                'FontName', obj.police,...
                'ForegroundColor', obj.forground,...
                'style', 'text',...
                'unit', 'normalized',...
                'position', [.04,.2,.45,.1],...
                'string', 'File length (h) : ',...
                'horizontalalignment','right',...
                'backgroundcolor', obj.background);
            
            obj.display.fileLength = uicontrol('parent', settingPanel,...
                'FontName', obj.police,...
                'ForegroundColor', obj.forground,...
                'style', 'edit',...
                'unit', 'normalized',...
                'position', [.52,.22,.4,.1],...
                'string', '1',...
                'backgroundcolor', obj.background);
            
            obj.display.ok1 = uicontrol('parent', settingPanel,...
                'FontName', obj.police,...
                'ForegroundColor', obj.forground,...
                'style', 'pushbutton',...
                'unit', 'normalized',...
                'string', 'Validate',...
                'Callback', @obj.validate,...
                'backgroundcolor', obj.background,...
                'position', [.2 .05 0.2 0.1]);
            
            obj.display.ok2 = uicontrol('parent', settingPanel,...
                'FontName', obj.police,...
                'ForegroundColor', obj.forground,...
                'style', 'pushbutton',...
                'unit', 'normalized',...
                'string', 'Start now',...
                'Callback', @obj.immediate,...
                'backgroundcolor', obj.background,...
                'position', [.6 .05 0.2 0.1]);
            
        end
        
        function validate(obj,~,~)
            obj.config = obj.display.config.Value;
            obj.startAt = obj.display.startAt.String;
            obj.nFiles = str2double(obj.display.nFiles.String);
            obj.fileLength = str2double(obj.display.fileLength.String);
            close('Settings')
        end
        
        function immediate(obj,~,~)
            obj.config = obj.display.config.Value;
            obj.startAt = 'now';
            obj.nFiles = str2double(obj.display.nFiles.String);
            obj.fileLength = str2double(obj.display.fileLength.String);
            close('Settings')
        end
      
        
    end
    
end

