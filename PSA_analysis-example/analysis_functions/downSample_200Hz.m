function downSample_200Hz
%DOWNSAMPLE_200HZ To down sample to 200 Hz

% select files
[fname, fpath] = uigetfile('*.mat', 'Select your mat file to downsample', 'MultiSelect', 'on');

if ~iscell(fname)
    fname = {fname};
end

for c = 1:length(fname)
    mfile = matfile([fpath,fname{c}], 'Writable', true);
    
    traces = mfile.traces;
    
    ntraces = zeros(size(traces,1), length(traces)/5);
    
    for i = 1:size(traces,1)
        ntraces(i,:) = decimate(traces(i,:),5, 'fir');
    end
    
    mfile.traces = ntraces;
    
    Infos = mfile.Infos;
    Infos.Fs = '200';
    mfile.Infos = Infos;
end

end

