function [Bout] = findBouts(b, type, minSize)
% give back the begining and the end of bout of 'type' of mininum the size 
% of 'size' found in b.
% x is a string or a 1xn matrix. 
% type is a 1x1 string or one number
% size is a number

ex = sprintf('[^%s]%s{%i,}[^%s]', type, type, minSize, type);
st = regexp(b, ex, 'start')+1;
en = regexp(b, ex, 'end');

Bout = [st; en];

end