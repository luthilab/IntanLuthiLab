function plot_time_in_state(PSA)
%PLOT_TIME_IN_STATE to plot the time in state from a PSA

% if no PSA is passed as argument, ask user to provide one
if nargin == 0
    [Namepsa, Pathpsa] = uigetfile('*.mat', 'Select your psa result structure to complete');
    p = load([Pathpsa,Namepsa]);
    PSA = p.PSA;
end

animal_names = fieldnames(PSA);
conditions = fieldnames(PSA.(animal_names{1}).result.P01);

%% Get the results out for the time in state
T_time_in_state = table('Size', [length(animal_names)*3*length(conditions), 5],...
    'VariableNames', {'animal_name', 'condition', 'state', 'time_s', 'prop'},...
    'VariableTypes',{'string','string','string','double','double'});

% Fill the time_in_state table
k = 1;
for n = 1:length(animal_names)
    for c = 1:length(conditions)
        tis = PSA.(animal_names{n}).result.P01.(conditions{c}).time_in_state;
        total = tis.nrem + tis.rem + tis.wake;
        T_time_in_state(k,:) = {animal_names{n}, conditions{c}, 'w', tis.wake, (tis.wake/total)*100};
        k = k + 1;
        T_time_in_state(k,:) = {animal_names{n}, conditions{c}, 'n', tis.nrem, (tis.nrem/total)*100};
        k = k + 1;
        T_time_in_state(k,:) = {animal_names{n}, conditions{c}, 'r', tis.rem, (tis.rem/total)*100};
        k = k + 1;
    end
end

%% get the results out for the variables
T_variables = table('Size', [length(animal_names)*length(conditions), 5],...
    'VariableNames', {'animal_name', 'condition', 'waso', 'so', 'nma'},...
    'VariableTypes',{'string','string','double','double','double'});
k = 1;
for n = 1:length(animal_names)
    for c = 1:length(conditions)
        tis = PSA.(animal_names{n}).result.P01.(conditions{c}).time_in_state;
        T_variables(k,:) = {animal_names{n}, conditions{c}, tis.waso, tis.so, tis.nma};
        k = k + 1;
    end
end

%% save the two table in CSV
writetable(T_time_in_state, sprintf('time_in_state_%s_%s.csv', conditions{1},conditions{2}))
writetable(T_variables, sprintf('sleep_variables_%s_%s.csv', conditions{1},conditions{2}))

%% Plot the data from the table
figure
boxplot(T_time_in_state.prop, {T_time_in_state.state, T_time_in_state.condition})

figure
subplot(1,3,1)
boxplotScat(T_variables.so, T_variables.condition)
ylabel('Sleep onset (s)')

subplot(1,3,2)
boxplotScat(T_variables.waso, T_variables.condition)
ylabel('Wake after sleep onset (s)')

subplot(1,3,3)
boxplotScat(T_variables.nma, T_variables.condition)
ylabel('number of microarousals')

end

