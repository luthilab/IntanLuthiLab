function [v_b,v_MA] = f_ElimMA(v_b);
% This function eliminates microarousals of 1, 2 and 3 epochs of 4 seconds 
% from the b vector from the scoring.
%
% See also f_b2Vec.
%
% Alejandro Osorio-Forero 2019
    
    v_b(strfind(v_b,'2'))='w';
    v_b(strfind(v_b,'m'))='w';
    v_MA1 = strfind(v_b,'nwn');
    v_MA2 = strfind(v_b,'nwwn');
    v_MA3 = strfind(v_b,'nwwwn');
%     v_MA4 = strfind(v_b,'nwwwwn');
    
    for idx = 1:length(v_MA1)
        v_b(v_MA1(idx):v_MA1(idx)+2)='nnn';
    end
    for idx = 1:length(v_MA2)
        v_b(v_MA2(idx):v_MA2(idx)+3)='nnnn';
    end
    for idx = 1:length(v_MA3)
        v_b(v_MA3(idx):v_MA3(idx)+4)='nnnnn';
    end
    
    
%     for idx = 1:length(v_MA4)
%         v_b(v_MA4(idx):v_MA4(idx)+5)='nnnnnn';
%     end
    
%     v_MA = {v_MA1,v_MA2,v_MA3,v_MA4};
    v_MA = {v_MA1,v_MA2,v_MA3};
    
end