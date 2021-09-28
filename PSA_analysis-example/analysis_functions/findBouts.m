function [Bout] = findBouts(b, type, minSize)
% give back the begining and the end of bout of 'type' of mininum the size 
% of 'size' found in b.
% x is a string or a 1xn matrix. 
% type is one element of b that compose the bout of interest.
% minSize is a number representing the miminal amount of type to be considered a bout.
% 
% Romain Cardis 2021


ex = sprintf('[^%s]%s{%i,}[^%s]', type, type, minSize, type);
st = regexp(b, ex, 'start')+1;
en = regexp(b, ex, 'end')-1;

Bout = [st; en];

end
