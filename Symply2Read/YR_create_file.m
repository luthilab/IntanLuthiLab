function   [h] = YR_create_file(h, board, folder_name)
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here

switch h.typeOfFile
    case '.rhd'
        tempname = [h.pF_editFileName.String, '_1.rhd'];
        tempfile = fullfile(folder_name, tempname);
        board.SaveFile.Note1 = ['recording start: ',h.recStartvalue.String];
        board.SaveFile.open(rhd2000.savefile.Format.intan, tempfile);
    case '.mat'
        an = sum(cellfun('isempty',(h.traceIndex)));%how many analog channels
        if an>0
            traces = zeros(length(cell2mat(h.traceIndex))+an, 12*3600*1000); %#ok<PREALL>
        else
            traces = zeros(length(cell2mat(h.traceIndex)), 12*3600*1000); %#ok<NASGU>
        end
        info = struct();
        info.start = ['recording start: ',h.recStartvalue.String];
        info.samplingRate = h.setSF.String; %#ok<STRNU>
        tempfile = cell(1,h.chipID);
        traceIndex = h.traceIndex;
        traceName = h.traceName;
        for i = 1:h.chipID
            tempname = [h.pF_editFileName.String,'_Animal', num2str(i), '_1.mat'];
            tempfile{i} = fullfile(folder_name, tempname);
            save(tempfile{i}, 'traces','info', 'traceIndex', 'traceName', '-v7.3')
            h.matFile{i} = matfile(tempfile{i},'Writable',true);
        end
        
    case 'both (such greed)'
        
end
end

