function [cycles,loc,into,sigmaf] = ExtractSigmaCycles(sigma,b,eeg,plo,preprocessSig)
%EXTRACTSIGMACYCLES Here you give sigma extracted using wavelet and it will
%locate the peaks and troughs to isolate cycles in NREMS.
%
% INPUTS:
% sigma: is the complete sigma extraction of the whole recording using
% wavelet transform. Typically, you get it with the function
% Infra_OneBoutExtract on the whole eeg. Or, more simply with the
% SL_wavelet or AddSigmaWav to add the variable infra in the bt files. It
% should be sampled at 10 Hz.
%
% b: is the typical behavioral state vector in the bt files.
%
% eeg: is the eeg corresponding at (200 Hz) leave empty [] if not needed
%
% plo: put 1 if you want to plot the result of the cycle detection.
%
% sigNor: put 1 if you need to DO the sigma normalization and 0 if it is
% already normalized. Default is 1
%
% OUTPUTS:
% cycles: is the cycles taken from the EEG still sampled at 200 Hz.
% Continuity periods are in {1,:} and corresponding fragility in {2,:}.
%
% loc: is the localisation of the cycles in the 10 Hz infra line.
%
% into: is the corresponding target state (from scoring) in which each
% cycle goes. 1 is wake, 2 is NREMS, 3 is REMS.
%
% Romain Cardis 2019
%

switch nargin
    case 2
        eeg = [];
        plo = 0;
        preprocessSig = 1;
    case 3
        plo = 0;
        preprocessSig = 1;
    case 4
        preprocessSig = 1;
end

% first clean the sigma of artifacts
if preprocessSig == 1
    art = sigma>0.85;
    be = strfind(art,[0,1]);
    for i = be
        if i-40 >= 1
            art(i-40:i) = 1;
        end
    end
    en = strfind(art,[1,0]);
    for i = en
        if i+39 <= length(art)
            art(i:i+39) = 1;
        end
    end
    sigma(art) = NaN;
    sigma = interpNan(sigma);
    
    
    bhi = fir1(100, 0.025/10,'low');
    sigmaf = filtfilt(bhi,1,sigma);

    % find the mean sigma in NREMS and normalize it on it
    b(b=='m') = 'w';

    tb = b;
    tb(tb=='1') = 'w';
    tb(strfind(tb,'nwwwwn')+1) = 'n';
    tb(strfind(tb,'nwwwn')+1) = 'n';
    tb(strfind(tb,'nwwn')+1) = 'n';
    tb(strfind(tb,'nwn')+1) = 'n';
    
    nrem = find(tb=='n');
    nrem10 = zeros(1,length(sigmaf));
    for i = nrem
        nrem10((i-1)*40+1:i*40) = 1;
    end
    nrem10 = nrem10(1:length(sigmaf));
    sigmaf = sigmaf/mean(sigmaf(logical(nrem10)));
else
    sigmaf = sigma;
end

b(b=='3') = 'r';

% find peak and trough
[pea,peaklo] = findpeaks(sigmaf,'MinPeakHeight',1,'MinPeakDistance',250);
[trou,troulo] = findpeaks(-sigmaf,'MinPeakHeight',-1,'MinPeakDistance',200);
trou = -trou;

% allocate variables
into = zeros(1,length(peaklo));
cycles = cell(2,length(peaklo));
loc = zeros(3,length(peaklo));
p = 1;
for i = 1:length(troulo)-1
    peakbetween = peaklo(peaklo>troulo(i)&peaklo<troulo(i+1));
    if ~isempty(peakbetween) && length(peakbetween) <= 2 && ceil(troulo(i+1)/10/4+3) < length(b) && troulo(i+1)-troulo(i) < 1000
        try
            curst = b(floor(troulo(i)/10/4):ceil(troulo(i+1)/10/4+3));
        catch
            continue
        end
        curst = curst(3:end);
        if contains(curst,'n') && length(strfind(curst,'nw')) < 3 && ~contains(curst,'2')
            endtrough = troulo(i+1);
            % additional check to locate real end of trough
%             [~,rlo] = findpeaks(-sigmaf(peakbetween(end):troulo(i+1)));
%             if ~isempty(rlo)
%                 rlo = rlo(end)+peakbetween(end);
%                 if abs(sigmaf(peakbetween(end))-sigmaf(rlo)) > abs(sigmaf(troulo(i+1))-sigmaf(rlo))
%                     endtrough = rlo;
%                     curst = b(floor(troulo(i)/10/4):ceil(endtrough/10/4+3));
%                     curst = curst(floor(end/2)+1:end);
%                 end
%             end
            
            loc(:,p) = [troulo(i); endtrough; peakbetween(end)];
            
            if contains(curst,'nr')
                into(p) = 3;
            elseif contains(curst,'nw')
                into(p) = 1;
            else
                into(p) = 2;
            end
            if ~isempty(eeg)
                cycles{1,p} = eeg(troulo(i)*20:peakbetween(end)*20);
                cycles{2,p} = eeg(peakbetween(end)*20:endtrough*20);
            end
            p = p+1;
        end
    end
end

cycles = cycles(:,1:p-1);
into = into(:,1:p-1);
loc = loc(:,1:p-1);

% plot to see things

if plo == 1
    figure
    x = linspace(0,length(sigmaf)/10,length(sigmaf));
    plot(x,sigmaf)
    hold on
    line([0,length(sigmaf)/10],[1,1])
    scatter(x(peaklo),pea)
    scatter(x(troulo),trou)
    
    col = {'red','blue'};
    for i = 1:length(loc)
        c = mod(i,2)+1;
        line(x(loc(1,i):loc(2,i)), sigmaf(loc(1,i):loc(2,i)),'color',col{c})
    end
    
    yyaxis right
    plot(linspace(0,length(sigmaf)/10,length(b)),bToHyp(b,1)); ylim([-10,15])
end

end

