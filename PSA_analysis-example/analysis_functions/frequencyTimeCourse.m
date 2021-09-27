function out = frequencyTimeCourse(b, trace, Fs, phase, state)
%FFTsUENCYTIMECOURSE This function extract the mean fft along the
%recoding for periods of equivalent state duration. Separate in 12 time
%points for lightphase and 8 for dark phase. You might want to filter your
%signal before doing this. There is no filter in this function.
%
% b is the scored bstate
% trace is the signal
% Fs is sampling rate
% phase must be either 'light' or 'dark' or 'SD' for sd 6 hours ZT0-6 
%(default is 'light')
%
% state is the state from which the ffts need to be extracted
% ('w','n','r'), the default is 'n'
%
% The output is a structure that contains the mean FFT for each time point
% and the time points in hour corresponding.

if nargin == 3
    phase = 'light';
    state = 'n';
end
if nargin == 4
    state = 'n';
end
    
ny = Fs/2;
sec = 4;
Hz = linspace(0,1,((Fs*sec)/2)+1)*ny;

b = b(1:10800);

% get the correct number of bin depending on the state

if state == 'w' % 8 points in light, 12 in dark, 12 in SD
    art = '1';
    if strcmp(phase, 'light') == 1 % if light
        time = 1:8;
    elseif strcmp(phase,'SD') == 1 % if SD
        time = 1:12;
    else % if Dark
        time = 1:12;
    end
end

if state == 'n' % 12 points in light, 8 in dark, 8 in SD
    art = '2';
    if strcmp(phase,'light') == 1
        time = 1:12;
    elseif strcmp(phase,'SD') == 1 
        time = 1:8;
    else
        time = 1:8;
    end
end

if state == 'r' % 5 points in light, 3 in dark, 3 in SD
    art = '3';
    if strcmp(phase,'light') == 1
        time = 1:5;
    elseif strcmp(phase,'SD') == 1 
        time = 1:3;
    else
        time = 1:3;
    end
end

%% Now find the periods and do the FFTs

nAmount = length(b(b==state)) + length(b(b==art));
nPeriod = ceil(nAmount/time(end));
nn = 1;
k = 2;
parts = zeros(1,time(end)+1);
for i = 1:length(b)
    if b(i) == state || b(i) == art
        nn = nn+1;
        if mod(nn,nPeriod) == 0
            parts(k) = i;
            k=k+1;
        end
    end
end

parts(end) = 10800;

if strcmp(phase,'SD') == 1 && (state == 'n' || state == 'r')
    parts(1) = 5400;
end

FFTs = zeros(401,time(end));
TP = zeros(1,time(end));

for i = 1:length(parts)-1
    perB = b(parts(i)+1:parts(i+1));
    nTri = strfind(perB,repmat(state,1,3))+parts(i)+1;
    aFre = zeros(401,length(nTri));
    k = 1;
    for j = nTri
        epoch = trace(j*4*200-799:j*4*200);
        lafft = abs(fft(epoch-mean(epoch)));
        lafft = lafft(1:length(Hz)); % take only half the fft because we don't need the mirror image
        lafft = lafft./((200*4)/2); % first normalization by the sampling rate * time in second (200points*4sec) divided by 2
        lafft = lafft.^2; % then PSD
        
        aFre(:,k) = lafft';
        k = k+1;
    end
    FFTs(:,i) = mean(aFre,2); % fft values MEAN
    TP(1,i) = ((mean([parts(i)+1, parts(i+1)])*4)/60)/60; % time point position in hour
end

if strcmp(phase,'SD') == 1 && (state == 'n' || state == 'r')
    TP = [NaN(1,6),TP];
    FFTs = [NaN(401,6),FFTs];
end

out = struct('FFTs',FFTs,'TP',TP);

end
