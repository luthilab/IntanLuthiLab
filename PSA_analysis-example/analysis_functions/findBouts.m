function [Bout] = findBouts(x, type, minSize)
% give back the begining and the end of bout of 'type' of mininum the size 
% of 'size' found in x.
% x is a string or a 1xn matrix. 
% type is a 1x1 string or one number
% size is a number

Bout = [];
nn = 0;
nb = 1;

for i = 1:length(x)
    if x(i) == type
        nn = nn+1;
        if nn == minSize
            Bout(1,nb) = i - (minSize-1); %#ok<AGROW>
            nb = nb+1;
        end
    elseif nn >= minSize
        Bout(2,nb-1) = i - 2; %#ok<AGROW>
        nn = 0;
    else
        nn = 0;
    end
end

%if Bout(2,end) + 20 > length(x) || Bout(2,end) == 0
if~isempty(Bout)
    if Bout(2,end) == 0
        Bout = Bout(:,1:end-1);
    end
end

end