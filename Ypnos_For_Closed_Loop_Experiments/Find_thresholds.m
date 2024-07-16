function [outputArg1,outputArg2] = Find_thresholds(inputArg1,inputArg2)
%FIND_THRESHOLDS Loads files that are scored and contain a state info from
%YPNOS to evaluate the threshold for REM and WAKE

[Name, Path] = uigetfile('G:\RESEARCH\AL\PRIVATE\Romain\Data\REMS deprivation\Tests\*.mat', 'Select your EEG file to analyse','multiselect','on');

if ~iscell(Name)
    Name = {Name};
end

for i = 1:length(Name)
    f = matfile([Path,Name{i}]);
    state = f.states;
    b = f.b;
    w = strfind(b,'www');
    n = strfind(b,'nnn');
    r = strfind(b,'rrr');   
    wake = getMean(state,w);
    nrem = getMean(state,n);
    rem = getMean(state,r);
    figure
    cdfplot(wake(1,:))
    hold on
    cdfplot(nrem(1,:))
    cdfplot(rem(1,:))
    figure
    cdfplot(wake(2,:))
    hold on
    cdfplot(nrem(2,:))
    cdfplot(rem(2,:))
end

end

function out = getMean(state,s)

out = zeros(2,length(s));
for i = 1:length(s)
    st = state(:,s(i)*4-3:s(i)*4);
    out(:,i) = mean(st(2:3,:),2);
end

end