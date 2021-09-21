function [ CI ] = CI95(data, dim)
% Romain Cardis 2018

%CI95 simply calculate the 95% CI of the mean of the data set. If data is a
%vector, returns the 95 CI in a 1x2 vector. If data is a matrix of RxC, precise
%dim and it will return the 95 CI in a 2 by C or R matrix.

if nargin == 1

    SEM = nanstd(data)/sqrt(length(data(~isnan(data))));
    ts = tinv([0.025 0.975], length(data(~isnan(data)))-1);
    CI = nanmean(data) + ts * SEM;

else
    
    if dim == 2
        datafi = data';
        d = 1;
    else
        datafi = data;
        d = 2;
    end
    CI = zeros(2,size(data,d));
    for i = 1:size(data,d)
        dataf = datafi(:,i);
        SEM = nanstd(dataf)/sqrt(length(dataf(~isnan(dataf))));
        ts = tinv([0.025 0.975], length(dataf(~isnan(dataf)))-1);
        CI(:,i) = (nanmean(dataf) + ts * SEM)';
    end
    
end

end

