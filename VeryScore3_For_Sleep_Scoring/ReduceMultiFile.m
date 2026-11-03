function ReduceMultiFile
%REDUCEMULTIFILE Summary of this function goes here
%   Detailed explanation goes here

[name, path] = uigetfile('*.mat', 'Select your file to reduce', 'multiselect', 'on');

for i = 1:length(name)
    ReduceBTfileSize(matfile([path,name{i}]));
end

end

