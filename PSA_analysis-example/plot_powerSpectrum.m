function plot_powerSpectrum(PSA)
%PLOT_POWERSPECTRUM 

% if no PSA is passed as argument, ask user to provide one
if nargin == 0
    [Namepsa, Pathpsa] = uigetfile('*.mat', 'Select your psa result structure to complete');
    p = load([Pathpsa,Namepsa]);
    PSA = p.PSA;
end

animal_names = fieldnames(PSA);
conditions = fieldnames(PSA.(animal_names{1}).result.P01);

[wFFT, nFFT, rFFT] = deal(zeros(length(animal_names)*length(conditions), 401));
cond_n = zeros(length(animal_names)*length(conditions), 1);

k = 1;
for a = 1:length(animal_names)
    for c = 1:length(conditions)
        norval = PSA.(animal_names{a}).result.P01.(conditions{c}).power_spectrum.NORVAL;
        wFFT(k,:) = PSA.(animal_names{a}).result.P01.(conditions{c}).power_spectrum.wFFT / norval;
        nFFT(k,:) = PSA.(animal_names{a}).result.P01.(conditions{c}).power_spectrum.nFFT / norval;
        rFFT(k,:) = PSA.(animal_names{a}).result.P01.(conditions{c}).power_spectrum.rFFT / norval;
        cond_n(k) = c;
        k = k + 1;
    end
end

Hz = Get_Hz(200, 4);
figure
subplot(1,3,1)
plot_SEM(Hz, wFFT(cond_n==1,:),'blue');
hold on
plot_SEM(Hz, wFFT(cond_n==2,:),'red');
title('Wake')
xlim([0,25])

subplot(1,3,2)
plot_SEM(Hz, nFFT(cond_n==1,:),'blue');
hold on
plot_SEM(Hz, nFFT(cond_n==2,:),'red');
title('NREMS')
xlim([0,25])

subplot(1,3,3)
plot_SEM(Hz, rFFT(cond_n==1,:),'blue');
hold on
plot_SEM(Hz, rFFT(cond_n==2,:),'red');
title('REMS')
xlim([0,25])

end

