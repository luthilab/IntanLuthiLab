function renameFileToBt(varargin)
%RENAMEFILETOBT to rename the S2R or other files like I want
%
% input name must be in the format obtained with our recording softs:
% They MUST be like this. Otherwise it's unclear what would happen. If you
% dont have name2, name3 or name4 they should be _anything_ so that the
% separators exist. You should count 7 _ in the name of your files.
%
% date_name1_name2_name3_name4_condition_AnimalN_n

[Names, Path] = uigetfile('*.mat', 'Select your files to rename from intan to bt','multiselect', 'on');

for i = 1:length(Names)
    curnam = Names{i};
    sep = find(curnam == '_');
    
    if sep ~= 7; errordlg(['Your file ',curnam,' can not be renamed, it has not the right name format.']); continue; end
    
    phase = ['0',curnam(sep(7)+1:end-4)];
    nani = str2double(curnam(sep(7)-1));
    nam = curnam(sep(nani)+1:sep(nani+1)-1);
    cond = curnam(sep(5)+1:sep(6)-1);
    
    newname = [nam,'_',phase,'_',cond,'_t.mat'];
    
    movefile([Path,curnam], [Path,newname]);
end

end

