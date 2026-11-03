function ReduceBTfileSize(file)
%REDUCEBTFILESIZE This function reduce the size on the BT files by loading
%everything and resaving in one shot. Apparently it reduces them.

w = waitbar(.2, 'Loading all variables from file');

if nargin == 0
    [name, path] = uigetfile('*.mat', 'Select your file to reduce');
    f = load([path,name]);
else
    f = load(file.Properties.Source);
end

waitbar(.5, w, 'Reassigning names and stuff');
names = fieldnames(f);
assi(f,names)

waitbar(.7, w, 'Resaving all at once');
if nargin == 0
    save([path,name], names{:}, '-v7.3')
else
    save(file.Properties.Source, names{:}, '-v7.3')
end
waitbar(1, w, 'Top cool');
close(w)
msgbox('File reduced!')

end

function assi(f,names)

for i = 1:numel(names)
    assignin('caller', names{i}, f.(names{i}))
end

end