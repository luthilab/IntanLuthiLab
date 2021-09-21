function [into, position] = FragilityIntoState(signal,Fs,b)
%FRAGILITYINTOSTATE This function to extract the transitions within
%fragility period considered from hiblert angle of 90° to 170°.

sigma = Infra_OneBoutExtract(signal, [10,15], Fs, 0);
[~,loc,~,sigmaf] = ExtractSigmaCycles(sigma,b,[],0,1);
sigPhase = HilbertNREMSphase(sigmaf,b);
frag = (sigPhase<270 & sigPhase>90);

% Get the transition scored in a 10 Hz information
b(b=='m') = 'w';
b(b=='1') = 'w';
b(b=='2') = 'n';
b(b=='3') = 'r';
tran = zeros(1,length(frag));
tran(strfind(b,'nw')*4*10) = 1;
tran(strfind(b,'nr')*4*10) = 3;

% For each through, detect if there is a transition from 90 to 270°
into = repmat(2, 1, length(loc));

for i = 1:length(loc)-1
    curfrag = frag(loc(3,i):loc(3,i+1));
    curtran = tran(loc(3,i):loc(3,i+1));
    
    
    if ~isempty(find(curtran, 3))
        into(i) = 3;
    end
    
    fp = curtran(curfrag);
    if ~isempty(find(fp, 1))
        into(i) = 1;
    end
    
%     cursig = sigmaf(loc(3,i):loc(3,i+1));
%     plot(cursig)
%     yyaxis right
%     plot(curfrag)
%     hold on
%     plot(curtran)
%     delete(gca)
    
end

% Put the last cycle with the last transition
ltr = tran(loc(3,end):end);
if ~isempty(find(ltr, 3))
    into(end) = 3;
elseif ~isempty(find(ltr, 3))
    into(end) = 1;
end

position = loc(3,:);

end

