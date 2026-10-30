function tests = test_sensor
% Acceptance cases written before implementation; synthetic ground truth only.
% Run: results = runtests('tests/test_sensor.m'); assertSuccess(results)
tests = functiontests(localfunctions);
end

function setupOnce(t)
t.TestData.root = fileparts(fileparts(mfilename('fullpath')));
addpath(t.TestData.root);
t.TestData.folder = tempname;
mkdir(t.TestData.folder);
end

function teardownOnce(t)
rmdir(t.TestData.folder, 's');
end

function testSpectrumKnownAmplitudes(t)
fs = 200; time = (0:799)'/fs;
x = 2000 + 120*sin(2*pi*2*time) + 40*sin(2*pi*8*time);
R = VS3_sensorTool('spectrum', x, fs, [.5 5; 5 15]);
verifyEqual(t, R.frequency, [2 8], 'AbsTol', 1e-12);
verifyEqual(t, R.amplitude, [120 40], 'AbsTol', .02);
verifyEqual(t, R.period, [.5 .125], 'AbsTol', 1e-12);
verifyEqual(t, R.resolution, .25, 'AbsTol', 1e-12);
end

function testPeakMovesEveryEpoch(t)
fs = 200; time = (0:799)'/fs;
R1 = VS3_sensorTool('spectrum', sin(2*pi*2*time), fs, [.5 5;5 15]);
R2 = VS3_sensorTool('spectrum', sin(2*pi*3*time), fs, [.5 5;5 15]);
verifyEqual(t, R1.frequency(1), 2);
verifyEqual(t, R2.frequency(1), 3);
end

function testFlatSignalHasNoCandidate(t)
R = VS3_sensorTool('spectrum', ones(800,1)*2000, 200, [.5 5;5 15]);
verifyTrue(t, all(isnan(R.frequency)));
end

function testRespiratoryHarmonicIsFlagged(t)
time = (0:799)'/200;
R = VS3_sensorTool('spectrum', sin(2*pi*3*time)+.7*sin(2*pi*9*time), 200, [.5 5;5 15]);
verifyEqual(t, R.frequency, [3 9]);
verifyTrue(t, R.harmonic);
end

function testConvertAndEpochAlignment(t)
[file, raw] = fixture(t, 'clean');
target = fullfile(t.TestData.folder, 'clean.h5');
VS3_sensorConvert({file}, target);
verifyEqual(t, double(h5read(target, '/samples/raw_adc')), raw);
S = VS3_sensorTool('read', target);
verifyEqual(t, S.startPosix, posixtime(datetime(2026,9,24,17,19,28,'TimeZone','UTC')), 'AbsTol', 1e-6);
% Sensor starts 2 seconds AFTER EEG. Epoch 2 [4,8) -> sensor [2,6).
E = VS3_sensorTool('epoch', S, 2, 2, [.5 5;5 15]);
verifyTrue(t, E.valid, E.reason);
verifyEqual(t, E.time(1), 4, 'AbsTol', 1e-9);
verifyEqual(t, E.spectrum.frequency, [2 8], 'AbsTol', .25);
verifyEqual(t, numel(E.raw), 800);
E = VS3_sensorTool('epoch', S, 2, 1, [.5 5;5 15]);
verifyFalse(t, E.valid); % No extrapolation before sensor start.
end

function testGapIsNotInterpolated(t)
[file, ~] = fixture(t, 'gap');
target = fullfile(t.TestData.folder, 'gap.h5');
VS3_sensorConvert({file}, target);
S = VS3_sensorTool('read', target);
E = VS3_sensorTool('epoch', S, 0, 2, [.5 5;5 15]);
verifyFalse(t, E.valid);
verifyTrue(t, all(isnan(E.spectrum.frequency)));
end

function testClippingInvalidatesEpoch(t)
[file, ~] = fixture(t, 'clip');
target = fullfile(t.TestData.folder, 'clip.h5');
VS3_sensorConvert({file}, target);
S = VS3_sensorTool('read', target);
E = VS3_sensorTool('epoch', S, 0, 2, [.5 5;5 15]);
verifyFalse(t, E.valid);
verifyTrue(t, any(bitand(h5read(target,'/samples/quality'),uint8(1)) ~= 0));
end

function testOverlapAndOverwriteRejected(t)
[file, ~] = fixture(t, 'overlap');
target = fullfile(t.TestData.folder, 'overlap.h5');
verifyError(t, @() VS3_sensorConvert({file,file},target), 'VS3:sensorOverlap');
verifyFalse(t, isfile(target));
VS3_sensorConvert({file},target);
verifyError(t, @() VS3_sensorConvert({file},target), 'VS3:sensorExists');
end

function testClockAlignment(t)
I = struct('StartTimePosix', 1000);
verifyEqual(t, VS3_sensorTool('offset', 1020, I), 20);
verifyError(t, @() VS3_sensorTool('offset',1020,struct('StartTime','2026-09-24 19:19:08')), 'VS3:sensorClock');
end

function testComparisonViewFollowsEpoch(t)
[file,~] = fixture(t,'view');
target = fullfile(t.TestData.folder,'view.h5');
VS3_sensorConvert({file},target);
S = VS3_sensorTool('read',target);
config = struct('offset',0,'bands',[.5 5;5 15],'channel',1);
V = VS3_sensorView(S,config,{'EMG'},@fakeEmg,@(~) [],'off');
cleanup = onCleanup(@() delete(V)); %#ok<NASGU>
V.update(2);
verifyEqual(t,V.position,2);
verifyEqual(t,V.sensorLine.XData(1),4,'AbsTol',1e-9);
verifyEqual(t,V.emgLine.XData(1),4,'AbsTol',1e-9);
verifyTrue(t,any(contains(string(V.status.String),'Epoch 2')));
V.update(1); % invalid boundary must clear old sensor spectrum
verifyTrue(t,all(isnan(V.sensorSpectrum.YData)));
end

function testMultipleEmgChannelsRemainSeparate(t)
[file,~]=fixture(t,'multi');
target=fullfile(t.TestData.folder,'multi.h5');
VS3_sensorConvert({file},target);
S=VS3_sensorTool('read',target);
config=struct('offset',0,'bands',[.5 5;5 15],'channels',[1 2]);
V=VS3_sensorView(S,config,{'EMG1','EMG2'},@fakeMultiEmg,@(~) [],'off');
cleanup=onCleanup(@() delete(V)); %#ok<NASGU>
V.update(2);
verifyEqual(t,numel(V.emgLine),2);
verifyEqual(t,numel(V.emgSpectrum),2);
[~,i]=max(V.emgSpectrum(1).YData);
verifyEqual(t,V.emgSpectrum(1).XData(i),7,'AbsTol',1e-12);
[~,i]=max(V.emgSpectrum(2).YData);
verifyEqual(t,V.emgSpectrum(2).XData(i),9,'AbsTol',1e-12);
end

function [x,fs,unit]=fakeMultiEmg(channel,~)
fs=1000; x=sin(2*pi*(5+2*channel)*(0:3999)'/fs); unit='V';
end

function testMainWindowRestoresAndNavigatesSensor(t)
[file,~]=fixture(t,'main');
target=fullfile(t.TestData.folder,'main.h5');
VS3_sensorConvert({file},target);
recording=fullfile(t.TestData.folder,'main.mat');
traces=zeros(2,48000);
Infos=struct('Fs',1000,'Channel','EMG1, EMG2','Unit','V','StartTimePosix', ...
    posixtime(datetime(2026,9,24,17,19,28,'TimeZone','UTC')));
Sensor=struct('source',target,'offset',0,'bands',[.5 5;5 15],'channels',[1 2]);
save(recording,'traces','Infos','Sensor','-v7.3');
VS3_main(recording);
main=findall(groot,'Type','figure','Tag','VS3Main');
assertEqual(t,numel(main),1);
cleanup=onCleanup(@() delete(main)); %#ok<NASGU>
menu=findall(main,'Type','uimenu','Text','Show sensor / EMG comparison');
verifyEqual(t,string(menu.Enable),"on");
menu.Callback(menu,[]);
view=findall(groot,'Type','figure','Name','Sensor / EEG-EMG comparison');
assertEqual(t,numel(view),1);
main.KeyPressFcn(main,struct('Key','d','Modifier',{{}}));
edit=findall(view,'Style','edit','String','2');
verifyEqual(t,numel(edit),1); % Main navigation propagated to comparison.
delete(view);
menu.Callback(menu,[]); % Closed window can be recreated with its settings.
view=findall(groot,'Type','figure','Name','Sensor / EEG-EMG comparison');
verifyEqual(t,numel(view),1);
delete(main); % Comparison must close together with its parent.
verifyFalse(t,isgraphics(view));
end

function [x,fs,unit] = fakeEmg(~,ep)
fs=1000; x=sin(2*pi*(8+ep-2)*(0:3999)'/fs); unit='V';
end

% Regression specifications for dual names, shared time and display processing.
function testComparisonUsesOneEegClockWithOffset(t)
[file,~]=fixture(t,'shared_clock');
target=fullfile(t.TestData.folder,'shared_clock.h5'); VS3_sensorConvert({file},target);
S=VS3_sensorTool('read',target);
config=struct('offset',2,'bands',[.5 5;5 15],'channels',1);
V=VS3_sensorView(S,config,{'EMG'},@fakeEmg,@(~) [],'off');
cleanup=onCleanup(@() delete(V)); %#ok<NASGU>
V.update(2);
verifyEqual(t,V.sensorLine.XData(1),4,'AbsTol',1e-9);
verifyEqual(t,V.emgLine.XData(1),4,'AbsTol',1e-9);
verifyEqual(t,V.axesList(1).XLim,[4 8],'AbsTol',1e-9);
verifyEqual(t,V.axesList(2).XLim,[4 8],'AbsTol',1e-9);
verifyEqual(t,string(V.axesList(1).XLabel.String),"Time since EEG start (s; shared axis)");
verifyEqual(t,string(V.axesList(2).XLabel.String),"Time since EEG start (s; shared axis)");
end

function testMainDualChannelNames(t)
[main,P,V]=processedMainFixture(t,'dual_names');
cleanup=onCleanup(@() delete(main)); %#ok<NASGU>
labels=string(V.channelMenu.String);
verifyTrue(t,any(labels=="EMG_A | original: CH6"));
verifyTrue(t,any(labels=="EMG_B | original: CH7"));
verifyEqual(t,P.ChannelNames,{'EMG_A','EMG_B'});
end

function testComparisonFollowsFilterAndIgnoresDisplayGain(t)
[main,P,V]=processedMainFixture(t,'follow_filter');
cleanup=onCleanup(@() delete(main)); %#ok<NASGU>
P.position=2; P.selectedTraces=[1;0];
[b,a]=butter(4,25/100,'low');
P.filterTrace(b,a,'low-pass 25 Hz (test specification)');
expected=P.traces(1,801:1600)*P.rowInfo(1).scale;
verifyEqual(t,V.emgLine(1).YData,expected,'AbsTol',1e-12);
R=VS3_sensorTool('spectrum',expected,200,[.5 5;5 15]);
verifyEqual(t,V.emgSpectrum(1).YData,R.a','AbsTol',1e-12);
verifyTrue(t,any(contains(string(V.status.String),'low-pass 25 Hz')));
P.changeGain('plus',1000);
verifyEqual(t,V.emgLine(1).YData,expected,'AbsTol',1e-12);
end

function testComparisonSelectionSurvivesSwapAndSuppression(t)
[main,P,V]=processedMainFixture(t,'stable_selection');
cleanup=onCleanup(@() delete(main)); %#ok<NASGU>
V.channelMenu.Value=1; V.channelMenu.Callback(V.channelMenu,[]);
P.position=2; P.selectedTraces=[1;1]; P.swapTraces();
verifyEqual(t,string(V.emgLine(1).DisplayName),"EMG_A | original: CH6");
verifyEqual(t,V.emgLine(1).YData,P.traces(2,801:1600)*P.rowInfo(2).scale,'AbsTol',1e-12);
P.selectedTraces=[1;0]; P.supressTraces(); % Remove CH7; CH6 stays selected.
verifyEqual(t,numel(V.emgLine),1);
verifyEqual(t,string(V.emgLine(1).DisplayName),"EMG_A | original: CH6");
verifyEqual(t,V.emgLine(1).YData,P.traces(1,801:1600)*P.rowInfo(1).scale,'AbsTol',1e-12);
end

function [main,P,V]=processedMainFixture(t,kind)
[file,~]=fixture(t,kind);
target=fullfile(t.TestData.folder,[kind '.h5']); VS3_sensorConvert({file},target);
recording=fullfile(t.TestData.folder,[kind '.mat']);
time=(0:47999)/1000;
traces=[.001*sin(2*pi*8*time)+.002*sin(2*pi*60*time);.001*sin(2*pi*9*time)];
Infos=struct('Fs',1000,'Channel','EMG_A, EMG_B','Unit','V','StartTimePosix', ...
    posixtime(datetime(2026,9,24,17,19,28,'TimeZone','UTC')));
traceName={'CH6','CH7'};
Sensor=struct('source',target,'offset',0,'bands',[.5 5;5 15],'channels',[1 2]);
save(recording,'traces','Infos','traceName','Sensor','-v7.3');
VS3_main(recording);
main=findall(groot,'Type','figure','Tag','VS3Main');
menu=findall(main,'Type','uimenu','Text','Show sensor / EMG comparison');
menu.Callback(menu,[]);
state=mainState(main); P=state.bigplot; V=state.sensorView;
end

function h=mainState(main)
info=functions(main.KeyPressFcn);
for k=1:numel(info.workspace)
    if isfield(info.workspace{k},'h'); h=info.workspace{k}.h; return; end
end
error('Test:state','Main-window state not found.');
end

function [file, raw] = fixture(t, kind)
file = fullfile(t.TestData.folder, [kind '.csv']);
time = (0:2399)'/200;
raw = round(2000+120*sin(2*pi*2*time)+40*sin(2*pi*8*time));
if strcmp(kind,'clip'); raw(1001) = 4095; end
keep = true(size(time));
if strcmp(kind,'gap'); keep(1001:1020) = false; end
fid = fopen(file,'w'); cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'type,session,sample_index,utc,elapsed_s,raw_adc,rate_hz,segment_id,near_rail,filter_warmup,demo,edge_monotonic_ns\n');
for k = find(keep)'
    % Wall clock stays fixed intentionally: acquisition elapsed_s must win.
    fprintf(fid,'sample,session,%d,2026-09-24T17:19:28+00:00,%.9f,%d,200,0,0,0,False,%.0f\n',k,time(k),raw(k),1e12+time(k)*1e9);
end
raw = raw(keep);
end

function testFrequencyTimelineKnownPeaksAndSharedClock(t)
[file,~]=fixture(t,'timeline');
target=fullfile(t.TestData.folder,'timeline.h5'); VS3_sensorConvert({file},target);
S=VS3_sensorTool('read',target);
T=VS3_sensorTool('timeline',S,2,[.5 5;5 15],1:4,@timelineEmg,[1 2]);
verifyEqual(t,T.time,[2;6;10;14]);
verifyEqual(t,T.sensorFrequency(2,:),[2 8],'AbsTol',.25);
verifyEqual(t,T.sensorAmplitude(2,:),[120 40],'AbsTol',2);
verifyTrue(t,all(isnan(T.sensorFrequency(1,:))));
verifyTrue(t,all(isnan(T.sensorFrequency(4,:))));
verifyEqual(t,T.recordedFrequency(:,1,1),ones(4,1)*2);
verifyEqual(t,T.recordedFrequency(:,2,1),ones(4,1)*7);
verifyEqual(t,T.recordedFrequency(:,2,2),ones(4,1)*9);
verifyEqual(t,T.recordedAmplitude(:,2,2),ones(4,1)*.5,'AbsTol',1e-6);
end

function testFrequencyTimelineCancellation(t)
[file,~]=fixture(t,'cancel_timeline');
target=fullfile(t.TestData.folder,'cancel_timeline.h5'); VS3_sensorConvert({file},target);
S=VS3_sensorTool('read',target);
T=VS3_sensorTool('timeline',S,0,[.5 5;5 15],1:3,@timelineEmg,1,@(k,~) k<2);
verifyTrue(t,T.cancelled);
verifyTrue(t,all(isnan(T.recordedFrequency(2:end,:,:)),'all'));
end

function [x,fs,unit]=timelineEmg(ch,~)
fs=200; time=(0:799)'/fs;
x=sin(2*pi*2*time)+.5*sin(2*pi*(5+2*ch)*time); unit='V';
end

function testTimelineViewDualUnitsAndDragging(t)
[file,~]=fixture(t,'timeline_ui');
target=fullfile(t.TestData.folder,'timeline_ui.h5'); VS3_sensorConvert({file},target);
S=VS3_sensorTool('read',target);
config=struct('offset',0,'bands',[.5 5;5 15],'channels',[1 2],'recordingEpochCount',3);
V=VS3_sensorView(S,config,{'EMG1','EMG2'},@timelineEmg,@(~) [],'off');
cleanup=onCleanup(@() delete(V)); %#ok<NASGU>
V.update(2); V.showOverview();
verifyEqual(t,numel(V.trendAxes),2);
verifyEqual(t,string(V.overviewPanel.Visible),"on");
verifyEqual(t,string(V.detailPanel.Visible),"off");
verifyEqual(t,V.trendAxes(1).YAxis(2).Limits,config.bands(1,:)*60);
verifyEqual(t,V.trendAxes(2).YAxis(2).Limits,config.bands(2,:)*60);
V.setWindowSeconds(4); V.setViewportStart(4);
verifyEqual(t,V.trendAxes(1).XLim,[4 8]);
verifyEqual(t,V.trendAxes(2).XLim,[4 8]);
V.showDetails(); verifyEqual(t,string(V.detailPanel.Visible),"on");
verifyEqual(t,string(V.overviewPanel.Visible),"off");
end

function testComparisonSettingsInvalidateOldTrends(t)
[file,~]=fixture(t,'timeline_settings');
target=fullfile(t.TestData.folder,'timeline_settings.h5'); VS3_sensorConvert({file},target);
S=VS3_sensorTool('read',target);
config=struct('offset',0,'bands',[.5 5;5 15],'channels',1,'recordingEpochCount',3);
V=VS3_sensorView(S,config,{'EMG'},@timelineEmg,@(~) [],'off');
cleanup=onCleanup(@() delete(V)); %#ok<NASGU>
V.showOverview();
verifyError(t,@() V.setAnalysis(0,[.5 5;5 21]),'VS3:sensorBand');
verifyEqual(t,V.config.bands,[.5 5;5 15]);
V.setAnalysis(2,[1 4;6 12]);
verifyEqual(t,V.config.offset,2);
verifyEqual(t,V.trendAxes(1).YAxis(2).Limits,[60 240]);
verifyTrue(t,all(isnan(V.timeline.sensorFrequency(1,:))));
end

function testOverviewSelectionAndViewportStayConsistent(t)
[file,~]=fixture(t,'timeline_selection');
target=fullfile(t.TestData.folder,'timeline_selection.h5'); VS3_sensorConvert({file},target);
S=VS3_sensorTool('read',target);
config=struct('offset',0,'bands',[.5 5;5 15],'channels',[1 2],'recordingEpochCount',3);
V=VS3_sensorView(S,config,{'EMG1','EMG2'},@timelineEmg,@(~) [],'off');
cleanup=onCleanup(@() delete(V)); %#ok<NASGU>
V.showOverview(); V.setWindowSeconds(4); V.setViewportStart(4);
V.showDetails(); V.showOverview();
verifyEqual(t,V.trendAxes(1).XLim,[4 8]);
V.channelMenu.Value=2; V.changeChannel();
verifyEqual(t,V.config.channels,2);
verifyEqual(t,V.timeline.recordedFrequency(:,2,1),ones(3,1)*9);
verifyEqual(t,V.trendAxes(1).XLim,[4 8]);
end

% Navigation expectations fixed before the viewport synchronization repair.
% Epoch 301 is [1200,1204] s; its center is 1202 s. A 300-s window
% must therefore be [1052,1352], clamped only at the recording boundaries.
function testFiveMinuteWindowStartsAtCurrentEeg(t)
V=navigationView(t); cleanup=onCleanup(@() delete(V)); %#ok<NASGU>
V.update(301);
V.windowMenu.Value=3; V.windowMenu.Callback(V.windowMenu,[]);
verifyEqual(t,V.trendAxes(1).XLim,[1052 1352]);
verifyEqual(t,V.trendAxes(2).XLim,[1052 1352]);
verifyEqual(t,V.viewportSlider.Value,1052);
end

function testEegNavigationKeepsEpochInsideComparison(t)
V=navigationView(t); cleanup=onCleanup(@() delete(V)); %#ok<NASGU>
V.update(301); V.setWindowSeconds(300);
V.update(320); % Still inside: avoid moving the view on every four-second step.
verifyEqual(t,V.trendAxes(1).XLim,[1052 1352]);
V.update(451); % [1800,1804] no longer inside: both plots follow.
verifyEqual(t,V.trendAxes(1).XLim,[1652 1952]);
verifyEqual(t,V.trendAxes(2).XLim,[1652 1952]);
verifyEqual(t,V.viewportSlider.Value,1652);
verifyEqual(t,[V.trendPositions.Value],[1802 1802]);
V.update(452);
verifyEqual(t,V.trendAxes(1).XLim,[1652 1952]);
end

function testComparisonFollowClampsAtRecordingBoundaries(t)
V=navigationView(t); cleanup=onCleanup(@() delete(V)); %#ok<NASGU>
V.setWindowSeconds(300);
verifyEqual(t,V.trendAxes(1).XLim,[0 300]);
V.update(600);
verifyEqual(t,V.trendAxes(1).XLim,[2100 2400]);
verifyEqual(t,V.trendAxes(2).XLim,[2100 2400]);
verifyEqual(t,V.viewportSlider.Value,2100);
V.setWindowSeconds(3600); % Recording shorter than selected window.
verifyEqual(t,V.trendAxes(1).XLim,[0 2400]);
end

function testManualPanAndWindowChangeRemainUsable(t)
V=navigationView(t); cleanup=onCleanup(@() delete(V)); %#ok<NASGU>
V.update(301); V.setWindowSeconds(300);
V.setViewportStart(0); % User may explore a different time range.
verifyEqual(t,V.trendAxes(1).XLim,[0 300]);
V.setWindowSeconds(60); % Changing duration should find the current EEG again.
verifyEqual(t,V.trendAxes(1).XLim,[1172 1232]);
V.setViewportStart(1800); V.update(301); % Same-epoch refresh must not undo panning.
verifyEqual(t,V.trendAxes(1).XLim,[1800 1860]);
V.update(302); % A new EEG selection resumes following.
verifyEqual(t,V.trendAxes(1).XLim,[1176 1236]);
end

function testEegFollowAlsoWorksWhileDetailsAreOpen(t)
V=navigationView(t); cleanup=onCleanup(@() delete(V)); %#ok<NASGU>
V.update(301); V.setWindowSeconds(300); V.showDetails();
V.update(451); V.showOverview();
verifyEqual(t,V.trendAxes(1).XLim,[1652 1952]);
verifyEqual(t,V.trendAxes(2).XLim,[1652 1952]);
end

function V=navigationView(t)
[file,~]=fixture(t,'navigation');
target=[tempname(t.TestData.folder) '.h5'];
VS3_sensorConvert({file},target);
S=VS3_sensorTool('read',target);
% A 40-minute synthetic EEG with sensor coverage only during its first 12 s.
config=struct('offset',0,'bands',[.5 5;5 15],'channels',1,'recordingEpochCount',600);
V=VS3_sensorView(S,config,{'EMG'},@timelineEmg,@(~) [],'off');
V.update(1); V.showOverview();
end
