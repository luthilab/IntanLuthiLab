function p_PowerSpectrum_Dynamics_nrems(PSA)
%Power dynamics (per hour of NREMS) SO / sigma / delta 

% [Namepsa, Path] = uigetfile('F:\aluthi1\fbm_move\D2c\_PROJECTS\PROJECT_Najma\_GeneralCodesSleepAnalysis\_PSA\*.mat', 'Select your PSA to plot');
% p = load([Path,Namepsa]);
% PSA = p.PSA;

animalID = fieldnames(PSA);
state = 'nf';
phase = 'phase01';

len_rec = 5; %5h => 10 bins
len_rec_epochs = len_rec*3600/4;
bin = len_rec*2;

fr = 70; %0.75 -35Hz (fr=1000: 0-500Hz)
fr_pts_1 = 4;
fr_pts_2 = 141;

function [FFT_pos_animal_mean,FFT_state_animal_mean] = loop_for(cond)
for i = 1:numel(animalID)
    if isfield(PSA.(animalID{i}),cond) 
        cur = PSA.(animalID{i}).(cond);
        day = fieldnames(cur);
        FFT_pos_days = zeros(length(day),bin);
        FFT_state_days = zeros(length(day),2001); 
        for k = 1:numel(day)
            fft_pos = cur.(day{k}).(phase).PowerSpectrum.(strcat(state,'pos'));
            cur_fft = cur.(day{k}).(phase).PowerSpectrum.(strcat(state,'FFT'));
            % 10 bins of equal amount of nrems in a 5h recording for every
            % condition and every day
            fft_pos = fft_pos(fft_pos<len_rec_epochs);
            nb_nrems = length(fft_pos); 
            bin_count = floor(nb_nrems/bin);
            bining = zeros(1,bin+1);
            bining(1) = 1;
            bining(end) = length(fft_pos);
            for itt = 2:bin
                bining(1,itt) = bining(1,itt-1)+bin_count;
            end
            FFT_pos_bin = zeros(1,bin);
            FFT_state_bin = zeros(bin,2001); 
            for iter = 1:bin
                index_bining = bining(iter):bining(iter+1);
                % position to have the time points
                fft_pos_bin = fft_pos(index_bining);
                FFT_pos_bin(iter) = mean(fft_pos_bin);
                
                %take the corresponding FFT
                state_fft_bin = cur_fft(:,index_bining);
                FFT_state_bin(iter,:) = mean(state_fft_bin,2);
            end
            if k ==1
                FFT_pos_days = FFT_pos_bin; %10 time points
                FFT_state_days = FFT_state_bin; % 10 bins with 2001
            else
                FFT_pos_days = FFT_pos_days + FFT_pos_bin; %10 time points
                FFT_state_days = FFT_state_days + FFT_state_bin; % 10 bins with 2001
            end
            
        end
        %normalize per day
        FFT_pos_animal_mean(i,:) = FFT_pos_days /  numel(day); 
        FFT_state_animal_mean(:,:,i) = FFT_state_days / numel(day);

        % FFT_animal = FFT_state_animal_mean(:,1:fr_pts,:); %to have 0-35Hz (1:141) instead of 0-500Hz (1:2001)
        % if size(FFT_animal,1)>1
        %     mat(i,:) = nanmean(FFT_animal,1); %mean for 1 animal through all days
        %     mat(i,:) = mat(i,:)./sum(mat(i,:)); %normalization to have relative power spectrum
        % else
        %     mat(i,:) = (FFT_animal)./sum(FFT_animal); %%normalization to have relative power spectrum
        % end
        
    end
end
end

[pos_nacl,mat_nacl] = loop_for('nacl');
[pos_cno,mat_cno] = loop_for('cno');
[pos_cno2,mat_cno2] = loop_for('cno2');

%to have 0.75-35Hz (1:141) instead of 0-500Hz (1:2001)
%mat_nacl = mat_nacl(:,fr_pts_1:fr_pts_2);
% mat_nacl = mat_nacl./sum(mat_nacl(:,fr_pts_1:fr_pts_2),2);

%Normalization with the last 2 bins
normalization_nacl = sum(mean(mat_nacl(len_rec*2-1:len_rec*2,fr_pts_1:fr_pts_2,:),1),2);
% normalization_cno = sum(mean(mat_cno(len_rec*2-1:len_rec*2,fr_pts_1:fr_pts_2,:),1),2);
% normalization_cno2 = sum(mean(mat_cno2(9:10,fr_pts_1:fr_pts_2,:),1),2);

mat_nacl = mat_nacl./normalization_nacl;
mat_cno = mat_cno./normalization_nacl;
mat_cno2 = mat_cno2./normalization_nacl;

SO_nacl = mean(mat_nacl(:,4:7,:),2); %0.75-1.5Hz
SO_nacl = reshape(SO_nacl,bin,numel(animalID));
SO_cno = mean(mat_cno(:,4:7,:),2);
SO_cno = reshape(SO_cno,bin,numel(animalID));
SO_cno2 = mean(mat_cno2(:,4:7,:),2);
SO_cno2 = reshape(SO_cno2,bin,numel(animalID));
%normalization on the last 2 values in nacl 
% mean_SO_nacl_last_2_values = nanmean(nanmean(SO_nacl(end-1:end,:),2));
% SO_nacl=SO_nacl/mean_SO_nacl_last_2_values*100;
% SO_cno=SO_cno/mean_SO_nacl_last_2_values*100;
% SO_cno2=SO_cno2/mean_SO_nacl_last_2_values*100;

delt_nacl = mean(mat_nacl(:,7:17,:),2); %1.5-4Hz
delt_nacl = reshape(delt_nacl,bin,numel(animalID));
delt_cno = mean(mat_cno(:,7:17,:),2);
delt_cno = reshape(delt_cno,bin,numel(animalID));
delt_cno2 = mean(mat_cno2(:,7:17,:),2);
delt_cno2 = reshape(delt_cno2,bin,numel(animalID));
%normalization on the last 2 values in nacl 
% mean_delt_nacl_last_2_values = nanmean(nanmean(delt_nacl(end-1:end,:),2));
% delt_nacl=delt_nacl/mean_delt_nacl_last_2_values*100;
% delt_cno=delt_cno/mean_delt_nacl_last_2_values*100;
% delt_cno2=delt_cno2/mean_delt_nacl_last_2_values*100;

sig_nacl = mean(mat_nacl(:,41:61,:),2); %10-15Hz
sig_nacl = reshape(sig_nacl,bin,numel(animalID));
sig_cno = mean(mat_cno(:,41:61,:),2);
sig_cno = reshape(sig_cno,bin,numel(animalID));
sig_cno2 = mean(mat_cno2(:,41:61,:),2);
sig_cno2 = reshape(sig_cno2,bin,numel(animalID));
%normalization on the last 2 values in nacl 
% mean_sig_nacl_last_2_values = nanmean(nanmean(sig_nacl(end-1:end,:),2));
% sig_nacl=sig_nacl/mean_sig_nacl_last_2_values*100;
% sig_cno=sig_cno/mean_sig_nacl_last_2_values*100;
% sig_cno2=sig_cno2/mean_sig_nacl_last_2_values*100;


%% PLOT
%SO_nacl : Column = 11 animals, row = 10 bins
%pos_nacl : Column = 10 bins, row = 11 animals
%SO 
figure('color','w');
myplot(pos_nacl',SO_nacl,'black',len_rec)
myplot(pos_cno',SO_cno,'blue',len_rec)
myplot(pos_cno2',SO_cno2,'red',len_rec)
ylabel('% from last hour of NaCl')
xlabel('Time from i.p. inj point (h)')
ylim([70,180])
title('SO 0.75-1.5Hz')
tickout

figure('color','w');
SO_nacl_mean = mean(SO_nacl(1:2,:),1); 
SO_cno_mean = mean(SO_cno(1:2,:),1);
SO_cno2_mean = mean(SO_cno2(1:2,:),1);
myboxplot(SO_nacl_mean',SO_cno_mean',SO_cno2_mean',200,'SO (bin 1&2)')

figure('color','w');
SO_nacl_mean = mean(SO_nacl(len_rec*2-1:len_rec*2,:),1); 
SO_cno_mean = mean(SO_cno(len_rec*2-1:len_rec*2,:),1);
SO_cno2_mean = mean(SO_cno2(len_rec*2-1:len_rec*2,:),1);
myboxplot(SO_nacl_mean',SO_cno_mean',SO_cno2_mean',200,'SO (last 2 bins)')

%Delta
figure('color','w');
myplot(pos_nacl',delt_nacl,'black',len_rec)
hold on
myplot(pos_cno',delt_cno,'blue',len_rec)
myplot(pos_cno2',delt_cno2,'red',len_rec)
ylabel('% from last hour of NaCl')
xlabel('Time from i.p. inj point (h)')
ylim([70,160])
title('Delta 1.5-4Hz')
tickout

figure('color','w');
delt_nacl_mean = mean(delt_nacl(1:2,:),1); 
delt_cno_mean = mean(delt_cno(1:2,:),1);
delt_cno2_mean = mean(delt_cno2(1:2,:),1);
myboxplot(delt_nacl_mean',delt_cno_mean',delt_cno2_mean',180,'delta (bin 1&2)')

figure('color','w');
delt_nacl_mean = mean(delt_nacl(len_rec*2-1:len_rec*2,:),1); 
delt_cno_mean = mean(delt_cno(len_rec*2-1:len_rec*2,:),1);
delt_cno2_mean = mean(delt_cno2(len_rec*2-1:len_rec*2,:),1);
myboxplot(delt_nacl_mean',delt_cno_mean',delt_cno2_mean',180,'delta (last 2 bins)')

%Sigma
figure('color','w');
myplot(pos_nacl',sig_nacl,'black',len_rec)
myplot(pos_cno',sig_cno,'blue',len_rec)
myplot(pos_cno2',sig_cno2,'red',len_rec)
ylabel('% from last hour of NaCl')
xlabel('Time from i.p. inj point (h)')
ylim([30,110])
title('Sigma 10-15Hz')
tickout

figure('color','w');
sig_nacl_mean = mean(sig_nacl(1:2,:),1); 
sig_cno_mean = mean(sig_cno(1:2,:),1);
sig_cno2_mean = mean(sig_cno2(1:2,:),1);
myboxplot(sig_nacl_mean',sig_cno_mean',sig_cno2_mean',140,'sigma(first_2bins)')

figure('color','w');
sig_nacl_mean = mean(sig_nacl(len_rec*2-1:len_rec*2,:),1); 
sig_cno_mean = mean(sig_cno(len_rec*2-1:len_rec*2,:),1);
sig_cno2_mean = mean(sig_cno2(len_rec*2-1:len_rec*2,:),1);
myboxplot(sig_nacl_mean',sig_cno_mean',sig_cno2_mean',140,'sigma(last_2bins)')

end

function [h] = myplot(x,y,c,time)   
%------  SEM  ----------
x_mean = nanmean(x,2);
x_SEM = nanstd(x,[],2)/sqrt(size(x,1));

data_mean = nanmean(y,2);  % Mean Across rows
data_SEM = nanstd(y,[],2)/sqrt(size(y,1));      % SEM Across rows
% plot(x_mean, data_mean, c)
% errorbarxy(x_mean,data_mean,x_SEM,data_SEM,c); 
h = shadedErrorBar(x_mean,data_mean,data_SEM,'lineprops',c); %,'transparent',false);
 
tick_x = linspace(0,time*3600/4,time+1);
xticks(tick_x)
lab_x = linspace(0,time,time+1);
xticklabels({lab_x})
xlim([0,time*3600/4])
end

function myboxplot(x1,x2,x3,y_lim,label)
boxplot([x1,x2,x3],'colors','kbr','Widths',0.3)
ylim([0,y_lim])
ylabel([label,' (%)'])
xticklabels({'NaCl','CNO 1.5mg/kg','CNO 2.5mg/kg'})
title(label)
tickout
y_line1 = [x1,x2];
y_line2 = [x2,x3];
for r = 1:length(y_line1)
    line([1.2,1.8],y_line1(r,:),'color','k')
    line([2.2,2.8],y_line2(r,:),'color','k')
end

path = '\\nasdcsr.unil.ch\recherche\FAC\FBM\DNF\aluthi1\fbm_move\D2c\_PROJECTS\PROJECT_Najma\_GeneralCodesSleepAnalysis\STATS_AND_DATA';
%TABLE WITH DATA
mat_csv = [x1 x2 x3];
table_cvs = array2table(mat_csv);
table_cvs.Properties.VariableNames(1:3) = {'nacl','cno','cno2'};
writetable(table_cvs,[path,'\Power_Spectrum_dynamics_2bins_',label,'_DATA.csv'],'WriteRowNames',true)
%STATS
fileID = fopen([path,'\Power_Spectrum_dynamics_2bins_',label,'_STATS.txt'],'w');
Stats_tests(x1,x2,x3,fileID)

end